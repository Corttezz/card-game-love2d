import math
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sprites", "world")
N = 9
PAD = 4
STRETCH = 0.22
RIPPLE = 1.2


def flame_mask(a, top_frac):
    rgb = a[..., :3].astype(float) / 255
    mx = rgb.max(2)
    mn = rgb.min(2)
    s = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    lum = rgb[..., 0] * 0.3 + rgb[..., 1] * 0.55 + rgb[..., 2] * 0.15
    m = (a[..., 3] > 127) & (((mx > 0.62) & (s > 0.35)) | (lum > 0.78))
    H = a.shape[0]
    m[int(H * top_frac):, :] = False
    return m


def flame(arr, k, top_frac):
    out = arr.copy()
    H, W = arr.shape[:2]
    m = flame_mask(arr, top_frac)
    if m.sum() < 4:
        return out
    ys, xs = np.nonzero(m)
    base, top = ys.max(), ys.min()
    hgt = base - top + 1
    ph = 2 * math.pi * k / N
    s = 1.0 + STRETCH * (0.5 + 0.5 * math.sin(ph))
    hot = math.sin(ph * 2) > 0.3
    x0, x1 = xs.min(), xs.max()
    for y in range(max(0, top - int(hgt * STRETCH) - 2), base + 1):
        f = (base - y) / max(1, hgt)
        dx = int(round(RIPPLE * math.sin(ph * 2 + y * 0.9) * min(1.0, f)))
        sy = int(round(base - (base - y) / s))
        if sy < 0 or sy >= H:
            continue
        for x in range(max(0, x0 - 2), min(W, x1 + 3)):
            if m[y, x]:
                out[y, x] = 0
            sx = x - dx
            if 0 <= sx < W and m[sy, sx]:
                c = arr[sy, sx].copy()
                if hot and f > 0.6:
                    c[:3] = np.minimum(255, c[:3].astype(int) + 24)
                out[y, x] = c
    for y in range(top, base + 1):
        for x in range(W):
            if m[y, x] and out[y, x, 3] == 0 and (base - y) / max(1, hgt) < 0.35:
                out[y, x] = arr[y, x]
    return out


def glow(arr, k, top_frac):
    out = arr.copy().astype(int)
    m = flame_mask(arr, top_frac)
    ph = 2 * math.pi * k / N
    gain = 0.88 + 0.12 * math.sin(ph) + 0.04 * math.sin(ph * 3 + 1.0)
    out[m, :3] = np.clip(out[m, :3] * gain, 0, 255)
    return out.astype(np.uint8)


def run(name, mode, top_frac):
    src = os.path.join(ROOT, name + ".png")
    im = Image.open(src).convert("RGBA")
    pad = PAD if mode == "flame" else 0
    base = Image.new("RGBA", (im.width, im.height + pad), (0, 0, 0, 0))
    base.paste(im, (0, pad))
    arr = np.array(base)
    d = os.path.join(ROOT, "anim", name)
    os.makedirs(d, exist_ok=True)
    for f in os.listdir(d):
        if f.endswith(".png"):
            os.remove(os.path.join(d, f))
    for k in range(N):
        fr = flame(arr, k, top_frac) if mode == "flame" else glow(arr, k, top_frac)
        Image.fromarray(fr).save(os.path.join(d, f"{k}.png"))
    base.save(src)
    print(d, base.size)


if __name__ == "__main__":
    run(sys.argv[1], sys.argv[2], float(sys.argv[3]) if len(sys.argv) > 3 else 0.45)
