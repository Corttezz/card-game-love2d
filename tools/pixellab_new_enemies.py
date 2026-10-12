#!/usr/bin/env python3
"""
tools/pixellab_new_enemies.py — gera inimigos NOVOS (sprite base + idle) via
PixelLab, no estilo do roster existente. Hurt/death saem depois pela fábrica
tools/pixellab_enemy_anims.py (mesma doutrina: frame 0 = idle real).

Fluxo por inimigo (serial — a conta dropa submits concorrentes):
  base   create_image_pro com style_image = sprite do roster do MESMO bioma
         → 4 candidatos em tools/preview_out/new_enemies/<id>/cand_N.png
         (OLHAR e escolher; recusar "vetor liso")
  pick   python3 tools/pixellab_new_enemies.py pick <id> <N>
         → recorta/encaixa no canvas e grava enemies/<id>/south.png
  idle   idle ASSADO por deslocamento a partir do south.png (12 quadros,
         loop fechado; ver idle_cfg) — zero geração, zero deriva

Uso:
  python3 tools/pixellab_new_enemies.py base <id> [seed]
  python3 tools/pixellab_new_enemies.py pick <id> <N>
  python3 tools/pixellab_new_enemies.py idle <id...>
  python3 tools/pixellab_new_enemies.py sheet <id...>
Contagem de gerações gasta em tools/preview_out/new_enemies/ledger.json.
"""
import base64
import json
import os
import re
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixellab_enemy_anims as F  # rpc/tool_text/fetch/token compartilhados

ROOT = F.ROOT
ENEMIES_DIR = F.ENEMIES_DIR
OUT = os.path.join(ROOT, "tools/preview_out/new_enemies")
LEDGER = os.path.join(OUT, "ledger.json")

STYLE = ("dark fantasy grimoire pixel art, inked engraving style, earthy "
         "desaturated palette, crisp 1px pure black outline, detailed "
         "shading with clear darks and mid-tones, dramatic silhouette, "
         "moody upper-left lighting, hand-placed pixels with visible "
         "dithering and hard edges, NO smooth vector gradients, NO "
         "anti-aliased blur, Slay the Spire card art aesthetic. "
         "Front view, facing the viewer straight on, full body visible, "
         "centered, feet/base touching the bottom of the canvas, "
         "transparent background, single creature, no text, no ground.")

