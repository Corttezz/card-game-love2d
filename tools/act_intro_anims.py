#!/usr/bin/env python3
"""Limpa os loops do PixelLab da cena de abertura e grava em assets/sprites/act_intro/act<N>/.

uso: python tools/act_intro_anims.py <ato>
- traveler: só a figura (maior componente + o cajado), nada acima do topo do capuz do quadro 0
  (o modelo inventou um brilho flutuando acima da cabeça em alguns quadros); recortado no mesmo
  retângulo em todos os quadros, para não tremer.
- crow: penas puxadas para quase preto (o modelo tingiu de roxo), olho vermelho vira ouro apagado.
"""
import glob, os, sys
import numpy as np
from PIL import Image
from scipy import ndimage as nd

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def frames(d, prefix):
    fs = glob.glob(os.path.join(d, prefix + "_*.png"))
    return [Image.open(f).convert("RGBA") for f in sorted(fs, key=lambda s: int(s.rsplit("_", 1)[1][:-4]))]


def clean_traveler(ims):
    arrs = [np.array(im) for im in ims]
    a0 = arrs[0][..., 3] > 0
    top = np.where(a0.any(1))[0].min()
    out = []
    for a in arrs:
        m = a[..., 3] > 0
        m[:max(0, top - 1)] = False
        lab, n = nd.label(m, structure=np.ones((3, 3)))
        if n:
            sizes = nd.sum(m, lab, range(1, n + 1))
            keep = [i + 1 for i, s in enumerate(sizes) if s >= 0.02 * sizes.max()]  # figura + cajado; some faísca
            m = np.isin(lab, keep)
        b = a.copy(); b[~m] = 0
        # brilho claro fora da silhueta do quadro 0 (+1 px) = sobra do "halo" inventado: apaga
        Lb = b[..., :3].astype(int) @ np.array([0.3, 0.59, 0.11])
        halo = (Lb > 150) & ~nd.binary_dilation(a0, iterations=1) & (b[..., 3] > 0)
        b[halo] = 0
        out.append(b)
    union = np.any([b[..., 3] > 0 for b in out], axis=0)
    ys, xs = np.where(union)
    box = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
    return [Image.fromarray(b).crop(box) for b in out], box


def clean_crow(ims):
    out = []
    for im in ims:
        a = np.array(im).astype(float)
        rgb = a[..., :3]
        L = rgb @ np.array([0.3, 0.59, 0.11])
        red = (rgb[..., 0] > 140) & (rgb[..., 1] < 90)
        dark = np.stack([L * 0.62 + 10, L * 0.58 + 9, L * 0.55 + 10], -1)   # preto-azulado quente, sem roxo
        rim = L > 120
        dark[rim] = np.stack([L * 0.85, L * 0.72, L * 0.55], -1)[rim]        # brilho de borda quente
        dark[red] = [150, 118, 60]
        a[..., :3] = np.clip(dark, 0, 255)
        out.append(Image.fromarray(a.astype(np.uint8)))
    return out


def sheet(ims, path):
    w, h = ims[0].size
    s = Image.new("RGBA", (w * len(ims), h), (0, 0, 0, 0))
    for i, im in enumerate(ims):
        s.alpha_composite(im, (i * w, 0))
    s.save(path, optimize=True)
    return w, h


def main(act):
    src = os.path.join(ROOT, "tools", "preview_out", "cenas_ato", f"ato{act}", "anim")
    dst = os.path.join(ROOT, "assets", "sprites", "act_intro", f"act{act}")
    tv = frames(os.path.join(src, "traveler"), "traveler")[:-1]      # o último repete o primeiro (loop)
    tv, box = clean_traveler(tv)
    tw, th = sheet(tv, os.path.join(dst, "traveler_anim.png"))
    # encaixe: desloca o quadro 0 sobre o recorte parado da pintura até a sobreposição de pixels ser máxima
    st = np.array(Image.open(os.path.join(dst, "traveler.png")))[..., 3] > 0
    f0 = np.array(tv[0])[..., 3] > 0
    best = (-1, 0, 0)
    for dy in range(-6, 7):
        for dx in range(-6, 7):
            H_, W_ = max(st.shape[0], f0.shape[0] + dy + 6) + 12, max(st.shape[1], f0.shape[1] + dx + 6) + 12
            A = np.zeros((H_, W_), bool); B = np.zeros((H_, W_), bool)
            A[6:6 + st.shape[0], 6:6 + st.shape[1]] = st
            B[6 + dy:6 + dy + f0.shape[0], 6 + dx:6 + dx + f0.shape[1]] = f0
            sc = (A & B).sum() - 0.5 * (A ^ B).sum()
            if sc > best[0]: best = (sc, dx, dy)
    import re as _re
    lay = open(os.path.join(dst, "layout.lua"), encoding="utf-8").read()
    tx, ty = map(int, _re.search(r"traveler = \{ x = (\d+), y = (\d+)", lay).groups())
    place = (tx + best[1], ty + best[2])
    cr = clean_crow(frames(os.path.join(src, "crow"), "crow")[:-1])
    cw, ch = sheet(cr, os.path.join(dst, "crow_anim.png"))
    with open(os.path.join(dst, "anims.lua"), "w", encoding="utf-8", newline="\n") as f:
        f.write("-- gerado por tools/act_intro_anims.py\nreturn {\n")
        f.write(f"    traveler = {{ file = \"traveler_anim.png\", w = {tw}, h = {th}, frames = {len(tv)}, fps = 6,\n")
        f.write(f"                 x = {place[0]}, y = {place[1]} }},  -- encaixe sobre o recorte parado da pintura\n")
        f.write(f"    crow = {{ file = \"crow_anim.png\", w = {cw}, h = {ch}, frames = {len(cr)}, fps = 10 }},\n}}\n")
    print(f"viajante {len(tv)}q {tw}x{th} em {place}; corvo {len(cr)}q {cw}x{ch}")


if __name__ == "__main__":
    main(int(sys.argv[1]))
