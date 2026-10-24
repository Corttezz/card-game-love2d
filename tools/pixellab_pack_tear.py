import base64
import json
import os
import re
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "tools/preview_out/pacotes_v2/raw")
JOBS = os.path.join(RAW, "jobs.json")
PACKS = ["pack_standard", "pack_buffoon", "pack_arcana", "pack_celestial", "pack_spectral"]

ACTION = ("the sealed card pack tears open: the serrated top strip rips off and flies "
          "upward out of the frame, the envelope mouth bulges open and the edges of a "
          "few cards peek out of the opening; the envelope itself stays in place and "
          "keeps its colours, emblem and outline; crisp pixel art, no glow, no light rays")


def call(tool, args, timeout=300):
    import pixellab_enemy_anims as F
    return F.tool_text(F.rpc("tools/call", {"name": tool, "arguments": args}, timeout=timeout))


def jobs():
    return json.load(open(JOBS)) if os.path.exists(JOBS) else {}


def queue(names, seed):
    os.makedirs(RAW, exist_ok=True)
    J = jobs()
    for pid in names:
        src = os.path.join(ROOT, "assets/sprites/shop/v5", pid + ".png")
        b64 = base64.b64encode(open(src, "rb").read()).decode()
        text = call("animate_image", {
            "first_frame_url": "data:image/png;base64," + b64,
            "action": ACTION, "frame_count": 8, "seed": seed,
        })
        m = re.search(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", text)
        key = "%s_s%d" % (pid, seed)
        J[key] = m.group(0) if m else None
        print("[queue] %s %s" % (key, J[key]), flush=True)
        if not m:
            print(text[:300])
        json.dump(J, open(JOBS, "w"), indent=2)
        time.sleep(1.5)


def poll():
    import pixellab_enemy_anims as F
    J = jobs()
    pending = {k: v for k, v in J.items() if v and not os.path.isdir(os.path.join(RAW, k))}
    t0 = time.time()
    while pending and time.time() - t0 < 1500:
        for k, jid in list(pending.items()):
            text = call("get_image", {"job_id": jid})
            low = text.lower()
            if "failed" in low and "status" in low:
                print("[FAIL] %s %s" % (k, text[:200]))
                pending.pop(k)
                continue
            if "completed" not in low:
                continue
            mN = re.search(r"frames:\s*(\d+)", text)
            mU = re.search(r"(https?://\S+/download)\?index=", text)
            if mN and mU:
                urls = ["%s?index=%d" % (mU.group(1), i) for i in range(int(mN.group(1)))]
            else:
                urls = [u.rstrip(")\"',.") for u in re.findall(r"https?://\S+", text)]
                urls = [u for u in urls if u.endswith(".png") or "download" in u]
            d = os.path.join(RAW, k)
            os.makedirs(d, exist_ok=True)
            for i, u in enumerate(urls):
                open(os.path.join(d, "%d.png" % i), "wb").write(F.fetch(u))
            print("[ok] %s %d quadros" % (k, len(urls)), flush=True)
            pending.pop(k)
        if pending:
            time.sleep(20)
    for k in pending:
        print("[FAIL] %s sem resposta" % k)


if __name__ == "__main__":
    if sys.argv[1] == "queue":
        queue(sys.argv[3:] or PACKS, int(sys.argv[2]))
    else:
        poll()
