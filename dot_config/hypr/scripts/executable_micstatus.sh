#!/usr/bin/env bash
# waybar custom mic indicator.
#  - shows ONLY while an app is actively recording the mic (gpu-screen-recorder ignored)
#  - green glyph when unmuted, red when muted (via CSS class)
#  - clean text tooltip listing the app(s)
#  - on-click (set in waybar config) toggles mute
SRC="@DEFAULT_AUDIO_SOURCE@"

# apps currently capturing the mic, minus gpu-screen-recorder's persistent stream
apps=$(pactl list source-outputs 2>/dev/null \
  | grep -oP 'application\.name = "\K[^"]+' \
  | grep -viE 'gsr|gpu.?screen.?recorder' | sort -u)

if [ -z "$apps" ]; then
  echo '{"text":""}'      # nothing using the mic -> hidden
  exit 0
fi

if wpctl get-volume "$SRC" 2>/dev/null | grep -q '\[MUTED\]'; then
  cls="muted";   glyph="󰍭"   # mic-off
else
  cls="unmuted"; glyph="󰍬"   # mic
fi

tip=$(printf '%s' "$apps" | paste -sd ', ')
printf '{"text":"%s","class":"%s","tooltip":"Mic in use: %s"}\n' "$glyph" "$cls" "$tip"
