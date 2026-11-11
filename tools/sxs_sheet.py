"""Folhas lado a lado: quadro do JOGO (captura headless do próprio jogo) x quadro do SITE, por passo da abertura.
uso: python -X utf8 tools/sxs_sheet.py <dir_jogo> <dir_site> <dir_saida> <locale> <WxH>"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

G, S, O, loc, size = sys.argv[1:6]
os.makedirs(O, exist_ok=True)
BEATS = [
    ("1. carta entra no drive", "b1_insert_a", "b1_insert_a"), ("1. carta entra no drive", "b1_insert_b", "b1_insert_b"),
    ("2. tela liga (tubo, no site)", None, "b2_tube_25"), ("2. tela liga (clarão)", "b2_flash", "b2_flash"),
    ("2. TV liga em tela cheia", "b2_power_05", "b2_power_05"), ("2. TV liga em tela cheia", "b2_power_20", "b2_power_20"), ("2. TV liga em tela cheia", "b2_power_45", "b2_power_45"),
    ("3. carregando", "b3_loading", "b3_loading"), ("3. selo suga as cartas", "b3_splash_20", "b3_splash_20"), ("3. selo suga as cartas", "b3_splash_35", "b3_splash_35"), ("3. selo suga as cartas", "b3_splash_50", "b3_splash_50"),
    ("3. logo preenchido (raios)", "b3_sting_14", "b3_sting_14"), ("3. logo preenchido (carga)", "b3_sting_22", "b3_sting_22"), ("3. logo preenchido (clarão)", "b3_sting_26", "b3_sting_26"), ("3. logo preenchido", "b3_sting_28", "b3_sting_28"),
    ("4. o nome no tubo", "b4_page_typed", "b4_page_typed"), ("4. o nome RUNEMOIRE", "b4_sting_32", "b4_sting_32"), ("4. o nome RUNEMOIRE", "b4_sting_38", "b4_sting_38"),
    ("5. zoom com a borda de TV", "b5_dive_25", "b5_dive_25"), ("5. zoom com a borda de TV", "b5_dive_50", "b5_dive_50"), ("5. zoom com a borda de TV", "b5_dive_80", "b5_dive_80"),
    ("6. tela de título com o CRT", "b6_menu", "b6_menu"),
]
w, h = map(int, size.split("x"))
k = 640 / w if w > h else 300 / w
tw, th = int(w * k), int(h * k)
font = ImageFont.load_default()
rows = []
for title, gb, sb in BEATS:
    gp = os.path.join(G, f"{loc}_{size}_{gb}.png") if gb else None
    sp = os.path.join(S, f"{loc}_{size}_{sb}.png")
    if not os.path.exists(sp):
        continue
    row = Image.new("RGB", (tw * 2 + 30, th + 24), (20, 16, 14))
    d = ImageDraw.Draw(row)
    d.text((6, 4), f"{title}   [{gb or '-'}]   JOGO | SITE", fill=(230, 210, 160), font=font)
    if gp and os.path.exists(gp):
        row.paste(Image.open(gp).convert("RGB").resize((tw, th)), (0, 22))
    else:
        d.text((10, 30 + th // 2), "(no jogo o tubo já começa ligado)", fill=(200, 180, 140), font=font)
    row.paste(Image.open(sp).convert("RGB").resize((tw, th)), (tw + 30, 22))
    row.save(os.path.join(O, f"sxs_{loc}_{size}_{sb}.png"))
    rows.append(row)
per = 6
for i in range(0, len(rows), per):
    part = rows[i:i + per]
    sheet = Image.new("RGB", (part[0].width, sum(r.height for r in part)), (0, 0, 0))
    y = 0
    for r in part:
        sheet.paste(r, (0, y)); y += r.height
    sheet.save(os.path.join(O, f"sheet_{loc}_{size}_{i // per + 1}.png"))
print(len(rows), "pares")
