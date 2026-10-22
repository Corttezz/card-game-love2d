#!/usr/bin/env python3
"""
tools/pixellab_entradas.py: clipes de ENTRADA dos inimigos (roteiro em
docs/superpowers/specs/2026-10-22-entradas-inimigos-design.md) via PixelLab
`animate_image` (v3), uma ferramenta por familia, e as ANCORAS de cenario via
`create_image_pro` (PNG da criatura + marco do bioma como referencia).

Quadro 0 = idle real (ou um quadro DERIVADO do idle: afundado no chao,
silhueta escura, estatua cinza, pilha de pedras da morte) e o ultimo quadro e
PINADO no idle 0 (`last_frame_base64`), entao todo clipe termina onde o idle
continua. Tripwires: anim morta, fim que nao casa com o idle (forca o idle 0
no ultimo quadro se o desvio for pequeno; senao regera com outra semente).

  python tools/pixellab_entradas.py run [ato|id ...]     # fabrica serial (1 job por vez)
  python tools/pixellab_entradas.py retry <id>/<clip>    # mais uma tentativa
  python tools/pixellab_entradas.py strips [ato|id ...]  # tiras 4x em tools/preview_out/entradas_arte/atoN/
  python tools/pixellab_entradas.py anchors queue|poll|sheet|install <nome>=<idx> ...
  python tools/pixellab_entradas.py derived              # so grava os quadros derivados (conferir)
  python tools/pixellab_entradas.py status
"""
import base64
import hashlib
import json
import os
import re
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixellab_enemy_anims as F  # noqa: E402

from PIL import Image  # noqa: E402

ROOT = F.ROOT
OUT = os.path.join(ROOT, "tools/preview_out/entradas_arte")
JOBS_FILE = os.path.join(OUT, "jobs.json")
ANCHOR_JOBS = os.path.join(OUT, "anchor_jobs.json")
ANCHOR_RAW = os.path.join(OUT, "anchors_raw")
ANCHOR_DIR = os.path.join(ROOT, "assets/sprites/world/anchors")
WORLD = os.path.join(ROOT, "assets/sprites/world")
MAX_TRIES = 3

ACTS = {
    1: ["cursed_scarecrow", "hollow_farmer", "plague_rats", "harvest_reaper",
        "blight_bull", "wicker_effigy"],
    2: ["moon_gargoyle", "ram_cultist", "storm_harpy", "rune_golem",
        "spectral_knight", "storm_griffin"],
    3: ["ember_imp", "hellhound", "abyss_acolyte", "obsidian_sentinel",
        "pit_brute", "abyss_watcher"],
}

SUFFIX = (" Palette, colors, proportions, face and every piece of clothing "
          "and equipment stay unchanged in every frame. Nothing new appears, "
          "background stays empty and transparent.")

