#!/usr/bin/env python3
# tools/bake_boss_idle.py
# ============================================================================
# IDLE DOS CHEFES assado por DESLOCAMENTO a partir de UM quadro base.
# ============================================================================
# Por que não regerar no PixelLab: `animate_image` redesenha o sprite inteiro
# e o chefe DERIVA (medido no lich, Set/2026: ~90% dos pixels mudam entre
# quadros, a capa vira outra forma). Os idles antigos de 4 quadros eram
# justamente isso — 37-46% de pixels mudando entre quadros = chuvisco de
# regeração, não movimento (memory/enemy_pose_and_scene_anchor.md §4).
#
# Aqui cada quadro vem do quadro BASE (`idle/south/0.png`, que também é o
# quadro 0 do hurt e da death): deriva zero por construção, o quadro 0 sai
# IDÊNTICO ao base (o hurt/death continuam emendando sem pulo) e a amplitude
# de cada movimento é um número escolhido aqui.
#
# Movimentos (campo de deslocamento suave, amostragem inversa nearest):
#   rotate — gira uma região em torno de um pivô (asa batendo, braço)
#   shift  — translada uma região, com rampa vertical opcional (capa que
#            balança mais na barra do que no ombro; peito que sobe)
# REGIÃO PASSA DA BORDA: a amostragem é inversa (o destino busca a origem),
# então a região tem que cobrir onde o pano CHEGA, não só onde ele está —
# caixa rente à barra da capa travava o movimento na borda (o lich mexia 4px
# no teste em vez dos ~10 configurados). Por isso várias caixas saem do canvas.
# Cada movimento tem `lag` (fração do ciclo): o pano atrasa em relação ao
# peito — movimento SECUNDÁRIO, não tudo batendo junto.
#
# O ciclo é um LOOP fechado de N quadros (não ping-pong): o EnemyRenderer
# toca com `pose.idle = { fps, cycle = true }` de src/data/enemy_poses.lua.
#
# Uso:
#   python tools/bake_boss_idle.py run [ids...]     # escreve os quadros
#   python tools/bake_boss_idle.py sheet <id> <out> # prancha (sem gravar)
#   python tools/bake_boss_idle.py weights <id> <out> # mapa das regiões
# ============================================================================
import math
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..",
                    "assets", "sprites", "characters", "enemies")


# ---------------------------------------------------------------------------
# Regiões: peso 0..1 com borda macia (feather em px). Coordenadas = pixels do
# canvas do idle (as mesmas de `love . sheet` / zoom com régua).
# ---------------------------------------------------------------------------
def ellipse(cx, cy, rx, ry, feather=6):
    return ("ellipse", cx, cy, rx, ry, feather)


def box(x0, y0, x1, y1, feather=6):
    return ("box", x0, y0, x1, y1, feather)


def region_weight(spec, X, Y):
    kind = spec[0]
    if kind == "ellipse":
        _, cx, cy, rx, ry, f = spec
        # distância "normalizada" convertida em px aproximados na borda
        d = np.sqrt(((X - cx) / rx) ** 2 + ((Y - cy) / ry) ** 2)
        edge_px = (d - 1.0) * min(rx, ry)
        return np.clip(0.5 - edge_px / max(1e-6, f), 0, 1)
    if kind == "box":
        _, x0, y0, x1, y1, f = spec
        dx = np.maximum(x0 - X, X - x1)
        dy = np.maximum(y0 - Y, Y - y1)
        edge_px = np.maximum(dx, dy)
        return np.clip(0.5 - edge_px / max(1e-6, f), 0, 1)
    raise ValueError(kind)


def weight(motion, X, Y):
    w = np.zeros_like(X, dtype=np.float64)
    for spec in motion.get("regions", []):
        w = np.maximum(w, region_weight(spec, X, Y))
    for spec in motion.get("exclude", []):
        w = w * (1 - region_weight(spec, X, Y))
    ramp = motion.get("ramp")   # ("y", y0, y1): 0 em y0 → 1 em y1
    if ramp:
        _, y0, y1 = ramp
        r = np.clip((Y - y0) / float(y1 - y0), 0, 1)
        w = w * (r * r * (3 - 2 * r))      # smoothstep
    return w


