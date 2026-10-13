#!/usr/bin/env python3
# tools/bake_idle_fx.py
# ============================================================================
# EFEITO PINTADO QUE TEM QUE SE MEXER (Out/2026, dono: "a fumaça do
# incensário do cultista está parada").
# ============================================================================
# Os idles assados por deslocamento carregam fumaça, raio, gota, brilho e
# chama PINTADOS junto do corpo: balançam com ele, mas não vivem. Aqui cada
# elemento declarado ganha movimento próprio, quadro a quadro, por cima do
# idle e do hurt, na grade do pixel (sem suavização), corpo e pé intactos:
#
#   smoke  sobe em espiral (rolagem contínua ao longo do eixo `flow`, com
#          ondulação crescente) e se desfaz no topo em pontilhado; um tom
#          a mais nos quadros pares. Pixels do elemento são apagados e
#          redesenhados (a caixa só pode conter o elemento + fundo).
#   flame  estica da base, ondula a ponta, ponta sobe um tom (qualquer cor:
#          a alma roxa do dullahan também).
#   pulse  brilho em 3 degraus (escuro / base / claro), sem meio-termo.
#   arcs   cada faísca do raio acende, apaga e pula 1px em fase própria.
#   drip   a gota/baba estica pra baixo a partir da raiz e volta.
#   sparks fagulhas soltas sobem e piscam.
#
# NÃO serve pra névoa que passa POR CIMA do corpo (a do pé do escudo do
# spectral_knight): apagar o elemento abre buraco no que está atrás dele.
#
# Caixas (x0, y0, x1, y1) em px do canvas do idle, lidas com régua no
# quadro 0 (`zoom.py`). Rodar UMA vez sobre o idle/hurt atual.
#
# Uso: python tools/bake_idle_fx.py preview <out.png> [ids]
#      python tools/bake_idle_fx.py run [ids]
# ============================================================================
import math
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..",
                    "assets", "sprites", "characters", "enemies")

# (tipo, caixa, opções)
CONFIG = {
    "ram_cultist": [("smoke", (2, 8, 18, 56), {"flow": (0, -1), "sel": "gray"})],
    "dullahan": [("flame", (44, 2, 64, 26), {}), ("flame", (70, 18, 88, 40), {})],
    "spectral_knight": [("smoke", (58, 0, 78, 16), {"flow": (0, -1), "sel": "gray"}),
                        ("smoke", (0, 22, 14, 62), {"flow": (0, -1), "sel": "gray"}),
                        ("pulse", (22, 25, 72, 78), {"sel": "glow"})],
    "spore_mother": [("drip", (12, 36, 108, 56), {"sel": "glow"}),
                     ("pulse", (12, 30, 108, 45), {"sel": "glow"})],
    "storm_griffin": [("arcs", (10, 0, 40, 80), {}), ("arcs", (80, 0, 118, 66), {})],
    "ice_wyrm": [("smoke", (97, 20, 118, 42), {"flow": (1, -1), "sel": "light"})],
    "frost_wolf": [("smoke", (4, 36, 22, 52), {"flow": (-1, -1), "sel": "light"})],
    "plague_toad": [("drip", (46, 16, 58, 34), {"sel": "glow"}),
                    ("pulse", (30, 0, 103, 60), {"sel": "glow"})],
    "blight_bull": [("sparks", (14, 0, 96, 24), {}), ("sparks", (14, 40, 30, 60), {})],
    "pit_brute": [("pulse", (14, 22, 104, 64), {"sel": "glow"})],
    "fallen_angel": [("pulse", (48, 3, 78, 14), {"sel": "glow"})],
    "abyss_watcher": [("pulse", (30, 25, 100, 120), {"sel": "glow"})],
}
CYCLES = {"smoke": 1, "flame": 3, "pulse": 2, "arcs": 4, "drip": 2, "sparks": 2}


def hsv(a):
    rgb = a[..., :3].astype(float) / 255
    mx = rgb.max(2)
    mn = rgb.min(2)
    s = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    return mx, s


def select(a, box, sel):
    H, W = a.shape[:2]
    x0, y0, x1, y1 = box
    reg = np.zeros((H, W), bool)
    reg[max(0, y0):min(H, y1), max(0, x0):min(W, x1)] = True
    al = a[..., 3] > 25
    v, s = hsv(a)
    if sel == "gray":
        m = (s < 0.35) & (v > 0.28)
    elif sel == "light":
        m = (v > 0.62) & (s < 0.55)
    elif sel == "glow":
        m = (v > 0.55) & (s > 0.35)
    elif sel == "arc":
        m = (v > 0.70) & (a[..., 2] > 150)
    else:                                   # "all": tudo que é opaco na caixa
        m = np.ones((H, W), bool)
    return reg & al & m


