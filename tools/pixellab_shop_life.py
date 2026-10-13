#!/usr/bin/env python3
"""
tools/pixellab_shop_life.py — arte dos PROPS VIVOS da Loja v3 (F3, Out/2026):
lanterna, copo de dados, mariposa, teia e etiqueta de liquidação. Consumidos
por src/ui/shop/ShopProps.lua; prancha de prova em tools/preview_shop_props.lua.
(A arte da CENA — estantes, balcão, sino, livro — é de tools/pixellab_shop_props.py,
frente loja-cena; este script só cuida da vida.)

Contrato dos arquivos em assets/sprites/shop/ (sprite sheets HORIZONTAIS,
quadro N no x = N*largura):
  lantern.png        32x48 x 3 quadros (chama)                       -> 96x48
  dice_cup.png       32x32 x 5 quadros: repouso, chacoalho a/b/c, deitado -> 160x32
  die_faces.png      16x16 x 6 faces                                 -> 96x16
  moth.png           16x16 x 4 quadros (asas: aberta, meia, fechada, meia) -> 64x16
  cobweb.png         32x32 estatica
  price_tag_sale.png 24x16 etiqueta vermelha torta (oferta do dia)

O que vem da IA e o que e desenhado aqui, e POR QUE:
  * lanterna / copo / teia: PixelLab `create_image_pro` com imagem de estilo
    (a espada-ancora `_style_reference.png`; o copo usa o copo do mini-jogo,
    vizinho de balcao). `gen` baixa candidatos, OLHAR a prancha, `pick`.
  * quadros da chama e do chacoalho: derivados DO QUADRO ESCOLHIDO por edicao
    de pixel (chama: os dois tons exatos da chama redesenhados em 3 poses;
    chacoalho: cisalhamento de 1 px da metade de cima + deitado = rotacao de
    90 graus, que em pixel art e sem perda). Gerar 5 quadros na IA daria 5
    copos diferentes — o objeto tem que ser o MESMO em todo quadro.
  * faces do dado, mariposa e etiqueta: pixel a pixel. Contagem de pips e o
    ciclo de asa sao informacao, e gerador erra contagem (mesma regra de
    tools/pixellab_scribe_dice.py).

Uso:
  python tools/pixellab_shop_life.py gen lantern|dice_cup|cobweb [seed]
  python tools/pixellab_shop_life.py pick lantern|dice_cup|cobweb <N>
  python tools/pixellab_shop_life.py frames        # lantern/dice_cup -> sheets
  python tools/pixellab_shop_life.py handmade      # die_faces, moth, price_tag_sale
  python tools/pixellab_shop_life.py contact       # prancha de tudo (preview_out)
Candidatos em tools/preview_out/shop_props/<nome>/ (quadro escolhido = base.png).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEST = os.path.join(ROOT, "assets/sprites/shop")
OUT = os.path.join(ROOT, "tools/preview_out/shop_props")
STYLE_SWORD = os.path.join(ROOT, "assets/sprites/_style_reference.png")
STYLE_CUP = os.path.join(ROOT, "assets/sprites/minigame/dice_cup.png")

STYLE = ("single prop, one object centered on a transparent canvas, crisp "
         "dark 1px outline, warm medieval grimoire palette (aged leather "
         "browns, tarnished brass, iron, parchment), dark shading and one "
         "bright highlight, hand-placed pixel art with hard edges, NO text, "
         "NO background, NO frame, NO smooth vector gradients, NO blur")

# nome -> (largura, altura, imagem de estilo, descricao)
SPECS = {
    "lantern": (32, 48, STYLE_SWORD,
                "a small hanging iron lantern seen from the front, square "
                "cage of dark iron bars with a pointed roof and a ring on "
                "top, a single lit candle inside with a bright yellow-orange "
                "flame, warm glow on the glass panes, hanging straight down"),
    "dice_cup": (32, 32, STYLE_CUP,
                 "a worn brown leather dice cup standing upright, mouth "
                 "open at the top, tarnished brass rim and two brass rivets, "
                 "no dice, seen slightly from above"),
    "cobweb": (32, 32, STYLE_SWORD,
               "a thin dusty spider web filling the top-left corner of the "
               "canvas, pale grey-beige threads radiating from the corner "
               "with a few sagging cross threads, no spider"),
}


def _pl():
    import pixellab_new_enemies as N  # call/b64/wait_job/download_all
    return N


def cmd_gen(name, seed=None):
    N = _pl()
    w, h, style, desc = SPECS[name]
    args = {"description": f"{desc}. {STYLE}", "width": w, "height": h,
            "no_background": True, "style_image_base64": N.b64(style),
            "style_copy": ["color_palette", "outline", "detail", "shading"]}
    if seed is not None:
        args["seed"] = int(seed)
    text = N.call("create_image_pro", args)
    jid = N.job_id_of(text)
    print(f"[gen] {name} job {jid}", flush=True)
    done = N.wait_job(jid, 1500) if jid else None
    if not done:
        print(text[:300])
        return
    d = os.path.join(OUT, name)
    os.makedirs(d, exist_ok=True)
    n = N.download_all(done, os.path.join(d, "cand_{}.png"))
    print(f"[gen] {name}: {n} candidatos em {d}", flush=True)
    contact_candidates(name, n)


def contact_candidates(name, n):
    from PIL import Image
    d = os.path.join(OUT, name)
    ims = [Image.open(os.path.join(d, f"cand_{i}.png")).convert("RGBA")
           for i in range(n)]
    w, h = SPECS[name][0], SPECS[name][1]
    k = 4
    sh = Image.new("RGBA", (n * (w * k + 8), h * k), (40, 36, 32, 255))
    for i, im in enumerate(ims):
        big = im.resize((im.width * k, im.height * k), Image.NEAREST)
        sh.paste(big, (i * (w * k + 8), 0), big)
    p = os.path.join(d, "contact.png")
    sh.save(p)
    print(p)


def _binarize(im):
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255) if a >= 128 else (0, 0, 0, 0)
    return im


def cmd_pick(name, n):
    from PIL import Image
    w, h = SPECS[name][0], SPECS[name][1]
    im = Image.open(os.path.join(OUT, name, f"cand_{n}.png")).convert("RGBA")
    if im.size != (w, h):
        im = im.resize((w, h), Image.NEAREST)
    _binarize(im)
    os.makedirs(DEST, exist_ok=True)
    base = os.path.join(OUT, name, "base.png")
    im.save(base)
    if name == "cobweb":
        # A IA desenha os fios em TINTA escura (contorno), e fio preto some
        # na parede escura da loja: fio escuro vira fio palido empoeirado,
        # realce claro vira meio-tom, alfa por peso do fio.
        q = im.load()
        for y in range(im.height):
            for x in range(im.width):
                r, g, b, a = q[x, y]
                if a == 0:
                    continue
                k = 1 - (r * 0.3 + g * 0.59 + b * 0.11) / 255
                q[x, y] = (int(120 + 105 * k), int(112 + 98 * k), int(96 + 88 * k),
                           int(150 + 90 * k))
        im.save(os.path.join(DEST, "cobweb.png"))
    print(f"[pick] {name} <- cand_{n} ({base})")


# ---------------------------------------------------------------------------
# QUADROS derivados do quadro escolhido
# ---------------------------------------------------------------------------
# Cores da chama do quadro escolhido (cand_0 da lanterna) e a caixa onde ela
# vive. Mascara GENERICA por tom quente pegava os vidros ambar inteiros —
# a chama e dois tons exatos dentro de uma caixa.
FLAME_CORE = (250, 123, 3, 255)
FLAME_BRIGHT = (254, 197, 69, 255)
FLAME_MID = (234, 149, 57, 255)
FLAME_BOX = (11, 26, 19, 37)   # x0, y0, x1, y1 inclusivos


def lantern_frames(base):
    """3 poses da chama, lanterna identica fora dela (so a luz mexe):
    1 = base; 2 = chama encolhe 1 px no topo e o nucleo pende 1 px a
    esquerda; 3 = chama cresce 1 px no topo e o nucleo pende a direita."""
    W, H = base.size
    px = base.load()
    x0, y0, x1, y1 = FLAME_BOX
    core = [(x, y) for y in range(y0, y1 + 1) for x in range(x0, x1 + 1)
            if px[x, y] == FLAME_CORE]
    bright = [(x, y) for y in range(y0, y1 + 1) for x in range(x0, x1 + 1)
              if px[x, y] == FLAME_BRIGHT]
    if len(core) < 2 or len(bright) < 4:
        raise SystemExit(f"[frames] chama nao bate com as cores esperadas "
                         f"(core {len(core)}, bright {len(bright)}) — reveja FLAME_*")
    top = min(y for _, y in bright)
    print(f"[frames] chama: nucleo {len(core)} px, brilho {len(bright)} px, topo y={top}")

    def variant(grow, dx):
        im = base.copy()
        q = im.load()
        if grow:
            for (x, y) in bright:
                if y == top and q[x, y - 1][3] and q[x, y - 1] != FLAME_CORE:
                    q[x, y - 1] = FLAME_BRIGHT
        else:
            for (x, y) in bright:
                if y == top:
                    q[x, y] = FLAME_MID
        for (x, y) in core:
            q[x, y] = FLAME_BRIGHT
        for (x, y) in core:
            nx, ny = x + dx, y - (1 if grow else 0)
            if x0 <= nx <= x1 and y0 <= ny <= y1:
                q[nx, ny] = FLAME_CORE
        return im

    return [base.copy(), variant(False, -1), variant(True, 1)]


def _shear(im, top_dx):
    """Cisalha a METADE DE CIMA do sprite em top_dx px (le como inclinar)."""
    from PIL import Image
    W, H = im.size
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    src = im.load()
    dst = out.load()
    cut = H // 2
    for y in range(H):
        dx = top_dx if y < cut else 0
        for x in range(W):
            nx = x + dx
            if 0 <= nx < W:
                dst[nx, y] = src[x, y]
    return out


def dice_cup_frames(base):
    """repouso, chacoalho a (inclina esq.), b (inclina dir.), c (sobe 1 px),
    deitado (rotacao 90 graus, boca pra direita, apoiado no chao)."""
    from PIL import Image
    W, H = base.size
    rest = base.copy()
    a = _shear(base, -1)
    b = _shear(base, 1)
    c = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    c.paste(base, (0, -1))
    lying = base.rotate(-90, expand=False)  # boca pra direita
    bbox = lying.getbbox()
    if bbox:
        shift = (H - 2) - bbox[3]
        tmp = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        tmp.paste(lying, (0, shift))
        lying = tmp
    return [rest, a, b, c, lying]


def _sheet(frames, path):
    from PIL import Image
    w, h = frames[0].size
    sh = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sh.paste(f, (i * w, 0))
    sh.save(path)
    print("[frames]", path, sh.size)


def cmd_frames():
    from PIL import Image
    os.makedirs(DEST, exist_ok=True)
    for name, fn in (("lantern", lantern_frames), ("dice_cup", dice_cup_frames)):
        base = os.path.join(OUT, name, "base.png")
        if not os.path.exists(base):
            print(f"[frames] {name}: sem base.png (rode gen + pick)")
            continue
        frames = fn(Image.open(base).convert("RGBA"))
        _sheet(frames, os.path.join(DEST, name + ".png"))


# ---------------------------------------------------------------------------
# PIXEL A PIXEL: faces do dado (16x16), mariposa (16x16 x4), etiqueta (24x16)
# ---------------------------------------------------------------------------
INK = (28, 20, 16, 255)
BONE_HI = (246, 232, 200, 255)
BONE = (226, 204, 160, 255)
BONE_SH = (184, 156, 112, 255)
BONE_DK = (138, 108, 74, 255)
PIP = (140, 26, 22, 255)
PIP_HI = (196, 58, 44, 255)

PIPS = {
    1: [(1, 1)],
    2: [(0, 0), (2, 2)],
    3: [(0, 0), (1, 1), (2, 2)],
    4: [(0, 0), (2, 0), (0, 2), (2, 2)],
    5: [(0, 0), (2, 0), (1, 1), (0, 2), (2, 2)],
    6: [(0, 0), (2, 0), (0, 1), (2, 1), (0, 2), (2, 2)],
}


def die_faces():
    """Dado 16x16: contorno tinta, canto chanfrado 1 px, luz alto-esq.,
    sombra baixo-dir., pips 3x3 SOLIDOS na grade 3x3 (com os cantos
    cortados o pip virava uma cruz em 16 px)."""
    from PIL import Image
    S = 16
    frames = []
    for n in range(1, 7):
        im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        px = im.load()
        for y in range(S):
            for x in range(S):
                cx = min(x, S - 1 - x)
                cy = min(y, S - 1 - y)
                if cx + cy < 1:
                    continue
                edge = cx == 0 or cy == 0 or cx + cy == 1
                if edge:
                    px[x, y] = INK
                elif x + y <= 3:
                    px[x, y] = BONE_HI
                elif x >= S - 3 or y >= S - 3:
                    px[x, y] = BONE_DK if (x >= S - 2 or y >= S - 2) else BONE_SH
                else:
                    px[x, y] = BONE
        for (c, l) in PIPS[n]:
            ox = 3 + c * 4
            oy = 3 + l * 4
            for dy in range(3):
                for dx in range(3):
                    px[ox + dx, oy + dy] = PIP
            px[ox, oy] = PIP_HI
        frames.append(im)
    return frames


MOTH_BODY = (74, 58, 40, 255)
MOTH_WING = (196, 172, 128, 255)
MOTH_WING_DK = (150, 126, 88, 255)
MOTH_SPOT = (96, 70, 48, 255)


def moth_frames():
    """Mariposa vista de cima, 16x16, corpo vertical de 2 px no centro,
    asas em 4 aberturas (6, 4, 2, 4 px de envergadura por lado)."""
    from PIL import Image
    S = 16
    cx = 7  # corpo ocupa colunas 7-8
    spans = [6, 4, 2, 4]
    frames = []
    for span in spans:
        im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        px = im.load()
        for row in range(4, 12):
            k = row - 4
            frac = [0.55, 0.85, 1.0, 1.0, 0.9, 0.7, 0.45, 0.25][k]
            w = max(1, int(round(span * frac)))
            for i in range(w):
                col_l = cx - 1 - i
                col_r = cx + 2 + i
                shade = MOTH_WING_DK if i == w - 1 or row in (4, 11) else MOTH_WING
                if 0 <= col_l < S:
                    px[col_l, row] = shade
                if 0 <= col_r < S:
                    px[col_r, row] = shade
            if span >= 4 and k == 2 and w >= 3:
                px[cx - 1 - 1, row] = MOTH_SPOT
                px[cx + 2 + 1, row] = MOTH_SPOT
        outline = []
        for y in range(S):
            for x in range(S):
                if px[x, y][3] == 0:
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < S and 0 <= ny < S and px[nx, ny][3] and px[nx, ny] != INK:
                            outline.append((x, y))
                            break
        for (x, y) in outline:
            px[x, y] = INK
        for row in range(3, 13):
            px[cx, row] = MOTH_BODY
            px[cx + 1, row] = MOTH_BODY
        px[cx - 1, 2] = INK
        px[cx + 2, 2] = INK
        px[cx, 3] = INK
        px[cx + 1, 3] = INK
        frames.append(im)
    return frames


TAG_RED = (158, 34, 30, 255)
TAG_RED_HI = (204, 66, 52, 255)
TAG_RED_DK = (112, 22, 20, 255)
TAG_STRING = (214, 196, 150, 255)


def price_tag_sale():
    """Etiqueta 24x16 vermelha, pendurada TORTA (inclinacao ~1:3), ponta
    chanfrada a esquerda com o furo do barbante. Texto do preco vai por
    cima (a tela desenha), por isso o miolo e liso."""
    from PIL import Image
    W, H = 24, 16
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = im.load()
    for y in range(2, 15):
        off = (y - 2) // 3          # 0..4: inclinacao ~1:3, le como torta
        x0 = 2 + off
        x1 = 19 + off
        if y in (2, 14):
            x0 += 2
        elif y in (3, 13):
            x0 += 1
        for x in range(x0, min(W, x1 + 1)):
            edge = (x == x0 or x == x1 or y == 2 or y == 14)
            if edge:
                px[x, y] = INK
            elif y == 3 or x == x0 + 1:
                px[x, y] = TAG_RED_HI
            elif y == 13 or x == x1 - 1:
                px[x, y] = TAG_RED_DK
            else:
                px[x, y] = TAG_RED
    # furo do barbante (anel de tinta com o miolo vazado)
    for (x, y) in ((5, 6), (6, 6), (7, 6), (5, 7), (7, 7), (5, 8), (6, 8), (7, 8)):
        px[x, y] = INK
    px[6, 7] = (0, 0, 0, 0)
    # barbante subindo da ponta ate o topo (sai do furo)
    for (x, y) in ((6, 5), (5, 4), (5, 3), (4, 2), (4, 1), (4, 0)):
        px[x, y] = TAG_STRING
    return im


def cmd_handmade():
    os.makedirs(DEST, exist_ok=True)
    _sheet(die_faces(), os.path.join(DEST, "die_faces.png"))
    _sheet(moth_frames(), os.path.join(DEST, "moth.png"))
    price_tag_sale().save(os.path.join(DEST, "price_tag_sale.png"))
    print("[handmade] price_tag_sale.png 24x16")


def cmd_contact():
    """Prancha x4 de todos os sheets instalados (prova visual)."""
    from PIL import Image
    os.makedirs(OUT, exist_ok=True)
    names = ["lantern.png", "dice_cup.png", "die_faces.png", "moth.png",
             "cobweb.png", "price_tag_sale.png"]
    ims = []
    for n in names:
        p = os.path.join(DEST, n)
        if os.path.exists(p):
            ims.append((n, Image.open(p).convert("RGBA")))
    k = 4
    W = max(im.width for _, im in ims) * k + 16
    H = sum(im.height * k + 12 for _, im in ims)
    sh = Image.new("RGBA", (W, H), (40, 36, 32, 255))
    y = 0
    for n, im in ims:
        big = im.resize((im.width * k, im.height * k), Image.NEAREST)
        sh.paste(big, (8, y), big)
        y += big.height + 12
    p = os.path.join(OUT, "contact_all.png")
    sh.save(p)
    print(p)


if __name__ == "__main__":
    c, a = (sys.argv[1] if len(sys.argv) > 1 else ""), sys.argv[2:]
    if c == "gen":
        cmd_gen(a[0], a[1] if len(a) > 1 else None)
    elif c == "pick":
        cmd_pick(a[0], int(a[1]))
    elif c == "frames":
        cmd_frames()
    elif c == "handmade":
        cmd_handmade()
    elif c == "contact":
        cmd_contact()
    else:
        print(__doc__)
