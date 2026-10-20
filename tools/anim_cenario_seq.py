#!/usr/bin/env python3
import os
import sys

import numpy as np
from PIL import Image


def load(path):
    return np.array(Image.open(path).convert("RGB")).astype(np.int16)


def main():
    if len(sys.argv) < 4:
        print("uso: anim_cenario_seq.py <pasta-save> <prefixo> <saida-dir> [x0,y0,x1,y1 ...]")
        return 1
    src, prefix, out = sys.argv[1], sys.argv[2], sys.argv[3]
    crops = [tuple(int(v) for v in c.split(",")) for c in sys.argv[4:]]
    files = [] if os.environ.get("SEQ_SKIP0") else [prefix + ".png"]
    i = 1
    while os.path.exists(os.path.join(src, f"{prefix}_seq{i}.png")):
        files.append(f"{prefix}_seq{i}.png")
        i += 1
    frames = [load(os.path.join(src, f)) for f in files]
    os.makedirs(out, exist_ok=True)
    h, w = frames[0].shape[:2]
    moved = np.zeros((h, w), bool)
    for a, b in zip(frames, frames[1:]):
        moved |= np.abs(a - b).sum(axis=2) > 24
    dim = (frames[0] * 0.35).astype(np.uint8)
    dim[moved] = (255, 60, 200)
    Image.fromarray(dim).resize((w // 2, h // 2), Image.NEAREST).save(os.path.join(out, "mexeu.png"))
    print(os.path.join(out, "mexeu.png"), f"{int(moved.sum())} px mudaram em {len(frames)} quadros")
    for ci, (x0, y0, x1, y1) in enumerate(crops):
        k = int(os.environ.get("SEQ_SCALE", "1"))
        cw, ch = (x1 - x0) * k, (y1 - y0) * k
        tiles = [Image.fromarray(f[y0:y1, x0:x1].astype(np.uint8)).resize((cw, ch), Image.NEAREST)
                 for f in frames]
        sheet = Image.new("RGB", ((cw + 6) * len(tiles), ch), (40, 40, 48))
        for k, t in enumerate(tiles):
            sheet.paste(t, (k * (cw + 6), 0))
        p = os.path.join(out, f"recorte_{ci}.png")
        sheet.save(p)
        print(p)
    return 0


if __name__ == "__main__":
    sys.exit(main())