def bg_pixel(a, y, x):
    """pixel cercado de transparência = fundo (pode ser apagado)"""
    H, W = a.shape[:2]
    n = 0
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)):
        yy, xx = y + dy, x + dx
        if not (0 <= yy < H and 0 <= xx < W) or a[yy, xx, 3] <= 25:
            n += 1
    return n >= 3


def fx_smoke(arr, out, box, opt, k, n):
    m = select(arr, box, opt.get("sel", "gray"))
    if m.sum() < 4:
        return
    ys, xs = np.nonzero(m)
    t0, b0, l0, r0 = ys.min(), ys.max(), xs.min(), xs.max()
    fx, fy = opt.get("flow", (0, -1))
    ph = k / n                                       # 0..1 por volta
    # apaga o elemento (a caixa só tem fumaça + fundo)
    for y, x in zip(ys, xs):
        out[y, x, 3] = 0
    hgt, wid = b0 - t0 + 1, r0 - l0 + 1
    for y, x in zip(ys, xs):
        # rolagem ao longo do fluxo: o destino pega a origem "atrás" dele
        if fy != 0:
            off = int(round(ph * hgt))
            sy = t0 + (y - t0 + off * (-fy)) % hgt
            curl = math.sin(2 * math.pi * ((y - t0) / max(1, hgt) * 1.3 - ph)) \
                * 1.6 * (1 - (y - t0) / max(1, hgt))
            sx = x - int(round(curl + fx * ph * 2))
        else:
            off = int(round(ph * wid))
            sx = l0 + (x - l0 + off * (-fx)) % wid
            sy = y
        # o destino só é desenhado onde HAVIA fumaça na forma original
        # (silhueta fica, a textura corre por dentro) — mais as bordas
        # da ondulação
        if not (0 <= sy < arr.shape[0] and 0 <= sx < arr.shape[1]):
            continue
        if not m[sy, sx]:
            # pega o vizinho de fumaça mais próximo na mesma linha
            for d in (1, -1, 2, -2):
                if 0 <= sx + d < arr.shape[1] and m[sy, sx + d]:
                    sx += d
                    break
            else:
                continue
        c = arr[sy, sx].copy()
        # desfaz no topo do fluxo (pontilhado que anda)
        frac = (y - t0) / max(1, hgt) if fy < 0 else (b0 - y) / max(1, hgt)
        if fy == 0:
            frac = ((r0 - x) / max(1, wid)) if fx > 0 else ((x - l0) / max(1, wid))
        if frac < 0.22 and (x + y + k) % 2 == 0:
            continue
        if k % 2 == 0 and frac < 0.5:
            c[:3] = np.minimum(255, c[:3].astype(int) + 14)
        out[y, x] = c


def fx_flame(arr, out, box, opt, k, n, seed=0.0):
    m = select(arr, box, "glow")
    if m.sum() < 4:
        return
    ys, xs = np.nonzero(m)
    base, top = ys.max(), ys.min()
    hgt = base - top + 1
    ph = 2 * math.pi * CYCLES["flame"] * k / n + seed
    s = 1.0 + 0.30 * (0.5 + 0.5 * math.sin(ph))
    hot = math.sin(ph * 2) > 0
    H, W = arr.shape[:2]
    x0, _, x1, _ = box
    for y in range(max(0, top - int(hgt * 0.3) - 2), base + 1):
        f = (base - y) / max(1, hgt)
        dx = int(round(1.4 * math.sin(ph * 1.3 + y * 0.9) * min(1.0, f)))
        sy = int(round(base - (base - y) / s))
        if not (0 <= sy < H):
            continue
        for x in range(max(0, x0 - 2), min(W, x1 + 2)):
            sx = x - dx
            if 0 <= sx < W and m[sy, sx]:
                c = arr[sy, sx].copy()
                if hot and f > 0.55:
                    c[:3] = np.minimum(255, c[:3].astype(int) + 30)
                out[y, x] = c


