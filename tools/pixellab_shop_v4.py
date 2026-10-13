#!/usr/bin/env python3
"""
tools/pixellab_shop_v4.py: assets da Loja v4 (docs/plan/shop-v4-estudo.md).

A loja v4 mora numa GRADE DE ARTE 640x360 (pixel de 3 px em 1080p, 4 em
1440p, 2 em 720p: cover-fit em múltiplo inteiro) com UMA inclinação de pixel
art, 1:8 (sobe 1 px a cada 8 px pra direita, ~7,1 graus). As duas superfícies
(degrau das cartas e mesa dos objetos) são desenhadas AQUI, na grade, com as
bordas exatamente em 1:8: a madeira é uma tábua RETA (textura) deslocada uma
linha a cada 8 colunas (cisalhamento inteiro, sem reamostrar = sem escadinha
irregular). A parede do fundo vem do PixelLab (create_image_pro com o salão do
ato 1 como referência de estilo).

  python tools/pixellab_shop_v4.py mock                 # guia de composição
  python tools/pixellab_shop_v4.py queue <grupo> [nomes] # walls | wood | items
  python tools/pixellab_shop_v4.py poll                  # baixa o que ficou pronto
  python tools/pixellab_shop_v4.py compose <wall> <out>  # parede + superfícies

Base64 NUNCA passa por tool call (memória pixellab-base64-mcp-http): este
script lê os PNGs do disco e fala HTTP direto com o MCP.
"""
import base64
import json
import os
import re
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "tools/preview_out/shop_v4/raw")
JOBS = os.path.join(RAW, "jobs.json")

W, H = 640, 360
RUN = 8                     # inclinação 1:8 (uma linha a cada 8 colunas)

# ---------------------------------------------------------------------------
# GEOMETRIA (espelhada em src/ui/shop/ShopLayout.lua ART): retas y = y0 - x/8
# (arredondamento: linha = y0 - floor(x / 8), passo na coluna múltipla de 8)
# ---------------------------------------------------------------------------
G = {
    # v5 rodada 2 (dono: "faixa escura muito grossa abaixo das cartas"): a
    # face do degrau caiu de 12 pra 8 linhas, o vão escuro de 13 pra 4; a
    # mesa ficou 11 px mais funda. Espelhado em ShopLayout.LINES.
    "shelf_top": 188,      # topo da face de cima do degrau (aresta de trás)
    "shelf_edge": 198,     # aresta da FRENTE do tampo do degrau: base das cartas
    "shelf_face": 206,     # fim da face da frente do degrau
    "table_back": 210,     # aresta de trás do tampo da mesa
    "table_edge": 306,     # aresta da frente do tampo
}


