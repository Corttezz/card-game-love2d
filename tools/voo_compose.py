import os
import sys

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "tools/preview_out/voo")


def frames(src, eid, mode):
    out = []
    i = 0
    while True:
        p = os.path.join(src, f"{eid}_{mode}_{i:02d}.png")
        if not os.path.exists(p):
            return out
        out.append(Image.open(p).convert("RGB"))
        i += 1


def label(im, text):
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, 8 + 7 * len(text), 16), fill=(20, 18, 18))
    d.text((4, 2), text, fill=(235, 225, 200))
    return im


def gif(eid, a, b, fps):
    w, h = a[0].size
    seq = []
    for fa, fb in zip(a, b):
        im = Image.new("RGB", (w * 2 + 6, h), (12, 10, 10))
        im.paste(label(fa.copy(), "antes"), (0, 0))
        im.paste(label(fb.copy(), "depois"), (w + 6, 0))
        seq.append(im)
    p = os.path.join(OUT, f"{eid}_antes_depois.gif")
    pal = seq[len(seq) // 2].quantize(colors=255, method=Image.MEDIANCUT)
    q = [im.quantize(palette=pal, dither=Image.Dither.NONE) for im in seq]
    q[0].save(p, save_all=True, append_images=q[1:], duration=int(1000 / fps), loop=0, optimize=True)
    return p


def zoom(im, box, k):
    return im.crop(box).resize(((box[2] - box[0]) * k, (box[3] - box[1]) * k), Image.NEAREST)


def sheet(eid, a, b, pick, ground_box):
    w, h = a[0].size
    gw, gh = (ground_box[2] - ground_box[0]) * 3, (ground_box[3] - ground_box[1]) * 3
    cols = len(pick)
    cw = max(w, gw)
    row_h = [h, gh, h, gh]
    sh = Image.new("RGB", (cols * (cw + 6) + 6, sum(row_h) + 5 * 6 + 20), (12, 10, 10))
    d = ImageDraw.Draw(sh)
    d.text((6, 4), f"{eid}: linhas 1-2 antes (1:1 e chao 3x), linhas 3-4 depois", fill=(235, 225, 200))
    y = 20
    for seq, name in ((a, "antes"), (b, "depois")):
        for j, i in enumerate(pick):
            x = 6 + j * (cw + 6)
            sh.paste(label(seq[i].copy(), f"{name} {i}"), (x, y + 6))
            sh.paste(zoom(seq[i], ground_box, 3), (x, y + 12 + h))
        y += h + gh + 12
    p = os.path.join(OUT, f"{eid}_antes_depois.png")
    sh.save(p)
    return p


def main():
    src, eid = sys.argv[1], sys.argv[2]
    fps = float(sys.argv[3]) if len(sys.argv) > 3 else 12
    os.makedirs(OUT, exist_ok=True)
    a, b = frames(src, eid, "antes"), frames(src, eid, "depois")
    n = min(len(a), len(b))
    a, b = a[:n], b[:n]
    w, h = a[0].size
    gw = min(w, 150)
    gb = (max(0, w // 2 - gw // 2), max(0, h - 110), min(w, w // 2 + gw // 2), h)
    pick = []
    hp = os.path.join(src, f"{eid}_depois_sopros.txt")
    if os.path.exists(hp):
        hits = [int(x) for x in open(hp).read().split(",") if x.strip()]
        for hf in hits[:2]:
            pick += [x for x in (hf - 2, hf, hf + 2, hf + 4) if 0 <= x < n]
    if not pick:
        step = max(1, n // 8)
        pick = list(range(0, n, step))[:8]
    pick = sorted(set(pick))[:8]
    print(gif(eid, a, b, fps))
    print(sheet(eid, a, b, pick, gb))


if __name__ == "__main__":
    main()
