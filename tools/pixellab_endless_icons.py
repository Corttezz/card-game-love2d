#!/usr/bin/env python3
"""
tools/pixellab_endless_icons.py — ícones dos SELOS DO GRIMÓRIO e das
MALDIÇÕES do endless (Out/2026, memory/endless_and_seals.md).

Contrato dos ícones de status (StatusPill / intent_*): 64x64 transparente,
UM objeto gordo com contorno preto, cor própria, legível a ~36-48px.

  python tools/pixellab_endless_icons.py gen <nome> [seed]   # candidatos
  python tools/pixellab_endless_icons.py pick <nome> <N>     # instala
Candidatos em tools/preview_out/endless_icons/<nome>/; instala em
assets/sprites/icons/<nome>.png.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixellab_new_enemies as N  # call/b64/wait_job/download_all
import pixellab_intent_icons as I  # contact()/cmd_pick reaproveitados

ROOT = N.ROOT
ICONS = os.path.join(ROOT, "assets/sprites/icons")
OUT = os.path.join(ROOT, "tools/preview_out/endless_icons")

STYLE = I.STYLE

SPECS = {
    "seal_grimoire": ("status_strength",
        "a round dark red wax seal stamp with a small open book emblem pressed "
        "into it, drips of wax at the edge, tarnished gold ribbon behind"),
    "curse_vigor_profano": ("status_strength",
        "a sickly purple beating heart wrapped in black thorny vines, "
        "unholy vitality"),
    "curse_laminas": ("intent_attack",
        "two crossed jagged dark steel blades dripping red, cursed sharpened "
        "swords"),
    "curse_couraca_abissal": ("status_vulnerable",
        "a black obsidian shield with glowing violet cracks and a skull boss "
        "in the center, abyssal armor"),
    "curse_cacada": ("intent_attack",
        "a curved bone hunting horn with a red cord and three red claw marks "
        "behind it, the hunt"),
    "curse_dizimo": ("status_strength",
        "a small leather coin purse tied with a black cord with a red skull "
        "stamp, a few gold coins spilling, tithe tax"),
    "status_crows": ("status_poison",
        "a black raven with wings spread wide in flight seen from the front, "
        "glossy blue-violet sheen on the feathers, one glowing ember-orange "
        "eye, two smaller ravens flying behind it, a murder of crows"),
    "curse_fome": ("status_weak",
        "an empty cracked wooden bowl with a broken spoon and grey smoke "
        "rising, famine hunger"),
}


# Emblemas de CONQUISTA (medalhão redondo com aro de bronze, mesmo contrato
# de assets/sprites/achievements/). `pick` deixa em OUT/_ach_import/, que vai
# pro pipeline oficial: python -I tools/achievement_icons.py all <dir>.
ACH_DIR = os.path.join(ROOT, "assets/sprites/achievements")
ACH_STYLE = ("round bronze medallion badge with a dark inner field, one bold "
             "emblem inside, crisp 1px dark outline, hand-placed pixel art, "
             "NO text, NO background outside the medallion")
ACH = {
    "ciclo_3": ("alem_da_pagina", "three overlapping dark red curse runes "
                "circling an open book, cursed cycle"),
    "ciclo_5": ("alem_da_pagina", "a burning open book with five small purple "
                "curse flames around it"),
    "ciclo_10": ("alem_da_pagina", "an ouroboros of black ink swallowing its "
                 "tail around a glowing violet eye, endless"),
    "primeiro_selo": ("alem_da_pagina", "a single red wax seal with a book "
                      "emblem, gold ribbon"),
    "selo_max_guerreiro": ("alem_da_pagina", "a red wax seal pierced by a "
                           "steel sword, ten tiny gold dots on the rim"),
    "selo_max_mago": ("alem_da_pagina", "a red wax seal under a glowing blue "
                      "arcane orb, ten tiny gold dots on the rim"),
    "selo_max_ladino": ("alem_da_pagina", "a red wax seal with a green "
                        "poisoned dagger across it, ten tiny gold dots on the rim"),
}


def cmd_gen(name, seed=None):
    if name in ACH:
        style_id, desc = ACH[name]
        style_path = os.path.join(ACH_DIR, style_id + ".png")
        desc = f"{desc}. {ACH_STYLE}"
    else:
        style_id, desc = SPECS[name]
        style_path = os.path.join(ICONS, style_id + ".png")
        desc = f"{desc}. {STYLE}"
    args = {"description": desc, "width": 64, "height": 64,
            "no_background": True,
            "style_image_base64": N.b64(style_path)}
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
    I.OUT = OUT
    I.contact(name, n)


def cmd_pick(name, n):
    """Binariza o alfa (pixel art sem meio-tom) e instala em 64x64."""
    from PIL import Image
    dest = os.path.join(OUT, "_ach_import") if name in ACH else ICONS
    os.makedirs(dest, exist_ok=True)
    im = Image.open(os.path.join(OUT, name, f"cand_{n}.png")).convert("RGBA")
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255) if a >= 128 else (0, 0, 0, 0)
    if im.size != (64, 64):
        im = im.resize((64, 64), Image.NEAREST)
    im.save(os.path.join(dest, name + ".png"))
    print(f"[pick] {name} <- cand_{n} -> {dest}")


if __name__ == "__main__":
    c, a = (sys.argv[1] if len(sys.argv) > 1 else ""), sys.argv[2:]
    if c == "gen":
        cmd_gen(a[0], a[1] if len(a) > 1 else None)
    elif c == "pick":
        cmd_pick(a[0], int(a[1]))
    else:
        print(__doc__)
