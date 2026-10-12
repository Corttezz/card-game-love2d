#!/usr/bin/env python3
# tools/death_eyes_off.py
# ============================================================================
# OLHO APAGA NA MORTE (Out/2026, dono: "o espantalho morre e parece que os
# olhos continuam abertos, brilhando").
# ============================================================================
# A micro-luz dos emissivos já some na death (EnemyRenderer), mas os quadros
# da death vêm do PixelLab com o olho PINTADO aceso até o cadáver. Aqui, nos
# quadros da segunda metade da morte, os pixels do olho escurecem até virar
# órbita apagada.
#
# Como acha o olho (o corpo tomba e o olho anda): parte da âncora "olho" de
# src/data/enemy_emissives.lua no quadro 0 e, quadro a quadro, segue a
# mancha PEQUENA da cor dela mais próxima (componente <= MAX_BLOB px, caixa
# <= MAX_BOX, até TRACK px do quadro anterior).
#
# Uso:
#   python tools/death_eyes_off.py preview <out.png> [ids]   (não grava)
#   python tools/death_eyes_off.py run [ids]
# Rodar UMA vez sobre a death original (escurecer de novo escurece mais).
# ============================================================================
import os
import re
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..", "assets", "sprites", "characters", "enemies")
EMIS = os.path.join(HERE, "..", "src", "data", "enemy_emissives.lua")

TOL = 70          # distância RGB (0-255) à cor da âncora
MAX_BLOB = 18     # px: olho é mancha pequena
MAX_BOX = 6       # px: largura/altura máxima da mancha
EYE_R = 5         # px: raio em volta do olho registrado
FALLBACK = 16     # px: busca da mancha quando o retalho perde o olho
START = 0.35      # fração da death em que o olho começa a apagar
# olho de cor que só ele tem no corpo (rastreio perde a cabeça que gira):
# varre o quadro inteiro atrás de manchas pequenas dessa cor
# (só o lich: monarca e espectro de gelo têm o MESMO tom nos realces do
# corpo e a varredura sujava tudo — conferido na prancha)
SWEEP = {"tower_lich"}
# tolerância de cor por inimigo (o olho do lich no cadáver clareou)
TOL_BY = {"tower_lich": 110}
# o rastreio se perdeu e caiu num realce do corpo (conferido na prancha):
# o olho já termina escuro nesses cadáveres
SKIP = {"frost_wight", "pit_brute", "carrion_king"}
FULL = 0.65       # ...e onde já está todo apagado


def eye_colors():
    """{id: [(cor, xr, yr), ...]} das âncoras marcadas como olho."""
    s = open(EMIS, encoding="utf-8").read()
    out = {}
    for m in re.finditer(r"^    (\w+)\s*=\s*\{(.*?)^    \},", s, re.S | re.M):
        eid, body = m.group(1), m.group(2)
        for a in re.finditer(r"\{\s*xr\s*=\s*([\d.]+)\s*,\s*yr\s*=\s*([\d.]+).*?"
                             r"color\s*=\s*\{([^}]*)\}[^}]*\}\s*,?\s*--([^\n]*)",
                             body, re.S):
            if re.search(r"olho|eye", a.group(4), re.I):
                vals = [float(v) for v in a.group(3).split(",")[:3]]
                out.setdefault(eid, []).append(
                    (tuple(int(v * 255) for v in vals),
                     float(a.group(1)), float(a.group(2))))
    return out


def components(mask):
    h, w = mask.shape
    seen = np.zeros_like(mask)
    comps = []
    for y in range(h):
        for x in range(w):
            if mask[y, x] and not seen[y, x]:
                stack, pts = [(y, x)], []
                seen[y, x] = True
                while stack:
                    cy, cx = stack.pop()
                    pts.append((cy, cx))
                    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        ny, nx = cy + dy, cx + dx
                        if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not seen[ny, nx]:
                            seen[ny, nx] = True
                            stack.append((ny, nx))
                comps.append(pts)
    return comps


def blobs(arr, col, tol=None):
    """Manchas pequenas e claras da cor do olho: [(cy, cx, pts)]."""
    rgb = arr[..., :3].astype(int)
    a = arr[..., 3] > 25
    m = (np.abs(rgb - np.array(col)).sum(axis=2) < (tol or TOL)) & a & (rgb.max(axis=2) > 140)
    out = []
    for pts in components(m):
        ys = [p[0] for p in pts]
        xs = [p[1] for p in pts]
        if len(pts) <= MAX_BLOB and max(ys) - min(ys) < MAX_BOX and max(xs) - min(xs) < MAX_BOX:
            out.append((sum(ys) / len(ys), sum(xs) / len(xs), pts))
    return out


def frames(eid):
    d = os.path.join(ROOT, eid, "animations", "death", "south")
    if not os.path.isdir(d):
        return []
    fs = sorted((f for f in os.listdir(d) if f.endswith(".png")),
                key=lambda f: int(f.split(".")[0]))
    return [os.path.join(d, f) for f in fs]


