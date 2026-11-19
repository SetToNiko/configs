#!/usr/bin/env bash
# Drag-select screenshots (maim -s): drag a box, or click a window to take
# just that window; Esc or right click cancels.
#   screenshot.sh clip   copy to the clipboard            ($mod+s)
#   screenshot.sh save   save to ~/Documents/Screenshots  ($mod+Shift+s)
# A cancelled selection changes nothing: the clipboard keeps its contents and
# no empty file is left behind.
set -u

tmp=$(mktemp --suffix=.png)
trap 'rm -f "$tmp"' EXIT

# -u hides the mouse pointer in the shot
maim -s -u "$tmp" 2>/dev/null && [ -s "$tmp" ] || exit 0

case "${1:-}" in
  clip)
    xclip -selection clipboard -t image/png -i "$tmp"
    ;;
  save)
    dir="$HOME/Documents/Screenshots"
    mkdir -p "$dir"
    cp "$tmp" "$dir/$(date +%Y-%m-%d_%H-%M-%S).png"
    ;;
  *)
    echo "usage: $0 clip|save" >&2
    exit 1
    ;;
esac
