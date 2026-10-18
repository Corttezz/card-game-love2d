import os
import sys
from PIL import Image, ImageDraw

CROPS = {
    "fork": {
        "arvores_esq_meio": (0, 330, 300, 230),
        "arvores_dir_fundo": (700, 300, 324, 200),
        "centro_marcos": (300, 300, 430, 200),
        "chao_frente": (250, 560, 520, 200),
        "grama_dir": (620, 380, 404, 380),
    },
    "landmark": {
        "fogueira": (380, 380, 300, 260),
        "poste_esq": (260, 370, 180, 380),
        "arvores_esq": (0, 300, 300, 300),
        "arvores_dir_fundo": (640, 290, 384, 180),
        "grama_dir_estrada": (600, 420, 424, 340),
        "grama_esq_estrada": (0, 440, 420, 320),
    },
    "viagem": {
        "estrada_fundo": (300, 300, 430, 220),
        "arvores_esq": (0, 330, 330, 300),
        "chao_frente": (200, 560, 620, 200),
    },
    "castelo": {
        "castelo": (250, 80, 520, 380),
        "esq_frente": (0, 380, 350, 380),
    },
}
TODS = ["dia", "meio", "por"]


def load(d, tod, scene):
    p = os.path.join(d, "b1_%s_%s.png" % (tod, scene))
    return Image.open(p).convert("RGB") if os.path.exists(p) else None


def label(im, text):
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, 8 + 7 * len(text), 14), fill=(0, 0, 0))
    d.text((4, 2), text, fill=(255, 255, 255))
    return im


def sheet(out_dir, scene, dirs, names, zoom=3):
    cols = len(dirs)
    frames = [[load(d, tod, scene) for d in dirs] for tod in TODS]
    fw, fh = 1024, 768
    full = Image.new("RGB", (cols * (fw + 8), len(TODS) * (fh + 8)), (20, 20, 20))
    for r, row in enumerate(frames):
        for c, im in enumerate(row):
            if im:
                full.paste(label(im.copy(), "%s %s" % (names[c], TODS[r])), (c * (fw + 8), r * (fh + 8)))
    full.save(os.path.join(out_dir, "folha_%s.png" % scene))
    for cname, (x, y, w, h) in CROPS.get(scene, {}).items():
        cw, ch = w * zoom, h * zoom
        sh = Image.new("RGB", (cols * (cw + 6), len(TODS) * (ch + 6)), (20, 20, 20))
        for r, row in enumerate(frames):
            for c, im in enumerate(row):
                if im:
                    crop = im.crop((x, y, x + w, y + h)).resize((cw, ch), Image.NEAREST)
                    sh.paste(label(crop, "%s %s" % (names[c], TODS[r])), (c * (cw + 6), r * (ch + 6)))
        sh.save(os.path.join(out_dir, "rec_%s_%s.png" % (scene, cname)))


def main():
    out_dir = sys.argv[1]
    pairs = sys.argv[2:]
    dirs, names = [], []
    for p in pairs:
        n, d = p.split("=", 1)
        names.append(n)
        dirs.append(d)
    os.makedirs(out_dir, exist_ok=True)
    scenes = [s for s in CROPS]
    for s in scenes:
        sheet(out_dir, s, dirs, names)
    print(out_dir)


if __name__ == "__main__":
    main()
