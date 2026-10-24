import os
import sys

from PIL import Image, ImageDraw

SAVE = os.path.join(os.environ.get("APPDATA", ""), "LOVE", os.environ.get("CARDGAME_IDENTITY", "road_v8"),
                    "estrada_final")
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "preview_out", "chao_v8")
RES = ["1280x720", "1920x1080", "3440x1440"]
SCENES = ["battle", "fork3", "fork2", "converge"]
NAMES = {3: "ato 3 cinza vulcanica", 5: "ato 5 trilha de lama e turfa"}


def label(im, text):
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, 12 + 7 * len(text), 18), fill=(0, 0, 0))
    d.text((5, 3), text, fill=(255, 255, 255))
    return im


def load(tag, ato, scene, res):
    p = os.path.join(SAVE, tag, "ato%d_%s_%s.png" % (ato, scene, res))
    return Image.open(p).convert("RGB") if os.path.exists(p) else None


def boxes(w, h):
    cw, ch = min(640, int(w * 0.36)), min(300, int(h * 0.26))
    near = (w // 2 - cw // 2, h - ch, w // 2 + cw // 2, h)
    fy = int(h * 0.50)
    far = (w // 2 - cw // 2, fy, w // 2 + cw // 2, fy + ch)
    return near, far


def sheet(ato, scene, res):
    a, b = load("antes", ato, scene, res), load("depois", ato, scene, res)
    if not a or not b:
        return False
    w, h = a.size
    near, far = boxes(w, h)
    tw = 960
    th = int(h * tw / w)
    cw, ch = near[2] - near[0], near[3] - near[1]
    W = max(2 * tw, 2 * cw + 8)
    out = Image.new("RGB", (W, th + 2 * (ch + 4)), (24, 24, 24))
    out.paste(label(a.resize((tw, th), Image.LANCZOS), "antes %s %s %s" % (NAMES[ato], scene, res)), (0, 0))
    out.paste(label(b.resize((tw, th), Image.LANCZOS), "depois %s %s %s" % (NAMES[ato], scene, res)), (tw, 0))
    y = th + 4
    out.paste(label(a.crop(near), "antes perto 1:1"), (0, y))
    out.paste(label(b.crop(near), "depois perto 1:1"), (cw + 8, y))
    y = y + ch + 4
    out.paste(label(a.crop(far), "antes longe 1:1"), (0, y))
    out.paste(label(b.crop(far), "depois longe 1:1"), (cw + 8, y))
    dst = os.path.join(OUT, "ato%d" % ato)
    os.makedirs(dst, exist_ok=True)
    out.save(os.path.join(dst, "%s_%s.png" % (scene, res)))
    return True


def run():
    n = 0
    for ato in (3, 5):
        for scene in SCENES:
            for res in RES:
                if sheet(ato, scene, res):
                    n += 1
    print(OUT, n)


if __name__ == "__main__":
    sys.exit(run())
