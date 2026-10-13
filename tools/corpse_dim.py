#!/usr/bin/env python3
# tools/corpse_dim.py
# ============================================================================
# CADÁVER APAGADO (Out/2026, dono: "o espantalho morto continua com os olhos
# amarelos acesos e o sorriso brilhando").
# ============================================================================
# death_eyes_off.py apagava só a mancha do OLHO rastreada da âncora — no
# espantalho o olho é uma fenda laranja grande e a cara inteira é um rosto
# claro de abóbora com dentes: sobrava brilho. Aqui a regra é do CORPO
# MORTO, não do olho: nos últimos quadros da death, tudo que a arte pinta
# como LUZ (tom saturado e claro — olho, boca acesa, gema, núcleo, brasa,
# chama) perde a luz progressivamente, e o que tem rosto declarado ganha
# PÁLPEBRA fechada e boca apagada.
#
#   glow: max(rgb) > GLOW_V e saturação > GLOW_S  →  escurece até DIM
#   FACES[id]: caixa do rosto no ÚLTIMO quadro (px do canvas da death),
#              rastreada pra trás por SSD nos quadros anteriores; dentro
#              dela, claro vira sombra e cada olho vira um traço escuro
#              (pálpebra) — olho fechado de morto, sem amarelo.
#
# Uso: python tools/corpse_dim.py preview <out.png> [ids]
#      python tools/corpse_dim.py run [ids]
# Rodar UMA vez (escurecer de novo escurece mais).
# ============================================================================
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..",
                    "assets", "sprites", "characters", "enemies")

LAST = 4          # quadros finais que apagam (o último = cadáver segurado)
GLOW_V = 0.58
GLOW_S = 0.45
DIM = 0.42        # fator final do brilho (0 = preto)

# rosto do cadáver: caixa no último quadro + olhos (cx, cy) dentro dela
FACES = {
    # cara de abóbora clara com fenda de olho laranja e dentes (quadro 8)
    "cursed_scarecrow": {"box": (47, 60, 70, 80),
                         "eyes": [(51, 69, 3), (63, 69, 3)]},
}


def frames(eid):
    d = os.path.join(ROOT, eid, "animations", "death", "south")
    if not os.path.isdir(d):
        return []
    return [os.path.join(d, f) for f in
            sorted((f for f in os.listdir(d) if f.endswith(".png")),
                   key=lambda f: int(f.split(".")[0]))]


def match(ref, cur, box, search=10):
    x0, y0, x1, y1 = box
    pa = ref[y0:y1, x0:x1].astype(float)
    H, W = cur.shape[:2]
    best, bd = (0, 0), None
    for dy in range(-search, search + 1):
        for dx in range(-search, search + 1):
            a0, b0 = y0 + dy, x0 + dx
            if a0 < 0 or b0 < 0 or a0 + (y1 - y0) > H or b0 + (x1 - x0) > W:
                continue
            d = ((pa - cur[a0:a0 + (y1 - y0), b0:b0 + (x1 - x0)].astype(float)) ** 2).sum()
            if bd is None or d < bd:
                best, bd = (dx, dy), d
    return best


def glow_mask(arr):
    rgb = arr[..., :3].astype(float) / 255
    mx = rgb.max(2)
    mn = rgb.min(2)
    s = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    return (arr[..., 3] > 25) & (mx > GLOW_V) & (s > GLOW_S)


def process(eid, write):
    fs = frames(eid)
    n = len(fs)
    if n == 0:
        return []
    imgs = [np.array(Image.open(p).convert("RGBA")) for p in fs]
    face = FACES.get(eid)
    out_frames = []
    for i, arr in enumerate(imgs):
        j = i - (n - LAST)
        out = arr.copy()
        if j >= 0:
            k = (j + 1) / LAST                       # 0.25 .. 1
            f = 1 - (1 - DIM) * k
            g = glow_mask(arr)
            rgb = out[..., :3].astype(float)
            # perde a luz e um pouco da cor (brasa morta, não lâmpada)
            lum = rgb.mean(axis=2, keepdims=True)
            rgb[g] = (rgb[g] * (1 - 0.35 * k) + lum[g] * 0.35 * k) * f
            if face:
                dx, dy = (0, 0) if i == n - 1 else match(imgs[-1], arr, face["box"])
                x0, y0, x1, y1 = face["box"]
                x0, x1, y0, y1 = x0 + dx, x1 + dx, y0 + dy, y1 + dy
                sub = rgb[y0:y1, x0:x1]
                a = arr[y0:y1, x0:x1, 3] > 25
                bright = a & (sub.max(axis=2) > 150)
                sub[bright] = sub[bright] * (1 - 0.45 * k)
                # pálpebra: olho vira um traço escuro na linha do meio, o
                # resto do olho vira pele na sombra
                for (ex, ey, r) in face["eyes"]:
                    ex, ey = ex + dx, ey + dy
                    for yy in range(ey - r + 1, ey + r):
                        for xx in range(ex - r, ex + r + 1):
                            if 0 <= yy < rgb.shape[0] and 0 <= xx < rgb.shape[1] \
                                    and arr[yy, xx, 3] > 25:
                                c = rgb[yy, xx]
                                warm = c[0] > 120 and c[0] > c[2] * 1.4
                                if yy == ey and warm:
                                    rgb[yy, xx] = (52, 30, 18)
                                elif warm:
                                    rgb[yy, xx] = (128, 84, 52)
            out[..., :3] = np.clip(rgb, 0, 255).astype(np.uint8)
            if write:
                Image.fromarray(out).save(fs[i])
        out_frames.append(out)
    return out_frames


def all_ids():
    return sorted(d for d in os.listdir(ROOT) if frames(d))


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "run"
    if cmd == "preview":
        out, ids = sys.argv[2], (sys.argv[3:] or all_ids())
        tiles = []
        for eid in ids:
            before = np.array(Image.open(frames(eid)[-1]).convert("RGBA"))
            after = process(eid, False)[-1]
            tiles.append((before, after))
        S = 2
        W = max(b.shape[1] for b, _ in tiles) * S
        H = max(b.shape[0] for b, _ in tiles) * S
        cols = 4
        rows = (len(tiles) + cols - 1) // cols
        img = Image.new("RGBA", (cols * (2 * W + 16), rows * (H + 6)), (40, 40, 48, 255))
        for i, (b, a) in enumerate(tiles):
            x = (i % cols) * (2 * W + 16)
            y = (i // cols) * (H + 6)
            for c, t in enumerate((b, a)):
                img.alpha_composite(Image.fromarray(t).resize(
                    (t.shape[1] * S, t.shape[0] * S), Image.NEAREST), (x + c * (W + 4), y))
        img.save(out)
    else:
        for eid in (sys.argv[2:] or all_ids()):
            process(eid, True)
            print("[cadaver] %s apagado" % eid)