# id → (canvas, sprite de estilo do roster, descrição)
SPECS = {
    # === ATO 1 — CAMPOS ====================================================
    "plague_rats": (96, "cursed_scarecrow",
        "a writhing heap of five plague rats piled on each other, mangy "
        "brown-grey fur, bald pink tails, red beady eyes, sores and "
        "yellow pustules, bared yellow teeth, low wide mound shape"),
    "hollow_farmer": (96, "cursed_scarecrow",
        "a corrupted hollow peasant farmer, gaunt grey skin, empty dark "
        "eye sockets with faint ember glow, tattered straw hat, patched "
        "brown tunic and apron, gripping a rusty pitchfork upright in "
        "both hands, hunched menacing stance"),
    "blight_bull": (112, "harvest_reaper",
        "a huge rotting blighted bull standing on four hooves facing the "
        "viewer, massive shoulders, long cracked horns, patches of rotten "
        "flesh and exposed ribs, wheat stalks tangled in its matted dark "
        "brown hide, glowing sickly orange eyes, steaming nostrils"),
    "wicker_effigy": (128, "harvest_reaper",
        "a towering wicker man effigy giant woven from dry branches and "
        "straw, hollow ribcage cage chest with a burning ember fire "
        "inside, antlered skull of a stag as its head with glowing eyes, "
        "long woven arms, small flames licking its shoulders"),
    # === ATO 2 — PLANALTOS =================================================
    "storm_harpy": (96, "moon_gargoyle",
        "a monstrous harpy, withered skeletal grey body fully covered in "
        "ragged dark slate feathers from neck to legs, gaunt vulture-like "
        "face with a hooked beak-like jaw, wild white hair, huge feather "
        "wings spread wide, long hooked claws held forward ready to "
        "slash, scaly bird legs with black talons, crouched predator "
        "stance standing on its talons"),
    "ram_cultist": (96, "moon_gargoyle",
        "a robed highland cultist wearing a ram skull mask with curled "
        "horns, dark grey wool robes with faded purple sash, swinging a "
        "smoking bronze censer on a chain in one hand, bone charms"),
    "spectral_knight": (112, "rune_golem",
        "a ghostly spectral knight in ancient pale grey-violet plate "
        "armor, empty helm with two cold violet eye lights, holding a "
        "huge tall tower shield in front with a faded crest, longsword "
        "in the other hand, wisps of ghostly mist at the joints"),
    "storm_griffin": (128, "moon_gargoyle",
        "a fierce storm griffin, eagle head with hooked beak, lion body "
        "standing on four legs facing the viewer, huge slate-grey wings "
        "raised, tawny and grey feathers, small blue lightning sparks "
        "crackling along the wing feathers, glowing pale eyes"),
    # === ATO 3 — ABISMO ====================================================
    "hellhound": (96, "ember_imp",
        "a two-headed hellhound standing on four legs facing the viewer, "
        "charred black hide with glowing orange lava cracks, both heads "
        "snarling with fangs, spiked spine, ember eyes, smoke rising"),
    "abyss_acolyte": (96, "obsidian_sentinel",
        "a hooded abyss acolyte in charred black and crimson robes, face "
        "hidden in shadow with two glowing orange eyes, holding an open "
        "burning grimoire in one hand, chains wrapped around its arms"),
    "pit_brute": (112, "obsidian_sentinel",
        "a hulking horned pit demon brute, massive muscular charred red-"
        "black body, iron collar with broken chain, dragging a huge iron "
        "sledgehammer, glowing lava seams on the skin, curved horns"),
    # NÃO é "beholder" (olho central + pedúnculos + boca é marca da WotC —
    # a 1ª leva saiu exatamente isso e foi recusada): massa de carne
    # pendurada feito água-viva, VÁRIOS olhos embutidos, sem pedúnculo/boca.
    "abyss_watcher": (128, "abyss_tyrant",
        "a floating abyssal horror shaped like a huge dark crimson "
        "jellyfish: a ragged bell of flesh crowned with cracked black bone "
        "plates and small horns, seven unblinking orange eyes of different "
        "sizes embedded in a vertical cluster on its front, a curtain of "
        "long black and crimson tentacles hanging down beneath it, no "
        "mouth, no eye stalks, faint orange glow inside the flesh"),
    # === ATO 4 — GELO ======================================================
    "frost_wolf": (96, "frost_wight",
        "a gaunt frost wolf standing on four legs facing the viewer, "
        "shaggy pale blue-white fur with icicles hanging from its belly "
        "and jaw, bared fangs, glowing icy blue eyes, frosty breath"),
    "rime_shaman": (96, "frost_wight",
        "a hunched goblin frost shaman wrapped in white fur pelts, blue-"
        "grey skin, bone necklace, holding a tall carved totem staff "
        "topped with a glowing pale blue ice crystal, feathers and runes"),
    "frost_troll": (112, "glacier_knight",
        "a massive hulking snow troll, shaggy white fur over pale blue "
        "skin, tusks, long arms with huge fists reaching the ground, ice "
        "shards growing from its shoulders and back, small glowing eyes"),
    "ice_wyrm": (128, "winter_monarch",
        "a coiled ice wyrm serpent dragon rearing up facing the viewer, "
        "pale blue crystalline scales, jagged ice spikes along the spine, "
        "small frozen wings, open jaws with frost breath, glowing cyan "
        "eyes, thick coiled tail resting on the ground"),
    # === ATO 5 — PÂNTANO ===================================================
    "plague_toad": (96, "bog_ghoul",
        "a giant bloated plague toad squatting facing the viewer, warty "
        "olive and mustard skin, swollen throat sac, glowing yellow-green "
        "poison pustules on its back, drooling toxic slime, wide mouth"),
    "leech_horror": (96, "bog_ghoul",
        "a horror made of a mass of writhing giant leeches fused into a "
        "rough hunched humanoid shape, glossy dark brown-red segmented "
        "bodies, round toothed sucker mouths, dripping swamp mud"),
    "croc_warrior": (112, "mire_hag",
        "a crocodile-man warrior standing upright, dark green scaly hide, "
        "long toothy snout, holding a bone-tipped spear and a round "
        "shield made of a turtle shell, leather belt with skull trinkets"),
    "spore_mother": (128, "rot_colossus",
        "a huge fungal matriarch: a hunched giant mushroom creature with "
        "a wide spotted rotten-red cap, thick root-like legs, gills "
        "dripping glowing green spores, small mushrooms growing on its "
        "body, mossy arms, glowing eyes under the cap"),
    # === ATO 6 — CREPÚSCULO ================================================
    "dusk_bat": (96, "blood_duke",
        "a giant vampire bat hovering facing the viewer, wings spread "
        "wide, dark purple-black leathery wings with red veins, big "
        "pointed ears, glowing red eyes, fangs bared, small clawed feet"),
    "grave_thrall": (96, "dusk_shade",
        "a skeletal grave thrall in rusted dark iron armor, holding a "
        "large battered rectangular tower shield in front of it, skull "
        "with faint violet eye glow, tattered purple tabard"),
    "dullahan": (112, "blood_duke",
        "a headless dark knight dullahan in black and crimson plate "
        "armor, carrying its own glowing-eyed helmeted head under one "
        "arm, wielding a long curved blade, tattered dark red cape, "
        "violet ghost flame rising from the empty neck"),
    "fallen_angel": (128, "eclipse_queen",
        "a fallen angel standing tall, large tattered black feathered "
        "wings, pale grey skin, cracked broken halo of dim gold floating "
        "above its head, dark violet robes and blackened armor, holding "
        "a long dark sword pointed down, glowing pale eyes"),
}


