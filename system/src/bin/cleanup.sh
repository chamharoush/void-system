#!/bin/bash

set -u

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"
TERM_CMD="${TERMINAL:-xterm}"

wipe_dir() {
    [ -d "$1" ] && find "$1" -mindepth 1 -delete 2>/dev/null
}

remove() {
    rm -rf -- "$@"
}

confirm() {
    [ "$(printf '%s\n' "No" "Yes" | dmenu -i -p "$1")" = "Yes" ]
}

notify() {
    notify-send "Cleanup" "$1"
}

avail_kb() {
    df --output=avail -k "$HOME" 2>/dev/null | tail -n1 | tr -d ' '
}

soft_cleanup() {
    wipe_dir "$CACHE_DIR/mozilla"
    wipe_dir "$CACHE_DIR/fontconfig"
    wipe_dir "$CACHE_DIR/thumbnails"
    remove "$DATA_DIR/recently-used.xbel" \
           "$HOME/.viminfo" \
           "$HOME/.lesshst"
}

deep_cleanup() {
    wipe_dir "$CACHE_DIR"
    wipe_dir "$DATA_DIR/Trash"
    remove "$STATE_DIR/nvim/log" \
           "$DATA_DIR/recently-used.xbel" \
           "$HOME/.viminfo" \
           "$HOME/.lesshst" \
           "$HOME/.wget-hsts" \
           "$HOME/.python_history" \
           "$HOME/.node_repl_history" \
           "$HOME/.sqlite_history" \
           "$HOME/.psql_history" \
           "$HOME/.mysql_history" \
           "$HOME/.zsh_history"
    : > "$HOME/.bash_history"
    if command -v flatpak >/dev/null 2>&1; then
        flatpak uninstall --unused -y >/dev/null 2>&1
    fi
}

system_cleanup() {
    doas xbps-remove -Ooy >/dev/null 2>&1
    command -v vkpurge >/dev/null 2>&1 && doas vkpurge rm all >/dev/null 2>&1
    doas find /var/log -type f \( -name '@*.s' -o -name '@*.u' -o -name '*.gz' -o -name '*.old' \) -delete >/dev/null 2>&1
}

docker_cleanup() {
    if ! command -v docker >/dev/null 2>&1; then
        notify "Docker is not installed."
        return 1
    fi
    if ! docker info >/dev/null 2>&1; then
        notify "Docker daemon is not running or you lack permission."
        return 1
    fi
    if confirm "Also remove unused Docker volumes?"; then
        docker system prune -af --volumes >/dev/null 2>&1
    else
        docker system prune -af >/dev/null 2>&1
    fi
    docker builder prune -af >/dev/null 2>&1
}

choice=$(printf '%s\n' \
    "Soft Cleanup" \
    "Deep Cleanup" \
    "System Cleanup" \
    "Docker Cleanup" \
    "Full Cleanup" \
    | dmenu -i -p "Select Cleanup Mode:")

[ -z "$choice" ] && exit 0

before=$(avail_kb)

case "$choice" in
    "Soft Cleanup")
        soft_cleanup
        label="Soft"
        ;;
    "Deep Cleanup")
        confirm "Deep cleanup wipes ALL cache, trash and shell history. Continue?" || exit 0
        deep_cleanup
        label="Deep"
        ;;
    "System Cleanup")
        confirm "Remove orphaned packages, old kernels, package cache and rotated logs?" || exit 0
        system_cleanup
        label="System"
        ;;
    "Docker Cleanup")
        confirm "Remove all unused Docker images, containers, networks and build cache?" || exit 0
        docker_cleanup || exit 1
        label="Docker"
        ;;
    "Full Cleanup")
        confirm "Run Deep, Docker and System cleanup together?" || exit 0
        deep_cleanup
        docker_cleanup
        system_cleanup
        label="Full"
        ;;
    *)
        notify "Unknown option: $choice"
        exit 1
        ;;
esac

after=$(avail_kb)
freed=$(( (after - before) / 1024 ))
[ "$freed" -lt 0 ] && freed=0
notify "$label cleanup completed. Freed ~${freed} MiB."
