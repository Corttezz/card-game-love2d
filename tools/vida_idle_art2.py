import base64
import json
import os
import re
import shutil
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib
import pixellab_enemy_anims as F
import vida_idle_art2_specs as SP
import vida_idle_art2_states as ST
from vida_idle_art2_specs import SPECS

ST.attach(SPECS)

from PIL import Image, ImageDraw

ROOT = F.ROOT
OUT = os.path.join(ROOT, "tools/preview_out/vida_idle")
RAW = os.environ.get("VIDA_ART2_RAW") or os.path.join(OUT, "raw_art2")
JOBS = os.path.join(RAW, "jobs.json")
INBOX = os.path.join(RAW, "inbox")
SLOTS = int(os.environ.get("VIDA_ART2_SLOTS", "3"))
LIFE_DIR = os.path.join(ROOT, "src/data/enemy_life")


def emissives():
    path = os.path.join(ROOT, "src/data/enemy_emissives.lua")
    src = open(path, encoding="utf-8").read()
    out = {}
    for m in re.finditer(r"\n    (\w+) = \{(.*?)\n    \},", src, re.S):
        pts = [(float(a), float(b), float(c)) for a, b, c in
               re.findall(r"xr = ([\d.]+), yr = ([\d.]+), r = ([\d.]+)", m.group(2))]
        out[m.group(1)] = pts
    return out


EMI = emissives()


def idle0_path(eid):
    return F.idle_frame_path(eid)


def idle0(eid):
    return Image.open(idle0_path(eid)).convert("RGBA")


def b64(path):
    with open(path, "rb") as f:
        return base64.b64encode(f.read()).decode()


def load_jobs():
    if os.path.exists(JOBS):
        with open(JOBS) as f:
            return json.load(f)
    return []


def save_jobs(jobs):
    os.makedirs(RAW, exist_ok=True)
    tmp = JOBS + ".tmp"
    with open(tmp, "w") as f:
        json.dump(jobs, f, indent=1)
    os.replace(tmp, JOBS)


def clip_spec(eid, clip):
    s = SPECS[eid]
    if clip == "idle":
        return s["idle"]
    if clip.startswith("state_"):
        return s["states"][clip]
    return s["fidgets"][clip]


def prompt(eid, clip, extra=""):
    importlib.reload(SP)
    importlib.reload(ST)
    SPECS.clear()
    SPECS.update(ST.attach(SP.SPECS))
    IDLE_TAIL, FIDGET_TAIL, FLOAT_TAIL = SP.IDLE_TAIL, SP.FIDGET_TAIL, SP.FLOAT_TAIL
    s = SPECS[eid]
    sp = clip_spec(eid, clip)
    keep = F.ENEMIES.get(eid, {}).get("keep", "")
    if clip == "idle":
        tail = FLOAT_TAIL if s.get("float") else IDLE_TAIL
    elif clip.startswith("state_"):
        tail = ST.STATE_TAIL.replace(" feet planted.", " floating.") if s.get("float") else ST.STATE_TAIL
    else:
        tail = FIDGET_TAIL
    txt = sp["action"] + (". " + extra if extra else "") + ". It keeps its " + keep + "." + tail
    return txt[:1000]


def try_dir(eid, clip, t):
    return os.path.join(RAW, eid, clip, f"t{t}")


