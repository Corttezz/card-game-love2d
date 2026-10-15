import glob
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BOSS = "abyss_tyrant"
ANIM = os.path.join(ROOT, "assets/sprites/characters/enemies", BOSS, "animations")
LINK_OUT = os.path.join(ROOT, "assets/sprites/characters/enemies", BOSS, "mechanic/chain_link.png")
DATA_OUT = os.path.join(ROOT, "src/data/boss_chain_grips.lua")
SHEET_OUT = os.path.join(ROOT, "tools/preview_out/correntes_tirano/grips_sheet.png")

GRIPS = [
    ("ankle_r", 84, 110),
    ("wrist_l", 22, 93),
    ("wrist_r", 101, 93),
]

PAL = {
    "O": (13, 13, 14, 255),
    "D": (38, 40, 41, 255),
    "M": (70, 62, 58, 255),
    "L": (113, 103, 96, 255),
    "H": (150, 138, 128, 255),
    ".": (0, 0, 0, 0),
}

LINK = [
    ".OOO.",
    "OHLMO",
    "OL.DO",
    "OM.DO",
    "OMDDO",
    ".OLO.",
    ".OMO.",
    ".ODO.",
]

FOOT_ALPHA = 20
HALF = 7
SEARCH = 18


def write_link():
    h = len(LINK)
    w = len(LINK[0])
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for y, row in enumerate(LINK):
        for x, ch in enumerate(row):
            im.putpixel((x, y), PAL[ch])
    im.save(LINK_OUT)
    return w, h


def frames(clip):
    fs = glob.glob(os.path.join(ANIM, clip, "south", "*.png"))
    fs.sort(key=lambda f: int(os.path.basename(f)[:-4]))
    return fs


def load(f):
    return np.asarray(Image.open(f).convert("RGBA")).astype(float)


def content_off(a):
    ys, xs = np.nonzero(a[:, :, 3] > FOOT_ALPHA)
    return (xs.min() + xs.max()) / 2 - a.shape[1] / 2


def track(ref, a, gx, gy, px, py):
    p = ref[gy - HALF:gy + HALF, gx - HALF:gx + HALF]
    best = None
    for dy in range(-SEARCH, SEARCH + 1):
        for dx in range(-SEARCH, SEARCH + 1):
            x, y = px + dx, py + dy
            if x - HALF < 0 or y - HALF < 0 or x + HALF > a.shape[1] or y + HALF > a.shape[0]:
                continue
            q = a[y - HALF:y + HALF, x - HALF:x + HALF]
            e = ((q - p) ** 2).sum() + (dx * dx + dy * dy) * 400
            if best is None or e < best[0]:
                best = (e, x, y)
    return best[1], best[2]


def main():
    lw, lh = write_link()
    ref_files = frames("idle")
    ref = load(ref_files[0])
    ref_off = content_off(ref)
    clips = sorted(d for d in os.listdir(ANIM) if os.path.isdir(os.path.join(ANIM, d, "south")))
    out = {}
    sheet_rows = []
    for clip in clips:
        rows = []
        for f in frames(clip):
            a = load(f)
            shx = (a.shape[1] - ref.shape[1]) / 2 + (content_off(a) - ref_off)
            shy = a.shape[0] - ref.shape[0]
            pts = []
            for _, gx, gy in GRIPS:
                px, py = int(round(gx + shx)), int(round(gy + shy))
                pts.append(track(ref, a, gx, gy, px, py))
            rows.append((f, pts))
        out[clip] = rows
        sheet_rows.append((clip, rows))
    lines = ["return {", '    %s = {' % BOSS, "        names = { %s }," % ", ".join('"%s"' % g[0] for g in GRIPS)]
    for clip in clips:
        frs = []
        for _, pts in out[clip]:
            frs.append("{ " + ", ".join("{ %d, %d }" % p for p in pts) + " }")
        lines.append("        %s = {" % clip)
        for fr in frs:
            lines.append("            %s," % fr)
        lines.append("        },")
    lines.append("    },")
    lines.append("}")
    with open(DATA_OUT, "w", newline="\n") as fh:
        fh.write("\n".join(lines) + "\n")
    k = 3
    cell_w = max(Image.open(rs[0][0]).size[0] for _, rs in sheet_rows) * k
    cell_h = 126 * k
    ncol = max(len(rs) for _, rs in sheet_rows)
    sheet = Image.new("RGBA", (cell_w * ncol, cell_h * len(sheet_rows)), (30, 60, 30, 255))
    colors = [(255, 60, 60, 255), (60, 200, 255, 255), (255, 230, 40, 255)]
    for r, (clip, rs) in enumerate(sheet_rows):
        for c, (f, pts) in enumerate(rs):
            im = Image.open(f).convert("RGBA")
            im = im.resize((im.size[0] * k, im.size[1] * k), Image.NEAREST)
            sheet.alpha_composite(im, (c * cell_w, r * cell_h))
            d = ImageDraw.Draw(sheet)
            for i, (x, y) in enumerate(pts):
                cx, cy = c * cell_w + x * k + 1, r * cell_h + y * k + 1
                d.rectangle([cx - 4, cy - 4, cx + 4, cy + 4], outline=colors[i], width=2)
            d.text((c * cell_w + 2, r * cell_h + 2), "%s %d" % (clip, c), fill=(255, 255, 255, 255))
    os.makedirs(os.path.dirname(SHEET_OUT), exist_ok=True)
    sheet.save(SHEET_OUT)
    print(DATA_OUT)
    print(LINK_OUT, lw, lh)
    print(SHEET_OUT)


if __name__ == "__main__":
    sys.exit(main())
