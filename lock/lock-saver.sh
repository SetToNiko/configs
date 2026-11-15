#!/usr/bin/env bash
set -euo pipefail

# xsecurelock saver module: plays the wallpaper clip made by wallpaper-rotate
# through the ASCII shader. xsecurelock starts one copy per monitor and passes
# the window to draw into as $XSCREENSAVER_WINDOW; run by hand without it, mpv
# opens its own window, which is handy for previewing shader edits.
# The image is revealed over $LOCK_REVEAL seconds (set by lock-screen.sh), and
# again over 2 seconds after each wake from suspend: xss-lock locks *before*
# the machine sleeps, so without the replay the reveal would play to a
# darkening screen and be over by the time you see it.
# With $LOCK_DISSOLVE set (by ascii-power, before a shutdown or reboot) it
# instead shows the desktop's full-colour ASCII still and breaks it apart over
# that many seconds.
# Packaged by home/base.nix as `lock-saver`. The shader is read live from the
# repo, so edits to ascii.glsl apply on the next lock without a rebuild.

cache="${XDG_CACHE_HOME:-$HOME/.cache}/lock"
colors="$HOME/.config/colors/colors.sh"
color() { sed -n "s/^$1=//p" "$colors" 2>/dev/null || true; }

# "#rrggbb" -> "vec3(r, g, b)" with 0-1 components
vec3() {
  local h=${1#\#}
  printf 'vec3(%d.0/255.0, %d.0/255.0, %d.0/255.0)' "0x${h:0:2}" "0x${h:2:2}" "0x${h:4:2}"
}

# Theme palette for the shader: the accents, the greys and the foreground, so
# every glyph is a theme colour. Left empty if colors.sh is missing, and the
# shader falls back to greys.
palette=()
for name in red orange yellow green aqua blue purple grey0 grey1 grey2 fg0; do
  hex=$(color "$name")
  [[ $hex =~ ^#[0-9a-fA-F]{6}$ ]] && palette+=("$(vec3 "$hex")")
done
fg=$(color fg0)
defs=""
if [ "${#palette[@]}" -gt 0 ] && [[ $fg =~ ^#[0-9a-fA-F]{6}$ ]]; then
  list=$(IFS=,; echo "${palette[*]}")
  defs="#define THEME_N ${#palette[@]}\n#define THEME_FG $(vec3 "$fg")\nconst vec3 THEME[THEME_N] = vec3[]($list);\n"
fi
# shader_for <name> <defines>: copy of ascii.glsl saved as ascii-<name>.glsl,
# with the palette and the mode's defines ("\n"-separated) in place of its
# "// THEME" line. One copy per monitor runs this; mv keeps the write atomic.
shader_for() {
  local out="$cache/ascii-$1.glsl" tmp
  tmp=$(mktemp "$cache/ascii.XXXXXX")
  sed "s|^// THEME\$|${defs}$2|" \
    "$HOME/dotfiles-nixos/configs/lock/ascii.glsl" > "$tmp"
  mv -f "$tmp" "$out"
  echo "$out"
}

bg0=$(color bg0)
mpv_pid=""
watch_pid=""
# play <name> <defines>: start mpv in the background with that shader
play() {
  local shader
  shader=$(shader_for "$1" "$2")
  # --video-unscaled centres the image at 1:1, matching `feh --bg-center`
  mpv --no-config --really-quiet --no-audio --no-osc --osd-level=0 \
    --no-input-default-bindings --input-vo-keyboard=no --input-cursor=no \
    ${XSCREENSAVER_WINDOW:+--wid="$XSCREENSAVER_WINDOW"} \
    --loop-file=inf --video-unscaled=yes \
    --background=color --background-color="${bg0:-#000000}" \
    --glsl-shader="$shader" \
    "$cache/loop.mkv" &
  mpv_pid=$!
}
reveal() { play "$1" "#define REVEAL $1.0"; }
stop() { [ -n "$mpv_pid" ] && { kill "$mpv_pid" 2>/dev/null; wait "$mpv_pid" 2>/dev/null; } || true; }

# xsecurelock ends the saver with SIGTERM; take mpv and the watcher down too
cleanup() {
  stop
  [ -n "$watch_pid" ] && kill "$watch_pid" 2>/dev/null || true
}
trap 'cleanup; exit 0' TERM INT HUP
trap cleanup EXIT

# Shutdown dissolve: no reveal, no wake handling
if [ -n "${LOCK_DISSOLVE:-}" ]; then
  play dissolve "#define WALLPAPER\n#define DISSOLVE $LOCK_DISSOLVE"
  wait "$mpv_pid"
  exit
fi

reveal "${LOCK_REVEAL:-4}"

# logind announces PrepareForSleep(false) on resume: restart with the quick reveal
if command -v gdbus >/dev/null; then
  coproc WATCH { exec gdbus monitor --system --dest org.freedesktop.login1 \
    --object-path /org/freedesktop/login1 2>/dev/null; }
  watch_pid=$WATCH_PID   # bash clears WATCH and WATCH_PID early; keep copies
  exec {watch_fd}<&"${WATCH[0]}"
  while IFS= read -r line <&"$watch_fd"; do
    case $line in
      *"PrepareForSleep (false"*) stop; reveal 2 ;;
    esac
  done
fi
wait "$mpv_pid"
