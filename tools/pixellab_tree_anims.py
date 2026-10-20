#!/usr/bin/env python3
import json
import os
import re
import shutil
import sys
import time

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixellab_enemy_anims as F

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORLD = os.path.join(ROOT, "assets/sprites/world")
ANIM = os.path.join(WORLD, "anim")
OUT = os.path.join(ROOT, "tools/preview_out", os.environ.get("ANIM_OUT", "anim_cenario"))
RAW = os.path.join(OUT, "raw")
JOBS = os.path.join(OUT, "jobs.json")

TREES = {
    "fields": ["fields_tree_%d" % i for i in range(6)] + ["fields_bush_0", "fields_flowers_0", "fields_tuft_0"],
    "highlands": ["highlands_pine_%d" % i for i in range(6)] + ["highlands_deadtree_0"]
                 + ["highlands_bush_%d" % i for i in range(3)] + ["highlands_grass_%d" % i for i in range(3)],
    "abyss": ["abyss_deadtree_%d" % i for i in range(6)] + ["abyss_bush_%d" % i for i in range(3)]
             + ["abyss_embers_%d" % i for i in range(4)],
    "frost": ["frost_pine_%d" % i for i in range(6)] + ["frost_deadtree_0", "frost_deadtree_1"],
    "marsh": ["marsh_deadtree_%d" % i for i in range(8)] + ["marsh_bush_0"]
             + ["marsh_reeds_%d" % i for i in range(3)] + ["marsh_rock_%d" % i for i in range(4)],
    "dusk": ["dusk_tree_%d" % i for i in range(7)] + ["dusk_bush_0"] + ["dusk_blooms_%d" % i for i in range(3)],
}

FRAMES = 6
IOU_MIN = 0.97
TRUNK_MIN = 0.95
TRUNK_FRAC = 0.30
DEAD_FRAC = 0.008

STILL = (" The trunk, the roots and the outer outline of the whole tree stay "
         "completely still and identical in every frame. The light comes from the "
         "same side in every frame, the lit side and the shadow side never change. "
         "Same colors, same palette. No camera movement, "
         "no zoom, no scaling, the tree never changes shape, size or position. "
         "Subtle idle loop that returns to the first frame.")

STILL_PLANT = (" The base where it touches the ground and the outer outline stay "
               "completely still and identical in every frame. The light comes from the "
               "same side in every frame. Same colors, same palette. No camera movement, "
               "no zoom, no scaling, it never changes shape, size or position. "
               "Subtle idle loop that returns to the first frame.")

PROMPTS = {
    "leafy": ("Gentle breeze idle loop, layered like a diorama: the leaf clusters "
              "at the front of the crown rustle a little, the clusters at the back "
              "of the crown barely move, a few pixels at most, small leaf clusters "
              "shifting back and forth." + STILL),
    "pine": ("Gentle breeze idle loop, layered like a diorama: only the needle tips "
             "of the branch layers bob up and down very slightly, the front layers a "
             "little more than the back ones, one or two pixels." + STILL),
    "snow": ("Gentle breeze idle loop: only the tips of the snow-laden branches "
             "bob very slightly, one or two pixels, the snow stays on the "
             "branches." + STILL),
    "dead": ("Gentle breeze idle loop: only the thinnest bare twigs at the ends "
             "of the branches quiver very slightly, one or two pixels, the "
             "thick branches and the trunk rigid. No leaves." + STILL),
    "ember": ("Slow idle loop: the glowing ember cracks in the bark pulse "
              "softly brighter and dimmer and the thinnest twig tips quiver "
              "one pixel." + STILL),
    "moss": ("Gentle breeze idle loop: only the hanging strands of moss sway "
             "slowly side to side, a few pixels, and the thinnest twig tips "
             "quiver." + STILL),
    "bush": ("Gentle breeze idle loop, layered: the leaves on the top and the front "
             "of the bush rustle a little, the inner and back leaves barely move, "
             "one or two pixels." + STILL_PLANT),
    "grass": ("Gentle breeze idle loop: only the tips of the grass blades and stems "
              "sway slowly to one side and back, one or two pixels, the roots still."
              + STILL_PLANT),
    "reeds": ("Gentle breeze idle loop: only the tops of the reeds and cattails sway "
              "slowly side to side, one or two pixels, the stems' bases still."
              + STILL_PLANT),
    "puddle": ("Gentle breeze idle loop: only the tips of the reeds growing in the "
               "puddle sway slightly, one or two pixels. The water surface, the "
               "stones and the mud stay perfectly still." + STILL_PLANT),
    "embers": ("Slow idle loop: the glowing embers and hot coals on the ground pulse "
               "softly brighter and dimmer, a tiny spark flickers, nothing moves "
               "position." + STILL_PLANT),
    "blooms": ("Gentle breeze idle loop: only the flower heads nod softly and the "
               "petals flutter, one or two pixels, the stems' bases still."
               + STILL_PLANT),
}

