#!/bin/sh

STEP="${2:-5}"
CONTROL="Master"

command -v wpctl >/dev/null 2>&1 || {
    echo "error: wpctl not found" >&2
    exit 1
}

case "$1" in
  up)   wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ ;;
  down) wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- ;;
  mute) wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle ;;
esac
