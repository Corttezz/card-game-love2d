#!/usr/bin/env python3
"""
tools/pixellab_shop_props.py — assets da Loja v3 (Balcão do Mercador).

Peças GRANDES saem do PixelLab (create_image_pixflux, HTTP direto — o base64
nunca passa por tool call, memória `pixellab-base64-mcp-http`); as peças
MIÚDAS (suporte de carta 32x16, etiqueta 24x16, prego, gancho, marca de
poeira) são desenhadas pixel a pixel aqui, na mesma paleta sépia: abaixo de
32 px a geração perde o contorno de 1 px e vira borrão.

  python tools/pixellab_shop_props.py queue [nome...]   # enfileira (1 geração cada)
  python tools/pixellab_shop_props.py poll              # baixa os prontos em tools/preview_out/shop_props/
  python tools/pixellab_shop_props.py install           # fatia/deriva pra assets/sprites/shop/
  python tools/pixellab_shop_props.py pixels            # desenha as peças miúdas

Saídas em assets/sprites/shop/:
  shelf_top_{left,mid,right}.png, shelf_bottom_{left,mid,right}.png,
  bell.png (4 quadros 32x32 lado a lado),
  ledger.png (2 quadros 40x32: fechado, entreaberto), scroll_frame.png
  (9-slice), card_stand_{1,2,3}.png, price_tag.png, nail.png, hook.png,
  dust_mark.png
"""
import json
import os
import re
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixellab_enemy_anims as F  # rpc/tool_text/fetch/token compartilhados

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW_DIR = os.path.join(ROOT, "tools/preview_out/shop_props/lojacena")
OUT_DIR = os.path.join(ROOT, "assets/sprites/shop")
JOBS_FILE = os.path.join(RAW_DIR, "lojacena_jobs.json")

STYLE = ("pixel art, side view, limited sepia palette (dark leather brown "
         "#6b5334, charcoal ink #2a2119, aged gold #b08a3e, bone white "
         "#d8c9a3, rust #8b4a1e), crisp 1px dark outline, no anti-aliasing, "
         "flat medieval grimoire style, transparent background")

SPECS = {
    "shelf_top": dict(
        w=256, h=40,
        desc="long wooden shelf board seen from the front, flat top surface, "
             "thick plank with visible wood grain, two small iron brackets "
             "underneath at the ends, straight horizontal, fills the full width"),
    "shelf_bottom": dict(
        w=256, h=40,
        desc="long dark wooden shelf board seen from the front, flat top "
             "surface, plank with wood grain and three iron nails along the "
             "front edge, straight horizontal, fills the full width"),
    "bell": dict(
        w=32, h=32,
        desc="small brass service bell on a dark wooden base, round dome with "
             "a button on top, seen from the front"),
    "ledger": dict(
        w=40, h=32,
        desc="closed thick leather ledger book lying flat, brass clasp, worn "
             "spine, seen from the front at a slight angle"),
    "scroll_frame": dict(
        w=96, h=128,
        desc="hanging parchment scroll, wooden roller bar at the top and at "
             "the bottom, blank aged parchment sheet in the middle, slightly "
             "curled edges, seen from the front"),
}


def _ensure():
    os.makedirs(RAW_DIR, exist_ok=True)
    os.makedirs(OUT_DIR, exist_ok=True)


def _jobs():
    if os.path.exists(JOBS_FILE):
        return json.load(open(JOBS_FILE))
    return {}


def _save_jobs(j):
    json.dump(j, open(JOBS_FILE, "w"), indent=1)