CLIPS = {
    "cursed_scarecrow": {
        "awaken": dict(frames=8, first="idle", end="idle", action=(
            "hangs completely limp and motionless like a real scarecrow on "
            "its pole for the first two frames, then jolts alive: the whole "
            "body shudders violently, head snaps up, ember eyes flare, claw "
            "arms jerk and flail, loose straw bursts out of the collar and "
            "shoulders, it tears itself free and lurches forward with one "
            "small hop, then settles into its standing stance")),
    },
    "hollow_farmer": {
        "walk": dict(frames=8, first="idle", end="idle", action=(
            "walks slowly toward the viewer with a stiff limping shuffle, "
            "one leg dragging, the pitchfork dragged along the ground beside "
            "it, hat brim bobbing, two full steps, then stops and plants the "
            "pitchfork upright with a thud, settling into its hunched "
            "stance")),
    },
    "plague_rats": {
        "form": dict(frames=8, first="rats_bottom", end="idle", action=(
            "more plague rats crawl in from the left and right sides along "
            "the ground and climb up onto the backs of the rats at the "
            "bottom, scrambling over each other, tails whipping, until the "
            "full heap of rats is stacked up, then the pile settles still; "
            "every rat always touches the ground or another rat, nothing "
            "floats in the air, nothing drops from above")),
    },
    "harvest_reaper": {
        "form": dict(frames=8, first="mist", end="idle", action=(
            "materialises slowly out of a dark shapeless mist: the black "
            "shadow brightens a little more in EVERY frame, steadily and "
            "gradually from the first frame to the last, never getting "
            "darker again, the hood, wheat straw shoulders and the long "
            "scythe resolving with color returning from the center outward, "
            "the body perfectly still, ending fully solid in its standing "
            "stance")),
    },
    "blight_bull": {
        "charge": dict(frames=8, first="idle", end="idle", action=(
            "gallops straight toward the viewer at full speed, head lowered "
            "with the horns forward, hooves pounding in a running cycle, "
            "wheat stalks and steam streaming, then skids to a hard stop, "
            "front hooves braced, head tossing up with a snort, settling "
            "into its standing stance")),
    },
    "wicker_effigy": {
        "awaken": dict(frames=8, first="unlit", end="idle", action=(
            "the dark unlit wicker giant ignites from the inside: a single "
            "small ember glows in the woven chest, a small fire grows in "
            "the ribcage, then small flames catch on both shoulders and the "
            "skull eyes light up, the body straightens and the long arms "
            "spread slightly as it comes alive, then settles into its "
            "standing stance; the woven wicker body itself stays dark "
            "brown wood in every frame, it never glows, never turns yellow "
            "or bright, only the three small fires and the eyes give light")),
    },
    "moon_gargoyle": {
        "awaken": dict(frames=8, first="statue", end="idle", action=(
            "the grey stone statue slowly comes alive: thin cracks run "
            "across the stone, the eyes begin to glow violet, and the grey "
            "stone gradually gives way to its natural pale lavender-grey "
            "skin and dark purple wing membranes, a little more in every "
            "frame, the wings twitch and open, the body shifts on its "
            "haunches, then it settles into its crouched stance; the "
            "colours only move from grey toward the final colours, no "
            "flashing, no bright glow, no red, no cyan, never any colour "
            "other than grey, lavender and purple")),
    },
    "ram_cultist": {
        "walk": dict(frames=8, first="idle", end="idle", action=(
            "EXAGGERATED slow heavy walk toward the viewer: the whole body "
            "rocks far to the left then far to the right with each step "
            "like a lumbering monk, the ram skull head dipping low and "
            "rising high, the robe hem swinging wide and lifting to show a "
            "boot stepping forward, the censer swinging in a big arc on "
            "its chain, two full steps, then stops and raises its free "
            "hand open, settling into its standing stance")),
    },
    "storm_harpy": {
        "swoop": dict(frames=8, first="idle", end="idle", action=(
            "flying cycle: the huge wings beat in deep powerful strokes, "
            "sweeping up high and down low, the bird legs tucked up under "
            "the body, white hair and feathers streaming, claws forward, "
            "then the wings return to the wide open pose")),
        "land": dict(frames=6, first="idle", end="idle", action=(
            "drops onto the ground: the wings flare up wide to brake, the "
            "talons slam down, the body crouches low absorbing the landing, "
            "wings beating once, then it rises into its crouched stance "
            "with the wings open")),
    },
    "rune_golem": {
        "assemble": dict(frames=8, first="rubble", end="idle", action=(
            "the low heap of broken grey stones assembles itself SLOWLY "
            "over the whole clip, a few stones at a time: first only the "
            "two legs stack up while every other stone still lies on the "
            "ground, then the lower torso, then the chest and shoulders, "
            "then the massive fists, the head last; the runes stay dark "
            "grey the whole time and only glow faint purple in the final "
            "frame, never bright, never pink; settling into its standing "
            "stance")),
    },
    "spectral_knight": {
        "form": dict(frames=8, first="mist", end="idle", action=(
            "the ghostly knight solidifies out of dark mist: the faint dark "
            "shape grows brighter and more defined, armor plates, tower "
            "shield and the violet sword resolving with color, pale mist "
            "curling away, it takes one step forward and raises the sword, "
            "ending fully solid in its guard stance")),
    },
    "storm_griffin": {
        "swoop": dict(frames=8, first="idle", end="idle", action=(
            "flying cycle: the enormous wings beat in deep powerful strokes "
            "sweeping high and low, lightning sparks trailing from the "
            "feathers, the lion hind legs and tail tucked back, beak open, "
            "then the wings return to the raised pose")),
        "land": dict(frames=6, first="idle", end="idle", action=(
            "lands heavily: the wings flare high and wide to brake, the "
            "eagle talons slam onto the ground, the body crouches low "
            "absorbing the impact, feathers ruffling, then it rises into "
            "its standing stance with the wings raised")),
    },
    "ember_imp": {
        "emerge": dict(frames=8, first="sunk:30", end="idle", action=(
            "leaps up out of the ground: the imp pushes up and springs "
            "upward with its forelegs, body rising fully into view, flame "
            "mane and tail flame whipping, grinning wide, lands on all four "
            "paws and settles into its crouched stance")),
    },
    "hellhound": {
        "charge": dict(frames=8, first="idle", end="idle", action=(
            "bounds straight toward the viewer at full gallop, both heads "
            "low and snarling, flame manes streaming back, four legs in a "
            "running cycle, then skids to a hard stop with the claws digging "
            "in, both heads snapping up, settling into its standing stance")),
    },
    "abyss_acolyte": {
        "walk": dict(frames=8, first="idle", end="idle", action=(
            "glides forward toward the viewer in a slow ominous walk, robes "
            "and chains swaying, the burning grimoire held open, two full "
            "steps, then stops and lifts the grimoire higher with the flame "
            "flaring, settling into its standing stance")),
    },
    "obsidian_sentinel": {
        "awaken": dict(frames=8, first="unlit", end="idle", action=(
            "the dead black statue comes alive slowly: the dark seams on "
            "the armor warm from black to dull dark red and then to the "
            "orange glow, starting at the chest and spreading to the arms "
            "and legs a little more in every frame, the visor lights last, "
            "the armor shudders and it takes one heavy step forward, "
            "settling into its standing stance; the glow is only ever dull "
            "red or orange, never yellow, never white, no burst, no "
            "sparks, no flash, no star shape, the black armor stays black")),
    },
    "pit_brute": {
        "emerge": dict(frames=8, first="sunk:26", end="idle", action=(
            "climbs up out of a pit: both huge hands reach up and grab the "
            "edge, the horned head and shoulders rise, it heaves its massive "
            "body up and out, drags the sledgehammer up after it and plants "
            "the hammer head-down in front, settling into its standing "
            "stance with both hands on the handle")),
    },
    "abyss_watcher": {
        "form": dict(frames=8, first="dark", end="idle", action=(
            "the dark floating mass condenses into the watcher: the glowing "
            "orange eyes open one at a time, the central eye last, the "
            "curtain of tentacles unfurls downward, the bone crown and "
            "horns surface as color returns, ending fully formed in its "
            "floating pose")),
    },
}

