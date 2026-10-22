#!/usr/bin/env python3
import base64
import hashlib
import io
import json
import os
import re
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixellab_enemy_anims as F

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ENEMIES = os.path.join(ROOT, "assets/sprites/characters/enemies")
WORLD = os.path.join(ROOT, "assets/sprites/world")
ANCHOR_DIR = os.path.join(WORLD, "anchors")
OUT = os.path.join(ROOT, "tools/preview_out/entradas_arte")
RAW = os.path.join(OUT, "raw_b")
JOBS = os.path.join(OUT, "jobs_b.json")
ANIM_TOOL = "animate_image"
ANCHOR_TOOL = "create_image_pro"

KEEP = (" The creature keeps its exact design, palette, proportions and every "
        "piece of equipment in every frame; nothing new appears, background "
        "stays empty.")
END = " The final frame is exactly the original starting pose."

ACT_OF = {
    "frost_wight": 4, "frost_wolf": 4, "rime_shaman": 4, "glacier_knight": 4,
    "frost_troll": 4, "ice_wyrm": 4,
    "bog_ghoul": 5, "plague_toad": 5, "leech_horror": 5, "mire_hag": 5,
    "croc_warrior": 5, "spore_mother": 5,
    "dusk_shade": 6, "dusk_bat": 6, "grave_thrall": 6, "blood_duke": 6,
    "dullahan": 6, "fallen_angel": 6,
}

