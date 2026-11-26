#!/usr/bin/env bash
# Palette menu ($mod+p in i3/config): pick a palette with rofi.
# The palette becomes the palette of the active Theme Studio theme (saved in
# theme-studio/themes.json), and theme-switch applies it. Without an active
# theme, the menu only applies the palette.
# Theme Studio keeps the active theme in ~/.config/colors/theme and the
# applied palette in ~/.config/colors/current.
set -euo pipefail

config=${XDG_CONFIG_HOME:-$HOME/.config}
palettes=$config/theme-studio/palettes.json
themes=$config/theme-studio/themes.json
current=$(cat "$config/colors/current" 2>/dev/null || true)
theme=$(cat "$config/colors/theme" 2>/dev/null || true)

# Shows an error in a rofi message box, then stops.
fail() {
  rofi -e "Palette menu: $1"
  exit 1
}

# The palettes in the order of palettes.json; the applied one is selected.
choice=$(jq -r '.palettes | keys_unsorted[]' "$palettes" |
  rofi -dmenu -i -p palette -select "$current") || exit 0
[ -n "$choice" ] || exit 0

# Save the palette in the active theme. A temporary file next to themes.json,
# then a rename, so a failed write never leaves half a file.
if [ -n "$theme" ] && jq -e --arg t "$theme" '.themes[$t]' "$themes" >/dev/null 2>&1; then
  tmp=$(mktemp "$themes.XXXXXX")
  if ! jq --arg t "$theme" --arg p "$choice" '.themes[$t].palette = $p' "$themes" >"$tmp"; then
    rm -f "$tmp"
    fail "could not save the palette in the theme '$theme'"
  fi
  chmod --reference="$themes" "$tmp"
  mv "$tmp" "$themes"
fi

theme-switch "$choice" || fail "theme-switch could not apply '$choice'"
