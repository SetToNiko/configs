#!/usr/bin/env bash
set -euo pipefail

# Pick a random wallpaper, set it centred on every monitor, and pre-render the
# clip the lock screen plays (see lock-saver.sh and ascii.glsl).
# Packaged by home/base.nix as `wallpaper-rotate`; a systemd timer runs it.
#   wallpaper-rotate          switch to a new random wallpaper
#   wallpaper-rotate refresh  re-apply the current one (after a monitor or theme change)

dir="${WALLPAPER_DIR:-$HOME/dotfiles-nixos/wallpaper}"
cache="${XDG_CACHE_HOME:-$HOME/.cache}/lock"
mkdir -p "$cache"

# i3 startup and the autorandr hook can both run this at login
exec 9>"$cache/.lock"
flock 9

current=$(cat "$cache/wallpaper" 2>/dev/null || true)
img=$current

if [ "${1:-}" != refresh ] || [ ! -f "$current" ]; then
  mapfile -t images < <(find -L "$dir" -maxdepth 1 -type f \
    \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) | sort)
  if [ "${#images[@]}" -eq 0 ]; then
    echo "no images in $dir" >&2
    exit 1
  fi
  # Don't show the same wallpaper twice in a row when there's a choice
  if [ "${#images[@]}" -gt 1 ]; then
    mapfile -t images < <(printf '%s\n' "${images[@]}" | grep -vxF -- "$current")
  fi
  img=${images[RANDOM % ${#images[@]}]}

  # Two seconds of the still image as video. mpv loops it on the lock screen,
  # and the shader is animated by mpv's frame counter, which needs real frames.
  ffmpeg -nostdin -loglevel error -y -loop 1 -framerate 30 -i "$img" -t 2 \
    -vf 'scale=trunc(iw/2)*2:trunc(ih/2)*2,format=yuv420p' \
    -c:v libx264 -preset veryfast -tune stillimage -crf 16 "$cache/loop.tmp.mkv"
  mv -f "$cache/loop.tmp.mkv" "$cache/loop.mkv"
  printf '%s\n' "$img" > "$cache/wallpaper"
fi

# The border around the centred image uses the colour scheme's background
bg0=$(sed -n 's/^bg0=//p' "$HOME/.config/colors/colors.sh" 2>/dev/null || true)
feh --no-fehbg --bg-center --image-bg "${bg0:-#000000}" "$img"
