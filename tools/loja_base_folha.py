import os
import sys

from PIL import Image, ImageDraw

SAVE = os.path.join(os.environ.get("APPDATA", ""), "LOVE", "lojabase", "loja_base")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "tools/preview_out/loja_base")


def tile(path, h):
    if not os.path.exists(path):
        return Image.new("RGB", (h, h), (60, 0, 60))
    im = Image.open(path).convert("RGB")
    k = h / im.height
    return im.resize((max(1, int(im.width * k)), h), Image.NEAREST)


def folha(antes, depois, act):
    rows = []
    for name in ("fork_shop_base", "lm_shop_base", "fork_event_base", "lm_event_base"):
        h = 300 if name.startswith("fork") else 420
        a = tile(os.path.join(SAVE, antes, f"ato{act}", name + ".png"), h)
        b = tile(os.path.join(SAVE, depois, f"ato{act}", name + ".png"), h)
        rows.append((name, a, b))
    W = max(a.width + b.width for _, a, b in rows) + 30
    H = sum(a.height + 22 for _, a, _ in rows)
    out = Image.new("RGB", (W, H), (24, 20, 18))
    d = ImageDraw.Draw(out)
    y = 0
    for name, a, b in rows:
        d.text((6, y + 4), f"ato {act} {name}: antes | depois", fill=(240, 220, 170))
        out.paste(a, (6, y + 20))
        out.paste(b, (a.width + 20, y + 20))
        y += a.height + 22
    p = os.path.join(OUT, f"ato{act}_antes_depois.png")
    out.save(p)
    print(p)
    for name in ("fork_shop", "lm_shop", "fork_event", "lm_event"):
        src = os.path.join(SAVE, depois, f"ato{act}", name + ".png")
        if os.path.exists(src):
            Image.open(src).convert("RGB").save(os.path.join(OUT, f"ato{act}_{name}_depois.png"))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    antes, depois = sys.argv[1], sys.argv[2]
    for act in sys.argv[3:] or ["1", "2", "3", "4", "5", "6"]:
        folha(antes, depois, act)
