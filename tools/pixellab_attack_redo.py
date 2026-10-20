#!/usr/bin/env python3
import base64
import json
import os
import re
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixellab_enemy_anims as F

OUT = os.path.join(F.ROOT, "tools/preview_out/attack_redo")
JOBS = os.path.join(OUT, "jobs.json")

SUFFIX = (" Palette, colors, lighting, proportions, face and every piece of clothing "
          "and equipment stay exactly as in the first frame and fully visible in every "
          "frame. The character keeps the same size and stays inside the frame. Nothing "
          "new appears, no glow, no flash, no recoloring, background stays empty.")

ATTACKS = {
    "carrion_king": ("winds up by raising one taloned claw and half-opening its dark "
                     "wings, then lunges forward and slashes the claw down diagonally "
                     "in a vicious swipe toward the viewer, beak open, then pulls back "
                     "and settles into its original standing stance"),
    "cursed_scarecrow": ("rears back and lifts its right claw hand to shoulder height, then lunges "
                         "its upper body forward and rakes the claw down across its chest in one "
                         "big swipe, then straightens back into its original standing stance. The "
                         "claw hand is a plain brown burlap glove with dark talons the whole time: "
                         "it never glows, never burns, never turns yellow or orange. Pure body "
                         "motion, no visual effects of any kind: no sparks, no slash arc, no ring, "
                         "no fire, no impact flash"),
    "harvest_reaper": ("raises the long scythe high behind its shoulder, then swings it "
                       "down in a wide sweeping arc in front of its body toward the "
                       "viewer, robes and wheat-straw shoulders swaying with the motion, "
                       "then lifts the scythe back to its original standing stance"),
}


def load():
    if os.path.exists(JOBS):
        with open(JOBS) as f:
            return json.load(f)
    return {}


def save(j):
    os.makedirs(OUT, exist_ok=True)
    with open(JOBS, "w") as f:
        json.dump(j, f, indent=2)


def submit(eid, seed):
    padx = int(os.environ.get("ATTACK_PAD_X", "0"))
    padt = int(os.environ.get("ATTACK_PAD_TOP", "0"))
    if padx or padt:
        import io
        from PIL import Image
        im = Image.open(F.idle_frame_path(eid)).convert("RGBA")
        out = Image.new("RGBA", (im.width + 2 * padx, im.height + padt), (0, 0, 0, 0))
        out.paste(im, (padx, padt))
        buf = io.BytesIO()
        out.save(buf, "PNG")
        b64 = base64.b64encode(buf.getvalue()).decode()
    else:
        with open(F.idle_frame_path(eid), "rb") as f:
            b64 = base64.b64encode(f.read()).decode()
    prompt = f"{ATTACKS[eid]}. It keeps its {F.ENEMIES[eid]['keep']}." + SUFFIX
    args = {"action": prompt, "first_frame_base64": b64, "frame_count": 8, "seed": seed}
    text = F.tool_text(F.rpc("tools/call", {"name": "animate_image", "arguments": args}))
    m = re.search(r"([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})", text)
    if not m:
        print(f"[submit] {eid}: sem job id: {text[:300]}", flush=True)
        return None
    return m.group(1)


def poll(job_id, dest):
    text = F.tool_text(F.rpc("tools/call", {"name": "get_image", "arguments": {"job_id": job_id}}))
    low = text.lower()
    if "status: failed" in low or "status: error" in low:
        print(f"[poll] falhou: {text[:300]}", flush=True)
        return "error"
    if "status: completed" not in low:
        return "wait"
    mN = re.search(r"frames:\s*(\d+)", text)
    mURL = re.search(r"(https?://\S+/download)\?index=\d+", text)
    if not (mN and mURL):
        print(f"[poll] sem urls: {text[:300]}", flush=True)
        return "error"
    os.makedirs(dest, exist_ok=True)
    for i in range(int(mN.group(1))):
        with open(os.path.join(dest, f"{i}.png"), "wb") as f:
            f.write(F.fetch(f"{mURL.group(1)}?index={i}"))
    return "done"


def run(ids, seeds):
    jobs = load()
    for eid in ids:
        for seed in seeds:
            key = f"{eid}/s{seed}" + os.environ.get("ATTACK_TAG", "")
            st = jobs.get(key, {})
            if st.get("status") == "done":
                continue
            jid = st.get("job_id") or submit(eid, seed)
            if not jid:
                continue
            jobs[key] = {"status": "pending", "job_id": jid}
            save(jobs)
            res = "wait"
            for _ in range(90):
                time.sleep(10)
                try:
                    res = poll(jid, os.path.join(OUT, eid, f"s{seed}" + os.environ.get("ATTACK_TAG", "")))
                except Exception as e:
                    print(f"[poll] {key}: {e}", flush=True)
                    res = "wait"
                if res != "wait":
                    break
            jobs[key]["status"] = res
            save(jobs)
            print(f"[attack_redo] {key}: {res}", flush=True)


if __name__ == "__main__":
    ids = sys.argv[1].split(",")
    seeds = [int(s) for s in sys.argv[2].split(",")]
    run(ids, seeds)
