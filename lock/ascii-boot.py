# Boot animation frames: the reverse of the shutdown dissolve. Takes the
# desktop's ASCII still (made by wallpaper-rotate) and writes frames in which
# its characters fade in one by one, in random order, for Plymouth to play
# (modules/ascii-boot.nix), plus the finished image at screen size for the
# LightDM greeter. Run by ascii-boot.sh; see there for the arguments.

import argparse
import os
import shutil
import tempfile

import numpy as np
from PIL import Image

CELL = 12      # character cell in pixels: CELL in ascii.glsl
CLUMP = 4      # patches of up to this many cells tend to arrive together (R_CLUMP)

p = argparse.ArgumentParser()
p.add_argument("still")
p.add_argument("out")
p.add_argument("--seconds", type=float, required=True)  # until the image is complete
p.add_argument("--fade", type=float, required=True)     # seconds each character fades in
p.add_argument("--fps", type=int, required=True)        # FPS in modules/ascii-boot.script
p.add_argument("--bg", required=True)                   # "#rrggbb" around the image
p.add_argument("--screen", required=True)               # "WxH" of the greeter image
a = p.parse_args()

still = np.asarray(Image.open(a.still).convert("RGB"))
h, w = still.shape[:2]
ch, cw = -(-h // CELL), -(-w // CELL)
rng = np.random.default_rng()

# Random order, half per cell and half per patch of cells, as in the dissolve.
# Ranking spreads the start times evenly, so characters arrive at a steady pace.
noise = rng.random((ch, cw)) + np.kron(
    rng.random((-(-ch // CLUMP), -(-cw // CLUMP))), np.ones((CLUMP, CLUMP))
)[:ch, :cw]
order = noise.ravel().argsort().argsort().reshape(ch, cw) / max(ch * cw - 1, 1)
start = order * max(a.seconds - a.fade, 0.0)

tmp = tempfile.mkdtemp(dir=a.out, prefix=".new-")
frames = int(np.ceil(a.seconds * a.fps))
for k in range(frames + 1):
    t = np.clip((k / a.fps - start) / max(a.fade, 1e-6), 0.0, 1.0)
    t = t * t * (3 - 2 * t)  # ease in and out
    alpha = np.repeat(np.repeat(t, CELL, 0), CELL, 1)[:h, :w, None]
    Image.fromarray((still * alpha).astype(np.uint8)).save(
        f"{tmp}/frame-{k}.png", compress_level=1
    )

bg = tuple(int(a.bg.lstrip("#")[i : i + 2], 16) for i in (0, 2, 4))
Image.new("RGB", (1, 1), bg).save(f"{tmp}/bg.png")

# Greeter background: the finished image centred on a screen-sized canvas,
# like feh --bg-center, so it lines up with the desktop and the last frame
sw, sh = map(int, a.screen.split("x"))
canvas = Image.new("RGB", (sw, sh), bg)
canvas.paste(Image.fromarray(still), ((sw - w) // 2, (sh - h) // 2))
canvas.save(f"{tmp}/greeter.png", compress_level=1)

# Swap the new set in: drop the old frames (there may have been more), then
# move each new file into place
for name in os.listdir(a.out):
    if name.startswith("frame-"):
        os.remove(f"{a.out}/{name}")
for name in os.listdir(tmp):
    os.chmod(f"{tmp}/{name}", 0o644)
    os.replace(f"{tmp}/{name}", f"{a.out}/{name}")
shutil.rmtree(tmp)
