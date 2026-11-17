#!/bin/sh

DIR="$HOME/pictures/screenshots"
mkdir -p "$DIR"
FILE="$DIR/screenshot_$(date +%Y%m%d_%H%M%S).png"

monitor_geom() {
  xrandr --listmonitors |
    awk -v n="$1:" 'NR > 1 && $1 == n { print $3 }' |
    sed 's|/[0-9]*||g'
}

CHOICE=$(printf 'Screen 1\nScreen 2\nSelect area\n' | dmenu -i -p "Screenshot:")
[ -z "$CHOICE" ] && exit 0 # menu cancelled

case "$CHOICE" in
"Screen 1")
  GEOM=$(monitor_geom 0)
  maim -g "$GEOM" "$FILE"
  ;;
"Screen 2")
  GEOM=$(monitor_geom 1)
  maim -g "$GEOM" "$FILE"
  ;;
"Select area") maim -s "$FILE" ;;
*) exit 1 ;;
esac

if [ ! -s "$FILE" ]; then
  rm -f "$FILE"
  command -v notify-send >/dev/null && notify-send "Screenshot" "Cancelled or failed"
  exit 1
fi

xclip -selection clipboard -t image/png -i "$FILE"
command -v notify-send >/dev/null && notify-send "Screenshot saved" "$FILE"
