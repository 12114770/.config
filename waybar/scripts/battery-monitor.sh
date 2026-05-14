#!/bin/sh

set -eu

BATTERY_DEV="$(upower -e | awk '/\/battery_/ { print; exit }')"
LAST_JSON=''

if [ -z "$BATTERY_DEV" ]; then
  printf '{"text":"no battery","tooltip":"No battery device found","class":["missing"]}\n'
  exit 0
fi

print_status() {
  info="$(upower -i "$BATTERY_DEV")"

  percentage=''
  state=''
  time_to_empty=''
  time_to_full=''

  while IFS="$(printf '\t')" read -r key value; do
    case "$key" in
      percentage) percentage="$value" ;;
      state) state="$value" ;;
      time_to_empty) time_to_empty="$value" ;;
      time_to_full) time_to_full="$value" ;;
    esac
  done <<EOF
$(printf '%s\n' "$info" | awk -F: '
  /^[[:space:]]*percentage:/ { gsub(/^[[:space:]]+/, "", $2); gsub(/%/, "", $2); print "percentage\t" $2 }
  /^[[:space:]]*state:/ { gsub(/^[[:space:]]+/, "", $2); print "state\t" $2 }
  /^[[:space:]]*time to empty:/ { gsub(/^[[:space:]]+/, "", $2); print "time_to_empty\t" $2 }
  /^[[:space:]]*time to full:/ { gsub(/^[[:space:]]+/, "", $2); print "time_to_full\t" $2 }
')
EOF

  [ -n "$percentage" ] || percentage=0

  if [ "$percentage" -le 10 ]; then
    icon="󰂎"
  elif [ "$percentage" -le 20 ]; then
    icon="󰁺"
  elif [ "$percentage" -le 30 ]; then
    icon="󰁻"
  elif [ "$percentage" -le 40 ]; then
    icon="󰁼"
  elif [ "$percentage" -le 50 ]; then
    icon="󰁽"
  elif [ "$percentage" -le 60 ]; then
    icon="󰁾"
  elif [ "$percentage" -le 70 ]; then
    icon="󰁿"
  elif [ "$percentage" -le 80 ]; then
    icon="󰂀"
  elif [ "$percentage" -le 90 ]; then
    icon="󰂁"
  elif [ "$percentage" -le 97 ]; then
    icon="󰂂"
  else
    icon="󰁹"
  fi

  text="$icon $percentage%"
  tooltip="$state"
  class="$state"

  case "$state" in
    charging)
      text="  $percentage%"
      if [ -n "$time_to_full" ]; then
        tooltip="Charging, $time_to_full until full"
      else
        tooltip="Charging"
      fi
      ;;
    fully-charged)
      if [ "$percentage" -eq 100 ]; then
        text="  $percentage%"
      else
        text="󰁹 $percentage%"
      fi
      tooltip="Fully charged"
      class="full"
      ;;
    pending-charge)
      text="  $percentage%"
      tooltip="Plugged in"
      class="plugged"
      ;;
    discharging)
      if [ -n "$time_to_empty" ]; then
        tooltip="Discharging, $time_to_empty remaining"
      else
        tooltip="Discharging"
      fi
      ;;
    *)
      tooltip="$state"
      ;;
  esac

  if [ "$percentage" -le 15 ]; then
    class="$class critical"
  elif [ "$percentage" -le 30 ]; then
    class="$class warning"
  fi

  text_escaped="$(printf '%s' "$text" | awk '{ gsub(/\\/, "\\\\"); gsub(/"/, "\\\""); print }')"
  tooltip_escaped="$(printf '%s' "$tooltip" | awk '{ gsub(/\\/, "\\\\"); gsub(/"/, "\\\""); print }')"

  json="$(printf '{"text":"%s","tooltip":"%s","class":["%s"]}' "$text_escaped" "$tooltip_escaped" "$class")"

  if [ "$json" != "$LAST_JSON" ]; then
    printf '%s\n' "$json"
    LAST_JSON="$json"
  fi
}

print_status
upower --monitor | while IFS= read -r _line; do
  print_status
done
