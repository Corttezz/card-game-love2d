#!/usr/bin/env python3
"""
tools/pixellab_combo_jokers.py — ilustrações dos 3 coringas de COMBO na
doutrina de carta (Out/2026, 2ª volta).

A 1ª volta foi reprovada pelo dono: "arte BÁSICA e FORA do nosso design" —
eram ícones planos de objeto (três adagas, dois escudos, duas cartas). O
contrato dos coringas, lido nas ilustrações existentes (joker_shield,
joker_vampire, joker_jester, joker_abyss, rogue_after_image): PERSONAGEM ou
cena dramática com sujeito central, contraste forte de valor, contorno de
tinta, paleta sépia com UM acento, sombreado com textura. Mesma receita que
gerou as cartas boas: `create_map_object` 64x64, view side, single color
outline, detailed shading, high detail + o sufixo canônico de
tools/pixellab_generate_new_cards.py (memory/sprite_design_queue.md). O
object_id fica salvo — é ele que o animate_object v3 usa depois.

  python tools/pixellab_combo_jokers.py gen <icon> [n]   # n variantes
  python tools/pixellab_combo_jokers.py fetch           # baixa prontos
  python tools/pixellab_combo_jokers.py contact <icon>  # prancha 3x
  python tools/pixellab_combo_jokers.py pick <icon> <k> # instala variante k
"""
import json
import os
import re
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixellab_new_enemies as N  # call/fetch (Bearer do ~/.claude.json)

ROOT = N.ROOT
OUT = os.path.join(ROOT, "tools/preview_out/combo_jokers/v2")
JOBS = os.path.join(OUT, "jobs.json")
ICONS = os.path.join(ROOT, "assets/sprites/icons")

STYLE = (", dark fantasy grimoire illustration pixel art, inked engraving "
         "style, earthy desaturated palette (bone white, rust orange, deep "
         "blood crimson, tarnished dark steel, charcoal black, burnt sienna, "
         "aged gold, dark leather brown), NO neon colors, NO bright magenta "
         "or cyan, crisp 1px pure black outline, detailed shading with clear "
         "darks and mid-tones, dramatic silhouette, moody upper-left "
         "lighting, limited 8-color palette, Slay the Spire and Magic the "
         "Gathering card art aesthetic")

SUBJECTS = {
    # Chuva de Lâminas — Saraivada (ataques)
    "combo_volley": [
        "hooded knife thrower bust with a fan of five gleaming throwing "
        "daggers held between the fingers of a raised gloved hand, more "
        "daggers raining down around him, cruel grin under the hood",
        "storm of steel daggers falling point down from dark storm clouds "
        "toward the viewer, blades glinting, dramatic rain of blades",
        "masked blade dancer upper body, crimson scarf, throwing a spread "
        "of curved knives that fly outward in an arc, blades catching light",
        # 2ª rodada: v0 lia "garra" (adagas curtas demais entre os dedos)
        "hooded assassin bust, face half in shadow, holding three long "
        "steel throwing daggers fanned out in one raised hand, blades long "
        "and clearly visible, a few more daggers falling around him, "
        "crimson cloth mask over the mouth",
        "grinning rogue bust with a wide-brimmed hat, crossing two arms "
        "loaded with throwing knives, a bandolier of daggers across the "
        "chest, blades glinting",
    ],
    # Muro de Escudos — Muralha (defesas)
    "combo_wall": [
        "grim veteran soldier face with scarred cheek peering over a tight "
        "row of overlapping round iron shields, spear tips above the shield "
        "wall, helmet with nose guard",
        "phalanx of overlapping heraldic round shields locked rim to rim "
        "forming an iron wall, spear points rising behind them, one shield "
        "with a gleaming bronze boss in the center",
        "stern shieldmaiden bust with braided hair and iron helm, holding a "
        "huge round shield in front with more shields overlapping behind "
        "her, cold glint on the iron rim",
        # 2ª rodada: a MURALHA tem que ser de vários escudos (v1/v2 tinham 1)
        "three helmeted soldiers in a tight shield wall, faces hidden behind "
        "a row of three overlapping round iron shields locked rim to rim, "
        "spear tips rising above, front view",
        "grim bearded veteran warrior in a nasal helmet crouched behind a "
        "wall of three overlapping painted round shields, eyes glaring over "
        "the rims, a spear resting on top",
    ],
    # Espelho Gêmeo — Par (duas cartas iguais)
    "combo_pair": [
        "ornate gilded hand mirror with a cracked glass, in the glass a pale "
        "masked face appears doubled, two identical reflections side by "
        "side split by the crack",
        "pale twin-faced harlequin bust, the face split down the middle by "
        "a cracked mirror line, both halves identical and mirrored, gold "
        "filigree collar",
        "tall ornate mirror in a dark gold baroque frame, cracked glass "
        "showing a hooded figure and its exact twin reflection facing each "
        "other",
    ],
}


