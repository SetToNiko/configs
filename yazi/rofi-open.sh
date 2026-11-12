#!/usr/bin/env bash

# Show the apps that can open the selected file's type in rofi, then open the file(s) with chosen app
mime=$(xdg-mime query filetype "$1")

# Start the program detached from yazi, then close yazi
launch() { setsid -f "$@" >/dev/null 2>&1; ya emit quit; }

# Find a .desktop file by its ID in the XDG data dirs
find_desktop(){
    local dir
    IFS=: read -ra dirs <<< "${XDG_DATA_HOME:-$HOME/.local/share}:${XDG_DATA_DIRS:-/usr/share}"
    for dir in "${dirs[@]}"; do
        [ -f "$dir/applications/$1" ] && { echo "$dir/applications/$1"; return; }
    done
}

# Build the menu: app display name -> .desktop path
  declare -A paths
  menu=""
  while read -r id; do
    path=$(find_desktop "$id")
    [ -n "$path" ] || continue
    name=$(grep -m1 '^Name=' "$path" | cut -d= -f2-)
    [ -n "${paths[$name]}" ] && continue
    paths[$name]=$path
    menu+="$name"$'\n'
  done < <(gio mime "$mime" 2>/dev/null | sed -n 's/^\t//p' | awk '!seen[$0]++')

  # No apps registered for this type: fall back to every command on PATH
  if [ -z "$menu" ]; then
    app=$(compgen -c | sort -u | rofi -dmenu -i -p "Open with") || exit 0
    [ -n "$app" ] && launch "$app" "$@"
    exit 0
  fi

  choice=$(printf '%s' "$menu" | rofi -dmenu -i -p "Open with ($mime)") || exit 0
  path=${paths[$choice]}
  [ -n "$path" ] || exit 0

  if grep -q '^Terminal=true' "$path"; then
    # Terminal apps (e.g. nvim): run them in a new Ghostty window
    cmd=$(grep -m1 '^Exec=' "$path" | cut -d= -f2- | sed 's/ %[fFuUick]//g')
    launch ghostty -e $cmd "$@"
  else
    launch gio launch "$path" "$@"
  fi
