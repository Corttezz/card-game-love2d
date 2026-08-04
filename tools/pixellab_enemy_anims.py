#!/usr/bin/env python3
"""
tools/pixellab_enemy_anims.py — regenera as animações HURT e DEATH dos
inimigos via PixelLab `animate_image` (v3), preservando a identidade do
sprite: o frame 0 é o PNG REAL do idle (animations/idle/south/0.png), então
o monstro nunca "vira outro personagem" (bug dos templates antigos
taking-punch/falling-back-death — drift medido de 134-368/canal em TODOS os
21 do roster, Ago/2026).

Doutrina (mesma das cartas, memory/card_icon_animation.md):
  - OLHAR a arte antes de escrever o prompt (campo `keep` = whitelist do que
    não pode sumir: espada do glacier_knight, gola de palha do espantalho...)
  - hurt: flinch curto que VOLTA à pose original; silhueta/cores intactas.
  - death: conceito específico por inimigo (palha desmonta, slime vira poça,
    golem desmorona, espectro apaga) e SEMPRE termina baixo, deitado,
    imóvel no fundo do frame — nada de "flutuando de lado".
  - Tripwires pós-download: anim morta (todos frames md5 iguais) e morte
    terminando alta (altura conteúdo último frame > 0.62× idle) => RETRY.

Uso:
  python3 tools/pixellab_enemy_anims.py pilot            # só cursed_scarecrow
  python3 tools/pixellab_enemy_anims.py run [id ...]     # fábrica serial
  python3 tools/pixellab_enemy_anims.py sheet <id>       # contact sheet
  python3 tools/pixellab_enemy_anims.py status           # resumo dos jobs

Serial de propósito: a conta processa 1 job de animação por vez (lição da
fábrica de cartas — submits concorrentes são DROPADOS em silêncio).
Jobs em tools/preview_out/enemy_anim_jobs.json. Backup = git (assets
versionados).
"""
import base64
import hashlib
import io
import json
import os
import re
import sys
import time
import urllib.request

URL = "https://api.pixellab.ai/mcp"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ENEMIES_DIR = os.path.join(ROOT, "assets/sprites/characters/enemies")
JOBS_FILE = os.path.join(ROOT, "tools/preview_out/enemy_anim_jobs.json")
SCRATCH = os.environ.get("ENEMY_ANIM_SCRATCH", os.path.join(ROOT, "tools/preview_out"))

FRAMES_HURT = 6    # +1 de input = 7 instalados (HURT_FPS 12 ≈ 0.58s)
FRAMES_DEATH = 8   # +1 de input = 9 instalados (DEATH_FPS 10 = 0.9s)

HURT_SUFFIX = (" Then returns exactly to the original starting stance. "
               "Palette, colors, proportions, face and every piece of "
               "clothing and equipment stay unchanged and fully visible in "
               "every frame. Nothing disappears, nothing new appears, "
               "background stays empty.")
DEATH_SUFFIX = (" The final frames are completely motionless: the body lies "
                "crumpled LOW at the very bottom of the frame, resting on "
                "the ground. Palette, colors and equipment stay unchanged, "
                "nothing new appears, background stays empty.")

