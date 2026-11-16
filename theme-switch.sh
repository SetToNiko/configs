#!/usr/bin/env bash
# Switch colour scheme.
# Usage: theme-switch.sh <name>, or no argument for a rofi picker.
here=$(dirname "$(readlink -f "$0")")
palettes="${PALETTES:-$here/palettes.json}"
out="$HOME/.config/colors"

# Menu rows: bold name, one swatch per main colour,
# and "(active)" after the current scheme
menu_rows='to_entries[]
  | "<b>\(.key)</b>   "
    + ([.value | .bg0, .fg0, .red, .orange, .yellow, .green, .aqua, .blue, .purple | "<span foreground=\"\(.)\">██</span>"] | join(""))
    + (if .key == $cur then "   <i>(active)</i>" else "" end)'

if [ -n "$1" ]; then
  name=$1
else
  . "$here/lib/rofi-picker.sh"
  current=$(cat "$out/current" 2>/dev/null)
  # Delete messages use the active palette's red
  red=$(jq -r --arg n "$current" '.[$n].red // "#ff5555"' "$palettes")
  name=$(json_picker "$palettes" Theme "$menu_rows" "$current" "$red" Palette) || exit 0
fi

[ -n "$name" ] || exit 0
jq -e --arg n "$name" 'has($n)' "$palettes" >/dev/null || { echo "no scheme '$name'" >&2; exit 1; }

mkdir -p "$out"
jq -r --arg n "$name" '.[$n] | to_entries[] | "set $\(.key) \(.value)"' \
  "$palettes" > "$out/i3"
jq -r --arg n "$name" '.[$n] | to_entries[] | "\(.key)=\(.value)"' \
  "$palettes" > "$out/colors.sh"
echo "$name" > "$out/current"

# Ghostty: the palette sets background, foreground and all 16 ANSI colours,
# so programs using named terminal colours (starship, ls, git, yazi) match it.
# A Ghostty theme of the same name, if there is one, still supplies the rest
# (cursor, selection). Palettes made by hand have none, and naming a missing
# theme is a Ghostty config error, so only name it when it exists, and take
# cursor and selection colours from the palette otherwise. Without ghostty
# on PATH it can't be checked: keep the theme line.
theme_line=1
if ghostty_bin=$(command -v ghostty); then
  themes="$(dirname "$(readlink -f "$ghostty_bin")")/../share/ghostty/themes"
  [ -f "$themes/$name" ] || [ -f "$HOME/.config/ghostty/themes/$name" ] || theme_line=
fi
{ if [ -n "$theme_line" ]; then
    printf 'theme = %s\n' "$name"
  else
    jq -r --arg n "$name" '.[$n]
      | "cursor-color = \(.fg0)", "cursor-text = \(.bg0)",
        "selection-background = \(.bg3)", "selection-foreground = \(.fg0)"' "$palettes"
  fi
  # 0 black, 1-6 accents, 7 white; 8-15 the bright versions
  jq -r --arg n "$name" '.[$n]
    | "background = \(.bg0)", "foreground = \(.fg0)",
      ([.bg1, .red, .green, .yellow, .blue, .purple, .aqua, .fg0] | to_entries[]
        | "palette = \(.key)=\(.value)"),
      ([.grey0, .red, .green, .yellow, .blue, .purple, .aqua, .fg1] | to_entries[]
        | "palette = \(.key + 8)=\(.value)")' \
    "$palettes"; } > "$out/ghostty"

# rofi: raw colours only; config.rasi decides what uses them
{ echo '* {'
  jq -r --arg n "$name" '.[$n] | to_entries[] | "    \(.key | gsub("_"; "-")): \(.value);"' "$palettes"
  echo '}'; } > "$out/rofi.rasi"

# Firefox (Pywalfox): mapping lives in configs/pywalfox/colors.jq
mkdir -p "$HOME/.cache/wal"
jq --arg n "$name" -f "$here/pywalfox/colors.jq" \
  "$palettes" > "$HOME/.cache/wal/colors.json"

if [ -z "$NO_RESTART" ]; then
  pkill -USR2 -f '^ghostty( |$)'   # Ghostty reloads its config on SIGUSR2
  i3-msg restart >/dev/null
  pywalfox update >/dev/null 2>&1
  # Wallpaper border colour follows bg0
  command -v wallpaper-rotate >/dev/null && wallpaper-rotate refresh >/dev/null 2>&1 &
fi
