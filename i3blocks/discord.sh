#!/usr/bin/env bash
# i3blocks discord (interval=persist): nerd font icon plus the server
# currently open ("@name" in a DM). Prints an empty line when Discord isn't
# running so the block is hidden. Click focuses the Discord window (reopens
# it if closed).
#
# Stays running and reprints whenever i3 reports that the Discord window
# changed title, opened or closed, so the block never polls for the name.

icon=$'\xf3\xb0\x99\xaf' # nf-md-discord (U+F066F)

running() {
  # the nix build runs as ".Discord-wrapped"; other installs as "Discord"
  pgrep -f '[D]iscord-wrapped' >/dev/null || pgrep -x Discord >/dev/null
}

# window title looks like "#channel | Server - Discord" or "@name - Discord"
title() {
  i3-msg -t get_tree 2>/dev/null |
    jq -r 'first(.. | objects | select(.window_properties?.class == "discord") | .name) // empty'
}

last=unset
update() {
  local where t
  if running; then
    where=$(title)
    where=${where% - Discord}
    where=$(printf '%s' "$where" | sed -E 's/^(\([0-9]+\)|[•●]) *//') # unread markers
    case "$where" in
      *' | '*) where=${where##* | } ;;  # "#channel | Server" -> "Server"
      Discord | Friends | "") where= ;; # no server or DM open
    esac
    t="$icon"
    [ -n "$where" ] && t="$icon $where"
  else
    t= # empty line hides the block
  fi
  if [ "$t" != "$last" ]; then
    echo "$t"
    last=$t
  fi
}

click() {
  [ "$1" = 1 ] || return
  running || return
  if [ -n "$(title)" ]; then
    i3-msg '[class="discord"] focus' >/dev/null 2>&1
  else
    discord >/dev/null 2>&1 & # window closed: launching again reopens it
  fi
}

# One stream of "evt" (the Discord window changed) and "click N" (i3blocks
# writes the mouse button to our stdin) lines.
exec 3<&0
events() {
  while read -r b <&3; do echo "click $b"; done &
  local reader=$!
  i3-msg -t subscribe -m '["window"]' 2>/dev/null |
    jq --unbuffered -r 'select(.container.window_properties.class == "discord"
      and (.change == "title" or .change == "new" or .change == "close")) | "evt"'
  kill "$reader" 2>/dev/null # subscription ended: end the stream so the caller reattaches
}

while :; do
  update
  while :; do
    # the 30s timeout only catches Discord quitting with no window open
    if read -r -t 30 kind arg; then
      [ "$kind" = click ] && click "$arg"
      [ "$kind" = evt ] && sleep 0.1 # let i3's tree catch up with the event
    elif [ $? -le 128 ]; then
      break # event stream ended (i3 restarting): reattach
    fi
    update
  done < <(events)
  sleep 2
done
