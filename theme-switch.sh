#!/usr/bin/env bash
  # Switch colour scheme.
  # Usage: theme-switch.sh <name>, or no argument for a rofi picker.
  palettes="${PALETTES:-$HOME/dotfiles-nixos/configs/palettes.json}"
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
    mapfile -t names < <(jq -r 'keys_unsorted[]' "$palettes")

    # Start the menu on the scheme that's active now
    current=$(cat "$out/current" 2>/dev/null)
    row=0
    for i in "${!names[@]}"; do
      [ "${names[$i]}" = "$current" ] && row=$i
    done

    idx=$(jq -r --arg cur "$current" "$menu_rows" "$palettes" |
      rofi -dmenu -i -markup-rows -format i \
        -selected-row "$row" -a "$row" -p "Theme") || exit 0
    name=${names[$idx]}
  fi

  [ -n "$name" ] || exit 0
  jq -e --arg n "$name" 'has($n)' "$palettes" >/dev/null || { echo "no scheme '$name'" >&2; exit 1; }

mkdir -p "$out"
jq -r --arg n "$name" '.[$n] | to_entries[] | "set $\(.key) \(.value)"' \
  "$palettes" > "$out/i3"
jq -r --arg n "$name" '.[$n] | to_entries[] | "\(.key)=\(.value)"' \
  "$palettes" > "$out/colors.sh"
echo "$name" > "$out/current"
# Ghostty: palette names are Ghostty theme names
# plus the palette's background, so edits to bg in palettes.json reach the terminal
printf 'theme = %s\nbackground = %s\n' "$name" "$(jq -r --arg n "$name" '.[$n].bg0' "$palettes")" > "$out/ghostty"

# rofi: raw colours only; config.rasi decides what uses them
{ echo '* {'
  jq -r --arg n "$name" '.[$n] | to_entries[] | "    \(.key | gsub("_"; "-")): \(.value);"' "$palettes"
  echo '}'; } > "$out/rofi.rasi"

# Firefox (Pywalfox): mapping lives in configs/pywalfox/colors.jq
mkdir -p "$HOME/.cache/wal"
jq --arg n "$name" -f "$HOME/dotfiles-nixos/configs/pywalfox/colors.jq" \
  "$palettes" > "$HOME/.cache/wal/colors.json"

if [ -z "$NO_RESTART" ]; then
  pkill -USR2 -f '^ghostty( |$)'   # Ghostty reloads its config on SIGUSR2
  i3-msg restart >/dev/null
  pywalfox update >/dev/null 2>&1
fi
