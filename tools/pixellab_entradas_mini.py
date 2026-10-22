import base64
import json
import os
import re
import shutil
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixellab_enemy_anims as F
import pixellab_entradas as PE
import pixellab_entradas_mini_specs as S

from PIL import Image

ROOT = F.ROOT
OUT = os.path.join(ROOT, "tools/preview_out/entradas_arte/mini")
STILLS = os.path.join(OUT, "stills")
DERIVED = os.path.join(OUT, "derived")
TRIES = os.path.join(OUT, "tries")
LOG = os.path.join(OUT, "jobs.json")


def log(entry):
    os.makedirs(OUT, exist_ok=True)
    data = []
    if os.path.exists(LOG):
        with open(LOG) as f:
            data = json.load(f)
    entry["t"] = time.strftime("%Y-%m-%d %H:%M:%S")
    data.append(entry)
    with open(LOG, "w") as f:
        json.dump(data, f, indent=1)


def b64(path):
    with open(path, "rb") as f:
        return base64.b64encode(f.read()).decode()


def idle_path(eid):
    return F.idle_frame_path(eid)


def source(eid, kind):
    if kind == "idle":
        return idle_path(eid)
    if kind.startswith("still:"):
        return os.path.join(DERIVED, f"{eid}_{kind[6:]}.png")
    if kind.startswith("derive:"):
        os.makedirs(DERIVED, exist_ok=True)
        p = os.path.join(DERIVED, f"{eid}_{kind[7:].replace(':', '')}.png")
        if kind[7:].startswith("down:"):
            frac = float(kind.split(":")[2])
            im = PE.idle0(eid)
            bb = im.getbbox()
            dy = int(round((bb[3] - bb[1]) * frac))
            out = Image.new("RGBA", im.size, (0, 0, 0, 0))
            out.paste(im, (0, dy), im)
            out.save(p)
        elif "@" in kind:
            k, base = kind[7:].split("@")
            orig = PE.idle0
            PE.idle0 = lambda e: Image.open(source(eid, base)).convert("RGBA")
            try:
                p = os.path.join(DERIVED, f"{eid}_{k}_{base.replace(':', '_')}.png")
                PE.derive(eid, k).save(p)
            finally:
                PE.idle0 = orig
        else:
            PE.derive(eid, kind[7:]).save(p)
        return p
    if kind.startswith("clip:"):
        c, i = kind[5:].split("@")
        return os.path.join(F.anim_dir(eid, c), f"{i}.png")
    return os.path.join(ROOT, kind)


