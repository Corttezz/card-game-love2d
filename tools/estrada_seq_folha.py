import os
import re
import shutil
import sys

from PIL import Image, ImageDraw

SAVE = os.path.join(os.environ.get("APPDATA", ""), "LOVE", os.environ.get("CARDGAME_IDENTITY", "estrada_seq"),
                    "estrada_seq")
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "preview_out", "estrada_seq")


def flagged(flags_path):
    out = {}
    if not os.path.exists(flags_path):
        return out
    for line in open(flags_path, encoding="utf-8"):
        parts = line.split(" ")
        if parts and parts[0].isdigit():
            out[int(parts[0])] = parts[2] + ":" + parts[3]
    return out


def sheet(res, tag, tw=256, cols=12, per=144):
    tdir = os.path.join(SAVE, res, "thumbs")
    files = sorted(f for f in os.listdir(tdir) if f.startswith(tag + "_"))
    if not files:
        return None
    fl = flagged(os.path.join(SAVE, res, tag + "_flags.txt"))
    ims = []
    for f in files:
        n = int(re.search(r"_(\d+)\.png$", f).group(1))
        im = Image.open(os.path.join(tdir, f)).convert("RGB")
        if im.width != tw:
            im = im.resize((tw, int(tw * im.height / im.width)), Image.LANCZOS)
        if any(abs(n - k) <= 1 for k in fl):
            d = ImageDraw.Draw(im)
            d.rectangle((0, 0, im.width - 1, im.height - 1), outline=(255, 0, 0), width=3)
        ims.append(im)
    th = ims[0].height
    dst = os.path.join(OUT, res)
    os.makedirs(dst, exist_ok=True)
    p = None
    for page in range(0, len(ims), per):
        chunk = ims[page:page + per]
        rows = (len(chunk) + cols - 1) // cols
        out = Image.new("RGB", (cols * tw, rows * th))
        for i, im in enumerate(chunk):
            out.paste(im, ((i % cols) * tw, (i // cols) * th))
        p = os.path.join(dst, "folha_%s_p%d.jpg" % (tag, page // per + 1))
        out.save(p, quality=72)
    return p


def run():
    n = 0
    for res in os.listdir(SAVE):
        rdir = os.path.join(SAVE, res)
        if not os.path.isdir(os.path.join(rdir, "thumbs")):
            continue
        tags = sorted({f.rsplit("_", 1)[0] for f in os.listdir(os.path.join(rdir, "thumbs"))})
        for tag in tags:
            if sheet(res, tag):
                n += 1
        dst = os.path.join(OUT, res)
        os.makedirs(dst, exist_ok=True)
        for f in os.listdir(rdir):
            if f.endswith("_flags.txt") or f == "resumo.txt":
                shutil.copy(os.path.join(rdir, f), os.path.join(dst, f))
    print(OUT, n)


if __name__ == "__main__":
    sys.exit(run())
