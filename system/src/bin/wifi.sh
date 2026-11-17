#!/bin/sh

notify-send "WiFi" "Scanning for networks..."

nmcli radio wifi on
nmcli device wifi rescan >/dev/null 2>&1

sleep 2

LIST=$(nmcli -g SSID,SECURITY device wifi list | grep -v '^:')

if [ -z "$LIST" ]; then
    notify-send -u critical "WiFi Error" "No networks found by nmcli!"
    exit 1
fi

OFF_OPTION="󰤮  Turn Off WiFi"

MENU=$(printf "%s\n%s" "$OFF_OPTION" "$(echo "$LIST" | sort -u | awk -F: '{print "󰤨  "$1" ["$2"]"}')")

CHOSEN=$(echo "$MENU" | dmenu -i -l 10 -p "Select WiFi:")
[ -z "$CHOSEN" ] && exit 0

if [ "$CHOSEN" = "$OFF_OPTION" ]; then
    nmcli radio wifi off
    notify-send "WiFi" "WiFi disabled"
    exit 0
fi

SSID=$(echo "$CHOSEN" | sed -E 's/^󰤨  //; s/ \[[^]]+\]$//')
notify-send "WiFi" "Connecting to: $SSID..."

OUT=$(nmcli connection up "$SSID" 2>&1)
if [ $? -eq 0 ]; then
    notify-send "WiFi" "Connected to $SSID (Saved)"
    exit 0
fi

PASS=$(dmenu -p "Password for $SSID:" < /dev/null)
[ -z "$PASS" ] && exit 0

OUT=$(nmcli device wifi connect "$SSID" password "$PASS" 2>&1)
if [ $? -eq 0 ]; then
    notify-send "WiFi" "Connected to $SSID"
else
    notify-send -u critical "WiFi Failed" "Error: $OUT"
fi
