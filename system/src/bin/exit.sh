#!/bin/sh

choice=$(printf "Shutdown\nReboot\nExit" | dmenu -i -p "Power:")

case "$choice" in
    Shutdown) doas poweroff ;;
    Reboot) doas reboot ;;
    Exit) pkill dwm ;;
esac