ANCHORS = {
    "cursed_scarecrow": dict(w=56, h=116, biome="fields", desc=(
        "a weathered wooden scarecrow pole: a single tall rough-hewn post "
        "with a short crossbar near the top lashed with frayed rope, loose "
        "straw stuck in the rope, a few crow feathers caught on the "
        "crossbar, the base of the post planted in a small mound of dry "
        "earth with a few dead wheat stalks")),
    "harvest_reaper": dict(w=128, h=64, biome="fields", desc=(
        "a low shapeless bank of thick dark grey-black mist creeping on the "
        "ground, wispy ragged edges, slightly darker at the center, a few "
        "dry wheat straws poking out of it")),
    "moon_gargoyle": dict(w=120, h=56, biome="highlands", desc=(
        "a flat-topped grey-blue weathered boulder for a statue to perch on, "
        "wide and low, cracked mossy stone with a worn flat top, small "
        "rubble and a tuft of grass at the base, cold moonlit stone")),
    "ram_cultist": dict(w=136, h=44, biome="highlands", desc=(
        "ONLY glowing violet lines floating on a transparent background, no "
        "ground, no disc, no slab, no stone, no earth under them: a ritual "
        "rune circle seen in slight perspective as a wide flat ellipse, a "
        "double ring of thin glowing violet lines with small violet runes "
        "between the rings, a small bone and a candle stub at the near "
        "edge, the glow faint")),
    "abyss_acolyte": dict(w=136, h=44, biome="abyss", desc=(
        "ONLY glowing orange ember lines floating on a transparent "
        "background, no ground, no disc, no slab, no stone platform under "
        "them: an infernal sigil seen in slight perspective as a wide flat "
        "ellipse, a ring of thin glowing orange lines with jagged runes and "
        "a pentagram star inside, a few small embers at the edges")),
    "obsidian_sentinel": dict(w=128, h=48, biome="abyss", desc=(
        "ONE single wide low plinth seen straight from the front and "
        "slightly above, filling the whole canvas width: a flat slab "
        "pedestal of black obsidian two shallow steps high, straight "
        "horizontal front edges, the top face visible as a thin strip, "
        "thin glowing orange lava cracks along the edges, chipped corners, "
        "ash at the base; not isometric, not a cube, one object only")),
    "ember_imp": dict(w=136, h=48, biome="abyss", desc=(
        "a glowing lava crack in flat black volcanic ground seen in slight "
        "perspective: a long jagged fissure with bright orange-yellow molten "
        "glow inside, cooling dark crust at the edges, small embers rising, "
        "a few hot rocks around it")),
    "pit_brute": dict(w=140, h=60, biome="abyss", desc=(
        "a dark pit in black volcanic ground seen in slight perspective as "
        "a wide ellipse hole: a rocky jagged rim of dark stone, the inside "
        "pitch black with a faint orange glow deep down, loose rocks and "
        "ash around the rim")),
    "abyss_watcher": dict(w=120, h=120, biome="abyss", desc=(
        "a shapeless hovering blot of pitch black smoke and shadow, a "
        "ragged round cloud slightly taller than wide with a few drifting "
        "dark tendrils hanging below it and faint dim embers inside, no "
        "face, no eyes")),
}

