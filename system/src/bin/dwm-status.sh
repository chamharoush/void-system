#!/bin/bash

DELIM=" ; "
SEP=" | "
SLOW_EVERY=5
ANSI=$'\e\\[[0-9;]*m'

CPU="󰍛 0%"
prev_total=0
prev_idle=0

module_action() {
    echo "[😈 Chamharoush]"
}

module_network() {
    if ip link show | grep -qE '^[0-9]+: e.*state UP'; then
        echo "󰈀 eth"
        return
    fi
    
    if command -v nmcli >/dev/null; then
        local con
        con=$(nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | awk -F: '/wireless/ {print $1; exit}')
        if [ -n "$con" ]; then
            echo "󰤨 $con"
            return
        fi
    fi
    
    echo "󰤭 off"
}

module_vpn() {
    if ip -o link show up 2>/dev/null | grep -qE ': (tun|tap|wg|proton)[0-9a-z]*'; then
        echo "󰒄 vpn"
    fi
}

module_cpu() {
    local cpu user nice system idle iowait irq softirq steal rest
    read -r cpu user nice system idle iowait irq softirq steal rest < /proc/stat
    local idle_all=$((idle + iowait))
    local total=$((user + nice + system + idle + iowait + irq + softirq + steal))
    local dt=$((total - prev_total))
    local di=$((idle_all - prev_idle))
    prev_total=$total
    prev_idle=$idle_all
    if [ "$dt" -gt 0 ]; then
        CPU="󰍛 $(( (100 * (dt - di)) / dt ))%"
    else
        CPU="󰍛 0%"
    fi
}

module_temp() {
    local z n t src=""
    for z in /sys/class/hwmon/hwmon*; do
        n=$(cat "$z/name" 2>/dev/null)
        case $n in
            coretemp|k10temp|zenpower|cpu_thermal) src="$z/temp1_input"; break ;;
        esac
    done
    if [ -z "$src" ]; then
        for z in /sys/class/thermal/thermal_zone*; do
            t=$(cat "$z/type" 2>/dev/null)
            case $t in
                x86_pkg_temp|TCPU|cpu-thermal|soc_thermal) src="$z/temp"; break ;;
            esac
        done
    fi
    [ -z "$src" ] && src=/sys/class/thermal/thermal_zone0/temp
    [ -r "$src" ] && echo "󰏈 $(( $(cat "$src") / 1000 ))°C"
}

module_ram() {
    local k v _ total=0 avail=0 used
    while read -r k v _; do
        case $k in
            MemTotal:) total=$v ;;
            MemAvailable:) avail=$v ;;
        esac
    done < /proc/meminfo
    used=$((total - avail))
    echo "󰘚 $((used / 1048576)).$(( (used % 1048576) * 10 / 1048576 ))G"
}

module_disk() {
    echo "󰋊 $(df -h / | awk 'NR==2 {print $5}')"
}

module_volume() {
    local vol muted=0
    if command -v wpctl >/dev/null; then
        local raw
        raw=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)
        vol=$(echo "$raw" | awk '{printf "%d", $2 * 100}')
        echo "$raw" | grep -q MUTED && muted=1
    elif command -v pactl >/dev/null; then
        vol=$(pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | grep -o '[0-9]*%' | head -1 | tr -d '%')
        pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | grep -q yes && muted=1
    else
        vol=$(amixer get Master 2>/dev/null | grep -o '[0-9]*%' | head -1 | tr -d '%')
        amixer get Master 2>/dev/null | grep -q '\[off\]' && muted=1
    fi
    [ -z "$vol" ] && return
    if [ "$muted" -eq 1 ]; then
        echo "󰖁 mut"
    else
        echo "󰕾 ${vol}%"
    fi
}

module_mic() {
    if command -v wpctl >/dev/null; then
        wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | grep -q MUTED && echo "󰍭 mut"
    elif command -v pactl >/dev/null; then
        pactl get-source-mute @DEFAULT_SOURCE@ 2>/dev/null | grep -q yes && echo "󰍭 mut"
    fi
}

module_battery() {
    local bat
    bat=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -1)
    [ -z "$bat" ] && return
    local cap status icon
    cap=$(cat "$bat/capacity")
    status=$(cat "$bat/status")
    case "$status" in
        Charging) icon="󰂄" ;;
        Full)     icon="󰁹" ;;
        *)        if [ "$cap" -le 15 ]; then icon="󰂃"; else icon="󰁹"; fi ;;
    esac
    if [ "$status" = "Full" ]; then
        echo "$icon"
    else
        echo "${icon} ${cap}%"
    fi
}

module_clock() {
    date '+󰥔 %a %d %b %H:%M'
}

join_modules() {
    local out="" part
    for part in "$@"; do
        [ -z "$part" ] && continue
        out="${out:+$out$SEP}$part"
    done
    echo "$out"
}

tick=0
net="" vpn="" temp="" disk="" bat=""

while true; do
    if [ $((tick % SLOW_EVERY)) -eq 0 ]; then
        net=$(module_network)
        vpn=$(module_vpn)
        temp=$(module_temp)
        disk=$(module_disk)
        bat=$(module_battery)
    fi

    action=$(module_action)
    module_cpu
    ram=$(module_ram)
    vol=$(module_volume)
    mic=$(module_mic)
    clock=$(module_clock)

    right=$(join_modules "$mic" "$vpn" "$net" "$CPU" "$temp" "$ram" "$disk" "$vol" "$bat" "$clock")

    xsetroot -name "${action}${DELIM}${right}"

    tick=$((tick + 1))
    sleep 1
done