# id → keep (whitelist visual), hurt (flinch), death (conceito da morte).
# `keep` é injetado nos dois prompts. Floaters não têm "feet stay planted".
ENEMIES = {
    "cursed_scarecrow": {
        "keep": ("ragged brown hood with grey feathers, thick straw collar "
                 "and straw shoulder tufts, glowing ember eyes, stitched "
                 "grin, oversized claw hands"),
        "hurt": ("struck hard: torso and head recoil sharply backward, loose "
                 "straw wisps shake at the collar, claws jolt up, feet stay "
                 "planted"),
        "death": ("like a puppet cut from its pole it crumples straight "
                  "down: knees buckle, torso folds forward, then the whole "
                  "body collapses into a low heap of straw and cloth on the "
                  "ground, hood resting on top of the pile"),
    },
    "grave_slime": {
        "keep": ("green translucent slime body with a skull suspended "
                 "inside, red rounded base"),
        "hurt": ("struck hard: the whole gelatinous body squashes and "
                 "wobbles violently side to side, skull rattling inside"),
        "death": ("the slime loses cohesion and melts straight down, body "
                  "flattening into a wide low puddle on the ground with the "
                  "skull settling half-sunk in the middle"),
    },
    "stone_golem": {
        "keep": ("slim bronze-brown stone construct, segmented plated body, "
                 "glowing core"),
        "hurt": ("struck hard: staggers backward, chest plates rattle, "
                 "small stone chips fly off, arms flail briefly, feet stay "
                 "planted"),
        "death": ("the joints give out one by one: it sinks to its knees, "
                  "torso tips forward, and the whole construct collapses "
                  "into a low pile of broken stone segments on the ground"),
    },
    "abyss_wraith": {
        "keep": ("plain black hooded robe, white skull face, hovering "
                 "slightly"),
        "hurt": ("struck hard: the hovering robe jolts backward, hood "
                 "snapping, skull face flickering dimmer for a moment"),
        "death": ("the robe loses its shape and deflates: it sinks straight "
                  "down and settles as a flat empty black cloth heap on the "
                  "ground, the skull face fading out as it falls"),
    },
    "abyss_tyrant": {
        "keep": ("massive horned demon skull head, glowing orange chest "
                 "core, heavy dark armor with spiked pauldrons, dark cape"),
        "hurt": ("struck hard: the huge frame rocks backward, cape swings, "
                 "chest core flares brighter for an instant, feet stay "
                 "planted"),
        "death": ("the heavy armor gives way: it drops to both knees with "
                  "weight, chest core dimming to black, then the armored "
                  "bulk topples forward flat onto the ground, horns and "
                  "cape settling last"),
    },
    "blood_duke": {
        "keep": ("pale vampire count, slicked black hair, red glowing eyes, "
                 "black cape with red lining, white gloves, gold trim"),
        "hurt": ("struck hard: he doubles over clutching his chest, cape "
                 "flaring behind him, then straightens, feet stay planted"),
        "death": ("he clutches his chest, staggers, sinks to his knees and "
                  "collapses face-down, the great cape draping over his "
                  "fallen body like a shroud on the ground"),
    },
    "bog_ghoul": {
        "keep": ("hunched rotting green ghoul, sunken glowing eyes, ragged "
                 "torn flesh, long arms"),
        "hurt": ("struck hard: the hunched body lurches backward, head "
                 "whipping, long arms swinging loose, feet stay planted"),
        "death": ("its legs give out and the rotten body slumps forward, "
                  "folding into a low motionless heap of limbs on the "
                  "ground"),
    },
    "carrion_king": {
        "keep": ("skeletal king with dark feathered wings, gold crown, "
                 "exposed ribcage, purple tattered robes"),
        "hurt": ("struck hard: wings snap open in shock, skeletal torso "
                 "recoils, crown tilting, then wings settle back"),
        "death": ("the wings droop lifeless, it falls to its knees, the "
                  "skeletal body crumples sideways to the ground in a low "
                  "heap of bones, feathers and robes, the crown toppling "
                  "off beside the skull"),
    },
    "dusk_shade": {
        "keep": ("hooded wraith wreathed in wispy purple flames, dark robe, "
                 "hovering"),
        "hurt": ("struck hard: the hovering shade jolts backward, purple "
                 "flames guttering low for a moment, hood snapping"),
        "death": ("the purple flames gutter and die out, the dark robe "
                  "collapses inward and sinks straight down into a small "
                  "flat smoldering heap on the ground"),
    },
    "eclipse_queen": {
        "keep": ("pale vampire queen, huge purple bat-wing cloak, dark "
                 "crown, long dark gown"),
        "hurt": ("struck hard: she recoils, the great wing cloak flares "
                 "wide in shock, then folds back around her, feet stay "
                 "planted"),
        "death": ("her knees give way and she FALLS all the way down to "
                  "the ground: her upright figure disappears as she "
                  "collapses forward, the huge bat wings crumpling and "
                  "folding FLAT over her fallen body, ending as a low "
                  "flat mound of folded wings and gown lying on the "
                  "ground, less than half her standing height, no part "
                  "of her still upright"),
    },
    "ember_imp": {
        "keep": ("four-legged lava imp, cracked black body with glowing "
                 "lava seams, flame mane and flame tail tip"),
        "hurt": ("struck hard: the imp flinches back on all four legs, "
                 "flame mane whipping, lava seams flaring, paws stay on "
                 "the ground"),
        "death": ("every flame dies: the mane flame and the tail flame "
                  "both shrink and extinguish COMPLETELY, the tail drops "
                  "and lies flat on the ground, lava seams cooling to "
                  "dark, the body slumps down flat on its belly, legs "
                  "splayed, ending as a motionless dark cooling husk "
                  "lying low on the ground with NO flame anywhere"),
    },
    "frost_wight": {
        "keep": ("skeletal wight in icy pale tattered robes, frost-blue "
                 "glow, hood"),
        "hurt": ("struck hard: the frame jerks backward, tattered robes "
                 "swirling, frost glow flickering, then settles"),
        "death": ("the icy glow fades out, the skeletal frame buckles and "
                  "crumples straight down into a low heap of bones and "
                  "frozen rags on the ground"),
    },
    "glacier_knight": {
        "keep": ("heavy pale-blue ice armor with icy flame wisps, great "
                 "frost greatsword held low in front"),
        "hurt": ("struck hard: the knight staggers a step back, armor "
                 "plates jolting, but KEEPS GRIPPING the greatsword, icy "
                 "flames flickering, feet stay planted"),
        "death": ("the knight drops to one knee leaning on the greatsword, "
                  "then the grip fails and armor and sword crash down "
                  "together, ending as a low heap of armor plates with the "
                  "sword lying flat beside it on the ground"),
    },
    "harvest_reaper": {
        "keep": ("hooded reaper with golden wheat-straw shoulders, long "
                 "scythe with dark blade, skull face"),
        "hurt": ("struck hard: recoils sharply, wheat shoulders shedding a "
                 "few strands, but KEEPS GRIPPING the scythe, feet stay "
                 "planted"),
        "death": ("the scythe slips from its grip and falls flat, the "
                  "reaper folds forward and collapses into a low heap of "
                  "robes and wheat straw on the ground beside the fallen "
                  "scythe"),
    },
    "mire_hag": {
        # NOTA (retry Ago/2026): a arte do idle NÃO tem cajado — a 1ª
        # geração materializava um do nada porque o prompt citava "staff".
        "keep": ("swamp witch with wide-brimmed pointed hat keeping its "
                 "exact shape, grey hair, green cloak, bone trinkets, "
                 "hands empty"),
        "hurt": ("struck hard: she doubles over in pain, hat brim "
                 "flopping, cloak swinging, hands stay empty, feet stay "
                 "planted"),
        "death": ("she crumples straight down, cloak spreading around her, "
                  "ending as a low mound of green cloth on the ground with "
                  "the wide-brimmed hat settling on top"),
    },
    "moon_gargoyle": {
        "keep": ("crouched grey stone gargoyle, bat wings, pointed ears, "
                 "glowing eyes"),
        "hurt": ("struck hard: the stone body rocks back on its haunches, "
                 "wings snapping open, small stone chips flying, then "
                 "settles back into the crouch"),
        "death": ("the stone body CRACKS apart and BREAKS to pieces: the "
                  "eye glow fades to black, the wings break off and fall, "
                  "the whole statue crumbles downward chunk by chunk and "
                  "ends as a FLAT low pile of broken grey stone rubble "
                  "scattered on the ground, nothing left standing, no "
                  "body shape remaining"),
    },
    "obsidian_sentinel": {
        # NOTA (retry Ago/2026): a arte NÃO tem escudo separado — a 1ª
        # geração materializava um "tower shield" flutuante do nada (que na
        # morte ficava de pé feito lápide). Prompt sem citar escudo.
        "keep": ("black obsidian plate armor with glowing orange lava "
                 "seams and a grey kite-shaped tabard on the front, "
                 "hands empty at its sides"),
        "hurt": ("struck hard: the armored body staggers a step back, "
                 "lava seams flaring bright for an instant, armor plates "
                 "rattling, hands stay empty, feet stay planted"),
        "death": ("the lava seams cool and fade to black, it drops to its "
                  "knees, and the black armor collapses forward, ending "
                  "as a low flat heap of dark armor plates lying on the "
                  "ground, nothing standing"),
    },
    "rot_colossus": {
        "keep": ("huge green rotting colossus with antler branches on its "
                 "head, massive shoulders, tusked jaw"),
        "hurt": ("struck hard: the massive torso rocks backward, antlers "
                 "swaying, arms swinging heavily, feet stay planted"),
        "death": ("the colossus sways, drops to one knee with crushing "
                  "weight, then the huge body topples forward and lands "
                  "flat, ending as a low mountainous heap on the ground "
                  "with the antlers resting sideways"),
    },
    "rune_golem": {
        "keep": ("bulky grey stone golem covered in glowing purple runes, "
                 "massive fists"),
        "hurt": ("struck hard: staggers backward, purple runes flickering "
                 "erratically, stone chips flying from the shoulders, feet "
                 "stay planted"),
        "death": ("the purple runes dim and go dark one by one, the golem "
                  "sinks to its knees and breaks apart, collapsing into a "
                  "low pile of cracked grey stones on the ground"),
    },
    "tower_lich": {
        "keep": ("lich king with gold crown, pale skull face, purple "
                 "robes, staff topped with a glowing orb"),
        "hurt": ("struck hard: recoils, robes swirling, the staff orb "
                 "flickering, but KEEPS GRIPPING the staff, crown stays "
                 "on"),
        "death": ("the orb light dies, the staff falls flat from its hand, "
                  "and the lich crumples straight down into a low heap of "
                  "purple robes and bones on the ground, the crown rolling "
                  "to rest beside the skull"),
    },
    "winter_monarch": {
        "keep": ("ice king in pale blue armor with crown of ice shards, "
                 "long staff with glowing blue gem, frost aura"),
        "hurt": ("struck hard: staggers backward, frost aura flaring, ice "
                 "armor plates rattling, but KEEPS GRIPPING the staff, "
                 "feet stay planted"),
        "death": ("the staff gem goes dark and the staff drops flat, the "
                  "ice armor cracks and the monarch collapses to his knees "
                  "then flat forward, ending as a low heap of shattered "
                  "ice plates and robes on the ground"),
    },
    "mire_hag_placeholder_do_not_use": None,
}
ENEMIES.pop("mire_hag_placeholder_do_not_use")


