#!/usr/bin/env python3
import base64
import json
import os
import re
import shutil
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixellab_enemy_anims as F  # noqa: E402
from pixellab_vida_art1_specs import SPECS, SUFFIX, ACTS  # noqa: E402

from PIL import Image  # noqa: E402

ROOT = F.ROOT
OUT = os.path.join(ROOT, "tools/preview_out/vida_idle")
RAW = os.path.join(OUT, "raw_art1")
JOBS = os.environ.get("VIDA_JOBS") or os.path.join(OUT, "jobs_art1.json")
SLOTS = int(os.environ.get("VIDA_SLOTS", "3"))
MAX_TRIES = 3


def act_of(eid):
    for a, ids in ACTS.items():
        if eid in ids:
            return a
    return 0


def idle0_path(eid):
    return F.idle_frame_path(eid)


def idle0(eid):
    return Image.open(idle0_path(eid)).convert("RGBA")


def load_jobs():
    if os.path.exists(JOBS):
        with open(JOBS) as f:
            return json.load(f)
    return {}


def save_jobs(j):
    os.makedirs(OUT, exist_ok=True)
    tmp = JOBS + ".tmp"
    with open(tmp, "w") as f:
        json.dump(j, f, indent=1)
    os.replace(tmp, JOBS)


def b64file(p):
    with open(p, "rb") as f:
        return base64.b64encode(f.read()).decode()


def spec_of(eid, clip):
    s = SPECS[eid]
    if clip == "idle":
        return s["idle"]
    if clip.startswith("state_"):
        return s["states"][clip]
    return s["fidgets"][clip]


def clips_of(eid):
    s = SPECS[eid]
    out = []
    if s.get("idle"):
        out.append("idle")
    out += list(s.get("fidgets", {}).keys())
    out += list(s.get("states", {}).keys())
    return out


def submit(eid, clip, seed):
    sp = spec_of(eid, clip)
    tool = sp.get("tool", "animate_image")
    text = f"{sp['action']}. It keeps its {SPECS[eid]['keep']}." + SUFFIX
    first = idle0_path(eid)
    if tool == "animate_image_pixminimax":
        args = {"description": text[:1000], "first_frame_base64": b64file(first),
                "frame_count": sp["frames"], "no_background": True,
                "direction": "south", "view": "side"}
    else:
        args = {"action": text[:1000], "first_frame_base64": b64file(first),
                "frame_count": sp["frames"]}
    args["last_frame_base64"] = b64file(first)
    if seed is not None:
        args["seed"] = int(seed)
    try:
        t = F.tool_text(F.rpc("tools/call", {"name": tool, "arguments": args}))
    except Exception as e:
        return None, str(e)
    m = re.search(r"([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})", t)
    return (m.group(1) if m else None), t


def poll(job, dest):
    try:
        t = F.tool_text(F.rpc("tools/call", {"name": "get_image", "arguments": {"job_id": job}}))
    except Exception:
        return "wait"
    low = t.lower()
    if "status: failed" in low or "status: error" in low:
        return "error"
    if "status: completed" not in low:
        return "wait"
    mN = re.search(r"frames:\s*(\d+)", t)
    mU = re.search(r"(https?://\S+/download)\?index=\d+", t)
    if not (mN and mU):
        return "error"
    os.makedirs(dest, exist_ok=True)
    for i in range(int(mN.group(1))):
        with open(os.path.join(dest, f"{i}.png"), "wb") as f:
            f.write(F.fetch(f"{mU.group(1)}?index={i}"))
    return "done"


def frames_in(d):
    return [os.path.join(d, f) for f in sorted([f for f in os.listdir(d) if f.endswith(".png")],
                                               key=lambda f: int(f[:-4]))]


def palette(im):
    cols = {}
    for p in im.getdata():
        if p[3] >= 128:
            cols[p[:3]] = cols.get(p[:3], 0) + 1
    return list(cols.keys())


def nearest(c, pal, cache):
    r = cache.get(c)
    if r is None:
        r = min(pal, key=lambda q: (q[0] - c[0]) ** 2 + (q[1] - c[1]) ** 2 + (q[2] - c[2]) ** 2)
        cache[c] = r
    return r


def settle(eid, im, ref, pal, cache, tol=26):
    im = im.convert("RGBA")
    if im.size != ref.size:
        im = im.resize(ref.size, Image.NEAREST)
    a = im.load()
    b = ref.load()
    w, h = ref.size
    out = Image.new("RGBA", ref.size, (0, 0, 0, 0))
    o = out.load()
    for y in range(h):
        for x in range(w):
            p = a[x, y]
            q = b[x, y]
            if p[3] < 128:
                continue
            if q[3] >= 128 and max(abs(p[i] - q[i]) for i in range(3)) <= tol:
                o[x, y] = q
            else:
                n = nearest(p[:3], pal, cache)
                o[x, y] = (n[0], n[1], n[2], 255)
    return out


