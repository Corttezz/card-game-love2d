import hashlib
import json
import os
import shutil
import sys
import threading
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixellab_enemy_anims as F
import pixellab_entradas_mini as MN

from PIL import Image

ROOT = F.ROOT
OUT = os.path.join(ROOT, "tools/preview_out/entradas_arte/e462")
STILLS = os.path.join(OUT, "stills")
DERIVED = os.path.join(OUT, "derived")
TRIES = os.path.join(OUT, "tries")
MINI_DERIVED = os.path.join(ROOT, "tools/preview_out/entradas_arte/mini/derived")
LOG = os.path.join(OUT, "jobs.json")
LOCK = threading.Lock()

FRONT = ("Same creature, same pixel art style, same pixel scale, same outline weight, same palette and shading, "
         "same canvas, front view facing the viewer, the whole body fully inside the canvas with empty space around "
         "it. Only the pose changes. Transparent background, nothing else in the image.")
SIDE = ("Same creature, same pixel art style, same pixel scale, same outline weight, same palette and shading, same "
        "canvas size. The whole body and both wings fully inside the canvas with empty space around them. "
        "Transparent background, nothing else in the image, no ground, no shadow.")
ANIM = (" Palette, colors, proportions, face and every body part stay unchanged in every frame. Nothing new appears: "
        "no particles, no sparks, no dust, no text, background stays empty and transparent, nothing leaves the frame.")

STILL_SPECS = {
    "carrion_king/side": dict(base="idle", suffix=SIDE, desc=(
        "Redraw this crowned crow king seen from the SIDE, in profile, facing RIGHT, flying horizontally through the "
        "air: the body leaning forward almost level, the crowned crow head in profile with the long beak pointing to "
        "the right, both big blue-black wings raised HIGH above the back in the up-stroke, feathers spread, the orange "
        "talons pulled up and tucked under the belly, the tattered purple robe pieces streaming back to the left "
        "behind the body. Compact enough to fit the canvas.")),
    "carrion_king/side_down": dict(base="still:side", suffix=SIDE, desc=(
        "Same flying crow king in side view facing right, now in the DOWN-stroke: both big wings swept DOWN below "
        "the body, wing tips pointing down and back, the body lifted a little, talons still tucked, robe streaming "
        "back to the left. Same head, crown, beak and colors.")),
    "fallen_angel/fly": dict(base="idle", suffix=FRONT, desc=(
        "Change the pose: the fallen angel is FLYING in the air: the two huge black feathered wings raised HIGH above "
        "the shoulders in the up-stroke, the body leaning slightly forward, both legs hanging loose below the robe "
        "with the toes pointing DOWN like a diver, feet not standing on anything, the long dark sword held low in one "
        "hand pointing down, the purple robe hem fluttering back, the gold halo above the head. The wing tips stay "
        "inside the canvas.")),
    "fallen_angel/fly_down": dict(base="still:fly", suffix=FRONT, desc=(
        "Same flying fallen angel, now the down-stroke: both huge black wings swept DOWN and forward below the "
        "shoulders in a powerful beat, wing tips low at the sides, the body pushed up a little, legs dangling with "
        "toes pointing down, robe hem flaring. Same face, halo, sword and colors. The wing tips stay inside the "
        "canvas.")),
    "fallen_angel/touch": dict(base="idle", suffix=FRONT, desc=(
        "Change the pose: the fallen angel is landing: the huge black wings flared wide OPEN and raised to brake, "
        "the toes of one foot just touching the ground, the other leg bent, knees beginning to bend, the robe hem "
        "billowing up, the sword held low and out to the side, head lowered. The wing tips stay inside the canvas.")),
    "dullahan/strideA": dict(base="idle", suffix=FRONT, desc=(
        "Change ONLY the legs: the headless armored knight takes a heavy step forward toward the viewer, the LEFT "
        "armored leg lifted forward with the knee bent and the boot raised, the right leg planted behind. Keep "
        "EXACTLY as in the input: the violet flame burning on the empty neck, the dark red horned HELMET carried in "
        "the left hand at the side of the body with its violet eye glow and a small violet flame on top, the curved "
        "blade held low in the right hand, the dark red cape hanging close behind the body.")),
    "dullahan/strideB": dict(base="idle", suffix=FRONT, desc=(
        "Change ONLY the legs: the headless armored knight takes a heavy step forward toward the viewer, the RIGHT "
        "armored leg lifted forward with the knee bent and the boot raised, the left leg planted behind. Keep "
        "EXACTLY as in the input: the violet flame burning on the empty neck, the dark red horned HELMET carried in "
        "the left hand at the side of the body with its violet eye glow and a small violet flame on top, the curved "
        "blade held low in the right hand, the dark red cape hanging close behind the body.")),
    "blight_bull/gallopA": dict(base="idle", suffix=FRONT, desc=(
        "Change the pose: the huge blighted bull CHARGES toward the viewer at full gallop: head lowered with the "
        "long horns forward, the LEFT front leg reaching far forward and up with the hoof raised, the right front "
        "leg planted and bearing the weight, shoulders bunched and heaving, back low, the withered wheat stalks on "
        "the back tossed. Heavy and powerful.")),
    "blight_bull/gallopB": dict(base="idle", suffix=FRONT, desc=(
        "Change the pose: the huge blighted bull CHARGES toward the viewer at full gallop: head lowered with the "
        "long horns forward, the RIGHT front leg reaching far forward and up with the hoof raised, the left front "
        "leg planted and bearing the weight, the body dipped low on the planted leg, shoulders heaving, the withered "
        "wheat stalks on the back tossed. Heavy and powerful.")),
    "hellhound/lunge": dict(base="idle", suffix=FRONT, desc=(
        "Change the pose: the three-headed hellhound is mid-leap in a running gallop toward the viewer: the body "
        "stretched long, both front legs reaching forward with claws spread, the hind legs kicked out behind, the "
        "three heads low and forward with jaws open, the fiery manes streaming back. All flames stay attached to "
        "the body.")),
    "hellhound/gather": dict(base="idle", suffix=FRONT, desc=(
        "Keep the SAME three-quarter view as the input, facing the same way, the same heads in the same places. "
        "Change only the pose: the hellhound crouches low, gathering its legs under the body to spring forward, "
        "front legs bent with the paws planted, hind legs coiled under the belly, back arched, heads low and "
        "snarling, the fiery manes and tail flame streaming back. All flames stay attached to the body.")),
}