# ---------------------------------------------------------------------------
# CONFIG POR CHEFE — regiões lidas OLHANDO o quadro 0 de cada um com régua
# (doutrina: olhar a arte antes de decidir o movimento).
# ---------------------------------------------------------------------------
# PÉS FIXOS dos apoiados: a capa que balança passa rente às botas e a borda
# macia da região arrastava pixels do pé (o pé "patinava" 1px e, somado ao
# contorno de 1px que existia embaixo, o chefe lia flutuando — Out/2026).
# Caixas medidas nas linhas 104+ do quadro 0 (colunas com conteúdo).
TYRANT_FEET = [box(24, 102, 54, 140, 1), box(69, 102, 99, 140, 1)]
MONARCH_FEET = [box(33, 102, 57, 140, 1), box(66, 102, 85, 140, 1)]

CONFIG = {
    # Rei-carniça (ato 1): asas abertas que BATEM (rotação no ombro), peito
    # que estufa, talões pendurados que balançam atrasados.
    "carrion_king": {
        "frames": 12,
        "motions": [
            {"type": "rotate", "pivot": (52, 46), "angle": -10.0, "lag": 0.0,
             "regions": [ellipse(30, 66, 30, 46, 8)],
             "exclude": [ellipse(74, 60, 26, 40, 6)]},
            {"type": "rotate", "pivot": (96, 46), "angle": 10.0, "lag": 0.0,
             "regions": [ellipse(118, 66, 30, 46, 8)],
             "exclude": [ellipse(74, 60, 26, 40, 6)]},
            {"type": "shift", "dx": 0, "dy": -2.0, "lag": 0.08,
             "regions": [box(40, 8, 108, 98, 10)], "ramp": None},
            {"type": "shift", "dx": 0, "dy": -1.5, "lag": 0.25,
             "regions": [box(44, 96, 104, 128, 6)]},
        ],
    },
    # Lich da Torre (ato 2): capa em leque que ondula com atraso, barra do
    # manto que sobe/desce, botas penduradas balançando. Cajado FORA (madeira
    # não é pano) — o orbe pulsa no BossAura.
    "tower_lich": {
        "frames": 12,
        "motions": [
            # aba direita da capa: desliza pra fora e sobe na barra
            {"type": "shift", "dx": 5.0, "dy": -2.4, "lag": 0.18,
             "regions": [box(84, 52, 160, 150, 8)], "ramp": ("y", 52, 112)},
            # aba esquerda (atrás do cajado): espelhada, atrasada
            {"type": "shift", "dx": -3.5, "dy": -2.0, "lag": 0.30,
             "regions": [box(-20, 66, 40, 150, 6)], "ramp": ("y", 66, 112),
             "exclude": [box(24, 0, 44, 131, 2)]},
            # barra do manto central
            {"type": "shift", "dx": 1.0, "dy": -1.6, "lag": 0.42,
             "regions": [box(44, 92, 84, 112, 6)], "ramp": ("y", 92, 112)},
            # botas penduradas: balanço de pêndulo atrasado
            {"type": "rotate", "pivot": (68, 110), "angle": 5.0, "lag": 0.55,
             "regions": [box(48, 112, 88, 131, 4)]},
            # tronco inteiro respira (cajado fora)
            {"type": "shift", "dx": 0, "dy": -1.4, "lag": 0.0,
             "regions": [box(38, 10, 100, 80, 10)],
             "exclude": [box(8, 0, 44, 131, 3)]},
        ],
    },
    # Tirano do abismo (ato 3, o dono gostou): respiração pesada de fornalha
    # e capa que pesa. Pés FIXOS (apoiado).
    "abyss_tyrant": {
        "frames": 12,
        "motions": [
            {"type": "shift", "dx": 0, "dy": -1.6, "lag": 0.0,
             "regions": [box(20, 0, 104, 92, 12)]},
            {"type": "shift", "dx": -2.5, "dy": 0, "lag": 0.25,
             "regions": [box(-20, 40, 30, 118, 6)], "ramp": ("y", 40, 116),
             "exclude": TYRANT_FEET},
            {"type": "shift", "dx": 2.5, "dy": 0, "lag": 0.25,
             "regions": [box(94, 40, 145, 118, 6)], "ramp": ("y", 40, 116),
             "exclude": TYRANT_FEET},
        ],
    },
    # Monarca do inverno (ato 4): capa que tremula (a aba direita é a
    # inclinação da arte — balançando ela lê como pano ao vento, não torto),
    # peito respira, cajado parado. Pés FIXOS.
    "winter_monarch": {
        "frames": 12,
        "motions": [
            {"type": "shift", "dx": 0, "dy": -1.4, "lag": 0.0,
             "regions": [box(28, 14, 92, 84, 10)],
             "exclude": [box(0, 0, 32, 129, 3)]},
            {"type": "shift", "dx": 3.5, "dy": -1.5, "lag": 0.22,
             "regions": [box(86, 76, 145, 120, 6)], "ramp": ("y", 76, 116),
             "exclude": MONARCH_FEET},
            {"type": "shift", "dx": -2.0, "dy": -0.8, "lag": 0.35,
             "regions": [box(-10, 80, 34, 114, 5)], "ramp": ("y", 80, 112),
             "exclude": [box(30, 40, 46, 129, 2)] + MONARCH_FEET},
        ],
    },
    # Colosso podre (ato 5): fôlego de bicho enorme — peito/ombros sobem,
    # braços pendem e balançam atrasados. Pés FIXOS.
    "rot_colossus": {
        "frames": 12,
        "motions": [
            {"type": "shift", "dx": 0, "dy": -2.2, "lag": 0.0,
             "regions": [box(22, 0, 100, 84, 12)]},
            {"type": "rotate", "pivot": (34, 60), "angle": 4.0, "lag": 0.2,
             "regions": [box(10, 66, 40, 104, 6)]},
            {"type": "rotate", "pivot": (90, 60), "angle": -4.0, "lag": 0.2,
             "regions": [box(84, 66, 114, 104, 6)]},
        ],
    },
    # Rainha do eclipse (ato 6): asas que abrem e fecham devagar e capa em
    # leque ondulando na barra. Flutuante.
    "eclipse_queen": {
        "frames": 12,
        "motions": [
            {"type": "rotate", "pivot": (60, 44), "angle": -6.0, "lag": 0.0,
             "regions": [ellipse(30, 56, 34, 60, 8)],
             "exclude": [box(52, 26, 90, 135, 4)]},
            {"type": "rotate", "pivot": (80, 44), "angle": 6.0, "lag": 0.0,
             "regions": [ellipse(110, 56, 34, 60, 8)],
             "exclude": [box(52, 26, 90, 135, 4)]},
            {"type": "shift", "dx": 0, "dy": -1.4, "lag": 0.1,
             "regions": [box(50, 14, 92, 80, 8)]},
            {"type": "shift", "dx": 2.5, "dy": -1.2, "lag": 0.35,
             "regions": [box(10, 96, 130, 160, 8)], "ramp": ("y", 96, 134)},
        ],
    },
}


