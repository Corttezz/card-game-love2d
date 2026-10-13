#!/usr/bin/env python3
"""
tools/pixellab_boss_cine.py — POSES/ESTADOS das cinemáticas de chefe via
PixelLab `animate_image` (v3), na MESMA doutrina da fábrica de hurt/death
(tools/pixellab_enemy_anims.py, de onde importa rpc/submit/poll): o frame 0
é o PNG REAL do idle (animations/idle/south/0.png), então o chefe nunca
"vira outro" — on-model por construção (mesmo desenho, tamanho e paleta);
drift = retry.

Clips instalados em assets/sprites/characters/enemies/<id>/animations/<clip>/south/
e consumidos por src/ui/BossCinematic.lua (rasante usa `dive` se existir,
pouso usa `land`, cartão usa `roar`; os demais chefes têm os seus).

Uso:
  python3 tools/pixellab_boss_cine.py run [id ...]     # fábrica serial (1 job por vez)
  python3 tools/pixellab_boss_cine.py status
  python3 tools/pixellab_boss_cine.py sheet <id>       # prancha dos clips do chefe

Jobs em tools/preview_out/boss_cine_jobs.json.
"""
import json
import os
import re
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixellab_enemy_anims as F  # noqa: E402  (token, rpc, fetch, tripwires)

JOBS_FILE = os.path.join(F.ROOT, "tools/preview_out/boss_cine_jobs.json")

KEEP = {eid: spec["keep"] for eid, spec in F.ENEMIES.items()}

SUFFIX = (" Palette, colors, proportions, face and every piece of clothing "
          "and equipment stay unchanged and fully visible in every frame. "
          "Nothing disappears, nothing new appears, background stays empty.")

# clip -> (frames gerados, prompt). Frame 0 = idle real (a fábrica adiciona).
CLIPS = {
    "carrion_king": {
        "dive": (8, "spreads its dark feathered wings to full span and leans "
                    "into a fast forward dive like a raven swooping across a "
                    "hall: wings sweep in deep powerful strokes, talons tucked "
                    "under the body, tattered robes and crown streaming "
                    "backward, head thrust forward, beak open"),
        "land": (8, "drops into a heavy landing: wings flare high and wide to "
                    "brake, talons spread and slam onto the ground, the body "
                    "crouches low with the ribcage glowing, then it rises back "
                    "up into its standing stance"),
        "roar": (8, "throws its head back and screeches to the ceiling, beak "
                    "wide open, wings spread to their full span and shaking, "
                    "ribcage glowing brighter, then settles back into its "
                    "standing stance"),
    },
    "tower_lich": {
        "rise": (8, "rises slowly upward as if lifted out of the floor by "
                    "magic: robes and cape trailing downward, arms spreading "
                    "outward, the staff orb flaring with bright arcane light, "
                    "skull face tilting up, then settles into its floating "
                    "stance"),
        "roar": (8, "raises the staff high overhead, orb blazing, cape "
                    "billowing wide, skull jaw opening in a silent scream, "
                    "then lowers the staff back into its stance"),
    },
    "abyss_tyrant": {
        "stride": (8, "strides forward with heavy powerful steps, shoulders "
                      "swinging, cape sweeping behind, chest core flaring at "
                      "each step, horned skull lowered menacingly, then stops "
                      "in its standing stance"),
        "roar": (8, "plants both feet, throws its horned skull back and roars, "
                    "chest core blazing, arms spread wide, cape flaring, then "
                    "settles back into its standing stance"),
    },
    "winter_monarch": {
        "walk": (8, "walks forward slowly and regally, cape swaying, staff "
                    "planted with each step, crown of ice shards glinting, "
                    "then stops in its standing stance"),
        "roar": (8, "slams the staff into the ground, ice crystals bursting up "
                    "around the base, cape whipping, head raised, then settles "
                    "back into its standing stance"),
    },
    "rot_colossus": {
        "emerge": (8, "tears itself free from a tangle of roots: pushes up and "
                      "forward with both huge arms, torso lurching upward, "
                      "antler branches shaking, then lumbers one heavy step "
                      "forward into its standing stance"),
        # (sem "spores puffing": a 1ª geração desenhou nuvens brancas de
        # desenho animado — fora do estilo; o esporo é partícula do jogo)
        "roar": (8, "beats its chest with both fists and bellows, head thrown "
                    "back, antler branches shaking, jaw wide open, then "
                    "settles back into its standing stance"),
    },
    "eclipse_queen": {
        # v2 (Out/2026, frente rainha-eclipse): `unveil` = manifestação (ela
        # se fecha num casulo de asas e se REVELA ao abri-las), `crown` =
        # coroação (braços erguidos recebendo a coroa, no cartão de nome).
        "unveil": (8, "folds both enormous bat-wings forward wrapping them "
                      "tightly around her body like a closed cocoon that hides "
                      "her face and crown, holds the cocoon still for a moment, "
                      "then slowly unfurls the wings wide open revealing her "
                      "face with a cold stare, settling into her floating "
                      "stance"),
        "crown": (8, "raises both arms slowly upward with open palms as if "
                     "receiving a crown from above, head tilting back, the "
                     "bat-wing cloak spreading to its full span and trembling, "
                     "holds the cold triumphant pose, then lowers the arms "
                     "back into her floating stance"),
        "descend": (8, "descends slowly from above with her huge bat-wing cloak "
                       "unfurling wide, arms spread, head bowed then lifting, "
                       "then folds the wings and settles into her floating "
                       "stance"),
        "roar": (8, "flings both wings open to full span and lifts her head "
                    "with a cruel cry, cloak edges flaring, then folds the "
                    "wings back into her floating stance"),
    },
}


