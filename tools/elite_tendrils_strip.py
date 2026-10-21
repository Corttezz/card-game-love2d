import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def purple(p):
    r, g, b, a = p
    return a > 0 and b > g * 1.6 and r > g * 1.4 and max(r, g, b) < 140


def extents(frames, y0):
    w, h = frames[0].size
    pxs = [f.load() for f in frames]
    ext = {}
    for y in range(y0, h):
        body = [x for x in range(w) if pxs[0][x, y][3] > 0
                and all(p[x, y] == pxs[0][x, y] for p in pxs)]
        ext[y] = (min(body) - 1, max(body) + 1) if body else (w, -1)
    return ext


def strip(im, y0, ext):
    w, h = im.size
    px = im.load()
    for y in range(y0, h):
        lo, hi = ext[y]
        for x in range(w):
            p = px[x, y]
            if purple(p) and (x < lo or x > hi):
                px[x, y] = (0, 0, 0, 0)
    for y in range(y0, h):
        for x in range(w):
            p = px[x, y]
            if purple(p):
                n = 0
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] > 0:
                        n += 1
                if n <= 1:
                    px[x, y] = (0, 0, 0, 0)
    return im


if __name__ == "__main__":
    d = os.path.join(ROOT, sys.argv[1])
    y0 = int(sys.argv[2])
    out = sys.argv[3] if len(sys.argv) > 3 else d
    os.makedirs(out, exist_ok=True)
    names = sorted(f for f in os.listdir(d) if f.endswith(".png"))
    frames = [Image.open(os.path.join(d, f)).convert("RGBA") for f in names]
    ext = extents(frames, y0)
    for f, im in zip(names, frames):
        strip(im, y0, ext).save(os.path.join(out, f))
    print("[ok]", out)
