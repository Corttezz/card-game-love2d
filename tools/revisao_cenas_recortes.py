import os
import re
import sys

from PIL import Image, ImageDraw

TOP = 80
KEEP = {"mark", "landmark", "castle", "enemy", "clutter"}
PROP_KEEP = {"rock", "bush", "stump", "shrine", "flowers", "lantern", "brazier", "torch",
             "totem", "relic", "crystal", "mushroom", "fissure", "runestone", "pine", "tree",
             "deadtree", "post"}
ROW = re.compile(r"^(\w+) (\S+) (\S+) t=(-?[\d.]+) s=(-?[\d.]+) box=(-?\d+),(-?\d+),(-?\d+),(-?\d+)")


def items(txt):
    out = []
    for line in open(txt, encoding="utf-8"):
        m = ROW.match(line.strip())
        if not m:
            continue
        cat, kind, var, t, s, x1, y1, x2, y2 = m.groups()
        t = float(t)
        x1, y1, x2, y2 = int(x1), int(y1), int(x2), int(y2)
        if cat == "prop":
            if kind not in PROP_KEEP:
                continue
            if kind in ("tree", "pine", "deadtree") and t < 0.3:
                continue
            label = f"{kind}{var}"
        elif cat in KEEP:
            label = f"{cat}:{kind}"
        else:
            continue
        out.append((label, t, x1, y1, x2, y2))
    return out


def crop_base(img, it):
    label, t, x1, y1, x2, y2 = it
    W, H = img.size
    w, h = max(1, x2 - x1), max(1, y2 - y1)
    if y2 < TOP + 10 or y2 > H + h * 0.1 or x2 < 0 or x1 > W or h < 18:
        return None
    cx = (x1 + x2) / 2
    hw = max(w * 0.8, 50)
    top = y2 - max(h * 0.45, 36)
    bot = y2 + max(h * 0.22, 28)
    box = (int(max(0, cx - hw)), int(max(TOP, top)), int(min(W, cx + hw)), int(min(H, bot)))
    if box[2] - box[0] < 8 or box[3] - box[1] < 8:
        return None
    c = img.crop(box)
    k = max(1, min(4, int(380 / max(c.size[0], 1))))
    if k > 1:
        c = c.resize((c.size[0] * k, c.size[1] * k), Image.NEAREST)
    return c, k


def sheet(crops, path):
    pad = 6
    cols = 4
    rows = [crops[i:i + cols] for i in range(0, len(crops), cols)]
    cw = 0
    rh = []
    for r in rows:
        cw = max(cw, sum(c.size[0] for _, c, _ in r) + pad * (len(r) + 1))
        rh.append(max(c.size[1] for _, c, _ in r) + 22)
    out = Image.new("RGB", (max(cw, 200), sum(rh) + pad * (len(rows) + 1)), (30, 30, 34))
    d = ImageDraw.Draw(out)
    y = pad
    for r, h in zip(rows, rh):
        x = pad
        for label, c, k in r:
            d.text((x, y), f"{label} x{k}", fill=(255, 230, 120))
            out.paste(c, (x, y + 16))
            x += c.size[0] + pad
        y += h + pad
    out.save(path)


def main(src, dst, only=None):
    os.makedirs(dst, exist_ok=True)
    for name in sorted(os.listdir(src)):
        if not name.endswith(".png"):
            continue
        stem = name[:-4]
        if only and not re.search(only, stem):
            continue
        txt = os.path.join(src, stem + ".txt")
        if not os.path.exists(txt):
            continue
        img = Image.open(os.path.join(src, name)).convert("RGB")
        crops = []
        for it in items(txt):
            r = crop_base(img, it)
            if r:
                crops.append((it[0] + f" t{it[1]:.2f}", r[0], r[1]))
        if crops:
            p = os.path.join(dst, stem + "_bases.png")
            sheet(crops, p)
            print(p)




def box_of(txt, prefix):
    for line in open(txt, encoding="utf-8"):
        m = ROW.match(line.strip())
        if m and line.startswith(prefix):
            return tuple(int(v) for v in m.groups()[5:9])
    return None


def stack(parts, path, cols=2):
    pad = 6
    rows = [parts[i:i + cols] for i in range(0, len(parts), cols)]
    W = max(sum(p.size[0] for _, p in r) + pad * (len(r) + 1) for r in rows)
    Hs = [max(p.size[1] for _, p in r) + 18 for r in rows]
    out = Image.new("RGB", (W, sum(Hs) + pad * (len(rows) + 1)), (30, 30, 34))
    d = ImageDraw.Draw(out)
    y = pad
    for r, h in zip(rows, Hs):
        x = pad
        for label, p in r:
            d.text((x, y), label, fill=(255, 230, 120))
            out.paste(p, (x, y + 14))
            x += p.size[0] + pad
        y += h + pad
    out.save(path)
    print(path)


def folhas(src, dst):
    os.makedirs(dst, exist_ok=True)
    parts = []
    for kind in ("battle", "elite", "shop", "event", "rest"):
        for tod in ("65", "85"):
            stem = f"lm_{kind}_tod{tod}"
            txt = os.path.join(src, stem + ".txt")
            if not os.path.exists(txt):
                continue
            b = box_of(txt, "landmark")
            if not b:
                continue
            img = Image.open(os.path.join(src, stem + ".png")).convert("RGB")
            x1, y1, x2, y2 = b
            h = y2 - y1
            c = img.crop((max(0, x1 - 70), max(80, y2 - int(h * 0.55)), min(1920, x2 + 70), min(1080, y2 + 70)))
            c.save(os.path.join(dst, stem + "_base.png"))
            parts.append((stem, c))
    if parts:
        stack(parts, os.path.join(dst, "folha_landmarks.png"))
    parts = []
    for stem in sorted(os.listdir(src)):
        if stem.startswith("fork") and stem.endswith(".png"):
            img = Image.open(os.path.join(src, stem)).convert("RGB")
            c = img.crop((540, 420, 1400, 700))
            c.save(os.path.join(dst, stem[:-4] + "_marcos.png"))
            parts.append((stem[:-4], c))
    if parts:
        stack(parts, os.path.join(dst, "folha_marcos.png"), cols=1)


def viagem(src, dst):
    os.makedirs(dst, exist_ok=True)
    frames = sorted(n for n in os.listdir(src) if n.startswith("viagem_") and n.endswith(".png"))
    if not frames:
        return
    k = 4
    w, h = 1920 // k, 1000 // k
    cols = 4
    rows = (len(frames) + cols - 1) // cols
    out = Image.new("RGB", (cols * (w + 4), rows * (h + 16)), (30, 30, 34))
    d = ImageDraw.Draw(out)
    for i, n in enumerate(frames):
        im = Image.open(os.path.join(src, n)).convert("RGB").crop((0, 80, 1920, 1080)).resize((w, h), Image.LANCZOS)
        x, y = (i % cols) * (w + 4), (i // cols) * (h + 16)
        d.text((x, y), n[:-4], fill=(255, 230, 120))
        out.paste(im, (x, y + 14))
    p = os.path.join(dst, "folha_viagem.jpg")
    out.save(p, quality=88)
    print(p)



if __name__ == "__main__":
    if sys.argv[1] == "folhas":
        folhas(sys.argv[2], sys.argv[3])
        viagem(sys.argv[2], sys.argv[3])
    else:
        main(sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else None)
