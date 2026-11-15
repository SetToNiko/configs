#!/usr/bin/env bash
set -euo pipefail

# Pick a random wallpaper, render it as a still through the ASCII shader and set
# that centred on every monitor, and pre-render the clip the lock screen plays
# (see lock-saver.sh and ascii.glsl).
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

  # Every wallpaper at the same square size (that of contradictions_collapse):
  # scaled to cover it, then centre-cropped
  ffmpeg -nostdin -loglevel error -y -i "$img" \
    -vf 'scale=500:500:force_original_aspect_ratio=increase:flags=lanczos,crop=500:500' \
    -frames:v 1 "$cache/source.png"

  # Two seconds of the still image as video. mpv loops it on the lock screen,
  # and the shader is animated by mpv's frame counter, which needs real frames.
  ffmpeg -nostdin -loglevel error -y -loop 1 -framerate 30 -i "$cache/source.png" -t 2 \
    -vf 'format=yuv420p' \
    -c:v libx264 -preset veryfast -tune stillimage -crf 16 "$cache/loop.tmp.mkv"
  mv -f "$cache/loop.tmp.mkv" "$cache/loop.mkv"
  printf '%s\n' "$img" > "$cache/wallpaper"
fi

# Desktop background: one frame of the image through ascii.glsl in WALLPAPER
# mode (full colour, no twinkle, characters on black). mpv needs a window to
# run shaders, so it runs in a throwaway virtual X server with software
# rendering, where nothing shows on screen. Redone when the image changes or
# the shader is newer than the still. If it fails, the plain image is used
# instead.
src="$cache/source.png"
[ -s "$src" ] || src=$img   # older cache without the resized copy
shader="$HOME/dotfiles-nixos/configs/lock/ascii.glsl"
still="$cache/still.png"
if [ "$img" != "$current" ] || [ ! -s "$still" ] || [ "$shader" -nt "$still" ]; then
  sed "s|^// THEME\$|#define WALLPAPER|" "$shader" > "$cache/wallpaper.glsl"
  rm -f "$cache/still.tmp.png"
  LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a -s "-screen 0 640x480x24" \
    mpv --no-config --really-quiet --pause --no-audio \
      --vo=gpu-next --gpu-api=opengl --gpu-context=x11egl --gpu-sw=yes \
      --screenshot-sw=no --screenshot-format=png \
      --glsl-shader="$cache/wallpaper.glsl" \
      --script="$HOME/dotfiles-nixos/configs/lock/snapshot.lua" \
      --script-opts=snapshot-out="$cache/still.tmp.png" \
      "$src" </dev/null || true
  if [ -s "$cache/still.tmp.png" ]; then
    mv -f "$cache/still.tmp.png" "$still"
  else
    echo "ascii render failed; using the plain image" >&2
    rm -f "$still"
  fi
fi
bg_img=$img
[ -s "$still" ] && bg_img=$still

# The border around the centred image uses the colour scheme's background
bg0=$(sed -n 's/^bg0=//p' "$HOME/.config/colors/colors.sh" 2>/dev/null || true)
feh --no-fehbg --bg-center --image-bg "${bg0:-#000000}" "$bg_img"
