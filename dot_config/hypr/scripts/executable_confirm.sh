#!/usr/bin/env bash
# Themed Yes/No confirmation via rofi.
#   confirm.sh "Reboot the system now?" "systemctl reboot"
# Runs $2 only if the user picks "Yes". Defaults to "No" (safe for
# destructive actions). Theme: ~/.config/rofi/confirm.rasi
set -euo pipefail

prompt="${1:-Are you sure?}"
action="${2:-}"

choice=$(printf 'No\nYes' | rofi -dmenu -i \
  -theme "$HOME/.config/rofi/confirm.rasi" \
  -mesg "$prompt" \
  -no-custom \
  -selected-row 0 \
  -me-select-entry '' \
  -me-accept-entry 'MousePrimary' \
  -p "")

if [ "$choice" = "Yes" ] && [ -n "$action" ]; then
  exec sh -c "$action"
fi
