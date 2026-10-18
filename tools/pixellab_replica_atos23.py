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
OUT = os.path.join(ROOT, "tools/preview_out/replica_atos/pixellab")
RAW = os.path.join(OUT, "raw")
CAND = os.path.join(OUT, "cand")
JOBS = os.path.join(OUT, "jobs.json")
TOOL = "create_image_pro"

STYLE = (" Transparent background, nothing else in the image: no ground, no grass, no "
         "floor shadow, no landscape. The whole object is inside the canvas with a small "
         "margin, nothing cut off. Same hand-drawn pixel art style as the reference: crisp "
         "1 px dark outline, the same colour palette, flat clustered shading, few colours, "
         "no smooth gradients, no anti-aliasing, no photographic rendering. Side view, "
         "straight front perspective, the base sits flat on an invisible floor.")

TREE = (" Single isolated tree only. Thick visible roots at the base. Same scale as the "
        "reference tree (same trunk thickness and the same size of branch clusters). "
        "Light from the upper right: right side and tops lighter, left side and undersides darker.")

SPECS = {
    "hl_brazier": ("highlands_brazier_0.png", 48, 120,
        "a tall slender roadside lamp pillar of an old mountain kingdom: a narrow square "
        "column of weathered grey-blue stone blocks, as tall as a man, a wider stepped stone "
        "base, on top a small dark iron brazier bowl holding a cold pale blue spectral flame. "
        "Muted desaturated stone, only the flame is bright." + STYLE),
    "hl_pine_a": ("highlands_pine_0.png", 96, 176,
        "a very tall and narrow spire-shaped pine of the same cold blue-green highland forest, "
        "sparse tiers with visible gaps of sky between them, bare lower trunk" + TREE + STYLE),
    "hl_pine_b": ("highlands_pine_0.png", 96, 176,
        "an old storm-damaged pine of the same cold blue-green highland forest: the top of the "
        "crown snapped off and dead, a few long uneven branch tiers, crooked trunk" + TREE + STYLE),
    "hl_pine_c": ("highlands_pine_0.png", 112, 160,
        "a short wide bushy pine of the same cold blue-green highland forest, dense full "
        "round lower tiers much wider than tall, short thick trunk" + TREE + STYLE),
    "ab_brazier": ("abyss_brazier_0.png", 48, 120,
        "a tall slender roadside fire pillar of a hellish wasteland road: a narrow column of "
        "black volcanic stone with thin glowing ember cracks, as tall as a man, a wide rough "
        "base, on top a dark iron brazier bowl with an orange-red fire." + STYLE),
    "ab_torch": ("abyss_torch_0.png", 40, 124,
        "a tall roadside torch stand of a hellish wasteland road: a thin black wrought iron "
        "pole as tall as a man, a heavy rough black stone foot at the bottom, at the top a "
        "small iron cage holding a burning torch with an orange-red flame." + STYLE),
    "ab_dead_a":("abyss_deadtree_0.png", 112, 168,
        "a tall thin dead tree of the same hellish wasteland, a single straight charred trunk "
        "with short broken branches pointing up like spikes, glowing ember cracks in the bark" + TREE + STYLE),
    "ab_dead_b": ("abyss_deadtree_0.png", 120, 150,
        "a wide low dead tree of the same hellish wasteland, a short thick trunk with long "
        "bare branches spreading sideways almost horizontally, glowing ember cracks" + TREE + STYLE),
    "ab_dead_c": ("abyss_deadtree_0.png", 112, 168,
        "a dead tree of the same hellish wasteland bent hard to one side by the wind, a "
        "leaning curved trunk, few bare twisted branches, glowing ember cracks" + TREE + STYLE),
    "ab_fissure": ("abyss_rock_0.png", 72, 32,
        "a flat crack in the dark scorched ground seen from the side at a low angle, a "
        "jagged split in black volcanic soil with glowing orange lava deep inside, a few "
        "charred pebbles at the edges, very low and wide, flat on the ground." + STYLE),
}


def jobs():
    return json.load(open(JOBS)) if os.path.exists(JOBS) else {}


def save_jobs(j):
    json.dump(j, open(JOBS, "w"), indent=1)


def b64(path):
    return base64.b64encode(open(path, "rb").read()).decode()


def call(tool, args, timeout=300):
    return F.tool_text(F.rpc("tools/call", {"name": tool, "arguments": args}, timeout=timeout))


def queue(names):
    os.makedirs(RAW, exist_ok=True)
    J = jobs()
    for name in names:
        ref, w, h, desc = SPECS[name]
        r = b64(os.path.join(WORLD, ref))
        args = {
            "description": desc, "width": w, "height": h, "no_background": True,
            "style_image_base64": r,
            "style_copy": ["color_palette", "outline", "detail", "shading"],
            "reference_images": [{"base64": r, "usage": "style, palette, outline weight and "
                                  "scale: draw a DIFFERENT object of the same biome by the same artist"}],
        }
        text = call(TOOL, args)
        m = re.search(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", text)
        J[name] = {"job": m.group(0) if m else None}
        print(f"[queue] {name}: {J[name]['job']} {text[:80]!r}", flush=True)
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
            print(f, im.crop(bb).size)


def sheet(prefix):
    from PIL import Image, ImageDraw
    K = 2
    tiles = [(f, Image.open(os.path.join(CAND, f)).convert("RGBA"))
             for f in sorted(os.listdir(CAND)) if f.startswith(prefix)]
    ref = SPECS[tiles[0][0].split("__")[0]][0]
    tiles.insert(0, ("REF " + ref, Image.open(os.path.join(WORLD, ref)).convert("RGBA")))
    H = max(t.height for _, t in tiles) * K + 18
    W = sum(t.width * K + 10 for _, t in tiles)
    out = Image.new("RGBA", (W, H), (40, 44, 52, 255))
    d = ImageDraw.Draw(out)
    x = 0
    for label, t in tiles:
        big = t.resize((t.width * K, t.height * K), Image.NEAREST)
        out.alpha_composite(big, (x, H - big.height))
        d.text((x, 2), label[:24], fill=(240, 230, 210, 255))
        x += big.width + 10
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