def token():
    env = os.environ.get("PIXELLAB_TOKEN")
    if env:
        return env
    path = os.path.expanduser("~/.claude.json")
    try:
        with open(path) as f:
            cfg = json.load(f)
        for proj in cfg.get("projects", {}).values():
            srv = proj.get("mcpServers", {}).get("pixellab")
            if srv:
                auth = srv.get("headers", {}).get("Authorization", "")
                if auth.startswith("Bearer "):
                    return auth[len("Bearer "):]
        srv = cfg.get("mcpServers", {}).get("pixellab")
        if srv:
            auth = srv.get("headers", {}).get("Authorization", "")
            if auth.startswith("Bearer "):
                return auth[len("Bearer "):]
    except Exception as e:
        print(f"[token] falha lendo {path}: {e}")
    raise SystemExit("token PixelLab não encontrado")


TOKEN = token()


def rpc(method, params, timeout=180):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method,
                       "params": params}).encode()
    req = urllib.request.Request(URL, data=body, headers={
        "Authorization": f"Bearer {TOKEN}",
        "Content-Type": "application/json",
        "Accept": "application/json, text/event-stream",
    })
    raw = urllib.request.urlopen(req, timeout=timeout).read().decode()
    for line in raw.splitlines():
        if line.startswith("data:"):
            return json.loads(line[5:])
    raise RuntimeError("sem data: na resposta")


