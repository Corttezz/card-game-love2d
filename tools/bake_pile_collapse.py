#!/usr/bin/env python3
# tools/bake_pile_collapse.py
# ============================================================================
# MORTE DE CRIATURA-PILHA por DESMORONAMENTO (plague_rats, Out/2026).
# ============================================================================
# A morte anterior (pixellab_new_enemies.py bake_pile_death) AFUNDAVA o monte
# inteiro na terra, cortado numa linha reta: o dono viu "os ratos morrem e
# ficam errado no chão" — corpo atravessando a estrada e sprite cortado.
# Aqui o monte DESABA sobre o próprio chão: cada quadro vem do quadro 0 do
# idle cortado em faixas horizontais; as de cima CAEM (queda acelerada) e
# escorregam pros lados por cima das de baixo — o que sobra é um monte baixo
# de ratos mortos deitados NA estrada. Olho vermelho apaga e o pelo escurece
# no fim. A faixa de baixo (patas e rabo) não se mexe: o pé continua na
# mesma linha do idle.
#
# Canvas 40px mais largo que o do idle (20 de cada lado) pro monte espalhado
# caber; o EnemyRenderer mede cada clip pelo próprio canvas (clipMetrics).
#
# Uso: python tools/bake_pile_collapse.py [plague_rats]
# ============================================================================
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..",
                    "assets", "sprites", "characters", "enemies")

CONFIG = {
    # faixas horizontais do quadro 0 (y0, y1, dx final, dy final), de cima
    # pra baixo. Cada faixa CAI e escorrega pro lado sem ser redimensionada
    # (pixel intacto); a de baixo desenha por último, na frente. Achatar o
    # monte inteiro (1ª tentativa) dizimava linhas e o cadáver virava
    # chuvisco de contorno.
    "plague_rats": {"frames": 9, "pad": 20,
                    "bands": [(0, 40, -14, 30), (40, 58, 16, 22),
                              (58, 72, -8, 10), (72, 999, 0, 0)]},
}


def bake(eid):
    c = CONFIG[eid]
    base = np.array(Image.open(os.path.join(
        ROOT, eid, "animations", "idle", "south", "0.png")).convert("RGBA"))
    H, W = base.shape[:2]
    OX = c["pad"]
    OW = W + 2 * OX
    d = os.path.join(ROOT, eid, "animations", "death", "south")
    for f in os.listdir(d):
        if f.endswith(".png"):
            os.remove(os.path.join(d, f))
    n = c["frames"]
    for k in range(n):
        t = k / (n - 1)
        e = t * t                       # queda acelerada
        out = np.zeros((H, OW, 4), np.uint8)
        for (y0, y1, dx, dy) in c["bands"]:
            y1 = min(y1, H)
            sx = int(round(dx * e))
            sy = int(round(dy * e))
            ys0 = y0 + sy
            ys1 = min(H, ys0 + (y1 - y0))
            part = base[y0:y0 + (ys1 - ys0)]
            reg = out[ys0:ys1, OX + sx:OX + sx + W]
            m = part[:, :, 3] > 25
            reg[m] = part[m]
        if e > 0.5:
            r, g, b, al = [out[:, :, i].astype(int) for i in range(4)]
            eye = (r > 120) & (g < 80) & (b < 80) & (r > g * 2) & (al > 0)
            out[eye] = (40, 24, 22, 255)
        f = 1 - 0.15 * e
        out[:, :, :3] = (out[:, :, :3] * f).astype(np.uint8)
        Image.fromarray(out).save(os.path.join(d, "%d.png" % k))
    print("[pile-collapse] %s: %d quadros (canvas %dx%d)" % (eid, n, OW, H))


if __name__ == "__main__":
    for eid in (sys.argv[1:] or list(CONFIG.keys())):
        bake(eid)
