import base64
import json
import os
import re
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixellab_enemy_anims as F

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORLD = os.path.join(ROOT, "assets/sprites/world")
OUT = os.path.join(ROOT, "tools/preview_out/primeiro_plano/pixellab")
RAW = os.path.join(OUT, "raw")
CAND = os.path.join(OUT, "cand")
JOBS = os.path.join(OUT, "jobs.json")
TOOL = "create_image_pro"

DIORAMA = (" Treat it as a tiny pixel art diorama, not a flat texture: overlapping volumes in a "
           "front, middle and back layer, small clumps of different sizes and values, the front "
           "pieces crisp with a dark outline and more contrast, the back pieces darker and softer, "
           "every stone, stick and clump with thickness: a lit face and a shadowed face.")

SOLO = (" Low ground clutter seen from the side at eye level, much wider than tall, sitting flat "
        "on an invisible floor line at the bottom of the canvas. Transparent background, nothing "
        "else: no ground plane, no grass carpet, no floor shadow, no landscape, no sky. Everything "
        "inside the canvas with a small margin, nothing cut off. Same hand-drawn pixel art style "
        "as the style image: crisp 1 px dark outline, the same limited colour palette, flat "
        "clustered shading, few colours, no smooth gradients, no anti-aliasing, no photographic "
        "rendering.")


def light(side):
    return (" Light from the upper %s: the %s side and the tops are lighter, the %s side and "
            "undersides darker." % (side, side, "left" if side == "right" else "right"))


SPECS = {
    "fields_litter": ("fields_rock_0.png", 96, 56, "right",
        "a few fallen oak twigs and small dry brown leaves lying on the ground with two small "
        "grey pebbles, green forest meadow"),
    "highlands_litter": ("highlands_bush_0.png", 96, 56, "right",
        "a broken fallen pine branch with dark blue-green needles and two pine cones lying on the "
        "ground, cold misty highland forest at night"),
    "highlands_tuft": ("highlands_bush_0.png", 96, 56, "right",
        "a clump of tall cold blue-green mountain grass blades with one small grey-blue stone at "
        "its foot, misty highland at night"),
    "abyss_embers": ("abyss_bush_0.png", 64, 32, "right",
        "a small patch of burning embers and broken black charcoal pieces lying on the ground, "
        "glowing orange and red cracks, hellish volcanic wasteland"),
    "abyss_litter": ("abyss_bush_0.png", 96, 56, "right",
        "a charred broken branch with a few glowing ember tips and scattered small black "
        "volcanic pebbles lying on the ground, hellish wasteland"),
    "frost_drift": ("frost_rock_0.png", 96, 56, "right",
        "a low mound of drifted white snow with a few dry frozen grass blades sticking out of it, "
        "winter forest"),
    "frost_stones": ("frost_rock_0.png", 96, 56, "right",
        "three small grey stones half buried in a little snow, each stone capped with snow on "
        "top, winter forest"),
    "marsh_roots": ("marsh_bush_0.png", 96, 56, "right",
        "a few gnarled dark tree roots arching out of the ground and diving back down, with "
        "green moss on top, swamp at night"),
    "marsh_reeds": ("marsh_bush_0.png", 96, 56, "right",
        "a clump of tall thin bog reeds and two brown cattails, olive green, swamp at night"),
    "dusk_flowers": ("dusk_bush_0.png", 96, 56, "left",
        "a small clump of twilight wildflowers: thin stems with violet and pale amber blossoms "
        "and a few dark purple leaves, twilight meadow"),
    "dusk_leaves": ("dusk_bush_0.png", 96, 56, "left",
        "a scatter of fallen crimson and violet autumn leaves with one broken twig lying on the "
        "ground, twilight meadow"),
}


def jobs():
    return json.load(open(JOBS)) if os.path.exists(JOBS) else {}


def save_jobs(j):
    os.makedirs(OUT, exist_ok=True)
    json.dump(j, open(JOBS, "w"), indent=1)


def b64(path):
    return base64.b64encode(open(path, "rb").read()).decode()


def call(tool, args, timeout=300):
    return F.tool_text(F.rpc("tools/call", {"name": tool, "arguments": args}, timeout=timeout))


