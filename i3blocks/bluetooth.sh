#!/usr/bin/env bash
# i3blocks bluetooth (interval=persist, markup=pango): nerd font icon, plus
# the device name while one is connected. The icon is tinted by the connected
# device's battery level (red / orange / yellow / green from the theme) and
# dimmed when the adapter is powered off. Click opens blueman-manager.
#
# Stays running and reprints whenever BlueZ signals a change (connect,
# disconnect, power, battery level), so the block never polls.

icon=$'\xef\x8a\x93' # nf-fa-bluetooth (U+F293)

update() {
  local show dev mac name bat color t
  . ~/.config/colors/colors.sh # re-read each time so a theme switch is picked up

  show=$(timeout 2 bluetoothctl show 2>/dev/null)
  if ! echo "$show" | grep -q '^Controller'; then
    t= # no adapter: empty line hides the block
  elif ! echo "$show" | grep -q 'Powered: yes'; then
    t="<span color=\"${grey0:-#777777}\">$icon</span>"
  else
    # "Device XX:XX:XX:XX:XX:XX Name With Spaces" -> first connected device
    dev=$(timeout 2 bluetoothctl devices Connected 2>/dev/null | grep -m1 '^Device')
    mac=$(echo "$dev" | awk '{print $2}')
    name=$(echo "$dev" | cut -d' ' -f3-)

    color=
    if [ -n "$mac" ]; then
      # "Battery Percentage: 0x0a (10)" -> 10; absent on devices that don't report it
      bat=$(timeout 2 bluetoothctl info "$mac" 2>/dev/null | sed -n 's/.*Battery Percentage:.*(\([0-9]*\)).*/\1/p')
      if [ -n "$bat" ]; then
        if [ "$bat" -le 20 ]; then
          color=$red
        elif [ "$bat" -le 40 ]; then
          color=$orange
        elif [ "$bat" -le 60 ]; then
          color=$yellow
        else
          color=$green
        fi
      fi
    fi

    t="$icon"
    [ -n "$color" ] && t="<span color=\"$color\">$icon</span>"
    if [ -n "$name" ]; then
      # escape the name for pango markup
      name=${name//&/&amp;}
      name=${name//</&lt;}
      name=${name//>/&gt;}
      t="$t $name"
    fi
  fi

  if [ "$t" != "$last" ]; then
    echo "$t"
    last=$t
  fi
}
last=unset

# One stream of "evt" (BlueZ changed something) and "click N" (i3blocks
# writes the mouse button to our stdin) lines.
exec 3<&0
events() {
  while read -r b <&3; do echo "click $b"; done &
  local reader=$!
  dbus-monitor --system "type='signal',sender='org.bluez'" 2>/dev/null |
    grep --line-buffered '^signal' | sed -u 's/.*/evt/'
  kill "$reader" 2>/dev/null # monitor died: end the stream so the caller reattaches
}

while :; do
  update
  while :; do
    # the 60s timeout is only a safety net in case an event is missed
    if read -r -t 60 kind arg; then
      if [ "$kind" = click ] && [ "$arg" = 1 ]; then
        blueman-manager >/dev/null 2>&1 &
      fi
      # swallow the rest of the burst so one change means one refresh
      while read -r -t 0.2 kind arg; do :; done
    elif [ $? -le 128 ]; then
      break # event stream ended (bluetooth service restarting): reattach
    fi
    update
  done < <(events)
  sleep 2
done
