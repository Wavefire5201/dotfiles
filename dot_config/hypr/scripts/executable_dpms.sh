#!/bin/sh
# Monitors on/off. Hyprland 0.57 `hyprctl dispatch` takes Lua, so hypridle/hyprlock call this.
case "$1" in
  on) action=enable ;;
  off) action=disable ;;
  *) echo "usage: dpms.sh on|off" >&2; exit 1 ;;
esac
exec hyprctl dispatch "hl.dsp.dpms({ action = \"$action\" })"
