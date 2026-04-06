#!/bin/sh
set -eu

account=${1:?account required}
lock_dir="$HOME/.local/state/aerc"
lock_file="$lock_dir/mail-sync.lock"

mkdir -p "$lock_dir"

exec 9>"$lock_file"
if ! flock -n 9; then
  exit 0
fi

exec "$HOME/.config/aerc/scripts/sync-mail.sh" "$account"