CLIPS = {
    "frost_wight/form": dict(frames=8, start="idle", action=(
        "Forming out of blowing snow: the tattered icy robes whip and swirl "
        "as if made of wind-driven snow, the skeletal body ripples and "
        "flickers, streaks of loose snow swirl around and into it, the "
        "frost-blue glow inside the hood pulses brighter, then the robes "
        "settle and go still as it solidifies. Feet stay in place, no walking.")),
    "frost_wolf/trot": dict(frames=8, start="idle", action=(
        "Trotting in place: a smooth four-legged trot cycle, legs moving in "
        "alternating diagonal pairs, body bobbing slightly, head held low and "
        "forward, icicles swinging from the jaw, frosty breath puffing, "
        "finishing back in the same standing snarl.")),
    "frost_wolf/howl": dict(frames=6, start="idle", action=(
        "Throwing its head up and howling: paws planted, the wolf lifts its "
        "muzzle straight up to the sky with jaws open, a long plume of frosty "
        "breath rising, chest swelling, then lowers its head back down into "
        "the same snarling stance.")),
    "rime_shaman/walk": dict(frames=8, start="idle", action=(
        "Walking forward in place: short hunched goblin steps, the white fur "
        "cloak swaying, the totem staff tapping the ground on every other "
        "step, the raised casting hand bobbing, the ice crystal flickering, "
        "finishing in the same standing pose.")),
    "glacier_knight/walk": dict(frames=8, start="idle", action=(
        "Heavy armored march in place: slow ponderous steps, each foot "
        "stomping down with weight, shoulders rocking side to side, the "
        "greatsword held low swaying with the stride, the icy flame wisps on "
        "the armor trailing, finishing in the same standing guard.")),
    "frost_troll/emerge": dict(frames=8, start="down:0.55", action=(
        "Bursting up out of a snow bank: the troll starts crouched low and "
        "buried, then heaves upward, head and shoulders rising first with "
        "snow flying off its white fur and ice shards, long arms pushing up, "
        "it rises to full height and settles with both fists resting on the "
        "ground in the same hunched stance.")),
    "ice_wyrm/emerge": dict(frames=8, start="down:0.8", action=(
        "Erupting from under the snow: the wyrm rises straight up out of the "
        "ground, horned head first with jaws open breathing frost, then the "
        "neck and the spiked coils surge up, snow and ice chips scattering, "
        "the coils settling on the ground into the same coiled pose.")),
    "bog_ghoul/emerge": dict(frames=8, start="down:0.9", action=(
        "Crawling up out of the mud: one long clawed arm reaches up and claws "
        "at the ground first, then the head with glowing sunken eyes, then "
        "the hunched rotting body drags itself up out of the ground, mud "
        "dripping off, straightening into the same hunched standing pose.")),
    "plague_toad/hop": dict(frames=8, start="idle", action=(
        "Hopping: the bloated toad squats down compressing its body, springs "
        "up with hind legs extended and front legs tucked, arcs through the "
        "air, lands with a heavy squash, belly wobbling, slime splashing from "
        "its mouth, then settles back into the same squat.")),
    "leech_horror/emerge": dict(frames=8, start="down:0.9", action=(
        "Surging up out of a puddle: the fused leech mass bulges and pushes "
        "upward out of the ground, leeches writhing and slithering over each "
        "other as the torso rises, sucker mouths opening, the arms pulling "
        "free dripping mud, settling into the same hunched stance.")),
    "mire_hag/walk": dict(frames=8, start="idle", action=(
        "Walking forward in place with a sly creeping gait: small steps, the "
        "green cloak swaying, the wide hat brim bobbing, hands empty, "
        "shoulders rolling, finishing in the same standing pose.")),
    "croc_warrior/crawl": dict(frames=8, start="idle", action=(
        "Low stalking crawl in place: the crocodile warrior drops into a deep "
        "crouch, knees bent, dragging itself forward with a heavy reptilian "
        "gait, the long tail sweeping side to side, spear held low and the "
        "turtle shield forward, then rises back up into the same upright "
        "stance.")),
    "spore_mother/emerge": dict(frames=8, start="down:0.6", action=(
        "Unfolding and rising from the ground: the fungal matriarch starts "
        "squashed low, then rises upward, the huge mushroom cap lifting and "
        "spreading open wide, a puff of green spores drifting from the gills, "
        "root legs straightening, mossy arms unfolding, settling into the "
        "same standing pose.")),
    "dusk_shade/form": dict(frames=8, start="idle", action=(
        "Condensing from shadow: the hooded shade flickers and wavers like "
        "smoke, the purple flames around it flare and stretch upward then "
        "shrink back, the robe tatters sway, it stabilizes and goes still in "
        "the same hovering pose. No walking.")),
    "dusk_bat/swoop": dict(frames=8, start="idle", action=(
        "Flapping and swooping: big wing beats sweeping down and up through "
        "the full stroke, body tilting forward into a dive, then rearing back "
        "to brake with wings flared wide and ears back, then settling into "
        "the same hovering pose with wings spread.")),
    "grave_thrall/emerge": dict(frames=8, start="down:0.9", action=(
        "Climbing out of a grave: a skeletal hand holding the sword claws up "
        "through the ground first, then the skull and the rusted tower shield "
        "push up, the armored skeleton hauls itself up out of the ground with "
        "dirt falling off, and straightens into the same standing guard.")),
    "blood_duke/form": dict(frames=8, start="idle", action=(
        "Appearing with a cape flourish: the cape swirls wide and billows "
        "around him, he turns slightly with one arm sweeping across his face "
        "as the cape wraps him, then flings the cape open and back, stands "
        "tall and settles into the same pose with the red eyes glowing.")),
    "dullahan/walk": dict(frames=8, start="idle", action=(
        "Walking forward in place with a heavy knightly stride: armored "
        "steps, the cape swinging, the held helmeted head lifted slightly as "
        "its violet eyes flare and the flame on the neck leaps, the curved "
        "blade swaying low, finishing in the same standing pose.")),
    "fallen_angel/descend": dict(frames=8, start="idle", action=(
        "Descending in flight: the huge black wings beat in slow powerful "
        "strokes, sweeping up high then down, loose black feathers drifting "
        "away, the body straight and the sword held point-down, finishing "
        "with the wings spread wide in the same standing pose.")),
    "fallen_angel/land": dict(frames=6, start="idle", action=(
        "Landing: the wings flare up and wide to brake, the knees bend softly "
        "as the feet take the weight, a few feathers fall, then the body "
        "straightens and the wings settle back into the same spread pose.")),
}