def load():
    return json.load(open(JOBS)) if os.path.exists(JOBS) else {}


def save(j):
    os.makedirs(OUT, exist_ok=True)
    json.dump(j, open(JOBS, "w"), indent=2)


def gen(icon, n=None):
    jobs = load()
    subs = SUBJECTS[icon]
    for k, subj in enumerate(subs[: int(n) if n else len(subs)]):
        key = f"{icon}_{k}"
        if key in jobs:
            continue
        t = N.call("create_map_object", {
            "description": subj + STYLE, "width": 64, "height": 64,
            "view": "side", "outline": "single color outline",
            "shading": "detailed shading", "detail": "high detail"})
        m = re.search(r"id:\s*([0-9a-f-]{36})", t)
        if not m:
            print("[gen] sem id:", t[:200])
            continue
        jobs[key] = {"object_id": m.group(1), "subject": subj}
        save(jobs)
        print(f"[gen] {key} -> {m.group(1)}", flush=True)
        time.sleep(3)


def fetch():
    jobs = load()
    for key, j in jobs.items():
        out = os.path.join(OUT, key + ".png")
        if os.path.exists(out):
            continue
        t = N.call("get_map_object", {"object_id": j["object_id"]})
        if "completed" not in t.lower():
            print(f"[fetch] {key}: ainda processando")
            continue
        url = f"https://api.pixellab.ai/mcp/map-objects/{j['object_id']}/download"
        open(out, "wb").write(N.F.fetch(url))
        print(f"[fetch] {key} ok")


def contact(icon):
    from PIL import Image, ImageDraw
    fs = sorted(f for f in os.listdir(OUT) if re.match(re.escape(icon) + r"_d+.png$", f))
    ims = [Image.open(os.path.join(OUT, f)).convert("RGBA") for f in fs]
    S = 3
    sh = Image.new("RGBA", (len(ims) * (64 * S + 8), 64 * S + 14), (70, 58, 44, 255))
    d = ImageDraw.Draw(sh)
    for k, im in enumerate(ims):
        b = im.resize((64 * S, 64 * S), Image.NEAREST)
        sh.paste(b, (k * (64 * S + 8), 0), b)
        d.text((k * (64 * S + 8) + 2, 64 * S + 1), fs[k], fill=(255, 255, 200))
    p = os.path.join(OUT, icon + "_contact.png")
    sh.save(p)
    print(p)


def pick(icon, k):
    import shutil
    src = os.path.join(OUT, f"{icon}_{k}.png")
    shutil.copy(src, os.path.join(ICONS, icon + ".png"))
    jobs = load()
    jobs["picked_" + icon] = jobs[f"{icon}_{k}"]["object_id"]
    save(jobs)
    print(f"[pick] {icon} <- {icon}_{k} (object {jobs['picked_' + icon]})")


if __name__ == "__main__":
    c, a = sys.argv[1], sys.argv[2:]
    {"gen": lambda: gen(*a), "fetch": fetch, "contact": lambda: contact(a[0]),
     "pick": lambda: pick(a[0], a[1])}[c]()
