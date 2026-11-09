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

  # One eval runs float + center + focus in a single IPC call
  if [ -n "$window_id" ]; then
    w="address:$window_id"; hyprctl eval "hl.dispatch(hl.dsp.window.float({ window = \"$w\", action = \"enable\" })) hl.dispatch(hl.dsp.window.center({ window = \"$w\" })) hl.dispatch(hl.dsp.focus({ window = \"$w\" }))"
  fi
else
  # Window exists
  current_workspace=$(hyprctl activeworkspace -j | jq -r '.id')
  window_workspace=$(echo "$window_info" | jq -r '.workspace')

  if [ "$window_workspace" == "$current_workspace" ]; then
    # Toggle off: Move to special workspace (standard scratchpad)
    hyprctl dispatch "hl.dsp.window.move({ window = \"address:$window_id\", workspace = \"special:scratchpad\", follow = false })"
  else
    # Toggle on: Bring to current workspace and focus
    # One eval moves the window AND focuses it in the same frame
    w="address:$window_id"; hyprctl eval "hl.dispatch(hl.dsp.window.move({ window = \"$w\", workspace = $current_workspace, follow = false })) hl.dispatch(hl.dsp.focus({ window = \"$w\" }))"
  fi
fi
