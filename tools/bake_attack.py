#!/usr/bin/env python3
# tools/bake_attack.py
# ============================================================================
# GOLPE DE TODO INIMIGO (Out/2026, dono: "os monstros não têm animação de
# ataque?"). Só carrion_king, cursed_scarecrow e harvest_reaper tinham clip
# `attack` (PixelLab); os outros 42 atacavam só com a investida do engine.
# ============================================================================
# Clip assado a partir do quadro 0 do idle, 9 quadros a 12 fps (0,75s),
# casado com a investida do EnemyRenderer: ATK_WINDUP 0,18s + ATK_LUNGE
# 0,16s = apex em 0,34s → quadro 4 (0-based) é o GOLPE. Fases:
#
#   0     repouso (= idle 0: emenda sem pulo)
#   1-3   preparo: inclina pra TRÁS (longe do jogador, pra direita), arma
#   4-5   golpe: projeta pra FRENTE (esquerda-baixo, onde o jogador está)
#   6-8   volta ao repouso
#
# Arquétipo decide COMO o corpo se mexe (amostragem inversa, pixel inteiro):
#   melee   tronco inteiro cisalha (golpe de arma/garra)
#   bite    cabeça manda (peso concentrado em cima): bote/mordida/investida
#   caster  sobe e recua pouco, e o brilho pintado ACENDE no apex (flare)
#   slam    estica pra cima no preparo e ESMAGA no apex (martelo, golem)
#   breath  cabeça projeta e o brilho/luz pintado acende (sopro, raio)
# Quem pisa tem o pé PRESO (faixa de 10% acima da linha do apoio não mexe);
# quem flutua move o corpo inteiro. `attack_strong` = mesmo clip com
# amplitude 1,6x (o intent forte do jogo).
#
# Canvas: 24px a mais de cada lado (o corpo inclinado não corta); a margem
# de baixo é a do idle — o pé fica na mesma linha.
#
# Uso: python tools/bake_attack.py run [ids]        (pula quem já tem clip
#      python tools/bake_attack.py preview <out> [ids]   PixelLab)
# ============================================================================
import os
import re
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..", "assets", "sprites", "characters", "enemies")
POSES = os.path.join(HERE, "..", "src", "data", "enemy_poses.lua")

# clips de PixelLab (barra de qualidade) — não são substituídos
PIXELLAB = {"carrion_king", "cursed_scarecrow", "harvest_reaper"}

ARCH = {
    "melee": ["blood_duke", "bog_ghoul", "croc_warrior", "dullahan", "fallen_angel",
              "frost_wight", "glacier_knight", "hollow_farmer", "obsidian_sentinel",
              "spectral_knight", "grave_thrall"],
    "bite": ["dusk_bat", "frost_wolf", "hellhound", "plague_toad", "plague_rats",
             "leech_horror", "blight_bull", "moon_gargoyle", "ember_imp", "storm_harpy"],
    "caster": ["abyss_acolyte", "abyss_wraith", "dusk_shade", "mire_hag", "ram_cultist",
               "rime_shaman", "tower_lich", "eclipse_queen", "abyss_watcher",
               "spore_mother", "winter_monarch"],
    "slam": ["frost_troll", "pit_brute", "rot_colossus", "rune_golem", "stone_golem",
             "wicker_effigy", "grave_slime", "abyss_tyrant"],
    "breath": ["ice_wyrm", "storm_griffin"],
}
# chefe com assinatura: o tirano carrega o inferno (slam + flare)
FLARE_TOO = {"abyss_tyrant", "pit_brute", "wicker_effigy"}

# por quadro: inclinação (px no topo; + = pra trás/direita), escala vertical
# em torno do chão, flare 0..1
LEAN = [0, 5, 8, 10, -15, -13, -8, -3, 0]
SY_DEFAULT = [1, .99, .98, .98, 1.02, 1.01, 1, 1, 1]
SY_SLAM = [1, 1.02, 1.04, 1.05, .91, .93, .97, .99, 1]
SY_CASTER = [1, 1.01, 1.03, 1.04, 1.02, 1.01, 1, 1, 1]
FLARE = [0, 0, .25, .5, 1, .8, .45, .15, 0]
PAD = 24


def floating_ids():
    s = open(POSES, encoding="utf-8").read()
    return set(re.findall(r"^\s*(\w+)\s*=\s*\{\s*pose\s*=\s*\"floating\"", s, re.M))


def ground_row(a):
    al = a[..., 3] > 25
    h, w = al.shape
    run = np.zeros(w, int)
    xs = np.nonzero(al.any(0))[0]
    M = max(3, int(0.06 * (xs.max() - xs.min() + 1)))
    g = np.nonzero(al.any(1))[0].max()
    best = g
    for y in range(h):
        run = np.where(al[y], run + 1, 0)
        if (run >= 5).sum() >= M:
            best = y
    return best