def ledger_add(eid, kind, gens):
    os.makedirs(OUT, exist_ok=True)
    led = json.load(open(LEDGER)) if os.path.exists(LEDGER) else {"jobs": []}
    led["jobs"].append({"id": eid, "kind": kind, "gens": gens,
                        "t": time.strftime("%Y-%m-%d %H:%M")})
    json.dump(led, open(LEDGER, "w"), indent=2)


def b64(path):
    with open(path, "rb") as f:
        return base64.b64encode(f.read()).decode()


def call(name, args):
    return F.tool_text(F.rpc("tools/call", {"name": name, "arguments": args},
                             timeout=300))


def job_id_of(text):
    m = re.search(r"([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-"
                  r"[0-9a-f]{12})", text)
    return m.group(1) if m else None


def wait_job(job_id, max_s=900):
    t0 = time.time()
    while time.time() - t0 < max_s:
        time.sleep(10)
        try:
            text = call("get_image", {"job_id": job_id})
        except Exception as e:
            print(f"  poll erro {e}", flush=True)
            continue
        low = text.lower()
        if "status: failed" in low or "status: error" in low:
            print("  FALHOU:", text[:300], flush=True)
            return None
        if "status: completed" in low:
            return text
    print("  TIMEOUT", flush=True)
    return None


def download_all(text, dest_fmt):
    mN = re.search(r"(?:frames|images|count):\s*(\d+)", text)
    mURL = re.search(r"(https?://\S+/download)\?index=\d+", text)
    if not mURL:
        m1 = re.search(r"download:\s*(https?://\S+/download)\s", text + " ")
        if m1:  # quadro único: URL sem ?index
            open(dest_fmt.format(0), "wb").write(F.fetch(m1.group(1)))
            return 1
        urls = re.findall(r"https?://\S+\.png", text)
        for i, u in enumerate(urls):
            open(dest_fmt.format(i), "wb").write(F.fetch(u))
        return len(urls)
    n = int(mN.group(1)) if mN else 1
    base = mURL.group(1)
    for i in range(n):
        open(dest_fmt.format(i), "wb").write(F.fetch(f"{base}?index={i}"))
    return n


def cmd_base(eid, seed=None):
    size, style_id, desc = SPECS[eid]
    style_png = os.path.join(ENEMIES_DIR, style_id,
                             "animations/idle/south/0.png")
    args = {"description": f"{desc}. {STYLE}", "width": size,
            "height": size, "no_background": True,
            "style_image_base64": b64(style_png),
            "style_copy": ["color_palette", "outline", "detail", "shading"]}
    if seed is not None:
        args["seed"] = int(seed)
    text = call("create_image_pro", args)
    jid = job_id_of(text)
    print(f"[base] {eid} job {jid}", flush=True)
    if not jid:
        print(text[:400])
        return
    done = wait_job(jid)
    if not done:
        return
    gm = re.search(r"generations?[^\d]{0,20}(\d+)", done.lower())
    ledger_add(eid, "base", int(gm.group(1)) if gm else None)
    d = os.path.join(OUT, eid)
    os.makedirs(d, exist_ok=True)
    n = download_all(done, os.path.join(d, "cand_{}.png"))
    print(f"[base] {eid}: {n} candidatos em {d}", flush=True)
    open(os.path.join(d, "base_job.txt"), "w").write(done)
    contact(eid)