def load_jobs():
    if os.path.exists(JOBS_FILE):
        with open(JOBS_FILE) as f:
            return json.load(f)
    return {}


def save_jobs(jobs):
    os.makedirs(os.path.dirname(JOBS_FILE), exist_ok=True)
    with open(JOBS_FILE, "w") as f:
        json.dump(jobs, f, indent=2)


def submit(eid, clip):
    import base64
    frames, action = CLIPS[eid][clip]
    with open(F.idle_frame_path(eid), "rb") as f:
        b64 = base64.b64encode(f.read()).decode()
    prompt = f"{action}. It keeps its {KEEP[eid]}." + SUFFIX
    args = {"action": prompt, "first_frame_base64": b64, "frame_count": frames}
    text = F.tool_text(F.rpc("tools/call", {"name": "animate_image",
                                            "arguments": args}))
    m = re.search(r"([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-"
                  r"[0-9a-f]{12})", text)
    if not m:
        print(f"[submit] {eid}/{clip}: SEM JOB ID — {text[:200]}", flush=True)
        return None
    return m.group(1)


def run(only=None):
    targets = [(eid, clip) for eid in CLIPS if not only or eid in only
               for clip in CLIPS[eid]]
    print(f"[run] {len(targets)} jobs na fila", flush=True)
    for eid, clip in targets:
        jobs = load_jobs()
        key = f"{eid}/{clip}"
        st = jobs.get(key, {})
        if st.get("status") == "ok":
            continue
        job_id = st.get("job_id") if st.get("status") == "pending" else None
        if not job_id:
            job_id = submit(eid, clip)
            if not job_id:
                jobs = load_jobs()
                jobs[key] = {"status": "submit_failed"}
                save_jobs(jobs)
                continue
            jobs = load_jobs()
            jobs[key] = {"status": "pending", "job_id": job_id}
            save_jobs(jobs)
            print(f"[run] {key} -> job {job_id}", flush=True)
        result = "wait"
        for _ in range(72):  # até ~12 min
            time.sleep(10)
            result = F.poll_download(eid, clip, job_id)
            if result != "wait":
                break
        jobs = load_jobs()
        if result == "done":
            probs = [p for p in F.tripwires(eid, clip) if "MORTA" in p]
            jobs[key] = {"status": "ok" if not probs else "flagged",
                         "job_id": job_id, "problems": probs}
            if probs:
                print(f"[TRIPWIRE] {key}: {probs}", flush=True)
        else:
            jobs[key] = {"status": result, "job_id": job_id}
        save_jobs(jobs)
    print("[run] fim", flush=True)


def status():
    for k, v in sorted(load_jobs().items()):
        print(f"{k:32s} {v.get('status')}  {v.get('problems', '')}")


def sheet(eid):
    from PIL import Image
    clips = list(CLIPS[eid].keys())
    rows = []
    for clip in clips:
        d = F.anim_dir(eid, clip)
        if not os.path.isdir(d):
            continue
        files = sorted([f for f in os.listdir(d) if f.endswith(".png")],
                       key=lambda f: int(f.split(".")[0]))
        rows.append((clip, [Image.open(os.path.join(d, f)).convert("RGBA") for f in files]))
    if not rows:
        print("sem clips instalados")
        return
    cw = max(im.width for _, ims in rows for im in ims)
    ch = max(im.height for _, ims in rows for im in ims)
    n = max(len(ims) for _, ims in rows)
    out = Image.new("RGBA", (n * (cw + 2), len(rows) * (ch + 2)), (24, 20, 28, 255))
    for r, (clip, ims) in enumerate(rows):
        for i, im in enumerate(ims):
            out.paste(im, (i * (cw + 2), r * (ch + 2)), im)
    path = os.path.join(F.SCRATCH, f"boss_cine_clips_{eid}.png")
    out.save(path)
    print("[sheet]", path, out.size, [c for c, _ in rows])


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "run":
        run(sys.argv[2:] or None)
    elif cmd == "sheet":
        sheet(sys.argv[2])
    else:
        status()
