"""Imagem de compartilhamento (OG) 1200x630 da v3: a tela de título do jogo (capela do menu, selo e logotipo),
montada com a arte do próprio jogo em escala inteira. A mesma imagem vale para os 5 idiomas (não tem texto traduzível).
uso: python -X utf8 tools/og.py
"""
import os

from PIL import Image, ImageDraw

SITE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
V3 = os.path.join(SITE, "public", "img", "v3")
OUT = os.path.join(SITE, "public", "img", "og")
W, H = 1200, 630

scene = Image.open(os.path.join(V3, "menu.png")).convert("RGBA")
k = 3
big = scene.resize((scene.width * k, scene.height * k), Image.NEAREST)
x0 = (big.width - W) // 2
y0 = big.height - H - 30
base = big.crop((x0, y0, x0 + W, y0 + H))
shade = Image.new("RGBA", (W, H), (0, 0, 0, 0))
d = ImageDraw.Draw(shade)
for y in range(H):
    d.line([(0, y), (W, y)], fill=(8, 6, 10, int(120 * max(0, 1 - y / (H * 0.6)))))
base.alpha_composite(shade)
seal = Image.open(os.path.join(V3, "seal.png")).convert("RGBA")
word = Image.open(os.path.join(V3, "wordmark.png")).convert("RGBA")
word = word.resize((word.width * 2, word.height * 2), Image.NEAREST)
base.alpha_composite(seal, ((W - seal.width) // 2, 40))
base.alpha_composite(word, ((W - word.width) // 2, 40 + seal.height + 12))
os.makedirs(OUT, exist_ok=True)
for code in ["en", "pt_BR", "es", "fr", "de"]:
    base.convert("RGB").save(os.path.join(OUT, f"og_{code}.png"), optimize=True)
print("og ok")
