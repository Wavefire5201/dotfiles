#!/bin/bash

# Floating Kitty terminal toggle script for Hyprland
WINDOW_CLASS="kitty-floating"
WINDOW_TITLE="Floating Terminal"

# Use the -j (JSON) output and pipe once to jq for efficiency
window_info=$(hyprctl clients -j | jq -r ".[] | select(.class == \"$WINDOW_CLASS\") | {address: .address, workspace: .workspace.id}")
window_id=$(echo "$window_info" | jq -r '.address')

if [ -z "$window_id" ] || [ "$window_id" == "null" ]; then
  # Window doesn't exist, create it
  kitty --class="$WINDOW_CLASS" --title="$WINDOW_TITLE" &

  # Reduced sleep loop using the new 'activewindow' check for speed
  for i in {1..10}; do
    sleep 0.1
    window_id=$(hyprctl clients -j | jq -r ".[] | select(.class == \"$WINDOW_CLASS\") | .address")
    [[ -n "$window_id" ]] && break
  done

  # 0.53 batching: send multiple commands in one go to the IPC socket
  if [ -n "$window_id" ]; then
    hyprctl --batch "dispatch setfloating address:$window_id; dispatch centerwindow address:$window_id; dispatch focuswindow address:$window_id"
  fi
else
  # Window exists
  current_workspace=$(hyprctl activeworkspace -j | jq -r '.id')
  window_workspace=$(echo "$window_info" | jq -r '.workspace')

  if [ "$window_workspace" == "$current_workspace" ]; then
    # Toggle off: Move to special workspace (standard scratchpad)
    hyprctl dispatch movetoworkspacesilent special:scratchpad,address:$window_id
  else
    # Toggle on: Bring to current workspace and focus
    # Using --batch ensures the window moves AND gains focus in the same frame
    hyprctl --batch "dispatch movetoworkspacesilent $current_workspace,address:$window_id; dispatch focuswindow address:$window_id"
  fi
fi
