import base64
import json
import os
import re
import shutil
import sys
import threading
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixellab_enemy_anims as F
import pixellab_vida_c_specs as S

import numpy as np
from PIL import Image

ROOT = F.ROOT
OUT = os.path.join(ROOT, "tools/preview_out/vida_idle")
TRIES = os.path.join(OUT, "tries_c")
LOG = os.path.join(TRIES, "jobs.json")
LOCK = threading.Lock()
SLOTS = threading.Semaphore(3)


def b64(path):
    with open(path, "rb") as f:
        return base64.b64encode(f.read()).decode()


def idle0(eid):
    return F.idle_frame_path(eid)


def log(entry):
    with LOCK:
        os.makedirs(TRIES, exist_ok=True)
        data = []
        if os.path.exists(LOG):
            with open(LOG) as f:
                data = json.load(f)
        entry["t"] = time.strftime("%Y-%m-%d %H:%M:%S")
        data.append(entry)
        with open(LOG, "w") as f:
            json.dump(data, f, indent=1)


def submit(args):
    text = ""
    for _ in range(360):
        try:
            text = F.tool_text(F.rpc("tools/call", {"name": "animate_image", "arguments": args}, timeout=300))
        except Exception as e:
            text = str(e)
            time.sleep(20)
            continue
        m = re.search(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", text)
        if m:
            return m.group(0), text
        low = text.lower()
        if "rate limit" not in low and "concurrent" not in low and "too many" not in low:
            return None, text
        time.sleep(25)
    return None, text


def wait(job, dest):
    os.makedirs(dest, exist_ok=True)
    t0 = time.time()
    while time.time() - t0 < 7200:
        try:
            text = F.tool_text(F.rpc("tools/call", {"name": "get_image", "arguments": {"job_id": job}}))
        except Exception:
            time.sleep(15)
            continue
        low = text.lower()
        if "status: failed" in low or "status: error" in low:
            return None, text
        if "status: completed" in low:
            mN = re.search(r"frames:\s*(\d+)", text)
            mU = re.search(r"(https?://\S+/download)\?index=\d+", text)
            n = int(mN.group(1)) if mN else 1
            paths = []
            for i in range(n):
                url = f"{mU.group(1)}?index={i}"
                p = os.path.join(dest, f"{i}.png")
                for _ in range(5):
                    try:
                        data = F.fetch(url)
                        break
                    except Exception:
                        time.sleep(5)
                with open(p, "wb") as f:
                    f.write(data)
                paths.append(p)
            return paths, text
        time.sleep(15)
    return None, "timeout"


def load(p):
    return np.asarray(Image.open(p).convert("RGBA")).astype(np.int32)


def diff_frac(a, b):
    mask = (a[..., 3] > 0) | (b[..., 3] > 0)
    d = np.abs(a - b).max(axis=2) > 48
    return float((d & mask).sum()) / max(1, int(mask.sum()))


def bbox(a):
    ys, xs = np.nonzero(a[..., 3] > 0)
    if len(xs) == 0:
        return (0, 0, 0, 0)
    return (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)


def emissive_boxes(eid):
    with open(os.path.join(ROOT, "src/data/enemy_emissives.lua"), encoding="utf-8") as f:
        src = f.read()
    m = re.search(r"\n    " + eid + r" = \{(.*?)\n    \},", src, re.S)
    if not m:
        return []
    out = []
    for xr, yr, r in re.findall(r"xr = ([\d.]+), yr = ([\d.]+), r = ([\d.]+)", m.group(1))[:2]:
        out.append((float(xr), float(yr), float(r)))
    return out


def glow_count(a, boxes):
    h, w = a.shape[:2]
    tot = 0
    for xr, yr, r in boxes:
        cx, cy, rr = xr * w, yr * h, max(2.0, r * w)
        x0, x1 = int(max(0, cx - rr)), int(min(w, cx + rr + 1))
        y0, y1 = int(max(0, cy - rr)), int(min(h, cy + rr + 1))
        reg = a[y0:y1, x0:x1]
        rgb = reg[..., :3]
        sat = rgb.max(axis=2) - rgb.min(axis=2)
        tot += int(((rgb.max(axis=2) > 150) & (sat > 60) & (reg[..., 3] > 0)).sum())
    return tot


def palette_drift(base, frame):
    pal = np.unique(base[base[..., 3] > 0][:, :3], axis=0)
    px = frame[frame[..., 3] > 0][:, :3]
    if len(px) == 0 or len(pal) == 0:
        return 1.0
    best = np.full(len(px), 10 ** 9)
    for i in range(0, len(pal), 64):
        chunk = pal[i:i + 64]
        d = np.abs(px[:, None, :] - chunk[None, :, :]).sum(axis=2).min(axis=1)
        best = np.minimum(best, d)
    return float((best > 60).sum()) / len(px)


def metrics(eid, paths):
    base = load(idle0(eid))
    fr = [load(p) for p in paths]
    bb0 = bbox(base)
    h0, w0 = bb0[3] - bb0[1], bb0[2] - bb0[0]
    boxes = emissive_boxes(eid)
    g0 = glow_count(base, boxes) if boxes else 0
    steps = [diff_frac(fr[i], fr[i + 1]) for i in range(len(fr) - 1)]
    sizes = []
    glows = []
    pals = []
    for a in fr:
        b = bbox(a)
        sizes.append(max(abs((b[3] - b[1]) / max(1, h0) - 1), abs((b[2] - b[0]) / max(1, w0) - 1)))
        glows.append(glow_count(a, boxes) / g0 if g0 else 1.0)
        pals.append(palette_drift(base, a))
    edge = 0
    for a in fr:
        al = a[..., 3] > 0
        edge = max(edge, int(al[0].sum() + al[-1].sum() + al[:, 0].sum() + al[:, -1].sum()))
    return {"end": round(diff_frac(fr[-1], base), 3), "step_mean": round(float(np.mean(steps)), 3),
            "step_max": round(float(np.max(steps)), 3), "far": round(max(diff_frac(a, base) for a in fr), 3),
            "size": round(max(sizes), 3), "glow_min": round(min(glows), 2), "pal": round(max(pals), 3),
            "edge": edge}


def strip(paths, out, scale=4, mark=None, label=None):
    ims = [Image.open(p).convert("RGBA") for p in paths]
    cw = max(i.width for i in ims) * scale
    ch = max(i.height for i in ims) * scale
    gap = 6
    sheet = Image.new("RGBA", (len(ims) * (cw + gap) + gap, ch + 2 * gap), (58, 52, 50, 255))
    for n, im in enumerate(ims):
        x = gap + n * (cw + gap)
        if mark is not None and n == mark:
            sheet.paste((200, 40, 40, 255), (x - gap, 0, x - 1, sheet.height))
        sheet.alpha_composite(im.resize((im.width * scale, im.height * scale), Image.NEAREST), (x, gap))
    os.makedirs(os.path.dirname(out), exist_ok=True)
    sheet.save(out)


def prompt(eid, clip):
    c = S.C[eid]
    planted = S.PLANTED if c["grounded"] else ""
    if clip == "idle":
        return f"{c['idle']}. It keeps its {c['keep']}." + planted + S.IDLE_SUFFIX, c["idle_frames"]
    text, frames = c["fidgets"][clip]
    return f"{text}. It keeps its {c['keep']}." + planted + S.FIDGET_SUFFIX, frames


def try_dir(eid, clip):
    with LOCK:
        n = 1
        while os.path.isdir(os.path.join(TRIES, f"{eid}_{clip}_t{n}")):
            n += 1
        d = os.path.join(TRIES, f"{eid}_{clip}_t{n}")
        os.makedirs(d)
    return d, n


def anim(eid, clip, seed=None, extra=None):
    text, frames = prompt(eid, clip)
    if extra:
        text = extra + " " + text
    args = {"action": text[:1000], "first_frame_base64": b64(idle0(eid)),
            "last_frame_base64": b64(idle0(eid)), "frame_count": int(frames)}
    if seed is not None:
        args["seed"] = int(seed)
    with SLOTS:
        job, resp = submit(args)
        if not job:
            print(f"[FAIL] {eid}/{clip}: {resp[:300]}", flush=True)
            return
        d, n = try_dir(eid, clip)
        with open(os.path.join(d, "meta.json"), "w") as f:
            json.dump({"eid": eid, "clip": clip, "seed": seed, "frames": frames, "job": job, "prompt": text}, f,
                      indent=1)
        log({"eid": eid, "clip": clip, "seed": seed, "frames": frames, "job": job, "try": n})
        finish(d)


def finish(d):
    with open(os.path.join(d, "meta.json")) as f:
        meta = json.load(f)
    eid, clip, job = meta["eid"], meta["clip"], meta["job"]
    n = int(d.rsplit("_t", 1)[1])
    got, resp = wait(job, d)
    if not got:
        print(f"[FAIL] {eid}/{clip} t{n}: {resp[:300]}", flush=True)
        return
    m = metrics(eid, got)
    with open(os.path.join(d, "meta.json")) as f:
        meta = json.load(f)
    meta["metrics"] = m
    mc = re.search(r"charged:\s*(\d+)", resp or "")
    meta["charged"] = int(mc.group(1)) if mc else None
    with open(os.path.join(d, "meta.json"), "w") as f:
        json.dump(meta, f, indent=1)
    act = S.ACT[eid]
    strip(got + [idle0(eid)], os.path.join(TRIES, f"ato{act}", f"{eid}_{clip}_t{n}.png"), mark=len(got))
    print(f"[ok] {eid}/{clip} t{n}: {len(got)}q {json.dumps(m)}", flush=True)


def run(items, workers=3):
    queue = list(items)

    def worker():
        while True:
            with LOCK:
                if not queue:
                    return
                eid, clip, seed = queue.pop(0)
            try:
                anim(eid, clip, seed)
            except Exception as e:
                print(f"[FAIL] {eid}/{clip}: {e}", flush=True)

    ths = []
    for _ in range(workers):
        t = threading.Thread(target=worker)
        t.start()
        ths.append(t)
        time.sleep(3)
    for t in ths:
        t.join()


def fetch(names):
    ths = [threading.Thread(target=finish, args=(os.path.join(TRIES, x),)) for x in names]
    for t in ths:
        t.start()
    for t in ths:
        t.join()


def expand(args):
    items = []
    for a in args:
        if "/" in a:
            eid, clip = a.split("/", 1)
            seed = None
            if "@" in clip:
                clip, seed = clip.split("@")
            items.append((eid, clip, seed))
            continue
        ids = [e for e in S.C if str(S.ACT[e]) == a] if a.isdigit() else [a]
        for eid in ids:
            c = S.C[eid]
            if not c["boss"]:
                items.append((eid, "idle", None))
            for f in c["fidgets"]:
                items.append((eid, f, None))
    return items


def clip_dir(eid, clip):
    return F.anim_dir(eid, clip)


def install(eid, clip, n, fix=None):
    d = os.path.join(TRIES, f"{eid}_{clip}_t{n}")
    if fix and fix.get("as"):
        clip = fix["as"]
    files = sorted([x for x in os.listdir(d) if x.endswith(".png")], key=lambda s: int(s[:-4]))
    src = [os.path.join(d, x) for x in files]
    seq = src[:-1] if clip == "idle" else src
    if len(seq) > 12 and diff_frac(load(seq[0]), load(seq[1])) < 0.05:
        seq = [seq[0]] + seq[2:]
    dest = clip_dir(eid, clip)
    if clip != "idle" and os.path.isdir(dest):
        shutil.rmtree(dest)
    os.makedirs(dest, exist_ok=True)
    tmp = os.path.join(TRIES, f"_inst_{eid}_{clip}")
    if os.path.isdir(tmp):
        shutil.rmtree(tmp)
    os.makedirs(tmp)
    shutil.copyfile(idle0(eid), os.path.join(tmp, "0.png"))
    last = len(seq) - 1
    for i in range(1, len(seq)):
        out = os.path.join(tmp, f"{i}.png")
        if clip != "idle" and i == last:
            shutil.copyfile(idle0(eid), out)
        else:
            im = Image.open(seq[i]).convert("RGBA")
            if fix and str(i) in fix:
                im = Image.open(os.path.join(ROOT, fix[str(i)])).convert("RGBA")
            if fix and fix.get("erase"):
                a = np.asarray(im).copy()
                for bx in fix["erase"].split(";"):
                    x0, y0, x1, y1 = (int(v) for v in bx.split(","))
                    a[y0:y1, x0:x1] = 0
                im = Image.fromarray(a, "RGBA")
            if fix and fix.get("white"):
                im = fix_white(eid, im)
            if fix and fix.get("eyes"):
                im = fix_eyes(eid, im)
            if fix and fix.get("warm2green"):
                a = np.asarray(im).astype(np.int32).copy()
                warm = (a[..., 0] > a[..., 1] + 40) & (a[..., 3] > 0)
                m = np.zeros_like(warm)
                for bx in fix["warm2green"].split(";"):
                    x0, y0, x1, y1 = (int(v) for v in bx.split(","))
                    m[y0:y1, x0:x1] = warm[y0:y1, x0:x1]
                r = a[..., 0].copy()
                a[..., 0] = np.where(m, a[..., 1] // 2, a[..., 0])
                a[..., 1] = np.where(m, r, a[..., 1])
                a[..., 2] = np.where(m, (a[..., 2] + r // 3), a[..., 2])
                im = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")
            if fix and fix.get("lock"):
                for bx in fix["lock"].split(";"):
                    im = fix_lock(eid, im, tuple(int(v) for v in bx.split(",")))
            im.save(out)
    for x in os.listdir(dest):
        if x.endswith(".png") and x != "0.png":
            os.remove(os.path.join(dest, x))
    for x in os.listdir(tmp):
        if x != "0.png" or clip != "idle":
            shutil.copyfile(os.path.join(tmp, x), os.path.join(dest, x))
    shutil.rmtree(tmp)
    final_strip(eid, clip)
    print(f"[ok] instalado {eid}/{clip} t{n}: {len(seq)} quadros", flush=True)


def fix_white(eid, im):
    base = load(idle0(eid))
    a = np.asarray(im).astype(np.int32).copy()
    white = (a[..., :3].min(axis=2) > 190) & (a[..., 3] > 0)
    bw = (base[..., :3].min(axis=2) > 190) & (base[..., 3] > 0)
    near = np.zeros_like(bw)
    for dy in range(-3, 4):
        for dx in range(-3, 4):
            near |= np.roll(np.roll(bw, dy, 0), dx, 1)
    bad = white & ~near
    a[bad] = 0
    op = a[..., 3] > 0
    nb = np.zeros(op.shape, np.int32)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            if dx or dy:
                nb += np.roll(np.roll(op, dy, 0), dx, 1)
    a[op & (nb <= 1)] = 0
    return Image.fromarray(a.astype(np.uint8), "RGBA")


def glow_mask(a):
    rgb = a[..., :3]
    return (rgb.max(axis=2) > 150) & ((rgb.max(axis=2) - rgb.min(axis=2)) > 60) & (a[..., 3] > 0)


def fix_eyes(eid, im):
    base = load(idle0(eid))
    a = np.asarray(im).astype(np.int32).copy()
    h, w = base.shape[:2]
    for xr, yr, r in emissive_boxes(eid):
        cx, cy, rr = int(xr * w), int(yr * h), max(3, int(r * w))
        x0, x1, y0, y1 = max(0, cx - rr), min(w, cx + rr + 1), max(0, cy - rr), min(h, cy + rr + 1)
        hx0, hx1, hy0, hy1 = max(0, cx - 9), min(w, cx + 10), max(0, cy - 9), min(h, cy + 10)
        tpl = base[hy0:hy1, hx0:hx1]
        best, bd = None, None
        for dy in range(-5, 6):
            for dx in range(-5, 6):
                if hy0 + dy < 0 or hx0 + dx < 0 or hy1 + dy > h or hx1 + dx > w:
                    continue
                reg = a[hy0 + dy:hy1 + dy, hx0 + dx:hx1 + dx]
                d = int(np.abs(reg - tpl).sum())
                if bd is None or d < bd:
                    best, bd = (dx, dy), d
        if best is None:
            continue
        dx, dy = best
        src = base[y0:y1, x0:x1]
        m = glow_mask(src)
        ys, xs = np.nonzero(m)
        for yy, xx in zip(ys, xs):
            ty, tx = y0 + yy + dy, x0 + xx + dx
            if 0 <= ty < h and 0 <= tx < w and a[ty, tx, 3] > 0:
                a[ty, tx] = src[yy, xx]
    return Image.fromarray(a.astype(np.uint8), "RGBA")


def best_shift(base, a, box, r=5):
    x0, y0, x1, y1 = box
    h, w = base.shape[:2]
    tpl = base[y0:y1, x0:x1]
    best, bd = (0, 0), None
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            if y0 + dy < 0 or x0 + dx < 0 or y1 + dy > h or x1 + dx > w:
                continue
            reg = a[y0 + dy:y1 + dy, x0 + dx:x1 + dx]
            d = int(np.abs(reg - tpl).sum())
            if bd is None or d < bd:
                best, bd = (dx, dy), d
    return best


def fix_lock(eid, im, box):
    base = load(idle0(eid))
    a = np.asarray(im).astype(np.int32).copy()
    x0, y0, x1, y1 = box
    dx, dy = best_shift(base, a, box)
    src = base[y0:y1, x0:x1]
    m = src[..., 3] > 0
    tgt = a[y0 + dy:y1 + dy, x0 + dx:x1 + dx]
    tgt[m] = src[m]
    a[y0 + dy:y1 + dy, x0 + dx:x1 + dx] = tgt
    return Image.fromarray(a.astype(np.uint8), "RGBA")


def frames_of(eid, clip):
    dest = clip_dir(eid, clip)
    files = sorted([x for x in os.listdir(dest) if x.endswith(".png")], key=lambda s: int(s[:-4]))
    return [os.path.join(dest, x) for x in files]


def final_strip(eid, clip):
    paths = frames_of(eid, clip)
    act = S.ACT[eid]
    out = os.path.join(OUT, f"ato{act}", f"{eid}_{clip}.png")
    strip(paths + [paths[0]], out, mark=len(paths))
    print(out, flush=True)


def sheet(act):
    ids = [e for e in S.C if S.ACT[e] == int(act)]
    rows = [frames_of(e, "idle") for e in ids]
    scale = 2
    cw = max(Image.open(r[0]).width for r in rows) * scale
    ch = max(Image.open(r[0]).height for r in rows) * scale
    cols = max(len(r) for r in rows)
    gap = 6
    sh = Image.new("RGBA", (cols * (cw + gap) + gap, len(rows) * (ch + gap) + gap), (58, 52, 50, 255))
    for j, r in enumerate(rows):
        for i, p in enumerate(r):
            im = Image.open(p).convert("RGBA")
            sh.alpha_composite(im.resize((im.width * scale, im.height * scale), Image.NEAREST),
                               (gap + i * (cw + gap), gap + j * (ch + gap)))
    out = os.path.join(OUT, f"ato{act}", f"_folha_idle_ato{act}.png")
    sh.save(out)
    print(out, flush=True)


def report():
    rows = []
    for d in sorted(os.listdir(TRIES)):
        p = os.path.join(TRIES, d, "meta.json")
        if os.path.exists(p):
            with open(p) as f:
                m = json.load(f)
            rows.append(f"{d}: {json.dumps(m.get('metrics'))}")
    print("\n".join(rows), flush=True)


def main():
    cmd, rest = sys.argv[1], sys.argv[2:]
    if cmd == "run":
        w = 3
        pending = []
        while rest and "=" in rest[0]:
            k, v = rest[0].split("=", 1)
            if k == "workers":
                w = int(v)
            elif k == "fetch":
                pending = v.split(",")
            rest = rest[1:]
        ths = []
        for x in pending:
            def held(x=x):
                with SLOTS:
                    finish(os.path.join(TRIES, x))
            t = threading.Thread(target=held)
            t.start()
            ths.append(t)
        time.sleep(1)
        run(expand(rest), w)
        for t in ths:
            t.join()
    elif cmd == "fetch":
        fetch(rest)
    elif cmd == "install":
        fix = dict(a.split("=", 1) for a in rest[3:]) if len(rest) > 3 else None
        install(rest[0], rest[1], rest[2], fix)
    elif cmd == "strip":
        final_strip(rest[0], rest[1])
    elif cmd == "sheet":
        sheet(rest[0])
    elif cmd == "report":
        report()
    elif cmd == "metrics":
        print(json.dumps(metrics(rest[0], frames_of(rest[0], rest[1]))), flush=True)


if __name__ == "__main__":
    main()