def diff_frac(a, b):
    pa, pb = a.load(), b.load()
    w, h = a.size
    tot = d = 0
    for y in range(h):
        for x in range(w):
            p, q = pa[x, y], pb[x, y]
            if p[3] < 8 and q[3] < 8:
                continue
            tot += 1
            if (p[3] >= 128) != (q[3] >= 128) or max(abs(p[i] - q[i]) for i in range(3)) > 48:
                d += 1
    return d / max(1, tot)


def eyes_of(eid):
    src = open(os.path.join(ROOT, "src/data/enemy_emissives.lua"), encoding="utf-8").read()
    m = re.search(r"\n    " + eid + r" = \{(.*?)\n    \},", src, re.S)
    if not m:
        return []
    out = []
    for e in re.finditer(r"xr = ([\d.]+), yr = ([\d.]+), r = ([\d.]+)", m.group(1)):
        out.append(tuple(float(v) for v in e.groups()))
    return out


def glow(im, xr, yr, r):
    w, h = im.size
    cx, cy, rr = xr * w, yr * h, max(2.0, r * h)
    px = im.load()
    best = 0
    for y in range(max(0, int(cy - rr)), min(h, int(cy + rr) + 1)):
        for x in range(max(0, int(cx - rr)), min(w, int(cx + rr) + 1)):
            p = px[x, y]
            if p[3] < 128:
                continue
            v = max(p[:3]) + (max(p[:3]) - min(p[:3])) * 0.5
            best = max(best, v)
    return best


def metrics(eid, ims):
    ref = idle0(eid)
    rb = ref.getbbox()
    rw, rh = rb[2] - rb[0], rb[3] - rb[1]
    eyes = eyes_of(eid)
    g0 = [glow(ref, *e) for e in eyes]
    probs = []
    worst_size = 1.0
    worst_eye = 1.0
    for i, im in enumerate(ims[1:-1], start=1):
        bb = im.getbbox()
        if not bb:
            probs.append(f"vazio {i}")
            continue
        s = min((bb[3] - bb[1]) / rh, (bb[2] - bb[0]) / rw)
        s2 = max((bb[3] - bb[1]) / rh, (bb[2] - bb[0]) / rw)
        if abs(1 - s) > abs(1 - worst_size):
            worst_size = s
        if abs(1 - s2) > abs(1 - worst_size):
            worst_size = s2
        for k, e in enumerate(eyes):
            if g0[k] > 0:
                worst_eye = min(worst_eye, glow(im, *e) / g0[k])
    if abs(1 - worst_size) > 0.12:
        probs.append(f"tamanho {worst_size:.2f}")
    if worst_eye < 0.75:
        probs.append(f"olho {worst_eye:.2f}")
    steps = [diff_frac(ims[i], ims[i + 1]) for i in range(len(ims) - 1)]
    mx = max(steps) if steps else 0
    tot = max(diff_frac(ref, im) for im in ims)
    if tot < 0.015:
        probs.append("parado")
    if mx > 0.45:
        probs.append(f"chuvisco {mx:.2f}")
    end = diff_frac(ref, ims[-1])
    if end > 0.30:
        probs.append(f"fim {end:.2f}")
    return dict(size=round(worst_size, 3), eye=round(worst_eye, 3), step=round(mx, 3),
                motion=round(tot, 3), end=round(end, 3), problems=probs)


def process(eid, clip, raw_dir):
    ref = idle0(eid)
    pal = palette(ref)
    cache = {}
    files = frames_in(raw_dir)
    ims = [ref] + [settle(eid, Image.open(p), ref, pal, cache) for p in files[1:]]
    sd = raw_dir + "_s"
    os.makedirs(sd, exist_ok=True)
    for i, im in enumerate(ims):
        im.save(os.path.join(sd, f"{i}.png"))
    m = metrics(eid, ims)
    return m, sd


def tries_dir(eid, clip, n):
    return os.path.join(RAW, eid, f"{clip}_t{n}")