ANIM_SPECS = {
    "carrion_king/fly_side#a": dict(first="still:side", last="still:side_down", frames=4, action=(
        "the crow king flying in side view facing right beats both wings powerfully DOWN, the wings sweep from high "
        "above the back down below the body, the body rises slightly, the robe streams back")),
    "carrion_king/fly_side#b": dict(first="still:side_down", last="still:side", frames=4, action=(
        "the crow king flying in side view facing right lifts both wings back UP from below the body to high above "
        "the back, feathers spreading, the body sinks slightly, the robe streams back")),
    "fallen_angel/swoop#a": dict(first="still:fly", last="still:fly_down", frames=4, action=(
        "flying in the air, both huge black wings beat powerfully DOWN, the body rises a little, the dangling legs "
        "sway back, the robe hem ripples; the halo stays the same thin broken GOLD ring in every frame, never white, "
        "no white pixels anywhere")),
    "fallen_angel/swoop#b": dict(first="still:fly_down", last="still:fly", frames=4, action=(
        "flying in the air, both huge black wings lift back UP and spread, the body sinks a little, the dangling "
        "legs swing forward, the robe hem ripples")),
    "fallen_angel/land#a": dict(first="still:fly", last="still:touch", frames=6, action=(
        "comes in to land: the wings flare wide open to brake, the body swings upright, the legs drop down and "
        "reach for the ground, the toes touch down")),
    "fallen_angel/land#b": dict(first="still:touch", last="mini:fallen_angel_kneel", frames=6, action=(
        "the feet hit the ground, the knees bend deep absorbing the impact and it sinks onto one knee, the sword "
        "point strikes the ground, the wings sweep down low and fold, a few black feathers fall")),
    "dullahan/walk#a": dict(first="idle", last="still:strideA", frames=4, action=(
        "steps heavily forward onto the left foot, the armor plates jolt, the cape sways, the body dips into the "
        "step")),
    "dullahan/walk#b": dict(first="still:strideA", last="still:strideB", frames=4, action=(
        "the weight rolls over the planted left foot and the right leg swings forward and plants heavily, the "
        "armored body dips with the step, the cape sways to the other side")),
    "dullahan/walk#c": dict(first="still:strideB", last="idle", frames=4, action=(
        "drags the left leg up beside the right and stops heavily, the cape settles close to the body")),
    "blight_bull/charge#a": dict(first="idle", last="still:gallopA", frames=4, action=(
        "the bull lowers its head and lunges into a gallop, the left front hoof lifts and reaches forward, the "
        "shoulders heave, the body dips")),
    "blight_bull/charge#b": dict(first="still:gallopA", last="still:gallopB", frames=4, action=(
        "the left front hoof slams down and takes the weight, the right front leg lifts and reaches forward, the "
        "heavy body pitches down and up with the stride, horns low")),
    "blight_bull/charge#c": dict(first="still:gallopB", last="idle", frames=4, action=(
        "the right front hoof slams down, the bull digs in and brakes hard, raising its head back into its stance")),
    "hellhound/charge#a": dict(first="idle", last="still:gather", frames=4, action=(
        "the hellhound crouches and gathers all four legs under its body to spring, heads low, manes streaming")),
    "hellhound/charge#b": dict(first="still:gather", last="still:lunge", frames=4, action=(
        "the hellhound pushes off with the hind legs and stretches long in a leaping stride, front legs reaching "
        "forward, heads low, manes streaming back")),
    "hellhound/charge#c": dict(first="still:lunge", last="idle", frames=4, action=(
        "the front paws land and the hellhound skids to a halt, pulling its legs under it back into its snarling "
        "stance")),
}

