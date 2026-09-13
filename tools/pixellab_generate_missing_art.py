#!/usr/bin/env python3
"""
tools/pixellab_generate_missing_art.py — ilustrações 64×64 das 12 cartas que
ficavam ORFAS no atlas `src/data/card_art.lua` (caiam no fallback por tipo e
por isso compartilhavam arte: Adrenalina saia igual a Pocao de Cura, etc).

Uso:
  python tools/pixellab_generate_missing_art.py queue   # enfileira (ondas de 6)
  python tools/pixellab_generate_missing_art.py poll    # baixa prontos

Saida: assets/sprites/icons/<card_id>.png (contrato do CardArt atlas).
Jobs em tools/preview_out/missingart_jobs.json.
Contrato de estilo: memory/sprite_design_queue.md (sufixo canonico).
"""
import json
import os
import re
import sys
import base64
import time
import urllib.request

URL = "https://api.pixellab.ai/mcp"
TOKEN = "89fc4637-1de8-41f9-b0db-3ecbda2d65b2"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
JOBS_FILE = os.path.join(ROOT, "tools/preview_out/missingart_jobs.json")
OUT_DIR = os.path.join(ROOT, "assets/sprites/icons")

STYLE = (", dark fantasy grimoire illustration pixel art, inked engraving "
         "style, earthy desaturated palette (bone white, rust orange, deep "
         "blood crimson, tarnished dark steel, charcoal black, burnt sienna, "
         "aged gold, dark leather brown), NO neon colors, NO bright magenta "
         "or cyan, crisp 1px pure black outline, detailed shading with clear "
         "darks and mid-tones, dramatic silhouette, moody upper-left "
         "lighting, limited 8-color palette, Slay the Spire and Magic the "
         "Gathering card art aesthetic")

# Cada descricao vem do QUE A CARTA FAZ (efeitos + tags), nao do nome.
CARDS = {
    # ===== WARRIOR =====
    # Perde 4 HP, restaura 2 mana, compra 1 carta, Exaurir.
    "warrior_adrenaline_rush":
        "brutal iron syringe injector stabbed deep into a muscular bare "
        "forearm, blood running down the skin, jolt of energy sparks bursting "
        "up the arm, leather strap tourniquet",
    # Compre 2 cartas, +1 de Forca.
    "warrior_battle_orders":
        "ornate curved brass war horn with leather strap and engraved command "
        "sigils, being blown, carved sound ripple arcs radiating from the bell",
    # Joker: +2 bloqueio, reflete 8 no primeiro bloqueio do turno.
    "warrior_eternal_bulwark":
        "ancient black iron fortress gate set in a stone arch, rows of long "
        "outward-facing spikes bristling from the doors, braziers burning on "
        "both sides",
    # 6 de bloqueio + aplica Fraco por 2 turnos.
    "warrior_taunt":
        "armored gauntlet hand raised in a mocking beckoning gesture over a "
        "dented battered round shield, jeering challenge",
    # ===== MAGE =====
    # Evoca o orbe mais antigo, compra 1 carta.
    "mage_dark_harvest":
        "skeletal bony hand gripping a small reaping scythe, cutting a dark "
        "sphere of energy apart, shadow wisps being drawn into the palm",
    # Canaliza Raio + Gelo + Sombra, ganha +1 de Foco.
    "mage_primordial_storm":
        "three elemental spheres orbiting a churning storm vortex, one "
        "crackling with lightning, one encased in jagged frost, one a void of "
        "black shadow",
    # Cura 5 de HP, canaliza orbe Sagrado.
    # v2: v1 saiu como maos escuras sem nenhuma luz — nao lia "radiante".
    "mage_radiant_prayer":
        "huge blazing aged-gold sunburst halo filling the frame, thick rays of "
        "holy light streaming outward, small dark silhouette of clasped "
        "praying hands centered inside the glow",
    # Joker: todas as curas +50%.
    "mage_sacred_chalice":
        "ornate golden ceremonial chalice with gemstones on the stem, "
        "overflowing with glowing sacred light spilling over the rim",
    # ===== ROGUE =====
    # 4 de dano, aplica 3 de Veneno.
    "rogue_dirty_blade":
        "rusted notched dagger crusted with filth and dried grime, sickly "
        "green rot stains along the pitted blade, flies circling",
    # 6 de dano, cura 2 de HP ao atacar.
    # v2: v1 saiu um punhal reto vermelho quase identico ao icone `dagger`.
    # v3: v2 saiu com a LAMINA EM MAGENTA VIVO — viola o contrato de paleta
    # ("NO bright magenta"). Liderar pela cor e proibir explicitamente.
    "rogue_leech_blade":
        "dark tarnished iron sickle blade in deep desaturated crimson and "
        "charcoal tones ONLY, fat swollen black leech coiled tightly around "
        "the blade, engorged with dark blood, a deep blood-crimson droplet "
        "hanging from the hooked tip over a small dark stone bowl, "
        "absolutely NO pink, NO magenta, NO hot red, muted rust and dried "
        "blood tones only",
    # Custo 0, 2 de dano, aplica 2 de Veneno.
    # v2: v1 leu como pena/escrivaninha, sem veneno visivel.
    "rogue_poison_dart":
        "long wooden blowgun tube held diagonally with a small feathered dart "
        "loaded at the mouth, sickly green venom dripping thickly from the "
        "needle point, faint green vapor",
    # Joker: cada ataque aplica 2 de Veneno.
    "rogue_toxin_master":
        "hooded plague doctor beak mask with round dark goggles, bandolier of "
        "corked poison vials strapped across the chest, green fumes seeping "
        "from the beak",
}

