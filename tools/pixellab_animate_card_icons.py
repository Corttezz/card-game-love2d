#!/usr/bin/env python3
"""
tools/pixellab_animate_card_icons.py — anima ícones 64×64 de cartas raras/
lendárias via PixelLab (animate_object v3) e instala os frames no contrato do
IconFramesLoader:

    assets/sprites/icons_anim/<icon_name>/frame_NNN.png
    assets/sprites/icons_anim/<icon_name>/meta.lua      (fps)

Uso:
  python3 tools/pixellab_animate_card_icons.py queue   # enfileira animações
  python3 tools/pixellab_animate_card_icons.py poll    # baixa prontas + meta
  python3 tools/pixellab_animate_card_icons.py check   # frames vivos? (md5)

Pré-requisito por entrada: object_id do ícone no PixelLab (os do lote
Jul/2026 estão em tools/preview_out/newcards_jobs.json). Ícones antigos sem
object_id: gerar via MCP com custom_start_frame_base64 (ver
memory/card_icon_animation.md).

Regras do contrato (memory/card_icon_animation.md):
  - mode v3, frame_count 8 (vira 9 frames com o reference frame 0 = ícone
    original — manter keep_first_frame default garante que o frame 0 é
    IDÊNTICO ao PNG estático de assets/sprites/icons/).
  - Descrição SEMPRE: movimento sutil de idle + "everything else perfectly
    static" + "seamless loop, colors and silhouette unchanged".
  - Depois de baixar: rodar `check` (v3 às vezes anima morto — lição do
    luminaire_engine) e `love . preview_card_anim <card_id>` pra validar.

Jobs em tools/preview_out/icon_anim_jobs.json.
"""
import base64
import hashlib
import json
import os
import re
import sys
import time
import urllib.request

URL = "https://api.pixellab.ai/mcp"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
JOBS_FILE = os.path.join(ROOT, "tools/preview_out/icon_anim_jobs.json")
OUT_ROOT = os.path.join(ROOT, "assets/sprites/icons_anim")

SUFFIX = (", subtle idle motion, seamless loop, colors and silhouette "
          "unchanged, everything else perfectly static")

# Objeto host pra ícones SEM object_id próprio: animate_object com
# custom_start_frame_base64 usa as dimensões da imagem como canvas — o host
# só "hospeda" o grupo de animação (mesmo padrão das anims do WorldRoad).
HOST_OBJECT = "acbad108-e76b-4cf6-8247-dee3ab2427ab"

# icon_name (== nome do PNG em assets/sprites/icons/, sem extensão) →
#   object_id : objeto PixelLab de origem do ícone; OMITIR pra usar o
#               HOST_OBJECT com o PNG do ícone como start frame
#   anim      : descrição do movimento (foco no QUE se move e no que NÃO).
#               REGRA: olhar a imagem ANTES de escrever; intensidade segue a
#               raridade (basic/common = quase imperceptível). Ver
#               memory/card_icon_animation.md.
#   fps       : cadência de playback no jogo (meta.lua)
ANIMS = {
    # ===== rare (movimento visível ok) =====
    "warrior_standard_bearer": {
        "object_id": "acbad108-e76b-4cf6-8247-dee3ab2427ab",
        "anim": ("tattered war banner cloth waving gently in a slow breeze, "
                 "fabric edges rippling softly, the spear pole and golden "
                 "bull crest emblem stay perfectly static"),
        "fps": 8,
    },
    # ===== starters (basic — quase imperceptível, fps mais baixo) =====
    "warrior_strike": {
        "anim": ("armored warrior breathing calmly in idle stance, chest and "
                 "shoulders rising and falling very slightly, barely "
                 "perceptible motion, armor sword and pose stay unchanged"),
        "fps": 6,
    },
    "warrior_defend": {
        "anim": ("the kneeling knight's dark red cape swaying very gently in "
                 "a faint breeze, barely perceptible breathing, the round "
                 "shield and armor stay perfectly static"),
        "fps": 6,
    },
    "mage_zap": {
        # v3. v1: mão fechou em punho. v2: mão ok mas o brilho ESTOUROU
        # (frames quase brancos). Além de congelar a mão, LIMITAR a
        # amplitude da luz explicitamente.
        "anim": ("a tiny spark of light at the palm center glinting and "
                 "shifting very slightly, the glow brightness stays almost "
                 "constant with only a faint barely visible pulse, no "
                 "overexposure, no white flash, the hand and all fingers "
                 "completely frozen and motionless, static open hand"),
        "fps": 6,
    },
    "defense_001": {
        "anim": ("a faint light glint slowly passing across the bronze round "
                 "shield surface, very subtle metallic shimmer on the studs, "
                 "the shield shape stays perfectly static"),
        "fps": 6,
    },
    "rogue_strike": {
        "anim": ("the hooded rogue's red scarf tail fluttering very "
                 "slightly, barely perceptible breathing, the dagger hood "
                 "and pose stay perfectly static"),
        "fps": 6,
    },
    "rogue_defend": {
        # v2: a v1 animou a AÇÃO da pose de esquiva (ladino dançando).
        # Arte em pose dinâmica → congelar o corpo explicitamente.
        "anim": ("the figure completely frozen mid-dodge like a statue, no "
                 "limb or body movement whatsoever, only the red cape hem "
                 "and hood tip swaying very slightly in the wind, barely "
                 "perceptible"),
        "fps": 6,
    },
}


def token():
    """Bearer do PixelLab: ~/.claude.json (mcpServers.pixellab) — não versionar."""
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
    raise SystemExit("token PixelLab não encontrado (~/.claude.json ou $PIXELLAB_TOKEN)")


