"""Arte, shaders, sons e textos da ABERTURA do jogo (v3b), copiados do jogo sem redesenhar.
Os shaders vão verbatim para src/shaders (o site os executa em WebGL com a mesma matemática).
Texturas de dados (seal_data, wordmark_gold) ficam em img/v3b/raw e não viram WebP.
uso: python -X utf8 tools/v3b_assets.py"""
import json
import os
import re
import shutil
import subprocess

from PIL import Image

GAME = "E:/dev/projects/card-game-love2d"
SITE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IMG = os.path.join(SITE, "public", "img", "v3b")
RAW = os.path.join(IMG, "raw")
MED = os.path.join(SITE, "public", "media", "v3b")
SH = os.path.join(SITE, "src", "shaders")
for d in (IMG, RAW, MED, SH):
    os.makedirs(d, exist_ok=True)


def cp(src, dst, folder=IMG):
    shutil.copyfile(os.path.join(GAME, src), os.path.join(folder, dst))


cp("assets/sprites/intro/computer.png", "computer.png")
cp("assets/sprites/scenes/boot_anim/frame_00.png", "chamber.png")
cp("assets/sprites/scenes/boot_anim/clouds.png", "clouds.png")
for f in ["menu", "menu_normal", "menu_1", "menu_2"]:
    cp(f"assets/sprites/scenes/{f}.png", f"{f}.png")
for i in (1, 2, 3):
    cp(f"assets/effects/smoke{i}.png", f"smoke{i}.png")
cp("assets/branding/seal.png", "seal.png")
cp("assets/branding/wordmark.png", "wordmark.png")
cp("assets/branding/seal_data.png", "seal_data.png", RAW)
cp("assets/branding/wordmark_gold.png", "wordmark_gold.png", RAW)

# verso da carta com os cantos arredondados como o CardBack.lua faz ao carregar (raio 5)
back = Image.open(os.path.join(GAME, "assets/cards/back.png")).convert("RGBA")
w, h, r = back.width, back.height, 5
px = back.load()
for cx, cy, bx, by in [(r, r, 0, 0), (w - 1 - r, r, w - r, 0), (r, h - 1 - r, 0, h - r), (w - 1 - r, h - 1 - r, w - r, h - r)]:
    for x in range(bx, bx + r):
        for y in range(by, by + r):
            if (x - cx) ** 2 + (y - cy) ** 2 > r * r:
                px[x, y] = (0, 0, 0, 0)
back.save(os.path.join(IMG, "back.png"))

for f in ["crt", "boot_seal_glow", "boot_star_twinkle", "boot_moon_vortex", "brand_seal", "brand_word", "brand_fx"]:
    shutil.copyfile(os.path.join(GAME, "shaders", f + ".glsl"), os.path.join(SH, f + ".glsl"))

for f in ["boot-card-whoosh", "boot-tv-power-on", "boot-vortex", "boot-electric", "boot-impact", "card-draw", "button-click"]:
    shutil.copyfile(os.path.join(GAME, "audio/sfx", f + ".mp3"), os.path.join(MED, f + ".mp3"))
for i in range(1, 7):
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", os.path.join(GAME, f"audio/sfx/narrator/blip_{i}.wav"), "-ac", "1", "-b:a", "64k",
                    os.path.join(MED, f"blip_{i}.mp3")], check=True)

# textos da abertura em cada idioma, direto dos arquivos do jogo
out = {}
for code in ["en", "pt_BR", "es", "fr", "de"]:
    src = open(os.path.join(GAME, f"src/i18n/locales/{code}.lua"), encoding="utf8").read()
    boot = re.search(r"boot\s*=\s*\{(.*?)\}", src, re.S).group(1)
    menu = re.search(r"menu\s*=\s*\{(.*?)\}", src, re.S).group(1)
    g = lambda blk, k: re.search(k + r'\s*=\s*"((?:[^"\\]|\\.)*)"', blk).group(1)
    out[code] = {"loading": g(boot, "loading"), "skip": g(boot, "skip_hint"), "title": g(menu, "title"), "subtitle": g(menu, "subtitle")}
ver = re.search(r'Config.VERSION\s*=\s*"([^"]+)"', open(os.path.join(GAME, "src/core/Config.lua"), encoding="utf8").read()).group(1)
json.dump({"version": ver, "t": out}, open(os.path.join(SITE, "src", "data", "boot_i18n.json"), "w", encoding="utf8"), ensure_ascii=False, indent=1)
print(json.dumps(out, ensure_ascii=False)[:400], ver)