def fx_pulse(arr, out, box, opt, k, n):
    m = select(arr, box, opt.get("sel", "glow"))
    if not m.any():
        return
    step = [0.80, 1.0, 1.16, 1.0][(k * CYCLES["pulse"] * 4 // n) % 4]
    rgb = out[..., :3].astype(float)
    rgb[m] = np.minimum(255, rgb[m] * step)
    out[..., :3] = rgb.astype(np.uint8)


def components(mask):
    h, w = mask.shape
    seen = np.zeros_like(mask)
    comps = []
    for y in range(h):
        for x in range(w):
            if mask[y, x] and not seen[y, x]:
                st, pts = [(y, x)], []
                seen[y, x] = True
                while st:
                    cy, cx = st.pop()
                    pts.append((cy, cx))
                    for dy in (-1, 0, 1):
                        for dx in (-1, 0, 1):
                            ny, nx = cy + dy, cx + dx
                            if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not seen[ny, nx]:
                                seen[ny, nx] = True
                                st.append((ny, nx))
                comps.append(pts)
    return comps


def fx_arcs(arr, out, box, opt, k, n):
    m = select(arr, box, "arc")
    for ci, pts in enumerate(components(m)):
        state = (k * CYCLES["arcs"] * 3 // n + ci) % 3      # 0 aceso 1 fraco 2 apagado
        jx = (1 if (k + ci) % 2 else -1) if state == 0 else 0
        for (y, x) in pts:
            if bg_pixel(arr, y, x):
                out[y, x, 3] = 0
            else:
                out[y, x, :3] = (arr[y, x, :3] * 0.55).astype(np.uint8)
        if state == 2:
            continue
        for (y, x) in pts:
            xx = x + jx
            if 0 <= xx < arr.shape[1]:
                c = arr[y, x].copy()
                if state == 1:
                    c[:3] = (c[:3] * 0.7).astype(np.uint8)
                out[y, xx] = c


def fx_drip(arr, out, box, opt, k, n):
    m = select(arr, box, opt.get("sel", "glow"))
    if m.sum() < 2:
        return
    ph = 2 * math.pi * CYCLES["drip"] * k / n
    s = 1.0 + 0.45 * (0.5 + 0.5 * math.sin(ph))
    H, W = arr.shape[:2]
    for pts in components(m):
        ys = [p[0] for p in pts]
        top, bot = min(ys), max(ys)
        cols = sorted(set(p[1] for p in pts))
        for x in cols:
            colys = [p[0] for p in pts if p[1] == x]
            t, b = min(colys), max(colys)
            L = b - t + 1
            for y in range(t, min(H, t + int(math.ceil(L * s)) + 1)):
                sy = t + int((y - t) / s)
                if sy <= b and m[sy, x]:
                    out[y, x] = arr[sy, x]


def fx_sparks(arr, out, box, opt, k, n):
    m = select(arr, box, "glow")
    H, W = arr.shape[:2]
    comps = [c for c in components(m) if len(c) <= 12]
    for ci, pts in enumerate(comps):
        for (y, x) in pts:
            if bg_pixel(arr, y, x):
                out[y, x, 3] = 0
    for ci, pts in enumerate(comps):
        phase = (k * CYCLES["sparks"] / n + ci * 0.37) % 1.0
        rise = int(round(phase * 6))
        if (k + ci) % 4 == 3:
            continue                                  # pisca
        for (y, x) in pts:
            yy = y - rise
            if 0 <= yy < H and out[yy, x, 3] <= 25:
                out[yy, x] = arr[y, x]


FX = {"smoke": fx_smoke, "flame": fx_flame, "pulse": fx_pulse,
      "arcs": fx_arcs, "drip": fx_drip, "sparks": fx_sparks}


def clip_files(eid, clip):
    d = os.path.join(ROOT, eid, "animations", clip, "south")
    if not os.path.isdir(d):
        return []
    return [os.path.join(d, f) for f in
            sorted((f for f in os.listdir(d) if f.endswith(".png")),
                   key=lambda f: int(f.split(".")[0]))]


def process(eid, write):
    res = []
    for clip in ("idle", "hurt"):
        fs = clip_files(eid, clip)
        for k, p in enumerate(fs):
            arr = np.array(Image.open(p).convert("RGBA"))
            out = arr.copy()
            for (kind, box, opt) in CONFIG[eid]:
                FX[kind](arr, out, box, opt, k, len(fs))
            if write:
                Image.fromarray(out).save(p)
            res.append((clip, k, out))
    return res


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "run"
    if cmd == "preview":
        out, ids = sys.argv[2], (sys.argv[3:] or list(CONFIG))
        rows = [[o for (c, k, o) in process(eid, False) if c == "idle"] for eid in ids]
        S = 2
        W = max(f.shape[1] for r in rows for f in r) * S
        H = max(f.shape[0] for r in rows for f in r) * S
        img = Image.new("RGBA", ((W + 4) * 12, (H + 6) * len(rows)), (40, 40, 48, 255))
        for ri, r in enumerate(rows):
            for ci, f in enumerate(r[:12]):
                img.alpha_composite(Image.fromarray(f).resize(
                    (f.shape[1] * S, f.shape[0] * S), Image.NEAREST), (ci * (W + 4), ri * (H + 6)))
        img.save(out)
    else:
        for eid in (sys.argv[2:] or list(CONFIG)):
            process(eid, True)
            print("[fx] %s" % eid)
