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
ANIM = os.environ.get("ICON_ANIM_OUT") or os.path.join(ROOT, "assets/sprites/icons_anim")

# icon → material (faixa HSV) ou `layers` (lista de camadas, incl. mode
# "points": olhos que acendem sem o rosto mexer), direção da varredura, largura da faixa (px),
# ganho do brilho, quadros, fps, `stagger`: nº de alvos varridos em
# sequência (as três adagas uma depois da outra) separados no eixo x.
SPECS = {
    "joker_boss_carrion": dict(frames=12, fps=8, layers=[
        dict(mode="points", points=[(26, 19), (37, 19)], phase=0.0,
             glow=(255, 170, 60), gain=1.8),
        dict(mode="points", points=[(31, 46)], phase=0.5,
             glow=(255, 200, 90), gain=1.5),
        dict(hue=(28, 55), smin=0.45, smax=1.0, vmin=0.55, vmax=1.0,
             box=(0, 0, 64, 16), dir=(1.0, 0.25), width=6.0, gain=1.0,
             stagger=1),
    ]),
    "joker_boss_eclipse": dict(frames=12, fps=8, layers=[
        dict(mode="points", points=[(28, 28), (35, 28)], phase=0.0,
             glow=(236, 86, 196), gain=1.6),
        dict(hue=(5, 30), smin=0.30, smax=1.0, vmin=0.60, vmax=1.0,
             box=(0, 0, 64, 42), dir=(1.0, 0.30), width=6.0, gain=0.7,
             stagger=1),
    ]),
    "joker_boss_winter": dict(frames=12, fps=8, layers=[
        dict(mode="points", points=[(27, 24), (36, 24)], phase=0.0,
             glow=(150, 220, 255), gain=0.9),
        dict(hue=(185, 220), smin=0.15, smax=1.0, vmin=0.45, vmax=1.0,
             dir=(1.0, 0.35), width=5.0, gain=0.55, stagger=1),
    ]),
    # combo_volley: idle do PixelLab v3 (aprovado — brilho nas lâminas,
    # silhueta intacta); não assar aqui por cima.
    # 2ª volta (arte de personagem): veterano atrás dos escudos — olhos
    # dourados acendem alternando + reflexo varrendo o ouro dos escudos.
    # O v3 mexia o rosto (barba/boca ondulando) — reprovado no olho.
    "combo_wall": dict(frames=12, fps=7, layers=[
        dict(mode="points", points=[(29, 17), (34, 17)], phase=0.0,
             glow=(255, 214, 120), gain=0.9),
        dict(hue=(28, 55), smin=0.45, smax=1.0, vmin=0.55, vmax=1.0,
             box=(0, 24, 64, 64), dir=(1.0, 0.2), width=4.0, gain=0.6,
             stagger=1),
    ]),
    # espelho rachado: os dois olhos vermelhos das máscaras acendem
    # alternando (o v3 FECHAVA os olhos e o vermelho sumia — pop no loop).
    "combo_pair": dict(frames=12, fps=7, layers=[
        dict(mode="points", points=[(26, 22), (37, 22)], phase=0.5,
             glow=(255, 60, 50), gain=0.9),
        dict(hue=(28, 55), smin=0.45, smax=1.0, vmin=0.55, vmax=1.0,
             dir=(0.3, 1.0), width=4.0, gain=0.5, stagger=1),
    ]),
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


def apply_layer(fr, base, spec, i, n):
    """Aplica UMA camada de movimento no quadro i (fr float32, in-place)."""
    h, w = base.shape[:2]
    if spec.get("mode") == "points":
        # olhos: pontos que acendem e apagam, alternando (fase por ponto);
        # halo de 1px em cruz com metade da força. Rosto PARADO — só a cor
        # do ponto muda (o v3 abria/fechava olho e mexia boca: reprovado).
        for k, (x, y) in enumerate(spec["points"]):
            ph = 2 * math.pi * (i / n + k * spec.get("phase", 0.5))
            amt = (0.5 - 0.5 * math.cos(ph)) if i > 0 else 0
            amt = round(amt * 3) / 3 * spec["gain"]
            g = np.array(spec["glow"], np.float32)
            for (ox, oy, f) in ((0, 0, 1.0), (1, 0, .45), (-1, 0, .45),
                                (0, 1, .45), (0, -1, .45)):
                xx, yy = x + ox, y + oy
                if 0 <= xx < w and 0 <= yy < h and base[yy, xx, 3] > 0:
                    fr[yy, xx, :3] += (g - fr[yy, xx, :3]) * amt * f
        return
    mask = material_mask(base, spec)
    if spec.get("max_comp"):
        mask = small_components(mask, spec["max_comp"])
    if spec.get("box"):
        bx0, by0, bx1, by1 = spec["box"]
        bm = np.zeros_like(mask)
        bm[by0:by1, bx0:bx1] = True
        mask &= bm
    ys, xs = np.nonzero(mask)
    if not len(xs) or i == 0:
        return
    dx, dy = spec.get("dir", (0, 1))
    norm = math.hypot(dx, dy)
    dx, dy = dx / norm, dy / norm
    k = spec.get("stagger", 1)
    x0, x1 = xs.min(), xs.max() + 1
    slot = (i / n) * (k + 1)
    t_idx = int(slot)
    if t_idx >= k:
        return
    t = slot - t_idx
    sx0 = x0 + (x1 - x0) * t_idx / k
    sx1 = x0 + (x1 - x0) * (t_idx + 1) / k
    cols = np.arange(w)[None, :]
    sel = mask & (cols >= sx0) & (cols < sx1)
    sy, sx = np.nonzero(sel)
    if not len(sy):
        return
    if spec.get("mode") == "pulse":
        amt = math.sin(math.pi * t)
        amt = round(amt * 3) / 3 * spec["gain"]
        g = np.array(spec["glow"], np.float32)
        px = fr[sy, sx, :3]
        fr[sy, sx, :3] = px + (g - px) * amt
        return
    proj = sx * dx + sy * dy
    pmin, pmax = proj.min() - spec["width"], proj.max() + spec["width"]
    c = pmin + (pmax - pmin) * t
    d = np.abs(proj - c)
    amt = np.clip(1 - d / spec["width"], 0, 1)
    amt = np.round(amt * 2) / 2 * spec["gain"]   # degraus (pixel art)
    px = fr[sy, sx, :3]
    fr[sy, sx, :3] = px + (255 - px) * amt[:, None]


def bake(icon, spec):
    base = np.array(Image.open(os.path.join(ICONS, icon + ".png")).convert("RGBA"))
    layers = spec.get("layers", [spec])
    n = spec["frames"]
    out_dir = os.path.join(ANIM, icon)
    os.makedirs(out_dir, exist_ok=True)
    for f in os.listdir(out_dir):
        os.remove(os.path.join(out_dir, f))
    for i in range(n):
        fr = base.copy().astype(np.float32)
        for layer in layers:
            apply_layer(fr, base, layer, i, n)
        Image.fromarray(fr.clip(0, 255).astype(np.uint8)).save(
            os.path.join(out_dir, f"frame_{i:03d}.png"))
    with open(os.path.join(out_dir, "meta.lua"), "w") as f:
        f.write(f"return {{ fps = {spec['fps']} }}\n")
    print(f"[bake] {icon}: {n} quadros, {len(layers)} camada(s)")


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
