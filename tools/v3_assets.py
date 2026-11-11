"""Arte e som da tela de título (v3), copiados do jogo sem redesenhar. uso: python -X utf8 tools/v3_assets.py"""
import os
import shutil
import subprocess

from PIL import Image

GAME = "E:/dev/projects/card-game-love2d"
SITE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IMG = os.path.join(SITE, "public", "img", "v3")
MED = os.path.join(SITE, "public", "media", "v3")
os.makedirs(IMG, exist_ok=True)
os.makedirs(MED, exist_ok=True)

def cp(src, dst):
    shutil.copyfile(os.path.join(GAME, src), os.path.join(IMG, dst))
    return Image.open(os.path.join(IMG, dst)).size

out = {}
# a cena do menu: os 4 quadros que o jogo alterna a 10 fps (a chama das velas)
for f in ["menu", "menu_normal", "menu_1", "menu_2"]:
    out[f] = cp(f"assets/sprites/scenes/{f}.png", f"{f}.png")
out["back"] = cp("assets/cards/back.png", "back.png")
out["seal"] = cp("assets/branding/seal.png", "seal.png")
out["wordmark"] = cp("assets/branding/wordmark.png", "wordmark.png")
out["panel"] = cp("assets/sprites/ui/panel_main.png", "panel.png")
# como o Panel9 do jogo: recorta a moldura (margem 26, desenhada em 2x)
_p = Image.open(os.path.join(IMG, "panel.png")).convert("RGBA")
_p.crop(_p.getbbox()).save(os.path.join(IMG, "panel.png"))
out["panel"] = Image.open(os.path.join(IMG, "panel.png")).size
out["ach"] = cp("assets/sprites/achievements/primeira_pagina.png", "ach.png")
out["ach_locked"] = cp("assets/sprites/achievements/primeira_pagina_locked.png", "ach_locked.png")
# sons do próprio jogo (só tocam com o som ligado)
for f in ["button-click", "menu-hover", "menu-open", "menu-close", "card-discovered"]:
    shutil.copyfile(os.path.join(GAME, "audio/sfx", f + ".mp3"), os.path.join(MED, f + ".mp3"))
# música do menu, mais leve para a web (mono 96 kbps)
subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", os.path.join(GAME, "audio/music.mp3"), "-ac", "1", "-b:a", "96k", os.path.join(MED, "menu.mp3")], check=True)
# cor média da primeira e da última linha da cena (o site usa para prolongar a parede no celular)
import json
_m = Image.open(os.path.join(IMG, "menu.png")).convert("RGB")
def _avg(y0):
    px = [_m.getpixel((x, y)) for x in range(_m.width) for y in range(y0, y0 + 4)]
    return "#%02x%02x%02x" % tuple(sum(p[i] for p in px) // len(px) for i in range(3))
json.dump({"top": _avg(0), "bottom": _avg(_m.height - 4)}, open(os.path.join(SITE, "src", "data", "scene_colors.json"), "w"))
for k, v in out.items():
    print(k, v)
print("menu.mp3", round(os.path.getsize(os.path.join(MED, "menu.mp3")) / 1e6, 2), "MB")