STYLE = {
    "fields_tree": "leafy", "dusk_tree": "leafy",
    "highlands_pine": "pine", "frost_pine": "snow",
    "abyss_deadtree": "ember", "marsh_deadtree": "moss",
    "highlands_deadtree": "dead", "frost_deadtree": "dead",
    "fields_bush": "bush", "highlands_bush": "bush", "abyss_bush": "bush",
    "marsh_bush": "bush", "dusk_bush": "bush",
    "fields_flowers": "blooms", "dusk_blooms": "blooms",
    "fields_tuft": "grass", "highlands_grass": "grass",
    "marsh_reeds": "reeds", "marsh_rock": "puddle", "abyss_embers": "embers",
}

TRUNK_BY_PROMPT = {"embers": 0.0, "pine": 0.12, "snow": 0.12, "bush": 0.12, "grass": 0.12, "reeds": 0.12, "blooms": 0.15,
                   "puddle": 0.45}


EXCLUDE = {
    "dusk_tree_1": [(24, 28, 58, 102)],
}


def trunk_frac(name):
    return TRUNK_BY_PROMPT.get(style_of(name), TRUNK_FRAC)


CALM = (" Extremely subtle: keep every pixel of the original drawing, the texture "
        "and shading stay exactly the same, only a few tips move by a single pixel.")


def style_of(name):
    for k in sorted(STYLE, key=len, reverse=True):
        if name.startswith(k):
            return STYLE[k]
    return "leafy"


def base_path(name):
    return os.path.join(WORLD, name + ".png")


def load_jobs():
    if os.path.exists(JOBS):
        with open(JOBS) as f:
            return json.load(f)
    return {}


def save_jobs(jobs):
    os.makedirs(OUT, exist_ok=True)
    with open(JOBS, "w") as f:
        json.dump(jobs, f, indent=1)


def attempt_dir(name, attempt):
    return os.path.join(RAW, name, str(attempt))


def next_attempt(name):
    d = os.path.join(RAW, name)
    if not os.path.isdir(d):
        return 1
    n = [int(x) for x in os.listdir(d) if x.isdigit()]
    return (max(n) + 1) if n else 1


def queue(names, seed=None, prompt_key=None, frames=FRAMES, pin=False, tool="animate_image"):
    import base64
    jobs = load_jobs()
    for name in names:
        with open(base_path(name), "rb") as f:
            b64 = base64.b64encode(f.read()).decode()
        key = prompt_key or style_of(name)
        text_prompt = PROMPTS[key] + (CALM if os.environ.get("ANIM_CALM") else "")
        if tool == "animate_image_pixminimax":
            args = {"description": text_prompt, "first_frame_base64": b64,
                    "frame_count": frames, "no_background": True}
        else:
            args = {"action": text_prompt, "first_frame_base64": b64,
                    "frame_count": frames}
        if pin:
            args["last_frame_base64"] = b64
        if seed is not None:
            args["seed"] = seed
        text = F.tool_text(F.rpc("tools/call", {"name": tool,
                                                "arguments": args}))
        m = re.search(r"([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})", text)
        if not m:
            print(f"[FAIL] {name}: sem job id: {text[:200]}")
            continue
        att = next_attempt(name)
        os.makedirs(attempt_dir(name, att), exist_ok=True)
        jobs[f"{name}/{att}"] = {"name": name, "attempt": att, "job": m.group(1),
                                 "prompt": key, "seed": seed, "frames": frames, "pin": pin,
                                 "tool": tool, "status": "queued",
                                 "t": time.time()}
        save_jobs(jobs)
        print(f"[ok] {name} tentativa {att} job {m.group(1)} prompt={key} frames={frames} pin={pin}")
        time.sleep(2)


