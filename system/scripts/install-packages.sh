#!/bin/sh

set -eu

if [ "$(id -u)" -ne 0 ]; then
    echo "Run this script as root." >&2
    exit 1
fi

xbps-install -Syu xbps
xbps-install -y void-repo-nonfree
xbps-install -Sy

packages="
dejavu-fonts-ttf
noto-fonts-ttf
noto-fonts-ttf-extra
noto-fonts-emoji
nerd-fonts-symbols-ttf
NetworkManager
alsa-pipewire
base-system
bridge-utils
chrony
cryptsetup
curl
dialog
docker
docker-buildx
docker-compose
dunst
edk2-ovmf
elogind
fd
firefox
gcc
gnupg
grub-x86_64-efi
gst-plugins-ugly1
htop
iptables-nft
keepassxc
libX11-devel
libXft-devel
libXinerama-devel
libnotify
libspa-bluetooth
libvirt
linux
lvm2
maim
make
mesa-dri
opendoas
passt
patch
pavucontrol
pipewire
pkg-config
polkit
psmisc
pulseaudio-utils
qemu
setxkbmap
socklog-void
swtpm
sxhkd
tmux
tree
ufw
unzip
vim
virt-manager
wget
wireplumber
xauth
xclip
xdg-utils
xdotool
xev
xinit
xorg-input-drivers
xorg-server
xprop
xrandr
xsetroot
zathura
zathura-pdf-mupdf
"

xbps-install -y $packages
