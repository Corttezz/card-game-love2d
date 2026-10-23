import os
import shutil
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EN = os.path.join(ROOT, "assets/sprites/characters/enemies")

EYES = {
    "plague_toad": [
        {"box": (49, 7, 56, 14), "line": 10, "lid": (40, 10), "lid2": (44, 9)},
        {"box": (27, 8, 31, 13), "line": 10, "lid": (40, 10), "lid2": (44, 9)},
    ],
}


def lid_frame(base, eyes, amount):
    a = base.copy()
    for e in eyes:
        x0, y0, x1, y1 = e["box"]
        top = base[e["lid"][1], e["lid"][0]].copy()
        bot = base[e["lid2"][1], e["lid2"][0]].copy()
        stop = y0 + int(round((e["line"] - y0) * amount)) if amount < 1 else e["line"]
        for y in range(y0, y1):
            for x in range(x0, x1):
                px = base[y, x]
                cx, cy = (x0 + x1 - 1) / 2, (y0 + y1 - 1) / 2
                rx, ry = (x1 - x0) / 2, (y1 - y0) / 2
                if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 > 1.0 or px[3] == 0:
                    continue
                if amount >= 1:
                    a[y, x] = top if y < e["line"] else bot
                elif y < stop:
                    a[y, x] = top
        ly = e["line"] if amount >= 1 else stop
        for x in range(x0 + 1, x1 - 1):
            if base[ly, x][3]:
                a[ly, x] = (24, 18, 10, 255)
    return a


def main():
    eid = sys.argv[1]
    src = os.path.join(EN, eid, "animations/idle/south/0.png")
    base = np.asarray(Image.open(src).convert("RGBA")).copy()
    seq = [None, 0.5, 1.0, 1.0, 0.5, None]
    dest = os.path.join(EN, eid, "animations/fidget_blink/south")
    if os.path.isdir(dest):
        shutil.rmtree(dest)
    os.makedirs(dest)
    for i, amt in enumerate(seq):
        out = os.path.join(dest, f"{i}.png")
        if amt is None:
            shutil.copyfile(src, out)
        else:
            Image.fromarray(lid_frame(base, EYES[eid], amt).astype(np.uint8), "RGBA").save(out)
    print(dest)


if __name__ == "__main__":
    main()