def poll():
    jobs = load_jobs()
    pending = [k for k, j in jobs.items() if j["status"] == "queued"]
    for k in pending:
        j = jobs[k]
        text = F.tool_text(F.rpc("tools/call", {"name": "get_image",
                                                "arguments": {"job_id": j["job"]}}))
        low = text.lower()
        if "status: failed" in low or "status: error" in low:
            j["status"] = "failed"
            j["error"] = text[:300]
            print(f"[FAIL] {k}: {text[:200]}")
        elif "status: completed" in low:
            mN = re.search(r"frames:\s*(\d+)", text)
            mURL = re.search(r"(https?://\S+/download)\?index=\d+", text)
            if not (mN and mURL):
                j["status"] = "failed"
                j["error"] = "sem urls"
                print(f"[FAIL] {k}: completo sem urls: {text[:200]}")
            else:
                n, base = int(mN.group(1)), mURL.group(1)
                d = attempt_dir(j["name"], j["attempt"])
                os.makedirs(d, exist_ok=True)
                for i in range(n):
                    with open(os.path.join(d, f"{i}.png"), "wb") as f:
                        f.write(F.fetch(f"{base}?index={i}"))
                j["status"] = "downloaded"
                j["n"] = n
                print(f"[ok] {k}: {n} quadros em {d}")
        else:
            print(f"[wait] {k}")
        save_jobs(jobs)


def rgba(path):
    return np.array(Image.open(path).convert("RGBA"))


def trunk_box(base, frac=TRUNK_FRAC):
    a = base[:, :, 3] > 0
    ys, xs = np.where(a)
    y0, y1 = ys.min(), ys.max()
    ty0 = int(y1 - (y1 - y0) * frac)
    rows = a[ty0:y1 + 1]
    cols = np.where(rows.any(axis=0))[0]
    return ty0, y1, cols.min(), cols.max()


def frames_of(name, attempt):
    d = attempt_dir(name, attempt)
    files = sorted([f for f in os.listdir(d) if re.match(r"^\d+\.png$", f)],
                   key=lambda f: int(f[:-4]))
    return [rgba(os.path.join(d, f)) for f in files]


def measure(name, attempt):
    base = rgba(base_path(name))
    frs = frames_of(name, attempt)
    bm = base[:, :, 3] > 0
    ty0, ty1, tx0, tx1 = trunk_box(base, trunk_frac(name))
    rows = []
    g0 = frs[0] if frs else None
    for i, fr in enumerate(frs):
        if fr.shape != base.shape:
            rows.append((i, 0.0, 0.0, "dim %sx%s" % (fr.shape[1], fr.shape[0])))
            continue
        fm = fr[:, :, 3] > 0
        inter = np.logical_and(bm, fm).sum()
        union = np.logical_or(bm, fm).sum()
        iou = inter / union if union else 0.0
        trunk = 1.0
        changed = 0
        if g0.shape == fr.shape:
            same = np.all(fr == g0, axis=2)
            tb = same[ty0:ty1 + 1, tx0:tx1 + 1]
            mask = g0[ty0:ty1 + 1, tx0:tx1 + 1, 3] > 0
            trunk = float(tb[mask].mean()) if mask.any() else 1.0
            changed = int((~same).sum())
        rows.append((i, float(iou), trunk, "moveu %d px" % changed))
    return rows


def check(names):
    jobs = load_jobs()
    allok = True
    for name in names:
        atts = sorted(int(x) for x in os.listdir(os.path.join(RAW, name))) if os.path.isdir(os.path.join(RAW, name)) else []
        for att in atts:
            rows = measure(name, att)
            if not rows:
                continue
            ok = all(r[1] >= IOU_MIN and r[2] >= TRUNK_MIN for r in rows)
            allok = allok and ok
            print(f"{name} tentativa {att}: {'[ok]' if ok else '[FAIL]'}")
            for i, iou, trunk, note in rows:
                print(f"  quadro {i}: IoU {iou:.4f} tronco {trunk:.4f} {note}")
            key = f"{name}/{att}"
            if key in jobs:
                jobs[key]["iou_min"] = min(r[1] for r in rows)
                jobs[key]["trunk_min"] = min(r[2] for r in rows)
                jobs[key]["ok"] = ok
    save_jobs(jobs)
    return allok


