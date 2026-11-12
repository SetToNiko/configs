#!/usr/bin/env bash

# Pick an editor or IDE in rofi and open the dir in it
#

dir=$1
#
# Start the program detached from yazi, then close yazi
launch() { setsid -f "$@" >/dev/null 2>&1; ya emit quit; }

[ -d "$dir" ] || exit 0

# label | command | "term" if it runs in a terminal
editors=(
  "Neovim|nvim|term"
  "IntelliJ IDEA|idea|"
  "IntelliJ IDEA Community|idea-community|"
  "Android Studio|android-studio|"
  "VS Code|code|"
)

# Menu: only the ones that are installed
declare -A cmds terms
menu=""
for entry in "${editors[@]}"; do
  IFS='|' read -r label cmd term <<< "$entry"
  command -v "$cmd" >/dev/null || continue
  cmds[$label]=$cmd
  terms[$label]=$term
  menu+="$label"$'\n'
done


choice=$(printf '%s' "$menu" | rofi -dmenu -i -p "Open $(basename "$dir") in") || exit 0
cmd=${cmds[$choice]}
[ -n "$cmd" ] || exit 0

if [ -n "${terms[$choice]}" ]; then
  # Terminal editors: new Ghostty window, started inside the directory
  launch ghostty --working-directory="$dir" -e "$cmd" .
else
  launch "$cmd" "$dir"
fi