def arch_of(eid):
    for k, ids in ARCH.items():
        if eid in ids:
            return k
    return "melee"


def bake_clip(eid, amp, floating):
    base = np.array(Image.open(os.path.join(
        ROOT, eid, "animations", "idle", "south", "0.png")).convert("RGBA"))
    H, W0 = base.shape[:2]
    src = np.zeros((H, W0 + 2 * PAD, 4), np.uint8)
    src[:, PAD:PAD + W0] = base
    W = src.shape[1]
    al = src[..., 3] > 25
    ys = np.nonzero(al.any(1))[0]
    top = ys.min()
    G = ground_row(src)
    hgt = max(1, G - top)
    arch = arch_of(eid)
    expo = {"melee": 1.2, "bite": 2.2, "caster": 1.0, "slam": 1.0, "breath": 2.0}[arch]
    lean_k = {"melee": 1.0, "bite": 1.25, "caster": 0.45, "slam": 0.55, "breath": 0.9}[arch]
    sy_tab = SY_SLAM if arch == "slam" else SY_CASTER if arch == "caster" else SY_DEFAULT
    flare_on = arch in ("caster", "breath") or eid in FLARE_TOO
    Y, X = np.mgrid[0:H, 0:W].astype(np.float64)
    pin = G - 0.10 * hgt
    if floating:
        # quem voa MERGULHA: o corpo todo vai junto, cabeça um pouco mais
        wgt = np.clip((G - Y) / hgt, 0, 1) * 0.5 + 0.5
    else:
        wgt = np.clip((pin - Y) / max(1, pin - top), 0, 1) ** expo
    rgb = src[..., :3].astype(float) / 255
    mx = rgb.max(2)
    sat = np.where(mx > 0, (mx - rgb.min(2)) / np.maximum(mx, 1e-6), 0)
    glow = al & (mx > 0.55) & (sat > 0.35)
    frames = []
    for k in range(9):
        lean = LEAN[k] * lean_k * amp
        sy = 1 + (sy_tab[k] - 1) * amp
        dx = lean * wgt
        srcx = np.rint(X - dx).astype(int)
        srcy = np.rint(G - (G - Y) / sy).astype(int) if not floating else \
            np.rint(Y - (sy - 1) * hgt * 0.5).astype(int)
        if not floating:
            srcy = np.where(Y >= pin, Y.astype(int), srcy)
        ok = (srcx >= 0) & (srcx < W) & (srcy >= 0) & (srcy < H)
        out = np.zeros_like(src)
        out[ok] = src[srcy[ok], srcx[ok]]
        f = FLARE[k] * min(1.0, amp)
        if flare_on and f > 0:
            g2 = np.zeros_like(glow)
            g2[ok] = glow[srcy[ok], srcx[ok]]
            c = out[..., :3].astype(float)
            c[g2] = np.minimum(255, c[g2] * (1 + 0.55 * f) + 30 * f)
            out[..., :3] = c.astype(np.uint8)
        frames.append(out)
    return frames


def write(eid, name, frames):
    d = os.path.join(ROOT, eid, "animations", name, "south")
    os.makedirs(d, exist_ok=True)
    for f in os.listdir(d):
        if f.endswith(".png"):
            os.remove(os.path.join(d, f))
    for i, fr in enumerate(frames):
        Image.fromarray(fr).save(os.path.join(d, "%d.png" % i))


def targets(args):
    ids = args or sorted(d for d in os.listdir(ROOT)
                         if os.path.isdir(os.path.join(ROOT, d, "animations", "idle", "south")))
    return ids


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "run"
    fl = floating_ids()
    if cmd == "run":
        for eid in targets(sys.argv[2:]):
            if eid in PIXELLAB:
                continue
            write(eid, "attack", bake_clip(eid, 1.0, eid in fl))
            write(eid, "attack_strong", bake_clip(eid, 1.6, eid in fl))
            print("[golpe] %-20s %s%s" % (eid, arch_of(eid), " (flutua)" if eid in fl else ""))
    elif cmd == "preview":
        out, ids = sys.argv[2], targets(sys.argv[3:])
        rows = [bake_clip(e, 1.0, e in fl) for e in ids if e not in PIXELLAB]
        S = 2
        Wt = max(r[0].shape[1] for r in rows) * S
        Ht = max(r[0].shape[0] for r in rows) * S
        img = Image.new("RGBA", ((Wt + 2) * 9, (Ht + 4) * len(rows)), (40, 40, 48, 255))
        for ri, r in enumerate(rows):
            for ci, f in enumerate(r):
                img.alpha_composite(Image.fromarray(f).resize(
                    (f.shape[1] * S, f.shape[0] * S), Image.NEAREST), (ci * (Wt + 2), ri * (Ht + 4)))
        img.save(out)
