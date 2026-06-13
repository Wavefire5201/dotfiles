#!/usr/bin/env bash
# Browse recent screenshots in rofi (thumbnails) with per-item actions.
DIR="${SCREENSHOT_DIR:-$HOME/Pictures/Screenshots}"
[ -d "$DIR" ] || exit 0

# newest-first list, thumbnail shown as the rofi icon
entries="$(
  fd -e png -e jpg -e jpeg --type f . "$DIR" 2>/dev/null \
    | xargs -d '\n' -r ls -1t 2>/dev/null \
    | head -100 \
    | while IFS= read -r f; do
        printf '%s\0icon\x1f%s\n' "$(basename "$f")" "$f"
      done
)"
[ -z "$entries" ] && { notify-send -a screenshot "Screenshot" "No screenshots yet"; exit 0; }

sel="$(printf '%s' "$entries" | rofi -dmenu -i -show-icons -p "screenshots")"
[ -z "$sel" ] && exit 0
target="$DIR/$sel"
[ -f "$target" ] || exit 0

action="$(printf 'Open\nCopy to clipboard\nAnnotate\nDelete\nReveal in files' \
  | rofi -dmenu -i -p "$sel")"
case "$action" in
  Open)                imv "$target" & ;;
  "Copy to clipboard") wl-copy < "$target"; notify-send -a screenshot "Screenshot" "Copied $sel" ;;
  Annotate)            swappy -f "$target" -o - | wl-copy --type image/png ;;
  Delete)              rm -f "$target"; notify-send -a screenshot "Screenshot" "Deleted $sel" ;;
  "Reveal in files")   dolphin --select "$target" & ;;
esac
