import colorsys
import os
import sys
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EN = os.path.join(ROOT, "assets", "sprites", "characters", "enemies", "spectral_knight", "animations")
GROUND = 110
BAND = 7
FLOOR_A = 0.38
BOOT_X1 = 36
IDLE_W = 112


def is_mist(r, g, b):
    _, l, _ = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
    return l >= 0.47 and b >= r - 6 and b >= g


def ramp(y):
    if y <= GROUND - BAND:
        return 1.0
    k = (y - (GROUND - BAND)) / BAND
    return 1.0 - (1.0 - FLOOR_A) * min(1.0, k)


def fix(im):
    im = im.convert("RGBA")
    px = im.load()
    w, h = im.size
    x0 = BOOT_X1 + (w - IDLE_W) // 2
    for y in range(GROUND - BAND + 1, h):
        k = ramp(y)
        for x in range(x0, w):
            r, g, b, a = px[x, y]
            if a and is_mist(r, g, b):
                px[x, y] = (r, g, b, max(27, int(round(a * k))))
    return im


def main(args):
    n = 0
    for clip in sorted(os.listdir(EN)):
        d = os.path.join(EN, clip, "south")
        if not os.path.isdir(d):
            continue
        for f in os.listdir(d):
            if f.endswith(".png"):
                p = os.path.join(d, f)
                fix(Image.open(p)).save(p)
                n += 1
    print("frames", n)


if __name__ == "__main__":
    main(sys.argv[1:])