def tool_text(result):
    return "\n".join(p.get("text", "") for p in result["result"]["content"]
                     if p.get("type") == "text")


def fetch(url):
    headers = {"User-Agent": "curl/8.4.0"}
    if "api.pixellab.ai" in url:
        headers["Authorization"] = f"Bearer {TOKEN}"
    req = urllib.request.Request(url, headers=headers)
    return urllib.request.urlopen(req, timeout=120).read()


def load_jobs():
    if os.path.exists(JOBS_FILE):
        with open(JOBS_FILE) as f:
            return json.load(f)
    return {}


def save_jobs(jobs):
    os.makedirs(os.path.dirname(JOBS_FILE), exist_ok=True)
    with open(JOBS_FILE, "w") as f:
        json.dump(jobs, f, indent=2)


def idle_frame_path(eid):
    return os.path.join(ENEMIES_DIR, eid, "animations/idle/south/0.png")


def anim_dir(eid, anim):
    return os.path.join(ENEMIES_DIR, eid, "animations", anim, "south")


def build_prompt(eid, anim):
    spec = ENEMIES[eid]
    if anim == "hurt":
        return (f"{spec['hurt']}. It keeps its {spec['keep']}."
                + HURT_SUFFIX)
    return (f"{spec['death']}. It keeps its {spec['keep']}."
            + DEATH_SUFFIX)


