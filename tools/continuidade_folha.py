import csv
import glob
import os
import sys

from PIL import Image, ImageDraw

PHASE_COLORS = {
    "travel": (60, 60, 90), "arrival": (40, 80, 40), "battle": (70, 40, 40),
    "fork": (80, 70, 30), "converge": (90, 60, 20), "landmark": (40, 70, 80), "stop": (50, 50, 50),
}


def load(path):
    lums, shadow, phases = {}, {}, {}
    with open(path, newline="") as fh:
        for r in csv.DictReader(fh):
            f = int(r["frame"])
            phases[f] = r["phase"]
            if r["uid"] == "-1":
                shadow[f] = r
            else:
                lums.setdefault(r["uid"], {})[f] = r
    return lums, shadow, phases


def plot(path, out, title):
    lums, shadow, phases = load(path)
    n = max(phases) if phases else 1
    W, H, M = 1600, 900, 40
    img = Image.new("RGB", (W, H), (18, 18, 22))
    d = ImageDraw.Draw(img)
    sx = (W - 2 * M) / n
    half = (H - 3 * M) // 2
    for f, ph in phases.items():
        c = PHASE_COLORS.get(ph, (40, 40, 40))
        d.rectangle([M + (f - 1) * sx, M, M + f * sx, H - M], fill=c)
    d.text((M, 8), title + "   x de tela (cima) e alpha (baixo) por luminaria; cinza = sombra do inimigo", fill=(230, 230, 230))
    palette = [(255, 200, 80), (120, 200, 255), (255, 120, 160), (160, 255, 140), (220, 160, 255),
               (255, 255, 140), (120, 255, 230), (255, 160, 100), (200, 200, 200), (255, 90, 90)]
    for i, (uid, fr) in enumerate(sorted(lums.items(), key=lambda kv: int(kv[0]))):
        col = palette[i % len(palette)]
        prev = None
        for f in range(1, n + 1):
            r = fr.get(f)
            if r and float(r["a"]) > 0.02:
                x = M + (f - 0.5) * sx
                y = M + half * float(r["x"]) / 1920.0
                ya = 2 * M + half + half * (1 - float(r["a"]))
                if prev:
                    d.line([prev[0], prev[1], x, y], fill=col, width=2)
                    d.line([prev[0], prev[2], x, ya], fill=col, width=1)
                prev = (x, y, ya)
            else:
                prev = None
    prev = None
    for f in range(1, n + 1):
        r = shadow.get(f)
        if r:
            x = M + (f - 0.5) * sx
            y = 2 * M + half + half * (1 - min(1.0, float(r["t"]) / 400.0))
            if prev:
                d.line([prev[0], prev[1], x, y], fill=(170, 170, 170), width=3)
            prev = (x, y)
        else:
            prev = None
    img.save(out)
    print(out)


def sheet(frames_dir, out, cols=6, every=2, scale=0.25):
    files = sorted(glob.glob(os.path.join(frames_dir, "f_*.png")))[::every]
    if not files:
        return
    tiles = []
    for f in files:
        im = Image.open(f).convert("RGB")
        im = im.resize((int(im.width * scale), int(im.height * scale)), Image.NEAREST)
        dr = ImageDraw.Draw(im)
        dr.rectangle([0, 0, 150, 14], fill=(0, 0, 0))
        dr.text((3, 2), os.path.basename(f)[2:-4], fill=(255, 255, 0))
        tiles.append(im)
    tw, th = tiles[0].size
    rows = (len(tiles) + cols - 1) // cols
    out_im = Image.new("RGB", (tw * cols, th * rows), (0, 0, 0))
    for i, t in enumerate(tiles):
        out_im.paste(t, ((i % cols) * tw, (i // cols) * th))
    out_im.save(out)
    print(out)


if __name__ == "__main__":
    mode = sys.argv[1]
    if mode == "plot":
        plot(sys.argv[2], sys.argv[3], sys.argv[4] if len(sys.argv) > 4 else "")
    else:
        sheet(sys.argv[2], sys.argv[3], every=int(sys.argv[4]) if len(sys.argv) > 4 else 2)
