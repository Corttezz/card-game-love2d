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


# Loja v5: MARGEM em volta do miolo 640x360 (as coordenadas da arte, as
# retas G e o ShopLayout continuam no miolo). Com ela o cover-fit fica em
# múltiplo INTEIRO também em 1366x768, 1024x768 e 1280x800 (antes caíam no
# fracionário 2,13-2,22: pixel de 2 e 3 px misturados). Espelhado em
# ShopLayout.ART.pad.
PX, PY = 24, 24


class Off:
    """Acesso ao pixel em coordenadas do MIOLO (x, y podem ser negativos)."""

    def __init__(self, px):
        self.px = px

    def __getitem__(self, k):
        return self.px[k[0] + PX, k[1] + PY]

    def __setitem__(self, k, v):
        self.px[k[0] + PX, k[1] + PY] = v


def extend_wall(wall):
    """Parede 640x360 -> (640+2PX)x(360+2PY) espelhando as bordas (o pilar de
    madeira dos cantos fica mais largo; o alto fica sob a TopBar)."""
    out = Image.new("RGB", (W + 2 * PX, H + 2 * PY))
    out.paste(wall, (PX, PY))
    src = wall.load()
    o = out.load()
    for y in range(H + 2 * PY):
        sy = min(H - 1, max(0, y - PY))
        if y - PY < 0:
            sy = min(H - 1, PY - y - 1)
        for x in range(W + 2 * PX):
            sx = x - PX
            if sx < 0:
                sx = -sx - 1
            elif sx >= W:
                sx = 2 * W - sx - 1
            if x - PX < 0 or x - PX >= W or y - PY < 0:
                o[x, y] = src[sx, sy]
    return out


def calm_wall(c, x, y):
    """Loja v5 (briefing item 7): o fundo dá contexto, não disputa com a
    vitrine. Contraste puxado pra um tom escuro médio, saturação menor e uma
    POÇA DE LUZ em degraus sobre a área de exposição (centro ~ x 250, y 150 do
    miolo); fora dela, a parede (frascos, cortina) desce de degrau em degrau.
    Degraus com dither Bayer, nada de blur."""
    r, g, b = c
    l = 0.299 * r + 0.587 * g + 0.114 * b
    # menos saturação e menos contraste
    r, g, b = (r * 0.72 + l * 0.28, g * 0.72 + l * 0.28, b * 0.72 + l * 0.28)
    mid = (34, 22, 20)
    r, g, b = (r * 0.78 + mid[0] * 0.22, g * 0.78 + mid[1] * 0.22, b * 0.78 + mid[2] * 0.22)
    dx, dy = (x - 250) / 330.0, (y - 150) / 190.0
    d = (dx * dx + dy * dy) ** 0.5
    steps = [(0.55, 0.86), (0.80, 0.74), (1.05, 0.64), (9.0, 0.56)]
    k = steps[-1][1]
    for i, (lim, kk) in enumerate(steps):
        if d < lim:
            k = kk
            # degrau com dither na faixa de transição
            if i > 0 and d < steps[i - 1][0] + 0.06 and BAYER[y % 4][x % 4] < 8:
                k = steps[i - 1][1]
            break
    # frascos e prateleira do alto: um degrau a mais de sombra
    if y < 100:
        k *= 0.86
    return (int(r * k), int(g * k), int(b * k))


def compose(wall_path, out, warm=False):
    wood_top = Tex(os.path.join(RAW, "wood_top.png"))
    wood_front = Tex(os.path.join(RAW, "wood_front.png"), rows=(14, 80))
    if wall_path and wall_path != "none":
        wall = Image.open(wall_path).convert("RGB").resize((W, H), Image.NEAREST)
    else:
        wall = Image.new("RGB", (W, H), (30, 18, 16))
    wall = extend_wall(wall)
    wp = wall.load()
    for yy in range(H + 2 * PY):
        for xx in range(W + 2 * PX):
            wp[xx, yy] = calm_wall(wp[xx, yy], xx - PX, yy - PY)
    img = wall.copy()
    px = Off(img.load())
    wpx = Off(wall.load())

    for x in range(-PX, W + PX):
        y_st, y_se = yl(G["shelf_top"], x), yl(G["shelf_edge"], x)
        y_sf, y_tb = yl(G["shelf_face"], x), yl(G["table_back"], x)
        y_te = yl(G["table_edge"], x)
        # parede: escurece em degraus ao descer pro degrau (sombra do móvel)
        for y in range(-PY, y_st):
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
        for y in range(y_te, H + PY):
            v = y - y_te
            # textura em espelho vertical (a margem de baixo passa da altura dela)
            vv = v % (2 * wood_front.h)
            t = wood_front.at(x, vv if vv < wood_front.h else 2 * wood_front.h - vv - 1)
            base = 0.6 + 2.0 * t - 0.012 * v
            px[x, y] = tone(base * light(x, y), x, y)
        px[x, y_te] = INK
        if y_te + 1 < H + PY:
            px[x, y_te + 1] = RAMP[2]
    img.save(out)
    print("[compose]", out)
    return out


def main(args):
    wall = args[0] if args else "none"
    out = args[1] if len(args) > 1 else os.path.join(RAW, "scene_" + os.path.basename(wall))
    compose(wall, out, warm="--warm" in args)
