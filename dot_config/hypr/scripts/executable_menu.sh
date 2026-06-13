#!/usr/bin/env bash
# Central command menu (omarchy-style) — one rofi hub for the whole system.
# Bound to Super+Alt+Space. Re-press toggles it closed (or use Esc).
term="kitty"
S="$HOME/.config/hypr/scripts"

# toggle: if a rofi menu is already open, close it instead of opening another
if pgrep -x rofi >/dev/null 2>&1; then
  pkill -x rofi
  exit 0
fi

options="󰀻    Apps
󰆍    Run
󰖯    Windows
󰊠    Emoji
󰪚    Calculator
󰅍    Clipboard
󰹑    Screenshot
󰈋    Color picker
󰖩    Wi-Fi
󰂯    Bluetooth
󰕾    Audio
󰸉    Wallpaper
󰍃    Lock
󰐥    Power"

sel="$(printf '%s' "$options" | rofi -dmenu -i -p "menu")"
# let rofi close before launching grab/eyedropper actions
[ -n "$sel" ] && sleep 0.15

case "$sel" in
  *Apps*)            vicinae toggle ;;
  *Run*)             rofi -show run ;;
  *Windows*)         rofi -show window ;;
  *Emoji*)           rofi -show emoji -modi emoji ;;
  *Calculator*)      rofi -show calc -modi calc -no-show-match -no-sort ;;
  *Clipboard*)       pgrep clipse >/dev/null 2>&1 && killall clipse || "$term" --class clipse -e clipse ;;
  *Screenshot*)      "$S/screenshot-menu.sh" ;;
  *"Color picker"*)  "$S/screenshot.sh" color ;;
  *Wi-Fi*)           rofi-wifi-menu ;;
  *Bluetooth*)       blueman-manager ;;
  *Audio*)           pavucontrol ;;
  *Wallpaper*)       waypaper ;;
  *Lock*)            hyprlock ;;
  *Power*)           wlogout ;;
esac
