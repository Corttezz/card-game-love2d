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
OUT = os.path.join(ROOT, "tools/preview_out/landmarks_diorama/pixellab")
RAW = os.path.join(OUT, "raw")
CAND = os.path.join(OUT, "cand")
JOBS = os.path.join(OUT, "jobs.json")
TOOL = "create_image_pro"

DIORAMA = (" Treat the sprite as a small pixel art diorama, not a flat texture: every mass has thickness "
           "with a lit face and a shadow face, parts in front overlap and partly hide the parts behind, "
           "small irregular dotted shadows fall from upper parts onto lower parts and onto the base, front "
           "parts have a crisp outline and strong contrast, parts behind are darker and softer.")
SOLO = (" Single isolated object only, transparent background, no ground plane, no grass carpet, no floor "
        "shadow, no landscape, nothing cut off at the edges. Same hand-drawn pixel art style, palette and "
        "pixel scale as the reference, crisp 1 px dark outline, limited palette, flat clustered shading, "
        "no smooth gradients, no anti-aliasing, no vector shapes, no painterly or realistic 3D rendering. "
        "Side view, straight front perspective, the base sits flat on an invisible floor.")
LIGHT = {
    "sun_r": " Warm sunlight comes from the upper RIGHT: lit faces on the right and on top, shadow faces on the left and underneath.",
    "moon_r": " Pale moonlight comes from the upper RIGHT: lit faces on the right and on top, shadow faces on the left and underneath.",
    "cold_r": " Cold white winter sun comes from the upper RIGHT: lit faces on the right and on top, shadow faces on the left and underneath.",
    "lava_r": " Dim red volcanic sunset light comes from the upper RIGHT: lit faces on the right and on top, shadow faces on the left and underneath; the fire itself lights the inner faces of the stones and logs with orange.",
    "sun_l": " Low golden evening sun comes from the upper LEFT: lit faces on the left and on top, shadow faces on the right and underneath.",
}

