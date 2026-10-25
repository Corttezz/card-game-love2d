import os
import re
import sys

from PIL import Image, ImageDraw

SAVE = os.path.join(os.environ.get("APPDATA", ""), "LOVE", os.environ.get("CARDGAME_IDENTITY", "estrada_fluxo"),
                    "estrada_fluxo", os.environ.get("SEQ_RES", "1920x1080"), "full")
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "preview_out", "curva_castelo")
PAT = re.compile(r"^(ato\d+_[\w]+?)_(\d{4})_(\w+)\.png$")


def frames():
    by = {}
    if not os.path.isdir(SAVE):
        return by
    for f in sorted(os.listdir(SAVE)):
        m = PAT.match(f)
        if m:
            by.setdefault(m.group(1), []).append((int(m.group(2)), m.group(3), os.path.join(SAVE, f)))
    return by


def pick(lst, n):
    if len(lst) <= n:
        return lst
    return [lst[round(i * (len(lst) - 1) / (n - 1))] for i in range(n)]


def sheet(items, dst, title, tw=480, cols=4):
    ims = []
    for n, ph, p in items:
        im = Image.open(p).convert("RGB")
        im = im.resize((tw, int(tw * im.height / im.width)), Image.LANCZOS)
        d = ImageDraw.Draw(im)
        d.rectangle((0, 0, 150, 14), fill=(0, 0, 0))
        d.text((3, 1), "%s f%d" % (ph, n), fill=(255, 255, 255))
        ims.append(im)
    if not ims:
        return None
    th = ims[0].height
    rows = (len(ims) + cols - 1) // cols
    out = Image.new("RGB", (cols * tw, rows * th + 18), (0, 0, 0))
    ImageDraw.Draw(out).text((4, 3), title, fill=(255, 255, 0))
    for i, im in enumerate(ims):
        out.paste(im, ((i % cols) * tw, 18 + (i // cols) * th))
    out.save(dst, quality=82)
    return dst


def gif(items, dst, tw=640):
    ims = []
    for _, _, p in items:
        im = Image.open(p).convert("RGB")
        ims.append(im.resize((tw, int(tw * im.height / im.width)), Image.LANCZOS).quantize(colors=128))
    if ims:
        ims[0].save(dst, save_all=True, append_images=ims[1:], duration=100, loop=0)
    return dst


def pair(left, right, dst, title, n=8, tw=640):
    if not left or not right:
        return None
    a, b = pick(left, n), pick(right, n)
    rows = min(len(a), len(b))
    th = int(tw * 1080 / 1920)
    out = Image.new("RGB", (2 * tw, rows * th + 18), (0, 0, 0))
    ImageDraw.Draw(out).text((4, 3), title, fill=(255, 255, 0))
    for r in range(rows):
        for c, (n_, ph, p) in enumerate((a[r], b[r])):
            im = Image.open(p).convert("RGB").resize((tw, th), Image.LANCZOS)
            d = ImageDraw.Draw(im)
            d.rectangle((0, 0, 230, 14), fill=(0, 0, 0))
            d.text((3, 1), "%s %s f%d" % ("raso" if c == 0 else "fechado", ph, n_), fill=(255, 255, 255))
            out.paste(im, (c * tw, 18 + r * th))
    out.save(dst, quality=82)
    return dst


def run():
    want = sys.argv[1] if len(sys.argv) > 1 else ""
    gif_tag = sys.argv[2] if len(sys.argv) > 2 else ""
    os.makedirs(OUT, exist_ok=True)
    made = []
    for tag, lst in frames().items():
        if want and not tag.startswith(want):
            continue
        turn = [x for x in lst if x[1] == "converge"]
        back = [x for x in lst if x[1] in ("partida", "viagem")]
        nxt = [x for x in lst if x[1] == "forkB"][:2]
        a = sheet(pick(turn, 12), os.path.join(OUT, "curva_%s.jpg" % tag), "%s: curva (escolha do ramo)" % tag)
        b = sheet(pick(back, 14) + nxt, os.path.join(OUT, "volta_%s.jpg" % tag), "%s: volta a trilha" % tag)
        made += [p for p in (a, b) if p]
        if tag.endswith("_3_loja"):
            raso = frames().get(tag.replace("_3_loja", "_3_descanso"), [])
            seq = lambda lst: [x for x in lst if x[1] in ("converge", "partida")]
            made.append(pair(seq(raso), seq(lst), os.path.join(OUT, "comparar_%s.jpg" % tag.split("_")[0]),
                             "%s: curva rasa (esq.) x curva fechada (dir.)" % tag.split("_")[0]))
        if gif_tag and tag == gif_tag:
            made.append(gif(turn + back + nxt, os.path.join(OUT, "curva_%s.gif" % tag)))
    for p in made:
        if p:
            print(p)


if __name__ == "__main__":
    sys.exit(run())