KEEP = {
    "carrion_king": "golden crown, black crow head with ivory beak, glowing orange eyes, blue-black wings and tattered purple robe",
}


def log(entry):
    with LOCK:
        os.makedirs(OUT, exist_ok=True)
        data = json.load(open(LOG)) if os.path.exists(LOG) else []
        entry["t"] = time.strftime("%Y-%m-%d %H:%M:%S")
        data.append(entry)
        json.dump(data, open(LOG, "w"), indent=1)


def source(eid, kind):
    if kind == "idle":
        return F.idle_frame_path(eid)
    if kind.startswith("still:"):
        return os.path.join(DERIVED, f"{eid}_{kind[6:]}.png")
    if kind.startswith("mini:"):
        return os.path.join(MINI_DERIVED, kind[5:] + ".png")
    return os.path.join(ROOT, kind)


def keep(eid):
    return KEEP.get(eid) or F.ENEMIES.get(eid, {}).get("keep") or "look"


def still(key, seed=0):
    eid, name = key.split("/")
    spec = STILL_SPECS[key]
    src = Image.open(source(eid, spec["base"])).convert("RGBA")
    padded, box = MN.pad4(src)
    tmp = os.path.join(OUT, f"_pad_{eid}_{name}_{seed}.png")
    os.makedirs(OUT, exist_ok=True)
    padded.save(tmp)
    desc = spec["desc"] + " " + spec["suffix"]
    args = {"method": "text", "description": desc[:2000], "image_base64": MN.b64(tmp),
            "no_background": True, "seed": int(seed)}
    job, text = MN.submit("edit_image_pro_flash", args)
    os.remove(tmp)
    if not job:
        print(f"[FAIL] still {key}: {text[:300]}", flush=True)
        return
    log({"kind": "still", "key": key, "seed": seed, "job": job})
    got = MN.wait(job, STILLS, f"{eid}_{name}_s{seed}_")
    res = []
    for p in got:
        im = Image.open(p).convert("RGBA")
        if im.size == padded.size:
            im = im.crop(box)
        im.save(p)
        res.append(p)
    MN.strip([source(eid, spec["base"])] + res, os.path.join(OUT, f"{eid}_still_{name}_s{seed}.png"), scale=3)
    print(f"[ok] still {key} s{seed}: {len(res)}", flush=True)


def pick(key, path):
    eid, name = key.split("/")
    os.makedirs(DERIVED, exist_ok=True)
    im = Image.open(path).convert("RGBA")
    ref = Image.open(F.idle_frame_path(eid))
    assert im.size == ref.size, (im.size, ref.size)
    im.save(os.path.join(DERIVED, f"{eid}_{name}.png"))
    print(f"[ok] {key} <- {path}", flush=True)


