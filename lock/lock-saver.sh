#!/usr/bin/env bash
set -euo pipefail

# xsecurelock saver module: plays the wallpaper clip made by wallpaper-rotate
# through the ASCII shader. xsecurelock starts one copy per monitor and passes
# the window to draw into as $XSCREENSAVER_WINDOW.
# Packaged by home/base.nix as `lock-saver`. The shader is read live from the
# repo, so edits to ascii.glsl apply on the next lock without a rebuild.

cache="${XDG_CACHE_HOME:-$HOME/.cache}/lock"
bg0=$(sed -n 's/^bg0=//p' "$HOME/.config/colors/colors.sh" 2>/dev/null || true)

# --video-unscaled centres the image at 1:1, matching `feh --bg-center`
exec mpv --no-config --really-quiet --no-audio --no-osc --osd-level=0 \
  --no-input-default-bindings --input-vo-keyboard=no --input-cursor=no \
  --wid="$XSCREENSAVER_WINDOW" --loop-file=inf --video-unscaled=yes \
  --background=color --background-color="${bg0:-#000000}" \
  --glsl-shader="$HOME/dotfiles-nixos/configs/lock/ascii.glsl" \
  "$cache/loop.mkv"
