import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixellab_landmarks_diorama as L

ROOT = L.ROOT
L.OUT = os.path.join(ROOT, "tools/preview_out/loja_base/pixellab")
L.RAW = os.path.join(L.OUT, "raw")
L.CAND = os.path.join(L.OUT, "cand")
L.JOBS = os.path.join(L.OUT, "jobs.json")

FLAT = (" It is a GROUND DECAL lying perfectly flat on the floor, seen from a low three-quarter camera "
        "like the floor of a side-view pixel art diorama: very wide and very thin, no thickness, no "
        "raised platform, no cliff sides, no walls, no building, no character. The outer edge is ragged "
        "and irregular, broken into small bites and tongues, never a rectangle or a clean oval. Pixels "
        "near the edge are sparse so it blends into the surrounding ground. Transparent background "
        "outside the patch. Same pixel art style, palette and pixel scale as the reference, limited "
        "palette, flat clustered shading, no smooth gradients, no anti-aliasing.")
PROP = (" Small, about knee height of a man. Every mass has a lit face and a shadow face, front parts "
        "overlap the parts behind." + L.SOLO)

B = {
    "fl": ("landmark_shop.png", "sun_r", "an old forest country road with dark green grass",
           "damp dark brown compacted earth with patches of green moss, a few small grey flat stones "
           "and some trampled grass blades",
           "a short walkway of four or five worn wooden planks laid across the ground one after another",
           "two stacked wooden crates and one small wooden barrel with iron hoops",
           "a short broken wooden fence of two posts and one rail, with a small hanging wooden sign",
           "a low clump of dark green fern and leafy bushes"),
    "hi": ("highlands_landmark_shop.png", "moon_r", "a cold moonlit highland with blue-grey stone",
           "packed grey-brown earth with pale blue-grey flagstones half sunk in it, a few loose pebbles "
           "and short trampled grass",
           "a short path of four flat grey-blue stepping stones laid on the ground one after another",
           "a small pile of firewood logs and one small wooden barrel",
           "a short low dry-stone wall of stacked grey-blue stones with a small wooden sign post",
           "a low clump of heather and blue-green tufts of grass"),
    "ab": ("abyss_landmark_shop.png", "lava_r", "a scorched volcanic wasteland with ash and embers",
           "scorched black and dark brown rock ground with fine grey ash, a few small cracks with dim "
           "orange glow and some black cinders",
           "a short path of four flat dark basalt slabs laid on the ground one after another",
           "an iron-banded dark wooden chest and a charred small barrel",
           "a short fence of two charred wooden stakes with a rusty chain and a small skull sign",
           "a low clump of dry dead thorny shrubs with a few dark red leaves"),
    "fr": ("frost_landmark_shop.png", "cold_r", "a snowy frozen tundra",
           "a cleared yard of trampled packed snow with footprints, a few spots of frozen dark earth "
           "showing through and small icy stones, soft snow piled at the ragged edge",
           "a short path of four wooden planks half covered in snow laid on the ground one after another",
           "two snow-capped wooden crates and a small stack of split firewood",
           "a short wooden fence of two posts and one rail with snow on top and a small sign",
           "a low clump of snowy dark green juniper shrubs"),
    "ma": ("marsh_landmark_shop.png", "moon_r", "a haunted dark green swamp",
           "soggy dark mud with small puddles of black water reflecting a little light, green moss "
           "and a few reeds",
           "a short walkway of four rotten wooden boards laid on the mud one after another",
           "a small wooden barrel and a woven fishing basket on a wooden stake",
           "a short crooked fence of two thin stakes with rope and a small lantern hook",
           "a low clump of swamp reeds and cattails"),
    "du": ("dusk_landmark_shop.png", "sun_l", "an autumn heath at golden dusk with violet shadows",
           "warm ochre-brown packed earth with fallen red and orange leaves, a few flat violet-grey "
           "stones and dry golden grass",
           "a short path of four flat violet-grey stepping stones with fallen leaves",
           "a hay sack, a small wooden crate and two small pumpkins",
           "a short wooden fence of two posts and one rail with a small hanging sign",
           "a low clump of dry golden grass and small red autumn bushes"),
}

SPECS = {}
for bid, (ref, light, world, pad, path, propA, propB, veg) in B.items():
    SPECS[bid + "_pad"] = (ref, 128, 40, light,
        "the flat ground of a small shop yard in " + world + ": " + pad + "." + FLAT)
    SPECS[bid + "_path"] = (ref, 32, 40, light,
        "a short straight access path to a shop door in " + world + ": " + path + ". Seen from the front "
        "at a low camera, the path runs STRAIGHT from the bottom edge of the image up to the top edge, "
        "vertical and centered, symmetric left and right, every plank or stone is laid horizontally "
        "across the path, the near ones at the bottom are a little wider, the far ones at the top a "
        "little narrower. It is not rotated, not diagonal, not a ramp, not a pallet, not a box." + FLAT)
    SPECS[bid + "_propa"] = (ref, 40, 32, light,
        "a small group of yard props for a shop in " + world + ": " + propA + "." + PROP)
    SPECS[bid + "_propb"] = (ref, 48, 32, light,
        "a small yard prop for a shop in " + world + ": " + propB + "." + PROP)
    SPECS[bid + "_veg"] = (ref, 40, 28, light,
        "a small vegetation clump of " + world + ": " + veg + ", low and wider than tall, it grows "
        "against the corner of a building." + PROP)
