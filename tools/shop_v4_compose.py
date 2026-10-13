"""
tools/shop_v4_compose.py: monta a pintura da Loja v4 (640x360).

  parede (PixelLab) + DEGRAU das cartas + MESA dos objetos.

As duas superfícies são desenhadas aqui, na grade da arte, com as arestas
EXATAMENTE em 1:8: a textura de madeira é RETA (tábuas na horizontal, gerada
no PixelLab) e cada coluna x é deslocada floor(x/8) linhas pra cima (o
cisalhamento é inteiro: nenhum pixel é reamostrado, os degraus têm todos 8 px).
A cor sai de uma RAMPA de 8 tons de madeira sépia (a mesma família do
ShelfItem.WOOD e dos salões), escolhida pela luminância da textura x a luz da
cena (vela à esquerda), com dither Bayer 4x4 entre tons vizinhos: pixel art
de verdade, sem gradiente contínuo.

  python tools/pixellab_shop_v4.py compose <wall.png|none> <saida.png> [--warm]
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixellab_shop_v4 as V

W, H, RUN, G = V.W, V.H, V.RUN, V.G
RAW = V.RAW

RAMP = [
    (18, 8, 10), (38, 18, 16), (60, 29, 21), (84, 43, 27),
    (112, 60, 33), (144, 82, 41), (180, 110, 52), (222, 150, 74),
]
HI = (246, 196, 112)          # aresta iluminada (1 px)
INK = (14, 6, 8)              # contorno

BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def yl(y0, x):
    return y0 - (x // RUN)


def lum(c):
    return (0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]) / 255.0


def tone(v, x, y):
    """v em 0..len(RAMP)-1 contínuo -> tom da rampa com dither entre vizinhos."""
    v = max(0.0, min(len(RAMP) - 1.0, v))
    i = int(v)
    f = v - i
    # degrau limpo; dither (xadrez) só na faixa estreita entre dois tons
    if i + 1 < len(RAMP):
        if f > 0.62 or (f > 0.38 and (x + y) % 2 == 0):
            i += 1
    return RAMP[i]


class Tex:
    """Textura reta com repetição espelhada (sem costura) e luminância normalizada."""

    def __init__(self, path, rows=None):
        im = Image.open(path).convert("RGB")
        if rows:
            im = im.crop((0, rows[0], im.width, rows[1]))
        self.w, self.h = im.size
        self.px = im.load()
        ls = sorted(lum(self.px[x, y]) for x in range(self.w) for y in range(self.h))
        self.lo, self.hi = ls[len(ls) // 20], ls[-len(ls) // 20]

    def at(self, u, v):
        p = (u // self.w) % 2
        u = u % self.w
        if p:
            u = self.w - 1 - u
        v = max(0, min(self.h - 1, v))
        l = lum(self.px[u, v])
        return max(0.0, min(1.0, (l - self.lo) / max(1e-6, self.hi - self.lo)))


def light(x, y):
    """Luz da cena: vela/lanterna à esquerda no alto; o lado direito cai."""
    return 1.0 - 0.55 * (x / W) - 0.15 * (y / H)


def compose(wall_path, out, warm=False):
    wood_top = Tex(os.path.join(RAW, "wood_top.png"))
    wood_front = Tex(os.path.join(RAW, "wood_front.png"), rows=(14, 80))
    if wall_path and wall_path != "none":
        wall = Image.open(wall_path).convert("RGB").resize((W, H), Image.NEAREST)
    else:
        wall = Image.new("RGB", (W, H), (30, 18, 16))
    img = wall.copy()
    px = img.load()
    wpx = wall.load()

    for x in range(W):
        y_st, y_se = yl(G["shelf_top"], x), yl(G["shelf_edge"], x)
        y_sf, y_tb = yl(G["shelf_face"], x), yl(G["table_back"], x)
        y_te = yl(G["table_edge"], x)
        # parede: escurece em degraus ao descer pro degrau (sombra do móvel)
        for y in range(0, y_st):
            d = y_st - y
            if d < 22:
                k = 0.45 + 0.55 * (d / 22.0)
                if BAYER[y % 4][x % 4] < (1 - k) * 16:
                    c = wpx[x, y]
                    px[x, y] = (int(c[0] * 0.55), int(c[1] * 0.55), int(c[2] * 0.55))
        # ===== degrau das cartas =====
        # tampo (face de cima): 1 tábua, clara na frente
        for y in range(y_st, y_se):
            v = y - y_st
            t = wood_top.at(x, 20 + v)
            base = 3.2 + 1.6 * t + 0.25 * v
            px[x, y] = tone(base * light(x, y) + 0.6, x, y)
        px[x, y_st] = INK if x % RUN else RAMP[1]
        px[x, y_se - 1] = HI if light(x, y_se) > 0.62 else RAMP[7]       # aresta da frente, iluminada
        # face da frente: tábua escura
        for y in range(y_se, y_sf):
            v = y - y_se
            t = wood_front.at(x + 37, v)
            base = 1.4 + 1.4 * t - 0.08 * v
            px[x, y] = tone(base * light(x, y) + 0.3, x, y)
        px[x, y_se] = RAMP[2]
        px[x, y_sf - 1] = INK
        # vão atrás do balcão: sombra funda
        for y in range(y_sf, y_tb):
            px[x, y] = RAMP[0] if (y - y_sf) > 2 or BAYER[y % 4][x % 4] < 10 else INK
        # ===== tampo da mesa =====
        depth = y_te - y_tb
        for y in range(y_tb, y_te):
            v = y - y_tb
            t = wood_top.at(x + 113, v % wood_top.h)
            front = v / depth                        # 0 = fundo, 1 = frente
            base = 2.0 + 2.2 * t + 1.2 * front
            px[x, y] = tone(base * light(x, y) + 0.5, x, y)
        px[x, y_tb] = INK
        px[x, y_tb + 1] = RAMP[1]
        px[x, y_te - 2] = RAMP[6] if light(x, y_te) > 0.55 else RAMP[5]
        px[x, y_te - 1] = HI if light(x, y_te) > 0.7 else RAMP[7]
        # ===== frente do balcão (painéis) =====
        for y in range(y_te, H):
            v = y - y_te
            t = wood_front.at(x, v)
            base = 0.6 + 2.0 * t - 0.012 * v
            px[x, y] = tone(base * light(x, y), x, y)
        px[x, y_te] = INK
        if y_te + 1 < H:
            px[x, y_te + 1] = RAMP[2]
    img.save(out)
    print("[compose]", out)
    return out


def main(args):
    wall = args[0] if args else "none"
    out = args[1] if len(args) > 1 else os.path.join(RAW, "scene_" + os.path.basename(wall))
    compose(wall, out, warm="--warm" in args)
