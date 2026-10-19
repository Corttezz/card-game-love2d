import csv
import glob
import os
import sys

from PIL import Image, ImageDraw


def crop_box(w, h, k=1.0):
    cw, ch = int(w * 0.42 * k), int(h * 0.46 * k)
    x0 = (w - cw) // 2
    y0 = int(h * 0.07)
    return x0, y0, x0 + cw, y0 + ch


def mark(img, w, x0):
    d = ImageDraw.Draw(img)
    cx = w // 2 - x0
    for y in range(0, img.height, 6):
        d.line([(cx, y), (cx, y + 2)], fill=(255, 0, 255), width=1)
    return img


def sheet(src, out, pattern, cols, title, k=1.0, every=1):
    files = sorted(glob.glob(os.path.join(src, pattern)))[::every]
    if not files:
        return None
    first = Image.open(files[0])
    w, h = first.size
    box = crop_box(w, h, k)
    cw, ch = box[2] - box[0], box[3] - box[1]
    rows = (len(files) + cols - 1) // cols
    lab = 18
    sh = Image.new("RGB", (cols * cw, rows * (ch + lab) + 24), (16, 14, 12))
    d = ImageDraw.Draw(sh)
    d.text((6, 4), title, fill=(240, 230, 210))
    for i, f in enumerate(files):
        im = Image.open(f).convert("RGB").crop(box)
        mark(im, w, box[0])
        x, y = (i % cols) * cw, 24 + (i // cols) * (ch + lab)
        sh.paste(im, (x, y + lab))
        d.text((x + 4, y + 3), os.path.basename(f)[:-4], fill=(240, 230, 210))
    sh.quantize(colors=256, method=Image.Quantize.MEDIANCUT).save(out, optimize=True)
    return out


def plot(src, out):
    path = os.path.join(src, "trace.csv")
    if not os.path.exists(path):
        return None
    rows = list(csv.DictReader(open(path)))
    W, H, pad = 1400, 360, 40
    im = Image.new("RGB", (W, H), (20, 18, 16))
    d = ImageDraw.Draw(im)
    n = len(rows)
    lim = 0.04
    cy = H // 2
    d.line([(pad, cy), (W - pad, cy)], fill=(90, 90, 90))
    for v in (-0.035, 0.035):
        yy = cy - v / lim * (H / 2 - pad)
        d.line([(pad, yy), (W - pad, yy)], fill=(70, 50, 50))
    last = None
    prev_phase = None
    for i, r in enumerate(rows):
        x = pad + i / max(1, n - 1) * (W - 2 * pad)
        y = cy - float(r["dx_frac"]) / lim * (H / 2 - pad)
        if r["phase"] != prev_phase:
            d.line([(x, pad), (x, H - pad)], fill=(50, 50, 70))
            d.text((x + 2, pad - 14 + (i % 2) * 8), r["phase"][:14], fill=(150, 150, 180))
            prev_phase = r["phase"]
        if last:
            d.line([last, (x, y)], fill=(255, 200, 80), width=2)
        last = (x, y)
    d.text((6, H - 18), "dx do castelo / largura (linhas: +-3,5%), por quadro", fill=(220, 220, 220))
    im.save(out)
    return out


def main():
    root = sys.argv[1]
    dest = sys.argv[2]
    os.makedirs(dest, exist_ok=True)
    for src in sorted(glob.glob(os.path.join(root, "a*"))):
        name = os.path.basename(src)
        for o in (
            sheet(src, os.path.join(dest, name + "_seq.png"), "seq_*.png", 8, name + " sequencia (1 a cada 2 quadros salvos)", 0.75, 2),
            sheet(src, os.path.join(dest, name + "_paradas.png"), "[0-9][0-9]_*.png", 4, name + " paradas"),
            plot(src, os.path.join(dest, name + "_dx.png")),
        ):
            if o:
                print(o)


main()