ANCHOR_COMMON = (
    ". Single isolated object only, nothing else: no landscape, no sky. "
    "Transparent background. Same hand-drawn pixel art style and the same "
    "pixel scale as the reference creature (1 px dark outline, flat "
    "clustered shading, limited palette, no smooth gradients, no "
    "anti-aliasing). Treat it as a small pixel art diorama with volume: a "
    "lit face and a shadow face, overlapping layers, selective outline. "
    "The light comes from the upper right.")

BIOME_REF = {
    "fields": "landmark_elite.png",
    "highlands": "highlands_landmark_elite.png",
    "abyss": "abyss_landmark_elite.png",
}


def act_of(eid):
    for act, ids in ACTS.items():
        if eid in ids:
            return act
    return 0


def load_jobs():
    if os.path.exists(JOBS_FILE):
        with open(JOBS_FILE) as f:
            return json.load(f)
    return {}


def save_jobs(jobs):
    os.makedirs(OUT, exist_ok=True)
    with open(JOBS_FILE, "w") as f:
        json.dump(jobs, f, indent=2)


def idle0(eid):
    return Image.open(F.idle_frame_path(eid)).convert("RGBA")


def derived_dir(eid):
    d = os.path.join(OUT, f"ato{act_of(eid)}", "derived")
    os.makedirs(d, exist_ok=True)
    return d


def _warm(r, g, b):
    return r > 150 and r > b + 60 and g >= b


def _purple(r, g, b):
    return b > 110 and r > 90 and b > g + 40


