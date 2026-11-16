# Shared rofi menu for theme-switch.sh and font-switch.sh: pick a preset from
# a JSON object (one preset per key), or delete one with Alt+BackSpace.
# Source this file, then:
#
#   name=$(json_picker FILE PROMPT ROWS_JQ CURRENT RED NOUN) || exit 0
#
#   FILE     JSON file holding the presets
#   PROMPT   rofi prompt
#   ROWS_JQ  jq program printing one Pango-markup row per key, in file order;
#            it gets the active preset's name as $cur
#   CURRENT  active preset: highlighted, and can't be deleted
#   RED      colour of the delete message
#   NOUN     what a preset is called in messages ("Palette", "Font preset")
#
# Prints the chosen key; returns 1 if the menu was closed without choosing.

# Escape text for rofi's Pango markup
markup_escape() {
  printf '%s' "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'
}

json_picker() {
  local file=$1 prompt=$2 rows=$3 current=$4 red=$5 noun=$6
  local row=-1 notice= active i mesg idx status label tmp
  local -a names

  while :; do
    mapfile -t names < <(jq -r 'keys_unsorted[]' "$file")

    active=0
    for i in "${!names[@]}"; do
      [ "${names[$i]}" = "$current" ] && active=$i
    done
    # First time round, start on the active preset; after a delete, stay put
    [ "$row" -lt 0 ] && row=$active
    [ "$row" -ge "${#names[@]}" ] && row=$((${#names[@]} - 1))

    # Hint line, with the result of the last delete (if any) above it
    mesg="Enter: apply   Alt+BackSpace: delete from ${file##*/}"
    [ -n "$notice" ] && mesg="<span foreground=\"$red\"><b>$notice</b></span>"$'\n'"$mesg"
    notice=

    # Alt+BackSpace (kb-custom-1) deletes the highlighted preset; rofi exits with 10.
    idx=$(jq -r --arg cur "$current" "$rows" "$file" |
      rofi -dmenu -i -markup-rows -format i \
        -kb-custom-1 Alt+BackSpace -mesg "$mesg" \
        -selected-row "$row" -a "$active" -p "$prompt")
    status=$?

    if [ "$status" -eq 10 ] && [ -n "$idx" ]; then
      row=$idx
      label=$(markup_escape "${names[$idx]}")
      # Keep the active preset: activation falls back to a default without it
      if [ "${names[$idx]}" = "$current" ]; then
        notice="$noun \"$label\" is active and can't be deleted"
      else
        tmp=$(mktemp) &&
          jq --arg n "${names[$idx]}" 'del(.[$n])' "$file" > "$tmp" &&
          cat "$tmp" > "$file" &&
          notice="$noun \"$label\" deleted"
        rm -f "$tmp"
      fi
      continue
    fi
    [ "$status" -eq 0 ] || return 1
    printf '%s\n' "${names[$idx]}"
    return 0
  done
}
