#!/bin/sh

set -eu

PIDFILE="${XDG_RUNTIME_DIR:-/tmp}/sway-idle-power.pid"
DELAYED_SUSPEND_PIDFILE="${XDG_RUNTIME_DIR:-/tmp}/sway-delayed-suspend.pid"
SCRIPT_PATH="/home/lukas/.config/sway/idle-power.sh"
LOCK_CMD='swaylock -f -c 000000'

child_pid=""

log_msg() {
    if command -v logger >/dev/null 2>&1; then
        logger -t sway-idle-power "$*"
    fi
}

media_playing() {
    if ! command -v playerctl >/dev/null 2>&1; then
        return 1
    fi

    statuses=$(playerctl status 2>/dev/null || true)
    [ -n "${statuses}" ] || return 1

    printf '%s\n' "${statuses}" | grep -qx 'Playing'
}

lock_now() {
    if media_playing; then
        log_msg "skipping automatic lock because media is playing"
        return 0
    fi

    ${LOCK_CMD}
}

dpms_off_now() {
    if media_playing; then
        log_msg "skipping dpms off because media is playing"
        return 0
    fi

    swaymsg 'output * dpms off' >/dev/null
}

dpms_on_now() {
    swaymsg 'output * dpms on' >/dev/null
}

has_active_external_output() {
    if ! command -v swaymsg >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
        return 1
    fi

    swaymsg -t get_outputs -r 2>/dev/null | jq -e '
        map(select(
            .active == true and
            (.name | test("^(eDP|LVDS|DSI)"; "i") | not)
        ))
        | length > 0
    ' >/dev/null 2>&1
}

suspend_now() {
    ${LOCK_CMD} &
    systemctl suspend
}

handle_lid_close() {
    if has_active_external_output; then
        log_msg "ignoring lid close because an external output is active"
        return 0
    fi

    lock_now
}

schedule_suspend_in_five_minutes() {
    if [ -f "${DELAYED_SUSPEND_PIDFILE}" ]; then
        delayed_pid=$(cat "${DELAYED_SUSPEND_PIDFILE}" 2>/dev/null || true)
        if [ -n "${delayed_pid}" ] && kill -0 "${delayed_pid}" 2>/dev/null; then
            kill "${delayed_pid}" 2>/dev/null || true
        fi
        rm -f "${DELAYED_SUSPEND_PIDFILE}"
    fi

    ${LOCK_CMD} &
    (
        sleep 300
        rm -f "${DELAYED_SUSPEND_PIDFILE}"

        if session_is_idle; then
            log_msg "suspending after delayed lock because session is still idle"
            systemctl suspend
        else
            log_msg "cancelled delayed suspend because session became active"
        fi
    ) >/dev/null 2>&1 &
    printf '%s\n' "$!" > "${DELAYED_SUSPEND_PIDFILE}"
    log_msg "scheduled suspend in 5 minutes"
}

suspend_if_allowed() {
    if media_playing; then
        log_msg "skipping suspend because media is playing"
        return 0
    fi

    suspend_now
}

hibernate_if_allowed() {
    if media_playing; then
        log_msg "skipping hibernate because media is playing"
        return 0
    fi

    ${LOCK_CMD} &
    systemctl hibernate
}

suspend_then_hibernate_if_on_battery() {
    if on_ac_power; then
        log_msg "skipping suspend-then-hibernate because AC power is connected"
        return 0
    fi

    if media_playing; then
        log_msg "skipping suspend-then-hibernate because media is playing"
        return 0
    fi

    ${LOCK_CMD} &
    systemctl suspend-then-hibernate
}

case "${1:-}" in
    lock-now)
        lock_now
        exit 0
        ;;
    dpms-off)
        dpms_off_now
        exit 0
        ;;
    dpms-on)
        dpms_on_now
        exit 0
        ;;
    suspend-now)
        suspend_now
        exit 0
        ;;
    handle-lid-close)
        handle_lid_close
        exit 0
        ;;
    lock-then-suspend)
        schedule_suspend_in_five_minutes
        exit 0
        ;;
    suspend-if-allowed)
        suspend_if_allowed
        exit 0
        ;;
    hibernate-if-allowed)
        hibernate_if_allowed
        exit 0
        ;;
    suspend-then-hibernate-if-on-battery)
        suspend_then_hibernate_if_on_battery
        exit 0
        ;;
esac

cleanup() {
    if [ -n "${child_pid}" ]; then
        kill "${child_pid}" 2>/dev/null || true
        wait "${child_pid}" 2>/dev/null || true
        child_pid=""
    fi

    if [ -f "${PIDFILE}" ] && [ "$(cat "${PIDFILE}")" = "$$" ]; then
        rm -f "${PIDFILE}"
    fi
}

trap 'cleanup; exit 0' INT TERM EXIT

if [ -f "${PIDFILE}" ]; then
    old_pid=$(cat "${PIDFILE}" 2>/dev/null || true)
    if [ -n "${old_pid}" ] && kill -0 "${old_pid}" 2>/dev/null; then
        kill "${old_pid}" 2>/dev/null || true
        sleep 1
    fi
fi

printf '%s\n' "$$" > "${PIDFILE}"

on_ac_power() {
    for supply in /sys/class/power_supply/*; do
        [ -d "${supply}" ] || continue
        [ -f "${supply}/type" ] || continue
        [ -f "${supply}/online" ] || continue

        if [ "$(cat "${supply}/type")" = "Mains" ] && [ "$(cat "${supply}/online")" = "1" ]; then
            return 0
        fi
    done

    return 1
}

session_is_idle() {
    session_id=${XDG_SESSION_ID:-}
    [ -n "${session_id}" ] || return 0

    idle_hint=$(loginctl show-session "${session_id}" -p IdleHint --value 2>/dev/null || true)
    [ "${idle_hint}" = "yes" ]
}

start_swayidle() {
    mode="$1"

    if [ -n "${child_pid}" ]; then
        kill "${child_pid}" 2>/dev/null || true
        wait "${child_pid}" 2>/dev/null || true
    fi

    if [ "${mode}" = "ac" ]; then
        lock_timeout=1200
        dpms_timeout=1800
        suspend_timeout=36000
        sleep_action="${SCRIPT_PATH} hibernate-if-allowed"
    else
        lock_timeout=600
        dpms_timeout=900
        suspend_timeout=36000
        sleep_action="${SCRIPT_PATH} hibernate-if-allowed"
    fi

    log_msg "starting swayidle mode=${mode} lock=${lock_timeout}s dpms=${dpms_timeout}s hibernate=${suspend_timeout}s"

    swayidle -w \
        before-sleep "${LOCK_CMD}" \
        timeout "${lock_timeout}" "${SCRIPT_PATH} lock-now" \
        timeout "${suspend_timeout}" "${sleep_action}" &

    child_pid="$!"
}

current_mode=""

while :; do
    next_mode="battery"
    if on_ac_power; then
        next_mode="ac"
    fi

    if [ "${next_mode}" != "${current_mode}" ]; then
        start_swayidle "${next_mode}"
        current_mode="${next_mode}"
    fi

    sleep 30
done
