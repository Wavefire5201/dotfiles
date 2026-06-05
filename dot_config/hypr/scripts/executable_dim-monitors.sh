#!/usr/bin/env bash
# Save current brightness for each detected display and dim it.
# Guards against the "saved value drifts down to dim level" bug:
#   - never overwrite an existing save file (we're already mid-dim)
#   - if current brightness is at/below the dim level, assume the monitor
#     was left stuck dim from a prior cycle and save a sensible default
#     instead so restore has something useful to put back.
set -u

DIM_LEVEL=10
MIN_SANE=$((DIM_LEVEL + 5))
DEFAULT_BRIGHTNESS=60

for d in 1 2; do
    f="/tmp/hypridle-brightness-$d"
    if [ ! -e "$f" ]; then
        b=$(ddcutil --display "$d" getvcp 10 --brief 2>/dev/null | awk '{print $4}')
        if [ -n "${b:-}" ] && [ "$b" -ge "$MIN_SANE" ] 2>/dev/null; then
            printf '%s\n' "$b" > "$f"
        else
            # current looks unreasonably low (or unreadable) — fall back to default
            printf '%s\n' "$DEFAULT_BRIGHTNESS" > "$f"
        fi
    fi
    ddcutil --display "$d" setvcp 10 "$DIM_LEVEL" &
done
wait
