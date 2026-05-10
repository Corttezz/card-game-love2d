#!/usr/bin/env python3
# tools/generate_sfx.py
# Gera SFX únicos via ElevenLabs sound-effects API.
# Usage: ELEVENLABS_API_KEY=xxx python3 tools/generate_sfx.py [sfx_id|all]
#
# Cada SFX é descrito com prompt focado no contexto do jogo (não genérico).
# Salva em audio/sfx/<id>.mp3.

import os
import sys
import urllib.request
import json

API_URL = "https://api.elevenlabs.io/v1/sound-generation"
OUT_DIR = "audio/sfx"

# 8 SFX dedicados pra substituir cardSelect/deckStart/purchaseConfirm repetidos.
SFX = [
    {
        "id": "coin_clink",
        "duration": 0.4,
        "prompt": (
            "Single small gold coin dropping onto a stack of coins, bright "
            "metallic clink with subtle sparkle reverb tail, 8-bit retro RPG "
            "style, satisfying and crisp"
        ),
    },
    {
        "id": "coin_total_thud",
        "duration": 0.6,
        "prompt": (
            "Heavy pile of gold coins crashing down with deep metallic resonance, "
            "low-pitched cha-ching, RPG cash-out feel"
        ),
    },
    {
        "id": "cash_out_chime",
        "duration": 0.9,
        "prompt": (
            "Triumphant brass and bell chime confirming a victory cash-out, "
            "ascending notes with golden shimmer, short and impactful, "
            "Balatro-style positive feedback"
        ),
    },
    {
        "id": "pack_seal_break",
        "duration": 0.7,
        "prompt": (
            "Wax seal cracking open on a parchment envelope, brittle paper "
            "tearing, magical sparkle release, mystical reveal sound, "
            "card pack opening, Balatro/Hearthstone style"
        ),
    },
    {
        "id": "pack_card_reveal",
        "duration": 0.5,
        "prompt": (
            "Whoosh of a magical card materializing from thin air, soft chime "
            "tail, bright and arcane, short and ethereal"
        ),
    },
    {
        "id": "pack_card_pick",
        "duration": 0.5,
        "prompt": (
            "Player selecting a card from a magical pack, satisfying click "
            "with golden sparkle confirm, decisive and crisp"
        ),
    },
    {
        "id": "shop_open",
        "duration": 0.8,
        "prompt": (
            "Cozy shop bell ringing as door opens, warm welcoming chime with "
            "subtle wooden creak, medieval merchant vibe"
        ),
    },
    {
        "id": "shop_reroll",
        "duration": 0.6,
        "prompt": (
            "Quick riffle of cards being shuffled and re-dealt, brisk paper "
            "shuffle with magical sparkle on top, refresh action sound"
        ),
    },
]


def generate(item, api_key):
    body = json.dumps({
        "text": item["prompt"],
        "duration_seconds": item.get("duration", 1.0),
        "prompt_influence": 0.55,
        "model_id": "eleven_text_to_sound_v2",
    }).encode("utf-8")

    req = urllib.request.Request(
        API_URL,
        data=body,
        headers={
            "xi-api-key": api_key,
            "Content-Type": "application/json",
        },
        method="POST",
    )

    print(f"[gen] {item['id']}: {item['prompt'][:60]}...")
    with urllib.request.urlopen(req, timeout=60) as resp:
        data = resp.read()

    out = os.path.join(OUT_DIR, item["id"] + ".mp3")
    with open(out, "wb") as f:
        f.write(data)
    print(f"[ok]  {out} ({len(data)} bytes)")


def main():
    api_key = os.environ.get("ELEVENLABS_API_KEY")
    if not api_key:
        print("ERROR: ELEVENLABS_API_KEY não setada. Defina e rode de novo:")
        print("  export ELEVENLABS_API_KEY=<sua-chave>")
        print("  python3 tools/generate_sfx.py")
        return 1

    os.makedirs(OUT_DIR, exist_ok=True)

    target = sys.argv[1] if len(sys.argv) > 1 else "all"
    if target == "all":
        for item in SFX:
            try:
                generate(item, api_key)
            except Exception as e:
                print(f"[fail] {item['id']}: {e}")
    else:
        for item in SFX:
            if item["id"] == target:
                generate(item, api_key)
                return 0
        print(f"ERROR: sfx '{target}' não encontrado. Disponíveis: {[s['id'] for s in SFX]}")
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