TOKEN = token()


def rpc(method, params, timeout=120):
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


def load_jobs():
    if os.path.exists(JOBS_FILE):
        with open(JOBS_FILE) as f:
            return json.load(f)
    return {}


def save_jobs(jobs):
    os.makedirs(os.path.dirname(JOBS_FILE), exist_ok=True)
    with open(JOBS_FILE, "w") as f:
        json.dump(jobs, f, indent=2)


def queue():
    jobs = load_jobs()
    queued = 0
    for icon, spec in ANIMS.items():
        if icon in jobs and jobs[icon].get("group"):
            continue
        if os.path.isdir(os.path.join(OUT_ROOT, icon)):
            continue
        try:
            args = {
                "object_id": spec.get("object_id") or HOST_OBJECT,
                "animation_description": spec["anim"] + SUFFIX,
                "display_name": icon + "_idle",
                "mode": "v3",
                "frame_count": 8,
            }
            if not spec.get("object_id"):
                # Ícone sem objeto próprio: o PNG do ícone vira o start frame
                # (frame 0 idêntico ao estático) e o host só hospeda o grupo.
                icon_png = os.path.join(ROOT, "assets/sprites/icons",
                                        icon + ".png")
                with open(icon_png, "rb") as f:
                    args["custom_start_frame_base64"] = \
                        base64.b64encode(f.read()).decode()
            result = rpc("tools/call", {
                "name": "animate_object",
                "arguments": args,
            })
            text = tool_text(result)
            m = re.search(r"group:\s*([0-9a-f-]{36})", text)
            if m:
                jobs[icon] = {"object_id": args["object_id"], "group": m.group(1)}
                queued += 1
                print(f"[queue] {icon} -> group {m.group(1)}")
            else:
                print(f"[queue] {icon}: sem group — {text[:120]}")
        except Exception as e:
            print(f"[queue] {icon}: FALHOU {e}")
        save_jobs(jobs)
        time.sleep(1.5)
    print(f"[queue] {queued} novos jobs")


def fetch(url):
    # Bearer SÓ pra api.pixellab.ai — o bucket backblaze é público, MAS
    # bloqueia o User-Agent default do urllib (403) e rejeita Authorization
    # que não entende. curl funciona; urllib precisa de UA "normal".
    headers = {"User-Agent": "curl/8.4.0"}
    if "api.pixellab.ai" in url:
        headers["Authorization"] = f"Bearer {TOKEN}"
    req = urllib.request.Request(url, headers=headers)
    return urllib.request.urlopen(req, timeout=120).read()


def poll():
    jobs = load_jobs()
    pending = 0
    for icon, job in jobs.items():
        out_dir = os.path.join(OUT_ROOT, icon)
        has_frames = os.path.isdir(out_dir) and any(
            re.match(r"frame_\d+\.png$", f) for f in os.listdir(out_dir))
        if has_frames or not job.get("group"):
            continue
        try:
            result = rpc("tools/call", {
                "name": "get_object",
                "arguments": {"object_id": job["object_id"]},
            })
            text = tool_text(result)
            # Bloco da NOSSA animação: [group: <uuid>] ... unknown: <url>/{i}.png (i=0..N)
            blk = re.search(
                r"\[group: " + re.escape(job["group"]) + r"\]"
                r".*?unknown:\s*(\S+)/\{i\}\.png\s+\(i=0\.\.(\d+)\)",
                text, re.S)
            if not blk:
                print(f"[poll] {icon}: aguardando (group {job['group'][:8]}…)")
                pending += 1
                continue
            base, last = blk.group(1), int(blk.group(2))
            os.makedirs(out_dir, exist_ok=True)
            for i in range(last + 1):
                png = fetch(f"{base}/{i}.png")
                with open(os.path.join(out_dir, f"frame_{i:03d}.png"), "wb") as f:
                    f.write(png)
            fps = ANIMS.get(icon, {}).get("fps", 8)
            with open(os.path.join(out_dir, "meta.lua"), "w") as f:
                f.write(f"return {{ fps = {fps} }}\n")
            print(f"[poll] {icon}: {last + 1} frames + meta.lua (fps={fps})")
        except Exception as e:
            print(f"[poll] {icon}: erro {e}")
            pending += 1
    print(f"[poll] pendentes: {pending}")


def check():
    """Animação viva = frames com conteúdo distinto (v3 às vezes anima morto)."""
    bad = 0
    for icon in sorted(os.listdir(OUT_ROOT)) if os.path.isdir(OUT_ROOT) else []:
        d = os.path.join(OUT_ROOT, icon)
        if not os.path.isdir(d):
            continue
        hashes = set()
        n = 0
        for f in sorted(os.listdir(d)):
            if re.match(r"frame_\d+\.png$", f):
                with open(os.path.join(d, f), "rb") as fh:
                    hashes.add(hashlib.md5(fh.read()).hexdigest())
                n += 1
        distinct = len(hashes)
        status = "OK" if distinct >= max(2, n // 2) else "MORTA?"
        if status != "OK":
            bad += 1
        print(f"[check] {icon}: {n} frames, {distinct} distintos — {status}")
    if bad:
        print(f"[check] {bad} animação(ões) suspeitas — regerar com descrição "
              "mais explícita de movimento (replace_existing=true)")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "queue"
    if cmd == "queue":
        queue()
    elif cmd == "poll":
        poll()
    elif cmd == "check":
        check()
    else:
        print(__doc__)
