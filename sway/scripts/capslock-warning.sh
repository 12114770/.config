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
    makoctl list -j 2>/dev/null | python3 -c '
import json, sys

try:
    payload = json.load(sys.stdin)
except Exception:
    raise SystemExit(0)

if isinstance(payload, dict):
    groups = payload.get("data", [])
else:
    groups = [payload]

for group in groups:
    for item in group:
        app = item.get("app_name")
        if app is None:
            app = item.get("app-name", {}).get("data")
        if app == "capslock-warning":
            notification_id = item.get("id")
            if isinstance(notification_id, dict):
                notification_id = notification_id.get("data", "")
            print(notification_id or "")
'
}

dismiss_notification() {
    active_ids | while IFS= read -r id; do
        [ -n "$id" ] && makoctl dismiss -n "$id" >/dev/null 2>&1 || true
    done
}

has_notification() {
    active_ids | grep -q '.'
}

caps_state() {
    if get_caps_on; then
        printf 'on\n'
    else
        printf 'off\n'
    fi
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

sync_after_toggle() {
    stable_state=""
    stable_count=0
    attempts=0

    while [ "$attempts" -lt 10 ]; do
        state=$(caps_state)

        if [ "$state" = "$stable_state" ]; then
            stable_count=$((stable_count + 1))
        else
            stable_state="$state"
            stable_count=1
        fi

        if [ "$stable_count" -ge 2 ]; then
            break
        fi

        attempts=$((attempts + 1))
        sleep 0.05
    done

    if [ "$stable_state" = "on" ]; then
        show_notification
    else
        dismiss_notification
    fi
}

if [ "$1" = "--toggle" ]; then
    if has_notification; then
        dismiss_notification
    else
        show_notification
    fi
else
    check_capslock
fi
