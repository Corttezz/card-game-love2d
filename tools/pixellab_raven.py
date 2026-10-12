#!/usr/bin/env python3
"""
tools/pixellab_raven.py — o NARRADOR do tutorial (Out/2026): o corvo do
grimório, empoleirado num livro velho, olhando pra DIREITA (o balão de fala
fica à direita dele, canto inferior esquerdo da tela, à la Jimbo do Balatro).

Fluxo (mesma doutrina dos inimigos — tools/pixellab_new_enemies.py):
  base   create_image_pro com style_image = sprite do roster (traço/paleta do
         jogo) → 4 candidatos em tools/preview_out/raven/cand_N.png; OLHAR e
         recusar "vetor liso".
  pick   python tools/pixellab_raven.py pick <N>
         → assets/sprites/narrator/raven_base.png (alpha binário, recortado)
  frames python tools/pixellab_raven.py frames
         → bico aberto e olho fechado PINTADOS a partir da base (zero geração,
         zero deriva: quadro de fala = quadro base com o bico mexido). As
         coordenadas do bico/olho ficam em RIG, medidas no raven_base.png.

Uso:
  python tools/pixellab_raven.py base [seed]
  python tools/pixellab_raven.py pick <N>
  python tools/pixellab_raven.py frames
"""
import base64
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixellab_enemy_anims as F  # rpc/tool_text/fetch/token
import pixellab_new_enemies as NE  # call/job_id_of/wait_job/download_all

ROOT = F.ROOT
OUT = os.path.join(ROOT, "tools/preview_out/raven")
DEST = os.path.join(ROOT, "assets/sprites/narrator")

STYLE_REF = os.path.join(F.ENEMIES_DIR, "dusk_bat", "animations/idle/south/0.png")

DESC = ("a wise old black raven perched on top of a closed ancient leather "
        "grimoire book with brass corner clasps, side view facing RIGHT, "
        "glossy blue-black feathers with subtle purple sheen, small bright "
        "amber eye, thick dark grey beak, head slightly tilted curious, "
        "tail feathers hanging over the book edge, the book has a faded "
        "gold rune on its spine. Dark fantasy grimoire pixel art, inked "
        "engraving style, crisp 1px pure black outline, detailed shading "
        "with clear darks and mid-tones, hand-placed pixels with visible "
        "dithering and hard edges, NO smooth vector gradients, NO "
        "anti-aliased blur, Slay the Spire card art aesthetic, transparent "
        "background, single raven and its book only, no text, no ground.")


def cmd_base(seed=None):
    args = {"description": DESC, "width": 96, "height": 96,
            "no_background": True,
            "style_image_base64": NE.b64(STYLE_REF),
            "style_copy": ["color_palette", "outline", "detail", "shading"]}
    if seed is not None:
        args["seed"] = int(seed)
    text = NE.call("create_image_pro", args)
    jid = NE.job_id_of(text)
    print(f"[base] raven job {jid}", flush=True)
    if not jid:
        print(text[:400])
        return
    done = NE.wait_job(jid)
    if not done:
        return
    os.makedirs(OUT, exist_ok=True)
    tag = f"s{seed}_" if seed is not None else ""
    n = NE.download_all(done, os.path.join(OUT, "cand_" + tag + "{}.png"))
    open(os.path.join(OUT, f"base_job_{tag or 'x'}.txt"), "w").write(done)
    print(f"[base] {n} candidatos em {OUT}", flush=True)
    contact()


def contact():
    from PIL import Image
    fs = sorted(f for f in os.listdir(OUT) if f.startswith("cand_") and f.endswith(".png"))
    ims = [Image.open(os.path.join(OUT, f)).convert("RGBA") for f in fs]
    if not ims:
        return
    S = 3
    W = sum(im.width for im in ims) * S + 8 * len(ims)
    H = max(im.height for im in ims) * S
    sh = Image.new("RGBA", (W, H), (70, 78, 58, 255))
    x = 0
    for im in ims:
        big = im.resize((im.width * S, im.height * S), Image.NEAREST)
        sh.paste(big, (x, 0), big)
        x += im.width * S + 8
    sh.save(os.path.join(OUT, "contact.png"))
    print("ordem:", fs)
    print(os.path.join(OUT, "contact.png"))


def cmd_pick(name):
    from PIL import Image
    src = Image.open(os.path.join(OUT, f"cand_{name}.png")).convert("RGBA")
    px = src.load()
    for y in range(src.height):
        for x in range(src.width):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255) if a >= 128 else (0, 0, 0, 0)
    crop = src.crop(src.getbbox())
    W, H = crop.width + 4, crop.height + 4
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    canvas.paste(crop, (2, 2))
    os.makedirs(DEST, exist_ok=True)
    canvas.save(os.path.join(DEST, "raven_base.png"))
    print(f"[pick] cand {name} -> raven_base.png {canvas.size}")


