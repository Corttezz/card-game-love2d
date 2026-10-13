"""
tools/intro_computer_import.py: instala a ARTE DO COMPUTADOR da abertura
(gerada no Higgsfield/PixelLab com a nossa paleta) e acha a TELA sozinho.

Contrato da arte (ver docs/plan/intro-computer-prompt.md):
  * PNG com o computador visto de frente, centralizado, fundo TRANSPARENTE
    ou liso (o script recorta pela caixa opaca / pela cor do canto);
  * a TELA do computador pintada de MAGENTA PURO (#ff00ff): o script acha o
    retângulo, grava as coordenadas e deixa a tela transparente (o jogo
    desenha o tubo ali dentro).

  python tools/intro_computer_import.py <render.png> [--out assets/sprites/intro/computer.png]
      [--data src/data/intro_computer.lua]
      [--width 512]       # reduz pra essa largura (nearest) antes de instalar
      [--palette]         # quantiza nas cores do Palette (sépia do jogo)

Escreve assets/sprites/intro/computer.png e src/data/intro_computer.lua
({ image, w, h, screen = {x, y, w, h} }). A abertura (IntroTube) usa isso
quando existe; sem o arquivo, cai no televisor do shader.
"""
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_IMG = os.path.join(ROOT, "assets/sprites/intro/computer.png")
OUT_LUA = os.path.join(ROOT, "src/data/intro_computer.lua")

# paleta sépia do jogo (src/ui/Palette.lua, seção Grimoire) + gabinete
PALETTE = [
    (0x1a, 0x0f, 0x08), (0x6a, 0x4f, 0x24), (0xb8, 0xa0, 0x68), (0xe8, 0xd5, 0xa0),
    (0x8b, 0x1e, 0x1e), (0x4a, 0x52, 0x60), (0xb0, 0x8a, 0x3e), (0x4a, 0x60, 0x30),
    (0x8b, 0x4a, 0x1e), (0x1d, 0x1a, 0x18), (0x2e, 0x2a, 0x26), (0x3c, 0x36, 0x30),
    (0x55, 0x4d, 0x44), (0x7a, 0x6e, 0x60), (0xa3, 0x93, 0x7f), (0xcf, 0xbe, 0x9c),
]


def is_magenta(px):
    r, g, b = px[:3]
    return r > 200 and b > 200 and g < 80


def find_screen(im):
    px = im.load()
    w, h = im.size
    x0, y0, x1, y1 = w, h, -1, -1
    n = 0
    for y in range(h):
        for x in range(w):
            p = px[x, y]
            if (len(p) < 4 or p[3] > 64) and is_magenta(p):
                n += 1
                if x < x0: x0 = x
                if x > x1: x1 = x
                if y < y0: y0 = y
                if y > y1: y1 = y
    if x1 < 0:
        return None
    return (x0, y0, x1 - x0 + 1, y1 - y0 + 1), n


def crop_to_content(im):
    """recorta pela caixa opaca; fundo liso vira transparente pela cor do canto"""
    im = im.convert("RGBA")
    px = im.load()
    corner = px[0, 0]
    if corner[3] > 0:
        # fundo liso: qualquer pixel igual ao canto (tolerância) vira transparente
        w, h = im.size
        for y in range(h):
            for x in range(w):
                p = px[x, y]
                if abs(p[0] - corner[0]) + abs(p[1] - corner[1]) + abs(p[2] - corner[2]) < 24:
                    px[x, y] = (0, 0, 0, 0)
    bb = im.getbbox()
    return im.crop(bb) if bb else im


def quantize(im):
    pal = Image.new("P", (1, 1))
    flat = []
    for c in PALETTE:
        flat += list(c)
    flat += [0, 0, 0] * (256 - len(PALETTE))
    pal.putpalette(flat)
    rgb = im.convert("RGB").quantize(palette=pal, dither=Image.Dither.NONE).convert("RGBA")
    a = im.getchannel("A")
    rgb.putalpha(a)
    return rgb


def main(argv):
    if not argv or argv[0].startswith("-"):
        print(__doc__)
        return 1
    src = argv[0]
    out_img = OUT_IMG
    out_lua = OUT_LUA
    width = None
    if "--data" in argv:
        out_lua = argv[argv.index("--data") + 1]
    do_pal = "--palette" in argv
    if "--out" in argv:
        out_img = argv[argv.index("--out") + 1]
    if "--width" in argv:
        width = int(argv[argv.index("--width") + 1])
    im = crop_to_content(Image.open(src))
    if width and im.width > width:
        h = round(im.height * width / im.width)
        im = im.resize((width, h), Image.NEAREST)
    found = find_screen(im)
    if not found:
        print("[intro] NENHUM magenta #ff00ff na arte: pinte a tela do computador de magenta puro")
        return 2
    (sx, sy, sw, sh), n = found
    fill = n / float(sw * sh)
    if fill < 0.85:
        print(f"[intro] AVISO: a area magenta nao e um retangulo cheio ({fill:.0%}): a tela ficara pelo bbox")
    px = im.load()
    for y in range(sy, sy + sh):
        for x in range(sx, sx + sw):
            if is_magenta(px[x, y]):
                px[x, y] = (0, 0, 0, 0)
    if do_pal:
        im = quantize(im)
    os.makedirs(os.path.dirname(out_img), exist_ok=True)
    im.save(out_img)
    rel = os.path.relpath(out_img, ROOT).replace("\\", "/")
    with open(out_lua, "w", encoding="utf-8", newline="\n") as f:
        f.write("-- gerado por tools/intro_computer_import.py: a arte do computador da\n")
        f.write("-- abertura e o retangulo da TELA dentro dela (px da imagem).\n")
        f.write("return {\n")
        f.write(f'    image = "{rel}",\n')
        f.write(f"    w = {im.width}, h = {im.height},\n")
        f.write(f"    screen = {{ x = {sx}, y = {sy}, w = {sw}, h = {sh} }},\n")
        f.write("}\n")
    print(f"[intro] {rel} {im.width}x{im.height}; tela {sw}x{sh} em ({sx},{sy}); dados em {os.path.relpath(out_lua, ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
