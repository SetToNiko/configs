#!/usr/bin/env bash
# i3blocks keyboard (interval=persist): nerd font icon plus the active
# keyboard layout. Layouts come from services.xserver.xkb in
# modules/base.nix; Super+Space cycles through them.
#
# Left click opens a rofi menu to pick a layout; right click switches to the
# next one. Stays running and reprints whenever the layout changes
# (xkb-switch -W), so the block never polls.

icon=$'\xf3\xb0\x8c\x8c' # nf-md-keyboard (U+F030C)

# xkb layout -> bar label | menu entry (unknown layouts fall back to the code)
label() {
  case "$1" in
    us) echo EN ;;
    ca) echo FR ;;
    *) echo "${1^^}" ;;
  esac
}
name() {
  case "$1" in
    us) echo "English (US)" ;;
    ca) echo "Français (Canada)" ;;
    *) echo "$1" ;;
  esac
}

# "ca(multix)" -> "ca"
layout() { local l; l=$(xkb-switch -p 2>/dev/null); echo "${l%%(*}"; }

choose() {
  local l pick
  pick=$(for l in $(xkb-switch -l); do
    printf '%s\t%s\n' "$(name "${l%%(*}")" "$l"
  done | rofi -dmenu -i -p keyboard -display-columns 1 -display-column-separator $'\t') || return
  xkb-switch -s "${pick##*$'\t'}"
}

click() {
  case "$1" in
    1) choose & ;;
    3) xkb-switch -n ;;
  esac
}

last=
update() {
  local t
  t="$icon $(label "$(layout)")"
  if [ "$t" != "$last" ]; then
    echo "$t"
    last=$t
  fi
}

# One stream of "evt" (the layout changed) and "click N" (i3blocks writes the
# mouse button to our stdin) lines.
exec 3<&0
events() {
  while read -r b <&3; do echo "click $b"; done &
  local reader=$!
  xkb-switch -W 2>/dev/null | while read -r _; do echo evt; done
  kill "$reader" 2>/dev/null # watcher died (X keymap reloaded): reattach
}

while :; do
  update
  while read -r kind arg; do
    [ "$kind" = click ] && click "$arg"
    update
  done < <(events)
  sleep 1
done