def yline(y0, x):
    return y0 - (x // RUN)


def ensure():
    os.makedirs(RAW, exist_ok=True)


def jobs():
    return json.load(open(JOBS)) if os.path.exists(JOBS) else {}


def save_jobs(j):
    json.dump(j, open(JOBS, "w"), indent=1)


def b64(path):
    return base64.b64encode(open(path, "rb").read()).decode()


# ---------------------------------------------------------------------------
def mock(path=None):
    """Guia de composição: parede escura, degrau e mesa nas retas 1:8."""
    from PIL import Image
    ensure()
    im = Image.new("RGB", (W, H), (34, 22, 18))
    px = im.load()
    for x in range(W):
        for y in range(H):
            if y < yline(G["shelf_top"], x):
                c = (44, 30, 24) if (y // 40) % 2 else (40, 27, 22)
            elif y < yline(G["shelf_edge"], x):
                c = (150, 92, 48)
            elif y < yline(G["shelf_face"], x):
                c = (86, 46, 26)
            elif y < yline(G["table_back"], x):
                c = (30, 18, 14)
            elif y < yline(G["table_edge"], x):
                c = (128, 74, 38)
            else:
                c = (70, 36, 22)
            px[x, y] = c
    path = path or os.path.join(RAW, "mock.png")
    im.save(path)
    print("[mock]", path)
    return path


# ---------------------------------------------------------------------------
STYLE_REF = os.path.join(ROOT, "assets/sprites/scenes/castle_hall_1.png")

WALL_BASE = (
    "pixel art back wall of a small medieval relic shop at night, seen straight "
    "from the front, calm and dark, low contrast, warm candle glow from the left; "
    "the LOWER HALF of the picture is plain dark shadow with nothing in it; "
    "limited sepia palette, dark browns and deep reds, crisp 1px dark outlines, "
    "no anti-aliasing, no text, no letters, no people, no counter, no table, "
    "no cards, no coins, no skulls, no candles, no books")

WALLS = {
    "wall_a": "tall dark wooden shelves along the wall holding a few dusty glass "
              "jars and small bottles, old plank wall between them",
    "wall_b": "dark stone wall with a single long wooden shelf of glass jars high "
              "up and wooden beams, a faded red banner on the left",
    "wall_c": "dark wooden panelled wall with two narrow shelves of small potion "
              "bottles, dried herbs hanging from a beam at the top",
}

WOOD = {
    # tábua reta, vista de frente; vira o degrau (tampo claro + face escura)
    "wood_shelf": dict(w=320, h=24, desc=(
        "long straight wooden shelf plank seen from the front and slightly "
        "above: thin lit top surface strip and a darker front face below it, "
        "visible wood grain, dark 1px outline, fills the whole width, warm "
        "brown sepia palette")),
    # tampo da mesa: tábuas compridas na horizontal, vistas de cima
    "wood_top": dict(w=320, h=96, desc=(
        "worn wooden table top made of long horizontal planks seen from above, "
        "plank seams running left to right, subtle grain, warm brown sepia "
        "palette, even lighting, nothing on it, fills the whole picture")),
    # frente do balcão: painéis
    "wood_front": dict(w=320, h=80, desc=(
        "front of a dark wooden shop counter: a thick top rail and recessed "
        "vertical wooden panels below, iron nails, warm dark brown sepia palette, "
        "fills the whole picture, seen straight from the front")),
}


def call(tool, args, timeout=300):
    import pixellab_enemy_anims as F
    text = F.tool_text(F.rpc("tools/call", {"name": tool, "arguments": args}, timeout=timeout))
    m = re.search(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", text)
    return (m.group(0) if m else None), text


def queue(group, names=None):
    ensure()
    J = jobs()
    if group == "walls":
        mpath = os.path.join(RAW, "mock.png")
        if not os.path.exists(mpath):
            mock(mpath)
        for name, extra in WALLS.items():
            if names and name not in names:
                continue
            args = {
                "description": extra + ". " + WALL_BASE,
                "width": W, "height": H, "no_background": False,
                "style_image_base64": b64(STYLE_REF),
                "style_copy": ["color_palette", "outline", "detail", "shading"],
            }
            jid, text = call("create_image_pro", args)
            J[name] = jid
            print(f"[queue] {name}: {jid} {text[:90]!r}", flush=True)
            save_jobs(J)
            time.sleep(2)
    elif group == "wood":
        for name, spec in WOOD.items():
            if names and name not in names:
                continue
            args = {"description": spec["desc"] + ". pixel art, no anti-aliasing",
                    "width": spec["w"], "height": spec["h"], "no_background": False,
                    "shading": "medium shading", "text_guidance_scale": 9,
                    }
            jid, text = call("create_image_pixflux", args)
            J[name] = jid
            print(f"[queue] {name}: {jid} {text[:90]!r}", flush=True)
            save_jobs(J)
            time.sleep(1.5)
    elif group == "items":
        import shop_v4_items as I
        for name, (tool, args) in I.specs(RAW).items():
            if names and name not in names:
                continue
            jid, text = call(tool, args)
            J[name] = jid
            print(f"[queue] {name}: {jid} {text[:90]!r}", flush=True)
            save_jobs(J)
            time.sleep(1.5)


def poll(wait=True, only=None):
    import pixellab_enemy_anims as F
    J = jobs()
    pending = {n: j for n, j in J.items() if j and (not only or n in only)}
    t0 = time.time()
    while pending and time.time() - t0 < 1800:
        for name, jid in list(pending.items()):
            dest = os.path.join(RAW, f"{name}.png")
            if os.path.exists(dest):
                del pending[name]
                continue
            try:
                text = F.tool_text(F.rpc("tools/call", {"name": "get_image", "arguments": {"job_id": jid}}))
            except Exception as e:  # noqa
                print(f"[poll] {name}: erro {e}", flush=True)
                continue
            low = text.lower()
            if "failed" in low and "status" in low:
                print(f"[poll] {name}: FALHOU {text[:200]!r}", flush=True)
                del pending[name]
            elif "completed" in low:
                urls = re.findall(r"https?://\S+?\.png", text) or re.findall(r"(https?://\S+/download)", text)
                if urls:
                    data = F.fetch(urls[0])
                    open(dest, "wb").write(data)
                    print(f"[poll] {name}: salvo {dest}", flush=True)
                    # candidatos extras (pro devolve vários em tamanhos pequenos)
                    for i, u in enumerate(urls[1:16], 1):
                        try:
                            open(os.path.join(RAW, f"{name}__{i}.png"), "wb").write(F.fetch(u))
                        except Exception as e:  # noqa
                            print(f"[poll] {name}#{i}: {e}")
                else:
                    print(f"[poll] {name}: sem URL: {text[:300]!r}", flush=True)
                del pending[name]
        if pending and wait:
            time.sleep(15)
        elif not wait:
            break
    print("[poll] pendentes:", list(pending))


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "mock":
        mock()
    elif cmd == "queue":
        queue(sys.argv[2], sys.argv[3:] or None)
    elif cmd == "poll":
        poll(wait="--nowait" not in sys.argv, only=[a for a in sys.argv[2:] if not a.startswith("--")] or None)
    elif cmd == "compose":
        import shop_v4_compose as C
        C.main(sys.argv[2:])
    else:
        print(__doc__)
