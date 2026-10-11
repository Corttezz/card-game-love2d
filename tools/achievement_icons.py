# tools/achievement_icons.py
# Pipeline dos emblemas de conquista (uma receita so pro jogo e pra Steam).
#
#   python -I tools/achievement_icons.py import <dir>   copia <dir>/<id>.png
#        (64x64 RGBA vindos do PixelLab) pra assets/sprites/achievements/
#   python -I tools/achievement_icons.py locked         deriva <id>_locked.png
#   python -I tools/achievement_icons.py steam          exporta 256x256 pra
#        steam/achievements/icons/<API>.png e <API>_locked.png
#   python -I tools/achievement_icons.py all <dir>      os tres em sequencia
#
# BLOQUEADA = o MESMO emblema dessaturado e escurecido (silhueta legivel), nao
# um cadeado generico: o jogador reconhece o alvo antes de conquistar — a
# conquista e objetivo, nao segredo (secretas ganham "?" por cima NA UI).
#
# STEAM: 256x256, ampliacao NEAREST x4 (pixel art nao pode borrar), sobre o
# fundo INK do jogo (sem alpha — a Steam desenha o icone em fundos variados e
# transparencia vira halo). Ver memory/steam_achievements.md.

import os
import re

import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSET_DIR = os.path.join(ROOT, "assets", "sprites", "achievements")
STEAM_DIR = os.path.join(ROOT, "steam", "achievements", "icons")
INK = (26, 15, 8)          # Palette.INK #1a0f08
SIZE = 64
STEAM_SIZE = 256


def catalog():
    src = open(os.path.join(ROOT, "src", "data", "achievements.lua"), encoding="utf-8").read()
    return [(m.group(1), m.group(2)) for m in
            re.finditer(r'id\s*=\s*"([a-z0-9_]+)",\s*steam\s*=\s*"([A-Z0-9_]+)"', src)]


def do_import(srcdir):
    os.makedirs(ASSET_DIR, exist_ok=True)
    missing = []
    for aid, _ in catalog():
        p = os.path.join(srcdir, aid + ".png")
        if not os.path.exists(p):
            missing.append(aid)
            continue
        im = Image.open(p).convert("RGBA")
        if im.size != (SIZE, SIZE):
            im = im.resize((SIZE, SIZE), Image.NEAREST)
        im.save(os.path.join(ASSET_DIR, aid + ".png"))
    if missing:
        print("AVISO: sem emblema na origem:", ", ".join(missing))
    print("import ok")


def locked_of(im):
    out = Image.new("RGBA", im.size)
    src = im.load()
    dst = out.load()
    for y in range(im.size[1]):
        for x in range(im.size[0]):
            r, g, b, a = src[x, y]
            if a == 0:
                dst[x, y] = (0, 0, 0, 0)
                continue
            lum = 0.299 * r + 0.587 * g + 0.114 * b
            v = 18 + lum * 0.42            # escurece, preserva o desenho
            dst[x, y] = (int(min(255, v * 1.08)), int(min(255, v * 0.98)),
                         int(min(255, v * 0.86)), a)   # leve sepia
    return out


def do_locked():
    for aid, _ in catalog():
        p = os.path.join(ASSET_DIR, aid + ".png")
        if not os.path.exists(p):
            print("AVISO: emblema ausente:", p)
            continue
        locked_of(Image.open(p).convert("RGBA")).save(
            os.path.join(ASSET_DIR, aid + "_locked.png"))
    print("locked ok")


def flatten_256(im):
    big = im.resize((STEAM_SIZE, STEAM_SIZE), Image.NEAREST)
    bg = Image.new("RGB", big.size, INK)
    bg.paste(big, (0, 0), big)
    return bg


def do_steam():
    os.makedirs(STEAM_DIR, exist_ok=True)
    n = 0
    for aid, api in catalog():
        for suffix in ("", "_locked"):
            p = os.path.join(ASSET_DIR, aid + suffix + ".png")
            if not os.path.exists(p):
                print("AVISO: emblema ausente:", p)
                continue
            flatten_256(Image.open(p).convert("RGBA")).save(
                os.path.join(STEAM_DIR, api + suffix + ".png"))
            n += 1
    print("steam: %d icones 256x256 em %s" % (n, STEAM_DIR))


if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    if mode == "import":
        do_import(sys.argv[2])
    elif mode == "locked":
        do_locked()
    elif mode == "steam":
        do_steam()
    elif mode == "all":
        do_import(sys.argv[2]); do_locked(); do_steam()
    else:
        print("uso: python -I tools/achievement_icons.py import <dir>|locked|steam|all <dir>")
        sys.exit(2)