# Rig medido no raven_base.png (cand 0, 94×93) — ver head_zoom/full_zoom em
# tools/preview_out/raven/. Bico: dobradiça em (72,14), mandíbula de baixo nas
# linhas 14-16 de x 72 a 85 (a ponta em gancho 86-87 é da de CIMA). Olho:
# âmbar + brilho branco em x 64-71, y 6-12. Respiro: linhas 0-29 (cabeça e
# dorso) sobem 1px — a costura cai dentro da pena.
RIG = {
    "hinge": (72, 14), "lower": (72, 14, 85, 16), "drop": 3,
    "eye": (64, 6, 71, 12), "breath_rows": 29,
}
MOUTH = (74, 18, 26, 255)
INK = (14, 10, 18, 255)


def _is_eye(r, g, b):
    # âmbar (r>g>b bem separado) ou o brilho quase branco
    return (r > g > b and r - b > 45) or (r > 200 and g > 200 and b > 200)


def _open_beak(im):
    """Bico aberto por ROTAÇÃO nas duas mandíbulas em torno da dobradiça:
    a de cima sobe até UP px na ponta, a de baixo desce até DOWN px; o vão
    vira boca (contorno de tinta + vermelho escuro)."""
    hx, hy = RIG["hinge"]
    UP, DOWN, SPAN = 2.2, 4.6, 15.0
    src = im.copy()
    px, sp = im.load(), src.load()

    def upper(x, y):
        return (x >= hx + 1 and 5 <= y <= hy - 1) or (x >= 85 and y <= 17)

    def lower(x, y):
        return hx + 1 <= x <= 84 and hy <= y <= hy + 2

    for y in range(0, 20):
        for x in range(hx + 1, im.width):
            if upper(x, y) or lower(x, y):
                px[x, y] = (0, 0, 0, 0)
    top_of_lower, bot_of_upper = {}, {}
    for y in range(0, 20):
        for x in range(hx + 1, im.width):
            c = sp[x, y]
            if c[3] == 0:
                continue
            f = (x - hx) / SPAN
            if upper(x, y):
                ny = y - round(f * UP)
                if ny >= 0:
                    px[x, ny] = c
                    if y <= hy - 1:
                        bot_of_upper[x] = max(bot_of_upper.get(x, -1), ny)
            elif lower(x, y):
                ny = y + round(f * DOWN)
                if ny < im.height:
                    px[x, ny] = c
                    top_of_lower[x] = min(top_of_lower.get(x, 99), ny)
    for x in range(hx + 2, 85):
        if x in bot_of_upper and x in top_of_lower:
            for y in range(bot_of_upper[x] + 1, top_of_lower[x]):
                edge = (y == bot_of_upper[x] + 1) or (y == top_of_lower[x] - 1)
                px[x, y] = INK if edge else MOUTH
    return im


def _blink(im):
    x0, y0, x1, y1 = RIG["eye"]
    px = im.load()
    lid = px[x0 - 2, y0 + 3]
    hits = [(x, y) for y in range(y0, y1 + 1) for x in range(x0, x1 + 1)
            if px[x, y][3] and _is_eye(*px[x, y][:3])]
    if not hits:
        print("[frames] AVISO: olho não encontrado no rig")
        return im
    ys = [y for _, y in hits]
    mid = (min(ys) + max(ys)) // 2
    for x, y in hits:
        px[x, y] = INK if y == mid else lid
    return im


def _breathe(im):
    from PIL import Image
    out = im.copy()
    px, sp = out.load(), im.load()
    rows = RIG["breath_rows"]
    for y in range(0, rows + 1):
        for x in range(im.width):
            px[x, y] = sp[x, y + 1]
    return out


def cmd_frames():
    from PIL import Image
    base = Image.open(os.path.join(DEST, "raven_base.png")).convert("RGBA")
    combos = {
        "idle": base.copy(),
        "talk": _open_beak(base.copy()),
        "blink": _blink(base.copy()),
    }
    for name, im in list(combos.items()):
        combos[name + "_breathe"] = _breathe(im)
    for name, im in combos.items():
        im.save(os.path.join(DEST, f"raven_{name}.png"))
    # folha de conferência (OLHAR antes de commitar)
    S = 4
    names = ["idle", "talk", "blink", "idle_breathe", "talk_breathe", "blink_breathe"]
    W = (base.width * S + 8) * len(names)
    sheet = Image.new("RGBA", (W, base.height * S), (70, 78, 58, 255))
    for i, n in enumerate(names):
        big = combos[n].resize((base.width * S, base.height * S), Image.NEAREST)
        sheet.paste(big, (i * (base.width * S + 8), 0), big)
    p = os.path.join(OUT, "frames_sheet.png")
    sheet.save(p)
    print(p)


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "base":
        cmd_base(sys.argv[2] if len(sys.argv) > 2 else None)
    elif cmd == "pick":
        cmd_pick(sys.argv[2])
    elif cmd == "frames":
        cmd_frames()
    elif cmd == "contact":
        contact()
    else:
        print(__doc__)
