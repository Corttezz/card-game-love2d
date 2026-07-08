#!/usr/bin/env python3
"""
tools/pixellab_generate_new_cards.py — ilustrações 64×64 das 17 cartas novas
(gameplay-overhaul, Jul/2026) via PixelLab HTTP (bypass validado).

Uso:
  python3 tools/pixellab_generate_new_cards.py queue   # enfileira (em ondas)
  python3 tools/pixellab_generate_new_cards.py poll    # baixa prontos

Saída: assets/sprites/icons/<card_id>.png (contrato do CardArt atlas).
Jobs em tools/preview_out/newcards_jobs.json.
Contrato de estilo: memory/sprite_design_queue.md (sufixo canônico).
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
JOBS_FILE = os.path.join(ROOT, "tools/preview_out/newcards_jobs.json")
OUT_DIR = os.path.join(ROOT, "assets/sprites/icons")

STYLE = (", dark fantasy grimoire illustration pixel art, inked engraving "
         "style, earthy desaturated palette (bone white, rust orange, deep "
         "blood crimson, tarnished dark steel, charcoal black, burnt sienna, "
         "aged gold, dark leather brown), NO neon colors, NO bright magenta "
         "or cyan, crisp 1px pure black outline, detailed shading with clear "
         "darks and mid-tones, dramatic silhouette, moody upper-left "
         "lighting, limited 8-color palette, Slay the Spire and Magic the "
         "Gathering card art aesthetic")

CARDS = {
    # ===== WARRIOR =====
    "warrior_war_cry":
        "roaring armored warrior head with open helm, battle shout with "
        "carved sound wave arcs",
    "warrior_twin_strike":
        "two crossed sword slash arcs striking the same point, double blade "
        "trails",
    "warrior_iron_discipline":
        "clenched gauntlet fist in front of a tall iron tower shield",
    "warrior_colossus_blow":
        "giant spiked stone maul hammer swung downward smashing the ground, "
        "cracks and rubble flying, huge weapon fills the frame",
    "warrior_standard_bearer":
        "tattered war banner standard on a spear pole, heraldic bull crest",
    # ===== MAGE =====
    "mage_overcharge":
        "large glowing sphere of raw magical energy overloading, jagged "
        "energy arcs bursting outward in all directions, orb fills the frame",
    "mage_arcane_focus":
        "glowing third-eye rune floating between concentric arcane sigils",
    "mage_mind_spike":
        "jagged crystal spike piercing a glowing mind silhouette",
    "mage_twin_bolts":
        "two forked lightning bolts striking down in parallel",
    "mage_arcane_torrent":
        "swirling vertical torrent of arcane energy beams and glyphs",
    # ===== ROGUE =====
    "rogue_venom_coating":
        "curved assassin dagger dripping thick green venom over a vial",
    "rogue_twin_fangs":
        "two serpent fangs striking with venom droplets, snake curled behind",
    "rogue_expose_weakness":
        "dagger tip pointing at a cracked glowing weak spot on armor plate",
    "rogue_shadow_dance":
        "hooded rogue silhouette with twin shadow afterimages mid spin",
    "rogue_executioner":
        "hooded executioner's broad axe blade resting over a chopping block "
        "with skull",
    # ===== BASIC =====
    "attack_cleave":
        "wide horizontal sword cleave slash arc cutting through the frame",
    "defense_bulwark":
        "massive stone rampart wall section with tower crest and iron gate",
}


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
    queued = 0
    for card_id, subject in CARDS.items():
        if card_id in jobs and jobs[card_id].get("object_id"):
            continue
        out = os.path.join(OUT_DIR, card_id + ".png")
        if os.path.exists(out):
            continue
        try:
            result = rpc("tools/call", {
                "name": "create_map_object",
                "arguments": {
                    "description": subject + STYLE,
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
                queued += 1
                print(f"[queue] {card_id} -> {m.group(1)}")
            else:
                print(f"[queue] {card_id}: sem object_id — {text[:100]}")
        except Exception as e:
            print(f"[queue] {card_id}: FALHOU {e}")
        save_jobs(jobs)
        time.sleep(1.5)
    print(f"[queue] {queued} novos jobs")


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
