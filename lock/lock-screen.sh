#!/usr/bin/env bash
set -euo pipefail

# Lock the screen with xsecurelock: the ASCII wallpaper saver (lock-saver) and
# a bare password box in the current colour scheme.
# Packaged by home/base.nix as `lock-screen`; xss-lock runs it (configs/i3/config),
# so lock with `loginctl lock-session` rather than calling this directly.

color() { sed -n "s/^$1=//p" "$HOME/.config/colors/colors.sh" 2>/dev/null || true; }

XSECURELOCK_SAVER=$(command -v lock-saver)
bg=$(color bg0)
fg=$(color fg0)
warn=$(color red)
accent=$(color yellow)   # i3 focused border, rofi border
numlock=$(color blue)   # i3 binding-mode indicator
export XSECURELOCK_SAVER

# Reveal time for the ASCII image, in seconds: the first lock since login gets
# the slow reveal, later locks the quick one (lock-saver also replays the quick
# one on wake from suspend). The marker lives in /run/user, cleared on logout.
first="${XDG_RUNTIME_DIR:-/tmp}/lock-screen-shown"
if [ -e "$first" ]; then
  LOCK_REVEAL=2
else
  LOCK_REVEAL=2
  : > "$first"
fi
export LOCK_REVEAL

# picom paints into the composite overlay window too; sharing it makes the
# lock flicker against xsecurelock's "incompatible compositor" obscurer
export XSECURELOCK_NO_COMPOSITE=1
export XSECURELOCK_AUTH_BACKGROUND_COLOR="${bg:-#000000}"
export XSECURELOCK_AUTH_FOREGROUND_COLOR="${fg:-#ffffff}"
export XSECURELOCK_AUTH_WARNING_COLOR="${warn:-#ff0000}"

# The prompt is only the password box (xsecurelock is patched for this, see
# home/xsecurelock-password-box.patch): outlined in the accent colour, or in a
# contrasting one while Num Lock is on, at the bottom of each monitor.
export XSECURELOCK_AUTH_BORDER_COLOR="${accent:-#ffffff}"
export XSECURELOCK_AUTH_NUMLOCK_BORDER_COLOR="${numlock:-#00ffff}"
export XSECURELOCK_AUTH_BOTTOM_MARGIN=80
export XSECURELOCK_BURNIN_MITIGATION=0   # don't jitter it off-centre
export XSECURELOCK_SHOW_USERNAME=0
export XSECURELOCK_SHOW_HOSTNAME=0
export XSECURELOCK_SHOW_KEYBOARD_LAYOUT=0
export XSECURELOCK_SHOW_DATETIME=0
export XSECURELOCK_PASSWORD_PROMPT=asterisks
# Font from the font preset (font-switch.sh), GeistMono until one is set
export XSECURELOCK_FONT='GeistMono Nerd Font:size=14'
if [ -f "$HOME/.config/fonts/lock.sh" ]; then . "$HOME/.config/fonts/lock.sh"; fi
# Keep the box up while locked instead of closing it after 5 idle minutes
export XSECURELOCK_AUTH_TIMEOUT=86400

# Open the box once the reveal has played (any key opens it sooner):
# xsecurelock shows it on SIGUSR2. This shell's PID becomes xsecurelock's at
# the exec below, so wait until it has a SIGUSR2 handler (bit 12 of SigCgt) -
# before then the signal would kill it and unlock the screen. The saver starts
# at about that point, so the reveal ends $LOCK_REVEAL seconds later (plus a
# little for mpv to load). If the box is already open the signal does nothing.
lock_pid=$$
(
  # don't hold xss-lock's suspend inhibitor open
  if [ -n "${XSS_SLEEP_LOCK_FD:-}" ]; then exec {XSS_SLEEP_LOCK_FD}<&-; fi
  ready() {
    local caught
    [ "$(cat "/proc/$lock_pid/comm" 2>/dev/null)" = xsecurelock ] || return 1
    caught=$(sed -n 's/^SigCgt:\s*//p' "/proc/$lock_pid/status" 2>/dev/null)
    [ -n "$caught" ] && (( 0x$caught & 0x800 ))
  }
  for _ in {1..100}; do
    ready && break
    sleep 0.05
  done
  ready || exit 0
  sleep "$LOCK_REVEAL" 0.3
  # still locked (xsecurelock exits on unlock)
  ready && kill -USR2 "$lock_pid"
) &

exec xsecurelock
