#!/usr/bin/env bash
# i3blocks bluetooth: nerd font icon, plus the device name while one is
# connected. Dimmed when the adapter is powered off. Click opens blueman-manager.
. ~/.config/colors/colors.sh

case "${button:-$BLOCK_BUTTON}" in
  1) blueman-manager >/dev/null 2>&1 & ;;
esac

show=$(timeout 2 bluetoothctl show 2>/dev/null)
echo "$show" | grep -q '^Controller' || exit 0 # no adapter: print nothing so the block is hidden

icon=$'\xef\x8a\x93' # nf-fa-bluetooth (U+F293)

if ! echo "$show" | grep -q 'Powered: yes'; then
  echo "$icon"
  echo "$icon"
  echo "${grey0:-#777777}"
  exit 0
fi

# "Device XX:XX:XX:XX:XX:XX Name With Spaces" -> first connected device's name
dev=$(timeout 2 bluetoothctl devices Connected 2>/dev/null | awk '/^Device/ { $1=$2=""; sub(/^ +/, ""); print; exit }')

t="$icon"
[ -n "$dev" ] && t="$icon $dev"
echo "$t"
echo "$t"
exit 0
