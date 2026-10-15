#!/usr/bin/env python3
"""
tools/pixellab_boss_mechanics.py: arte das mecanicas dos chefes 2-6
(memory/boss_mechanics.md): icones de status 64x64 no estilo de
status_poison e objetos contados da cena / projeteis do golpe.

  python tools/pixellab_boss_mechanics.py gen <nome> [seed]
  python tools/pixellab_boss_mechanics.py pick <nome> <N>
Candidatos em tools/preview_out/boss_mech_art/<nome>/ (contact.png); pick
binariza o alfa e instala no destino do SPECS.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixellab_new_enemies as N

ROOT = N.ROOT
OUT = os.path.join(ROOT, "tools/preview_out/boss_mech_art")
ICONS = os.path.join(ROOT, "assets/sprites/icons")
ENEMIES = os.path.join(ROOT, "assets/sprites/characters/enemies")

ICON_STYLE = ("tiny dark fantasy grimoire status icon, pixel art at native "
              "size, one bold readable silhouette centered and filling the "
              "canvas, crisp near-black 1px outline, light from the upper "
              "left, hard-edged pixel clusters, NO anti-aliasing, NO smooth "
              "gradients, NO text, transparent background")
OBJ_STYLE = ("hand-placed pixel art game sprite, crisp near-black 1px "
             "outline, hard-edged pixel clusters, NO anti-aliasing, NO "
             "smooth gradients, NO text, transparent background, single "
             "object only, fills the canvas")


def idle0(eid):
    return os.path.join(ENEMIES, eid, "animations/idle/south/0.png")


def icon(desc):
    return (64, 64, os.path.join(ICONS, "status_poison.png"),
            desc + ". " + ICON_STYLE)


SPECS = {
    "status_runes": icon(
        "three glowing pale cyan rune stones floating in a triangle, carved "
        "dark slate stones with bright ice-blue arcane glyphs, a faint violet "
        "magic ring connecting them"),
    "status_chains": icon(
        "a heavy black iron chain in a loop with one broken link glowing "
        "molten orange at the crack, sparks"),
    "status_frost": icon(
        "a large jagged ice crystal snowflake shard, pale cyan and white "
        "with deep blue shading, frost spikes"),
    "status_roots": icon(
        "twisted rotten green-brown tree roots curling out of a clump of dark "
        "mud, sickly green sap dripping, mossy"),
    "status_moon": icon(
        "a pale lavender crescent moon with a dark violet shadow side and a "
        "thin magenta glowing rim, two tiny stars"),
    "rune_stone": (32, 32, idle0("tower_lich"),
        "a small floating rune stone shard, dark slate grey stone cut like a "
        "pointed crystal, one bright ice-blue glowing arcane glyph carved on "
        "its face, front view. " + OBJ_STYLE),
    "chain_link": (16, 32, idle0("abyss_tyrant"),
        "a vertical segment of a heavy black iron chain: exactly two "
        "interlocked oval links stacked top to bottom, the top link seen "
        "from the front and the bottom link seen edge-on, dark iron with "
        "rusty orange glints. " + OBJ_STYLE),
    "fireball": (32, 32, idle0("abyss_tyrant"),
        "a hellfire fireball flying to the right, bright yellow-orange core, "
        "red flame tail trailing to the left, dark smoke edge. " + OBJ_STYLE),
    "frost_corner": (64, 64, idle0("winter_monarch"),
        "a corner of frost growing on a window: jagged ice crystals and "
        "frost ferns spreading from the bottom-left corner of the canvas "
        "toward the top-right, pale cyan and white, transparent elsewhere. "
        + OBJ_STYLE),
    "ice_block": (96, 144, idle0("winter_monarch"),
        "a tall rectangular block of clear blue ice shaped like a playing "
        "card, transparent cracked ice with white frost on the edges and "
        "corners, bright highlights on the upper left, hollow see-through "
        "middle. " + OBJ_STYLE),
    "ice_shard": (32, 32, idle0("winter_monarch"),
        "a sharp icicle projectile flying to the right, pointed tip on the "
        "right, pale cyan ice with white highlight and a small frost trail "
        "on the left. " + OBJ_STYLE),
    "root": (32, 64, idle0("rot_colossus"),
        "a single thick rotten tree root tentacle rising straight up out of "
        "the ground, twisted dark brown bark with sickly green moss and "
        "glowing green sap veins, pointed tip at the top, wide base at the "
        "bottom. " + OBJ_STYLE),
    "moon": (32, 32, idle0("eclipse_queen"),
        "a small full moon disc, pale lavender white with soft violet craters "
        "and a thin magenta rim light, perfectly round. " + OBJ_STYLE),
    "crescent_blade": (32, 32, idle0("eclipse_queen"),
        "a spinning crescent moon blade projectile flying to the right, "
        "sharp pale lavender crescent with magenta glowing edge and a faint "
        "violet trail. " + OBJ_STYLE),
}

DEST = {
    "rune_stone": os.path.join(ENEMIES, "tower_lich/mechanic/rune.png"),
    "chain_link": os.path.join(ENEMIES, "abyss_tyrant/mechanic/chain_link.png"),
    "fireball": os.path.join(ENEMIES, "abyss_tyrant/mechanic/fireball.png"),
    "frost_corner": os.path.join(ENEMIES, "winter_monarch/mechanic/frost_corner.png"),
    "ice_block": os.path.join(ENEMIES, "winter_monarch/mechanic/ice_block.png"),
    "ice_shard": os.path.join(ENEMIES, "winter_monarch/mechanic/ice_shard.png"),
    "root": os.path.join(ENEMIES, "rot_colossus/mechanic/root.png"),
    "moon": os.path.join(ENEMIES, "eclipse_queen/mechanic/moon.png"),
    "crescent_blade": os.path.join(ENEMIES, "eclipse_queen/mechanic/crescent.png"),
}


def contact(name, scale):
    from PIL import Image, ImageDraw
    d = os.path.join(OUT, name)
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
        dr.text((x + 2, y + h), str(k), fill=(255, 255, 0))
    p = os.path.join(d, "contact.png")
    sh.save(p)
    print(p)


def cmd_gen(name, seed=None):
    w, h, style, desc = SPECS[name]
    args = {"description": desc, "width": w, "height": h,
            "no_background": True, "style_image_base64": N.b64(style)}
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
    N.download_all(done, os.path.join(d, "cand_{}.png"))
    contact(name, 4 if w <= 32 else 2)


def cmd_pick(name, n):
    from PIL import Image
    im = Image.open(os.path.join(OUT, name, f"cand_{n}.png")).convert("RGBA")
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255) if a >= 128 else (0, 0, 0, 0)
    dest = DEST.get(name) or os.path.join(ICONS, name + ".png")
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    im.save(dest)
    print(f"[pick] {name} <- cand_{n} -> {dest}")


if __name__ == "__main__":
    c, a = (sys.argv[1] if len(sys.argv) > 1 else ""), sys.argv[2:]
    if c == "gen":
        for nm in a[0].split(","):
            cmd_gen(nm, a[1] if len(a) > 1 else None)
    elif c == "pick":
        cmd_pick(a[0], int(a[1]))
    else:
        print(__doc__)
