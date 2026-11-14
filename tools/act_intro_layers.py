#!/usr/bin/env python3
"""Separa a pintura mestra do PixelLab em camadas de parallax (docs/cenas_de_ato/STYLE.md).

uso: python tools/act_intro_layers.py <ato>
Entrada: tools/preview_out/cenas_ato/ato<N>/raw/master__0.png (+ params em ACT abaixo)
Saída:   assets/sprites/act_intro/act<N>/{far,ground,arch,traveler}.png + layout.lua
As camadas de trás têm o que o arco e o viajante cobrem preenchido com a cor vizinha (só aparece nas bordas
quando a câmera desliza poucos pixels).
"""
import os, sys
import numpy as np
from PIL import Image
from scipy import ndimage as nd

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

ACT = {
    1: {
        "crop": (104, 58, 584, 326),       # área útil da pintura (o modelo deixa margem escura)
        "horizon": 140,                     # corte céu/chão (a névoa esconde a emenda)
        "arch_zone": (120, 110, 62),        # (esq, dir, topo): onde o arco pode estar
        "traveler": (281, 180, 308, 230),   # caixa do viajante na pintura
        "lantern": (285, 151),              # brilho da lanterna do oratório (pinta luz por cima)
        "sun": (365, 115),
    },
}


def fill_behind(img, hole):
    """Preenche o buraco com a cor do pixel válido mais próximo e suaviza só dentro dele."""
    out = img.copy()
    idx = nd.distance_transform_edt(hole, return_distances=False, return_indices=True)
    out[hole] = img[idx[0][hole], idx[1][hole]]
    soft = out.astype(float)
    for _ in range(3):
        blur = nd.uniform_filter(soft, size=(5, 5, 1))
        soft[hole] = blur[hole]
    out[hole] = soft[hole].round().astype(img.dtype)
    return out


def arch_mask(c, zone):
    r, g, b = (c[..., i].astype(int) for i in range(3))
    L = r * 0.3 + g * 0.59 + b * 0.11
    dark = L < 62
    foliage = (g >= r - 4) & (g > b - 12) & (L < 150) & ~(b > g + 4)
    trunk = (r >= g) & (g >= b - 6) & (L < 95) & (r - b < 70)
    tree = (dark | foliage | trunk) & ~(b > r + 6)
    H, W = L.shape
    ys, xs = np.mgrid[0:H, 0:W]
    left, right, top = zone
    cand = tree & ((xs < left) | (xs > W - right) | (ys < top))
    cand = nd.binary_opening(cand, iterations=1)
    lab, _ = nd.label(cand)
    border = set(np.unique(np.r_[lab[0, :], lab[:, 0], lab[:, -1]])) - {0}
    m = np.isin(lab, list(border))
    m = nd.binary_closing(m, iterations=2)
    m = nd.binary_fill_holes(m)
    return nd.binary_opening(m, iterations=1)


def main(act):
    P = ACT[act]
    src = os.path.join(ROOT, "tools", "preview_out", "cenas_ato", f"ato{act}", "raw", "master__0.png")
    c = np.array(Image.open(src).convert("RGB").crop(P["crop"]))
    if c.shape[0] < 270:                     # a cena é 480x270 (escala inteira em 1080p): repete a última linha
        c = np.pad(c, ((0, 270 - c.shape[0]), (0, 0), (0, 0)), mode="edge")
    H, W = c.shape[:2]
    rgba = np.dstack([c, np.full((H, W), 255, np.uint8)])
    arch = arch_mask(c, P["arch_zone"])
    tx0, ty0, tx1, ty1 = P["traveler"]
    # viajante: contorno preto de 1 px fechado; o interior é o personagem (capuz, manto, mochila, cajado)
    box = c[ty0:ty1, tx0:tx1].astype(int)
    Lb = box @ np.array([0.3, 0.59, 0.11])
    trav = np.zeros((H, W), bool)
    dk = (Lb < P.get("outline_l", 48)) | (Lb > 170)  # contorno preto + luz de contorno do capuz
    tm = nd.binary_fill_holes(nd.binary_closing(dk, iterations=1))
    lab, n = nd.label(tm)
    if n:
        sizes = nd.sum(tm, lab, range(1, n + 1))
        keep = [i + 1 for i, s_ in enumerate(sizes) if s_ >= 12]
        tm = np.isin(lab, keep)
    trav[ty0:ty1, tx0:tx1] = tm
    hole = arch | nd.binary_dilation(trav, iterations=1)
    back = fill_behind(c, hole)
    hz = P["horizon"]
    out = os.path.join(ROOT, "assets", "sprites", "act_intro", f"act{act}")
    os.makedirs(out, exist_ok=True)

    def save(name, a):
        Image.fromarray(a).save(os.path.join(out, name + ".png"), optimize=True)

    far = np.dstack([back, np.full((H, W), 255, np.uint8)])
    save("far", far)                                        # céu + montanhas (opaca, inteira)
    ground = far.copy(); ground[:hz - 6, :, 3] = 0           # chão: da linha do horizonte para baixo
    save("ground", ground)
    archa = rgba.copy(); archa[~arch, 3] = 0
    save("arch", archa)
    ys, xs = np.where(trav)
    tv = rgba[ys.min():ys.max() + 1, xs.min():xs.max() + 1].copy()
    tv[~trav[ys.min():ys.max() + 1, xs.min():xs.max() + 1], 3] = 0
    save("traveler", tv)
    with open(os.path.join(out, "layout.lua"), "w", encoding="utf-8", newline="\n") as f:
        f.write("-- gerado por tools/act_intro_layers.py; coordenadas na tela virtual da cena\n")
        f.write("return {\n")
        f.write(f"    size = {{ {W}, {H} }},\n    horizon = {hz},\n")
        f.write(f"    traveler = {{ x = {xs.min()}, y = {ys.min()}, w = {xs.max()-xs.min()+1}, h = {ys.max()-ys.min()+1} }},\n")
        f.write(f"    lantern = {{ {P['lantern'][0]}, {P['lantern'][1]} }},\n    sun = {{ {P['sun'][0]}, {P['sun'][1]} }},\n")
        f.write("}\n")
    print(f"ato {act}: {W}x{H}, arco {arch.mean():.2f}, viajante {tv.shape[1]}x{tv.shape[0]} em ({xs.min()},{ys.min()})")


if __name__ == "__main__":
    main(int(sys.argv[1]))
