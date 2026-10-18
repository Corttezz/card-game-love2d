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
    # ===== Assinaturas dos coringas de COMBO (Out/2026) — vão pra
    # audio/sfx/joker-sig/<card_id>.mp3 (registro por SCAN no main.lua).
    # Free tier: regerar com plano pago antes de vender (known_gaps §0b).
    {
        "id": "joker_combo_volley", "dir": "audio/sfx/joker-sig",
        "duration": 0.9,
        "prompt": (
            "Three quick steel daggers thrown in rapid succession, three "
            "sharp whooshing swishes ending in three small metallic thunks "
            "into wood, rhythmic, retro dark fantasy card game"
        ),
    },
    {
        "id": "joker_combo_wall", "dir": "audio/sfx/joker-sig",
        "duration": 0.9,
        "prompt": (
            "Two heavy bronze round shields slamming together edge to edge, "
            "deep resonant metallic clang with a short low ring, sturdy "
            "defensive wall locking into place, dark fantasy"
        ),
    },
    {
        "id": "joker_combo_pair", "dir": "audio/sfx/joker-sig",
        "duration": 0.9,
        "prompt": (
            "A cracked magic mirror humming, then a crisp glass chime "
            "that echoes back as an identical mirrored twin chime a moment "
            "later, eerie and satisfying, dark fantasy card game"
        ),
    },
    # ===== Cinemática de CHEFE (Out/2026) — audio/sfx/boss/, registrados
    # sob demanda pelo src/ui/BossCinematic.lua (Sfx.has decide o fallback).
    # Free tier: regerar com plano pago antes de vender (known_gaps §0b).
    {
        "id": "boss_eyes_ignite", "dir": "audio/sfx/boss",
        "duration": 1.4,
        "prompt": (
            "Two embers igniting in a pitch dark stone hall, low sinister "
            "rumble swelling under a soft crackle, a distant crow croak, "
            "ominous dark fantasy, retro pixel RPG"
        ),
    },
    {
        "id": "boss_wing_pass", "dir": "audio/sfx/boss",
        "duration": 0.8,
        "prompt": (
            "Giant raven wings beating once as a huge bird sweeps past the "
            "listener at high speed, heavy feathered whoosh with a gust of "
            "wind and rustling feathers, dark fantasy"
        ),
    },
    {
        "id": "boss_reveal_sting", "dir": "audio/sfx/boss",
        "duration": 2.6,
        "prompt": (
            "Dark orchestral boss reveal sting: a heavy low brass hit with "
            "a short choir swell and a flock of crows cawing, then a deep "
            "resonant tail, menacing, retro dark fantasy RPG"
        ),
    },
    # ===== Cinemática de CHEFE, rodada 3 (Out/2026): som na sequência inteira.
    {
        "id": "boss_eyes_rumble", "dir": "audio/sfx/boss",
        "duration": 3.0,
        "prompt": (
            "Deep subterranean rumble, slow and menacing, continuous low drone with a faint ember crackle, seamless loop, dark fantasy dungeon, no melody"
        ),
    },
    {
        "id": "boss_blink_click", "dir": "audio/sfx/boss",
        "duration": 0.5,
        "prompt": (
            "A single dry wet click, like a giant eyelid snapping shut and open once, close and intimate, creature sound, short"
        ),
    },
    {
        "id": "appear_1", "dir": "audio/sfx/boss/crow",
        "duration": 1.3,
        "prompt": (
            "Large black raven wings flapping in and landing nearby: four heavy wingbeats, a soft feather rustle as it settles, then one single low raspy croak heard far away in the distance, only one short call. Dark fantasy game sound effect, no music."
        ),
    },
    {
        "id": "appear_2", "dir": "audio/sfx/boss/crow",
        "duration": 1.4,
        "prompt": (
            "Three heavy wingbeats of a raven arriving and landing on a branch, feathers folding. After a pause, one very faint deep croak far in the distance, muffled, a single short call. Dark fantasy game sound effect, no music."
        ),
    },
    {
        "id": "appear_3", "dir": "audio/sfx/boss/crow",
        "duration": 1.0,
        "prompt": (
            "Only wings: a large black raven flies in and lands, three or four strong wingbeats getting closer, then feathers folding. No bird calls, no cawing, no vocals. Close, dry, dark fantasy game sound effect."
        ),
    },
    {
        "id": "dive_1", "dir": "audio/sfx/boss/crow",
        "duration": 0.9,
        "prompt": (
            "A single large black bird dives fast through the air: a short sharp whoosh of feathered wings swooping down, ending in a dry hard peck impact of beak and claws striking leather. No bird calls, no cawing, no vocals. Dark fantasy game sound effect, close, dry."
        ),
    },
    {
        "id": "dive_2", "dir": "audio/sfx/boss/crow",
        "duration": 0.8,
        "prompt": (
            "Fast feathered swoop: a raven dives down with a quick rising whoosh of wings, then a sharp dry thud of a beak and talons striking. Very short. No bird calls, no cawing, no vocals. Dark fantasy combat sound effect."
        ),
    },
    {
        "id": "dive_3", "dir": "audio/sfx/boss/crow",
        "duration": 0.8,
        "prompt": (
            "A black crow swoops down from above: a short building whoosh of air through stiff feathers, then a single dry knock of a beak striking hard. No bird calls, no cawing, no whistle, no vocals. Close, dry, dark fantasy combat sound effect."
        ),
    },
    {
        "id": "flock_1", "dir": "audio/sfx/boss/crow",
        "duration": 1.6,
        "prompt": (
            "A flock of dozens of black crows takes off at once: a dense mass of flapping wings and rustling feathers, rising and sweeping past, then fading. Only wings, no cawing, no bird calls, no vocals. Dark fantasy game sound effect."
        ),
    },
    {
        "id": "flock_2", "dir": "audio/sfx/boss/crow",
        "duration": 1.5,
        "prompt": (
            "Swarm of ravens whirling around: thick fluttering of many wings, a rushing cloud of feathers passing overhead and away. Only wings and air, no calls, no cawing, no vocals. Dark fantasy game sound effect."
        ),
    },
    {
        "id": "flock_3", "dir": "audio/sfx/boss/crow",
        "duration": 1.4,
        "prompt": (
            "Murder of crows scattering: a sudden rush of dozens of wings flapping hard and flying off, rustling feathers, wind. Only wings, no cawing, no vocals. Dark fantasy game sound effect."
        ),
    },
    {
        "id": "cine_1", "dir": "audio/sfx/boss/crow",
        "duration": 1.9,
        "prompt": (
            "Ominous crow king entrance: slow powerful wingbeats of a huge black bird, then one single long low croaking caw, one call only, with cavernous reverb. Dark fantasy cinematic sound effect, no music."
        ),
    },
    {
        "id": "cine_2", "dir": "audio/sfx/boss/crow",
        "duration": 1.8,
        "prompt": (
            "A single low guttural raven call, one only, deep and rough, followed by a flurry of wings and falling feathers in a dark hall with reverb. Dark fantasy cinematic sound effect, no music."
        ),
    },
    {
        "id": "cine_3", "dir": "audio/sfx/boss/crow",
        "duration": 1.9,
        "prompt": (
            "Dying crow lord: one single hoarse fading raven caw, one call only, then wings flutter away and feathers drift down, distant echo. Dark fantasy cinematic sound effect, no music."
        ),
    },
    {
        "id": "boss_land_impact", "dir": "audio/sfx/boss",
        "duration": 1.1,
        "prompt": (
            "Huge winged creature slamming down onto stone, heavy deep thud with stone debris rattling and a short low rumble tail, dark fantasy boss landing"
        ),
    },
    {
        "id": "boss_feathers_settle", "dir": "audio/sfx/boss",
        "duration": 1.3,
        "prompt": (
            "Dozens of feathers fluttering and settling softly onto a stone floor after a gust, delicate rustling, quiet tail"
        ),
    },
    {
        "id": "boss_death_thud", "dir": "audio/sfx/boss",
        "duration": 0.9,
        "prompt": (
            "A massive body collapsing onto stone in slow motion, deep muffled thud with bones cracking, long low tail, dark fantasy"
        ),
    },
    {
        "id": "boss_feather_burst", "dir": "audio/sfx/boss",
        "duration": 0.8,
        "prompt": (
            "A violent burst of feathers exploding outward with a whoosh of air, fast rustle, dark fantasy creature death"
        ),
    },
    {
        "id": "boss_hold_ambience", "dir": "audio/sfx/boss",
        "duration": 2.8,
        "prompt": (
            "Eerie quiet after a battle in a stone hall: distant wind, a slow drip of water, faint ember crackle, somber, seamless loop, no melody"
        ),
    },
    # ===== Entradas/mortes dos outros 5 chefes (Out/2026).
    {
        "id": "boss_rune_ignite", "dir": "audio/sfx/boss",
        "duration": 0.6,
        "prompt": (
            "A single arcane rune igniting with a cold crystalline chime and a short icy hiss, magical, dark fantasy"
        ),
    },
    {
        "id": "boss_frost_storm", "dir": "audio/sfx/boss",
        "duration": 2.6,
        "prompt": (
            "A swirling blizzard of ice and arcane wind building up inside a stone hall, crackling frost, howling gust, seamless loop, dark fantasy"
        ),
    },
    {
        "id": "boss_frost_shatter", "dir": "audio/sfx/boss",
        "duration": 1.0,
        "prompt": (
            "A large ice statue shattering into thousands of shards with a crystalline crash and tinkling fragments scattering on stone"
        ),
    },
    {
        "id": "boss_door_burst", "dir": "audio/sfx/boss",
        "duration": 1.2,
        "prompt": (
            "A massive iron and bone gate exploding outward with a deep boom, splintering wood, stone debris and a roaring blast of fire behind it"
        ),
    },
    {
        "id": "boss_hellfire_wall", "dir": "audio/sfx/boss",
        "duration": 2.6,
        "prompt": (
            "A towering wall of hellfire roaring and crackling with deep bass rumble, embers popping, demonic, seamless loop"
        ),
    },
    {
        "id": "boss_chains_rattle", "dir": "audio/sfx/boss",
        "duration": 1.4,
        "prompt": (
            "Heavy iron chains dropping and rattling against stone walls, clanking and swinging, echo of a large hall"
        ),
    },
    {
        "id": "boss_lava_implosion", "dir": "audio/sfx/boss",
        "duration": 1.2,
        "prompt": (
            "A giant armored body sinking into lava with a hiss, bubbling magma and a deep implosive whump, fading embers"
        ),
    },
    {
        "id": "boss_blizzard_whiteout", "dir": "audio/sfx/boss",
        "duration": 2.8,
        "prompt": (
            "A fierce whiteout blizzard howling through a frozen hall, icy wind gusts, snow hissing, seamless loop"
        ),
    },
    {
        "id": "boss_ice_crackle", "dir": "audio/sfx/boss",
        "duration": 1.0,
        "prompt": (
            "Ice forming rapidly and cracking across a stone floor, sharp crystalline crackles and creaks, cold"
        ),
    },
    {
        "id": "boss_heartbeat", "dir": "audio/sfx/boss",
        "duration": 1.2,
        "prompt": (
            "A single enormous wet heartbeat of a giant rotting heart, deep thump thump with a squelch, echo in a cave"
        ),
    },
    {
        "id": "boss_roots_crawl", "dir": "audio/sfx/boss",
        "duration": 2.2,
        "prompt": (
            "Thick wooden roots creeping and cracking across a stone floor, creaking wood, wet snapping, mud squelching, seamless loop"
        ),
    },
    {
        "id": "boss_emerge_tear", "dir": "audio/sfx/boss",
        "duration": 1.3,
        "prompt": (
            "A giant creature tearing itself free from a tangle of roots and mud, wood splintering, wet suction, deep groan"
        ),
    },
    {
        "id": "boss_spore_collapse", "dir": "audio/sfx/boss",
        "duration": 1.3,
        "prompt": (
            "A huge rotten body collapsing and bursting into a cloud of spores, wet squelch, soft puffing release, cave echo"
        ),
    },
    {
        "id": "boss_eclipse_hum", "dir": "audio/sfx/boss",
        "duration": 2.8,
        "prompt": (
            "A deep ominous cosmic hum as a solar eclipse closes, low drone with a dark choir undertone and faint crackling corona, seamless loop"
        ),
    },
    {
        "id": "boss_descend_wings", "dir": "audio/sfx/boss",
        "duration": 1.6,
        "prompt": (
            "Enormous leathery bat wings unfurling and beating slowly as a figure descends from above, deep wing thumps, fabric rustling"
        ),
    },
    {
        "id": "boss_eclipse_break", "dir": "audio/sfx/boss",
        "duration": 1.2,
        "prompt": (
            "A dark eclipse breaking apart with a bright crystalline crack and a rush of returning light, shimmering tail"
        ),
    },
    # ---- Rainha do Eclipse v2 (chefe final, frente rainha-eclipse, Out/2026) ----
    {
        "id": "boss_eclipse_omen", "dir": "audio/sfx/boss",
        "duration": 4.5,
        "prompt": (
            "The sound of a world dying before an eclipse: a deep descending drone, distant church bells played in reverse, "
            "air being sucked out of a cathedral, electric light flickering with dry ticks, ending in a hollow near-silent hum"
        ),
    },
    {
        "id": "boss_eclipse_unveil", "dir": "audio/sfx/boss",
        "duration": 3.5,
        "prompt": (
            "A slow dark revelation: rising sacred female choir swell with a cold glassy shimmer, huge silk cloak unfurling, "
            "many layered whispered breaths underneath, building to a soft deep impact"
        ),
    },
    {
        "id": "boss_crown_tick", "dir": "audio/sfx/boss",
        "duration": 0.5,
        "prompt": (
            "A single tiny crystal bell tick, very short, pure and crystalline, with a brief cathedral reverb tail"
        ),
    },
    {
        "id": "boss_eclipse_crown", "dir": "audio/sfx/boss",
        "duration": 4.0,
        "prompt": (
            "Coronation sting: reversed choir swell into one huge sacred choir chord with a tubular bell strike and a deep "
            "sub drum hit, then a long dark cathedral reverb tail with a faint dissonant whisper"
        ),
    },
    {
        "id": "boss_eclipse_phase", "dir": "audio/sfx/boss",
        "duration": 2.5,
        "prompt": (
            "An eclipse snapping shut: a deep whoomp, bells sucked backwards, a choir gasp, sudden sub-bass drop and a "
            "hollow metallic ring fading in a stone hall"
        ),
    },
    {
        "id": "boss_eclipse_fade", "dir": "audio/sfx/boss",
        "duration": 4.5,
        "prompt": (
            "A woman's voice holding one high sung note that slowly dissolves into ash and wind, reversed choir fading out, "
            "soft ember crackles, ending in silence"
        ),
    },
    # A FAIXA do chefe final (audio/music/music-boss-eclipse.mp3) foi gerada
    # pelo MESMO endpoint com loop=true, 30 s, e pós-processada (highpass 25 Hz,
    # loudnorm -15, emenda no corte de 8,3 s -> 28 s). Prompt:
    #   "Sacred dark orchestral loop, 58 BPM, D minor. A large cathedral choir
    #    sings a slow solemn hymn in the foreground, pipe organ holds deep
    #    chords, tubular bells toll on the downbeat, a huge slow taiko drum hits
    #    every two bars. Midway the choir turns dissonant and a cold whispered
    #    breath passes under it before the hymn returns. Choir loud and close,
    #    seamless loop"
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

    out_dir = item.get("dir", OUT_DIR)
    os.makedirs(out_dir, exist_ok=True)
    out = os.path.join(out_dir, item["id"] + ".mp3")
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
