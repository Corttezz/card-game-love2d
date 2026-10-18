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
OUT = os.path.join(ROOT, "tools/preview_out/arvores_anim")
RAW = os.path.join(OUT, "raw")
JOBS = os.path.join(OUT, "jobs.json")

TREES = {
    "fields": ["fields_tree_%d" % i for i in range(6)],
    "highlands": ["highlands_pine_0", "highlands_pine_1", "highlands_pine_2", "highlands_deadtree_0"],
    "abyss": ["abyss_deadtree_0", "abyss_deadtree_1", "abyss_deadtree_2"],
    "frost": ["frost_pine_0", "frost_pine_1", "frost_pine_2", "frost_deadtree_0"],
    "marsh": ["marsh_deadtree_0", "marsh_deadtree_1", "marsh_deadtree_2"],
    "dusk": ["dusk_tree_0", "dusk_tree_1", "dusk_tree_2"],
}

FRAMES = 6
IOU_MIN = 0.97
TRUNK_MIN = 0.95
TRUNK_FRAC = 0.30
DEAD_FRAC = 0.008

STILL = (" The trunk, the roots and the outer outline of the whole tree stay "
         "completely still and identical in every frame. No camera movement, "
         "no zoom, no scaling, the tree never changes shape, size or position. "
         "Subtle idle loop that returns to the first frame.")

PROMPTS = {
    "leafy": ("Gentle breeze idle loop: only the leaves inside the crown rustle "
              "and shimmer very slightly, a few pixels, small leaf clusters "
              "shifting back and forth." + STILL),
    "pine": ("Gentle breeze idle loop: only the needle tips of the branches "
             "bob up and down very slightly, a few pixels, the layers of the "
             "crown breathing softly." + STILL),
    "snow": ("Gentle breeze idle loop: only the tips of the snow-laden branches "
             "bob very slightly, a few pixels, a few loose snowflakes drifting "
             "off the branches." + STILL),
    "dead": ("Gentle breeze idle loop: only the thinnest bare twigs at the ends "
             "of the branches quiver very slightly, one or two pixels, the "
             "thick branches and the trunk rigid." + STILL),
    "ember": ("Slow idle loop: the glowing ember cracks in the bark pulse "
              "softly brighter and dimmer and the thinnest twig tips quiver "
              "one pixel." + STILL),
    "moss": ("Gentle breeze idle loop: only the hanging strands of moss sway "
             "slowly side to side, a few pixels, and the thinnest twig tips "
             "quiver." + STILL),
}

STYLE = {
    "fields": "leafy", "dusk": "leafy",
    "highlands_pine": "pine", "frost_pine": "snow",
    "abyss": "ember", "marsh": "moss",
    "highlands_deadtree": "dead", "frost_deadtree": "dead",
}


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


def queue(names, seed=None, prompt_key=None, frames=FRAMES, pin=False):
    import base64
    jobs = load_jobs()
    for name in names:
        with open(base_path(name), "rb") as f:
            b64 = base64.b64encode(f.read()).decode()
        key = prompt_key or style_of(name)
        args = {"action": PROMPTS[key], "first_frame_base64": b64,
                "frame_count": frames}
        if pin:
            args["last_frame_base64"] = b64
        if seed is not None:
            args["seed"] = seed
        text = F.tool_text(F.rpc("tools/call", {"name": "animate_image",
                                                "arguments": args}))
        m = re.search(r"([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})", text)
        if not m:
            print(f"[FAIL] {name}: sem job id: {text[:200]}")
            continue
        att = next_attempt(name)
        os.makedirs(attempt_dir(name, att), exist_ok=True)
        jobs[f"{name}/{att}"] = {"name": name, "attempt": att, "job": m.group(1),
                                 "prompt": key, "seed": seed, "frames": frames, "pin": pin,
                                 "tool": "animate_image", "status": "queued",
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


def trunk_box(base):
    a = base[:, :, 3] > 0
    ys, xs = np.where(a)
    y0, y1 = ys.min(), ys.max()
    ty0 = int(y1 - (y1 - y0) * TRUNK_FRAC)
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
    ty0, ty1, tx0, tx1 = trunk_box(base)
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


def delta(base, g0, gi):
    bm = base[:, :, 3] > 0
    ty0 = trunk_box(base)[0]
    moved = ~np.all(gi == g0, axis=2)
    moved &= bm
    moved[ty0:, :] = False
    moved &= ~rim_of(bm)
    moved &= gi[:, :, 3] > 0
    out = base.copy()
    out[moved] = gi[moved]
    out[~bm] = 0
    return out, int(moved.sum())


def install(name, attempt, force=False):
    rows = measure(name, attempt)
    gate = all(r[1] >= IOU_MIN and r[2] >= TRUNK_MIN for r in rows)
    if not gate and not force:
        print(f"[FAIL] {name} tentativa {attempt}: reprovada no check, não instalada")
        return False
    base = rgba(base_path(name))
    frs = [f for f in frames_of(name, attempt) if f.shape == base.shape]
    pal = palette_of(base)
    g = [snap_palette(f, pal) for f in frs]
    outs = []
    counts = []
    for n in range(1, len(g)):
        out, c = delta(base, g[0], g[n])
        counts.append(c)
        outs.append(out)
    if max(counts) < DEAD_FRAC * int((base[:, :, 3] > 0).sum()) and not force:
        print(f"[FAIL] {name} tentativa {attempt}: animação morta ({counts} px), não instalada")
        return False
    dest = os.path.join(ANIM, name)
    if os.path.isdir(dest):
        shutil.rmtree(dest)
    os.makedirs(dest)
    shutil.copyfile(base_path(name), os.path.join(dest, "0.png"))
    for n, out in enumerate(outs, 1):
        Image.fromarray(out).save(os.path.join(dest, f"{n}.png"))
    print(f"[ok] {name}: {len(g)} quadros instalados em {dest} (px movidos por quadro {counts})")
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
              pin="pin" in kw)
    elif cmd == "poll":
        poll()
    elif cmd == "check":
        return 0 if check(expand(pos)) else 1
    elif cmd == "install":
        for spec in pos:
            name, _, att = spec.partition(":")
            install(name, int(att) if att else max(int(x) for x in os.listdir(os.path.join(RAW, name))),
                    force="force" in kw)
    elif cmd == "sheet":
        sheet(expand(pos), scale=int(kw.get("scale", 1)), dt=float(kw.get("dt", 0.15)))
    elif cmd == "rawsheet":
        for spec in pos:
            name, _, att = spec.partition(":")
            rawsheet(name, int(att) if att else max(int(x) for x in os.listdir(os.path.join(RAW, name))),
                     scale=int(kw.get("scale", 3)))
    elif cmd == "texmem":
        texmem(expand(pos))
    elif cmd == "status":
        for k, j in load_jobs().items():
            print(f"{k}: {j['status']} prompt={j['prompt']} iou={j.get('iou_min')} tronco={j.get('trunk_min')}")
    return 0


if __name__ == "__main__":
    sys.exit(main() or 0)