def anim(key, seed=None, tool=None):
    spec = ANIM_SPECS[key]
    eid, rest = key.split("/")
    clip = rest.split("#")[0]
    tool = tool or spec.get("tool", "animate_image")
    frames = int(spec.get("frames", 8))
    first = source(eid, spec["first"])
    last = source(eid, spec["last"])
    text = f"{spec['action']}. It keeps its {keep(eid)}." + ANIM
    if tool == "animate_image_pixminimax":
        args = {"description": text[:1000], "first_frame_base64": MN.b64(first), "frame_count": frames,
                "no_background": True, "direction": "south", "view": "side"}
    else:
        args = {"action": text[:1000], "first_frame_base64": MN.b64(first), "frame_count": frames}
    args["last_frame_base64"] = MN.b64(last)
    if seed is not None:
        args["seed"] = int(seed)
    job, resp = MN.submit(tool, args)
    if not job:
        print(f"[FAIL] anim {key}: {resp[:300]}", flush=True)
        return
    tag = rest.replace("#", "_")
    with LOCK:
        n = 1
        while os.path.isdir(os.path.join(TRIES, f"{eid}_{tag}_t{n}")):
            n += 1
        dest = os.path.join(TRIES, f"{eid}_{tag}_t{n}")
        os.makedirs(dest)
    json.dump({"key": key, "tool": tool, "seed": seed, "frames": frames, "job": job,
               "first": spec["first"], "last": spec["last"]}, open(os.path.join(dest, "meta.json"), "w"), indent=1)
    log({"kind": "anim", "key": key, "tool": tool, "seed": seed, "job": job, "try": n})
    got = MN.wait(job, dest, "")
    if not got:
        return
    dr = MN.drift(got[-1], last)
    MN.strip(got + [last], os.path.join(OUT, f"{eid}_{tag}_t{n}.png"), marks=(len(got),))
    print(f"[ok] {key} t{n}: {len(got)} quadros, drift fim {dr:.3f}", flush=True)


def frames_of(eid, tag, n):
    d = os.path.join(TRIES, f"{eid}_{tag}_t{n}")
    fs = sorted([x for x in os.listdir(d) if x.endswith(".png")], key=lambda s: int(s[:-4]))
    return [os.path.join(d, x) for x in fs]


def no_sparks(im):
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if not a or min(r, g, b) < 200:
                continue
            n = 0
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    if (dx or dy) and 0 <= x + dx < w and 0 <= y + dy < h and px[x + dx, y + dy][3]:
                        n += 1
            if n <= 2:
                px[x, y] = (0, 0, 0, 0)
    return im


ISLAND_MAX = 8


def no_islands(im):
    im = no_sparks(im)
    px = im.load()
    w, h = im.size
    seen = bytearray(w * h)
    for y0 in range(h):
        for x0 in range(w):
            if seen[y0 * w + x0] or not px[x0, y0][3]:
                continue
            comp, stack = [], [(x0, y0)]
            seen[y0 * w + x0] = 1
            while stack:
                x, y = stack.pop()
                comp.append((x, y))
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx] and px[nx, ny][3]:
                            seen[ny * w + nx] = 1
                            stack.append((nx, ny))
            if len(comp) <= ISLAND_MAX:
                for x, y in comp:
                    px[x, y] = (0, 0, 0, 0)
    return im