SPECS = {
    "fl_lantern": ("anim/fields_lantern_0/0.png", 40, 72, "sun_r",
        "a slim roadside lamp post of an old country road: one straight squared wooden post as tall "
        "as a man, about 5 pixels thick, its right face lit and its left face in shadow, wood grain and "
        "a few knots, a short thin wooden arm with a small diagonal brace near the top, and hanging from "
        "the arm on a short chain a SMALL iron lantern with a warm glowing glass, the lantern is tiny, "
        "at most one fifth of the post height. A few flat stones wedged at the foot of the post. "
        "Muted brown wood, only the lantern glass is bright."),
    "ma_rest": ("anim/marsh_landmark_rest/0.png", 56, 56, "moon_r",
        "a small swamp campfire: a ring of round mossy stones of different sizes around crossed wet dark "
        "logs, a lively orange fire in the middle, a few reeds at one side, the stones in front overlap "
        "the logs, low and wider than tall."),
    "du_rest": ("anim/dusk_landmark_rest/0.png", 56, 56, "sun_l",
        "a small campfire of an autumn dusk heath: a ring of flat grey stones of different sizes around "
        "three crossed thick logs with bark, a lively orange fire in the middle, the stones in front "
        "overlap the logs, low and wider than tall."),
    "fr_rest": ("anim/frost_landmark_rest/0.png", 56, 56, "cold_r",
        "a small campfire in the snow: a ring of rough dark granite stones of different sizes with thin "
        "snow caps on top, crossed split logs, a lively orange fire in the middle, the stones in front "
        "overlap the logs, low and wider than tall."),
    "ab_rest": ("anim/abyss_landmark_rest/0.png", 64, 56, "lava_r",
        "a small campfire of a scorched volcanic wasteland: a ring of jagged dark basalt stones of "
        "different sizes with glowing orange cracks, two charred crossed logs with ember-red bark, a "
        "lively orange and yellow fire in the middle, a few black cinders around the ring, the stones in "
        "front overlap the logs, low and wider than tall, no flat colored pad under it."),
    "ma_elite": ("anim/marsh_landmark_elite/0.png", 72, 80, "moon_r",
        "a cursed swamp totem: a thick rotten tree stump carved into a tall post with a horned animal "
        "skull nailed on top, three glowing green runes carved down the front, hanging moss strands, "
        "thick gnarled roots gripping the mud at the base, a couple of reeds in front of the roots."),
    "du_elite": ("anim/dusk_landmark_elite/0.png", 64, 80, "sun_l",
        "an ancient standing stone of an autumn heath: a tall thick weathered menhir with a lit front "
        "face and a darker side face, a column of small glowing golden runes carved down the front, "
        "lichen patches, a few smaller fallen stones and dry golden grass tufts around its base."),
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


def queue(names, tag="a"):
    os.makedirs(RAW, exist_ok=True)
    J = jobs()
    for name in names:
        ref, w, h, light, desc = SPECS[name]
        r = b64(os.path.join(WORLD, ref))
        args = {
            "description": desc + DIORAMA + LIGHT[light] + SOLO,
            "width": w, "height": h, "no_background": True,
            "style_image_base64": r,
            "style_copy": ["color_palette", "outline", "detail", "shading"],
        }
        text = call(TOOL, args)
        m = re.search(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", text)
        key = name + "_" + tag
        J[key] = {"job": m.group(0) if m else None, "spec": name}
        print(f"[queue] {key}: {J[key]['job']} {'' if m else text[:300]}", flush=True)
        save_jobs(J)
        time.sleep(2)


def download(name, jid):
    text = call("get_image", {"job_id": jid})
    low = text.lower()
    if "status: failed" in low or "status: error" in low:
        print(f"[FAIL] {name}: {text[:160]}")
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
    print(f"[ok] {name}: {len(urls)}", flush=True)
    return "done"


def poll():
    J = jobs()
    pending = {n: j for n, j in J.items() if j.get("job")
               and not os.path.exists(os.path.join(RAW, n + "__0.png")) and not j.get("dead")}
    t0 = time.time()
    while pending and time.time() - t0 < 1800:
        for name, j in list(pending.items()):
            st = download(name, j["job"])
            if st == "error":
                J[name]["dead"] = True
                save_jobs(J)
            if st != "wait":
                pending.pop(name)
        if pending:
            time.sleep(15)


def process():
    from PIL import Image
    os.makedirs(CAND, exist_ok=True)
    for f in sorted(os.listdir(RAW)):
        if not f.endswith(".png") or os.path.exists(os.path.join(CAND, f)):
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
    K = 3
    tiles = [(f[:-4], Image.open(os.path.join(CAND, f)).convert("RGBA"))
             for f in sorted(os.listdir(CAND)) if f.startswith(prefix)]
    spec = prefix.split("_")[0] + "_" + prefix.split("_")[1]
    ref = SPECS[spec][0]
    tiles.insert(0, ("ATUAL", Image.open(os.path.join(WORLD, ref)).convert("RGBA")))
    H = max(t.height for _, t in tiles) * K + 20
    W = sum(t.width * K + 12 for _, t in tiles) + 12
    out = Image.new("RGBA", (W, H * 2 + 8), (92, 98, 88, 255))
    d = ImageDraw.Draw(out)
    x = 12
    for label, t in tiles:
        big = t.resize((t.width * K, t.height * K), Image.NEAREST)
        out.alpha_composite(big, (x, H - big.height))
        out.alpha_composite(t, (x, H * 2 - t.height))
        d.text((x, 2), label[-14:], fill=(255, 250, 230, 255))
        x += big.width + 12
    p = os.path.join(OUT, f"folha_{prefix}.png")
    out.save(p)
    print(p)


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "queue":
        queue(sys.argv[3:], sys.argv[2])
    elif cmd == "poll":
        poll()
    elif cmd == "process":
        process()
    elif cmd == "sheet":
        sheet(sys.argv[2])
