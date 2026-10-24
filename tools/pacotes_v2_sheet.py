import os
import re
import sys

from PIL import Image, ImageDraw

KEYS = ["1_carga", "2_estouro", "3_cartas", "4_hover", "5_selecionada", "6_confirmou"]
CELL_W = 640


def prefixes(save_dir):
    rx = re.compile(r"^(pv2_[a-z]+_\d+x\d+_[a-z0-9_]+?)_(\d{3})\.png$")
    out = set()
    for f in os.listdir(save_dir):
        m = rx.match(f)
        if m:
            out.add(m.group(1))
    return sorted(out)


def frames(save_dir, prefix):
    rx = re.compile("^" + re.escape(prefix) + r"_(\d{3})\.png$")
    got = []
    for f in os.listdir(save_dir):
        m = rx.match(f)
        if m:
            got.append((int(m.group(1)), os.path.join(save_dir, f)))
    got.sort()
    return [p for _, p in got]


def key_cells(save_dir, prefix):
    cells = []
    for k in KEYS:
        p = os.path.join(save_dir, "%s_key_%s.png" % (prefix, k))
        if os.path.exists(p):
            im = Image.open(p).convert("RGB")
            h = int(im.height * CELL_W / im.width)
            cells.append((k, im.resize((CELL_W, h), Image.LANCZOS)))
            im.close()
        else:
            cells.append((k, None))
    return cells


def label(draw, x, y, text):
    draw.rectangle([x, y, x + 8 * len(text) + 10, y + 18], fill=(0, 0, 0))
    draw.text((x + 5, y + 3), text, fill=(255, 230, 160))


def sheet(save_dir, prefix, out_dir):
    cells = key_cells(save_dir, prefix)
    ch = next((c.height for _, c in cells if c is not None), 360)
    cols, rows = 3, 2
    img = Image.new("RGB", (cols * CELL_W + (cols + 1) * 6, rows * ch + (rows + 1) * 6 + 24), (20, 16, 12))
    d = ImageDraw.Draw(img)
    d.text((8, 6), prefix, fill=(255, 230, 160))
    for i, (k, c) in enumerate(cells):
        x = 6 + (i % cols) * (CELL_W + 6)
        y = 30 + (i // cols) * (ch + 6)
        if c is not None:
            img.paste(c, (x, y))
        label(d, x + 4, y + 4, k)
    path = os.path.join(out_dir, prefix[4:] + "_folha.png")
    img.save(path)
    return path


def gif(save_dir, prefix, out_dir):
    fs = frames(save_dir, prefix)
    if not fs:
        return None
    ims = []
    for p in fs:
        im = Image.open(p).convert("RGB")
        ims.append(im.convert("P", palette=Image.ADAPTIVE, colors=255))
        im.close()
    path = os.path.join(out_dir, prefix[4:] + ".gif")
    ims[0].save(path, save_all=True, append_images=ims[1:], duration=67, loop=0, optimize=False)
    return path


def compare(save_dir, res, kind, out_dir):
    a = key_cells(save_dir, "pv2_antes_%s_%s" % (res, kind))
    b = key_cells(save_dir, "pv2_depois_%s_%s" % (res, kind))
    if all(c is None for _, c in a) or all(c is None for _, c in b):
        return None
    sc = 0.5
    cw = int(CELL_W * sc)
    ch = next((int(c.height * sc) for _, c in a + b if c is not None), 180)
    img = Image.new("RGB", (len(KEYS) * (cw + 4) + 80, 2 * (ch + 4) + 28), (20, 16, 12))
    d = ImageDraw.Draw(img)
    d.text((8, 6), "%s %s  antes (cima) x depois (baixo)" % (kind, res), fill=(255, 230, 160))
    for row, cells in enumerate((a, b)):
        d.text((6, 28 + row * (ch + 4) + ch // 2), "antes" if row == 0 else "depois", fill=(255, 230, 160))
        for i, (k, c) in enumerate(cells):
            x = 76 + i * (cw + 4)
            y = 26 + row * (ch + 4)
            if c is not None:
                img.paste(c.resize((cw, ch), Image.LANCZOS), (x, y))
            if row == 0:
                d.text((x + 2, y + 2), k, fill=(255, 230, 160))
    path = os.path.join(out_dir, "comparar_%s_%s.png" % (kind, res))
    img.save(path)
    return path


def main():
    save_dir = sys.argv[1]
    out_dir = sys.argv[2] if len(sys.argv) > 2 else os.path.join("tools", "preview_out", "pacotes_v2")
    os.makedirs(out_dir, exist_ok=True)
    made = []
    for p in prefixes(save_dir):
        made.append(sheet(save_dir, p, out_dir))
        made.append(gif(save_dir, p, out_dir))
    for res in ("1920x1080", "1280x720"):
        for kind in ("standard", "buffoon", "arcana", "celestial", "spectral"):
            made.append(compare(save_dir, res, kind, out_dir))
    for m in made:
        if m:
            print(m)


if __name__ == "__main__":
    main()
