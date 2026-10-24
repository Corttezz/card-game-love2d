import os
import re
import sys

from PIL import Image, ImageDraw

SAVE = os.path.join(os.environ.get("APPDATA", ""), "LOVE", os.environ.get("CARDGAME_IDENTITY", "estrada_fluxo"),
                    "estrada_fluxo")
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "preview_out", "estrada_fluxo")


def flagged(path):
    out = {}
    if not os.path.exists(path):
        return out
    for line in open(path, encoding="utf-8"):
        parts = line.split(" ")
        if parts and parts[0].isdigit():
            out[int(parts[0])] = parts[2] + ":" + parts[3]
    return out


def sheet(rdir, dst, tag, tw=320, cols=8, every=2):
    tdir = os.path.join(rdir, "thumbs")
    files = sorted(f for f in os.listdir(tdir) if f.startswith(tag + "_"))
    if not files:
        return None
    fl = flagged(os.path.join(rdir, tag + "_flags.txt"))
    ims = []
    for i, f in enumerate(files):
        n = int(re.search(r"_(\d+)\.png$", f).group(1))
        hit = any(abs(n - k) <= 2 for k in fl)
        if i % every and not hit:
            continue
        im = Image.open(os.path.join(tdir, f)).convert("RGB")
        im = im.resize((tw, int(tw * im.height / im.width)), Image.LANCZOS)
        if hit:
            d = ImageDraw.Draw(im)
            d.rectangle((0, 0, im.width - 1, im.height - 1), outline=(255, 0, 0), width=3)
        ims.append(im)
    th = ims[0].height
    rows = (len(ims) + cols - 1) // cols
    out = Image.new("RGB", (cols * tw, rows * th))
    for i, im in enumerate(ims):
        out.paste(im, ((i % cols) * tw, (i // cols) * th))
    p = os.path.join(dst, "folha_%s.jpg" % tag)
    out.save(p, quality=70)
    return p


def keys(rdir, dst, tag, tw=640):
    kdir = os.path.join(rdir, "chave")
    if not os.path.isdir(kdir):
        return None
    files = sorted(f for f in os.listdir(kdir) if f.startswith(tag + "_"))
    if not files:
        return None
    ims = []
    for f in files:
        im = Image.open(os.path.join(kdir, f)).convert("RGB")
        im = im.resize((tw, int(tw * im.height / im.width)), Image.LANCZOS)
        d = ImageDraw.Draw(im)
        d.rectangle((0, 0, 200, 16), fill=(0, 0, 0))
        d.text((4, 2), f[len(tag) + 1:-4], fill=(255, 255, 255))
        ims.append(im)
    cols = 4
    th = ims[0].height
    rows = (len(ims) + cols - 1) // cols
    out = Image.new("RGB", (cols * tw, rows * th))
    for i, im in enumerate(ims):
        out.paste(im, ((i % cols) * tw, (i // cols) * th))
    p = os.path.join(dst, "momentos_%s.jpg" % tag)
    out.save(p, quality=80)
    return p


def run():
    want = sys.argv[1] if len(sys.argv) > 1 else ""
    n = 0
    for res in os.listdir(SAVE):
        rdir = os.path.join(SAVE, res)
        if not os.path.isdir(os.path.join(rdir, "thumbs")):
            continue
        dst = os.path.join(OUT, res)
        os.makedirs(dst, exist_ok=True)
        tags = sorted({f.rsplit("_", 1)[0] for f in os.listdir(os.path.join(rdir, "thumbs"))})
        for tag in tags:
            if want and not tag.startswith(want):
                continue
            if sheet(rdir, dst, tag):
                n += 1
            keys(rdir, dst, tag)
        for f in os.listdir(rdir):
            if f.endswith("_flags.txt") or f == "resumo.txt":
                with open(os.path.join(rdir, f), "rb") as a, open(os.path.join(dst, f), "wb") as b:
                    b.write(a.read())
    print(OUT, n)


if __name__ == "__main__":
    sys.exit(run())