def submit(eid, anim, seed=None):
    with open(idle_frame_path(eid), "rb") as f:
        b64 = base64.b64encode(f.read()).decode()
    args = {
        "action": build_prompt(eid, anim),
        "first_frame_base64": b64,
        "frame_count": FRAMES_HURT if anim == "hurt" else FRAMES_DEATH,
    }
    if seed is not None:
        args["seed"] = seed
    text = tool_text(rpc("tools/call", {"name": "animate_image",
                                        "arguments": args}))
    m = re.search(r"([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-"
                  r"[0-9a-f]{12})", text)
    if not m:
        print(f"[submit] {eid}/{anim}: SEM JOB ID — {text[:200]}", flush=True)
        return None
    return m.group(1)


def poll_download(eid, anim, job_id):
    """Uma checada no get_image. Retorna 'done'|'wait'|'error'."""
    try:
        text = tool_text(rpc("tools/call", {"name": "get_image",
                                            "arguments": {"job_id": job_id}}))
    except Exception as e:
        print(f"[poll] {eid}/{anim}: erro get_image ({e})", flush=True)
        return "wait"
    low = text.lower()
    if "status: failed" in low or "status: error" in low:
        print(f"[poll] {eid}/{anim}: FALHOU — {text[:200]}", flush=True)
        return "error"
    if "status: completed" not in low:
        return "wait"
    # Formato atual: "frames: N" + "download: <base>/download?index=0 ..."
    mN = re.search(r"frames:\s*(\d+)", text)
    mURL = re.search(r"(https?://\S+/download)\?index=\d+", text)
    if not (mN and mURL):
        print(f"[poll] {eid}/{anim}: completo mas sem URLs — {text[:200]}",
              flush=True)
        return "error"
    n, base = int(mN.group(1)), mURL.group(1)
    dest = anim_dir(eid, anim)
    os.makedirs(dest, exist_ok=True)
    for f in os.listdir(dest):
        if f.endswith(".png"):
            os.remove(os.path.join(dest, f))
    for i in range(n):
        with open(os.path.join(dest, f"{i}.png"), "wb") as f:
            f.write(fetch(f"{base}?index={i}"))
    print(f"[ok] {eid}/{anim}: {n} frames instalados", flush=True)
    return "done"


def tripwires(eid, anim):
    """Valida a anim instalada. Retorna lista de problemas (vazia = ok)."""
    from PIL import Image
    dest = anim_dir(eid, anim)
    files = sorted([f for f in os.listdir(dest) if f.endswith(".png")],
                   key=lambda f: int(f.split(".")[0]))
    probs = []
    hashes = set()
    for f in files:
        with open(os.path.join(dest, f), "rb") as fh:
            hashes.add(hashlib.md5(fh.read()).hexdigest())
    if len(hashes) <= 1:
        probs.append("ANIM MORTA (todos os frames iguais)")
    if anim == "death" and len(files) >= 2:
        first = Image.open(os.path.join(dest, files[0])).convert("RGBA")
        last = Image.open(os.path.join(dest, files[-1])).convert("RGBA")
        bb0, bbN = first.getbbox(), last.getbbox()
        if bb0 and bbN:
            h0 = bb0[3] - bb0[1]
            hN = bbN[3] - bbN[1]
            # 0.68: monte com capuz/chapéu por cima chega a ~0.63 e é
            # legítimo (piloto scarecrow); em pé de verdade é 0.8-1.0.
            if hN > h0 * 0.68:
                probs.append(f"MORTE ALTA (pose final {hN}px vs idle {h0}px "
                             f"= {hN/h0:.2f}, alvo <=0.68)")
            # corpo tem que descansar perto do fundo do CONTEÚDO original
            if bbN[3] < bb0[3] - 6:
                probs.append(f"CORPO FLUTUANDO (base do conteúdo {bbN[3]} "
                             f"vs chão {bb0[3]})")
    return probs


