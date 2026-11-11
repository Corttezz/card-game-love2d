"""Pick the chosen PixelLab candidates and post-process them into art/gen/.

Candidates live in raw/cand/ (already alpha-thresholded and cropped by plab.py process).
  python finalize.py
"""
import os
from collections import Counter

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
CAND = os.path.join(HERE, "raw", "cand")
RAW = os.path.join(HERE, "raw")
GEN = os.path.join(HERE, "..", "..", "art", "gen")


def cand(name):
    return Image.open(os.path.join(CAND, name + ".png")).convert("RGBA")


def save(im, rel):
    p = os.path.join(GEN, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    im.save(p)
    print(f"{rel:28s} {im.width}x{im.height}")


def threshold(im):
    im = im.copy()
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            c = px[x, y]
            px[x, y] = (c[0], c[1], c[2], 255 if c[3] >= 128 else 0)
    return im


def components(im):
    """8-connected opaque components -> list of pixel sets."""
    a = im.load()
    seen, comps = set(), []
    for y in range(im.height):
        for x in range(im.width):
            if a[x, y][3] and (x, y) not in seen:
                stack, comp = [(x, y)], set()
                seen.add((x, y))
                while stack:
                    cx, cy = stack.pop()
                    comp.add((cx, cy))
                    for dx in (-1, 0, 1):
                        for dy in (-1, 0, 1):
                            nx, ny = cx + dx, cy + dy
                            if 0 <= nx < im.width and 0 <= ny < im.height and (nx, ny) not in seen \
                                    and a[nx, ny][3]:
                                seen.add((nx, ny))
                                stack.append((nx, ny))
                comps.append(comp)
    return comps


def keep(im, pred):
    """Drop components for which pred(comp) is False, then crop."""
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    src, dst = im.load(), out.load()
    for comp in components(im):
        if pred(comp):
            for p in comp:
                dst[p] = src[p]
    return out.crop(out.getbbox())


def largest(im):
    comps = components(im)
    big = max(len(c) for c in comps)
    return keep(im, lambda c: len(c) == big)


def pad_to(im, w, h, anchor="bottom"):
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    x = (w - im.width) // 2
    y = h - im.height if anchor == "bottom" else (h - im.height) // 2
    out.alpha_composite(im, (x, y))
    return out


# ---------------------------------------------------------------- 1 tome
save(cand("tome2_b__00"), "tome_closed.png")

# ---------------------------------------------------------------- 2 runes
RUNES = {"fields": 38, "highlands": 0, "abyss": 22, "frost": 13, "marsh": 51, "dusk": 17, "eclipse": 47}
ims = {k: largest(cand(f"rune_{k}_a__{i:02d}")) for k, i in RUNES.items()}
W = max(i.width for i in ims.values())
H = max(i.height for i in ims.values())
for k, im in ims.items():
    save(pad_to(im, W, H), f"runes/rune_{k}.png")

# ---------------------------------------------------------------- 3 cursors
CURSORS = {"fields": "cursor_fields_a__34", "highlands": "cursor_highlands_a__29",
           "abyss": "cursor_abyss_a__40", "frost": "cursor_frost_a__13",
           "marsh": "cursor_marsh2_b__13", "dusk": "cursor_dusk_a__33"}
hotspots = {}
for k, name in CURSORS.items():
    im = largest(cand(name))
    canvas = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    canvas.alpha_composite(im, (0, 0))
    a = canvas.load()
    tip = min(((x, y) for y in range(24) for x in range(24) if a[x, y][3]), key=lambda p: (p[0] + p[1], p[1]))
    hotspots[k] = tip
    save(canvas, f"cursors/cursor_{k}.png")
print("cursor hotspots (x, y):", hotspots)

# ---------------------------------------------------------------- 4 fx (PixelLab part)
for i, n in enumerate([1, 2, 8]):
    save(largest(cand(f"fx_leaf_a__{n:02d}")), f"fx/leaf_{i}.png")

frames = [threshold(Image.open(os.path.join(RAW, f"bat_anim_a__{n:02d}.png")).convert("RGBA"))
          for n in (0, 1, 2, 4)]  # wings up, mid, level, down
box = [min(f.getbbox()[0] for f in frames), min(f.getbbox()[1] for f in frames),
       max(f.getbbox()[2] for f in frames), max(f.getbbox()[3] for f in frames)]
for i, f in enumerate(frames):
    save(f.crop(box), f"fx/bat_{i}.png")

# ---------------------------------------------------------------- 5 ui
# parchment: 46x46 candidate -> 48x48 9-slice (16 px corners). Corners come from the
# candidate's corners; the 16 px middle bands come from its center, and their first and
# last columns/rows are replaced by the per-row (per-column) most common colour so that
# the bands tile seamlessly.
src = cand("ui_parchment_a__05")
S = src.width
P = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
mid0 = (S - 16) // 2
# 3x3 grid of source regions: (sx, sw) per column, same for rows
cols = [(0, 16), (mid0, 16), (S - 16, 16)]
for gy, (sy, sh) in enumerate(cols):
    for gx, (sx, sw) in enumerate(cols):
        P.alpha_composite(src.crop((sx, sy, sx + sw, sy + sh)), (gx * 16, gy * 16))
px = P.load()


def mode(vals):
    return Counter(vals).most_common(1)[0][0]


for y in range(48):  # horizontal bands: seam columns 16 and 31
    m = mode([px[x, y] for x in range(16, 32)])
    px[16, y] = m
    px[31, y] = m
for x in range(48):  # vertical bands: seam rows 16 and 31
    m = mode([px[x, y] for y in range(16, 32)])
    px[x, 16] = m
    px[x, 31] = m
save(P, "ui/parchment_9slice.png")

div = cand("ui_divider_a__02")
save(keep(div, lambda c: len(c) >= 12 and not (max(x for x, _ in c) < 10 or min(x for x, _ in c) > div.width - 11)),
     "ui/divider.png")
save(largest(cand("ui_corner_a__05")), "ui/corner.png")
save(cand("ui_ribbon_a__00"), "ui/ribbon.png")

# ---------------------------------------------------------------- 6 page_torn
# candidates came out portrait (69x94); rotated a quarter turn (lossless) for the landscape slot
save(cand("page_torn2_b__01").transpose(Image.Transpose.ROTATE_270), "page_torn.png")

# ---------------------------------------------------------------- 7 eclipse wallpaper (opaque scene)
save(Image.open(os.path.join(RAW, "eclipse_wall2_b__00.png")).convert("RGB"), "eclipse_wallpaper.png")
