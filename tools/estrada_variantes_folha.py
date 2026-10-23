import os
import sys

from PIL import Image, ImageDraw

SAVE = os.path.join(os.environ.get("APPDATA", ""), "LOVE", os.environ.get("CARDGAME_IDENTITY", "estrada"),
                    "estrada_variantes")
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "preview_out", "estrada_variantes")
VARS = ["atual", "A", "B", "C"]
CREST = {"fork": 480, "battle": 432}


def crop(src, out, x0, y0, w, h, k):
    im = Image.open(src).crop((x0, y0, x0 + w, y0 + h))
    im.resize((w * k, h * k), Image.NEAREST).save(out)


def label(im, text):
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, 8 + 7 * len(text), 18), fill=(0, 0, 0))
    d.text((4, 3), text, fill=(255, 255, 255))
    return im


def sheet(tag, atos, names):
    base = os.path.join(SAVE, tag)
    for ato in atos:
        dst = os.path.join(OUT, "ato%d" % ato)
        os.makedirs(dst, exist_ok=True)
        for scene in ("fork", "battle"):
            ims = []
            for v in VARS:
                p = os.path.join(base, "ato%d_%s_%s.png" % (ato, scene, v))
                if not os.path.exists(p):
                    continue
                ims.append((v, Image.open(p).convert("RGB")))
            if not ims:
                continue
            w, h = ims[0][1].size
            half = [(v, label(im.resize((w // 2, h // 2), Image.LANCZOS), "%s %s" % (v, names.get((ato, v), ""))))
                    for v, im in ims]
            cols = 2
            rows = (len(half) + 1) // 2
            full = Image.new("RGB", (cols * w // 2, rows * h // 2))
            for i, (v, im) in enumerate(half):
                full.paste(im, ((i % cols) * w // 2, (i // cols) * h // 2))
            full.save(os.path.join(dst, "folha_%s_%s.png" % (scene, tag)))
            cy = CREST[scene]
            near = [im.crop((720, h - 300, 1200, h)).resize((960, 600), Image.NEAREST) for _, im in ims]
            far = [im.crop((800, cy - 10, 1120, cy + 140)).resize((640, 300), Image.NEAREST) for _, im in ims]
            strip = Image.new("RGB", (960 * len(near), 900), (0, 0, 0))
            for i, (v, _) in enumerate(ims):
                strip.paste(label(near[i], "%s perto 2x" % v), (960 * i, 0))
                strip.paste(label(far[i], "%s crista 2x" % v), (960 * i + 160, 600))
            strip.save(os.path.join(dst, "recortes_%s_%s.png" % (scene, tag)))


def overview(tag):
    tiles = []
    for ato in range(1, 7):
        for v in VARS[1:]:
            p = os.path.join(SAVE, tag, "ato%d_fork_%s.png" % (ato, v))
            if os.path.exists(p):
                im = Image.open(p).convert("RGB").crop((480, 380, 1440, 1080)).resize((480, 350), Image.LANCZOS)
                tiles.append(label(im, "ato%d %s" % (ato, v)))
    if not tiles:
        return
    full = Image.new("RGB", (480 * 3, 350 * ((len(tiles) + 2) // 3)))
    for i, im in enumerate(tiles):
        full.paste(im, ((i % 3) * 480, (i // 3) * 350))
    os.makedirs(OUT, exist_ok=True)
    full.save(os.path.join(OUT, "visao_geral_18_%s.png" % tag))


if __name__ == "__main__":
    mode = sys.argv[1]
    if mode == "crop":
        crop(sys.argv[2], sys.argv[3], *map(int, sys.argv[4:9]))
    elif mode == "sheet":
        tag = sys.argv[2]
        atos = [int(a) for a in (sys.argv[3] if len(sys.argv) > 3 else "1,2,3,4,5,6").split(",")]
        sheet(tag, atos, {})
        overview(tag)


def cmp(tag, ato, scene, out, x0=700, y0=560, w=520, h=520):
    ims = []
    for v in VARS:
        p = os.path.join(SAVE, tag, "ato%d_%s_%s.png" % (ato, scene, v))
        if os.path.exists(p):
            ims.append(label(Image.open(p).convert("RGB").crop((x0, y0, x0 + w, y0 + h)), v))
    full = Image.new("RGB", (w * len(ims), h))
    for i, im in enumerate(ims):
        full.paste(im, (i * w, 0))
    full.save(out)


if __name__ == "__main__" and sys.argv[1] == "cmp":
    cmp(sys.argv[2], int(sys.argv[3]), sys.argv[4], sys.argv[5], *map(int, sys.argv[6:10]))
