#!/usr/bin/env python3
"""Arte das cenas de abertura de ato (docs/cenas_de_ato/STYLE.md) no PixelLab.

uso: python tools/pixellab_act_intro.py queue <ato> <nome...>   (cria jobs)
     python tools/pixellab_act_intro.py poll <ato>              (baixa as candidatas)
     python tools/pixellab_act_intro.py balance
Saída bruta: tools/preview_out/cenas_ato/ato<N>/raw/<nome>__<i>.png
Chave: a mesma do pixellab_enemy_anims (PIXELLAB_TOKEN ou ~/.claude.json), nunca impressa.
"""
import base64, json, os, re, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixellab_enemy_anims as F

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = lambda act: os.path.join(ROOT, "tools", "preview_out", "cenas_ato", f"ato{act}")

SUFFIX = (" Pixel art, crisp pixels, earthy natural palette, NO neon colors, NO bright cyan or magenta, "
          "detailed shading with clear darks and mid-tones, painterly lush depth, no text, no letters, no UI.")
DIORAMA = (" Every tree and bush has volume: canopy in front, middle and back planes, leaves overlapping trunks, "
           "dappled shadow, lit faces toward the light and dark faces away from it.")

ACT = {
    1: {
        "light": "warm golden late-afternoon sun low on the right horizon behind the trees",
        "specs": {
            # nome: (ferramenta, w, h, no_background, descrição)
            "master": ("pro", 688, 384, False,
                "Wide establishing shot of ruined farmland at golden dusk seen from under the arch of a huge ancient oak. "
                "Massive gnarled oak trunks on the far left and far right edges, their heavy leafy branches arching across "
                "the whole top of the frame like a natural doorway, dark and backlit in the foreground. Through the arch: "
                "a mossy cobblestone path starts at the bottom center-right and winds into the distance between golden "
                "grass fields, broken old stone field walls and a toppled wooden fence, a small wayside shrine with a "
                "lantern beside the path, far away a ruined castle on a hill and blue-grey mountains, a peach and gold "
                "sky with a soft glowing sun low on the right, light shafts through the leaves, soft muted teal-green "
                "highlights on the foliage, floating dust motes, a little low mist on the fields. A single small cloaked "
                "and hooded traveler with a backpack and a plain wooden walking stick stands on the path in the middle "
                "distance, seen from behind, looking at the land ahead. The left third of the sky is calm and empty."),
        },
    },
    2: {
        "light": 'cold silver moonlight from a moon high on the right, deep blue-violet night',
        "specs": {"master": ("pro", 688, 384, False, "Wide establishing shot of misty highland hills at night seen from under the arch of old twisted pine and yew trees. Gnarled dark trunks on the far left and far right edges, their needled branches arching across the whole top of the frame like a natural doorway, dark and backlit in the foreground. Through the arch: a worn flagstone path starts at the bottom center-right and climbs into the distance across heather-covered hills and scattered standing stones, a broken wooden signpost beside the path, far away a tall ruined sorcerer's watchtower on a crag with one faint violet window light, layered blue-grey hills fading into mist, a deep blue-violet night sky with a few stars and a pale moon on the right, thin drifting clouds, soft cold rim light on the branches, low fog in the valleys. A single small cloaked and hooded traveler with a backpack and a plain wooden walking stick stands on the path in the middle distance, seen from behind, looking at the land ahead. The left third of the sky is calm and empty.")},
    },
    3: {
        "light": 'a huge swollen blood-red sun sinking low behind the chasm on the right, smoky crimson air',
        "specs": {"master": ("pro", 688, 384, False, 'Wide establishing shot of a road descending toward a vast dark chasm seen from under the arch of charred dead trees. Blackened twisted trunks on the far left and far right edges, their bare thorny branches arching across the whole top of the frame like a natural doorway, very dark and backlit in the foreground. Through the arch: a cracked stone road starts at the bottom center-right and winds down between jagged dark rocks and toppled stone pillars toward a deep abyss, an old iron lantern post with a dim red flame beside the road, far away the broken edge of the chasm with glowing cracks and distant ruined spires, a smoky crimson and rust sky with a swollen red sun low on the right, drifting ash, red haze in the depths. Dark fantasy, ominous, still with the same calm composition. A single small cloaked and hooded traveler with a backpack and a plain wooden walking stick stands on the path in the middle distance, seen from behind, looking at the land ahead. The left third of the sky is calm and empty.')},
    },
    4: {
        "light": 'pale cold white winter sun high on the right through thin cloud, blue-grey frozen air',
        "specs": {"master": ("pro", 688, 384, False, 'Wide establishing shot of a spectral frozen glacier valley seen from under the arch of old snow-laden fir trees. Dark fir trunks on the far left and far right edges, their heavy snow-covered branches arching across the whole top of the frame like a natural doorway, dark and backlit in the foreground. Through the arch: a snowy stone path with half-buried flagstones starts at the bottom center-right and winds into the distance across a frozen plain, a leaning frost-covered waymarker stone with a faint pale blue glow beside the path, far away a vast pale blue glacier wall with icy spires and a frozen ruined citadel, a cold blue-grey and pearl sky with a pale white sun on the right, faint ghostly wisps in the air, light falling snow, cold mist on the ground. A single small cloaked and hooded traveler with a backpack and a plain wooden walking stick stands on the path in the middle distance, seen from behind, looking at the land ahead. The left third of the sky is calm and empty.')},
    },
    5: {
        "light": 'a sickly yellow-green moon high on the right, murky green night haze',
        "specs": {"master": ("pro", 688, 384, False, 'Wide establishing shot of a rotting swamp at night seen from under the arch of drooping dead willow and mangrove trees. Twisted mossy trunks on the far left and far right edges, their hanging moss-draped branches arching across the whole top of the frame like a natural doorway, dark and backlit in the foreground. Through the arch: a path of old wooden planks and mossy stepping stones starts at the bottom center-right and winds into the distance over still dark water, reeds and rotting stumps, a crooked post with a small hanging lantern giving a dim green-yellow glow beside the path, far away a sunken ruined shrine and dead trees in thick mist, a murky green and olive night sky with a sickly pale moon on the right, a few faint glowing marsh lights over the water, heavy low mist. A single small cloaked and hooded traveler with a backpack and a plain wooden walking stick stands on the path in the middle distance, seen from behind, looking at the land ahead. The left third of the sky is calm and empty.')},
    },
    6: {
        "light": 'a huge low setting sun partly covered by a dark eclipse disc in the center-right sky, deep amber and violet dusk',
        "specs": {"master": ("pro", 688, 384, False, 'Wide establishing shot of vast twilight fields at the end of the journey seen from under the arch of old autumn trees. Gnarled dark trunks on the far left and far right edges, their branches heavy with amber and crimson autumn leaves arching across the whole top of the frame like a natural doorway, dark and backlit in the foreground. Through the arch: a long stone road starts at the bottom center-right and runs far into the distance between rolling fields of tall amber grass and old stone markers, a ruined stone archway gate beside the road, far away a dark spired eclipse palace on the horizon, a dramatic amber, rose and violet dusk sky with a huge low sun on the center-right partly covered by a dark eclipse disc ringed with light, long light shafts, drifting leaves. Grave and bittersweet, the end of a long road. A single small cloaked and hooded traveler with a backpack and a plain wooden walking stick stands on the path in the middle distance, seen from behind, looking at the land ahead. The left third of the sky is calm and empty.')},
    },
}


