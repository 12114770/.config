#!/bin/sh
set -eu

NOTMUCH_CONFIG="$HOME/.config/notmuch/default/config"
STATE_DIR="$HOME/.local/state/aerc"
STATE_FILE="$STATE_DIR/notified-new-mail"
QUERY='tag:new and tag:unread and tag:inbox'

mkdir -p "$STATE_DIR"

current_file=$(mktemp)
previous_file=$(mktemp)
new_file=$(mktemp)
cleanup() {
  rm -f "$current_file" "$previous_file" "$new_file"
}
trap cleanup EXIT INT TERM

notmuch --config="$NOTMUCH_CONFIG" search --output=messages "$QUERY" | sort -u > "$current_file"

if [ ! -f "$STATE_FILE" ]; then
  cp "$current_file" "$STATE_FILE"
  exit 0
fi

sort -u "$STATE_FILE" > "$previous_file"
grep -Fvx -f "$previous_file" "$current_file" > "$new_file" || true

new_count=$(wc -l < "$new_file")
if [ "$new_count" -eq 0 ]; then
  cp "$current_file" "$STATE_FILE"
  exit 0
fi

summary=$(
  while IFS= read -r message_id; do
    [ -n "$message_id" ] || continue
    notmuch --config="$NOTMUCH_CONFIG" search --output=summary --limit=1 --sort=newest-first -- "id:\"$message_id\""
  done < "$new_file"
)
body=$(printf '%s\n' "$summary" | cut -d';' -f2- | sed 's/^ *//')

if [ -z "$body" ]; then
  body="$new_count new unread message(s)"
fi

notify-send \
  --app-name="mail-sync" \
  --icon="mail-unread" \
  "New mail ($new_count)" \
  "$body"

cp "$current_file" "$STATE_FILE"