V2 = {
    "frost_wight/form": dict(pin=True, action=(
        "Materializing: the whole figure fades between translucent and solid, "
        "flickering like a ghost, the tattered robe hems ripple and lift as if "
        "in a cold wind, the body sways slightly side to side, the hood glow "
        "pulses, then it steadies and goes still. No snow, no particles, no "
        "streaks, no splash, feet never move.")),
    "frost_wolf/howl": dict(pin=True, action=(
        "Howling: the wolf plants its paws, raises its head and points its "
        "muzzle straight up at the sky with the jaws wide open, neck "
        "stretched, chest lifted, holds the howl, then lowers its head back "
        "down into the snarl. No breath cloud, no vapor, no smoke, nothing "
        "comes out of the mouth.")),
    "rime_shaman/walk": dict(pin=False, action=(
        "Walking cycle in place, exaggerated: the goblin takes clear high "
        "steps, left leg lifting with the knee bent then planting, then the "
        "right leg, the whole body bobbing up and down with each step, the "
        "fur cloak swinging, the staff planting on the ground with each "
        "stride, the raised hand pumping.")),
    "glacier_knight/walk": dict(pin=False, action=(
        "Heavy walking cycle in place, exaggerated: the knight lifts one "
        "armored leg high and stomps it down, then the other, the whole body "
        "rising and dropping with each stomp, shoulders swinging, the "
        "greatsword tip swinging left and right with the stride.")),
    "plague_toad/hop": dict(pin=False, action=(
        "Jumping: the toad crouches and squashes flat, then LEAPS high into "
        "the air with all four legs stretched out and the body clearly off "
        "the ground, rises to the top of the frame, falls back down and "
        "lands with a heavy squash, belly flattening and rippling, then "
        "settles into the squat.")),
    "mire_hag/walk": dict(pin=False, action=(
        "Walking cycle in place, exaggerated: the witch takes clear steps, "
        "one boot lifting and planting then the other, hips swaying, the "
        "whole body bobbing up and down, the green cloak swinging wide, the "
        "hat brim bouncing with each step, hands swinging at her sides.")),
    "croc_warrior/crawl": dict(pin=False, action=(
        "Prowling cycle in place: the crocodile warrior crouches low with "
        "knees deeply bent, body leaning forward, and takes slow heavy "
        "stalking steps, one clawed foot lifting and planting then the "
        "other, the tail swinging side to side, keeping the spear upright "
        "and the shield steady on its arm.")),
    "dullahan/walk": dict(pin=False, action=(
        "Walking cycle in place, exaggerated: the headless knight takes "
        "clear armored steps, one leg lifting and planting then the other, "
        "the body bobbing up and down, the cape swinging behind, the held "
        "helmet lifting slightly with each stride, the curved blade swinging "
        "low, the neck flame leaning back.")),
    "fallen_angel/land": dict(pin=True, action=(
        "Landing hard: both huge wings sweep forward and up high above the "
        "head to brake, the body drops and the knees bend deeply as the feet "
        "hit the ground, then the body straightens and the wings sweep back "
        "down and settle into the spread pose.")),
}

V3 = {
    "plague_toad/hop": dict(pin=True, action=(
        "Leaping hop, exaggerated squash and stretch: frame by frame the toad "
        "first squashes down wide and flat, then STRETCHES tall and narrow "
        "with the hind legs fully extended straight down and the front legs "
        "tucked up, the whole body lifted to the top of the frame with empty "
        "space under its feet, then falls, lands and squashes flat and wide "
        "again, then recovers to the squat.")),
}

DIORAMA = (" Treat it as a small pixel art diorama, not a flat texture: every mass has thickness "
           "with a lit face and a shadow face, parts in front overlap the parts behind, small "
           "irregular dotted shadows fall from upper parts onto lower parts, the front has a crisp "
           "outline and strong contrast, parts behind are darker and softer.")
SOLO = (" Single isolated ground prop only, transparent background, no creature, no figure, no "
        "landscape, nothing cut off at the edges. Same hand-drawn pixel art style, palette and "
        "pixel scale as the reference, crisp 1 px dark outline, limited palette, flat clustered "
        "shading, no smooth gradients, no anti-aliasing, no vector shapes. Side view from slightly "
        "above, straight front perspective, wider than tall, the base sits flat on an invisible floor.")
LIGHT = {
    "frost": " Cold white winter sun comes from the upper RIGHT: lit faces on the right and on top, shadow faces on the left and underneath.",
    "marsh": " Pale sickly moonlight comes from the upper RIGHT: lit faces on the right and on top, shadow faces on the left and underneath.",
    "dusk": " Low golden evening sun comes from the upper LEFT: lit faces on the left and on top, shadow faces on the right and underneath.",
}

