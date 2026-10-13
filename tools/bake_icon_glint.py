#!/usr/bin/env python3
"""
tools/bake_icon_glint.py — idle de ícone de carta ASSADO a partir do PNG
estático: um brilho que VARRE os pixels de um material (aço, bronze, ouro…)
sem mexer em nenhum contorno. Zero geração, zero deriva.

Por que existe: o v3 do PixelLab, pedido pra "um brilho deslizar pela
lâmina", ENTORTOU as três adagas do combo_volley (lâmina reta virando
cimitarra nos quadros 3-7) — silhueta destruída, exatamente o defeito da
doutrina (memory/card_icon_animation.md). Brilho passageiro em metal é o
movimento canônico de carta uncommon e não precisa de modelo nenhum.

Saída no contrato do IconFramesLoader:
  assets/sprites/icons_anim/<icon>/frame_000.png .. frame_NNN.png + meta.lua
frame_000 == PNG estático (sem pop entre o idle parado e o animado).

  python tools/bake_icon_glint.py <icon>          # usa SPECS[icon]
  python tools/bake_icon_glint.py sheet <icon...> # prancha 3x
"""
import colorsys
import math
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICONS = os.path.join(ROOT, "assets/sprites/icons")
ANIM = os.path.join(ROOT, "assets/sprites/icons_anim")

# icon → material (faixa HSV), direção da varredura, largura da faixa (px),
# ganho do brilho, quadros, fps, `stagger`: nº de alvos varridos em
# sequência (as três adagas uma depois da outra) separados no eixo x.
SPECS = {
    # três adagas de aço: brilho desce cada lâmina, esquerda → direita
    "combo_volley": dict(hue=None, smax=0.25, vmin=0.35, vmax=0.95,
                         dir=(0.35, 1.0), width=3.5, gain=0.75,
                         frames=12, fps=8, stagger=3),
    # escudo-torre de bronze: reflexo morno atravessa a face na diagonal
    "combo_wall": dict(hue=(10, 40), smin=0.40, smax=0.85, vmin=0.30,
                       vmax=0.80, dir=(1.0, 1.0), width=5.0, gain=0.45,
                       frames=12, fps=7, stagger=1),
    # espelho: o reflexo varre o vidro lilás (o v1 eram duas cartas largas
    # que o slot da carta cortava ao meio — ícone redesenhado estreito)
    "combo_pair": dict(hue=(225, 285), smin=0.10, smax=0.55, vmin=0.60,
                       vmax=1.0, dir=(1.0, 0.6), width=4.0, gain=0.70,
                       frames=12, fps=7, stagger=1),
}


def material_mask(a, spec):
    h, w = a.shape[:2]
    m = np.zeros((h, w), bool)
    for y in range(h):
        for x in range(w):
            r, g, b, al = a[y, x]
            if al < 200:
                continue
            hh, ss, vv = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if ss > spec["smax"] or not (spec["vmin"] <= vv <= spec["vmax"]):
                continue
            if ss < spec.get("smin", 0):
                continue
            if spec["hue"] is not None:
                lo, hi = spec["hue"]
                if not (lo <= hh * 360 <= hi):
                    continue
            m[y, x] = True
    return m


def small_components(mask, max_side):
    """Só os grupos de pixel com bbox <= max_side (o naipe), descartando os
    longos (o filete vermelho da borda da carta, mesma cor do naipe)."""
    h, w = mask.shape
    seen = np.zeros_like(mask)
    out = np.zeros_like(mask)
    for y0 in range(h):
        for x0 in range(w):
            if not mask[y0, x0] or seen[y0, x0]:
                continue
            comp, st = [], [(y0, x0)]
            seen[y0, x0] = True
            while st:
                y, x = st.pop()
                comp.append((y, x))
                for ny in (y - 1, y, y + 1):
                    for nx in (x - 1, x, x + 1):
                        if 0 <= ny < h and 0 <= nx < w and mask[ny, nx]                                 and not seen[ny, nx]:
                            seen[ny, nx] = True
                            st.append((ny, nx))
            ys = [c[0] for c in comp]
            xs = [c[1] for c in comp]
            if max(ys) - min(ys) < max_side and max(xs) - min(xs) < max_side:
                for c in comp:
                    out[c] = True
    return out