def palette_of(base):
    px = base[base[:, :, 3] > 0][:, :3]
    return np.unique(px, axis=0).astype(np.int32)


def snap_palette(fr, pal):
    out = fr.copy()
    m = out[:, :, 3] > 0
    px = out[m][:, :3].astype(np.int32)
    d = ((px[:, None, :] - pal[None, :, :]) ** 2).sum(axis=2)
    idx = d.argmin(axis=1)
    rgb = out[m]
    rgb[:, :3] = pal[idx]
    rgb[:, 3] = 255
    out[m] = rgb
    return out


def rim_of(bm):
    pad = np.pad(bm, 1)
    n4 = pad[:-2, 1:-1] & pad[2:, 1:-1] & pad[1:-1, :-2] & pad[1:-1, 2:]
    return bm & ~n4


def delta(base, g0, gi, frac=TRUNK_FRAC, name=None):
    bm = base[:, :, 3] > 0
    ty0 = trunk_box(base, frac)[0]
    moved = ~np.all(gi == g0, axis=2)
    moved &= bm
    moved[ty0:, :] = False
    moved &= ~rim_of(bm)
    moved &= gi[:, :, 3] > 0
    for x0, y0, x1, y1 in EXCLUDE.get(name, ()):
        moved[y0:y1, x0:x1] = False
    out = base.copy()
    out[moved] = gi[moved]
    out[~bm] = 0
    return out, int(moved.sum())


def install(name, attempt, seq):
    base, g = snapped(name, attempt)
    outs = build(name, base, g, seq)
    dest = os.path.join(ANIM, name)
    if os.path.isdir(dest):
        shutil.rmtree(dest)
    os.makedirs(dest)
    shutil.copyfile(base_path(name), os.path.join(dest, "0.png"))
    for n, out in enumerate(outs[1:], 1):
        Image.fromarray(out).save(os.path.join(dest, f"{n}.png"))
    print(f"[ok] {name}: {len(outs)} quadros instalados em {dest} (tentativa {attempt}, sequência {seq})")
    return True


def sheet(names, scale=1, dt=0.15):
    for name in names:
        d = os.path.join(ANIM, name)
        if not os.path.isdir(d):
            print(f"[FAIL] {name}: sem pasta anim")
            continue
        files = sorted([f for f in os.listdir(d) if re.match(r"^\d+\.png$", f)],
                       key=lambda f: int(f[:-4]))
        frames = [Image.open(os.path.join(d, f)).convert("RGBA") for f in files]
        w, h = frames[0].size
        gap = 4
        out = Image.new("RGBA", ((w + gap) * len(frames) * scale, h * scale), (40, 40, 48, 255))
        for i, fr in enumerate(frames):
            out.paste(fr.resize((w * scale, h * scale), Image.NEAREST),
                      (i * (w + gap) * scale, 0), fr.resize((w * scale, h * scale), Image.NEAREST))
        bioma = name.split("_")[0]
        od = os.path.join(OUT, bioma)
        os.makedirs(od, exist_ok=True)
        sp = os.path.join(od, f"sheet_{name}.png" if scale == 1 else f"sheet_{name}_{scale}x.png")
        out.save(sp)
        if scale > 1:
            print(f"[ok] {sp}")
            continue
        seq = frames + frames[-2:0:-1]
        gp = os.path.join(od, f"{name}.gif")
        big = [f.resize((w * 3, h * 3), Image.NEAREST) for f in seq]
        bg = [Image.new("RGBA", b.size, (40, 40, 48, 255)) for b in big]
        for b, g in zip(big, bg):
            g.paste(b, (0, 0), b)
        bg[0].save(gp, save_all=True, append_images=bg[1:], duration=int(dt * 1000),
                   loop=0, disposal=2)
        print(f"[ok] {sp}")
        print(f"[ok] {gp}")


def rawsheet(name, attempt, scale=3):
    base = Image.open(base_path(name)).convert("RGBA")
    d = attempt_dir(name, attempt)
    files = sorted([f for f in os.listdir(d) if re.match(r"^\d+\.png$", f)],
                   key=lambda f: int(f[:-4]))
    ims = [base] + [Image.open(os.path.join(d, f)).convert("RGBA") for f in files]
    w, h = base.size
    out = Image.new("RGBA", ((w + 4) * len(ims) * scale, h * scale), (40, 40, 48, 255))
    for i, im in enumerate(ims):
        b = im.resize((im.size[0] * scale, im.size[1] * scale), Image.NEAREST)
        out.paste(b, (i * (w + 4) * scale, 0), b)
    p = os.path.join(d, f"_raw_{scale}x.png")
    out.save(p)
    print(f"[ok] {p}")


