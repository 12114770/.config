#!/bin/sh

APP_NAME="tui-osd"
BAR_WIDTH=18

clamp_percent() {
    value=${1:-0}

    if [ "$value" -lt 0 ] 2>/dev/null; then
        printf '0\n'
    elif [ "$value" -gt 100 ] 2>/dev/null; then
        printf '100\n'
    else
        printf '%s\n' "$value"
    fi
}

repeat_char() {
    count=${1:-0}
    char=${2:-#}
    result=""

    while [ "$count" -gt 0 ]; do
        result="${result}${char}"
        count=$((count - 1))
    done

    printf '%s' "$result"
}

level_word() {
    percent=$(clamp_percent "$1")

    if [ "$percent" -le 5 ]; then
        printf 'MIN\n'
    elif [ "$percent" -le 30 ]; then
        printf 'LOW\n'
    elif [ "$percent" -le 65 ]; then
        printf 'MID\n'
    elif [ "$percent" -le 95 ]; then
        printf 'HIGH\n'
    else
        printf 'MAX\n'
    fi
}

render_box() {
    headline=$1
    percent=$(clamp_percent "$2")
    state=$3
    filled=$((percent * BAR_WIDTH / 100))
    empty=$((BAR_WIDTH - filled))
    if [ "$state" = "MUTED" ]; then
        bar="$(repeat_char "$BAR_WIDTH" '░')"
    else
        bar="$(repeat_char "$filled" '█')$(repeat_char "$empty" '░')"
    fi

    label_len=${#headline}
    pad=$(( (BAR_WIDTH - label_len) / 2 ))
    padding="$(repeat_char "$pad" ' ')"

    printf '%s%s\n%s' "$padding" "$headline" "$bar"
}

show_osd() {
    body=$1

    notify-send \
        -a "$APP_NAME" \
        -u normal \
        -h string:x-canonical-private-synchronous:"$APP_NAME" \
        "$body" \
        >/dev/null 2>&1
}

brightness_percent() {
    brightnessctl info | sed -n 's/.*(\([0-9][0-9]*\)%).*/\1/p'
}

volume_percent() {
    pactl get-sink-volume @DEFAULT_SINK@ | grep -o '[0-9]\+%' | tr -d '%' | sed -n '1p'
}

volume_state() {
    if pactl get-sink-mute @DEFAULT_SINK@ | grep -q 'yes'; then
        printf 'MUTED\n'
    else
        printf 'LIVE\n'
    fi
}

show_brightness() {
    percent=$(brightness_percent)
    box=$(render_box "BRIGHTNESS" "$percent" "DISPLAY")
    show_osd "$box"
}

show_volume() {
    percent=$(volume_percent)
    state=$(volume_state)

    if [ "$state" = "MUTED" ]; then
        box=$(render_box "VOLUME" 0 "$state")
    else
        box=$(render_box "VOLUME" "$percent" "$state")
    fi

    show_osd "$box"
}

case "$1" in
    volume-up)
        pactl set-sink-volume @DEFAULT_SINK@ +5% >/dev/null 2>&1 && show_volume
        ;;
    volume-down)
        pactl set-sink-volume @DEFAULT_SINK@ -5% >/dev/null 2>&1 && show_volume
        ;;
    volume-mute)
        pactl set-sink-mute @DEFAULT_SINK@ toggle >/dev/null 2>&1 && show_volume
        ;;
    brightness-up)
        brightnessctl set 5%+ >/dev/null 2>&1 && show_brightness
        ;;
    brightness-down)
        brightnessctl set 5%- >/dev/null 2>&1 && show_brightness
        ;;
    show-volume)
        show_volume
        ;;
    show-brightness)
        show_brightness
        ;;
    *)
        printf 'Usage: %s {volume-up|volume-down|volume-mute|brightness-up|brightness-down|show-volume|show-brightness}\n' "$0" >&2
        exit 1
        ;;
esac
