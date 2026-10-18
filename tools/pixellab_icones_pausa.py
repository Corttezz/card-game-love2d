#!/usr/bin/env python3
"""
tools/pixellab_icones_pausa.py: icones proprios de UI (atalhos da pausa e
reusos de arte de carta), Out/2026.

  python tools/pixellab_icones_pausa.py submit [nome,...]
  python tools/pixellab_icones_pausa.py fetch
  python tools/pixellab_icones_pausa.py pick <nome> <N>
  python tools/pixellab_icones_pausa.py sheet <saida.png> nome:N ...

Ferramenta: SEMPRE create_image_pro, estilo = ui_act_scroll.png (familia dos
icones de UI), referencia ui_score_star.png, lidos do DISCO.
"""
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixellab_new_enemies as N
import pixellab_arte_pendente as A

ROOT = N.ROOT
ICONS = os.path.join(ROOT, "assets/sprites/icons")
OUT = os.path.join(ROOT, "tools/preview_out/icones_pausa")
JOBS = os.path.join(OUT, "jobs.json")
STYLE = os.path.join(ICONS, "ui_act_scroll.png")
REF = os.path.join(ICONS, "ui_score_star.png")

ICON_STYLE = ("tiny dark fantasy grimoire UI icon, pixel art at native size, "
              "one bold readable silhouette centered and filling the canvas, "
              "readable at 24 pixels, crisp near-black 1px outline, light from "
              "the upper left, hard-edged pixel clusters, warm sepia parchment, "
              "aged gold and deep brown palette, NO anti-aliasing, NO smooth "
              "gradients, NO text, NO letters, transparent background")

SPECS = {
    "ui_deck": ("a neat squared stack of five face-down playing cards seen "
                "slightly from above, offset edges showing the thickness of the "
                "pile, the top card back is dark oxblood leather with a thin "
                "gold border and a small gold eye sigil in the center, a card "
                "deck. "),
    "ui_jokers": ("a gilded golden jester mask, a smiling fool's face mask "
                  "with diamond shaped eye holes, topped by a small three "
                  "pointed crimson and gold fool's cap with round gold bells, "
                  "court jester emblem. "),
    "ui_journal": ("an open leather bound travel journal lying flat, the "
                   "parchment pages show a hand inked map with a dotted path "
                   "and a tiny red circle mark, a white quill feather pen "
                   "resting diagonally across the right page, ink journey log. "),
    "ui_guide": ("a thick closed leather tome standing upright facing the "
                 "viewer, dark brown cover with brass corner guards, a large "
                 "embossed gold question mark sigil on the cover, a red ribbon "
                 "bookmark hanging from the bottom, guide book. "),
    "ui_health": ("a plump bright crimson heart with a thin gold rim and a "
                  "hard white pixel shine on the upper left, life and health "
                  "emblem, simple and bold. "),
    "ui_mana": ("a faceted glowing sapphire blue mana crystal gem set in a "
                "small gold claw mount, bright cyan core light, magic energy "
                "emblem. "),
    "ui_forge": ("a dark iron blacksmith anvil with a small hammer resting on "
                 "top, a burst of bright orange forge sparks, upgrade forge "
                 "emblem. "),
    "ui_gold": ("a tidy pile of thick stamped gold coins, three short stacks "
                "of coins leaning on each other with two loose coins lying in "
                "front, each coin with a dark rim and a small embossed eye "
                "sigil, warm aged gold with a hard white pixel shine on the "
                "upper left, treasure and gold currency emblem. "),
    "ui_gold_b": ("one big round gold coin seen face on, thick beaded rim, an "
                  "embossed crown sigil in the center, a small stack of three "
                  "more coins tucked behind it to the lower right, warm aged "
                  "gold with hard pixel highlights, gold currency emblem. "),
    "ui_gold_c": ("one big round gold coin seen face on filling the canvas, "
                  "thick beaded rim, a large embossed open eye sigil in the "
                  "center, two more coins stacked flat behind it to the lower "
                  "right, warm aged gold with hard pixel highlights, bold and "
                  "readable when tiny, gold currency emblem. "),
}


def load():
    return json.load(open(JOBS)) if os.path.exists(JOBS) else {}


def save(j):
    os.makedirs(OUT, exist_ok=True)
    json.dump(j, open(JOBS, "w"), indent=2)


def submit(names):
    jobs = load()
    for name in names:
        if jobs.get(name, {}).get("job"):
            print(f"[submit] {name} ja enfileirado: {jobs[name]['job']}")
            continue
        args = {"description": SPECS[name] + ICON_STYLE, "width": 64,
                "height": 64, "no_background": True,
                "style_image_base64": N.b64(STYLE),
                "reference_images": [{"base64": N.b64(REF),
                                      "usage": "icon family: same outline "
                                               "weight, shading, palette and "
                                               "level of detail"}]}
        text = N.call("create_image_pro", args)
        jid = N.job_id_of(text)
        jobs[name] = {"job": jid}
        save(jobs)
        print(f"[submit] {name} -> {jid} {text[:160]!r}", flush=True)
        time.sleep(2)


def fetch():
    jobs = load()
    pend = 0
    for name, j in jobs.items():
        d = os.path.join(OUT, name)
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
        A.contact(name, d)
    print(f"[fetch] pendentes {pend}")


def pick(name, n):
    from PIL import Image
    im = Image.open(os.path.join(OUT, name, f"cand_{n}.png")).convert("RGBA")
    if im.size != (64, 64):
        im = im.resize((64, 64), Image.NEAREST)
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255) if a >= 128 else (0, 0, 0, 0)
    dest = os.path.join(ICONS, name + ".png")
    im.save(dest)
    print(f"[pick] {name} <- cand_{n} -> {dest}")


def sheet(dest, picks):
    from PIL import Image
    sizes = [24, 32, 64, 192]
    rows = []
    for p in picks:
        name, n = p.split(":")
        rows.append(Image.open(os.path.join(OUT, name, f"cand_{n}.png")).convert("RGBA"))
    w = sum(sizes) + 10 * len(sizes) + 10
    S = Image.new("RGBA", (w, len(rows) * 202 + 10), (58, 44, 36, 255))
    for r, im in enumerate(rows):
        x = 10
        for s in sizes:
            small = im.resize((s, s), Image.NEAREST if s % 64 == 0 else Image.BOX)
            if s < 64:
                small = small.resize((s * 3, s * 3), Image.NEAREST)
            S.paste(small, (x, 10 + r * 202), small)
            x += small.width + 10
    S.save(dest)
    print(dest)


if __name__ == "__main__":
    c, a = (sys.argv[1] if len(sys.argv) > 1 else ""), sys.argv[2:]
    if c == "submit":
        submit(a[0].split(",") if a else list(SPECS))
    elif c == "fetch":
        fetch()
    elif c == "pick":
        pick(a[0], int(a[1]))
    elif c == "sheet":
        sheet(a[0], a[1:])
    else:
        print(__doc__)
