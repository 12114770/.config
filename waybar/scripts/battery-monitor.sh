#!/bin/sh

set -eu

BATTERY_DEV="$(upower -e | awk '/\/battery_/ { print; exit }')"

if [ -z "$BATTERY_DEV" ]; then
  printf '{"text":"no battery","tooltip":"No battery device found","class":["missing"]}\n'
  exit 0
fi

print_status() {
  info="$(upower -i "$BATTERY_DEV")"

  percentage="$(printf '%s\n' "$info" | awk -F: '/^[[:space:]]*percentage:/ { gsub(/^[[:space:]]+/, "", $2); gsub(/%/, "", $2); print $2; exit }')"
  state="$(printf '%s\n' "$info" | awk -F: '/^[[:space:]]*state:/ { gsub(/^[[:space:]]+/, "", $2); print $2; exit }')"
  time_to_empty="$(printf '%s\n' "$info" | awk -F: '/^[[:space:]]*time to empty:/ { gsub(/^[[:space:]]+/, "", $2); print $2; exit }')"
  time_to_full="$(printf '%s\n' "$info" | awk -F: '/^[[:space:]]*time to full:/ { gsub(/^[[:space:]]+/, "", $2); print $2; exit }')"

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

  text_escaped="$(printf '%s' "$text" | sed 's/\\/\\\\/g; s/"/\\"/g')"
  tooltip_escaped="$(printf '%s' "$tooltip" | sed 's/\\/\\\\/g; s/"/\\"/g')"

  printf '{"text":"%s","tooltip":"%s","class":["%s"]}\n' "$text_escaped" "$tooltip_escaped" "$class"
}

print_status
upower --monitor-detail | while IFS= read -r _line; do
  print_status
done