def sheet(eid):
    from PIL import Image
    out = os.path.join(SCRATCH, f"enemy_{eid}_sheet.png")
    rows = []
    for anim in ["idle", "hurt", "death"]:
        d = anim_dir(eid, anim)
        fs = sorted([f for f in os.listdir(d) if f.endswith(".png")],
                    key=lambda f: int(f.split(".")[0]))
        rows.append([Image.open(os.path.join(d, f)).convert("RGBA")
                     for f in fs])
    S = 2
    w = max(sum(im.width for im in r) + 6 * len(r) for r in rows) * S
    h = sum(max(im.height for im in r) for r in rows) * S + 24
    im_sheet = Image.new("RGBA", (w, h), (30, 24, 20, 255))
    y = 0
    for r in rows:
        x = 0
        rh = max(im.height for im in r)
        for im in r:
            im_sheet.paste(im.resize((im.width * S, im.height * S),
                                     Image.NEAREST),
                           (x, y + (rh - im.height) * S))
            x += (im.width + 6) * S
        y += rh * S + 8
    im_sheet.save(out)
    print(out)


def run(only=None):
    """Fábrica serial: para cada inimigo×anim pendente, submete, espera,
    baixa, valida. 1 job por vez (limite da conta)."""
    targets = []
    for eid in ENEMIES:
        if only and eid not in only:
            continue
        for anim in ["hurt", "death"]:
            targets.append((eid, anim))
    print(f"[run] {len(targets)} jobs na fila", flush=True)
    for eid, anim in targets:
        jobs = load_jobs()
        key = f"{eid}/{anim}"
        st = jobs.get(key, {})
        if st.get("status") == "ok":
            continue
        job_id = st.get("job_id") if st.get("status") == "pending" else None
        if not job_id:
            job_id = submit(eid, anim)
            if not job_id:
                jobs = load_jobs()
                jobs[key] = {"status": "submit_failed"}
                save_jobs(jobs)
                continue
            jobs = load_jobs()
            jobs[key] = {"status": "pending", "job_id": job_id}
            save_jobs(jobs)
            print(f"[run] {key} -> job {job_id}", flush=True)
        # espera ESTE job terminar antes do próximo (serial)
        result = "wait"
        for _ in range(60):  # até ~10min
            time.sleep(10)
            result = poll_download(eid, anim, job_id)
            if result != "wait":
                break
        jobs = load_jobs()
        if result == "done":
            probs = tripwires(eid, anim)
            jobs[key] = {"status": "ok" if not probs else "flagged",
                         "job_id": job_id, "problems": probs}
            if probs:
                print(f"[TRIPWIRE] {key}: {probs}", flush=True)
        else:
            jobs[key] = {"status": result, "job_id": job_id}
        save_jobs(jobs)
    print("[run] fim", flush=True)


def status():
    jobs = load_jobs()
    counts = {}
    for k, v in sorted(jobs.items()):
        s = v.get("status", "?")
        counts[s] = counts.get(s, 0) + 1
        extra = " " + "; ".join(v.get("problems", [])) if v.get("problems") else ""
        print(f"  {k:<28} {s}{extra}")
    print(f"[status] {counts}")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "pilot":
        run(only={"cursed_scarecrow"})
    elif cmd == "run":
        only = set(sys.argv[2:]) or None
        run(only)
    elif cmd == "sheet":
        sheet(sys.argv[2])
    elif cmd == "status":
        status()
    else:
        print(__doc__)