SPECS["ma_pad2"] = ("marsh_landmark_shop.png", 112, 36, "moon_r",
    "the yard of a stilt hut in a haunted swamp: a small boardwalk platform of a few wide wet wooden "
    "planks laid side by side on dark mud, the planks have a pale moonlit top edge, around it three or "
    "four dark water puddles each with a thin pale rim highlight, a few large flat mossy patches. Few, "
    "large, clean shapes, calm and readable, no noise, no speckle." + FLAT)
SPECS["ma_propc"] = ("marsh_landmark_shop.png", 24, 40, "moon_r",
    "a single wooden stake pushed into the mud with a small iron lantern hanging from a hook at its top, "
    "the lantern glass glows warm yellow, a coil of pale rope hangs on the stake." + PROP)
SPECS["ma_propd"] = ("marsh_landmark_shop.png", 40, 28, "moon_r",
    "a small wooden barrel with a pale weathered top rim and pale iron hoops, next to it a coil of thick "
    "pale hemp rope lying on the ground." + PROP)
SPECS["ab_pad2"] = ("abyss_landmark_shop.png", 120, 36, "lava_r",
    "the yard of a shop in a scorched volcanic wasteland: warm dark red-brown baked rock ground with "
    "patches of pale grey ash, several thin glowing orange and yellow cracks running through it, a few "
    "glowing ember coals scattered near the ragged edge, warm and readable, not black." + FLAT)
SPECS["ab_propc"] = ("abyss_landmark_shop.png", 40, 30, "lava_r",
    "an iron-bound wooden chest with warm red-brown wood and bright copper corners, a small iron brazier "
    "next to it with glowing orange coals that light the chest." + PROP)
SPECS["ab_propd"] = ("abyss_landmark_shop.png", 44, 30, "lava_r",
    "a short fence of two charred wooden stakes with glowing ember tips joined by a rusty orange chain, "
    "a small wooden sign with a red painted mark hangs from the chain." + PROP)
L.SPECS = SPECS

def queue(names, tag):
    import re
    import time
    os.makedirs(L.RAW, exist_ok=True)
    J = L.jobs()
    for name in names:
        ref, w, h, light, desc = SPECS[name]
        text = L.call(L.TOOL, {
            "description": (desc + L.LIGHT[light])[:1990],
            "width": w, "height": h, "no_background": True,
            "style_image_base64": L.b64(os.path.join(L.WORLD, ref)),
            "style_copy": ["color_palette", "outline", "detail", "shading"],
        })
        m = re.search(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", text)
        key = name + "_" + tag
        J[key] = {"job": m.group(0) if m else None, "spec": name}
        print(f"[queue] {key}: {J[key]['job']} {'' if m else text[:120]}", flush=True)
        L.save_jobs(J)
        time.sleep(2)


def fill(tag, only=None):
    import time
    while True:
        J = L.jobs()
        miss = [n for n in sorted(SPECS) if (not only or n in only) and not (J.get(n + "_" + tag) or {}).get("job")]
        if not miss:
            break
        queue(miss[:1], tag)
        J = L.jobs()
        if not J[miss[0] + "_" + tag].get("job"):
            time.sleep(30)


def process():
    from PIL import Image
    os.makedirs(L.CAND, exist_ok=True)
    for f in sorted(os.listdir(L.RAW)):
        if not f.endswith(".png") or os.path.exists(os.path.join(L.CAND, f)):
            continue
        try:
            im = Image.open(os.path.join(L.RAW, f)).convert("RGBA")
        except Exception:
            continue
        a = im.getchannel("A").point(lambda v: 255 if v >= 128 else 0)
        im.putalpha(a)
        bb = im.getbbox()
        if bb:
            im.crop(bb).save(os.path.join(L.CAND, f))


def sheet(prefix, bg=(46, 58, 40)):
    from PIL import Image, ImageDraw
    K = 4
    names = sorted((f for f in os.listdir(L.CAND) if f.startswith(prefix + "_")),
                   key=lambda f: (f.rsplit("__", 1)[0], int(f.rsplit("__", 1)[1][:-4])))
    tiles = [(f[:-4], Image.open(os.path.join(L.CAND, f)).convert("RGBA")) for f in names]
    if not tiles:
        return
    cols = 4
    cw = max(t.width for _, t in tiles) * K + 16
    ch = max(t.height for _, t in tiles) * K + 18
    rows = (len(tiles) + cols - 1) // cols
    out = Image.new("RGBA", (cw * cols, ch * rows), bg + (255,))
    d = ImageDraw.Draw(out)
    for i, (label, t) in enumerate(tiles):
        x, y = (i % cols) * cw + 8, (i // cols) * ch + 14
        out.alpha_composite(t.resize((t.width * K, t.height * K), Image.NEAREST), (x, y))
        out.alpha_composite(t, (x + cw - t.width - 16, y))
        d.text((x, y - 12), label.split("_", 2)[-1], fill=(255, 250, 200, 255))
    p = os.path.join(L.OUT, f"folha_{prefix}.png")
    out.save(p)
    print(p)


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "queue":
        names = sys.argv[3:]
        if names == ["all"]:
            names = sorted(SPECS)
        queue(names, sys.argv[2])
    elif cmd == "fill":
        fill(sys.argv[2], sys.argv[3:] or None)
    elif cmd == "poll":
        L.poll()
    elif cmd == "process":
        process()
    elif cmd == "sheet":
        sheet(sys.argv[2])
