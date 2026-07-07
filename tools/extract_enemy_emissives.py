#!/usr/bin/env python3
"""
tools/extract_enemy_emissives.py — pipeline PADRÃO de emissivos de monstro.

Varre o frame 0 do idle de cada inimigo, acha clusters de pixels EMISSIVOS
(olhos, chamas, cristais, runas: alta saturação + alto brilho, área pequena)
e imprime candidatos para revisão. Gera também uma folha de contato anotada
(scratch/enemy_emissives_sheet.png) com círculos nos candidatos — REVISAR
VISUALMENTE antes de aceitar (dourado de coroa/palha engana o detector).

Uso:  python3 tools/extract_enemy_emissives.py [<enemy_id> ...]
Saída: candidatos por inimigo (xr, yr, r, cor) no formato do
       src/data/enemy_emissives.lua — copiar/ajustar à mão após revisão.

Novo monstro no jogo? Rode isto, revise a folha, adicione a entrada no
enemy_emissives.lua. Ver memory/lighting_engine.md.
"""
import colorsys
import os
import sys

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ENEMIES_DIR = os.path.join(ROOT, "assets/sprites/characters/enemies")

MIN_CLUSTER = 2      # px
MAX_CLUSTER = 60     # px — emissivo é PONTO, não área (palha/manto ficam fora)
MAX_ANCHORS = 5


def is_emissive(r, g, b, a):
    if a < 200:
        return False
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    # núcleo quente/mágico: muito claro E saturado
    if v > 0.82 and s > 0.50:
        return True
    # olho espectral frio (ciano/azul pálido brilhante)
    if v > 0.85 and b > r + 40 and s > 0.25:
        return True
    return False


def clusters(img):
    W, H = img.size
    px = img.load()
    mask = [[is_emissive(*px[x, y]) for x in range(W)] for y in range(H)]
    seen = [[False] * W for _ in range(H)]
    out = []
    for y in range(H):
        for x in range(W):
            if mask[y][x] and not seen[y][x]:
                stack = [(x, y)]
                seen[y][x] = True
                pts = []
                while stack:
                    cx, cy = stack.pop()
                    pts.append((cx, cy))
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1),
                                   (1, 1), (-1, 1), (1, -1), (-1, -1)):
                        nx, ny = cx + dx, cy + dy
                        if 0 <= nx < W and 0 <= ny < H \
                           and mask[ny][nx] and not seen[ny][nx]:
                            seen[ny][nx] = True
                            stack.append((nx, ny))
                if MIN_CLUSTER <= len(pts) <= MAX_CLUSTER:
                    mx = sum(p[0] for p in pts) / len(pts)
                    my = sum(p[1] for p in pts) / len(pts)
                    ext = max(max(p[0] for p in pts) - min(p[0] for p in pts),
                              max(p[1] for p in pts) - min(p[1] for p in pts)) + 1
                    rs = sum(px[p[0], p[1]][0] for p in pts) / len(pts)
                    gs = sum(px[p[0], p[1]][1] for p in pts) / len(pts)
                    bs = sum(px[p[0], p[1]][2] for p in pts) / len(pts)
                    out.append((len(pts), mx, my, ext, (rs, gs, bs)))
    out.sort(reverse=True)
    return out[:MAX_ANCHORS]


def main():
    ids = sys.argv[1:] or sorted(os.listdir(ENEMIES_DIR))
    sheet_cells = []
    for eid in ids:
        f0 = os.path.join(ENEMIES_DIR, eid, "animations/idle/south/0.png")
        if not os.path.isfile(f0):
            continue
        img = Image.open(f0).convert("RGBA")
        W, H = img.size
        cl = clusters(img)
        print(f"    -- {eid} ({W}x{H})")
        print(f"    {eid} = {{")
        for sz, mx, my, ext, (r, g, b) in cl:
            rr = max(0.04, (ext * 1.6) / H)   # raio em fração da ALTURA
            print(f"        {{ xr = {mx / W:.3f}, yr = {my / H:.3f}, "
                  f"r = {rr:.3f}, color = {{ {r / 255:.2f}, {g / 255:.2f}, "
                  f"{b / 255:.2f} }} }},  -- {sz}px")
        print("    },")

        cell = img.resize((W * 3, H * 3), Image.NEAREST).convert("RGB")
        d = ImageDraw.Draw(cell)
        for sz, mx, my, ext, _ in cl:
            rad = max(4, ext * 3)
            d.ellipse([mx * 3 - rad, my * 3 - rad, mx * 3 + rad, my * 3 + rad],
                      outline=(255, 0, 255), width=1)
        d.text((2, 2), eid, fill=(255, 255, 0))
        sheet_cells.append(cell)

    if sheet_cells:
        cols = 5
        cw = max(c.width for c in sheet_cells)
        ch = max(c.height for c in sheet_cells)
        rows = (len(sheet_cells) + cols - 1) // cols
        sheet = Image.new("RGB", (cw * cols, ch * rows), (24, 20, 18))
        for i, c in enumerate(sheet_cells):
            sheet.paste(c, ((i % cols) * cw, (i // cols) * ch))
        out = os.path.join(ROOT, "tools/preview_out")
        os.makedirs(out, exist_ok=True)
        path = os.path.join(out, "enemy_emissives_sheet.png")
        sheet.save(path)
        print(f"\n[sheet] {path}", file=sys.stderr)


if __name__ == "__main__":
    main()