def diffsheet(names, scale=4):
    for name in names:
        d = os.path.join(ANIM, name)
        if not os.path.isdir(d):
            print(f"[FAIL] {name}: sem pasta anim")
            continue
        files = sorted([f for f in os.listdir(d) if re.match(r"^\d+\.png$", f)],
                       key=lambda f: int(f[:-4]))
        frs = [rgba(os.path.join(d, f)) for f in files]
        f0 = frs[0]
        h, w = f0.shape[:2]
        tiles = [f0]
        for fr in frs[1:]:
            diff = np.zeros_like(f0)
            m = np.any(fr[:, :, :3] != f0[:, :, :3], axis=2) & (f0[:, :, 3] > 0)
            diff[:, :, 3] = (f0[:, :, 3] > 0) * 255
            diff[:, :, :3] = (f0[:, :, :3] * 0.35).astype(np.uint8)
            diff[m] = (255, 60, 200, 255)
            tiles.append(diff)
        out = Image.new("RGBA", ((w + 4) * len(tiles) * scale, h * scale), (40, 40, 48, 255))
        for i, t in enumerate(tiles):
            im = Image.fromarray(t).resize((w * scale, h * scale), Image.NEAREST)
            out.paste(im, (i * (w + 4) * scale, 0), im)
        od = os.path.join(OUT, name.split("_")[0])
        os.makedirs(od, exist_ok=True)
        sp = os.path.join(od, f"diff_{name}.png")
        out.save(sp)
        print(f"[ok] {sp}")


def snapped(name, attempt):
    base = rgba(base_path(name))
    frs = [f for f in frames_of(name, attempt) if f.shape == base.shape]
    pal = palette_of(base)
    return base, [snap_palette(f, pal) for f in frs]


def build(name, base, g, seq):
    return [base] + [delta(base, g[seq[0]], g[n], trunk_frac(name), name)[0] for n in seq[1:]]


GATE = {"embers": (0.30, 0.20)}


def score_seq(base, outs, cap=(0.07, 0.08)):
    bm = base[:, :, 3] > 0
    area = int(bm.sum())
    moved = [int((np.any(o[:, :, :3] != base[:, :, :3], axis=2) & bm).sum()) for o in outs[1:]]
    steps = [int((np.any(outs[i][:, :, :3] != outs[i + 1][:, :, :3], axis=2) & bm).sum())
             for i in range(len(outs) - 1)]
    mx = max(moved)
    ratio = max(steps) / max(1, mx)
    ok = (mx >= 0.012 * area and mx <= cap[0] * area and max(steps) <= cap[1] * area
          and sum(1 for st in steps if st < 0.2 * max(steps)) <= 1
          and 2 * sum(1 for st in steps if st >= 0.35 * max(steps)) >= len(steps))
    return ok, moved, steps, area, mx, ratio


def evaluate(name, attempt):
    import itertools
    base, g = snapped(name, attempt)
    best = None
    cache = {}
    for ref in range(1, len(g)):
        rest = list(range(ref + 1, len(g)))
        for k in range(min(len(rest), 6), 2, -1):
            for sub in itertools.combinations(rest, k):
                seq = (ref,) + sub
                outs = [base]
                for n in sub:
                    key = (ref, n)
                    if key not in cache:
                        cache[key] = delta(base, g[ref], g[n], trunk_frac(name), name)[0]
                    outs.append(cache[key])
                ok, moved, steps, area, mx, ratio = score_seq(base, outs, GATE.get(style_of(name), (0.07, 0.08)))
                score = (ok, len(seq), -abs(mx - 0.03 * area), -ratio)
                if best is None or score > best["score"]:
                    best = {"seq": list(seq), "ok": ok, "moved": moved, "steps": steps,
                            "area": area, "frac": round(mx / area, 4), "ratio": round(ratio, 3),
                            "score": score}
    return best