def install_chain(eid, clip, parts, direction="south", mirror=None, loop=False, fix=None, skip=()):
    seq = []
    for k, (tag, n) in enumerate(parts):
        fr = frames_of(eid, tag, n)
        key = json.load(open(os.path.join(TRIES, f"{eid}_{tag}_t{n}", "meta.json")))
        firstf = source(eid, key["first"])
        lastf = source(eid, key["last"])
        mids = fr[1:-1]
        if k == 0:
            seq.append(("file", firstf))
        seq += [("gen", p) for p in mids]
        seq.append(("file", lastf))
    if loop:
        seq = seq[:-1]
    seq = [s for i, s in enumerate(seq) if i not in skip]
    dest = os.path.join(F.ENEMIES_DIR, eid, "animations", clip, direction)
    if os.path.isdir(dest):
        for x in os.listdir(dest):
            if x.endswith(".png"):
                os.remove(os.path.join(dest, x))
    os.makedirs(dest, exist_ok=True)
    for i, (kind, p) in enumerate(seq):
        out = os.path.join(dest, f"{i}.png")
        if kind == "file" and (not fix or i == 0 or i == len(seq) - 1):
            shutil.copyfile(p, out)
        elif kind == "file":
            fix(Image.open(p).convert("RGBA")).save(out)
        else:
            im = Image.open(p).convert("RGBA")
            if fix:
                im = fix(im)
            im.save(out)
    paths = [os.path.join(dest, f"{i}.png") for i in range(len(seq))]
    if mirror:
        md = os.path.join(F.ENEMIES_DIR, eid, "animations", clip, mirror)
        if os.path.isdir(md):
            for x in os.listdir(md):
                if x.endswith(".png"):
                    os.remove(os.path.join(md, x))
        os.makedirs(md, exist_ok=True)
        for i, p in enumerate(paths):
            Image.open(p).transpose(Image.FLIP_LEFT_RIGHT).save(os.path.join(md, f"{i}.png"))
    MN.strip(paths + [F.idle_frame_path(eid)], os.path.join(OUT, f"{eid}_{clip}_instalado.png"), marks=(len(paths),))
    print(f"[ok] instalado {eid}/{clip}/{direction}: {len(paths)} quadros", flush=True)


def md5(p):
    return hashlib.md5(open(p, "rb").read()).hexdigest()


def check(eid, clip, direction="south"):
    d = os.path.join(F.ENEMIES_DIR, eid, "animations", clip, direction)
    fs = sorted([x for x in os.listdir(d) if x.endswith(".png")], key=lambda s: int(s[:-4]))
    idle = Image.open(F.idle_frame_path(eid)).convert("RGBA")
    last = Image.open(os.path.join(d, fs[-1])).convert("RGBA")
    first = Image.open(os.path.join(d, fs[0])).convert("RGBA")
    same_last = last.tobytes() == idle.tobytes()
    edges = []
    prev = None
    act = []
    for f in fs:
        im = Image.open(os.path.join(d, f)).convert("RGBA")
        bb = im.getchannel("A").getbbox()
        edges.append(bb is not None and (bb[0] == 0 or bb[1] == 0 or bb[2] == im.width or bb[3] == im.height))
        if prev is not None:
            a, b = prev.tobytes(), im.tobytes()
            act.append(sum(1 for i in range(3, len(a), 4) if (a[i] > 0) != (b[i] > 0)))
        prev = im
        assert im.size == idle.size, (f, im.size, idle.size)
    print(json.dumps({"clip": f"{eid}/{clip}/{direction}", "quadros": len(fs), "ultimo_eq_idle0": same_last,
                      "primeiro_eq_idle0": first.tobytes() == idle.tobytes(),
                      "toca_borda": [i for i, e in enumerate(edges) if e], "atividade_alpha": act}))


def run_parallel(calls):
    ths = []
    for fn, a in calls:
        t = threading.Thread(target=fn, args=a)
        t.start()
        ths.append(t)
        time.sleep(1.5)
    for t in ths:
        t.join()


def main():
    cmd, rest = sys.argv[1], sys.argv[2:]
    if cmd == "stills":
        run_parallel([(still, (k.split("@")[0], int(k.split("@")[1]) if "@" in k else 0)) for k in rest])
    elif cmd == "pick":
        for a in rest:
            key, _, name = a.partition("=")
            pick(key, os.path.join(STILLS, name + ".png"))
    elif cmd == "anims":
        calls = []
        for k in rest:
            key, _, seed = k.partition("@")
            calls.append((anim, (key, int(seed) if seed else None)))
        run_parallel(calls)
    elif cmd == "install":
        eid, clip = rest[0], rest[1]
        kw = dict(a.split("=", 1) for a in rest[3:])
        parts = []
        for p in rest[2].split("+"):
            tag, _, n = p.partition(":")
            parts.append((tag, int(n)))
        install_chain(eid, clip, parts, direction=kw.get("dir", "south"), mirror=kw.get("mirror"),
                      loop=kw.get("loop") == "1", fix={"sparks": no_sparks, "islands": no_islands}.get(kw.get("fix")),
                      skip=tuple(int(v) for v in kw.get("skip", "").split(",") if v))
        check(eid, clip, kw.get("dir", "south"))
    elif cmd == "check":
        check(rest[0], rest[1], rest[2] if len(rest) > 2 else "south")


if __name__ == "__main__":
    main()