def contact(eid):
    from PIL import Image
    d = os.path.join(OUT, eid)
    fs = sorted(f for f in os.listdir(d) if f.startswith("cand_"))
    ims = [Image.open(os.path.join(d, f)).convert("RGBA") for f in fs]
    S = 3
    W = sum(im.width for im in ims) * S + 8 * len(ims)
    H = max(im.height for im in ims) * S
    sh = Image.new("RGBA", (W, H), (70, 78, 58, 255))
    x = 0
    for im in ims:
        big = im.resize((im.width * S, im.height * S), Image.NEAREST)
        sh.paste(big, (x, 0), big)
        x += im.width * S + 8
    sh.save(os.path.join(d, "contact.png"))
    print(os.path.join(d, "contact.png"))


def cmd_pick(eid, n):
    """Encaixa o candidato N num canvas com 3px de folga em cima/lados e o
    pé encostado no fundo (folga 2px), igual aos sprites do roster."""
    from PIL import Image
    src = Image.open(os.path.join(OUT, eid, f"cand_{n}.png")).convert("RGBA")
    # limpa alpha fraco (franja de antialias) — pixel art é binária
    px = src.load()
    for y in range(src.height):
        for x in range(src.width):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255) if a >= 128 else (0, 0, 0, 0)
    bb = src.getbbox()
    crop = src.crop(bb)
    W = max(crop.width + 8, src.width)
    H = crop.height + 5
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    canvas.paste(crop, ((W - crop.width) // 2, H - crop.height - 2))
    d = os.path.join(ENEMIES_DIR, eid)
    os.makedirs(d, exist_ok=True)
    canvas.save(os.path.join(d, "south.png"))
    print(f"[pick] {eid} cand {n} -> south.png {canvas.size}")


# ---------------------------------------------------------------------------
# IDLE ASSADO (zero geração, zero deriva). O piloto com animate_image
# (hollow_farmer, Out/2026) derivou: a cabeça girava e o brilho dos olhos
# SUMIA do quadro 2 em diante — e o emissivo do LightEngine é ancorado no
# quadro 0. Mesmo motor do tools/bake_boss_idle.py (deslocamento a partir do
# quadro base), com um rig GENÉRICO tirado do bbox do conteúdo:
#   breathe — tudo acima dos pés sobe com rampa (0 no tornozelo, 1 no topo)
#   sway    — cabeça/topo balança de lado, atrasado (movimento secundário)
# Pés fixos (faixa de baixo excluída) nos apoiados — pé que patina lê como
# flutuando. EXTRA_MOTIONS soma movimentos próprios (asa que bate etc.),
# em coordenadas do canvas do south.png.
# ---------------------------------------------------------------------------
IDLE_FRAMES = 12
def _wings(lp, rp, lbox, rbox, body, angle=5.0, lag=0.1):
    """Par de asas girando no ombro (abre/fecha), corpo excluído."""
    import bake_boss_idle as B
    return [
        {"type": "rotate", "pivot": lp, "angle": -angle, "lag": lag,
         "regions": [B.box(*lbox, 6)], "exclude": [B.box(*body, 3)]},
        {"type": "rotate", "pivot": rp, "angle": angle, "lag": lag,
         "regions": [B.box(*rbox, 6)], "exclude": [B.box(*body, 3)]},
    ]


# coordenadas medidas no south.png de cada um (zoom com régua)
EXTRA_MOTIONS = {
    "storm_griffin": _wings((52, 46), (78, 46), (-10, -10, 50, 80),
                            (80, -10, 140, 80), (50, 30, 80, 101)),
    "storm_harpy": _wings((38, 28), (61, 28), (-10, -10, 38, 72),
                          (61, -10, 110, 72), (38, 18, 61, 81), angle=6.0),
    "dusk_bat": _wings((42, 30), (62, 30), (-10, -10, 42, 80),
                       (62, -10, 112, 80), (42, 15, 62, 72), angle=8.0,
                       lag=0.0),
    # asa esquerda só até y 78: abaixo dela passa a espada (madeira/aço
    # não balança com pena)
    "fallen_angel": _wings((54, 42), (80, 42), (-10, -10, 54, 78),
                           (80, -10, 145, 110), (54, 20, 80, 130),
                           angle=4.0, lag=0.15),
    # cortina de tentáculos ondula atrasada (balança mais na ponta)
    "abyss_watcher": [{"type": "shift", "dx": 2.5, "dy": 0, "lag": 0.3,
                       "regions": [("box", -10, 70, 140, 140, 6)],
                       "ramp": ("y", 70, 125)}],
}
FLOATING = {"abyss_watcher", "dusk_bat"}


def idle_cfg(eid):
    from PIL import Image
    im = Image.open(os.path.join(ENEMIES_DIR, eid, "south.png"))
    x0, y0, x1, y1 = im.convert("RGBA").getbbox()
    H = y1 - y0
    feet = y1 - (0.0 if eid in FLOATING else 0.14) * H
    top_band = y0 + 0.38 * H
    import bake_boss_idle as B
    motions = [
        {"type": "shift", "dx": 0, "dy": -2.2, "lag": 0.0,
         "regions": [B.box(x0 - 12, y0 - 12, x1 + 12, feet, 4)],
         "ramp": ("y", feet, y0 + 0.30 * H)},
        {"type": "shift", "dx": 1.2, "dy": 0, "lag": 0.25,
         "regions": [B.box(x0 - 12, y0 - 12, x1 + 12, top_band, 8)]},
    ]
    motions += EXTRA_MOTIONS.get(eid, [])
    return {"frames": IDLE_FRAMES, "motions": motions}


def cmd_idle(eid):
    import shutil
    import bake_boss_idle as B
    dest = os.path.join(ENEMIES_DIR, eid, "animations/idle/south")
    os.makedirs(dest, exist_ok=True)
    for f in os.listdir(dest):
        os.remove(os.path.join(dest, f))
    shutil.copy(os.path.join(ENEMIES_DIR, eid, "south.png"),
                os.path.join(dest, "0.png"))
    B.CONFIG[eid] = idle_cfg(eid)
    B.bake(eid)


def cmd_endframe(eid, desc):
    """Quadro FINAL da morte (cadáver) quando o animate_image se recusa a
    derrubar o bicho (plague_rats: duas tentativas terminando com a pilha
    de pé). Gera com o south.png como estilo, no MESMO canvas; o `endpick`
    encaixa com o pé na mesma linha e a fábrica de anims interpola até ele
    (campo `last_frame` do ENEMIES)."""
    south = os.path.join(ENEMIES_DIR, eid, "south.png")
    from PIL import Image
    w, h = Image.open(south).size
    W, H = (w + 3) // 4 * 4, (h + 3) // 4 * 4
    args = {"description": f"{desc}. {STYLE}", "width": max(W, 64),
            "height": max(H, 64), "no_background": True,
            "style_image_base64": b64(south)}
    text = call("create_image_pro", args)
    jid = job_id_of(text)
    print(f"[endframe] {eid} job {jid}", flush=True)
    done = wait_job(jid) if jid else None
    if not done:
        print(text[:300])
        return
    ledger_add(eid, "endframe", None)
    d = os.path.join(OUT, eid)
    os.makedirs(d, exist_ok=True)
    n = download_all(done, os.path.join(d, "end_cand_{}.png"))
    print(f"[endframe] {n} candidatos", flush=True)


def cmd_endpick(eid, n):
    """Encaixa end_cand_N no canvas do south.png, centrado, pé na mesma
    linha do idle. Grava enemies/<id>/death_end.png (fonte da fábrica; não é
    lido pelo jogo)."""
    from PIL import Image
    south = Image.open(os.path.join(ENEMIES_DIR, eid, "south.png"))
    sb = south.getbbox()
    src = Image.open(os.path.join(OUT, eid, f"end_cand_{n}.png")).convert("RGBA")
    px = src.load()
    for y in range(src.height):
        for x in range(src.width):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255) if a >= 128 else (0, 0, 0, 0)
    crop = src.crop(src.getbbox())
    if crop.width > south.width:
        k = south.width / crop.width
        crop = crop.resize((south.width, max(1, int(crop.height * k))),
                           Image.NEAREST)
    out = Image.new("RGBA", south.size, (0, 0, 0, 0))
    out.paste(crop, ((south.width - crop.width) // 2, sb[3] - crop.height))
    dst = os.path.join(OUT, eid, "death_end.png")
    out.save(dst)
    print(f"[endpick] {dst} {crop.size}")


def cmd_clean(eid, anim, minpx=8):
    """Apaga ilhas soltas (< minpx pixels conectados) dos quadros 1+ de um
    clip — o v3 deixa faísca/lasca flutuando no fim da morte (wicker_effigy:
    bolinha branca no ar no cadáver). Quadro 0 intocado (= idle)."""
    from PIL import Image
    d = os.path.join(ENEMIES_DIR, eid, "animations", anim, "south")
    fs = sorted((f for f in os.listdir(d) if f.endswith(".png")),
                key=lambda f: int(f.split(".")[0]))
    total = 0
    for f in fs[1:]:
        im = Image.open(os.path.join(d, f)).convert("RGBA")
        px = im.load()
        W, H = im.size
        seen = set()
        for y in range(H):
            for x in range(W):
                if px[x, y][3] == 0 or (x, y) in seen:
                    continue
                comp, st = [], [(x, y)]
                seen.add((x, y))
                while st:
                    cx, cy = st.pop()
                    comp.append((cx, cy))
                    for nx in (cx - 1, cx, cx + 1):
                        for ny in (cy - 1, cy, cy + 1):
                            if (0 <= nx < W and 0 <= ny < H
                                    and (nx, ny) not in seen
                                    and px[nx, ny][3] > 0):
                                seen.add((nx, ny))
                                st.append((nx, ny))
                if len(comp) < minpx:
                    for c in comp:
                        px[c] = (0, 0, 0, 0)
                    total += len(comp)
        im.save(os.path.join(d, f))
    print(f"[clean] {eid}/{anim}: {total} px soltos removidos")


def cmd_bake_pile_death(eid, keep=10, frames=8):
    """Morte ASSADA de criatura-pilha (plague_rats). O v3 não derruba a
    pilha: 2 prompts terminaram de pé e, com o cadáver pinado como último
    quadro, segurou o monte inteiro e PULOU pro cadáver no fim. Recortar a
    camada de cima deixou costura (linha reta cortando ratos). Aqui o monte
    inteiro AFUNDA na terra com queda acelerada — cortado na linha do chão,
    que é onde a cena já tem chão — até sobrar só uma faixa de `keep` px
    (rabos e lombos rente ao solo). Sem costura: o único corte é o chão.
    Quadro 0 = idle (pé na mesma linha)."""
    from PIL import Image
    base = Image.open(os.path.join(ENEMIES_DIR, eid, "south.png")).convert("RGBA")
    W, H = base.size
    x0, y0, x1, floor = base.getbbox()
    d = os.path.join(ENEMIES_DIR, eid, "animations/death/south")
    for f in os.listdir(d):
        os.remove(os.path.join(d, f))
    base.save(os.path.join(d, "0.png"))
    drop = (floor - y0) - keep
    for k in range(1, frames + 1):
        t = k / frames
        dy = int(round(t * t * drop))
        fr = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        fr.alpha_composite(base.crop((0, 0, W, floor - dy)), (0, dy))
        fr.save(os.path.join(d, f"{k}.png"))
    print(f"[pile-death] {eid}: {frames + 1} quadros")


def cmd_sheet(ids):
    for eid in ids:
        F.sheet(eid)


if __name__ == "__main__":
    c = sys.argv[1] if len(sys.argv) > 1 else ""
    a = sys.argv[2:]
    if c == "base":
        cmd_base(a[0], a[1] if len(a) > 1 else None)
    elif c == "pick":
        cmd_pick(a[0], a[1])
    elif c == "idle":
        for eid in a:
            cmd_idle(eid)
    elif c == "endframe":
        cmd_endframe(a[0], " ".join(a[1:]))
    elif c == "endpick":
        cmd_endpick(a[0], a[1])
    elif c == "clean":
        cmd_clean(a[0], a[1], int(a[2]) if len(a) > 2 else 8)
    elif c == "piledeath":
        cmd_bake_pile_death(a[0], int(a[1]) if len(a) > 1 else 10)
    elif c == "contact":
        contact(a[0])
    elif c == "sheet":
        cmd_sheet(a)
    else:
        print(__doc__)
