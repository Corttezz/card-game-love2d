import json
import os
import shutil
import sys
import threading
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixellab_enemy_anims as F
import pixellab_vida_c as V

import numpy as np
from PIL import Image

ROOT = F.ROOT
OUT = os.path.join(ROOT, "tools/preview_out/voo")
TRIES = os.path.join(ROOT, "tools/preview_out/voo_tries")
SLOTS = threading.Semaphore(int(os.environ.get("VOO_SLOTS", "6")))
LOCK = threading.Lock()

SUFFIX = (" Seamless hovering loop in mid-air: the last frame flows back into the first. Same creature, same size, "
          "same colors and outline in every frame, centered on the same spot of the canvas. Glowing eyes keep glowing "
          "in every frame. Nothing new appears: no particles, no dust, no smoke clouds, no new objects, no ground, no "
          "shadow, nothing leaves the frame.")

SPECS = {
    "carrion_king": {
        "frames": 12,
        "text": ("Flying hover loop of a crowned black crow king. The two big black wings BEAT once: first both wings "
                 "lift UP and spread OUT to the sides (up-stroke, frames 1 to 5), then sweep powerfully DOWN past the "
                 "hips (down-stroke, frames 6 to 8), then come back to the start. On the down-stroke the whole body "
                 "rises 3 pixels, between strokes it sinks back. The orange talons hang loose below and dangle, they "
                 "never stand on anything. The tattered purple robe pieces flutter with each beat. The crown and the "
                 "skull face stay the same. The wing feathers keep the same blue-violet and dark purple colors as in the first frame. The wing tips stay inside the frame."),
    },
    "dusk_bat": {
        "frames": 12,
        "text": ("Flying hover loop of a giant red-membrane bat. The wings FLAP once with a big clear motion: the wings "
                 "rise HIGH above the head (up-stroke, frames 1 to 5), then sweep strongly DOWN and forward below the "
                 "body (down-stroke, frames 6 to 8), then come back up to the start. On the down-stroke the body "
                 "rises 3 pixels, between strokes it sinks. The little feet hang below, never touching anything. The "
                 "wing membranes stretch and bend with the beat. The wing tips stay inside the frame, never wider "
                 "than in the first frame. The red eyes keep glowing."),
    },
    "eclipse_queen": {
        "frames": 12,
        "text": ("Hovering loop of a dark queen with huge purple bat wings and a long black starry gown. The wings BEAT "
                 "slowly once: they fold DOWN and INWARD toward the gown in a strong down-stroke (frames 4 to 7), then "
                 "open back up and out (up-stroke) to the start. On the down-stroke the whole body lifts 2 pixels and "
                 "the long gown hem swings and ripples below as if pushed by the air. Her face, crown and arms stay "
                 "the same. The wing tips stay inside the frame, never wider or taller than in the first frame."),
    },
    "tower_lich": {
        "frames": 12,
        "text": ("Levitating loop of a skeletal frost lich floating above the ground, held up by rising cold air. The "
                 "long cape and the robe hem BILLOW: the cape side flaps lift and spread outward and the robe hem "
                 "streams and ripples upward (frames 3 to 6), then fall back and hang (frames 7 to 11). The dangling "
                 "brown boots sway loosely, toes pointing down, never standing. No sparkles, no stray pixels around the feet. The whole body rises 2 pixels while "
                 "the cape billows and sinks back after. The staff and its glowing orb move with the hand, the crown "
                 "and skull stay the same."),
    },
    "dusk_shade": {
        "frames": 12,
        "text": ("Hovering loop of a hooded shadow wraith floating in the air. The torn robe tatters and the long "
                 "side flaps STREAM and RIPPLE as if held up by air: they flare outward and lift (frames 3 to 6), "
                 "then fall and trail down (frames 7 to 11). The violet ghost flames on the shoulders flicker and "
                 "lick upward. The whole body rises 2 pixels while the tatters flare and sinks back after. The legs "
                 "hang loosely, never standing. The hood and face stay the same."),
    },
    "fallen_angel": {
        "frames": 12,
        "text": ("Flying hover loop of a dark fallen angel in black armor with a purple robe, a gold halo and a sword. "
                 "The two huge black feathered wings BEAT once with a big clear motion: first both wings lift HIGH and "
                 "spread OUT wide (up-stroke, frames 1 to 5), then sweep powerfully DOWN and forward (down-stroke, "
                 "frames 6 to 8), then come back to the start. On the down-stroke the whole body rises 3 pixels, "
                 "between strokes it sinks back. The legs and feet hang loose below and sway, never standing on "
                 "anything. The purple robe hem flutters and ripples with each beat. The gold halo, the pale face and "
                 "the sword stay the same. The wing tips stay inside the frame."),
    },
    "abyss_watcher": {
        "frames": 12,
        "text": ("Floating loop of a horned many-eyed jellyfish horror. The fleshy bell PULSES once like a swimming "
                 "jellyfish: it squeezes narrower and the tentacles snap DOWN and together in a strong push (frames 4 "
                 "to 6), the whole body rises 3 pixels on the push, then the bell relaxes wider and the tentacles "
                 "drift back out and curl (frames 7 to 11). The horned crown and the orange eyes stay the same."),
    },
}


