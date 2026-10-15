#!/usr/bin/env python3
import json
import os
import re
import shutil
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixellab_new_enemies as N

ROOT = N.ROOT
OUT = os.path.join(ROOT, "tools/preview_out/coringa_chefe")
JOBS = os.path.join(OUT, "jobs.json")
ICONS = os.path.join(ROOT, "assets/sprites/icons")

STYLE = (", dark fantasy grimoire illustration pixel art, inked engraving "
         "style, earthy desaturated palette (bone white, rust orange, deep "
         "blood crimson, tarnished dark steel, charcoal black, burnt sienna, "
         "aged gold, dark leather brown) with ONE accent color: {accent}, "
         "crisp 1px pure black outline, detailed shading with clear darks and "
         "mid-tones, hard pixel clusters, no smooth vector gradients, dramatic "
         "silhouette, moody upper-left lighting, limited palette, Slay the "
         "Spire and Magic the Gathering legendary card art aesthetic")

ACCENT = {
    "joker_boss_carrion": "dull violet with amber eye glow",
    "joker_boss_lich": "pale frost blue glow",
    "joker_boss_tyrant": "molten lava orange glow",
    "joker_boss_winter": "icy pale blue",
    "joker_boss_colossus": "sickly toxic green glow",
    "joker_boss_eclipse": "deep violet with a thin gold ring",
}