ANCHORS = {
    "frost_troll": dict(biome="frost", w=120, h=64, refs=["frost_drift_0", "frost_rock_0"], desc=(
        "a big rounded snow bank on a frozen road, a deep drift of packed white snow with a few "
        "windblown ridges, blue shadowed hollows, a rim of crusted ice chunks and two small dark "
        "rocks poking out at its foot, big enough to hide a crouching giant")),
    "ice_wyrm": dict(biome="frost", w=112, h=40, refs=["frost_drift_1", "frost_rock_0"], desc=(
        "a long low hump of snow on a frozen road, as if something huge is moving underneath: the "
        "snow surface bulged up and cracked in jagged lines, pale blue ice showing in the cracks, "
        "small ice chips tumbling down the sides, low and wide")),
    "bog_ghoul": dict(biome="marsh", w=104, h=40, refs=["marsh_rock_0", "marsh_roots_0"], desc=(
        "a patch of dark wet swamp mud on a road, oval and low, glossy brown-black sludge with "
        "several round gas bubbles rising and bursting, a few bits of rotten reed and bone sticking "
        "out of the mud, slick wet highlights")),
    "leech_horror": dict(biome="marsh", w=104, h=36, refs=["marsh_rock_0", "marsh_reeds_0"], desc=(
        "a dark murky puddle of swamp water on a road, oval and very low, ringed with wet mud and a "
        "few tufts of marsh grass, the water surface dark olive with ripple rings and a dull moon "
        "highlight, something lurking beneath hinted by a faint shape")),
    "spore_mother": dict(biome="marsh", w=128, h=80, refs=["marsh_mushroom_0", "marsh_stump_0"], desc=(
        "a dense cluster of huge swamp mushrooms grown together into a mound, rotten-red spotted "
        "caps of different sizes overlapping, thick pale stalks, glowing green spores dripping from "
        "the gills, moss and small toadstools around the base, big enough to hide a creature inside")),
    "grave_thrall": dict(biome="dusk", w=104, h=40, refs=["dusk_rock_0", "dusk_leaves_0"], desc=(
        "a disturbed grave on a dusk heath road: a low mound of freshly turned dark earth, loose "
        "clods and cracks across the top as if something is pushing from below, a tilted cracked "
        "grey headstone at the back, a few dry golden grass tufts and fallen red leaves at the edges")),
    "dusk_shade": dict(biome="dusk", w=96, h=32, refs=["dusk_rock_0", "dusk_leaves_0"], desc=(
        "a pool of living shadow on a road at dusk: an oval of deep violet-black darkness lying flat "
        "on the ground, its edges ragged and wispy with thin tendrils of purple smoke curling up, "
        "a faint purple glow inside, very low and wide")),
}


def jobs():
    return json.load(open(JOBS)) if os.path.exists(JOBS) else {}


def save_jobs(j):
    os.makedirs(OUT, exist_ok=True)
    json.dump(j, open(JOBS, "w"), indent=1)


def idle_path(eid):
    return os.path.join(ENEMIES, eid, "animations/idle/south/0.png")


def clip_dir(eid, clip):
    return os.path.join(ENEMIES, eid, "animations", clip, "south")


def b64_of(path):
    return base64.b64encode(open(path, "rb").read()).decode()


def img_b64(im):
    buf = io.BytesIO()
    im.save(buf, format="PNG")
    return base64.b64encode(buf.getvalue()).decode()


def start_frame(eid, start):
    from PIL import Image
    idle = Image.open(idle_path(eid)).convert("RGBA")
    if start == "idle":
        return idle
    kind, frac = start.split(":")
    bb = idle.getbbox()
    content_h = bb[3] - bb[1]
    dy = int(round(content_h * float(frac)))
    out = Image.new("RGBA", idle.size, (0, 0, 0, 0))
    if kind == "down":
        out.alpha_composite(idle, (0, dy))
    else:
        out.alpha_composite(idle.crop((0, dy, idle.width, idle.height)), (0, 0))
    return out


def attempt_dir(key, att):
    return os.path.join(RAW, key.replace("/", "_"), str(att))


def next_attempt(key):
    d = os.path.join(RAW, key.replace("/", "_"))
    if not os.path.isdir(d):
        return 1
    n = [int(x) for x in os.listdir(d) if x.isdigit()]
    return (max(n) + 1) if n else 1


