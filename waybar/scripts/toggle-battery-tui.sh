#!/bin/sh

TITLE="waybar-battery"
HTOP="/usr/bin/htop"

if pgrep -f "alacritty --title ${TITLE}" >/dev/null; then
  pkill -f "alacritty --title ${TITLE}"
  exit 0
fi

setsid -f alacritty --title "$TITLE" -e "$HTOP" >/dev/null 2>&1
