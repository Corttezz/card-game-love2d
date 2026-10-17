#!/usr/bin/env python3
"""
tools/pixellab_arte_pendente.py: arte pendente dos chefes (Out/2026).

  python tools/pixellab_arte_pendente.py submit [nome,...]   # enfileira (nao espera)
  python tools/pixellab_arte_pendente.py fetch               # baixa os prontos + prancha
  python tools/pixellab_arte_pendente.py pick <nome> <N>     # instala a candidata N

Ferramenta: SEMPRE create_image_pro (familia dos icones 64x64), com a
referencia de estilo lida do DISCO (nunca base64 transcrito).
  - joker_boss_eclipse_*: estilo = joker_boss_carrion.png (familia das artes
    de coringa de chefe) + o idle da rainha como referencia de personagem.
  - status_*/ui_*: estilo = status_poison.png (familia dos icones de status).
Candidatas em tools/preview_out/<pasta>/<nome>/cand_N.png + contact.png.
"""
import json
import os
import re
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixellab_new_enemies as N

ROOT = N.ROOT
ICONS = os.path.join(ROOT, "assets/sprites/icons")
ENEMIES = os.path.join(ROOT, "assets/sprites/characters/enemies")
PREVIEW = os.path.join(ROOT, "tools/preview_out")

ICON_STYLE = ("tiny dark fantasy grimoire status icon, pixel art at native "
              "size, one bold readable silhouette centered and filling the "
              "canvas, crisp near-black 1px outline, light from the upper "
              "left, hard-edged pixel clusters, NO anti-aliasing, NO smooth "
              "gradients, NO text, transparent background")
JOKER_STYLE = (", dark fantasy grimoire illustration pixel art, inked "
               "engraving style, crisp 1px pure black outline, detailed "
               "shading with clear darks and mid-tones, hard pixel clusters, "
               "no smooth vector gradients, dramatic silhouette, moody "
               "upper-left lighting, limited palette, legendary card art")

QUEEN_IDLE = os.path.join(ENEMIES, "eclipse_queen/animations/idle/south/0.png")
CARRION_JOKER = os.path.join(ICONS, "joker_boss_carrion.png")
POISON = os.path.join(ICONS, "status_poison.png")

QUEEN_BASE = ("the eclipse queen exactly as in the character reference: pale "
              "lavender-white skin, long white hair, tall spiked silver crown, "
              "dark violet gown with gold trim, huge dark violet bat wings "
              "with bright magenta membrane edges")

SPECS = {
    "joker_boss_eclipse_bust": dict(
        out="coringa_rainha", w=64, h=64, style=CARRION_JOKER,
        refs=[(QUEEN_IDLE, "character base: the eclipse queen, keep her face, "
                           "crown, hair and wing colors")],
        desc=("front facing bust of " + QUEEN_BASE + ", a large black "
              "eclipse disc with a thin blazing gold and magenta corona ring "
              "behind her head like a halo, wings spread wide framing the "
              "disc, serene cruel half-closed eyes, dark petals falling"
              + JOKER_STYLE)),
    "joker_boss_eclipse_relic": dict(
        out="coringa_rainha", w=64, h=64, style=CARRION_JOKER,
        refs=[(QUEEN_IDLE, "character base: take the crown shape, the wing "
                           "shape and the violet, magenta, gold and silver "
                           "palette from this queen")],
        desc=("a black eclipse moon disc ringed by a blazing thin gold corona "
              "with magenta flares, a tall spiked silver queen crown floating "
              "on top of the disc like a halo, two huge dark violet bat wings "
              "with magenta membrane edges spread wide behind the disc, a few "
              "dark petals and tiny pale stars, nothing else"
              + JOKER_STYLE)),
    "status_focus": dict(
        out="icones_proprios", w=64, h=64, style=POISON, refs=[],
        desc=("a glowing golden arcane third eye sigil: an open eye with a "
              "bright amber core inside two thin concentric golden rings, "
              "four short gold rays, concentrated magical focus, warm gold "
              "and amber with deep brown shadows. " + ICON_STYLE)),
    "status_eclipse": dict(
        out="icones_proprios", w=64, h=64, style=POISON, refs=[],
        desc=("a total solar eclipse: a pitch black round sun disc covered "
              "by the moon with a thin blazing magenta and violet corona of "
              "flame licking around its rim, dark violet rays, ominous. "
              + ICON_STYLE)),
    "ui_score_star": dict(
        out="icones_proprios", w=64, h=64, style=POISON, refs=[],
        desc=("a bright gold five-pointed star medal with a hard pixel "
              "shine on the upper left point, bronze laurel sprigs at the "
              "sides, score trophy emblem, warm gold and bronze. " + ICON_STYLE)),
    "ui_act_scroll": dict(
        out="icones_proprios", w=64, h=64, style=POISON, refs=[],
        desc=("an aged parchment map scroll partly unrolled showing a tiny "
              "inked castle tower and a winding road, a dark red wax seal "
              "on the corner, wooden rollers, journey progress emblem. "
              + ICON_STYLE)),
}

