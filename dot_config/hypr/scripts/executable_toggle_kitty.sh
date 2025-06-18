#!/bin/bash

# Floating Kitty terminal toggle script for Hyprland
# This script toggles a floating kitty terminal window

WINDOW_CLASS="kitty-floating"
WINDOW_TITLE="Floating Terminal"

# Check if the window exists
window_id=$(hyprctl clients -j | jq -r ".[] | select(.class == \"$WINDOW_CLASS\") | .address")

if [ -z "$window_id" ]; then
  # Window doesn't exist, create it
  kitty --class="$WINDOW_CLASS" --title="$WINDOW_TITLE" &

  # Wait for the window to appear and get its ID
  for i in {1..20}; do
    sleep 0.1
    window_id=$(hyprctl clients -j | jq -r ".[] | select(.class == \"$WINDOW_CLASS\") | .address")
    if [ -n "$window_id" ]; then
      break
    fi
  done

  if [ -n "$window_id" ]; then
    # Force floating state and properties
    hyprctl dispatch setfloating address:$window_id
    sleep 0.1
    hyprctl dispatch centerwindow address:$window_id
    hyprctl dispatch resizewindowpixel exact 40% 40%,address:$window_id
    hyprctl dispatch focuswindow address:$window_id
  fi
else
  # Window exists, check if it's visible on current workspace
  current_workspace=$(hyprctl activeworkspace -j | jq -r '.id')
  window_workspace=$(hyprctl clients -j | jq -r ".[] | select(.address == \"$window_id\") | .workspace.id")
  window_hidden=$(hyprctl clients -j | jq -r ".[] | select(.address == \"$window_id\") | .hidden")

  if [ "$window_hidden" = "true" ]; then
    # Window is hidden, show it on current workspace
    hyprctl dispatch movetoworkspacesilent $current_workspace,address:$window_id
    hyprctl dispatch focuswindow address:$window_id
  elif [ "$window_workspace" = "$current_workspace" ]; then
    # Window is visible on current workspace, hide it
    hyprctl dispatch movetoworkspacesilent special:scratch,address:$window_id
  else
    # Window is on different workspace, bring it to current workspace
    hyprctl dispatch movetoworkspacesilent $current_workspace,address:$window_id
    hyprctl dispatch focuswindow address:$window_id
  fi
fi
