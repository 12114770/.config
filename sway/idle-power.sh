#!/bin/sh

set -eu

PIDFILE="${XDG_RUNTIME_DIR:-/tmp}/sway-idle-power.pid"
LOCK_CMD='swaylock -f -c 000000'

child_pid=""

suspend_now() {
    ${LOCK_CMD} &
    lock_pid=$!

    sleep 1

    systemctl suspend

    wait "${lock_pid}"
}

if [ "${1:-}" = "suspend-now" ]; then
    suspend_now
    exit 0
fi

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
        suspend_timeout=7200
    else
        suspend_timeout=600
    fi

    swayidle -w \
        timeout "${suspend_timeout}" "/home/lukas/.config/sway/idle-power.sh suspend-now" &

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