def bake(icon, spec):
    base = np.array(Image.open(os.path.join(ICONS, icon + ".png")).convert("RGBA"))
    h, w = base.shape[:2]
    mask = material_mask(base, spec)
    if spec.get("max_comp"):
        mask = small_components(mask, spec["max_comp"])
    ys, xs = np.nonzero(mask)
    dx, dy = spec.get("dir", (0, 1))
    norm = math.hypot(dx, dy)
    dx, dy = dx / norm, dy / norm
    n = spec["frames"]
    k = spec.get("stagger", 1)
    # alvos = fatias verticais iguais do material (as k adagas)
    x0, x1 = xs.min(), xs.max() + 1
    out_dir = os.path.join(ANIM, icon)
    os.makedirs(out_dir, exist_ok=True)
    for f in os.listdir(out_dir):
        os.remove(os.path.join(out_dir, f))
    frames = []
    for i in range(n):
        fr = base.copy().astype(np.float32)
        if i > 0:
            # cada alvo tem sua janela de tempo: k varreduras + 1 pausa
            slot = (i / n) * (k + 1)
            t_idx = int(slot)
            if t_idx < k:
                t = slot - t_idx
                sx0 = x0 + (x1 - x0) * t_idx / k
                sx1 = x0 + (x1 - x0) * (t_idx + 1) / k
                sel = mask & (np.arange(w)[None, :] >= sx0) & (np.arange(w)[None, :] < sx1)
                sy, sx = np.nonzero(sel)
                if len(sy) and spec.get("mode") == "pulse":
                    # sobe e desce dentro da janela do alvo, em degraus
                    amt = math.sin(math.pi * t)
                    amt = round(amt * 3) / 3 * spec["gain"]
                    g = np.array(spec["glow"], np.float32)
                    px = fr[sy, sx, :3]
                    fr[sy, sx, :3] = px + (g - px) * amt
                elif len(sy):
                    proj = sx * dx + sy * dy
                    pmin, pmax = proj.min() - spec["width"], proj.max() + spec["width"]
                    c = pmin + (pmax - pmin) * t
                    d = np.abs(proj - c)
                    amt = np.clip(1 - d / spec["width"], 0, 1)
                    # degraus (pixel art): 0, meio, cheio
                    amt = np.round(amt * 2) / 2 * spec["gain"]
                    px = fr[sy, sx, :3]
                    fr[sy, sx, :3] = px + (255 - px) * amt[:, None]
        frames.append(fr.clip(0, 255).astype(np.uint8))
    for i, fr in enumerate(frames):
        Image.fromarray(fr).save(os.path.join(out_dir, f"frame_{i:03d}.png"))
    with open(os.path.join(out_dir, "meta.lua"), "w") as f:
        f.write(f"return {{ fps = {spec['fps']} }}\n")
    print(f"[bake] {icon}: {n} quadros, {int(mask.sum())} px de material")


def sheet(icons, out):
    rows = []
    for ic in icons:
        d = os.path.join(ANIM, ic)
        fs = sorted(f for f in os.listdir(d) if f.startswith("frame_"))
        rows.append([Image.open(os.path.join(d, f)).convert("RGBA") for f in fs])
    S = 3
    W = max(len(r) for r in rows) * (64 * S + 6)
    sh = Image.new("RGBA", (W, len(rows) * (64 * S + 6)), (60, 50, 40, 255))
    for y, r in enumerate(rows):
        for x, im in enumerate(r):
            b = im.resize((64 * S, 64 * S), Image.NEAREST)
            sh.paste(b, (x * (64 * S + 6), y * (64 * S + 6)), b)
    sh.save(out)
    print(out)


if __name__ == "__main__":
    if sys.argv[1] == "sheet":
        sheet(sys.argv[2:], os.path.join(ROOT, "tools/preview_out/icon_glint_sheet.png"))
    else:
        bake(sys.argv[1], SPECS[sys.argv[1]])