def derive(eid, kind):
    im = idle0(eid)
    w, h = im.size
    px = im.load()
    if kind == "idle":
        return im
    if kind.startswith("sunk:"):
        visible = int(kind.split(":")[1])
        bb = im.getbbox()
        dy = h - (bb[1] + visible)
        out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        out.paste(im, (0, dy), im)
        return out
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    po = out.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            if kind == "mist":
                k = 0.14
                po[x, y] = (int(r * k + 16), int(g * k + 12), int(b * k + 22), a)
            elif kind == "dark":
                k = 0.22
                if _warm(r, g, b):
                    po[x, y] = (int(r * 0.25), int(g * 0.18), int(b * 0.18), a)
                else:
                    po[x, y] = (int(r * k + 10), int(g * k + 6), int(b * k + 10), a)
            elif kind == "unlit":
                if _warm(r, g, b):
                    v = int((r + g + b) / 3 * 0.28)
                    po[x, y] = (v + 14, v + 8, v + 4, a)
                else:
                    po[x, y] = (int(r * 0.78), int(g * 0.76), int(b * 0.76), a)
            elif kind == "statue":
                v = int(0.3 * r + 0.5 * g + 0.2 * b)
                if _purple(r, g, b):
                    v = int(v * 0.75)
                po[x, y] = (int(v * 0.92) + 6, int(v * 0.92) + 6, int(v * 0.98) + 8, a)
            else:
                po[x, y] = (r, g, b, a)
    if kind == "rubble":
        import random
        rnd = random.Random(7)
        out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        bb = im.getbbox()
        cell = 14
        chunks = []
        for cy in range(bb[1], bb[3], cell):
            for cx in range(bb[0], bb[2], cell):
                c = im.crop((cx, cy, min(cx + cell, bb[2]), min(cy + cell, bb[3])))
                if c.getbbox() and sum(1 for px_ in c.getdata() if px_[3] > 0) > cell * cell * 0.45:
                    cp = c.load()
                    for yy in range(c.height):
                        for xx in range(c.width):
                            r, g, b, a = cp[xx, yy]
                            if a and _purple(r, g, b):
                                v = int((r + g + b) / 3 * 0.6)
                                cp[xx, yy] = (v, v, v + 6, a)
                    chunks.append(c.rotate(rnd.choice((0, 90, 180, 270)), expand=True))
        rnd.shuffle(chunks)
        floor = bb[3]
        cols = max(3, int((bb[2] - bb[0]) / cell))
        for i, c in enumerate(chunks):
            row = i // cols
            col = i % cols
            x = bb[0] + col * cell + rnd.randint(-3, 3) + (cell // 2 if row % 2 else 0)
            y = floor - c.height - row * (cell - 5)
            out.paste(c, (max(0, min(w - c.width, x)), max(0, y)), c)
    if kind == "rats_bottom":
        src = Image.open(os.path.join(ROOT, "tools/preview_out/new_enemies/plague_rats/death_end.png")).convert("RGBA")
        out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        bb_src = src.getbbox()
        bb_idle = im.getbbox()
        dy = bb_idle[3] - bb_src[3]
        out.paste(src, (0, dy), src)
    return out


def first_frame_path(eid, clip):
    spec = CLIPS[eid][clip]
    if spec["first"] == "idle":
        return F.idle_frame_path(eid)
    p = os.path.join(derived_dir(eid), f"{eid}_{clip}_first.png")
    derive(eid, spec["first"]).save(p)
    return p


def b64file(path):
    with open(path, "rb") as f:
        return base64.b64encode(f.read()).decode()


def submit(eid, clip, seed=None):
    spec = CLIPS[eid][clip]
    prompt = f"{spec['action']}. It keeps its {F.ENEMIES[eid]['keep']}." + SUFFIX
    args = {"action": prompt[:1000],
            "first_frame_base64": b64file(first_frame_path(eid, clip)),
            "frame_count": spec["frames"]}
    if spec.get("end") == "idle":
        args["last_frame_base64"] = b64file(F.idle_frame_path(eid))
    if seed is not None:
        args["seed"] = seed
    text = F.tool_text(F.rpc("tools/call", {"name": "animate_image",
                                            "arguments": args}))
    m = re.search(r"([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-"
                  r"[0-9a-f]{12})", text)
    if not m:
        print(f"[submit] {eid}/{clip}: SEM JOB ID {text[:200]}", flush=True)
        return None
    return m.group(1)


def frame_files(d):
    return sorted([f for f in os.listdir(d) if f.endswith(".png")],
                  key=lambda f: int(f.split(".")[0]))


def end_drift(eid, clip):
    d = F.anim_dir(eid, clip)
    files = frame_files(d)
    last = Image.open(os.path.join(d, files[-1])).convert("RGBA")
    ref = idle0(eid)
    if last.size != ref.size:
        return 1.0
    a, b = last.load(), ref.load()
    w, h = ref.size
    diff = 0
    tot = 0
    for y in range(h):
        for x in range(w):
            pa, pb = a[x, y], b[x, y]
            if pa[3] < 8 and pb[3] < 8:
                continue
            tot += 1
            if abs(pa[3] - pb[3]) > 40 or max(abs(pa[i] - pb[i]) for i in range(3)) > 48:
                diff += 1
    return diff / max(1, tot)


def tripwires(eid, clip):
    d = F.anim_dir(eid, clip)
    files = frame_files(d)
    probs = []
    hashes = set()
    for f in files:
        with open(os.path.join(d, f), "rb") as fh:
            hashes.add(hashlib.md5(fh.read()).hexdigest())
    if len(hashes) <= 2:
        probs.append("ANIM MORTA")
    ref = idle0(eid)
    rb = ref.getbbox()
    rh = rb[3] - rb[1]
    for f in files[1:-1]:
        im = Image.open(os.path.join(d, f)).convert("RGBA")
        bb = im.getbbox()
        if not bb:
            probs.append(f"QUADRO VAZIO {f}")
            continue
        hh = bb[3] - bb[1]
        if hh < rh * 0.25:
            probs.append(f"QUADRO MINUSCULO {f} ({hh}px)")
    drift = end_drift(eid, clip)
    if drift > 0.08:
        probs.append(f"FIM DESVIA DO IDLE ({drift:.2f})")
    return probs, drift


def pin_end(eid, clip):
    d = F.anim_dir(eid, clip)
    files = frame_files(d)
    idle0(eid).save(os.path.join(d, files[-1]))


def snapshot(eid, clip, tag):
    d = F.anim_dir(eid, clip)
    keep = os.path.join(OUT, f"ato{act_of(eid)}", "tries", f"{eid}_{clip}_{tag}")
    os.makedirs(keep, exist_ok=True)
    for f in frame_files(d):
        Image.open(os.path.join(d, f)).save(os.path.join(keep, f))
    return keep


def restore(eid, clip, keep):
    d = F.anim_dir(eid, clip)
    for f in frame_files(d):
        os.remove(os.path.join(d, f))
    for f in frame_files(keep):
        Image.open(os.path.join(keep, f)).save(os.path.join(d, f))


def _dead(probs):
    return any("MORTA" in p or "VAZIO" in p for p in probs)


def _finish(eid, clip, job_id):
    jobs = load_jobs()
    key = f"{eid}/{clip}"
    st = jobs.get(key, {})
    tries = st.get("tries", [])
    probs, drift = tripwires(eid, clip)
    keep = snapshot(eid, clip, f"t{len(tries) + 1}")
    tries = tries + [dict(job=job_id, drift=round(drift, 3), problems=probs, dir=keep)]
    if not _dead(probs) and drift <= 0.30:
        if drift > 0.0:
            pin_end(eid, clip)
        jobs[key] = dict(status="ok" if drift <= 0.08 else "pinned", job_id=job_id,
                         tries=tries, drift=round(drift, 3))
    elif len(tries) >= MAX_TRIES:
        best = min((t for t in tries if t.get("dir") and not _dead(t.get("problems", []))),
                   key=lambda t: t.get("drift", 9), default=None)
        if best:
            restore(eid, clip, best["dir"])
            pin_end(eid, clip)
            jobs[key] = dict(status="best_of_3", job_id=best["job"], tries=tries,
                             drift=best["drift"])
        else:
            jobs[key] = dict(status="failed", job_id=job_id, tries=tries)
    else:
        jobs[key] = dict(status="retry", job_id=job_id, tries=tries)
    save_jobs(jobs)
    strip(eid, clip)
    print(f"[{jobs[key]['status']}] {key} drift={drift:.3f} {probs}", flush=True)


def _submit_next(eid, clip):
    jobs = load_jobs()
    key = f"{eid}/{clip}"
    st = jobs.get(key, {})
    tries = st.get("tries", [])
    seed = 1000 + 97 * len(tries) + 7 * act_of(eid)
    import subprocess
    out = subprocess.run([sys.executable, os.path.abspath(__file__), "submit1", eid, clip,
                          str(seed if tries else -1)], capture_output=True, text=True).stdout
    m = re.search(r"JOB ([0-9a-f-]{36})", out)
    job_id = m.group(1) if m else None
    jobs = load_jobs()
    if not job_id:
        jobs[key] = dict(st, status="submit_failed", tries=tries)
        save_jobs(jobs)
        return False
    jobs[key] = dict(st, status="pending", job_id=job_id, tries=tries)
    save_jobs(jobs)
    print(f"[run] {key} -> job {job_id} (tentativa {len(tries) + 1})", flush=True)
    return True


def targets(args):
    ids = []
    for a in args or [str(k) for k in ACTS]:
        if a.isdigit():
            ids += ACTS[int(a)]
        elif a in CLIPS:
            ids.append(a)
    return [(eid, clip) for eid in ids for clip in CLIPS[eid]]


def run(args, slots=4):
    todo = targets(args)
    print(f"[run] {len(todo)} clipes", flush=True)
    t0 = time.time()
    while time.time() - t0 < 3 * 3600:
        jobs = load_jobs()
        pending = [(e, c) for e, c in todo if jobs.get(f"{e}/{c}", {}).get("status") == "pending"]
        for eid, clip in pending:
            st = jobs[f"{eid}/{clip}"]
            r = F.poll_download(eid, clip, st["job_id"])
            if r == "done":
                _finish(eid, clip, st["job_id"])
            elif r == "error":
                j = load_jobs()
                tries = st.get("tries", []) + [dict(job=st["job_id"], result="error")]
                j[f"{eid}/{clip}"] = dict(st, status="failed" if len(tries) >= MAX_TRIES else "retry", tries=tries)
                save_jobs(j)
        jobs = load_jobs()
        pending = [(e, c) for e, c in todo if jobs.get(f"{e}/{c}", {}).get("status") == "pending"]
        waiting = [(e, c) for e, c in todo
                   if jobs.get(f"{e}/{c}", {}).get("status") in (None, "retry", "submit_failed")]
        for eid, clip in waiting[:max(0, slots - len(pending))]:
            if _submit_next(eid, clip):
                pending.append((eid, clip))
            time.sleep(2)
        if not pending and not waiting:
            break
        time.sleep(15)
    print("[run] fim", flush=True)


def retry(key):
    eid, clip = key.split("/")
    jobs = load_jobs()
    st = jobs.get(key, {})
    jobs[key] = dict(st, status="retry")
    save_jobs(jobs)
    run([eid])


def strip(eid, clip, scale=4):
    d = F.anim_dir(eid, clip)
    if not os.path.isdir(d):
        return None
    files = frame_files(d)
    ims = [Image.open(os.path.join(d, f)).convert("RGBA") for f in files]
    ims.append(idle0(eid))
    cw = max(im.width for im in ims) * scale
    ch = max(im.height for im in ims) * scale
    gap = 6
    out = Image.new("RGBA", (len(ims) * (cw + gap) + gap, ch + 2 * gap), (58, 52, 50, 255))
    for i, im in enumerate(ims):
        big = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
        x = gap + i * (cw + gap) + (cw - big.width) // 2
        out.paste(big, (x, gap + ch - big.height), big)
    sep = len(files) * (cw + gap) + gap // 2
    for y in range(out.height):
        out.putpixel((sep, y), (220, 60, 60, 255))
    od = os.path.join(OUT, f"ato{act_of(eid)}")
    os.makedirs(od, exist_ok=True)
    p = os.path.join(od, f"{eid}_{clip}.png")
    out.save(p)
    return p


def strips(args):
    for eid, clip in targets(args):
        p = strip(eid, clip)
        if p:
            print(p)


def derived(args=None):
    for eid, clip in targets(args):
        if CLIPS[eid][clip]["first"] != "idle":
            print(first_frame_path(eid, clip))


def status():
    jobs = load_jobs()
    for act, ids in ACTS.items():
        for eid in ids:
            for clip in CLIPS[eid]:
                st = jobs.get(f"{eid}/{clip}", {})
                print(f"ato{act} {eid:18s} {clip:9s} {st.get('status', 'missing'):10s} "
                      f"drift={st.get('drift', '')} tries={len(st.get('tries', []))}")


def load_anchor_jobs():
    if os.path.exists(ANCHOR_JOBS):
        with open(ANCHOR_JOBS) as f:
            return json.load(f)
    return {}


def save_anchor_jobs(j):
    os.makedirs(OUT, exist_ok=True)
    with open(ANCHOR_JOBS, "w") as f:
        json.dump(j, f, indent=2)


def anchors_queue(names=None, seed=None):
    J = load_anchor_jobs()
    for eid, spec in ANCHORS.items():
        if names and eid not in names:
            continue
        creature = b64file(F.idle_frame_path(eid))
        biome = b64file(os.path.join(WORLD, BIOME_REF[spec["biome"]]))
        args = {
            "description": spec["desc"] + ANCHOR_COMMON,
            "width": spec["w"], "height": spec["h"], "no_background": True,
            "style_image_base64": creature,
            "style_copy": ["outline", "detail", "shading"],
            "reference_images": [
                {"base64": creature,
                 "usage": "pixel scale, outline weight and shading style: the "
                          "creature this prop belongs to, draw the prop at the "
                          "same pixel scale"},
                {"base64": biome,
                 "usage": "biome palette and mood: the landmark of the same "
                          "road, match its colours and lighting"},
            ],
        }
        if seed is not None:
            args["seed"] = seed
        m = None
        for _ in range(60):
            text = F.tool_text(F.rpc("tools/call", {"name": "create_image_pro",
                                                    "arguments": args}, timeout=300))
            m = re.search(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", text)
            if m or "rate limit" not in text:
                break
            time.sleep(20)
        J.setdefault(eid, []).append({"job": m.group(0) if m else None, "done": False})
        print(f"[queue] {eid}: {J[eid][-1]['job']} {text[:80]!r}", flush=True)
        save_anchor_jobs(J)
        time.sleep(2)


def anchors_poll():
    os.makedirs(ANCHOR_RAW, exist_ok=True)
    J = load_anchor_jobs()
    pending = True
    t0 = time.time()
    while pending and time.time() - t0 < 1800:
        pending = False
        for eid, lst in J.items():
            for n, j in enumerate(lst):
                if j.get("done") or not j.get("job"):
                    continue
                text = F.tool_text(F.rpc("tools/call", {"name": "get_image",
                                                        "arguments": {"job_id": j["job"]}}))
                low = text.lower()
                if "status: failed" in low or "status: error" in low:
                    j["done"] = "error"
                    print(f"[poll] {eid}: FALHOU {text[:160]}", flush=True)
                    continue
                if "status: completed" not in low:
                    pending = True
                    continue
                mf = re.search(r"frames:\s*(\d+)", text)
                m0 = re.search(r"(https?://\S+download\?index=)0", text)
                urls = [m0.group(1) + str(i) for i in range(int(mf.group(1)))] if mf and m0 else []
                for i, u in enumerate(urls):
                    with open(os.path.join(ANCHOR_RAW, f"{eid}__{n}_{i}.png"), "wb") as f:
                        f.write(F.fetch(u))
                j["done"] = True
                print(f"[ok] {eid}: lote {n}, {len(urls)} candidatas", flush=True)
        save_anchor_jobs(J)
        if pending:
            time.sleep(20)


def anchors_sheet():
    for eid, spec in ANCHORS.items():
        files = sorted(f for f in os.listdir(ANCHOR_RAW) if f.startswith(eid + "__"))
        if not files:
            continue
        ims = [idle0(eid)] + [Image.open(os.path.join(ANCHOR_RAW, f)).convert("RGBA") for f in files]
        S = 3
        cw = max(im.width for im in ims) * S
        ch = max(im.height for im in ims) * S
        out = Image.new("RGBA", ((cw + 8) * len(ims) + 8, ch + 16), (58, 52, 50, 255))
        for i, im in enumerate(ims):
            big = im.resize((im.width * S, im.height * S), Image.NEAREST)
            out.paste(big, (8 + i * (cw + 8), 8 + ch - big.height), big)
        p = os.path.join(OUT, f"ato{act_of(eid)}", f"{eid}_anchor_cands.png")
        os.makedirs(os.path.dirname(p), exist_ok=True)
        out.save(p)
        print(p, files)


def anchors_install(pairs):
    os.makedirs(ANCHOR_DIR, exist_ok=True)
    for pair in pairs:
        eid, idx = pair.split("=")
        src = os.path.join(ANCHOR_RAW, f"{eid}__{idx}.png")
        im = Image.open(src).convert("RGBA")
        bb = im.getbbox()
        im = im.crop(bb)
        dst = os.path.join(ANCHOR_DIR, f"{eid}_anchor.png")
        im.save(dst)
        print(dst, im.size)


def derived_anchors():
    os.makedirs(ANCHOR_DIR, exist_ok=True)
    for eid, kind in (("wicker_effigy", "unlit"),):
        p = os.path.join(ANCHOR_DIR, f"{eid}_anchor.png")
        derive(eid, kind).save(p)
        print(p)


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    rest = sys.argv[2:]
    if cmd == "run":
        run(rest)
    elif cmd == "submit1":
        sd = int(rest[2])
        jid = submit(rest[0], rest[1], seed=None if sd < 0 else sd)
        print(f"JOB {jid}" if jid else "JOB none")
    elif cmd == "retry":
        retry(rest[0])
    elif cmd == "strips":
        strips(rest)
    elif cmd == "derived":
        derived(rest)
        derived_anchors()
    elif cmd == "anchors":
        sub = rest[0] if rest else "sheet"
        if sub == "queue":
            anchors_queue(rest[1:] or None)
        elif sub == "poll":
            anchors_poll()
        elif sub == "sheet":
            anchors_sheet()
        elif sub == "install":
            anchors_install(rest[1:])
    else:
        status()