def call(tool, args, timeout=300):
    return F.tool_text(F.rpc("tools/call", {"name": tool, "arguments": args}, timeout=timeout))


def job_id_of(text):
    m = re.search(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", text)
    return m.group(0) if m else None


def queue(keys, seed=None, variant=None):
    J = jobs()
    submitted = []
    for key in keys:
        spec = CLIPS[key]
        alt = variant.get(key) if variant else None
        eid = key.split("/")[0]
        first = start_frame(eid, spec["start"])
        pin = alt.get("pin", True) if alt else True
        args = {
            "action": (alt["action"] if alt else spec["action"]) + KEEP + (END if pin else ""),
            "first_frame_base64": img_b64(first),
            "frame_count": spec["frames"],
        }
        if pin:
            args["last_frame_base64"] = b64_of(idle_path(eid))
        if seed is not None:
            args["seed"] = seed
        text = call(ANIM_TOOL, args)
        jid = job_id_of(text)
        if not jid:
            if "rate limit" in text.lower():
                print(f"[cheio] {key}: fila da conta lotada", flush=True)
                break
            print(f"[FAIL] {key}: sem job id: {text[:300]}", flush=True)
            continue
        att = next_attempt(key)
        os.makedirs(attempt_dir(key, att), exist_ok=True)
        J[f"{key}#{att}"] = {"key": key, "attempt": att, "job": jid, "seed": seed,
                             "variant": "v2" if alt else "v1", "pin": pin,
                             "status": "queued", "t": time.time()}
        save_jobs(J)
        submitted.append(key)
        print(f"[queue] {key}#{att} job {jid}", flush=True)
        time.sleep(2)
    return submitted


def run(keys, seed=None, variant=None):
    todo = list(keys)
    while todo:
        done = queue(todo, seed, variant)
        todo = [k for k in todo if k not in done]
        if todo:
            time.sleep(30)
            poll()
    poll(loop=True)


def queue_anchor(ids, seed=None):
    from PIL import Image
    J = jobs()
    for aid in ids:
        a = ANCHORS[aid]
        tiles = [Image.open(os.path.join(WORLD, r + ".png")).convert("RGBA") for r in a["refs"]]
        tiles.append(Image.open(idle_path(aid)).convert("RGBA"))
        H = max(t.height for t in tiles)
        W = sum(t.width + 4 for t in tiles)
        ref = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        x = 0
        for t in tiles:
            ref.alpha_composite(t, (x, H - t.height))
            x += t.width + 4
        args = {
            "description": a["desc"] + DIORAMA + LIGHT[a["biome"]] + SOLO,
            "width": a["w"], "height": a["h"], "no_background": True,
            "style_image_base64": img_b64(ref),
            "style_copy": ["color_palette", "outline", "detail", "shading"],
        }
        if seed is not None:
            args["seed"] = seed
        text = call(ANCHOR_TOOL, args)
        jid = job_id_of(text)
        key = f"anchor/{aid}"
        if not jid:
            print(f"[FAIL] {key}: {text[:300]}", flush=True)
            continue
        att = next_attempt(key)
        os.makedirs(attempt_dir(key, att), exist_ok=True)
        J[f"{key}#{att}"] = {"key": key, "attempt": att, "job": jid, "seed": seed,
                             "status": "queued", "t": time.time()}
        save_jobs(J)
        print(f"[queue] {key}#{att} job {jid}", flush=True)
        time.sleep(2)


def poll(loop=False):
    while True:
        J = jobs()
        pending = [k for k, j in J.items() if j["status"] == "queued"]
        for k in pending:
            j = J[k]
            try:
                text = call("get_image", {"job_id": j["job"]})
            except Exception as e:
                print(f"[wait] {k}: {e}", flush=True)
                continue
            low = text.lower()
            if "status: failed" in low or "status: error" in low:
                j["status"] = "failed"
                j["error"] = text[:300]
                print(f"[FAIL] {k}: {text[:200]}", flush=True)
            elif "status: completed" in low:
                mN = re.search(r"frames:\s*(\d+)", text)
                mURL = re.search(r"(https?://\S+/download)\?index=\d+", text)
                if not (mN and mURL):
                    j["status"] = "failed"
                    j["error"] = "sem urls"
                    print(f"[FAIL] {k}: completo sem urls: {text[:200]}", flush=True)
                else:
                    n, base = int(mN.group(1)), mURL.group(1)
                    d = attempt_dir(j["key"], j["attempt"])
                    os.makedirs(d, exist_ok=True)
                    for i in range(n):
                        open(os.path.join(d, f"{i}.png"), "wb").write(F.fetch(f"{base}?index={i}"))
                    j["status"] = "downloaded"
                    j["n"] = n
                    print(f"[ok] {k}: {n} quadros", flush=True)
            else:
                print(f"[wait] {k}", flush=True)
            save_jobs(J)
        if not loop or not [k for k, j in J.items() if j["status"] == "queued"]:
            break
        time.sleep(20)


def frames_of(key, att):
    from PIL import Image
    d = attempt_dir(key, att)
    fs = sorted([f for f in os.listdir(d) if re.match(r"^\d+\.png$", f)], key=lambda f: int(f[:-4]))
    return [Image.open(os.path.join(d, f)).convert("RGBA") for f in fs]


def diff(a, b):
    import numpy as np
    A = np.array(a).astype(int)
    B = np.array(b).astype(int)
    mask = (A[:, :, 3] > 0) | (B[:, :, 3] > 0)
    if not mask.any():
        return 0.0
    dd = np.abs(A - B)[:, :, :3].sum(axis=2) / 3.0
    return float(dd[mask].mean())


def measure(key, att):
    from PIL import Image
    eid = key.split("/")[0]
    idle = Image.open(idle_path(eid)).convert("RGBA")
    fr = frames_of(key, att)
    hashes = {hashlib.md5(f.tobytes()).hexdigest() for f in fr}
    steps = [diff(fr[i], fr[i + 1]) for i in range(len(fr) - 1)]
    return {
        "n": len(fr),
        "dead": len(hashes) <= 2,
        "drift_last": round(diff(fr[-1], idle), 1),
        "drift_prev": round(diff(fr[-2], idle), 1) if len(fr) > 1 else 0,
        "motion": round(sum(steps) / max(1, len(steps)), 1),
        "max_step": round(max(steps), 1) if steps else 0,
    }


def strip(keys):
    from PIL import Image, ImageDraw
    K = 4
    for key in keys:
        eid, clip = key.split("/")
        idle = Image.open(idle_path(eid)).convert("RGBA")
        atts = [j for j in jobs().values() if j["key"] == key and j["status"] in ("downloaded", "installed")]
        if not atts:
            continue
        rows = []
        for j in sorted(atts, key=lambda x: x["attempt"]):
            fr = frames_of(key, j["attempt"])
            m = measure(key, j["attempt"])
            rows.append((f"#{j['attempt']} {m}", [idle] + fr))
        cw = idle.width * K + 6
        ch = idle.height * K + 18
        W = cw * max(len(r[1]) for r in rows) + 12
        H = ch * len(rows) + 12
        out = Image.new("RGBA", (W, H), (70, 74, 66, 255))
        d = ImageDraw.Draw(out)
        for ri, (label, fr) in enumerate(rows):
            y = 12 + ri * ch
            d.text((8, y - 10), label, fill=(255, 250, 230, 255))
            for i, f in enumerate(fr):
                big = f.resize((f.width * K, f.height * K), Image.NEAREST)
                out.alpha_composite(big, (8 + i * cw, y + 8))
                d.text((8 + i * cw, y + 8 + big.height - 12), "idle" if i == 0 else str(i - 1), fill=(255, 220, 120, 255))
        p = os.path.join(OUT, f"ato{ACT_OF[eid]}", f"{eid}_{clip}.png")
        os.makedirs(os.path.dirname(p), exist_ok=True)
        out.save(p)
        print(p, flush=True)


def install(key, att, drop_first=True):
    from PIL import Image
    eid, clip = key.split("/")
    idle = Image.open(idle_path(eid)).convert("RGBA")
    fr = frames_of(key, att)
    gen = fr[1:] if drop_first else fr
    gen = gen[:-1] + [idle]
    d = clip_dir(eid, clip)
    os.makedirs(d, exist_ok=True)
    for f in os.listdir(d):
        if f.endswith(".png"):
            os.remove(os.path.join(d, f))
    for i, f in enumerate(gen):
        assert f.size == idle.size, (key, f.size, idle.size)
        f.save(os.path.join(d, f"{i}.png"))
    J = jobs()
    for k, j in J.items():
        if j["key"] == key:
            j["status"] = "installed" if j["attempt"] == att else ("downloaded" if j["status"] == "installed" else j["status"])
    save_jobs(J)
    print(f"[install] {key} <- #{att}: {len(gen)} quadros em {d}", flush=True)


def hard_alpha(im):
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            c = px[x, y]
            px[x, y] = (c[0], c[1], c[2], 255 if c[3] >= 128 else 0)
    return im


def anchor_sheet(aid):
    from PIL import Image, ImageDraw
    K = 3
    key = f"anchor/{aid}"
    atts = [j for j in jobs().values() if j["key"] == key and j["status"] in ("downloaded", "installed")]
    idle = Image.open(idle_path(aid)).convert("RGBA")
    tiles = [("creature", idle)]
    for j in sorted(atts, key=lambda x: x["attempt"]):
        d = attempt_dir(key, j["attempt"])
        for f in sorted(os.listdir(d)):
            if f.endswith(".png"):
                im = hard_alpha(Image.open(os.path.join(d, f)).convert("RGBA"))
                tiles.append((f"#{j['attempt']}/{f[:-4]}", im))
    H = max(t.height for _, t in tiles) * K + 20
    W = sum(t.width * K + 12 for _, t in tiles) + 12
    out = Image.new("RGBA", (W, H * 2 + 8), (70, 74, 66, 255))
    d = ImageDraw.Draw(out)
    x = 12
    for label, t in tiles:
        big = t.resize((t.width * K, t.height * K), Image.NEAREST)
        out.alpha_composite(big, (x, H - big.height))
        out.alpha_composite(t, (x, H * 2 - t.height))
        d.text((x, 2), label, fill=(255, 250, 230, 255))
        x += big.width + 12
    p = os.path.join(OUT, f"ato{ACT_OF[aid]}", f"anchor_{aid}.png")
    os.makedirs(os.path.dirname(p), exist_ok=True)
    out.save(p)
    print(p, flush=True)


def install_anchor(aid, att, idx):
    from PIL import Image
    key = f"anchor/{aid}"
    src = os.path.join(attempt_dir(key, att), f"{idx}.png")
    im = hard_alpha(Image.open(src).convert("RGBA"))
    bb = im.getbbox()
    im = im.crop(bb)
    os.makedirs(ANCHOR_DIR, exist_ok=True)
    p = os.path.join(ANCHOR_DIR, f"{aid}_anchor.png")
    im.save(p)
    print(f"[install] {p} {im.size}", flush=True)


def status():
    J = jobs()
    for k, j in sorted(J.items()):
        print(f"  {k:<32} {j['status']}")
    done = {j["key"] for j in J.values() if j["status"] == "installed"}
    print("[faltam]", [k for k in CLIPS if k not in done])
    print("[gerações]", len(J))


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    rest = sys.argv[2:]
    seed = None
    if rest and rest[0].startswith("seed="):
        seed = int(rest[0][5:])
        rest = rest[1:]
    if cmd == "queue":
        queue(rest or list(CLIPS), seed)
    elif cmd == "run":
        have = {j["key"] for j in jobs().values() if j["status"] != "failed"}
        run(rest or [k for k in CLIPS if k not in have], seed)
    elif cmd == "run2":
        run(rest or list(V2), seed, V2)
    elif cmd == "run3":
        run(rest or list(V3), seed, V3)
    elif cmd == "queue_act":
        queue([k for k in CLIPS if ACT_OF[k.split("/")[0]] == int(rest[0])], seed)
    elif cmd == "anchors":
        queue_anchor(rest or list(ANCHORS), seed)
    elif cmd == "poll":
        poll(loop=bool(rest and rest[0] == "loop"))
    elif cmd == "strip":
        strip(rest or list(CLIPS))
    elif cmd == "install":
        install(rest[0], int(rest[1]))
    elif cmd == "anchor_sheet":
        for a in (rest or list(ANCHORS)):
            anchor_sheet(a)
    elif cmd == "install_anchor":
        install_anchor(rest[0], int(rest[1]), int(rest[2]))
    elif cmd == "measure":
        print(measure(rest[0], int(rest[1])))
    else:
        status()
