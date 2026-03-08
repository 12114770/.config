#!/bin/sh

set -eu

PIDFILE="${XDG_RUNTIME_DIR:-/tmp}/sway-idle-power.pid"
LOCK_CMD='swaylock -f -c 000000'
LOCK_AND_SCREEN_OFF_CMD='swaylock -f -c 000000 && swaymsg "output * dpms off"'
SCREEN_ON_CMD='swaymsg "output * dpms on"'
SUSPEND_CMD='systemctl suspend'

child_pid=""

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

start_swayidle() {
    mode="$1"

    if [ -n "${child_pid}" ]; then
        kill "${child_pid}" 2>/dev/null || true
        wait "${child_pid}" 2>/dev/null || true
    fi

    if [ "${mode}" = "ac" ]; then
        lock_timeout=1800
    else
        lock_timeout=300
    fi

    suspend_timeout=$((lock_timeout * 2))

    swayidle -w \
        timeout "${lock_timeout}" "${LOCK_AND_SCREEN_OFF_CMD}" \
        timeout "${suspend_timeout}" "${SUSPEND_CMD}" \
        resume "${SCREEN_ON_CMD}" \
        before-sleep "${LOCK_CMD}" &

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
