#!/usr/bin/env python3
"""
tools/pixellab_animate_card_icons.py — anima ícones 64×64 de cartas raras/
lendárias via PixelLab (animate_object v3) e instala os frames no contrato do
IconFramesLoader:

    assets/sprites/icons_anim/<icon_name>/frame_NNN.png
    assets/sprites/icons_anim/<icon_name>/meta.lua      (fps)

Uso:
  python3 tools/pixellab_animate_card_icons.py run     # FÁBRICA serial (1 por
                                                       # vez, submete+espera+
                                                       # baixa; usar em bg)
  python3 tools/pixellab_animate_card_icons.py queue   # só enfileira (legado)
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
    # rogue_defend: NÃO ANIMAR (decisão Jul/2026). A arte é uma pose de
    # esquiva em pleno movimento — o v3 sempre anima o gesto inteiro, mesmo
    # com "frozen like a statue" (2 tentativas reprovadas: ladino dançando).
    # Arte em ação = deixar estática; se quiser animar um dia, regerar a
    # ARTE numa pose neutra primeiro.

    # ===== BLOCO 1: lendárias (fps 9, vivas) + jokers raros (fps 8) =====
    "joker_abyss": {
        # face cósmica ornamentada. v2: v1 morfava o rosto (boca abria,
        # cores mudavam). Tática ídolo pintado: rosto intocável, só gemas.
        "anim": ("a still portrait of an ornate cosmic idol mask, the face "
                 "completely motionless like a painted statue, not a single "
                 "pixel of the face mouth or skin changes, the only "
                 "movement is the small gems on the headdress glinting one "
                 "after another with tiny sparkles"),
        "fps": 9,
    },
    "joker_shield": {
        # elmo de aço (objeto)
        "anim": ("a warm ember glow pulsing slowly inside the dark eye slit "
                 "of the steel helmet, a faint light glint passing across "
                 "the polished steel dome, the helmet completely static"),
        "fps": 9,
    },
    "joker_vampire": {
        # busto de lorde vampiro. v3 (última tentativa — depois vira
        # estática): v1 e v2 mexiam a BOCA (presas à mostra = gesto
        # implícito). Tática "retrato de cera": NADA no rosto muda,
        # nem 1 pixel; só a intensidade do brilho dos olhos.
        "anim": ("a still portrait of a vampire lord, his face frozen "
                 "completely motionless like a wax figure, not a single "
                 "pixel of the mouth fangs or expression changes, the only "
                 "movement is the red glow of his eyes slowly intensifying "
                 "and fading, everything else a static painting"),
        "fps": 9,
    },
    "joker_jester": {
        # rosto de bobo com chapéu de guizos
        "anim": ("the jester hat points with bells swaying very slightly, "
                 "the eyes glinting with mischief, the grinning face "
                 "completely static"),
        "fps": 8,
    },
    "jester_hat": {
        # chapéu de três pontas (objeto)
        "anim": ("the three floppy hat points swaying gently as if in a "
                 "faint breeze, the golden bells glinting, the hat base "
                 "completely static"),
        "fps": 8,
    },
    "warrior_berserk": {
        # homem-fera com dois machados, em pé (pose aberta — travar corpo)
        "anim": ("the beast warrior breathing heavily, chest heaving and "
                 "shoulders rising, fur bristling slightly, both axes arms "
                 "and legs completely frozen in place, no limb movement"),
        "fps": 8,
    },
    "warrior_brutality": {
        # brutamontes armado com martelo, em pé
        "anim": ("the armored brute breathing slowly and heavily, chest and "
                 "shoulders rising and falling, the hammer arms and legs "
                 "completely frozen, no limb movement"),
        "fps": 8,
    },
    "warrior_dark_embrace": {
        # vulto encapuzado de braços abertos, robes ao vento
        "anim": ("the dark hooded wraith's tattered robes drifting and "
                 "billowing slowly like smoke, faint shadow wisps rising "
                 "from the cloth, the hood and open arms pose completely "
                 "static"),
        "fps": 8,
    },
    "skull_crowned": {
        # caveira dourada coroada (objeto) — warrior_demon_form
        "anim": ("a dim red glow pulsing slowly inside the skull's empty "
                 "eye sockets, the golden crown jewels glinting one at a "
                 "time, the skull and crown completely static"),
        "fps": 8,
    },
    "warrior_juggernaut": {
        # colosso blindado em pé
        "anim": ("the armored colossus breathing slowly, massive shoulders "
                 "rising and falling slightly, a faint light glint passing "
                 "across the bronze armor plates, arms and legs completely "
                 "frozen, no limb movement"),
        "fps": 8,
    },

    # ===== BLOCO 2: raras — jokers/objetos (fps 8) =====
    "warrior_bastion": {
        # estandarte/tapeçaria ornamentada vertical
        "object_id": "f024bc9b-8492-4347-8306-4d9145257741",
        "anim": ("the tall ornate banner tapestry cloth waving gently in a "
                 "slow breeze, lower edge rippling softly, the top mount "
                 "and emblem completely static"),
        "fps": 8,
    },
    "heart": {
        # coração anatômico atravessado por espada — warrior_second_heart
        "anim": ("the anatomical heart beating slowly, contracting and "
                 "expanding subtly in a steady pulse, the sword piercing "
                 "it completely static"),
        "fps": 8,
    },
    "mage_creative_ai": {
        # cabeça de androide com cérebro dourado exposto
        "anim": ("tiny golden circuit lights on the exposed brain glinting "
                 "and pulsing one after another, a faint glow breathing in "
                 "the eye, the head profile completely static"),
        "fps": 8,
    },
    "mage_echo_form": {
        # 4 vultos idênticos de robe vermelho (ecos)
        "anim": ("the echo copies behind shimmering and fading slightly in "
                 "and out like ghostly afterimages, the front figure "
                 "completely static and solid"),
        "fps": 8,
    },
    "mage_electrodynamics": {
        # arcos elétricos pendentes (assunto naturalmente animado)
        "anim": ("the hanging electric arcs crackling and flickering, tiny "
                 "sparks jumping between the tendrils, the overall shape "
                 "and silhouette preserved"),
        "fps": 8,
    },
    "mage_machine_learning": {
        # cérebro sobre haste
        "anim": ("a faint warm glow pulsing slowly across the brain folds, "
                 "tiny synapse lights glinting briefly, the brain and stalk "
                 "completely static"),
        "fps": 8,
    },
    "rune": {
        # tablete de pedra com glifo "P" — mage_rune_of_power
        "anim": ("the carved golden rune glyph glowing brighter and dimmer "
                 "in a slow magical pulse, faint gold light spilling from "
                 "the grooves, the stone tablet completely static"),
        "fps": 8,
    },
    "gem": {
        # gema vermelha lapidada — mage_sages_gem
        "anim": ("the ruby gemstone facets glinting one after another as "
                 "light plays across them, a tiny white sparkle appearing "
                 "briefly, the gem completely static"),
        "fps": 8,
    },
    "rogue_a_thousand_cuts": {
        # duas espadas cruzadas em chamas
        "anim": ("the flames around the crossed swords flickering and "
                 "dancing gently, small embers rising, both blades "
                 "completely static"),
        "fps": 8,
    },
    "rogue_after_image": {
        # vulto de capa em pé
        "anim": ("the assassin's dark cape swaying gently, a faint ghostly "
                 "afterimage shimmer flickering at his silhouette edge, "
                 "body and pose completely frozen, no limb movement"),
        "fps": 8,
    },

    # ===== BLOCO 3: raras — attacks/effects (fps 8) =====
    "mage_arcane_torrent": {
        # torrente vertical de fogo/energia
        "object_id": "3e8012db-e803-4c95-839d-63c1ff4f1aba",
        "anim": ("the vertical torrent of arcane fire swirling and rising "
                 "continuously, flame tongues flickering at the edges, the "
                 "base crater completely static"),
        "fps": 8,
    },
    "mage_buffer": {
        # chama sobre pedestal escuro
        "anim": ("the flame on the dark pedestal flickering and dancing "
                 "gently, its light glow pulsing on the pedestal top, the "
                 "pedestal completely static"),
        "fps": 8,
    },
    "mage_fission": {
        # orbe solar explodindo. v2: v1 apagava o orbe até virar anel
        # escuro (loop pipocava). Núcleo SEMPRE aceso, brilho ~constante.
        "anim": ("the sun orb core stays fully bright and solid the whole "
                 "time, only the small orbiting fragments trembling "
                 "slightly and tiny sparks glinting around them, no dimming "
                 "no fading, brightness constant, silhouette unchanged"),
        "fps": 8,
    },
    "mage_meteor_strike": {
        # meteoro caindo. v2: v1 virou cogumelo de explosão e emagreceu
        # (animou o IMPACTO — mesma classe do erro rogue_defend). Forma
        # geral intocável, só as chamas da cauda tremulam.
        "anim": ("the meteor column keeps its exact shape and size the "
                 "whole time, only the flame edges of the trail flickering "
                 "gently and a few small embers drifting off, no explosion "
                 "no impact, silhouette completely unchanged"),
        "fps": 8,
    },
    "mage_rainbow": {
        # feixes verticais vermelho/azul subindo de um anel
        "anim": ("the vertical light beams shimmering and flowing slowly "
                 "upward, their brightness waving softly, the ring base "
                 "completely static"),
        "fps": 8,
    },
    "mage_twin_bolts": {
        # dois raios/chamas paralelos descendo
        "object_id": "585aebc0-ec09-4865-ab6f-5bd0a7b2dbc7",
        "anim": ("the two parallel lightning fire bolts crackling and "
                 "flickering as they streak down, tiny sparks breaking off, "
                 "the overall shape preserved"),
        "fps": 8,
    },
    "rogue_bullet_time": {
        # bala/projétil (objeto)
        "anim": ("a thin light glint sliding slowly along the bullet "
                 "casing, a faint spark at the tip, the bullet completely "
                 "static"),
        "fps": 8,
    },
    "rogue_corpse_explosion": {
        # corpo caído com miasma verde
        "anim": ("the sickly green miasma gas bubbles rising slowly from "
                 "the corpse and popping, the corpse itself completely "
                 "static"),
        "fps": 8,
    },
    "skull": {
        # caveira grande — rogue_death_mark
        "anim": ("a dim ghostly glow pulsing slowly inside the skull's "
                 "empty eye sockets, a faint shadow flicker under the jaw, "
                 "the skull completely static"),
        "fps": 8,
    },
    "mask": {
        # máscara de carnaval com fitas — rogue_doppelganger
        "anim": ("the ribbons hanging from the carnival mask swaying "
                 "gently, a sly glint passing across the eye holes, the "
                 "mask itself completely static"),
        "fps": 8,
    },
    "rogue_envenom": {
        # adaga curva com veneno
        "anim": ("thick green venom slowly dripping from the curved blade "
                 "edge, a faint toxic sheen shifting on the metal, the "
                 "dagger completely static"),
        "fps": 8,
    },
    "rogue_executioner": {
        # carrasco encapuzado com machado e cepo
        "object_id": "a88da962-3897-4337-86f6-08ec5283ef14",
        "anim": ("the hooded executioner breathing slowly, shoulders "
                 "rising slightly, a cold glint passing along the axe "
                 "blade, arms legs and the chopping block completely "
                 "frozen"),
        "fps": 8,
    },

    # ===== BLOCO 4: raras finais (fps 8) =====
    "star": {
        # medalhão/rosa-dos-ventos com estrela — rogue_shooting_star
        "anim": ("the star core glinting brightly, a small white sparkle "
                 "traveling slowly around the outer ring, the medallion "
                 "completely static"),
        "fps": 8,
    },
    "rogue_storm_of_steel": {
        # coração/massa de lâminas de aço com bordas em chamas
        "anim": ("the small flames at the steel edges flickering gently, "
                 "cold glints passing across the blade surfaces one at a "
                 "time, the steel mass completely static"),
        "fps": 8,
    },
    "warrior_bloodletting": {
        # figura encapuzada com adaga (busto calmo)
        "anim": ("the hooded figure breathing very slowly, a single drop "
                 "of blood slowly forming and falling from the dagger tip, "
                 "arms hood and pose completely frozen, no talking"),
        "fps": 8,
    },
    "warrior_colossus_blow": {
        # martelo de guerra colossal (objeto)
        "object_id": "90f36621-4a2b-4c9c-9df3-c578eac1faeb",
        "anim": ("a heavy light glint sliding slowly across the massive "
                 "hammer head, tiny dust particles drifting off the "
                 "handle, the hammer completely static"),
        "fps": 8,
    },
    "warrior_feed": {
        # vampiro segurando vítima (pose de ação contida — tentativa única;
        # se dançar, vira estática como rogue_defend)
        "anim": ("both figures completely frozen like a dark painting, "
                 "only the vampire's red cloak edge swaying very slightly "
                 "and a faint crimson glow pulsing around them, no limb or "
                 "head movement whatsoever, no talking"),
        "fps": 8,
    },
    "warrior_immolate": {
        # guerreiro em chamas com espada, em pé
        "anim": ("the flames engulfing the warrior flickering and dancing, "
                 "small embers rising from his shoulders, his body sword "
                 "and pose completely frozen, no limb movement"),
        "fps": 8,
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


def _has_frames(icon):
    d = os.path.join(OUT_ROOT, icon)
    return os.path.isdir(d) and any(
        re.match(r"frame_\d+\.png$", f) for f in os.listdir(d))


def _submit(icon, spec):
    """Submete UMA animação. Retorna (object_id, group) ou (None, None)."""
    args = {
        "object_id": spec.get("object_id") or HOST_OBJECT,
        "animation_description": spec["anim"] + SUFFIX,
        "display_name": icon + "_idle",
        "mode": "v3",
        "frame_count": 8,
        "replace_existing": True,
    }
    if not spec.get("object_id"):
        icon_png = os.path.join(ROOT, "assets/sprites/icons", icon + ".png")
        with open(icon_png, "rb") as f:
            args["custom_start_frame_base64"] = base64.b64encode(f.read()).decode()
    text = tool_text(rpc("tools/call", {"name": "animate_object",
                                        "arguments": args}))
    m = re.search(r"group:\s*([0-9a-f-]{36})", text)
    if not m:
        print(f"[run] {icon}: SEM GROUP — {text[:150]}", flush=True)
        return None, None
    return args["object_id"], m.group(1)


def _try_download(icon, object_id, group):
    """Uma checada: se o group está completo no get_object, baixa. True = ok."""
    try:
        text = tool_text(rpc("tools/call", {
            "name": "get_object",
            "arguments": {"object_id": object_id}}))
    except Exception as e:
        print(f"[run] {icon}: erro no get_object ({e})", flush=True)
        return False
    blk = re.search(
        r"\[group: " + re.escape(group) +
        r"\].*?unknown:\s*(\S+)/\{i\}\.png\s+\(i=0\.\.(\d+)\)",
        text, re.S)
    if not blk:
        return False
    base, last = blk.group(1), int(blk.group(2))
    out_dir = os.path.join(OUT_ROOT, icon)
    os.makedirs(out_dir, exist_ok=True)
    for i in range(last + 1):
        with open(os.path.join(out_dir, f"frame_{i:03d}.png"), "wb") as f:
            f.write(fetch(f"{base}/{i}.png"))
    fps = ANIMS.get(icon, {}).get("fps", 8)
    with open(os.path.join(out_dir, "meta.lua"), "w") as f:
        f.write(f"return {{ fps = {fps} }}\n")
    print(f"[run] {icon}: {last + 1} frames + meta.lua (fps={fps})", flush=True)
    return True


def _wait_download(icon, object_id, group, timeout=480):
    """Espera o group concluir no get_object e baixa os frames. True = ok."""
    deadline = time.time() + timeout
    while time.time() < deadline:
        time.sleep(25)
        if _try_download(icon, object_id, group):
            return True
    print(f"[run] {icon}: TIMEOUT ({timeout}s) — fica pro próximo run",
          flush=True)
    return False


def run():
    """FÁBRICA SERIAL: processa todo ANIMS sem frames, UM por vez (a API
    descarta jobs de interpolação concorrentes — memory/card_icon_animation).
    ~3-6 min por carta; rodar em background e validar por blocos."""
    jobs = load_jobs()
    todo = [(i, s) for i, s in ANIMS.items() if not _has_frames(i)]
    print(f"[run] fila: {len(todo)} animações", flush=True)
    ok, fail = 0, 0
    for n, (icon, spec) in enumerate(todo, 1):
        print(f"[run] ({n}/{len(todo)}) {icon}…", flush=True)
        # Job de run anterior pode ter concluído depois do timeout — checar
        # antes de gastar outra geração.
        prev = jobs.get(icon)
        if prev and prev.get("group") and \
                _try_download(icon, prev["object_id"], prev["group"]):
            ok += 1
            continue
        try:
            object_id, group = _submit(icon, spec)
        except Exception as e:
            print(f"[run] {icon}: FALHOU submit ({e})", flush=True)
            fail += 1
            continue
        if not group:
            fail += 1
            continue
        jobs[icon] = {"object_id": object_id, "group": group}
        save_jobs(jobs)
        if _wait_download(icon, object_id, group):
            ok += 1
        else:
            fail += 1
    print(f"[run] FIM: {ok} ok, {fail} falhas", flush=True)


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
    elif cmd == "run":
        run()
    else:
        print(__doc__)
