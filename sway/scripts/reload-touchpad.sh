#!/bin/sh

if sudo -n modprobe -r psmouse && sudo -n modprobe psmouse; then
    notify-send "Touchpad reloaded" "The psmouse module was restarted."
else
    notify-send -u critical "Touchpad reload failed" "Allow passwordless modprobe for psmouse in sudoers, then try again."
    exit 1
fi
