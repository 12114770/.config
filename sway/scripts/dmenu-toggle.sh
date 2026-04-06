#!/bin/sh

is_open() {
    pgrep -x bemenu >/dev/null 2>&1 || pgrep -f "j4-dmenu-desktop" >/dev/null 2>&1
}

close_menu() {
    pkill -x bemenu >/dev/null 2>&1 || true
    pkill -f "j4-dmenu-desktop" >/dev/null 2>&1 || true
}

open_menu() {
    if is_open; then
        return 0
    fi

    exec j4-dmenu-desktop --dmenu="env BEMENU_BACKEND=wayland /home/lukas/.local/bin/bemenu --binding vim --vim-esc-exits -i -n -c -l 8 --fixed-height --scrollbar autohide -p 'Search' --fn 'JetBrainsMono Nerd Font 10' -W 0.26 -H 30 --tb '#2f2f2f' --tf '#ffffff' --fb '#000000' --ff '#ffffff' --nb '#000000' --nf '#dddddd' --ab '#000000' --af '#dddddd' --hb '#000000' --hf '#ffffff' --sb '#000000' --sf '#ffffff' --scb '#2f2f2f' --scf '#6b6b6b' --bdr '#2472c8' -B 2 -R 0"
}

case "$1" in
    close)
        close_menu
        ;;
    open)
        open_menu
        ;;
    toggle|"")
        if is_open; then
            close_menu
        else
            open_menu
        fi
        ;;
    *)
        exit 1
        ;;
esac
