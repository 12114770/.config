#!/bin/bash
secret-tool lookup keepass Passwords | keepassxc --pw-stdin /home/lukas/Passwords.kdbx &
sleep 3
swaymsg '[app_id="keepassxc"] move scratchpad'