def call(tool, args, timeout=300):
    return F.tool_text(F.rpc("tools/call", {"name": tool, "arguments": args}, timeout=timeout))


def b64(path):
    return base64.b64encode(open(path, "rb").read()).decode()


def jobs_path(act):
    return os.path.join(OUT(act), "jobs.json")


def load_jobs(act):
    p = jobs_path(act)
    return json.load(open(p)) if os.path.exists(p) else {}


def queue(act, names, extra=None):
    os.makedirs(os.path.join(OUT(act), "raw"), exist_ok=True)
    J = load_jobs(act)
    spec = ACT[act]
    series = act != 1    # atos 2-6: a pintura do ato 1 é a referência da SÉRIE (composição e traço), não da paleta
    style = b64(os.path.join(OUT(1), "raw", "master__0.png") if series else os.path.join(OUT(act), "style_ref.png"))
    for name in names:
        tool, w, h, nobg, desc = (extra or {}).get(name) or spec["specs"][name]
        desc = desc + " Lighting: " + spec["light"] + "." + DIORAMA + SUFFIX
        refs = [{"base64": style, "usage": "style only: pixel scale, palette, outline weight and shading of this "
                                           "game's world art; do not copy its layout or any character"}]
        if series:
            refs = [{"base64": style, "usage": "same series: keep this exact framing (tree arch on the sides and top, "
                     "path from bottom center-right, small traveler from behind, calm empty sky on the left), the same "
                     "pixel scale, outline weight and shading; use a completely different biome, palette and light "
                     "as described"}]
        master = os.path.join(OUT(act), "master.png")
        if name != "master" and os.path.exists(master):
            refs.insert(0, {"base64": b64(master), "usage": "this is the full scene: draw ONLY the requested part of it, "
                                                            "same perspective, scale, colors and lighting"})
        if tool == "pro":
            args = {"description": desc, "width": w, "height": h, "no_background": nobg,
                    "style_image_base64": style,
                    "style_copy": ["outline", "detail", "shading"] if series else ["color_palette", "outline", "detail", "shading"],
                    "reference_images": refs}
            text = call("create_image_pro", args)
        else:
            args = {"description": desc, "width": w, "height": h, "no_background": nobg,
                    "outline": "single color black outline", "shading": "detailed shading",
                    "detail": "highly detailed", "view": "side", "text_guidance_scale": 8}
            text = call("create_image_pixflux", args)
        m = re.search(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", text)
        J[name] = {"job": m.group(0) if m else None, "tool": tool}
        print(f"[queue] {name}: {J[name]['job']} {text[:100]!r}", flush=True)
        json.dump(J, open(jobs_path(act), "w"), indent=1)
        time.sleep(2)


def poll(act):
    J = load_jobs(act)
    raw = os.path.join(OUT(act), "raw")
    pending = {n: j for n, j in J.items() if j.get("job") and not os.path.exists(os.path.join(raw, n + "__0.png"))}
    t0 = time.time()
    while pending and time.time() - t0 < 1500:
        for name, j in list(pending.items()):
            text = call("get_image", {"job_id": j["job"]})
            low = text.lower()
            if "status: failed" in low or "status: error" in low:
                print(f"[poll] {name}: FALHOU {text[:160]}"); pending.pop(name); continue
            if "status: completed" not in low:
                continue
            urls = []
            mf = re.search(r"frames:\s*(\d+)", text)
            m0 = re.search(r"(https?://\S+download\?index=)0", text)
            if mf and m0:
                urls = [m0.group(1) + str(i) for i in range(int(mf.group(1)))]
            if not urls:
                urls = [u.rstrip(")\"',") for u in re.findall(r"https?://\S+", text) if "download" in u or u.endswith(".png")]
            for i, u in enumerate(urls):
                open(os.path.join(raw, f"{name}__{i}.png"), "wb").write(F.fetch(u))
            print(f"[ok] {name}: {len(urls)} candidata(s)", flush=True)
            pending.pop(name)
        if pending:
            time.sleep(20)
    return pending


def balance():
    t = call("get_balance", {})
    return {k: v for k, v in re.findall(r"(generations_remaining|generations_used):\s*(\d+)", t)}


# ------------------------------------------------------------------ animações curtas (loops)
def submit(tool, args):
    for _ in range(60):
        text = call(tool, args)
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
    while time.time() - t0 < 1500:
        try:
            text = call("get_image", {"job_id": job})
        except Exception:
            time.sleep(15); continue
        low = text.lower()
        if "status: failed" in low or "status: error" in low:
            print(f"[FAIL] {prefix}: {text[:300]}"); return []
        if "status: completed" in low:
            mN = re.search(r"frames:\s*(\d+)", text)
            mU = re.search(r"(https?://\S+/download)\?index=\d+", text)
            n = int(mN.group(1)) if mN else 1
            paths = []
            for i in range(n):
                url = (mU.group(1) + f"?index={i}") if mU else re.findall(r"https?://\S+", text)[0].rstrip(")\"',")
                p = os.path.join(dest, f"{prefix}_{i}.png")
                open(p, "wb").write(F.fetch(url)); paths.append(p)
            return paths
        time.sleep(15)
    return []


def pad(src, size, dst, anchor="bottom"):
    from PIL import Image
    im = Image.open(src).convert("RGBA")
    c = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    y = size - im.height - 2 if anchor == "bottom" else (size - im.height) // 2
    c.alpha_composite(im, ((size - im.width) // 2, y))
    c.save(dst)
    return dst


def anim(act, name, first, action, frames=6, loop=True):
    dest = os.path.join(OUT(act), "anim", name)
    args = {"action": action + " Keep the exact same character design, colors, outline and pixel scale; pixel art.",
            "first_frame_base64": b64(first), "frame_count": frames}
    if loop:
        args["last_frame_base64"] = b64(first)
    job, text = submit("animate_image", args)
    if not job:
        print(f"[FAIL] {name}: {text[:300]}"); return []
    got = wait(job, dest, name)
    print(f"[ok] {name}: {len(got)} quadros em {dest}", flush=True)
    return got


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "balance":
        print(balance())
    elif cmd == "queue":
        queue(int(sys.argv[2]), sys.argv[3:])
    elif cmd == "anim_traveler":
        act = int(sys.argv[2]); d = os.path.join(OUT(act), "anim"); os.makedirs(d, exist_ok=True)
        first = pad(os.path.join(ROOT, "assets", "sprites", "act_intro", f"act{act}", "traveler.png"), 64, os.path.join(d, "traveler_first.png"))
        anim(act, "traveler", first, "The hooded traveler seen from behind stands still on the path; the long cloak and the hood "
             "gently ripple and sway in a soft breeze, a slight breathing motion. Feet stay planted, no walking, no turning.", 8)
    elif cmd == "crow":
        act = int(sys.argv[2]); d = os.path.join(OUT(act), "anim"); os.makedirs(d, exist_ok=True)
        job, text = submit("create_image_pixflux", {"description": "a single black crow flying, side view facing right, wings "
                          "spread mid-flap, small dark fantasy pixel art bird, dark grey-black feathers with subtle warm rim light"
                          + SUFFIX, "width": 32, "height": 32, "no_background": True,
                          "outline": "single color black outline", "shading": "medium shading", "detail": "medium detail",
                          "view": "side"})
        got = wait(job, d, "crow_base") if job else []
        print("crow base:", got, (text or "")[:120])
        if got:
            anim(act, "crow", got[0], "The crow flies in place, flapping its wings in a smooth full wingbeat cycle, body level, "
                 "facing right.", 6)
    elif cmd == "poll":
        left = poll(int(sys.argv[2]))
        print("pendentes:", sorted(left))

