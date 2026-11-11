"""Imagens de compartilhamento (OG) 1200x630, uma por idioma, com a arte do jogo.
uso: python -X utf8 tools/og.py
"""
import json
import os

from PIL import Image, ImageDraw, ImageFont

SITE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PUB = os.path.join(SITE, "public")
G = json.load(open(os.path.join(SITE, "src/data/game.json"), encoding="utf-8"))
FONT = "E:/dev/projects/card-game-love2d/assets/fonts/pixel.ttf"
W, H = 1200, 630


def img(rel):
    return Image.open(os.path.join(PUB, rel.lstrip("/"))).convert("RGBA")


def cover(im, w, h):
    k = max(w / im.width, h / im.height)
    big = im.resize((round(im.width * k), round(im.height * k)), Image.NEAREST)
    x, y = (big.width - w) // 2, big.height - h
    return big.crop((x, y, x + w, y + h))


b = next(x for x in G["biomes"] if x["id"] == "dusk")
base = cover(img(b["mtn"]["src"]), W, H)
if b.get("mtnFront"):
    base.alpha_composite(cover(img(b["mtnFront"]["src"]), W, H))
shade = Image.new("RGBA", (W, H), (10, 6, 14, 0))
d = ImageDraw.Draw(shade)
for y in range(H):
    a = int(150 * max(0, 1 - y / (H * 0.55)))
    d.line([(0, y), (W, y)], fill=(10, 6, 14, a))
base.alpha_composite(shade)
castle = img(b["castle"]["src"])
castle = castle.resize((castle.width * 2, castle.height * 2), Image.NEAREST)
base.alpha_composite(castle, ((W - castle.width) // 2, H - castle.height - 6))
wm = img(G["brand"]["wordmark"]["src"])
wm = wm.resize((wm.width * 3, wm.height * 3), Image.NEAREST)
base.alpha_composite(wm, ((W - wm.width) // 2, 40))
os.makedirs(os.path.join(PUB, "img/og"), exist_ok=True)
font = ImageFont.truetype(FONT, 24)
for code in ["en", "pt_BR", "es", "fr", "de"]:
    im = base.copy()
    dr = ImageDraw.Draw(im)
    txt = G["ui"]["subtitle"][code]
    tw = dr.textlength(txt, font=font)
    x, y = (W - tw) / 2, 40 + wm.height + 20
    for dx, dy in ((2, 2), (0, 2), (2, 0)):
        dr.text((x + dx, y + dy), txt, font=font, fill=(0, 0, 0, 255))
    dr.text((x, y), txt, font=font, fill=(245, 230, 200, 255))
    im.convert("RGB").save(os.path.join(PUB, f"img/og/og_{code}.png"), optimize=True)
print("og ok")

# papel de parede do segredo Eclipse: arte nova (art/gen) ampliada 3x sem suavizar
wp = Image.open(os.path.join(SITE, "art/gen/eclipse_wallpaper.png")).convert("RGB")
wp.resize((wp.width * 3, wp.height * 3), Image.NEAREST).save(os.path.join(PUB, "img/eclipse_wallpaper_3x.png"), optimize=True)
print("wallpaper ok")
