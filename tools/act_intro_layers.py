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
    # atos 2-6: mesma série (a pintura do ato 1 foi a referência de estilo); arco por luminância (contraluz)
    2: {"horizon": 150, "arch_zone": (125, 120, 60), "arch_lum": (170, 20, 310, 90),
        "traveler": (313, 168, 342, 224), "lantern": (0, 0), "sun": (415, 80)},
    3: {"horizon": 150, "arch_zone": (125, 120, 60), "arch_lum": (170, 20, 310, 90),
        "traveler": (301, 181, 332, 232), "lantern": (270, 160), "sun": (350, 100)},
    4: {"horizon": 130, "arch_zone": (125, 120, 60), "arch_lum": (170, 20, 310, 90), "lum_k": 0.42, "fill_holes": False,
        "traveler": (261, 163, 288, 199), "keep_traveler": True, "lantern": (0, 0), "sun": (330, 120)},
    5: {"horizon": 140, "arch_zone": (125, 120, 60), "arch_lum": (170, 20, 310, 90),
        "traveler": (261, 159, 290, 199), "keep_traveler": True, "lantern": (283, 130), "sun": (360, 72)},
    6: {"horizon": 140, "arch_zone": (125, 120, 60), "arch_lum": (170, 110, 310, 135), "lum_k": 0.40, "fill_holes": False,
        "traveler": (269, 165, 290, 207), "keep_traveler": True, "lantern": (0, 0), "sun": (320, 125)},
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


def arch_mask_lum(c, zone, sky_box, k=0.62, fill=True):
    """Arco em contraluz: o que é bem mais escuro que o céu e encosta na borda da tela."""
    L = c.astype(int) @ np.array([0.3, 0.59, 0.11])
    x0, y0, x1, y1 = sky_box
    thr = np.median(L[y0:y1, x0:x1]) * k
    H, W = L.shape
    ys, xs = np.mgrid[0:H, 0:W]
    left, right, top = zone
    m = (L < thr) & ((xs < left) | (xs > W - right) | (ys < top))
    m = nd.binary_opening(m, iterations=1)
    lab, _ = nd.label(m)
    border = set(np.unique(np.r_[lab[0, :], lab[:, 0], lab[:, -1]])) - {0}
    m = np.isin(lab, list(border))
    m = nd.binary_closing(m, iterations=2)
    return nd.binary_fill_holes(m) if fill else m


def main(act):
    P = ACT[act]
    src = os.path.join(ROOT, "tools", "preview_out", "cenas_ato", f"ato{act}", "raw", "master__0.png")
    full = np.array(Image.open(src).convert("RGB")).astype(int)
    if "crop" in P:
        box = P["crop"]
    else:   # o modelo deixa uma margem de cor lisa: a área útil é o que difere do canto
        diff = np.abs(full - full[3, 3]).sum(2) > 12
        ys, xs = np.where(diff)
        box = (xs.min(), ys.min(), xs.min() + 480, ys.min() + min(270, ys.max() + 1 - ys.min()))
    c = np.array(Image.open(src).convert("RGB").crop(box))
    if c.shape[0] < 270:                     # a cena é 480x270 (escala inteira em 1080p): repete a última linha
        c = np.pad(c, ((0, 270 - c.shape[0]), (0, 0), (0, 0)), mode="edge")
    H, W = c.shape[:2]
    rgba = np.dstack([c, np.full((H, W), 255, np.uint8)])
    if "arch_lum" in P:
        arch = arch_mask_lum(c, P["arch_zone"], P["arch_lum"], P.get("lum_k", 0.62), P.get("fill_holes", True))
    else:
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
    if P.get("keep_traveler"):     # viajante menor que o loop do ato 1: fica parado na camada do chão
        hole = arch
    else:
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
