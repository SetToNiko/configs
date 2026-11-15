#!/usr/bin/env bash
set -euo pipefail

# Prepare the next boot's animation from the current desktop: the ASCII still
# that the shutdown dissolve breaks apart is put back together, character by
# character, while the machine boots (Plymouth, see modules/ascii-boot.nix),
# then stays up as the LightDM greeter's background.
# ascii-power runs this during the dissolve; run it by hand to refresh the
# frames after changing the settings below.
# Packaged by home/base.nix as `ascii-boot`.

seconds=4.5   # until the whole image is shown; Plymouth has ~5 s after switch-root
fade=0.8      # seconds each character takes to fade in
fps=12        # keep in step with FPS in modules/ascii-boot.script

still="${XDG_CACHE_HOME:-$HOME/.cache}/lock/still.png"
out=/var/lib/ascii-boot   # created by modules/ascii-boot.nix, readable by plymouth and lightdm

[ -s "$still" ] || { echo "no ASCII still at $still (run wallpaper-rotate)" >&2; exit 1; }
[ -w "$out" ] || { echo "$out is missing or not writable (rebuild first)" >&2; exit 1; }

bg=$(sed -n 's/^bg0=//p' "$HOME/.config/colors/colors.sh" 2>/dev/null || true)
[[ $bg =~ ^#[0-9a-fA-F]{6}$ ]] || bg="#000000"

# Size of the primary monitor (the one the greeter draws on), else the first
screen=$(xrandr --listactivemonitors 2>/dev/null |
  sed -nE 's/^ *[0-9]+: \+(\*?)[^ ]* ([0-9]+)\/[0-9]+x([0-9]+)\/.*/\1 \2x\3/p' |
  sort -r | head -n1 | sed 's/^\** *//')
[ -n "$screen" ] || screen=2560x1600

exec python3 -I "$HOME/dotfiles-nixos/configs/lock/ascii-boot.py" "$still" "$out" \
  --seconds "$seconds" --fade "$fade" --fps "$fps" --bg "$bg" --screen "$screen"
