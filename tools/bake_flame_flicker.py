#!/usr/bin/env python3
# tools/bake_flame_flicker.py
# ============================================================================
# FOGO PINTADO QUE TREMULA (Out/2026, dono: "as chamas no ombro da efígie
# ficam paradas").
# ============================================================================
# Os idles assados por deslocamento (bake_boss_idle / pipeline dos inimigos
# novos) carregam o fogo pintado junto do corpo: ele balança com o ombro,
# mas não QUEIMA. Aqui, por cima de cada quadro do idle (e do hurt), cada
# região de fogo declarada ganha a linguagem dos braseiros do salão
# (HallAnim): linhas que ondulam pro lado, pontas que sobem, degrau de cor —
# sem suavização, pixel inteiro.
#
#   * máscara do fogo = pixels quentes e saturados DENTRO da caixa da região
#   * a chama ESTICA a partir da base (só cresce: o que ficaria vazio ao
#     encolher não tem como ser pintado sem inventar o que está atrás)
#   * ondulação horizontal mais forte nas pontas que na base
#   * degrau de cor: metade das vezes as pontas sobem um tom (amarelo)
#   * o resto do quadro (corpo) não muda: o bicho continua no modelo
#
# Ciclo de 3 tremidas por volta do idle (12 quadros a 5-6 fps ≈ 0,7s por
# tremida). Rodar UMA vez sobre o idle/hurt atual (rodar de novo estica de
# novo). Pra refazer: git checkout dos PNGs e rodar.
#
# Uso: python tools/bake_flame_flicker.py preview <out.png> [ids]
#      python tools/bake_flame_flicker.py run [ids]
# ============================================================================
import math
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..",
                    "assets", "sprites", "characters", "enemies")

# caixas (x0, y0, x1, y1) no canvas do idle, lidas com régua no quadro 0
CONFIG = {
    "wicker_effigy": [(32, 26, 48, 50), (78, 26, 94, 50), (56, 60, 72, 76)],
    "hellhound": [(0, 0, 72, 22), (73, 3, 93, 30)],   # crina acima dos olhos
    "abyss_acolyte": [(10, 8, 30, 26)],
}
CYCLES = 3        # tremidas por volta do clip
STRETCH = 0.30    # quanto a ponta sobe no pico (fração da altura da chama)
RIPPLE = 1.4      # px de ondulação na ponta


def flame_mask(a):
    rgb = a[..., :3].astype(float) / 255
    mx = rgb.max(2)
    mn = rgb.min(2)
    s = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    return (a[..., 3] > 25) & (r >= g) & (g >= b * 0.8) & (r > 0.70) \
        & (s > 0.45) & (mx > 0.55)


def flicker(arr, boxes, k, n, seed=0.0):
    out = arr.copy()
    H, W = arr.shape[:2]
    fm = flame_mask(arr)
    for bi, (x0, y0, x1, y1) in enumerate(boxes):
        reg = np.zeros_like(fm)
        reg[max(0, y0):min(H, y1), max(0, x0):min(W, x1)] = True
        m = fm & reg
        if m.sum() < 4:
            continue
        ys, xs = np.nonzero(m)
        base, top = ys.max(), ys.min()
        hgt = base - top + 1
        ph = 2 * math.pi * CYCLES * k / n + seed + bi * 1.7
        s = 1.0 + STRETCH * (0.5 + 0.5 * math.sin(ph))      # 1 .. 1+STRETCH
        hot = math.sin(ph * 2) > 0                          # degrau de cor
        lumas = arr[..., :3].astype(int).sum(2)
        yy0 = max(0, top - int(hgt * STRETCH) - 2)
        for y in range(yy0, base + 1):
            f = (base - y) / max(1, hgt)                    # 0 base .. 1 ponta
            dx = int(round(RIPPLE * math.sin(ph * 1.3 + y * 0.9) * min(1.0, f)))
            sy = int(round(base - (base - y) / s))
            if sy < 0 or sy >= H:
                continue
            for x in range(max(0, x0 - 2), min(W, x1 + 2)):
                sx = x - dx
                if 0 <= sx < W and m[sy, sx]:
                    c = arr[sy, sx].copy()
                    if hot and f > 0.55:
                        # ponta um tom acima: puxa pro amarelo claro
                        c[1] = min(255, int(c[1]) + 40)
                        c[2] = min(255, int(c[2]) + 18)
                    out[y, x] = c
        del lumas
    return out


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
            out = flicker(arr, CONFIG[eid], k, len(fs))
            if write:
                Image.fromarray(out).save(p)
            res.append((clip, k, out))
    return res


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "run"
    if cmd == "preview":
        out, ids = sys.argv[2], (sys.argv[3:] or list(CONFIG))
        rows = []
        for eid in ids:
            fr = [o for (c, k, o) in process(eid, False) if c == "idle"]
            rows.append(fr)
        S = 3
        W = max(f.shape[1] for r in rows for f in r) * S
        H = max(f.shape[0] for r in rows for f in r) * S
        img = Image.new("RGBA", (W * 12 + 60, (H + 6) * len(rows)), (40, 40, 48, 255))
        for ri, r in enumerate(rows):
            for ci, f in enumerate(r[:12]):
                im = Image.fromarray(f).resize((f.shape[1] * S, f.shape[0] * S), Image.NEAREST)
                img.alpha_composite(im, (ci * (W + 4), ri * (H + 6)))
        img.save(out)
    else:
        for eid in (sys.argv[2:] or list(CONFIG)):
            process(eid, True)
            print("[fogo] %s: idle + hurt tremulando" % eid)
