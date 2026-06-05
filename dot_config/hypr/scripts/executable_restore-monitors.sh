#!/usr/bin/env bash
# Restore previously saved brightness for each display, then clear the save
# files so the next dim cycle captures a fresh "original" value.
set -u

for d in 1 2; do
    f="/tmp/hypridle-brightness-$d"
    [ -r "$f" ] || continue
    b=$(cat "$f")
    if [ -n "${b:-}" ] && [ "$b" -ge 15 ] 2>/dev/null; then
        ddcutil --display "$d" setvcp 10 "$b" &
    fi
done
wait
rm -f /tmp/hypridle-brightness-*