def idle0(eid):
    return F.idle_frame_path(eid)


def try_dir(eid):
    with LOCK:
        n = 1
        while os.path.isdir(os.path.join(TRIES, f"{eid}_t{n}")):
            n += 1
        d = os.path.join(TRIES, f"{eid}_t{n}")
        os.makedirs(d)
    return d, n


def finish(d):
    with open(os.path.join(d, "meta.json")) as f:
        meta = json.load(f)
    got, resp = V.wait(meta["job"], d)
    if not got:
        print(f"[FAIL] {d}: {str(resp)[:300]}", flush=True)
        return
    m = V.metrics(meta["eid"], got)
    m["swing"] = swing(meta["eid"], got)
    meta["metrics"] = m
    import re
    mc = re.search(r"charged:\s*(\d+)", resp or "")
    meta["charged"] = int(mc.group(1)) if mc else None
    with open(os.path.join(d, "meta.json"), "w") as f:
        json.dump(meta, f, indent=1)
    V.strip(got + [idle0(meta["eid"])], d + ".png", mark=len(got))
    print(f"[ok] {d}: {len(got)}q {json.dumps(m)}", flush=True)


def swing(eid, paths):
    base = V.load(idle0(eid))
    b0 = V.bbox(base)
    out = []
    for p in paths:
        b = V.bbox(V.load(p))
        out.append((b[0] - b0[0], b[1] - b0[1], b[2] - b0[2], b[3] - b0[3]))
    return out


def anim(eid, seed=None, extra=""):
    sp = SPECS[eid]
    text = (extra + " " + sp["text"] + SUFFIX).strip()
    args = {"action": text[:1000], "first_frame_base64": V.b64(idle0(eid)),
            "last_frame_base64": V.b64(idle0(eid)), "frame_count": int(sp["frames"])}
    if seed is not None:
        args["seed"] = int(seed)
    with SLOTS:
        job, resp = V.submit(args)
        if not job:
            print(f"[FAIL] {eid}: {resp[:300]}", flush=True)
            return
        d, n = try_dir(eid)
        with open(os.path.join(d, "meta.json"), "w") as f:
            json.dump({"eid": eid, "seed": seed, "job": job, "prompt": text}, f, indent=1)
        finish(d)


def run(items):
    ths = []
    for eid, seed in items:
        t = threading.Thread(target=anim, args=(eid, seed))
        t.start()
        ths.append(t)
        time.sleep(2)
    for t in ths:
        t.join()


def install(eid, n, fix=None):
    d = os.path.join(TRIES, f"{eid}_t{n}")
    files = sorted([x for x in os.listdir(d) if x.endswith(".png")], key=lambda s: int(s[:-4]))
    src = [os.path.join(d, x) for x in files][:-1]
    dest = F.anim_dir(eid, "idle")
    keep = os.path.join(TRIES, f"_antes_{eid}")
    if not os.path.isdir(keep):
        shutil.copytree(dest, keep)
    for x in os.listdir(dest):
        if x.endswith(".png") and x != "0.png":
            os.remove(os.path.join(dest, x))
    for i in range(1, len(src)):
        im = Image.open(src[i]).convert("RGBA")
        if fix and fix.get("eyes"):
            im = V.fix_eyes(eid, im)
        if fix and fix.get("white"):
            im = V.fix_white(eid, im)
        if fix and fix.get("lock"):
            for bx in fix["lock"].split(";"):
                im = V.fix_lock(eid, im, tuple(int(v) for v in bx.split(",")))
        if fix and fix.get(f"f{i}"):
            im = Image.open(os.path.join(ROOT, fix[f"f{i}"])).convert("RGBA")
        im.save(os.path.join(dest, f"{i}.png"))
    paths = [os.path.join(dest, f"{i}.png") for i in range(len(src))]
    os.makedirs(OUT, exist_ok=True)
    V.strip(paths + [paths[0]], os.path.join(OUT, f"{eid}_idle_novo.png"), mark=len(paths))
    print(f"[ok] instalado {eid} t{n}: {len(src)} quadros", flush=True)


def restore(eid):
    keep = os.path.join(TRIES, f"_antes_{eid}")
    dest = F.anim_dir(eid, "idle")
    for x in os.listdir(dest):
        os.remove(os.path.join(dest, x))
    for x in os.listdir(keep):
        shutil.copyfile(os.path.join(keep, x), os.path.join(dest, x))
    print(f"[ok] restaurado {eid}", flush=True)


def main():
    cmd, rest = sys.argv[1], sys.argv[2:]
    if cmd == "run":
        items = []
        for a in rest:
            eid, _, seed = a.partition("@")
            items.append((eid, int(seed) if seed else None))
        run(items)
    elif cmd == "fetch":
        ths = [threading.Thread(target=finish, args=(os.path.join(TRIES, x),)) for x in rest]
        for t in ths:
            t.start()
        for t in ths:
            t.join()
    elif cmd == "install":
        fix = dict(a.split("=", 1) for a in rest[2:]) if len(rest) > 2 else None
        install(rest[0], rest[1], fix)
    elif cmd == "restore":
        restore(rest[0])


if __name__ == "__main__":
    main()