def queue(names):
    _ensure()
    jobs = _jobs()
    for name in names or SPECS:
        spec = SPECS[name]
        args = {"description": spec["desc"] + ". " + STYLE,
                "width": spec["w"], "height": spec["h"],
                "no_background": True, "outline": "single color black outline",
                "shading": "basic shading", "text_guidance_scale": 9}
        if "seed" in spec:
            args["seed"] = spec["seed"]
        text = F.tool_text(F.rpc("tools/call", {"name": "create_image_pixflux",
                                                "arguments": args}))
        m = re.search(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", text)
        jobs[name] = m.group(0) if m else None
        print(f"[queue] {name}: {jobs[name]}  ({text[:80]!r})", flush=True)
        _save_jobs(jobs)
        time.sleep(1.5)


def _download(text, dest):
    m = re.search(r"(https?://\S+/download)\b", text)
    if m:
        open(dest, "wb").write(F.fetch(m.group(1)))
        return True
    urls = re.findall(r"https?://\S+\.png", text)
    if urls:
        open(dest, "wb").write(F.fetch(urls[0]))
        return True
    return False


def poll(wait=True):
    _ensure()
    jobs = _jobs()
    pending = {n: j for n, j in jobs.items() if j}
    t0 = time.time()
    while pending and time.time() - t0 < 900:
        for name, jid in list(pending.items()):
            dest = os.path.join(RAW_DIR, f"{name}.png")
            if os.path.exists(dest):
                del pending[name]
                continue
            try:
                text = F.tool_text(F.rpc("tools/call", {"name": "get_image",
                                                        "arguments": {"job_id": jid}}))
            except Exception as e:  # noqa
                print(f"[poll] {name}: erro {e}", flush=True)
                continue
            low = text.lower()
            if "failed" in low or "error" in low:
                print(f"[poll] {name}: FALHOU {text[:200]!r}", flush=True)
                del pending[name]
            elif "completed" in low:
                if _download(text, dest):
                    print(f"[poll] {name}: salvo {dest}", flush=True)
                else:
                    print(f"[poll] {name}: completed mas sem URL: {text[:300]!r}", flush=True)
                del pending[name]
        if pending and wait:
            time.sleep(8)
        elif not wait:
            break
    print("[poll] pendentes:", list(pending))


# ============================================================================
# instalação: fatias/derivações
# ============================================================================
def _open(name):
    from PIL import Image
    return Image.open(os.path.join(RAW_DIR, f"{name}.png")).convert("RGBA")


def _bbox_crop(im, pad=0):
    bb = im.getbbox()
    if not bb:
        return im
    x0, y0, x1, y1 = bb
    return im.crop((max(0, x0 - pad), max(0, y0 - pad),
                    min(im.width, x1 + pad), min(im.height, y1 + pad)))


def _slice3(name, out_prefix, cap):
    im = _bbox_crop(_open(name))
    w = im.width
    left = im.crop((0, 0, cap, im.height))
    mid = im.crop((cap, 0, w - cap, im.height))
    right = im.crop((w - cap, 0, w, im.height))
    left.save(os.path.join(OUT_DIR, f"{out_prefix}_left.png"))
    mid.save(os.path.join(OUT_DIR, f"{out_prefix}_mid.png"))
    right.save(os.path.join(OUT_DIR, f"{out_prefix}_right.png"))
    print(f"[install] {out_prefix}: {left.size} {mid.size} {right.size}")


def _shear_frame(im, dx_top):
    """Inclina o sino: linhas de cima deslocadas dx_top px, base fixa."""
    from PIL import Image
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    h = im.height
    for y in range(h):
        k = 1 - y / max(1, h - 1)
        dx = int(round(dx_top * k))
        row = im.crop((0, y, im.width, y + 1))
        out.paste(row, (dx, y))
    return out


def install_bell():
    from PIL import Image
    im = _open("bell")
    im = im.resize((32, 32), Image.NEAREST) if im.size != (32, 32) else im
    frames = [im, _shear_frame(im, -2), _shear_frame(im, 2)]
    # 4º quadro: aro de brilho dourado (badalo tocou) — pixels de ouro em
    # volta da silhueta, 1 px.
    glow = Image.new("RGBA", im.size, (0, 0, 0, 0))
    px = im.load()
    gp = glow.load()
    for y in range(im.height):
        for x in range(im.width):
            if px[x, y][3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < im.width and 0 <= ny < im.height and px[nx, ny][3] > 0:
                        gp[x, y] = (0xd4, 0xb0, 0x60, 255)
                        break
    g4 = Image.alpha_composite(glow, im)
    frames.append(g4)
    sheet = Image.new("RGBA", (32 * 4, 32), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.paste(f, (i * 32, 0))
    sheet.save(os.path.join(OUT_DIR, "bell.png"))
    print("[install] bell: 4 quadros")


def install_ledger():
    from PIL import Image
    im = _open("ledger")
    im = im.resize((40, 32), Image.NEAREST) if im.size != (40, 32) else im
    # entreaberto: a capa (metade de cima da silhueta) sobe 2 px e deixa ver
    # uma linha de página clara.
    bb = im.getbbox() or (0, 0, 40, 32)
    x0, y0, x1, y1 = bb
    open_ = Image.new("RGBA", im.size, (0, 0, 0, 0))
    open_.paste(im, (0, 0))
    midy = (y0 + y1) // 2
    cover = im.crop((x0, y0, x1, midy))
    # página: faixa bone sob a capa
    page = Image.new("RGBA", (x1 - x0, 2), (0xd8, 0xc9, 0xa3, 255))
    open_.paste(page, (x0, midy - 1), page)
    open_.paste(cover, (x0 + 1, y0 - 2), cover)
    sheet = Image.new("RGBA", (80, 32), (0, 0, 0, 0))
    sheet.paste(im, (0, 0))
    sheet.paste(open_, (40, 0))
    sheet.save(os.path.join(OUT_DIR, "ledger.png"))
    print("[install] ledger: fechado + entreaberto")


def install_scroll():
    im = _bbox_crop(_open("scroll_frame"))
    im.save(os.path.join(OUT_DIR, "scroll_frame.png"))
    print(f"[install] scroll_frame {im.size}")


def install():
    _ensure()
    # (o balcão saiu do PixelLab: o tampo é desenhado liso pela cena — a arte
    # gerada tinha cerca/grade na frente e o rótulo não se lia por cima)
    for name, prefix, cap in (("shelf_top", "shelf_top", 40),
                              ("shelf_bottom", "shelf_bottom", 40)):
        if os.path.exists(os.path.join(RAW_DIR, f"{name}.png")):
            _slice3(name, prefix, cap)
    if os.path.exists(os.path.join(RAW_DIR, "bell.png")):
        install_bell()
    if os.path.exists(os.path.join(RAW_DIR, "ledger.png")):
        install_ledger()
    if os.path.exists(os.path.join(RAW_DIR, "scroll_frame.png")):
        install_scroll()


# ============================================================================
# peças miúdas, pixel a pixel
# ============================================================================
INK = (0x2a, 0x21, 0x19, 255)
WOOD = (0x6b, 0x53, 0x34, 255)
WOOD_D = (0x4a, 0x38, 0x22, 255)
WOOD_L = (0x8f, 0x70, 0x48, 255)
GOLD = (0xb0, 0x8a, 0x3e, 255)
GOLD_L = (0xd4, 0xb0, 0x60, 255)
BONE = (0xd8, 0xc9, 0xa3, 255)
BONE_D = (0xb8, 0xa0, 0x68, 255)
IRON = (0x4a, 0x52, 0x60, 255)
IRON_L = (0x8a, 0x94, 0xa0, 255)
DUST = (0x6a, 0x4f, 0x24, 255)


def _img(w, h):
    from PIL import Image
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def _rect(px, x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            px[x, y] = c


def _outline(px, x0, y0, x1, y1, c):
    _rect(px, x0, y0, x1, y0, c)
    _rect(px, x0, y1, x1, y1, c)
    _rect(px, x0, y0, x0, y1, c)
    _rect(px, x1, y0, x1, y1, c)


def card_stand(variant):
    """32x16: bloco de madeira com rasgo pra carta; base na última linha."""
    im = _img(32, 16)
    px = im.load()
    # bloco principal (vista frontal), base larga 4..27, topo 7..24
    _rect(px, 4, 6, 27, 15, WOOD)
    _rect(px, 4, 6, 27, 6, WOOD_L)
    _rect(px, 4, 14, 27, 15, WOOD_D)
    _outline(px, 3, 5, 28, 15, INK)
    # rasgo (slot) da carta: faixa escura no meio
    _rect(px, 8, 7, 23, 8, INK)
    # lábio da frente (o que cobre o pé da carta)
    _rect(px, 6, 9, 25, 9, WOOD_L)
    if variant == 2:
        # entalhe decorativo
        for x in (10, 14, 18, 22):
            px[x, 12] = WOOD_D
    elif variant == 3:
        # cantoneiras de ferro
        _rect(px, 4, 12, 6, 14, IRON)
        _rect(px, 25, 12, 27, 14, IRON)
        px[5, 13] = IRON_L
        px[26, 13] = IRON_L
    return im


def price_tag():
    """24x16: etiqueta de cartão bone com furo e contorno."""
    im = _img(24, 16)
    px = im.load()
    _rect(px, 1, 1, 22, 14, BONE)
    _rect(px, 1, 13, 22, 14, BONE_D)
    _outline(px, 0, 0, 23, 15, INK)
    # cantos chanfrados
    for (x, y) in ((0, 0), (23, 0), (0, 15), (23, 15)):
        px[x, y] = (0, 0, 0, 0)
    # furo do barbante
    px[11, 2] = INK
    px[12, 2] = INK
    px[11, 3] = INK
    px[12, 3] = INK
    # linha de ferrugem (desgaste) na borda esquerda
    px[1, 6] = BONE_D
    px[1, 7] = BONE_D
    return im


def nail():
    im = _img(8, 10)
    px = im.load()
    _rect(px, 2, 1, 5, 3, IRON)
    _outline(px, 1, 0, 6, 4, INK)
    px[3, 2] = IRON_L
    _rect(px, 3, 5, 4, 8, IRON)
    px[3, 9] = INK
    px[4, 9] = INK
    px[2, 5] = INK
    px[5, 5] = INK
    return im


def hook():
    im = _img(10, 14)
    px = im.load()
    # placa de fixação
    _rect(px, 2, 0, 7, 2, IRON)
    _outline(px, 1, 0, 8, 2, INK)
    # haste
    _rect(px, 4, 3, 5, 8, IRON)
    px[3, 3] = INK
    px[6, 3] = INK
    # curva do gancho
    _rect(px, 4, 9, 7, 10, IRON)
    _rect(px, 7, 7, 8, 10, IRON)
    px[8, 6] = IRON_L
    for (x, y) in ((3, 9), (3, 10), (4, 11), (5, 11), (6, 11), (7, 11), (9, 7), (9, 8), (9, 9), (9, 10), (8, 11)):
        px[x, y] = INK
    return im


def dust_mark():
    """64x64: mancha de poeira elíptica em dither (a marca do objeto)."""
    import math
    im = _img(64, 64)
    px = im.load()
    cx, cy = 31.5, 40
    for y in range(64):
        for x in range(64):
            dx = (x - cx) / 28.0
            dy = (y - cy) / 12.0
            d = dx * dx + dy * dy
            if d <= 1.0:
                # dither por anel: centro mais denso
                if d < 0.35:
                    on = (x + y) % 2 == 0
                elif d < 0.7:
                    on = (x % 2 == 0) and (y % 2 == 0)
                else:
                    on = (x % 3 == 0) and (y % 2 == 0)
                if on:
                    px[x, y] = (DUST[0], DUST[1], DUST[2], 170)
    return im


def pixels():
    _ensure()
    for v in (1, 2, 3):
        card_stand(v).save(os.path.join(OUT_DIR, f"card_stand_{v}.png"))
    price_tag().save(os.path.join(OUT_DIR, "price_tag.png"))
    nail().save(os.path.join(OUT_DIR, "nail.png"))
    hook().save(os.path.join(OUT_DIR, "hook.png"))
    dust_mark().save(os.path.join(OUT_DIR, "dust_mark.png"))
    print("[pixels] card_stand_1..3, price_tag, nail, hook, dust_mark")


# ============================================================================
# prancha de quadros (prova visual da F2): junta os PNGs do screenshot_shop fx
# ============================================================================
def sheet(tag, out_name, names, cols=3, scale=0.5):
    """names: lista de sufixos (fx_buy_0.png...) no save dir do LOVE."""
    from PIL import Image, ImageDraw
    save = os.path.join(os.environ.get("APPDATA", ""), "LOVE",
                        os.environ.get("CARDGAME_IDENTITY", "card-game"))
    ims = []
    for n in names:
        p = os.path.join(save, tag + n)
        if os.path.exists(p):
            im = Image.open(p).convert("RGB")
            im = im.resize((int(im.width * scale), int(im.height * scale)), Image.LANCZOS)
            ims.append((n, im))
        else:
            print("[sheet] faltando", p)
    if not ims:
        return
    w, h = ims[0][1].size
    rows = (len(ims) + cols - 1) // cols
    out = Image.new("RGB", (cols * (w + 8) + 8, rows * (h + 28) + 8), (30, 22, 16))
    d = ImageDraw.Draw(out)
    for i, (n, im) in enumerate(ims):
        x = 8 + (i % cols) * (w + 8)
        y = 8 + (i // cols) * (h + 28)
        out.paste(im, (x, y + 20))
        d.text((x + 2, y + 4), n, fill=(216, 201, 163))
    dest = os.path.join(RAW_DIR, out_name)
    out.save(dest)
    print("[sheet]", dest, out.size)


def cmd_sheet(tag):
    sheet(tag, "lojacena_f2_compra.png",
          ["fx_buy_0.png"] + [f"fx_buy_{i}.png" for i in range(1, 7)] +
          ["fx_deny_1.png", "fx_deny_2.png", "fx_deny_3.png"], cols=3, scale=0.5)
    sheet(tag, "lojacena_f2_sino.png",
          [f"fx_bell_{i}.png" for i in range(1, 9)], cols=3, scale=0.5)


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "help"
    if cmd == "queue":
        queue(sys.argv[2:])
    elif cmd == "poll":
        poll(wait="--nowait" not in sys.argv)
    elif cmd == "install":
        install()
    elif cmd == "pixels":
        pixels()
    elif cmd == "sheet":
        cmd_sheet(sys.argv[2] if len(sys.argv) > 2 else "")
    else:
        print(__doc__)
