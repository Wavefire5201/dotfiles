#!/usr/bin/env bash
# Rofi screenshot menu -> screenshot.sh actions
S="$HOME/.config/hypr/scripts/screenshot.sh"
BROWSE="$HOME/.config/hypr/scripts/screenshot-browse.sh"

options="󰩭  Region (annotate)
󰖯  Active window
󰍹  Whole screen
󰆏  Region to clipboard
󰚌  OCR region to text
󰈋  Pick colour
󰐃  Pin region to screen
󰋩  Browse screenshots"

sel="$(printf '%s' "$options" | rofi -dmenu -i -p "screenshot")"
# let rofi's layer surface fully close before we freeze/grab the screen or pin a
# window — otherwise the menu can end up in the frozen frame or steal focus
[ -n "$sel" ] && sleep 0.2
case "$sel" in
  *"Region (annotate)"*)   "$S" region ;;
  *"Active window"*)       "$S" window ;;
  *"Whole screen"*)        "$S" output ;;
  *"Region to clipboard"*) "$S" copy ;;
  *OCR*)                   "$S" ocr ;;
  *"Pick colour"*)         "$S" color ;;
  *"Pin region"*)          "$S" pin ;;
  *Browse*)                "$BROWSE" ;;
esac
