#!/usr/bin/env python3
# tools/boss_art_pass.py
# ============================================================================
# PASSE DE ARTE dos chefes — detalhe de pixel que a geração não deu, aplicado
# por REGRA (cor/vizinhança), nunca por coordenada fixa: assim o mesmo passe
# vale nos quadros do idle, do hurt, da death e do attack, e o chefe não
# "troca de roupa" quando apanha ou morre.
#
# Rodar UMA vez, sobre a arte original (o corvo é idempotente — a cor pintada
# não casa de novo —, a rainha NÃO: as dobras pintadas mudam a máscara do
# preto interior). Pra refazer: git checkout dos PNGs do chefe e rodar de novo.
#
#   carrion_king  — as asas eram cinza-pardo lavado (o dono: "não tem nada de
#                   especial"). As penas de borda ganham o brilho azul-violeta
#                   de corvo, casando com o manto roxo da arte.
#   eclipse_queen — a capa era um bloco PRETO chapado (1670 px de (3,8,10)
#                   numa caixa 80x44). Vira céu noturno: dobras em índigo
#                   pontilhado, estrelas de 1px (e algumas em cruz) e barra
#                   violeta. As bordas da membrana das asas ganham luz
#                   atravessando. O que o dono gostou (silhueta, cor, rosto)
#                   não é tocado.
#
# Uso:  python tools/boss_art_pass.py run [ids...]
#       python tools/boss_art_pass.py preview <id> <out.png>   (não grava)
# Depois de rodar: python tools/bake_boss_idle.py run <id>
# ============================================================================
import colorsys
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..",
                    "assets", "sprites", "characters", "enemies")
CLIPS = ("idle", "hurt", "death", "attack")


def clip_files(bid):
    out = []
    for clip in CLIPS:
        d = os.path.join(ROOT, bid, "animations", clip, "south")
        if not os.path.isdir(d):
            continue
        for f in sorted(os.listdir(d), key=lambda s: int(s.split(".")[0])):
            if f.endswith(".png"):
                out.append((clip, os.path.join(d, f)))
    # sprite estático dos ícones do MapScreen: mesmo canvas do idle
    south = os.path.join(ROOT, bid, "south.png")
    if os.path.isfile(south):
        out.append(("idle", south))
    return out


# ---------------------------------------------------------------------------
# carrion_king — brilho de corvo nas penas
# ---------------------------------------------------------------------------
def pass_carrion(arr, clip):
    h, w = arr.shape[:2]
    out = arr.copy()
    for y in range(h):
        for x in range(w):
            r, g, b, a = arr[y, x]
            if a < 10:
                continue
            # coroa: as pontas têm cinza-rosado do mesmo tom — fora
            if clip in ("idle", "hurt") and 50 <= x <= 100 and y < 32:
                continue
            hh, ll, ss = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
            if (hh < 0.17 or hh > 0.9) and ss < 0.2 and 0.22 < ll < 0.75:
                t = (ll - 0.22) / 0.5
                nh = 0.71 - 0.06 * t
                ns = 0.24 + 0.10 * t
                nl = ll * 0.78
                rr, gg, bb = colorsys.hls_to_rgb(nh, nl, ns)
                out[y, x] = (int(rr * 255), int(gg * 255), int(bb * 255), a)
    return out


# ---------------------------------------------------------------------------
# eclipse_queen — capa de céu noturno + luz na membrana
# ---------------------------------------------------------------------------
def _hash(x, y, salt=0):
    v = (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)
    v = (v ^ (v >> 13)) * 1274126177
    return ((v ^ (v >> 16)) & 0xFFFF) / 65535.0


