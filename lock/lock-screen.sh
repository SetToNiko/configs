#!/usr/bin/env bash
set -euo pipefail

# Lock the screen with xsecurelock: the ASCII wallpaper saver (lock-saver) and
# a minimal password prompt in the current colour scheme.
# Packaged by home/base.nix as `lock-screen`; xss-lock runs it (configs/i3/config),
# so lock with `loginctl lock-session` rather than calling this directly.

color() { sed -n "s/^$1=//p" "$HOME/.config/colors/colors.sh" 2>/dev/null || true; }

XSECURELOCK_SAVER=$(command -v lock-saver)
bg=$(color bg0)
fg=$(color fg0)
warn=$(color red)
export XSECURELOCK_SAVER

# picom paints into the composite overlay window too; sharing it makes the
# lock flicker against xsecurelock's "incompatible compositor" obscurer
export XSECURELOCK_NO_COMPOSITE=1
export XSECURELOCK_AUTH_BACKGROUND_COLOR="${bg:-#000000}"
export XSECURELOCK_AUTH_FOREGROUND_COLOR="${fg:-#ffffff}"
export XSECURELOCK_AUTH_WARNING_COLOR="${warn:-#ff0000}"

# Minimal prompt: a clock and the password field, nothing else
export XSECURELOCK_SHOW_USERNAME=0
export XSECURELOCK_SHOW_HOSTNAME=0
export XSECURELOCK_SHOW_KEYBOARD_LAYOUT=0
export XSECURELOCK_SHOW_DATETIME=1
export XSECURELOCK_DATETIME_FORMAT='%H:%M'
export XSECURELOCK_PASSWORD_PROMPT=asterisks
export XSECURELOCK_FONT='GeistMono Nerd Font:size=14'

exec xsecurelock
