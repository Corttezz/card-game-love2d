import os
import shutil
import sys

from PIL import Image, ImageDraw

SAVE = os.path.join(os.environ.get("APPDATA", ""), "LOVE", os.environ.get("CARDGAME_IDENTITY", "estrada_fin"),
                    "estrada_final")
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "preview_out", "estrada_final")
SCENES = ["fork3", "fork2", "converge", "battle", "continuar"]
NAMES = {1: "A trilha gasta", 2: "A trilha de cascalho", 3: "A trilha de cinza", 4: "A neve pisada",
         5: "B passarela de tabuas", 6: "A trilha de folhas"}


def label(im, text):
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, 10 + 7 * len(text), 18), fill=(0, 0, 0))
    d.text((5, 3), text, fill=(255, 255, 255))
    return im


def load(tag, ato, scene, res="1920x1080"):
    p = os.path.join(SAVE, tag, "ato%d_%s_%s.png" % (ato, scene, res))
    return Image.open(p).convert("RGB") if os.path.exists(p) else None


def crops(im, k=2):
    w, h = im.size
    sx, sy = w / 1920.0, h / 1080.0
    near = im.crop((int(760 * sx), int(840 * sy), int(1160 * sx), int(1080 * sy)))
    junc = im.crop((int(700 * sx), int(560 * sy), int(1220 * sx), int(820 * sy)))
    return (near.resize((near.width * k, near.height * k), Image.NEAREST),
            junc.resize((junc.width * k, junc.height * k), Image.NEAREST))


def run():
    os.makedirs(OUT, exist_ok=True)
    n = 0
    for ato in range(1, 7):
        dst = os.path.join(OUT, "ato%d" % ato)
        os.makedirs(dst, exist_ok=True)
        for f in os.listdir(os.path.join(SAVE, "depois")):
            if f.startswith("ato%d_" % ato):
                shutil.copy(os.path.join(SAVE, "depois", f), os.path.join(dst, f))
                n += 1
        for scene in ("fork3", "fork2", "converge", "battle"):
            a, b = load("antes", ato, scene), load("depois", ato, scene)
            if not a or not b:
                continue
            half = (960, 540)
            sheet = Image.new("RGB", (1920, 540 + 480 + 520))
            sheet.paste(label(a.resize(half, Image.LANCZOS), "antes (" + os.environ.get("ESTRADA_BASE", "302b5018") + ") ato %d %s" % (ato, NAMES[ato])), (0, 0))
            sheet.paste(label(b.resize(half, Image.LANCZOS), "depois ato %d %s" % (ato, NAMES[ato])), (960, 0))
            na, ja = crops(a)
            nb, jb = crops(b)
            sheet.paste(label(na, "antes perto 2x"), (0, 540))
            sheet.paste(label(nb, "depois perto 2x"), (960, 540))
            sheet.paste(label(ja.crop((0, 0, 960, 520)), "antes encruzilhada 2x"), (0, 1020))
            sheet.paste(label(jb.crop((0, 0, 960, 520)), "depois encruzilhada 2x"), (960, 1020))
            sheet.save(os.path.join(dst, "antes_depois_%s.png" % scene))
            n += 1
            if scene in ("fork3", "fork2", "converge"):
                own = Image.new("RGB", (1035, 584 * 2))
                own.paste(label(a.crop((443, 400, 1478, 984)), "antes " + scene), (0, 0))
                own.paste(label(b.crop((443, 400, 1478, 984)), "depois " + scene), (0, 584))
                own.save(os.path.join(dst, "enquadramento_dono_%s.png" % scene))
                n += 1
    print(OUT, n)


if __name__ == "__main__":
    sys.exit(run())
