#!/usr/bin/env bash
set -euo pipefail

# Shut down or reboot with the desktop's ASCII wallpaper breaking apart first.
#   ascii-power poweroff | reboot    no argument: rofi menu ($mod+Shift+p in i3)
#   ascii-power preview              play the dissolve, then give the screen back
# xsecurelock covers every monitor and runs lock-saver in dissolve mode (see
# lock-saver.sh and the DISSOLVE part of ascii.glsl); once the dissolve has
# played, systemd takes over and Plymouth keeps the screen blank until power-off.
# Meanwhile ascii-boot renders the same image fading back in, for the next boot.
# Packaged by home/base.nix as `ascii-power`.

seconds=4.0   # dissolve length; keep a decimal point (the shader needs a float)

action=${1:-}
if [ -z "$action" ]; then
  choice=$(printf 'Shut down\nReboot\n' | rofi -dmenu -i -p "Power") || exit 0
  case $choice in
    "Shut down") action=poweroff ;;
    Reboot) action=reboot ;;
    *) exit 0 ;;
  esac
fi
case $action in
  poweroff | reboot | preview) ;;
  *) echo "usage: ascii-power [poweroff|reboot|preview]" >&2; exit 2 ;;
esac

# Run xsecurelock just for its full-screen windows: lock-saver draws the
# dissolve, and the 500 ms saver delay lets mpv show the image before the
# windows appear, so there's no black flash first. Same picom fix as
# lock-screen.sh.
XSECURELOCK_SAVER=$(command -v lock-saver)
export XSECURELOCK_SAVER
export LOCK_DISSOLVE=$seconds
export XSECURELOCK_NO_COMPOSITE=1
export XSECURELOCK_SAVER_DELAY_MS=500
xsecurelock &
lock_pid=$!

# Next boot's animation (ascii-boot.sh), rendered while the dissolve plays
boot_pid=""
if command -v ascii-boot >/dev/null; then
  nice ascii-boot &
  boot_pid=$!
fi

sleep 0.5            # saver delay
sleep "$seconds"     # the dissolve
sleep 0.15           # a beat on the empty screen
if [ -n "$boot_pid" ] && ! wait "$boot_pid"; then
  echo "ascii-boot failed; the next boot reuses the last frames" >&2
fi

if [ "$action" = preview ]; then
  kill "$lock_pid" 2>/dev/null || true   # SIGTERM closes xsecurelock
  exit 0
fi

if ! systemctl "$action"; then
  # Blocked (e.g. an inhibitor): take the cover down rather than leave a dead screen
  kill "$lock_pid" 2>/dev/null || true
  echo "systemctl $action failed" >&2
  exit 1
fi
