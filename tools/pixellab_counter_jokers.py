import json
import os
import re
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixellab_new_enemies as N

ROOT = N.ROOT
OUT = os.path.join(ROOT, "tools/preview_out/coringas_contra/arte")
JOBS = os.path.join(OUT, "jobs.json")
ICONS = os.path.join(ROOT, "assets/sprites/icons")

STYLE = (", dark fantasy grimoire illustration pixel art, inked engraving "
         "style, earthy desaturated palette (bone white, rust orange, deep "
         "blood crimson, tarnished dark steel, charcoal black, burnt sienna, "
         "aged gold, dark leather brown), NO neon colors, NO bright magenta "
         "or cyan, crisp 1px pure black outline, detailed shading with clear "
         "darks and mid-tones, dramatic silhouette, moody upper-left "
         "lighting, limited 8-color palette, narrow centered composition, "
         "Slay the Spire and Magic the Gathering card art aesthetic")

SUBJECTS = {
    "counter_lantern": [
        "hooded night watchman bust raising an old brass lantern in front of "
        "his face, warm amber light cutting through swirling grey fog, eyes "
        "glinting under the hood",
        "ornate brass lantern with a single staring golden eye glowing inside "
        "the glass, wisps of grey fog parting around it, hanging from a hook",
        "old owl with huge glowing amber eyes perched on top of a brass "
        "lantern, grey mist around, front view",
    ],
    "counter_brazier": [
        "small iron brazier of glowing red coals held in two gloved hands, "
        "frost crystals melting and dripping on the rim, warm orange glow",
        "stern old blacksmith bust cupping a tiny iron brazier full of embers "
        "against his chest, frost on his beard melting, orange glow on face",
        "hanging iron censer full of glowing coals with icicles melting off "
        "its chains, sparks rising, front view",
    ],
    "counter_antidote": [
        "plague doctor bust with a leather beak mask holding up a small corked "
        "glass vial of clear amber antidote, green toxic smoke fading behind",
        "ornate corked glass flask of golden antidote bound with leather "
        "straps, a dead green serpent coiled at its base, front view",
        "bone white amulet of a serpent biting its own tail around a small "
        "amber crystal vial, faint green fumes dispersing",
    ],
    "counter_salamander": [
        "rust orange salamander coiled around a black iron amulet, scales "
        "glowing like embers, unharmed inside small flames, front view",
        "hooded fire walker bust wearing a cloak of salamander scales, flames "
        "licking the cloak without burning it, calm stern face",
        "large burnt sienna dragon scale shield charm with a salamander "
        "engraved on it, small flames sliding off its surface",
    ],
    "counter_weak": [
        "bronze bull head talisman with great curved horns and glowing red "
        "eyes on a leather cord, front view",
        "muscular horned bull warrior bust with a bronze nose ring, snorting "
        "steam, fierce eyes, front view",
        "aged gold armband engraved with a charging bull, clenched fist "
        "raised through it, front view",
    ],
    "counter_frail": [
        "ancient tortoise shell shield charm with iron rim and engraved "
        "runes, unbroken and heavy, front view",
        "old armored tortoise head peeking from a heavy spiked iron shell, "
        "calm wise eyes, front view",
        "stern knight bust holding a round shield made from a tortoise shell, "
        "cracks sealed with gold, front view",
    ],
    "counter_vulnerable": [
        "grey stone face carving with closed eyes, skin of granite, a crack "
        "sealed with aged gold, front view",
        "stone gargoyle bust with arms crossed, granite skin, an arrow "
        "broken against its chest, front view",
        "warrior bust whose skin turns to grey stone from the chest up, "
        "an arrow shattering on the stone shoulder, stern face",
    ],
    "counter_whetstone": [
        "grim old weaponsmith bust drawing a long sword blade across a grey "
        "whetstone, bright sparks flying, scarred face lit by the sparks",
        "grey whetstone block bound in iron bands with a dagger blade resting "
        "on it, sparks flying from the edge, front view",
        "armored gauntlet gripping a glowing sharpened spearhead that pierces "
        "through a cracked round shield, sparks, front view",
    ],
}


