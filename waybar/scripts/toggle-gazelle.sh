#!/bin/sh

TITLE="waybar-gazelle"

if pgrep -f "alacritty --title ${TITLE}" >/dev/null; then
  pkill -f "alacritty --title ${TITLE}"
  exit 0
fi

exec alacritty --title "$TITLE" -e /home/lukas/.local/bin/gazelle