def submit(tool, args):
    for _ in range(240):
        text = F.tool_text(F.rpc("tools/call", {"name": tool, "arguments": args}, timeout=300))
        m = re.search(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", text)
        if m:
            return m.group(0), text
        if "rate limit" not in text.lower() and "concurrent" not in text.lower():
            return None, text
        time.sleep(20)
    return None, text


def wait(job, dest, prefix):
    os.makedirs(dest, exist_ok=True)
    t0 = time.time()
    while time.time() - t0 < 1800:
        try:
            text = F.tool_text(F.rpc("tools/call", {"name": "get_image", "arguments": {"job_id": job}}))
        except Exception:
            time.sleep(15)
            continue
        low = text.lower()
        if "status: failed" in low or "status: error" in low:
            print(f"[FAIL] {prefix}: {text[:300]}", flush=True)
            return []
        if "status: completed" in low:
            mN = re.search(r"frames:\s*(\d+)", text)
            mU = re.search(r"(https?://\S+/download)\?index=\d+", text)
            n = int(mN.group(1)) if mN else 1
            paths = []
            for i in range(n):
                url = f"{mU.group(1)}?index={i}" if mU else None
                if not url:
                    m1 = re.search(r"(https?://\S+)", text)
                    url = m1.group(1)
                p = os.path.join(dest, f"{prefix}{i}.png")
                with open(p, "wb") as f:
                    f.write(F.fetch(url))
                paths.append(p)
            return paths
        time.sleep(15)
    return []


def pad4(im):
    w, h = im.size
    W, H = (w + 3) // 4 * 4, (h + 3) // 4 * 4
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    out.paste(im, (0, H - h))
    return out, (0, H - h, w, H)


def strip(paths, out, scale=4, marks=()):
    ims = [Image.open(p).convert("RGBA") for p in paths]
    cw = max(i.width for i in ims) * scale
    ch = max(i.height for i in ims) * scale
    gap = 6
    sheet = Image.new("RGBA", (len(ims) * (cw + gap) + gap, ch + 2 * gap), (58, 52, 50, 255))
    for n, im in enumerate(ims):
        x = gap + n * (cw + gap)
        if n in marks:
            for yy in range(sheet.height):
                for xx in range(x - gap, x - 1):
                    sheet.putpixel((xx, yy), (200, 40, 40, 255))
        sheet.alpha_composite(im.resize((im.width * scale, im.height * scale), Image.NEAREST), (x, gap))
    os.makedirs(os.path.dirname(out), exist_ok=True)
    sheet.save(out)
    print(out, flush=True)


def still(eid, name, seed=0, base="idle"):
    spec = S.STILLS[f"{eid}/{name}"]
    src = Image.open(source(eid, spec.get("base", base))).convert("RGBA")
    padded, box = pad4(src)
    tmp = os.path.join(OUT, f"_pad_{eid}_{name}.png")
    padded.save(tmp)
    desc = spec["desc"] + " " + S.STILL_SUFFIX
    args = {"method": "text", "description": desc[:2000], "image_base64": b64(tmp),
            "no_background": True, "seed": int(seed)}
    job, text = submit("edit_image_pro_flash", args)
    os.remove(tmp)
    if not job:
        print(f"[FAIL] still {eid}/{name}: {text[:300]}", flush=True)
        return
    log({"kind": "still", "key": f"{eid}/{name}", "seed": seed, "job": job})
    got = wait(job, STILLS, f"{eid}_{name}_s{seed}_")
    if not got:
        return
    res = []
    for p in got:
        im = Image.open(p).convert("RGBA")
        if im.size == padded.size:
            im = im.crop(box)
        im.save(p)
        res.append(p)
    strip([idle_path(eid)] + res, os.path.join(OUT, f"{eid}_still_{name}_s{seed}.png"), scale=3)


def pick(eid, name, path):
    os.makedirs(DERIVED, exist_ok=True)
    im = Image.open(os.path.join(ROOT, path) if not os.path.isabs(path) else path).convert("RGBA")
    ref = Image.open(idle_path(eid))
    assert im.size == ref.size, (im.size, ref.size)
    im.save(os.path.join(DERIVED, f"{eid}_{name}.png"))
    print(f"[ok] {eid}/{name} <- {path}", flush=True)


def drift(a, b):
    A = Image.open(a).convert("RGBA")
    B = Image.open(b).convert("RGBA")
    if A.size != B.size:
        return 1.0
    pa, pb = A.load(), B.load()
    n = d = 0
    for y in range(A.height):
        for x in range(A.width):
            ca, cb = pa[x, y], pb[x, y]
            if ca[3] or cb[3]:
                n += 1
                if max(abs(ca[i] - cb[i]) for i in range(4)) > 48:
                    d += 1
    return d / max(1, n)


def anim(eid, clip, tool=None, seed=None, frames=None, variant=None):
    key = f"{eid}/{clip}" + (f"#{variant}" if variant else "")
    spec = S.ANIMS[key]
    tool = tool or spec.get("tool", "animate_image")
    frames = int(frames or spec.get("frames", 12))
    first = source(eid, spec["first"])
    last = source(eid, spec["last"]) if spec.get("last") else None
    keep = F.ENEMIES[eid]["keep"]
    text = f"{spec['action']}. It keeps its {keep}." + S.ANIM_SUFFIX
    if tool == "animate_image_pixminimax":
        args = {"description": text[:1000], "first_frame_base64": b64(first), "frame_count": frames,
                "no_background": True, "direction": "south", "view": "side"}
    else:
        args = {"action": text[:1000], "first_frame_base64": b64(first), "frame_count": frames}
    if last:
        args["last_frame_base64"] = b64(last)
    if seed is not None:
        args["seed"] = int(seed)
    job, resp = submit(tool, args)
    if not job:
        print(f"[FAIL] anim {key}: {resp[:300]}", flush=True)
        return
    n = 1
    while os.path.isdir(os.path.join(TRIES, f"{eid}_{clip}_t{n}")):
        n += 1
    dest = os.path.join(TRIES, f"{eid}_{clip}_t{n}")
    os.makedirs(dest)
    with open(os.path.join(dest, "meta.json"), "w") as f:
        json.dump({"key": key, "tool": tool, "seed": seed, "frames": frames, "job": job,
                   "first": spec["first"], "last": spec.get("last")}, f, indent=1)
    log({"kind": "anim", "key": key, "tool": tool, "seed": seed, "frames": frames, "job": job, "try": n})
    got = wait(job, dest, "")
    if not got:
        return
    dr = drift(got[-1], last) if last else -1
    tail = [last] if last else []
    strip(got + tail, os.path.join(OUT, f"{eid}_{clip}_t{n}.png"), marks=(len(got),) if last else ())
    print(f"[ok] {key} t{n}: {len(got)} quadros, drift fim {dr:.3f}", flush=True)


def install(eid, clip, spec_n):
    seq = []
    metas = []
    for k, n in enumerate(str(spec_n).split("+")):
        d = os.path.join(TRIES, f"{eid}_{clip}_t{n}")
        with open(os.path.join(d, "meta.json")) as f:
            meta = json.load(f)
        metas.append(meta)
        files = sorted([x for x in os.listdir(d) if x.endswith(".png")], key=lambda s: int(s[:-4]))
        items = [os.path.join(d, x) for x in files]
        seq += items if k == 0 else items[1:]
    first = source(eid, metas[0]["first"])
    lastkind = metas[-1].get("last") or S.ANIMS.get(metas[-1]["key"], {}).get("end")
    last = source(eid, lastkind) if lastkind else None
    dest = F.anim_dir(eid, clip)
    if os.path.isdir(dest):
        for x in os.listdir(dest):
            if x.endswith(".png"):
                os.remove(os.path.join(dest, x))
    os.makedirs(dest, exist_ok=True)
    fix = getattr(S, "FIXUPS", {}).get(f"{eid}/{clip}")
    for i, src in enumerate(seq):
        out = os.path.join(dest, f"{i}.png")
        if i == 0:
            shutil.copyfile(first, out)
        elif i == len(seq) - 1 and last:
            shutil.copyfile(last, out)
        else:
            im = Image.open(src).convert("RGBA")
            if fix:
                im = fix(im, i)
            im.save(out)
    paths = [os.path.join(dest, f"{i}.png") for i in range(len(seq))]
    strip(paths + [idle_path(eid)], os.path.join(OUT, f"{eid}_{clip}.png"), marks=(len(paths),))
    print(f"[ok] instalado {eid}/{clip} t{spec_n}: {len(seq)} quadros", flush=True)


def main():
    cmd, rest = sys.argv[1], sys.argv[2:]
    if cmd == "still":
        still(rest[0], rest[1], int(rest[2]) if len(rest) > 2 else 0)
    elif cmd == "pick":
        pick(rest[0], rest[1], rest[2])
    elif cmd == "anim":
        kw = dict(a.split("=", 1) for a in rest[2:])
        anim(rest[0], rest[1], kw.get("tool"), kw.get("seed"), kw.get("frames"), kw.get("variant"))
    elif cmd == "install":
        install(rest[0], rest[1], rest[2])
    elif cmd == "derive":
        print(source(rest[0], "derive:" + rest[1]))


if __name__ == "__main__":
    main()
