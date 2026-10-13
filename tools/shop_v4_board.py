"""
tools/shop_v4_board.py: pranchas de prova da Loja v4.

  python tools/shop_v4_board.py study <saida.png>
      (a) a pintura atual (v3c) x (b) 3 cenários candidatos x (c) composição
      com cartas e objetos por cima (capturas do jogo em 1920x1080)
  python tools/shop_v4_board.py grid <saida.png> <colunas> <largura> <titulo> <png:rotulo>...
      prancha genérica (imagens redimensionadas pra mesma largura)
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "tools/preview_out/shop_v4/raw")
FONT = os.path.join(ROOT, "assets/fonts/pixel.ttf")
BG = (24, 16, 14)
INK = (236, 214, 170)
GOLD = (222, 170, 80)


def font(size):
    try:
        return ImageFont.truetype(FONT, size)
    except Exception:  # noqa
        return ImageFont.load_default()


def fit(im, w):
    h = round(im.height * w / im.width)
    resample = Image.NEAREST if w >= im.width else Image.LANCZOS
    return im.convert("RGB").resize((w, h), resample)


def grid(out, cols, width, title, items, sub=None):
    tiles = [(fit(Image.open(p), width), label) for p, label in items]
    th = max(t.height for t, _ in tiles)
    rows = (len(tiles) + cols - 1) // cols
    pad, head, lab = 16, 56 if sub is None else 80, 44
    W = cols * width + (cols + 1) * pad
    H = head + rows * (th + lab + pad) + pad
    board = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(board)
    d.text((pad, 14), title, fill=GOLD, font=font(22))
    if sub:
        d.text((pad, 46), sub, fill=INK, font=font(13))
    for i, (t, label) in enumerate(tiles):
        x = pad + (i % cols) * (width + pad)
        y = head + (i // cols) * (th + lab + pad)
        for j, line in enumerate(label.split("\n")[:2]):
            d.text((x, y + 2 + j * 18), line, fill=INK, font=font(14))
        board.paste(t, (x, y + lab))
    board.save(out)
    print("[board]", out, board.size)


def study(out):
    old = os.path.join(ROOT, "tools/preview_out/shop_v4/before_rest_1920x1080_pt_BR.png")
    items = [(old, "(a) atual v3c: pintura 688x384 + ponto de fuga\nborda a 6,83 graus, mesa cheia de objetos")]
    names = {"a": "A: estante com potes",
             "b": "B: pedra do salao 1 + faixa",
             "c": "C: madeira, ervas, frascos"}
    for k in "abc":
        items.append((os.path.join(RAW, f"scene_{k}.png"), f"(b) cenario {names[k]}\n640x360, degrau + mesa em 1:8"))
    for k in "abc":
        items.append((os.path.join(RAW, f"cand_{k}.png"), f"(c) composicao {k.upper()} com a vitrine\n1920x1080 pt_BR"))
    grid(out, 4, 640, "Loja v4: estudo do cenario (escolhido: B)", items,
         sub="notas em docs/plan/shop-v4-estudo.md: leitura em 1 s, coerencia de pixel, zero decoracao confundivel, espaco limpo")


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "study":
        study(sys.argv[2])
    elif cmd == "grid":
        out, cols, width, title = sys.argv[2], int(sys.argv[3]), int(sys.argv[4]), sys.argv[5]
        items = []
        for a in sys.argv[6:]:
            p, _, label = a.partition("::")
            items.append((p, label))
        grid(out, cols, width, title, items)