def submit(task):
    eid, clip = task["eid"], task["clip"]
    sp = clip_spec(eid, clip)
    args = {"action": prompt(eid, clip, task.get("extra", "")),
            "first_frame_base64": b64(idle0_path(eid)),
            "last_frame_base64": b64(idle0_path(eid)),
            "frame_count": task.get("frames") or sp["frames"],
            "seed": task["seed"]}
    name = "animate_image"
    if task.get("tool") == "pmm":
        name = "animate_image_pixminimax"
        fc = args.pop("frame_count")
        args["frame_count"] = max(4, (fc + 3) // 4 * 4)
        args["description"] = args.pop("action")
        args["direction"] = "south"
        args["view"] = "side"
        keep = F.ENEMIES.get(eid, {}).get("keep", "")
        if keep:
            args["subject_description"] = keep[:300]
    text = F.tool_text(F.rpc("tools/call", {"name": name, "arguments": args}))
    m = re.search(r"([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})", text)
    if not m:
        return None, text[:300]
    return m.group(1), ""


def poll(task):
    try:
        text = F.tool_text(F.rpc("tools/call", {"name": "get_image", "arguments": {"job_id": task["job"]}}))
    except Exception as e:
        return "wait", str(e)
    low = text.lower()
    if "status: failed" in low or "status: error" in low:
        return "error", text[:300]
    if "status: completed" not in low:
        return "wait", ""
    mN = re.search(r"frames:\s*(\d+)", text)
    mURL = re.search(r"(https?://\S+/download)\?index=\d+", text)
    if not (mN and mURL):
        return "error", text[:300]
    n, base = int(mN.group(1)), mURL.group(1)
    d = try_dir(task["eid"], task["clip"], task["t"])
    os.makedirs(d, exist_ok=True)
    for i in range(n):
        with open(os.path.join(d, f"{i}.png"), "wb") as f:
            f.write(F.fetch(f"{base}?index={i}"))
    return "done", ""


def frames_in(d):
    fs = sorted([f for f in os.listdir(d) if f.endswith(".png") and f[:-4].isdigit()], key=lambda f: int(f[:-4]))
    return [Image.open(os.path.join(d, f)).convert("RGBA") for f in fs]


def palette(im):
    return sorted(set(p[:3] for p in im.get_flattened_data() if p[3] >= 128))


def snap(im, pal, cache):
    im = im.copy()
    px = im.load()
    w, h = im.size
    far = 0
    tot = 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 128:
                px[x, y] = (0, 0, 0, 0)
                continue
            tot += 1
            k = (r, g, b)
            c = cache.get(k)
            if c is None:
                best = None
                bd = 1e9
                for q in pal:
                    dd = (q[0] - r) ** 2 + (q[1] - g) ** 2 + (q[2] - b) ** 2
                    if dd < bd:
                        bd, best = dd, q
                c = (best, bd)
                cache[k] = c
            if c[1] > 40 * 40:
                far += 1
            px[x, y] = (c[0][0], c[0][1], c[0][2], 255)
    return im, far / max(1, tot)


def diff(a, b, thr=48):
    pa, pb = a.load(), b.load()
    w, h = a.size
    n = t = 0
    for y in range(h):
        for x in range(w):
            p, q = pa[x, y], pb[x, y]
            if p[3] < 8 and q[3] < 8:
                continue
            t += 1
            if abs(p[3] - q[3]) > 40 or max(abs(p[i] - q[i]) for i in range(3)) > thr:
                n += 1
    return n / max(1, t)


def lum(p):
    return 0.3 * p[0] + 0.59 * p[1] + 0.11 * p[2]


def eye_lum(im, eid, idx):
    w, h = im.size
    pts = EMI.get(eid, [])
    if idx >= len(pts):
        return None
    xr, yr, r = pts[idx]
    cx, cy = xr * w, yr * h
    rad = max(3, r * h) + 2
    px = im.load()
    best = 0
    for y in range(int(cy - rad), int(cy + rad) + 1):
        for x in range(int(cx - rad), int(cx + rad) + 1):
            if 0 <= x < w and 0 <= y < h and px[x, y][3] > 128:
                best = max(best, lum(px[x, y]))
    return best


def low_row(im):
    bb = im.getbbox()
    return bb[3] if bb else 0


def metrics(eid, clip, ims):
    ref = idle0(eid)
    rb = ref.getbbox()
    rh = rb[3] - rb[1]
    m = {}
    m["end"] = round(diff(ims[-1], ref), 3)
    mov = [diff(ims[i], ims[i + 1], 24) for i in range(len(ims) - 1)]
    m["motion"] = round(sum(mov) / max(1, len(mov)), 3)
    m["maxdev"] = round(max(diff(im, ref) for im in ims[1:-1]), 3) if len(ims) > 2 else 0
    hs = [(im.getbbox()[3] - im.getbbox()[1]) / rh for im in ims if im.getbbox()]
    m["h"] = [round(min(hs), 2), round(max(hs), 2)]
    lows = [low_row(im) for im in ims]
    m["feet"] = [min(lows) - rb[3], max(lows) - rb[3]]
    eyes = []
    for idx in SPECS[eid].get("eyes", []):
        e0 = eye_lum(ref, eid, idx)
        if e0:
            eyes.append(round(min((eye_lum(im, eid, idx) or 0) for im in ims[1:-1]) / e0, 2) if len(ims) > 2 else 1)
    m["eyes"] = eyes
    from PIL import ImageFilter
    sil = ref.getchannel("A").point(lambda v: 255 if v >= 128 else 0).filter(ImageFilter.MaxFilter(9))
    base = sum(1 for v in ref.getchannel("A").get_flattened_data() if v >= 128)
    outs = []
    for im in ims[1:-1]:
        a = im.getchannel("A").get_flattened_data()
        s = sil.get_flattened_data()
        outs.append(sum(1 for x, y in zip(a, s) if x >= 128 and y == 0) / max(1, base))
    m["out"] = round(max(outs), 3) if outs else 0
    if clip == "idle" and len(ims) > 2:
        m["seam"] = round(diff(ims[-2], ref, 24), 3)
    return m


def processed(eid, clip, t):
    d = try_dir(eid, clip, t)
    ims = frames_in(d)
    ref = idle0(eid)
    pal = palette(ref)
    cache = {}
    out = [ref]
    fars = []
    for im in ims[1:]:
        if im.size != ref.size:
            im = im.resize(ref.size, Image.NEAREST)
        s, far = snap(im, pal, cache)
        for fx in SP.FIXUPS.get((eid, clip, t), []):
            if len(fx) > 2 and len(out) not in fx[2]:
                continue
            s = fixup(s, ref, fx[:2])
        out.append(s)
        fars.append(far)
    return out, (round(max(fars), 3) if fars else 0)


def transplant(im, ref, box, pad=10, rng=3):
    x0, y0, x1, y1 = box
    w, h = ref.size
    px, rp = im.load(), ref.load()
    best = None
    for dy in range(-rng, rng + 1):
        for dx in range(-rng, rng + 1):
            err = 0
            for y in range(max(0, y0 - pad), min(h, y1 + pad), 2):
                for x in range(max(0, x0 - pad), min(w, x1 + pad), 2):
                    if x0 <= x < x1 and y0 <= y < y1:
                        continue
                    sx, sy = x + dx, y + dy
                    if not (0 <= sx < w and 0 <= sy < h):
                        continue
                    a, b = rp[x, y], px[sx, sy]
                    err += abs(a[0] - b[0]) + abs(a[1] - b[1]) + abs(a[2] - b[2]) + abs(a[3] - b[3])
            if best is None or err < best[0]:
                best = (err, dx, dy)
    _, dx, dy = best
    im = im.copy()
    px = im.load()
    for y in range(y0, y1):
        for x in range(x0, x1):
            sx, sy = x + dx, y + dy
            if 0 <= sx < w and 0 <= sy < h and rp[x, y][3] >= 128:
                px[sx, sy] = rp[x, y]
    return im


def fixup(im, ref, fx):
    kind, (x0, y0, x1, y1) = fx
    if kind == "transplant":
        return transplant(im, ref, (x0, y0, x1, y1))
    im = im.copy()
    px, rp = im.load(), ref.load()
    cap = max(lum(rp[x, y]) for y in range(y0, y1) for x in range(x0, x1) if rp[x, y][3] >= 128) + 6
    for y in range(y0, y1):
        for x in range(x0, x1):
            r, g, b, a = px[x, y]
            if kind == "unflame":
                hot = r > 120 and b < 110 and r > b * 1.8
                if a >= 128 and px[x, y] != rp[x, y] and (hot or rp[x, y][3] < 128):
                    px[x, y] = rp[x, y]
            elif kind == "unglow":
                if a >= 128 and lum((r, g, b)) > cap:
                    px[x, y] = rp[x, y]
            elif kind == "erase_new":
                if a >= 128 and rp[x, y][3] < 128:
                    px[x, y] = (0, 0, 0, 0)
            elif kind == "restore":
                px[x, y] = rp[x, y]
    return im


def label_strip(rows, out, scale=4, bg=(52, 48, 58, 255)):
    w, h = rows[0][1][0].size
    cols = max(len(r[1]) for r in rows) + 1
    lab = 14
    S = Image.new("RGBA", (cols * (w * scale + 4), len(rows) * (h * scale + 4 + lab)), bg)
    dr = ImageDraw.Draw(S)
    for ri, (text, ims, ref) in enumerate(rows):
        y0 = ri * (h * scale + 4 + lab)
        dr.text((2, y0 + 1), text, fill=(230, 220, 200, 255))
        for i, im in enumerate(ims):
            big = im.resize((w * scale, h * scale), Image.NEAREST)
            S.alpha_composite(big, (i * (w * scale + 4), y0 + lab))
        if ref is not None:
            x = len(ims) * (w * scale + 4)
            dr.rectangle([x - 3, y0 + lab, x - 2, y0 + lab + h * scale], fill=(220, 40, 40, 255))
            S.alpha_composite(ref.resize((w * scale, h * scale), Image.NEAREST), (x, y0 + lab))
    os.makedirs(os.path.dirname(out), exist_ok=True)
    S.save(out)


def evaluate(task):
    eid, clip, t = task["eid"], task["clip"], task["t"]
    ims, far = processed(eid, clip, t)
    m = metrics(eid, clip, ims)
    m["far"] = far
    task["metrics"] = m
    d = try_dir(eid, clip, t)
    label_strip([(f"{eid}/{clip} t{t} {json.dumps(m)}", ims, idle0(eid))], os.path.join(d, "strip.png"))
    return m


def ingest(jobs):
    if not os.path.isdir(INBOX):
        return jobs
    files = sorted(os.listdir(INBOX))
    for f in files:
        with open(os.path.join(INBOX, f)) as fh:
            for it in json.load(fh):
                if it.get("t", 1) > 1 or it.get("front"):
                    k = next((i for i, j in enumerate(jobs) if j["status"] == "queued"), len(jobs))
                    jobs.insert(k, it)
                else:
                    jobs.append(it)
    if files:
        save_jobs(jobs)
        for f in files:
            os.remove(os.path.join(INBOX, f))
    return jobs


def next_t(jobs, eid, clip):
    ts = [j["t"] for j in jobs if j["eid"] == eid and j["clip"] == clip]
    disk = os.path.join(RAW, eid, clip)
    if os.path.isdir(disk):
        ts += [int(x[1:]) for x in os.listdir(disk) if x.startswith("t") and x[1:].isdigit()]
    return max(ts, default=0) + 1


def queue(args):
    jobs = load_jobs()
    pend = []
    if os.path.isdir(INBOX):
        for f in os.listdir(INBOX):
            with open(os.path.join(INBOX, f)) as fh:
                pend.extend(json.load(fh))
    extra = ""
    frames = None
    tool = None
    items = []
    for a in args:
        if a.startswith("extra="):
            extra = a[6:]
        elif a.startswith("frames="):
            frames = int(a[7:])
        elif a.startswith("tool="):
            tool = a[5:]
        else:
            items.append(a)
    new = []
    for it in items:
        eid, _, clip = it.partition("/")
        clips = [clip] if clip else (["idle"] if SPECS[eid]["idle"] else []) + list(SPECS[eid]["fidgets"])
        for c in clips:
            t = max(next_t(jobs + pend + new, eid, c), 1)
            new.append(dict(eid=eid, clip=c, t=t, seed=7000 + 131 * t + len(c) * 17 + SPECS[eid]["act"],
                            status="queued", extra=extra, frames=frames, tool=tool))
    os.makedirs(INBOX, exist_ok=True)
    with open(os.path.join(INBOX, f"q{int(time.time() * 1000)}.json"), "w") as f:
        json.dump(new, f)
    print("TOTAL queued", len(new), " ".join(f"{n['eid']}/{n['clip']}/t{n['t']}" for n in new))


def run():
    while True:
        jobs = ingest(load_jobs())
        active = [j for j in jobs if j["status"] == "submitted"]
        for j in active:
            st, info = poll(j)
            if st == "done":
                j["status"] = "done"
                try:
                    m = evaluate(j)
                    print(f"[ok] {j['eid']}/{j['clip']}/t{j['t']} {json.dumps(m)}", flush=True)
                except Exception as e:
                    j["status"] = "evalfail"
                    print(f"[FAIL] eval {j['eid']}/{j['clip']}/t{j['t']} {e}", flush=True)
            elif st == "error":
                j["status"] = "failed"
                j["info"] = info
                print(f"[FAIL] {j['eid']}/{j['clip']}/t{j['t']} {info}", flush=True)
        active = [j for j in jobs if j["status"] == "submitted"]
        for j in jobs:
            if len(active) >= SLOTS:
                break
            if j["status"] != "queued":
                continue
            try:
                jid, info = submit(j)
            except Exception as e:
                jid, info = None, str(e)
            if jid:
                j["status"] = "submitted"
                j["job"] = jid
                active.append(j)
                save_jobs(jobs)
            else:
                if "rate limit" not in info.lower():
                    j["status"] = "failed"
                    j["info"] = info
                    print(f"[FAIL] submit {j['eid']}/{j['clip']}/t{j['t']} {info}", flush=True)
                break
        save_jobs(jobs)
        left = [j for j in jobs if j["status"] in ("queued", "submitted")]
        if not left and not (os.path.isdir(INBOX) and os.listdir(INBOX)):
            print("TOTAL done", len(jobs), flush=True)
            return
        time.sleep(20)


def install(eid, clip, t):
    ims, _ = processed(eid, clip, t)
    dest = F.anim_dir(eid, clip)
    src0 = os.path.join(RAW, eid, "idle0.png")
    if not os.path.exists(src0):
        os.makedirs(os.path.dirname(src0), exist_ok=True)
        shutil.copyfile(idle0_path(eid), src0)
    if clip == "idle":
        keep = os.path.join(RAW, eid, "idle_before")
        if not os.path.isdir(keep):
            shutil.copytree(dest, keep)
        ims = ims[:-1]
    if os.path.isdir(dest):
        for f in os.listdir(dest):
            if f.endswith(".png"):
                os.remove(os.path.join(dest, f))
    os.makedirs(dest, exist_ok=True)
    for i, im in enumerate(ims):
        p = os.path.join(dest, f"{i}.png")
        if i == 0:
            shutil.copyfile(src0, p)
        else:
            im.save(p)
    if clip != "idle":
        shutil.copyfile(src0, os.path.join(dest, f"{len(ims) - 1}.png"))
    print(f"[ok] install {eid}/{clip} t{t} frames={len(ims)}")


def installed(eid, clip):
    return frames_in(F.anim_dir(eid, clip))


def strips(eids):
    for eid in eids:
        act = SPECS[eid]["act"]
        clips = ["idle"] + list(SPECS[eid]["fidgets"]) + list(SPECS[eid]["states"])
        for c in clips:
            d = F.anim_dir(eid, c)
            if not os.path.isdir(d):
                continue
            ims = installed(eid, c)
            out = os.path.join(OUT, f"ato{act}", f"{eid}_{c}.png")
            label_strip([(f"{eid}/{c} {len(ims)}q", ims, idle0(eid))], out)
            print(out)


def tries_sheet(eid, clip):
    base = os.path.join(RAW, eid, clip)
    rows = []
    for x in sorted(os.listdir(base), key=lambda s: int(s[1:]) if s[1:].isdigit() else 0):
        if not (x.startswith("t") and x[1:].isdigit()):
            continue
        try:
            ims, far = processed(eid, clip, int(x[1:]))
        except Exception:
            continue
        m = metrics(eid, clip, ims)
        m["far"] = far
        rows.append((f"{x} {json.dumps(m)}", ims, idle0(eid)))
    out = os.path.join(base, "tries.png")
    label_strip(rows, out, scale=3)
    print(out)


def lua_val(v, ind):
    if isinstance(v, dict):
        order = ["clip", "kind", "fps", "weight", "xr", "yr", "rate", "spread", "dir", "tint"]
        ks = [k for k in order if k in v] + [k for k in v if k not in order]
        return "{ " + ", ".join(f"{k} = {lua_val(v[k], ind)}" for k in ks) + " }"
    if isinstance(v, (list, tuple)):
        return "{ " + ", ".join(lua_val(x, ind) for x in v) + " }"
    if isinstance(v, str):
        return '"' + v + '"'
    if isinstance(v, float):
        return f"{v:g}"
    return str(v)


def life(eids):
    os.makedirs(LIFE_DIR, exist_ok=True)
    for eid in eids:
        s = SPECS[eid]
        fid = [dict(clip=c, fps=v["fps"], weight=v["weight"]) for c, v in s["fidgets"].items()
               if os.path.isdir(F.anim_dir(eid, c))]
        lines = ["return {", "    fidgets = {"]
        for f in fid:
            lines.append("        " + lua_val(f, 2) + ",")
        lines.append("    },")
        lines.append("    gap = " + lua_val([float(x) for x in s["gap"]], 1) + ",")
        lines.append("    fx = {")
        for f in s["fx"]:
            lines.append("        " + lua_val(f, 2) + ",")
        lines.append("    },")
        hx, hy = ST.HEAD[eid]
        sts = []
        for c, v in s["states"].items():
            if not os.path.isdir(F.anim_dir(eid, c)):
                continue
            name = c[len("state_"):]
            e = dict(clip=c, fps=v["fps"])
            if name == "enraged":
                e["fx"] = [dict(kind="smoke", xr=hx, yr=hy, rate=0.8, spread=0.06, dir="up")]
            sts.append((name, e))
        if sts:
            lines.append("    states = {")
            for name, e in sts:
                lines.append(f"        {name} = " + lua_val(e, 2) + ",")
            lines.append("    },")
        lines.append("}")
        p = os.path.join(LIFE_DIR, f"{eid}.lua")
        with open(p, "w", encoding="utf-8", newline="\n") as fh:
            fh.write("\n".join(lines) + "\n")
        print(p)


def act_sheet(act):
    eids = [e for e in SPECS if SPECS[e]["act"] == act]
    rows = []
    for e in eids:
        ims = installed(e, "idle")
        rows.append((f"{e} idle {len(ims)}q", ims, None))
    W = max(r[1][0].size[0] for r in rows)
    H = max(r[1][0].size[1] for r in rows)
    scale = 2
    cols = max(len(r[1]) for r in rows)
    lab = 14
    S = Image.new("RGBA", (cols * (W * scale + 4) + 4, len(rows) * (H * scale + lab + 6)), (52, 48, 58, 255))
    dr = ImageDraw.Draw(S)
    for ri, (text, ims, _) in enumerate(rows):
        y0 = ri * (H * scale + lab + 6)
        dr.text((2, y0 + 1), text, fill=(230, 220, 200, 255))
        for i, im in enumerate(ims):
            S.alpha_composite(im.resize((im.size[0] * scale, im.size[1] * scale), Image.NEAREST),
                              (i * (W * scale + 4), y0 + lab))
    out = os.path.join(OUT, f"ato{act}", f"ato{act}_idle_sheet.png")
    S.save(out)
    print(out)


def status():
    jobs = ingest(load_jobs()) if False else load_jobs()
    for j in jobs:
        print(j["eid"], j["clip"], f"t{j['t']}", j["status"], json.dumps(j.get("metrics", {})))


def main():
    a = sys.argv[1:]
    cmd = a[0] if a else "status"
    if cmd == "queue":
        queue(a[1:])
    elif cmd == "run":
        run()
    elif cmd == "install":
        install(a[1], a[2], int(a[3]))
    elif cmd == "strips":
        strips(a[1:] or list(SPECS))
    elif cmd == "tries":
        tries_sheet(a[1], a[2])
    elif cmd == "life":
        life(a[1:] or list(SPECS))
    elif cmd == "sheet":
        act_sheet(int(a[1]))
    elif cmd == "eval":
        for j in load_jobs():
            if j["status"] == "done":
                evaluate(j)
    else:
        status()


if __name__ == "__main__":
    main()