WAVE = 6          # limite pratico de jobs simultaneos no PixelLab
WAVE_SLEEP = 200  # segundos entre ondas


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
    todo = [c for c in CARDS
            if not (c in jobs and jobs[c].get("object_id"))
            and not os.path.exists(os.path.join(OUT_DIR, c + ".png"))]
    for wave_start in range(0, len(todo), WAVE):
        wave = todo[wave_start:wave_start + WAVE]
        for card_id in wave:
            try:
                result = rpc("tools/call", {
                    "name": "create_map_object",
                    "arguments": {
                        "description": CARDS[card_id] + STYLE,
                        "width": 64, "height": 64,
                        "view": "side",
                        "outline": "single color outline",
                        "shading": "detailed shading",
                        "detail": "high detail",
                    },
                })
                text = result["result"]["content"][0]["text"]
                m = re.search(r"Object ID:\*\*\s*`([^`]+)`", text) \
                    or re.search(r"\bid:\s*([0-9a-f-]{36})", text)
                if m:
                    jobs[card_id] = {"object_id": m.group(1)}
                    print(f"[queue] {card_id} -> {m.group(1)}")
                else:
                    print(f"[queue] {card_id}: sem object_id — {text[:120]}")
            except Exception as e:
                print(f"[queue] {card_id}: FALHOU {e}")
            save_jobs(jobs)
            time.sleep(1.5)
        if wave_start + WAVE < len(todo):
            print(f"[queue] onda cheia, aguardando {WAVE_SLEEP}s...")
            time.sleep(WAVE_SLEEP)
    print(f"[queue] {len(todo)} jobs enfileirados")


def poll():
    jobs = load_jobs()
    os.makedirs(OUT_DIR, exist_ok=True)
    pending = 0
    for card_id, job in jobs.items():
        out = os.path.join(OUT_DIR, card_id + ".png")
        if os.path.exists(out) or not job.get("object_id"):
            continue
        try:
            result = rpc("tools/call", {
                "name": "get_map_object",
                "arguments": {"object_id": job["object_id"]},
            })
            parts = result["result"]["content"]
            saved = False
            for p in parts:
                if p.get("type") == "image" and p.get("data"):
                    with open(out, "wb") as f:
                        f.write(base64.b64decode(p["data"]))
                    print(f"[poll] {card_id} salvo")
                    saved = True
                    break
            if not saved:
                txt = parts[0].get("text", "")[:80]
                print(f"[poll] {card_id}: aguardando ({txt})")
                pending += 1
        except Exception as e:
            print(f"[poll] {card_id}: erro {e}")
            pending += 1
    print(f"[poll] pendentes: {pending}")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "queue"
    if cmd == "queue":
        queue()
    elif cmd == "poll":
        poll()
    else:
        print(__doc__)