DEST = {
    "joker_boss_eclipse_bust": os.path.join(ICONS, "joker_boss_eclipse.png"),
    "joker_boss_eclipse_relic": os.path.join(ICONS, "joker_boss_eclipse.png"),
}


def jobs_path():
    return os.path.join(PREVIEW, "arte_pendente_jobs.json")


def load():
    p = jobs_path()
    return json.load(open(p)) if os.path.exists(p) else {}


def save(j):
    os.makedirs(PREVIEW, exist_ok=True)
    json.dump(j, open(jobs_path(), "w"), indent=2)


def submit(names):
    jobs = load()
    for name in names:
        if name in jobs and jobs[name].get("job"):
            print(f"[submit] {name} ja enfileirado: {jobs[name]['job']}")
            continue
        s = SPECS[name]
        args = {"description": s["desc"], "width": s["w"], "height": s["h"],
                "no_background": True, "style_image_base64": N.b64(s["style"])}
        if s["refs"]:
            args["reference_images"] = [{"base64": N.b64(p), "usage": u}
                                        for p, u in s["refs"]]
        text = N.call("create_image_pro", args)
        jid = N.job_id_of(text)
        jobs[name] = {"job": jid, "out": s["out"]}
        save(jobs)
        print(f"[submit] {name} -> {jid} {text[:80]!r}", flush=True)
        time.sleep(2)


def contact(name, d, scale=4):
    from PIL import Image, ImageDraw
    fs = sorted((f for f in os.listdir(d) if f.startswith("cand_")),
                key=lambda f: int(f[5:-4]))
    ims = [Image.open(os.path.join(d, f)).convert("RGBA") for f in fs]
    if not ims:
        return
    w, h = ims[0].width * scale, ims[0].height * scale
    cols = 8
    rows = (len(ims) + cols - 1) // cols
    sh = Image.new("RGBA", (cols * (w + 6), rows * (h + 14)), (58, 44, 36, 255))
    dr = ImageDraw.Draw(sh)
    for k, im in enumerate(ims):
        x, y = (k % cols) * (w + 6), (k // cols) * (h + 14)
        big = im.resize((w, h), Image.NEAREST)
        sh.paste(big, (x, y), big)
        dr.text((x + 2, y + h), f"{name} {k}", fill=(255, 255, 0))
    p = os.path.join(d, "contact.png")
    sh.save(p)
    print(p)


def fetch():
    jobs = load()
    pend = 0
    for name, j in jobs.items():
        d = os.path.join(PREVIEW, j["out"], name)
        if os.path.exists(os.path.join(d, "contact.png")):
            continue
        text = N.call("get_image", {"job_id": j["job"]})
        low = text.lower()
        if "status: failed" in low or "status: error" in low:
            print(f"[fetch] {name} FALHOU: {text[:200]!r}")
            continue
        if "status: completed" not in low:
            pend += 1
            continue
        os.makedirs(d, exist_ok=True)
        n = N.download_all(text, os.path.join(d, "cand_{}.png"))
        print(f"[fetch] {name}: {n} candidatas")
        contact(name, d)
    print(f"[fetch] pendentes {pend}")


def pick(name, n):
    from PIL import Image
    j = load()[name]
    im = Image.open(os.path.join(PREVIEW, j["out"], name, f"cand_{n}.png")).convert("RGBA")
    if im.size != (64, 64):
        im = im.resize((64, 64), Image.NEAREST)
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255) if a >= 128 else (0, 0, 0, 0)
    dest = DEST.get(name) or os.path.join(ICONS, name + ".png")
    im.save(dest)
    print(f"[pick] {name} <- cand_{n} -> {dest}")


if __name__ == "__main__":
    c, a = (sys.argv[1] if len(sys.argv) > 1 else ""), sys.argv[2:]
    if c == "submit":
        submit(a[0].split(",") if a else list(SPECS))
    elif c == "fetch":
        fetch()
    elif c == "pick":
        pick(a[0], int(a[1]))
    else:
        print(__doc__)
