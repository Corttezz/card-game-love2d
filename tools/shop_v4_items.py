"""
tools/shop_v4_items.py: guias e pedidos das artes NOVAS da mesa (Loja v4):
o elixir (health_upgrade) e os 5 pacotes, desenhados JÁ na diagonal 1:8 da
mesa (a face sobe 1 px a cada 8 px pra direita), mesma identidade das artes
antigas (vouchers/health_upgrade.png, packs/pack_*.png).

Para cada item: guia = a arte antiga reduzida pro tamanho da mesa, com a face
cisalhada em degraus INTEIROS de 1:8 e a lombada (espessura) à esquerda; o
create_image_pro recebe a antiga (identidade) + a guia (pose) e devolve 16
candidatas (canvas <= 85 px).
"""
import base64
import io
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RUN = 8

PACKS = {
    "pack_standard": "parchment-wrapped bundle of cards tied with dark string crossing on the front, red wax seal in the middle",
    "pack_arcana": "deep blue book-like card pack with a golden eye emblem in the middle and a purple ribbon crossing it",
    "pack_buffoon": "dark red card pack with a golden horned jester mask emblem and dark straps crossing it",
    "pack_celestial": "dark navy card pack with silver metal corners, a golden crescent moon and stars emblem, tied with brown string",
    "pack_spectral": "pale green card pack with a darker green skull emblem and dark thorny vines wrapped around it",
}

ITEM_STYLE = ("pixel art game item, standing upright on a wooden table, the object is "
              "turned so its front face runs along the table edge that rises to the "
              "right (one pixel up every eight pixels), the left side shows a little "
              "of its thickness, lit warmly from the upper left, crisp 1px dark "
              "outline, no anti-aliasing, limited sepia palette, transparent "
              "background, nothing else in the picture, no table, no shadow plate, "
              "no candle, no text")


def _crop(im):
    bb = im.getbbox()
    return im.crop(bb) if bb else im


def shear18(im):
    """Cisalhamento INTEIRO 1:8: a coluna x sobe floor(x/8) px (sem reamostrar)."""
    from PIL import Image
    w, h = im.size
    lift = (w - 1) // RUN
    out = Image.new("RGBA", (w, h + lift), (0, 0, 0, 0))
    for x in range(w):
        col = im.crop((x, 0, x + 1, h))
        out.paste(col, (x, lift - x // RUN))
    return out


def pack_guide(src, face_h=60):
    """Arte antiga reduzida (altura da face), cisalhada 1:8 + lombada à esquerda."""
    from PIL import Image
    im = _crop(Image.open(src).convert("RGBA"))
    w, h = im.size
    fw = max(8, round(w * face_h / h))
    face = im.resize((fw, face_h), Image.BOX)
    # lombada: 3 colunas mais escuras da cor da borda esquerda
    spine = 3
    out = Image.new("RGBA", (fw + spine, face_h), (0, 0, 0, 0))
    out.paste(face, (spine, 0), face)
    px = out.load()
    for y in range(face_h):
        r, g, b, a = face.getpixel((min(2, fw - 1), y))
        for x in range(spine):
            k = 0.45 + 0.1 * x
            px[x, y] = (int(r * k), int(g * k), int(b * k), a)
    sh = shear18(out)
    canvas = Image.new("RGBA", (64, 80), (0, 0, 0, 0))
    canvas.paste(sh, ((64 - sh.size[0]) // 2, 80 - sh.size[1] - 2), sh)
    return canvas


def _b64img(im):
    buf = io.BytesIO()
    im.save(buf, "PNG")
    return base64.b64encode(buf.getvalue()).decode()


def specs(raw):
    from PIL import Image
    out = {}
    gdir = os.path.join(raw, "guides")
    os.makedirs(gdir, exist_ok=True)
    for pid, desc in PACKS.items():
        src = os.path.join(ROOT, "assets/sprites/packs", pid + ".png")
        g = pack_guide(src)
        g.save(os.path.join(gdir, pid + "_guide.png"))
        old = _crop(Image.open(src).convert("RGBA"))
        out[pid] = ("create_image_pro", {
            "description": "card booster pack: " + desc + ". " + ITEM_STYLE,
            "width": 64, "height": 80, "no_background": True,
            "reference_images": [
                {"base64": _b64img(old), "usage": "identity: the same pack, same colours, same emblem and straps"},
                {"base64": _b64img(g), "usage": "pose, size and angle: upright pack, face slanted rising to the right, thin left side visible"},
            ],
        })
    src = os.path.join(ROOT, "assets/sprites/vouchers/health_upgrade.png")
    old = Image.open(src).convert("RGBA")
    out["health_upgrade"] = ("create_image_pro", {
        "description": ("small round glass potion bottle of red elixir with a cork, "
                        "a parchment label with a golden cross, turned a little to the "
                        "right so the label wraps around the bottle, flat round base "
                        "seen slightly from above. " + ITEM_STYLE),
        "width": 64, "height": 64, "no_background": True,
        "reference_images": [
            {"base64": _b64img(old), "usage": "identity: the same bottle, cork, red liquid and label with the golden cross"},
        ],
    })
    return out
