#!/usr/bin/env bash
# Unified screenshot + screen tools for Hyprland.
#
#   region   region        -> save + copy, then open annotator (optional drawing)
#   window   active window  -> save + copy, then annotator
#   output   whole monitor  -> save + copy (no annotate)
#   copy     region         -> clipboard only (nothing written to disk)
#   ocr      region         -> OCR (tesseract) -> clipboard
#   color    eyedropper     -> hex colour -> clipboard
#   pin      region         -> save + copy, pin as a floating always-on-top thumbnail
#
# Annotator is swappy by default. To switch: export SCREENSHOT_ANNOTATOR=ksnip
set -uo pipefail

DIR="${SCREENSHOT_DIR:-$HOME/Pictures/Screenshots}"
ANNOTATOR="${SCREENSHOT_ANNOTATOR:-swappy}"
mkdir -p "$DIR"
file="$DIR/screenshot_$(date +%Y-%m-%d_%H-%M-%S).png"

# note "<body>" [image] — if an image path is given, show it as the notification preview
note() {
  if [ -n "${2:-}" ] && [ -f "${2:-}" ]; then
    notify-send -a screenshot -t 3000 -i "$2" -h "string:image-path:$2" "Screenshot" "$1"
  else
    notify-send -a screenshot -t 3000 "Screenshot" "$1"
  fi
}

# annotate <src> <out> — open the annotator on <src>. swappy's -o prints the
# FINAL surface to stdout when it exits (copy-on-exit), which we tee to <out>.
# Returns 0 only if an annotated image was actually produced.
annotate() {
  local src="$1" out="$2"
  if [ "$ANNOTATOR" = swappy ]; then
    swappy -f "$src" -o - | tee "$out" >/dev/null
    [ -s "$out" ]
  else
    "$ANNOTATOR" "$src" # ksnip/other: rely on the tool's own save/clipboard
    return 1
  fi
}

case "${1:-region}" in
  region|window)
    [ "${1}" = window ] && target=active || target=area
    if grimblast --freeze save "$target" "$file"; then
      wl-copy < "$file" # raw capture on the clipboard immediately (fallback)
      edit="${file%.png}_edit.png"
      if annotate "$file" "$edit"; then
        wl-copy --type image/png < "$edit" # annotated result -> clipboard on exit
        note "Annotated · saved & copied $(basename "$edit")" "$edit"
      else
        rm -f "$edit"
        note "Saved & copied · $(basename "$file")" "$file"
      fi
    fi
    ;;
  output)
    if grimblast --freeze save output "$file"; then
      wl-copy < "$file"
      note "Saved & copied · $(basename "$file")" "$file"
    fi
    ;;
  copy)
    # save to a throwaway temp so the notification can preview the real image;
    # still copies to the clipboard, nothing lands in the screenshots dir
    tmp="$(mktemp --suffix=.png -p "${XDG_RUNTIME_DIR:-/tmp}" screenshot-clip.XXXXXX)"
    if grimblast --freeze save area "$tmp"; then
      wl-copy < "$tmp"
      note "Region copied to clipboard" "$tmp"
      ( sleep 30; rm -f "$tmp" ) >/dev/null 2>&1 &
    else
      rm -f "$tmp"
    fi
    ;;
  ocr)
    region="$(slurp)" || exit 0
    txt="$(grim -g "$region" - | tesseract - - -l eng 2>/dev/null)"
    if [ -n "${txt//[[:space:]]/}" ]; then
      printf '%s' "$txt" | wl-copy
      note "OCR copied · $(printf '%s' "$txt" | wc -w) words"
    else
      note "OCR · no text detected"
    fi
    ;;
  color)
    col="$(hyprpicker -a -f hex)" && [ -n "$col" ] && note "Colour copied · $col"
    ;;
  pin)
    if grimblast --freeze save area "$file"; then
      wl-copy < "$file"
      hyprctl dispatch exec "[float; pin; size 28% 28%; move 100%-30% 5%] imv \"$file\""
      note "Pinned · $(basename "$file")" "$file"
    fi
    ;;
  *)
    echo "usage: screenshot.sh {region|window|output|copy|ocr|color|pin}" >&2
    exit 1
    ;;
esac