def queue(names):
    os.makedirs(RAW, exist_ok=True)
    J = jobs()
    for name in names:
        ref, w, h, side, desc = SPECS[name]
        r = b64(os.path.join(WORLD, ref))
        args = {
            "description": desc + "." + DIORAMA + light(side) + SOLO,
            "width": w, "height": h, "no_background": True,
            "style_image_base64": r,
            "style_copy": ["color_palette", "outline", "detail", "shading"],
        }
        text = call(TOOL, args)
        m = re.search(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", text)
        J[name] = {"job": m.group(0) if m else None}
        print(f"[queue] {name}: {J[name]['job']} {text[:120]!r}", flush=True)
        save_jobs(J)
        time.sleep(2)


def download(name, jid):
    text = call("get_image", {"job_id": jid})
    low = text.lower()
    if "status: failed" in low or "status: error" in low:
        print(f"[poll] {name}: FALHOU {text[:160]}")
        return "error"
    if "status: completed" not in low:
        return "wait"
    mf = re.search(r"frames:\s*(\d+)", text)
    m0 = re.search(r"(https?://\S+download\?index=)0", text)
    urls = [m0.group(1) + str(i) for i in range(int(mf.group(1)))] if mf and m0 else []
    if not urls:
        urls = [u.rstrip(")\"',") for u in re.findall(r"https?://\S+", text) if "download" in u]
    for i, u in enumerate(urls):
        open(os.path.join(RAW, f"{name}__{i}.png"), "wb").write(F.fetch(u))
    print(f"[ok] {name}: {len(urls)} candidatas", flush=True)
    return "done"


def poll():
    J = jobs()
    pending = {n: j for n, j in J.items() if j.get("job")
               and not os.path.exists(os.path.join(RAW, n + "__0.png"))}
    t0 = time.time()
    while pending and time.time() - t0 < 1800:
        for name, j in list(pending.items()):
            if download(name, j["job"]) != "wait":
                pending.pop(name)
        if pending:
            time.sleep(20)


def process():
    from PIL import Image
    os.makedirs(CAND, exist_ok=True)
    for f in sorted(os.listdir(RAW)):
        if not f.endswith(".png"):
            continue
        im = Image.open(os.path.join(RAW, f)).convert("RGBA")
        px = im.load()
        for y in range(im.height):
            for x in range(im.width):
                c = px[x, y]
                px[x, y] = (c[0], c[1], c[2], 255 if c[3] >= 128 else 0)
        bb = im.getbbox()
        if bb:
            im.crop(bb).save(os.path.join(CAND, f))


def sheet(prefix):
    from PIL import Image, ImageDraw
    tiles = [(f[:-4], Image.open(os.path.join(CAND, f)).convert("RGBA"))
             for f in sorted(os.listdir(CAND)) if f.startswith(prefix)]
    ref = SPECS[prefix][0]
    tiles.insert(0, ("REF", Image.open(os.path.join(WORLD, ref)).convert("RGBA")))
    rows = []
    for K in (1, 4):
        cw = max(t.width for _, t in tiles) * K + 8
        chh = max(t.height for _, t in tiles) * K + 16
        cols = 8 if K == 4 else len(tiles)
        nr = (len(tiles) + cols - 1) // cols
        img = Image.new("RGBA", (cw * cols, chh * nr), (58, 62, 54, 255))
        d = ImageDraw.Draw(img)
        for i, (label, t) in enumerate(tiles):
            big = t.resize((t.width * K, t.height * K), Image.NEAREST)
            cx, cy = (i % cols) * cw, (i // cols) * chh
            img.alpha_composite(big, (cx + 4, cy + chh - big.height - 2))
            d.text((cx + 2, cy + 1), label.split("__")[-1], fill=(240, 230, 210, 255))
        rows.append(img)
    W = max(r.width for r in rows)
    out = Image.new("RGBA", (W, sum(r.height for r in rows)), (30, 30, 30, 255))
    y = 0
    for r in rows:
        out.alpha_composite(r, (0, y))
        y += r.height
    p = os.path.join(OUT, f"folha_{prefix}.png")
    out.save(p)
    print(p)


def install(pairs):
    import shutil
    for cand, target in zip(pairs[0::2], pairs[1::2]):
        shutil.copyfile(os.path.join(CAND, cand + ".png"), os.path.join(WORLD, target + ".png"))
        print(f"[install] {cand} -> {target}")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "queue":
        queue(sys.argv[2:])
    elif cmd == "poll":
        poll()
    elif cmd == "process":
        process()
    elif cmd == "sheet":
        sheet(sys.argv[2])
    elif cmd == "install":
        install(sys.argv[2:])