def displacement(cfg, k, n, X, Y):
    """Campo (dx, dy) do quadro k. Quadro 0 = zero exato."""
    dx = np.zeros_like(X, dtype=np.float64)
    dy = np.zeros_like(X, dtype=np.float64)
    theta = 2 * math.pi * k / n
    for m in cfg["motions"]:
        lag = 2 * math.pi * m.get("lag", 0.0)
        # (cos(lag) - cos(theta - lag)) / 2 : 0 no quadro 0, faixa total 1
        p = (math.cos(lag) - math.cos(theta - lag)) / 2.0
        w = weight(m, X, Y)
        if m["type"] == "shift":
            dx += w * m.get("dx", 0) * p
            dy += w * m.get("dy", 0) * p
        elif m["type"] == "rotate":
            px, py = m["pivot"]
            a = math.radians(m["angle"]) * p * w
            rx, ry = X - px, Y - py
            nx = px + rx * np.cos(a) - ry * np.sin(a)
            ny = py + rx * np.sin(a) + ry * np.cos(a)
            dx += nx - X
            dy += ny - Y
    return dx, dy


def bake(bid, write=True):
    cfg = CONFIG[bid]
    d = os.path.join(ROOT, bid, "animations", "idle", "south")
    base = np.array(Image.open(os.path.join(d, "0.png")).convert("RGBA"))
    h, w = base.shape[:2]
    Y, X = np.mgrid[0:h, 0:w].astype(np.float64)
    n = cfg["frames"]
    frames = []
    for k in range(n):
        if k == 0:
            frames.append(base.copy())
            continue
        dx, dy = displacement(cfg, k, n, X, Y)
        # amostragem INVERSA: o pixel de destino busca a origem p - d(p)
        sx = np.rint(X - dx).astype(int)
        sy = np.rint(Y - dy).astype(int)
        valid = (sx >= 0) & (sx < w) & (sy >= 0) & (sy < h)
        out = np.zeros_like(base)
        out[valid] = base[sy[valid], sx[valid]]
        frames.append(out)
    if write:
        for f in os.listdir(d):
            if f.endswith(".png"):
                os.remove(os.path.join(d, f))
        for i, fr in enumerate(frames):
            Image.fromarray(fr).save(os.path.join(d, "%d.png" % i))
        print("[bake] %s: %d quadros em %s" % (bid, n, d))
    return frames