def candidate(name, attempt, seq, scale=3):
    base, g = snapped(name, attempt)
    outs = build(name, base, g, seq)
    bm = base[:, :, 3] > 0
    h, w = base.shape[:2]
    rowsimg = Image.new("RGBA", ((w + 4) * len(outs) * scale, h * 2 * scale + 4), (40, 40, 48, 255))
    for i, o in enumerate(outs):
        im = Image.fromarray(o).resize((w * scale, h * scale), Image.NEAREST)
        rowsimg.paste(im, (i * (w + 4) * scale, 0), im)
        prev = outs[i - 1] if i else outs[0]
        m = np.any(o[:, :, :3] != prev[:, :, :3], axis=2) & bm
        d = np.zeros_like(base)
        d[:, :, 3] = bm * 255
        d[:, :, :3] = (base[:, :, :3] * 0.35).astype(np.uint8)
        d[m] = (255, 60, 200, 255)
        im = Image.fromarray(d).resize((w * scale, h * scale), Image.NEAREST)
        rowsimg.paste(im, (i * (w + 4) * scale, h * scale + 4), im)
    od = os.path.join(OUT, name.split("_")[0])
    os.makedirs(od, exist_ok=True)
    sp = os.path.join(od, f"cand_{name}_{attempt}.png")
    rowsimg.save(sp)
    print(f"[ok] {sp}")


def texmem(names):
    total = 0
    for name in names:
        d = os.path.join(ANIM, name)
        if not os.path.isdir(d):
            continue
        files = [f for f in os.listdir(d) if f.endswith(".png")]
        w, h = Image.open(os.path.join(d, files[0])).size
        kb = w * h * 4 * len(files) / 1024
        total += kb
        print(f"{name}: {len(files)} quadros {w}x{h} = {kb:.0f} KB")
    print(f"TOTAL {total / 1024:.2f} MB")


def all_names():
    return [n for v in TREES.values() for n in v]


def expand(args):
    if not args:
        return all_names()
    out = []
    for a in args:
        out += TREES.get(a, [a])
    return out


def main():
    if len(sys.argv) < 2:
        print("uso: queue|poll|check|install|sheet|texmem|status")
        return 1
    cmd = sys.argv[1]
    rest = sys.argv[2:]
    kw = {}
    pos = []
    for a in rest:
        if a.startswith("--"):
            k, _, v = a[2:].partition("=")
            kw[k] = v
        else:
            pos.append(a)
    if cmd == "queue":
        queue(expand(pos), seed=int(kw["seed"]) if "seed" in kw else None,
              prompt_key=kw.get("prompt"), frames=int(kw.get("frames", FRAMES)),
              pin="pin" in kw, tool=kw.get("tool", "animate_image"))
    elif cmd == "poll":
        poll()
    elif cmd == "check":
        return 0 if check(expand(pos)) else 1
    elif cmd == "install":
        for spec in pos:
            name, att, seq = (spec.split(":") + ["", ""])[:3]
            seq = [int(x) for x in seq.split(",")] if seq else evaluate(name, int(att))["seq"]
            install(name, int(att), seq)
    elif cmd == "sheet":
        sheet(expand(pos), scale=int(kw.get("scale", 1)), dt=float(kw.get("dt", 0.15)))
    elif cmd == "rawsheet":
        for spec in pos:
            name, _, att = spec.partition(":")
            rawsheet(name, int(att) if att else max(int(x) for x in os.listdir(os.path.join(RAW, name))),
                     scale=int(kw.get("scale", 3)))
    elif cmd == "diffsheet":
        diffsheet(expand(pos), scale=int(kw.get("scale", 4)))
    elif cmd == "evaluate":
        for spec in pos:
            name, _, att = spec.partition(":")
            ev = evaluate(name, int(att))
            ev.pop("score", None)
            print(name, att, ev)
    elif cmd == "candidate":
        for spec in pos:
            name, att, seq = (spec.split(":") + ["", ""])[:3]
            seq = [int(x) for x in seq.split(",")] if seq else evaluate(name, int(att))["seq"]
            candidate(name, int(att), seq, scale=int(kw.get("scale", 3)))
    elif cmd == "texmem":
        texmem(expand(pos))
    elif cmd == "status":
        for k, j in load_jobs().items():
            print(f"{k}: {j['status']} prompt={j['prompt']} iou={j.get('iou_min')} tronco={j.get('trunk_min')}")
    return 0


if __name__ == "__main__":
    sys.exit(main() or 0)