def match(prev, cur, cy, cx, half=9, search=14):
    """Onde o retalho de `prev` centrado em (cy, cx) foi parar em `cur`:
    busca por SSD (RGB, pesado por alpha) numa janela de +-search px."""
    H, W = prev.shape[:2]
    y0, y1 = int(cy) - half, int(cy) + half + 1
    x0, x1 = int(cx) - half, int(cx) + half + 1
    if y0 < 0 or x0 < 0 or y1 > H or x1 > W:
        return cy, cx
    pa = prev[y0:y1, x0:x1].astype(float)
    best, by, bx = None, cy, cx
    for dy in range(-search, search + 1):
        for dx in range(-search, search + 1):
            yy0, xx0 = y0 + dy, x0 + dx
            if yy0 < 0 or xx0 < 0 or yy0 + (y1 - y0) > H or xx0 + (x1 - x0) > W:
                continue
            ca = cur[yy0:yy0 + (y1 - y0), xx0:xx0 + (x1 - x0)].astype(float)
            d = ((pa - ca) ** 2).sum()
            if best is None or d < best:
                best, by, bx = d, cy + dy, cx + dx
    return by, bx


def process(eid, anchors, write):
    """O olho anda com a cabeça: a posição de cada olho é REGISTRADA quadro
    a quadro (retalho da cabeça do quadro anterior procurado no atual, SSD).
    Só os pixels claros da cor do olho num raio de EYE_R px da posição
    registrada escurecem. Detecção só por cor pegava palha, trigo e fagulha
    do mesmo tom (espantalho, ceifador, touro)."""
    fs = frames(eid)
    n = len(fs)
    if n == 0:
        return []
    imgs = [np.array(Image.open(p).convert("RGBA")) for p in fs]
    H, W = imgs[0].shape[:2]
    pos = [(yr * H, xr * W) for (_, xr, yr) in anchors]
    results = []
    for i, arr in enumerate(imgs):
        if i > 0:
            pos = [match(imgs[i - 1], arr, py, px) for (py, px) in pos]
        Y, X = np.mgrid[0:arr.shape[0], 0:arr.shape[1]]
        rgb = arr[..., :3].astype(int)
        m = np.zeros(arr.shape[:2], bool)
        for j, (col, _, _) in enumerate(anchors):
            py, px = pos[j]
            near = (Y - py) ** 2 + (X - px) ** 2 <= EYE_R ** 2
            hit = near & (np.abs(rgb - np.array(col)).sum(axis=2) < TOL) \
                & (rgb.max(axis=2) > 140) & (arr[..., 3] > 25)
            if not hit.any():
                # cabeça girou e o retalho perdeu o olho: mancha pequena da
                # cor do olho mais perto da posição prevista (até FALLBACK px)
                best, bd = None, FALLBACK
                for (cy, cx, pts) in blobs(arr, col):
                    d = ((cy - py) ** 2 + (cx - px) ** 2) ** 0.5
                    if d < bd:
                        best, bd = (cy, cx, pts), d
                if best:
                    pos[j] = (best[0], best[1])
                    for q in best[2]:
                        hit[q] = True
            m |= hit
        t = i / max(1, n - 1)
        if eid in SWEEP and t >= START:
            # cor do olho ÚNICA no cadáver (frio/roxo num corpo que não tem
            # esse tom): toda mancha pequena dessa cor apaga — inclusive a
            # gema da coroa, o que também é certo: o corpo "desliga"
            for (col, _, _) in anchors:
                for (_, _, pts) in blobs(arr, col, TOL_BY.get(eid)):
                    for q in pts:
                        m[q] = True
        out = arr.copy()
        if t >= START and m.any():
            k = min(1.0, (t - START) / (FULL - START))
            f = rgb.astype(float)
            f[m] = f[m] * (1 - k) + f[m] * 0.22 * k
            out[..., :3] = f.astype(np.uint8)
            if write:
                Image.fromarray(out).save(fs[i])
        results.append((out, m if t >= START else None))
    return results


def preview(out, ids, cols):
    tiles = []
    for eid in ids:
        if eid not in cols:
            continue
        res = process(eid, cols[eid], False)
        if not res:
            continue
        arr, m = res[-1]
        orig = np.array(Image.open(frames(eid)[-1]).convert("RGBA"))
        hl = orig.copy()
        if m is not None:
            hl[m] = (255, 0, 255, 255)
        tiles.append((eid, orig, hl, arr))
    S = 3
    W = max(t[1].shape[1] for t in tiles) * S
    H = max(t[1].shape[0] for t in tiles) * S
    img = Image.new("RGBA", (W * 3 + 12, (H + 4) * len(tiles)), (40, 40, 48, 255))
    for r, (eid, *ims) in enumerate(tiles):
        for c, a in enumerate(ims):
            im = Image.fromarray(a).resize((a.shape[1] * S, a.shape[0] * S), Image.NEAREST)
            img.alpha_composite(im, (c * (W + 6), r * (H + 4)))
    img.save(out)


if __name__ == "__main__":
    cols = eye_colors()
    cmd = sys.argv[1] if len(sys.argv) > 1 else "run"
    if cmd == "preview":
        ids = sys.argv[3:] or sorted(cols)
        preview(sys.argv[2], ids, cols)
    elif cmd == "run":
        for eid in (sys.argv[2:] or sorted(cols)):
            if eid in SKIP or eid not in cols:
                continue
            res = process(eid, cols[eid], True)
            n = sum(int(m.sum()) for _, m in res if m is not None)
            print("[olhos] %-20s %d px apagados" % (eid, n))