SUBJECTS = {
    "joker_boss_carrion": [
        "regal raven-headed king bust wearing a bent golden crown with a blue "
        "gem, tattered violet mantle, burning amber eyes, a black crow perched "
        "on his shoulder, black feathers drifting around",
        "a battered golden crown resting on a bleached raven skull, three "
        "black crows perched on the crown points, loose black feathers "
        "falling",
        "a murder of black crows swirling in a ring around a floating golden "
        "crown with a blue gem, wings spread, amber eyes glinting",
        "close-up of a crowned raven king face, curved black beak, piercing "
        "amber eye, golden crown with blue jewel, ragged feather collar, "
        "menacing regal stare",
    ],
    "joker_boss_lich": [
        "glowing pale blue phylactery orb held in a silver claw cage on top of "
        "a bone staff, a ghostly skull face visible inside the orb, frost "
        "runes floating around it",
        "lich skull bust wearing a jagged ice crown, cold blue eye lights, "
        "high frosted collar, cradling a glowing pale blue orb under the chin "
        "with bony fingers",
        "ornate crescent staff head of twisted silver and bone gripping a "
        "glowing frost blue orb, ice crystals and runic glyphs orbiting it",
        "small silver reliquary box cracked open, a frost blue soul flame "
        "with a tiny skull face rising from it, chains and frost around",
    ],
    "joker_boss_tyrant": [
        "a molten burning demon heart bound tightly by black iron chains, "
        "cracks of glowing lava light across it, smoke and embers rising",
        "horned demon skull of the abyss tyrant, jagged pale crown shards, "
        "molten orange fire burning inside the eye sockets and cracks, a "
        "broken iron chain hanging from one horn",
        "a broken iron shackle with snapped chain links glowing red hot, "
        "molten lava dripping from the break, embers flying",
        "armored demon fist clenching a ball of hellfire, molten cracks in "
        "the gauntlet, broken chain wrapped around the wrist, embers",
        "anatomical demon heart of black obsidian rock with veins of glowing "
        "molten lava, wrapped by a snapped black iron chain, embers and smoke "
        "rising, not a valentine heart, realistic organ shape with arteries",
        "front view of a giant horned demon skull with two thick curved ram "
        "horns, a crown of pale jagged bone shards, molten lava glowing in the "
        "eye sockets and cracks of the cranium, black iron chain draped across",
        "a molten lava core burning inside a ribcage of black iron, broken "
        "chains hanging from the ribs, fire and embers bursting out",
    ],
    "joker_boss_winter": [
        "an ornate frozen royal scepter with a pale blue orb in a claw of "
        "icicles, frost crystals and snowflakes swirling around it",
        "skeletal winter king bust in frost-covered plate armor, crown of "
        "long icicles, pale blue gem on the chest, cold breath mist",
        "a jagged crown of icicles frozen inside a clear block of ice, a pale "
        "blue jewel glowing at its center, frost cracks",
        "frost-covered kite shield with a skull crest encased in ice, "
        "icicles hanging from the rim, snowflakes drifting",
        "a heraldic kite shield made of pale blue glacier ice, a crowned "
        "skeleton king skull crest in frosted silver at its center, long "
        "icicles hanging from the bottom rim, frost crystals, cold mist",
        "pale frost blue skeletal monarch bust, crown of long sharp icicles, "
        "white frost-rimed fur mantle, glowing pale blue eye sockets, a pale "
        "blue jewel clasp, snowflakes falling",
        "round tower shield of thick clear blue ice with an ancient silver "
        "crown frozen inside it, cracks of white frost, icicles on the rim",
    ],
    "joker_boss_colossus": [
        "a huge rotten green heart overgrown with roots, glowing green "
        "mushrooms and old bones, toxic spores drifting up",
        "roaring moss covered troll colossus face with yellowed tusks, bone "
        "horns and glowing green mushrooms sprouting from its brow",
        "a giant split seed pod bursting open with glowing green spores, "
        "gnarled roots coiling out of it, bone fragments, rot",
        "a gnarled wooden fist of roots and moss clutching a cracked skull, "
        "small glowing green mushrooms growing between the knuckles",
    ],
    "joker_boss_eclipse": [
        "a black eclipse sun with a thin gold corona ring, a spiked silver "
        "queen crown floating in front of it, violet bat wings framing both, "
        "falling dark petals",
        "pale violet skinned eclipse queen bust, spiked silver crown, high "
        "black collar, a black sun halo with a thin gold ring behind her "
        "head, eyes closed serene and cruel",
        "a cracked broken golden halo around a black eclipse disk, violet "
        "light bleeding from the cracks, dark petals drifting",
        "a pair of folded violet bat wings cradling a black eclipse orb with "
        "a gold ring, an eye with a slit pupil opening in the center",
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
        desc = subj + STYLE.format(accent=ACCENT[icon])
        t = N.call("create_map_object", {
            "description": desc, "width": 64, "height": 64,
            "view": "side", "outline": "single color outline",
            "shading": "detailed shading", "detail": "high detail"})
        m = re.search(r"id:\s*([0-9a-f-]{36})", t)
        if not m:
            print("[gen] sem id:", t[:300])
            continue
        jobs[key] = {"object_id": m.group(1), "subject": subj}
        save(jobs)
        print(f"[gen] {key} -> {m.group(1)}", flush=True)
        time.sleep(3)


def fetch():
    jobs = load()
    pend = 0
    for key, j in jobs.items():
        if not isinstance(j, dict):
            continue
        out = os.path.join(OUT, key + ".png")
        if os.path.exists(out):
            continue
        t = N.call("get_map_object", {"object_id": j["object_id"]})
        if "completed" not in t.lower():
            pend += 1
            continue
        url = f"https://api.pixellab.ai/mcp/map-objects/{j['object_id']}/download"
        open(out, "wb").write(N.F.fetch(url))
        print(f"[fetch] {key} ok")
    print(f"[fetch] pendentes {pend}")


def contact(icon):
    from PIL import Image, ImageDraw
    fs = sorted(f for f in os.listdir(OUT) if re.match(re.escape(icon) + r"_\d+\.png$", f))
    ims = [Image.open(os.path.join(OUT, f)).convert("RGBA") for f in fs]
    S = 4
    sh = Image.new("RGBA", (len(ims) * (64 * S + 8), 64 * S + 14), (70, 58, 44, 255))
    d = ImageDraw.Draw(sh)
    for k, im in enumerate(ims):
        b = im.resize((64 * S, 64 * S), Image.NEAREST)
        sh.paste(b, (k * (64 * S + 8), 0), b)
        d.text((k * (64 * S + 8) + 2, 64 * S + 1), fs[k], fill=(255, 255, 200))
    p = os.path.join(OUT, icon + "_prancha.png")
    sh.save(p)
    print(p)


def pick(icon, k):
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