def strip_paths(paths, out, scale=4, mark=None, label=None):
    ims = [Image.open(p).convert("RGBA") for p in paths]
    cw = max(i.width for i in ims) * scale
    ch = max(i.height for i in ims) * scale
    gap = 6
    cols = len(ims)
    sheet = Image.new("RGBA", (cols * (cw + gap) + gap, ch + 2 * gap), (58, 52, 50, 255))
    for i, im in enumerate(ims):
        big = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
        sheet.paste(big, (gap + i * (cw + gap) + (cw - big.width) // 2, gap + ch - big.height), big)
    if mark is not None:
        x = gap + mark * (cw + gap) - gap // 2
        for y in range(sheet.height):
            sheet.putpixel((x, y), (220, 60, 60, 255))
    os.makedirs(os.path.dirname(out), exist_ok=True)
    sheet.save(out)
    return out


def finish(eid, clip, n, job):
    m, sd = process(eid, clip, tries_dir(eid, clip, n))
    p = frames_in(sd)
    out = os.path.join(OUT, f"ato{act_of(eid)}", "tries", f"{eid}_{clip}_t{n}.png")
    strip_paths(p + [idle0_path(eid)], out, mark=len(p))
    return m


def run(ids):
    todo = []
    for e in ids:
        if "/" in e:
            todo.append(tuple(e.split("/")))
        else:
            todo += [(e, c) for c in clips_of(e)]
    t0 = time.time()
    while time.time() - t0 < 12 * 3600:
        jobs = load_jobs()
        pend = []
        for e, c in todo:
            st = jobs.get(f"{e}/{c}", {})
            if st.get("status") != "pending":
                continue
            n = len(st.get("tries", [])) + 1
            r = poll(st["job"], tries_dir(e, c, n))
            if r == "wait":
                pend.append((e, c))
                continue
            jobs = load_jobs()
            st = jobs[f"{e}/{c}"]
            if r == "error":
                tr = st.get("tries", []) + [dict(job=st["job"], error=True)]
                status = "failed" if len(tr) >= MAX_TRIES else "retry"
            else:
                m = finish(e, c, n, st["job"])
                tr = st.get("tries", []) + [dict(job=st["job"], n=n, **m)]
                bad = [p for p in m["problems"] if not p.startswith(("olho", "chuvisco"))]
                status = "retry" if bad and len(tr) < MAX_TRIES else "review"
                print(f"[t{n}] {e}/{c} {m}", flush=True)
            jobs[f"{e}/{c}"] = dict(status=status, tries=tr)
            save_jobs(jobs)
        jobs = load_jobs()
        wait = [(e, c) for e, c in todo if jobs.get(f"{e}/{c}", {}).get("status") in (None, "retry")]
        for e, c in wait[:max(0, SLOTS - len(pend))]:
            st = jobs.get(f"{e}/{c}", {})
            tr = st.get("tries", [])
            seed = None if not tr else 3000 + 131 * len(tr)
            job, txt = submit(e, c, seed)
            if not job:
                print(f"[submit] {e}/{c}: {txt[:160]}", flush=True)
                time.sleep(20)
                break
            jobs = load_jobs()
            jobs[f"{e}/{c}"] = dict(status="pending", job=job, tries=tr)
            save_jobs(jobs)
            pend.append((e, c))
            print(f"[run] {e}/{c} job {job} t{len(tr) + 1}", flush=True)
            time.sleep(2)
        if not pend and not wait:
            break
        time.sleep(12)
    print("[run] fim", flush=True)


def again(key):
    jobs = load_jobs()
    st = jobs.get(key, {})
    st["status"] = "retry"
    jobs[key] = st
    save_jobs(jobs)


def anim_dir(eid, clip):
    return os.path.join(ROOT, "assets/sprites/characters/enemies", eid, "animations", clip, "south")


def install(eid, clip, n):
    sd = tries_dir(eid, clip, int(n)) + "_s"
    files = frames_in(sd)
    if clip == "idle":
        files = files[:-1]
    dest = anim_dir(eid, clip)
    if os.path.isdir(dest) and clip != "idle":
        shutil.rmtree(dest)
    if clip == "idle":
        bak = os.path.join(RAW, eid, "idle_before")
        if not os.path.isdir(bak):
            shutil.copytree(dest, bak)
        for f in os.listdir(dest):
            if f.endswith(".png") and f != "0.png":
                os.remove(os.path.join(dest, f))
    os.makedirs(dest, exist_ok=True)
    src0 = os.path.join(RAW, eid, "idle0.png")
    if not os.path.exists(src0):
        shutil.copyfile(idle0_path(eid), src0)
    for i, f in enumerate(files):
        if i == 0:
            if clip != "idle":
                shutil.copyfile(src0, os.path.join(dest, "0.png"))
            continue
        shutil.copyfile(f, os.path.join(dest, f"{i}.png"))
    if clip != "idle":
        shutil.copyfile(src0, os.path.join(dest, f"{len(files) - 1}.png"))
    jobs = load_jobs()
    st = jobs.get(f"{eid}/{clip}", {})
    st["status"] = "installed"
    st["installed"] = int(n)
    jobs[f"{eid}/{clip}"] = st
    save_jobs(jobs)
    strip(eid, clip)


def strip(eid, clip):
    d = anim_dir(eid, clip)
    p = frames_in(d)
    out = os.path.join(OUT, f"ato{act_of(eid)}", f"{eid}_{clip}.png")
    strip_paths(p + [idle0_path(eid)], out, mark=len(p))
    print(out)


def sheet(act):
    rows = []
    for eid in ACTS[act]:
        p = frames_in(anim_dir(eid, "idle"))
        rows.append([Image.open(x).convert("RGBA") for x in p])
    scale = 2
    cw = max(i.width for r in rows for i in r) * scale
    ch = max(i.height for r in rows for i in r) * scale
    cols = max(len(r) for r in rows)
    gap = 4
    sh = Image.new("RGBA", (cols * (cw + gap) + gap, len(rows) * (ch + gap) + gap), (58, 52, 50, 255))
    for j, r in enumerate(rows):
        for i, im in enumerate(r):
            big = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
            sh.paste(big, (gap + i * (cw + gap) + (cw - big.width) // 2, gap + j * (ch + gap) + ch - big.height), big)
    out = os.path.join(OUT, f"ato{act}", f"ato{act}_idle_sheet.png")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    sh.save(out)
    print(out)


def _num(v):
    s = f"{v:.2f}"
    return s


def _fx_lua(fx, ind):
    out = []
    for f in fx:
        parts = [f'kind = "{f["kind"]}"', f"xr = {_num(f['xr'])}", f"yr = {_num(f['yr'])}"]
        if "rate" in f:
            parts.append(f"rate = {_num(f['rate'])}")
        if "spread" in f:
            parts.append(f"spread = {_num(f['spread'])}")
        if "tint" in f:
            parts.append("tint = { " + ", ".join(_num(c) for c in f["tint"]) + " }")
        if "dir" in f:
            parts.append(f'dir = "{f["dir"]}"')
        out.append(ind + "{ " + ", ".join(parts) + " },")
    return out


def life(eid):
    from pixellab_vida_art1_specs import FX, BOSSES, STATE_FX
    base = os.path.join(ROOT, "assets/sprites/characters/enemies", eid, "animations")
    have = set(os.listdir(base))
    L = ["return {", "    fidgets = {"]
    fids = [c for c in SPECS[eid].get("fidgets", {}) if c in have]
    for i, c in enumerate(fids):
        n = len(frames_in(anim_dir(eid, c)))
        fps = 12 if n <= 9 else 10
        L.append(f'        {{ clip = "{c}", fps = {fps}, weight = {2 if i == 0 else 1} }},')
    L.append("    },")
    gap = (5.0, 10.0) if eid in BOSSES else (3.5, 8.0)
    L.append(f"    gap = {{ {gap[0]:.1f}, {gap[1]:.1f} }},")
    fx = FX.get(eid, [])
    if fx:
        L.append("    fx = {")
        L += _fx_lua(fx, "        ")
        L.append("    },")
    sts = [c for c in SPECS[eid].get("states", {}) if c in have]
    if sts:
        L.append("    states = {")
        for c in sts:
            key = c[len("state_"):]
            sfx = STATE_FX.get(eid, {}).get(key)
            if sfx:
                L.append(f'        {key} = {{ clip = "{c}", fps = 8, fx = {{')
                L += _fx_lua(sfx, "            ")
                L.append("        } },")
            else:
                L.append(f'        {key} = {{ clip = "{c}", fps = 8 }},')
        L.append("    },")
    L.append("}")
    p = os.path.join(ROOT, "src/data/enemy_life", f"{eid}.lua")
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(L) + "\n")
    print(p)


def status():
    for k, v in sorted(load_jobs().items()):
        last = v.get("tries", [{}])[-1] if v.get("tries") else {}
        print(k, v.get("status"), len(v.get("tries", [])), last.get("problems"), v.get("installed"))


def main(a):
    cmd = a[0]
    if cmd == "run":
        ids = []
        for x in a[1:] or ["1", "2"]:
            ids += ACTS[int(x)] if x.isdigit() else [x]
        run(ids)
    elif cmd == "again":
        for k in a[1:]:
            again(k)
    elif cmd == "install":
        install(a[1], a[2], a[3])
    elif cmd == "strip":
        strip(a[1], a[2])
    elif cmd == "sheet":
        sheet(int(a[1]))
    elif cmd == "status":
        status()
    elif cmd == "life":
        for e in a[1:]:
            life(e)
    elif cmd == "reprocess":
        e, c, n = a[1], a[2], int(a[3])
        print(finish(e, c, n, None))


if __name__ == "__main__":
    main(sys.argv[1:])
