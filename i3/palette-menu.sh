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

# The palettes in the order of palettes.json, one name per line.
names=$(jq -r '.palettes | keys_unsorted[]' "$palettes")

# One menu row per palette (Pango markup): a preview on the palette's own
# background (a text sample in its foreground colour, then its 7 accent
# colours as blocks), then the name. A missing colour shows as the
# background. The name is escaped, so & < > in a name cannot break the markup.
rows=$(jq -r '
  def esc: gsub("&"; "&amp;") | gsub("<"; "&lt;") | gsub(">"; "&gt;");
  .palettes | to_entries[] | .value as $p | ($p.bg0 // "#000000") as $bg |
  "<span background=\"\($bg)\" foreground=\"\($p.fg0 // $bg)\"> Aa "
  + ([ "red", "orange", "yellow", "green", "aqua", "blue", "purple" ]
     | map("<span foreground=\"\($p[.] // $bg)\">██</span>") | join(""))
  + " </span>  " + (.key | esc)
' "$palettes")

# The applied palette is the selected row (rofi counts rows from 0).
row=$(grep -nxF -- "$current" <<<"$names" | head -1 | cut -d: -f1 || true)
selected=$((${row:-1} - 1))

# rofi prints the number of the chosen row (-format i), not the markup.
index=$(rofi -dmenu -i -markup-rows -format i -p palette -selected-row "$selected" <<<"$rows") || exit 0
[ -n "$index" ] || exit 0
choice=$(sed -n "$((index + 1))p" <<<"$names")
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
