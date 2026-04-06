#!/bin/sh

APP_NAME="capslock-warning"

get_caps_on() {
    for led in /sys/class/leds/*::capslock/brightness; do
        [ -r "$led" ] || continue
        if [ "$(tr -d '[:space:]' < "$led")" = "1" ]; then
            return 0
        fi
    done
    return 1
}

active_ids() {
    makoctl list 2>/dev/null | python3 -c '
import json, sys

try:
    payload = json.load(sys.stdin)
except Exception:
    raise SystemExit(0)

for group in payload.get("data", []):
    for item in group:
        app = item.get("app-name", {}).get("data")
        if app == "capslock-warning":
            print(item.get("id", {}).get("data", ""))
'
}

dismiss_notification() {
    active_ids | while IFS= read -r id; do
        [ -n "$id" ] && makoctl dismiss -n "$id" >/dev/null 2>&1 || true
    done
}

show_notification() {
    notify-send \
        -u critical \
        -a "$APP_NAME" \
        -h string:x-canonical-private-synchronous:"$APP_NAME" \
        "Caps Lock On" \
        "Disable Caps Lock to avoid accidental typing." \
        >/dev/null 2>&1 || return 1
}

check_capslock() {
    if get_caps_on; then
        show_notification
    else
        dismiss_notification
    fi
}

if [ "$1" = "--toggle" ]; then
    dismiss_notification
    sleep 0.15
    check_capslock
elif [ "$1" = "--watch" ]; then
    last_state=""
    while :; do
        if get_caps_on; then
            state="on"
        else
            state="off"
        fi

        if [ "$state" != "$last_state" ]; then
            if [ "$state" = "on" ]; then
                show_notification
            else
                dismiss_notification
            fi
            last_state="$state"
        fi

        sleep 0.25
    done
else
    check_capslock
fi
