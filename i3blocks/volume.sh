#!/usr/bin/env bash
# i3blocks volume (interval=persist): "vol 50%" or "vol muted".
# Stays running and prints a new line whenever PipeWire reports a change
# (volume keys, headset buttons, another app, default output switching),
# so the block never polls.

vol() {
  wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null |
    awk '{ if (/MUTED/) print "vol muted"; else printf "vol %d%%\n", $2*100 }'
}

last=
update() {
  local now
  now=$(vol)
  if [ -n "$now" ] && [ "$now" != "$last" ]; then
    echo "$now"
    last=$now
  fi
}

while :; do
  update
  # pw-mon prints an event block for every change in the PipeWire graph
  while read -r _; do
    # swallow the rest of the burst so one change means one wpctl call
    while read -r -t 0.1 _; do :; done
    update
  done < <(pw-mon -N 2>/dev/null | grep --line-buffered -E '^(changed|added|removed):')
  sleep 2 # pipewire went away (restart): wait, then reattach
done
