import json
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "tools/preview_out/loja_base/pixellab/raw")
DEST = os.path.join(ROOT, "assets/sprites/world/base")
PICKS = os.path.join(ROOT, "tools/preview_out/loja_base/escolhas.json")
FLAT = ("pad", "path")


def lum(c):
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def edge(px, w, h, x, y):
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        nx, ny = x + dx, y + dy
        if nx < 0 or ny < 0 or nx >= w or ny >= h or px[nx, ny][3] == 0:
            return True
    return False


def hard(im):
    a = im.getchannel("A").point(lambda v: 255 if v >= 128 else 0)
    im.putalpha(a)
    return im


def flat(im, seed):
    im = hard(im)
    w, h = im.size
    px = im.load()
    for _ in range(2):
        kill = [(x, y) for y in range(h) for x in range(w)
                if px[x, y][3] and edge(px, w, h, x, y) and lum(px[x, y]) < 34]
        for x, y in kill:
            px[x, y] = (0, 0, 0, 0)
    ring = [(x, y) for y in range(h) for x in range(w) if px[x, y][3] and edge(px, w, h, x, y)]
    for x, y in ring:
        v = ((x * 73856093) ^ (y * 19349663) ^ seed) % 100
        if v < 38:
            px[x, y] = (0, 0, 0, 0)
    return im


def install(picks):
    os.makedirs(DEST, exist_ok=True)
    for name, src in sorted(picks.items()):
        flip = src.endswith("!")
        src = src.rstrip("!")
        im = Image.open(os.path.join(RAW, src + ".png")).convert("RGBA")
        part = name.split("_", 1)[1]
        im = flat(im, len(name) * 977) if part in FLAT else hard(im)
        if flip:
            im = im.transpose(Image.FLIP_LEFT_RIGHT)
        bb = im.getbbox()
        if bb:
            im = im.crop(bb)
        im.save(os.path.join(DEST, name + ".png"))
        print(f"[ok] {name} <- {src} {im.size}")


if __name__ == "__main__":
    picks = json.load(open(PICKS)) if os.path.exists(PICKS) else {}
    for a in sys.argv[1:]:
        k, v = a.split("=")
        picks[k] = v
    json.dump(picks, open(PICKS, "w"), indent=1, sort_keys=True)
    install(picks)
