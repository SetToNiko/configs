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
    current=$(cat "$out/current" 2>/dev/null)
    row=-1
    notice=
    # Delete messages use the active palette's red
    red=$(jq -r --arg n "$current" '.[$n].red // "#ff5555"' "$palettes")
    while :; do
      mapfile -t names < <(jq -r 'keys_unsorted[]' "$palettes")

      active=0
      for i in "${!names[@]}"; do
        [ "${names[$i]}" = "$current" ] && active=$i
      done
      # First time round, start on the active scheme; after a delete, stay put
      [ "$row" -lt 0 ] && row=$active
      [ "$row" -ge "${#names[@]}" ] && row=$((${#names[@]} - 1))

      # Hint line, with the result of the last delete (if any) above it
      mesg="Enter: apply   Alt+BackSpace: delete from palettes.json"
      [ -n "$notice" ] && mesg="<span foreground=\"$red\"><b>$notice</b></span>"$'\n'"$mesg"
      notice=

      # Alt+BackSpace (kb-custom-1) deletes the highlighted scheme; rofi exits with 10.
      idx=$(jq -r --arg cur "$current" "$menu_rows" "$palettes" |
        rofi -dmenu -i -markup-rows -format i \
          -kb-custom-1 Alt+BackSpace -mesg "$mesg" \
          -selected-row "$row" -a "$active" -p "Theme")
      status=$?

      if [ "$status" -eq 10 ] && [ -n "$idx" ]; then
        row=$idx
        # Keep the active scheme: activation falls back to a default without it
        # Name escaped for rofi's Pango markup
        label=$(printf '%s' "${names[$idx]}" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
        if [ "${names[$idx]}" = "$current" ]; then
          notice="Palette \"$label\" is active and can't be deleted"
        else
          tmp=$(mktemp) &&
            jq --arg n "${names[$idx]}" 'del(.[$n])' "$palettes" > "$tmp" &&
            cat "$tmp" > "$palettes" &&
            notice="Palette \"$label\" deleted"
          rm -f "$tmp"
        fi
        continue
      fi
      [ "$status" -eq 0 ] || exit 0
      name=${names[$idx]}
      break
    done
  fi

  [ -n "$name" ] || exit 0
  jq -e --arg n "$name" 'has($n)' "$palettes" >/dev/null || { echo "no scheme '$name'" >&2; exit 1; }

mkdir -p "$out"
jq -r --arg n "$name" '.[$n] | to_entries[] | "set $\(.key) \(.value)"' \
  "$palettes" > "$out/i3"
jq -r --arg n "$name" '.[$n] | to_entries[] | "\(.key)=\(.value)"' \
  "$palettes" > "$out/colors.sh"
echo "$name" > "$out/current"
# Ghostty: palette names are Ghostty theme names, plus the palette's own
# background, foreground and ANSI accents (normal 1-6 and bright 9-14) on top,
# so programs using named terminal colours (starship, ls, git) match the
# palette even when the Ghostty theme differs or doesn't exist.
{ printf 'theme = %s\n' "$name"
  jq -r --arg n "$name" '.[$n]
    | "background = \(.bg0)", "foreground = \(.fg0)",
      ([.red, .green, .yellow, .blue, .purple, .aqua] | to_entries[]
        | "palette = \(.key + 1)=\(.value)", "palette = \(.key + 9)=\(.value)")' \
    "$palettes"; } > "$out/ghostty"

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
  # Wallpaper border colour follows bg0
  command -v wallpaper-rotate >/dev/null && wallpaper-rotate refresh >/dev/null 2>&1 &
fi
