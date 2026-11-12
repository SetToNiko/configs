  #!/usr/bin/env bash
  # i3blocks battery: "bat 61%", "+" while charging, red at 15% or less.
  . ~/.config/colors/colors.sh
  bat=/sys/class/power_supply/BAT0
  c=$(cat "$bat/capacity")
  s=$(cat "$bat/status")

  t="bat $c%"
  [ "$s" = Charging ] && t="$t+"
  echo "$t"
  echo "$t"
  if [ "$c" -le 15 ] && [ "$s" != Charging ]; then
    echo "$red_lit"
  fi
  exit 0