def sheet(frames, out, s=3):
    h, w = frames[0].shape[:2]
    cols = min(6, len(frames))
    rows = (len(frames) + cols - 1) // cols
    img = Image.new("RGBA", (cols * (w * s + 6), rows * (h * s + 6)),
                    (40, 40, 48, 255))
    for i, fr in enumerate(frames):
        im = Image.fromarray(fr).resize((w * s, h * s), Image.NEAREST)
        img.alpha_composite(im, ((i % cols) * (w * s + 6),
                                 (i // cols) * (h * s + 6)))
    img.save(out)


def weights_map(bid, out, s=4):
    cfg = CONFIG[bid]
    d = os.path.join(ROOT, bid, "animations", "idle", "south")
    base = Image.open(os.path.join(d, "0.png")).convert("RGBA")
    w, h = base.size
    Y, X = np.mgrid[0:h, 0:w].astype(np.float64)
    tint = np.zeros((h, w, 4))
    cols = [(255, 60, 60), (60, 255, 60), (60, 120, 255), (255, 220, 40),
            (255, 60, 255), (40, 255, 255)]
    for i, m in enumerate(cfg["motions"]):
        wt = weight(m, X, Y)
        c = cols[i % len(cols)]
        for ch in range(3):
            tint[..., ch] = np.maximum(tint[..., ch], wt * c[ch])
        tint[..., 3] = np.maximum(tint[..., 3], wt * 120)
    bg = Image.new("RGBA", (w, h), (40, 40, 48, 255))
    bg.alpha_composite(base)
    bg.alpha_composite(Image.fromarray(tint.astype(np.uint8)))
    bg.resize((w * s, h * s), Image.NEAREST).save(out)


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "run"
    if cmd == "run":
        ids = sys.argv[2:] or list(CONFIG.keys())
        for bid in ids:
            bake(bid)
    elif cmd == "sheet":
        sheet(bake(sys.argv[2], write=False), sys.argv[3])
    elif cmd == "weights":
        weights_map(sys.argv[2], sys.argv[3])
    else:
        print(__doc__ or "uso: run | sheet <id> <out> | weights <id> <out>")
        sys.exit(1)
