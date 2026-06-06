#!/bin/bash
# Raycast-style floating notes popup (nvim in kitty) toggle for Hyprland.
# Summon/dismiss with Super+W. Notes live in ~/notes (plain markdown).
WINDOW_CLASS="notes"
WINDOW_TITLE="Notes"
NOTES_FILE="$HOME/notes/scratch.md"

window_info=$(hyprctl clients -j | jq -r ".[] | select(.class == \"$WINDOW_CLASS\") | {address: .address, workspace: .workspace.id}")
window_id=$(echo "$window_info" | jq -r '.address')

if [ -z "$window_id" ] || [ "$window_id" == "null" ]; then
  # Doesn't exist — create floating + centered, open nvim on the scratch note
  kitty --class="$WINDOW_CLASS" --title="$WINDOW_TITLE" -e nvim "$NOTES_FILE" &
  for i in {1..10}; do
    sleep 0.1
    window_id=$(hyprctl clients -j | jq -r ".[] | select(.class == \"$WINDOW_CLASS\") | .address")
    [[ -n "$window_id" ]] && break
  done
  if [ -n "$window_id" ]; then
    hyprctl --batch "dispatch setfloating address:$window_id; dispatch centerwindow address:$window_id; dispatch focuswindow address:$window_id"
  fi
else
  # Exists — toggle: hide to scratchpad if on this workspace, else summon here
  current_workspace=$(hyprctl activeworkspace -j | jq -r '.id')
  window_workspace=$(echo "$window_info" | jq -r '.workspace')
  if [ "$window_workspace" == "$current_workspace" ]; then
    hyprctl dispatch movetoworkspacesilent special:scratchpad,address:$window_id
  else
    hyprctl --batch "dispatch movetoworkspacesilent $current_workspace,address:$window_id; dispatch focuswindow address:$window_id"
  fi
fi