def load():
    return json.load(open(JOBS)) if os.path.exists(JOBS) else {}


def save(j):
    os.makedirs(OUT, exist_ok=True)
    json.dump(j, open(JOBS, "w"), indent=2)


def pending(jobs):
    return [k for k, j in jobs.items() if isinstance(j, dict)
            and not os.path.exists(os.path.join(OUT, k + ".png"))]


def submit(key, subj):
    t = N.call("create_map_object", {
        "description": subj + STYLE, "width": 64, "height": 64,
        "view": "side", "outline": "single color outline",
        "shading": "detailed shading", "detail": "high detail"})
    m = re.search(r"id:\s*([0-9a-f-]{36})", t)
    if not m:
        print("[gen] sem id:", t[:200], flush=True)
        return None
    return m.group(1)


def fetch_once():
    jobs = load()
    for key in pending(jobs):
        j = jobs[key]
        t = N.call("get_map_object", {"object_id": j["object_id"]})
        if "completed" not in t.lower():
            continue
        url = f"https://api.pixellab.ai/mcp/map-objects/{j['object_id']}/download"
        try:
            data = N.F.fetch(url)
        except Exception as e:
            print(f"[fetch] {key}: {e}", flush=True)
            continue
        open(os.path.join(OUT, key + ".png"), "wb").write(data)
        print(f"[fetch] {key} ok", flush=True)


def run(only=None, maxpar=3):
    queue = []
    for icon, subs in SUBJECTS.items():
        if only and icon not in only:
            continue
        for k, subj in enumerate(subs):
            queue.append((f"{icon}_{k}", subj))
    while True:
        jobs = load()
        todo = [(k, s) for k, s in queue if k not in jobs]
        busy = pending(jobs)
        if not todo and not busy:
            break
        while todo and len(busy) < maxpar:
            k, s = todo.pop(0)
            oid = submit(k, s)
            if oid:
                jobs = load()
                jobs[k] = {"object_id": oid, "subject": s}
                save(jobs)
                busy.append(k)
                print(f"[gen] {k} -> {oid}", flush=True)
            time.sleep(2)
        time.sleep(20)
        fetch_once()
    print("[done]", flush=True)


def contact(icon=None):
    from PIL import Image, ImageDraw
    pat = re.escape(icon) if icon else r"counter_[a-z]+"
    fs = sorted(f for f in os.listdir(OUT) if re.match(pat + r"_\d+\.png$", f))
    ims = [Image.open(os.path.join(OUT, f)).convert("RGBA") for f in fs]
    S = 3
    cols = 3
    rows = (len(ims) + cols - 1) // cols
    sh = Image.new("RGBA", (cols * (64 * S + 8), rows * (64 * S + 14)), (70, 58, 44, 255))
    d = ImageDraw.Draw(sh)
    for k, im in enumerate(ims):
        x, y = (k % cols) * (64 * S + 8), (k // cols) * (64 * S + 14)
        b = im.resize((64 * S, 64 * S), Image.NEAREST)
        sh.paste(b, (x, y), b)
        d.text((x + 2, y + 64 * S + 1), fs[k], fill=(255, 255, 200))
    p = os.path.join(OUT, (icon or "todas") + "_contact.png")
    sh.save(p)
    print(p)


def pick(icon, k):
    import shutil
    shutil.copy(os.path.join(OUT, f"{icon}_{k}.png"), os.path.join(ICONS, icon + ".png"))
    jobs = load()
    jobs["picked_" + icon] = jobs[f"{icon}_{k}"]["object_id"]
    save(jobs)
    print(f"[pick] {icon} <- {icon}_{k} (object {jobs['picked_' + icon]})")


if __name__ == "__main__":
    c, a = sys.argv[1], sys.argv[2:]
    {"run": lambda: run(a or None), "fetch": fetch_once,
     "contact": lambda: contact(a[0] if a else None),
     "pick": lambda: pick(a[0], a[1])}[c]()