def pass_eclipse(arr, clip):
    h, w = arr.shape[:2]
    rgb = arr[..., :3].astype(int)
    alpha = arr[..., 3]
    lum = rgb.max(axis=2)
    black = (alpha > 200) & (lum < 18)
    # INTERIOR do preto: 5x5 inteiro opaco e preto. O contorno do sprite é
    # da MESMA cor (3,8,10) e tem 1px — sem esse filtro, estrela no contorno.
    interior = black.copy()
    for dy in range(-2, 3):
        for dx in range(-2, 3):
            interior &= np.roll(np.roll(black, dy, axis=0), dx, axis=1)
    interior[:2, :] = False
    interior[-2:, :] = False
    interior[:, :2] = False
    interior[:, -2:] = False

    out = arr.copy()
    opaque = alpha > 10
    # topo do preto interior (a capa começa na cintura): mede por coluna
    ys, xs = np.nonzero(interior)
    if len(ys) == 0:
        return out
    top = ys.min()
    bottom = ys.max()
    cxm = (xs.min() + xs.max()) / 2.0
    for y, x in zip(ys, xs):
        k = (y - top) / max(1, bottom - top)          # 0 cintura → 1 barra
        # DOBRAS: faixas que abrem em leque a partir da cintura (convergem
        # em cxm no topo). Pontilhado 2x2 = textura de pano, não gradiente.
        u = (x - cxm) / (0.35 + 0.65 * k)
        fold = np.sin(u * 0.62)
        if fold > 0.45 and (x + y) % 2 == 0:
            out[y, x] = (18, 14, 42, 255)
        elif fold > 0.85:
            out[y, x] = (24, 18, 54, 255)
        # ESTRELAS: hash por pixel, densidade baixa, mais na barra
        s = _hash(int(x), int(y), 7)
        if s < 0.020 + 0.022 * k:
            out[y, x] = (150, 140, 205, 255)
        elif s > 0.9985:
            # estrela em cruz (5 px) — só onde a cruz inteira cabe no preto
            if all(interior[y + dy, x + dx] for dx, dy in
                   ((0, -1), (0, 1), (-1, 0), (1, 0))):
                out[y, x] = (232, 224, 255, 255)
                for dx, dy in ((0, -1), (0, 1), (-1, 0), (1, 0)):
                    out[y + dy, x + dx] = (120, 104, 180, 255)
    # BARRA: preto com transparente logo abaixo (capa, não asa: k grande)
    below = np.zeros_like(opaque)
    below[:-1] = ~opaque[1:]
    hem = black & below
    hem[: top + int((bottom - top) * 0.55)] = False
    for y, x in zip(*np.nonzero(hem)):
        out[y, x] = (92, 46, 128, 255)
        if y > 0 and black[y - 1, x]:
            out[y - 1, x] = (44, 22, 72, 255)
    # MEMBRANA: roxo da asa com transparente 1-2px abaixo = borda recortada
    # da asa. Clareia (luz atravessando a pele fina).
    purple = (alpha > 200) & (rgb[..., 0] > 40) & (rgb[..., 2] > 70) \
        & (rgb[..., 1] < rgb[..., 0] * 0.6)
    edge = np.zeros_like(opaque)
    edge[:-2] = ~opaque[2:] | ~opaque[1:-1]
    rim = purple & edge
    rim[top + int((bottom - top) * 0.55):] = False   # barra da capa fora
    def lit(c, kr):
        r, g, b = c
        return (min(255, int(r * (1 + 0.32 * kr) + 10 * kr)),
                min(255, int(g * (1 + 0.25 * kr) + 4 * kr)),
                min(255, int(b * (1 + 0.36 * kr) + 14 * kr)), 255)
    for y, x in zip(*np.nonzero(rim)):
        out[y, x] = lit(rgb[y, x], 1.0)
    # meia-luz pontilhada logo acima da borda: transição, não risco
    band = np.zeros_like(opaque)
    for d in (3, 4, 5):
        band[:-d] |= ~opaque[d:]
    band &= purple & ~rim
    band[top + int((bottom - top) * 0.55):] = False
    for y, x in zip(*np.nonzero(band)):
        if (x + y) % 2 == 0:
            out[y, x] = lit(rgb[y, x], 0.55)
    return out


PASSES = {"carrion_king": pass_carrion, "eclipse_queen": pass_eclipse}


def apply(bid, write=True):
    fn = PASSES[bid]
    results = []
    for clip, path in clip_files(bid):
        arr = np.array(Image.open(path).convert("RGBA"))
        new = fn(arr, clip)
        results.append((clip, path, arr, new))
        if write:
            Image.fromarray(new).save(path)
    if write:
        print("[art] %s: %d quadros" % (bid, len(results)))
    return results


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "run"
    if cmd == "run":
        for bid in (sys.argv[2:] or list(PASSES.keys())):
            apply(bid)
    elif cmd == "preview":
        res = apply(sys.argv[2], write=False)
        clip, path, old, new = res[0]
        hgt, wid = old.shape[:2]
        s = 5
        img = Image.new("RGBA", (wid * s * 2 + 10, hgt * s), (40, 40, 48, 255))
        img.alpha_composite(Image.fromarray(old).resize((wid * s, hgt * s),
                                                        Image.NEAREST), (0, 0))
        img.alpha_composite(Image.fromarray(new).resize((wid * s, hgt * s),
                                                        Image.NEAREST),
                            (wid * s + 10, 0))
        img.save(sys.argv[3])
    else:
        sys.exit("uso: run [ids] | preview <id> <out>")
