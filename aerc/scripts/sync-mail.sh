#!/bin/sh
set -eu

if ! command -v mbsync >/dev/null 2>&1; then
  printf '%s\n' 'mbsync is not installed. Run: sudo apt-get install isync libsasl2-modules-kdexoauth2' >&2
  exit 1
fi

account=${1:-allmail}
mbsync -c "$HOME/.config/isync/mbsyncrc" "$account"

if command -v notmuch >/dev/null 2>&1; then
  notmuch --config="$HOME/.config/notmuch/default/config" new
  exec "$HOME/.config/aerc/scripts/notify-new-mail.sh"
fi
