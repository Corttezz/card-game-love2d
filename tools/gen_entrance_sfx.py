import json
import os
import subprocess
import sys
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "audio", "sfx", "entrances")
RAW_DIR = os.environ.get("ENTRANCE_RAW_DIR") or os.path.join(ROOT, "tools", "preview_out", "entradas_som", "raw")
API = "https://api.elevenlabs.io/v1/sound-generation"
TARGET_MEAN_DB = -22.0
PEAK_CEIL_DB = -7.0

GEN = {
    "wicker_effigy_wake": (2.0, "dry wicker and straw figure catching fire from inside, whoosh of flames taking hold, crackling twigs, embers popping, night field"),
    "storm_griffin_stop": (1.8, "huge winged beast landing hard on wet hill ground with a thunder crack, heavy feathered wings folding, rumble"),
    "abyss_watcher_stop": (2.0, "deep ominous bass hum of a floating dark entity, wet eyelids opening one by one, low drone swelling, volcanic cavern"),
    "ice_wyrm_rise": (2.0, "thick ice sheet cracking and bursting upward in a geyser of snow and ice shards, deep rumble, blizzard"),
    "spore_mother_rise": (2.0, "giant wet mushroom cap slowly swelling with stretching creaks, then splitting open with a wet tearing pop and a long hiss of spores"),
    "fallen_angel_stop": (2.2, "large feathered wings folding with a soft heavy whump, feathers fluttering down, faint deep holy resonance tail"),
    "harvest_reaper_stop": (1.6, "long scythe blade singing through cold air, metallic ring swinging down, dark whisper of wind in dry wheat"),
    "blight_bull_skid": (1.8, "heavy bull hooves pounding dry dirt at a gallop, four thudding hoofbeats getting closer, then hooves sliding in loose soil and gravel to a stop with a dust puff and a loud snort, animal only, no vehicles, no rubber"),
    "rune_golem_stop": (2.0, "heavy boulders slamming and grinding together into a stack, stone on stone, deep thud, dust settling"),
    "spectral_knight_stop": (1.6, "ghostly plate armor stepping and settling, muffled hollow metal clank with eerie reverb, cold fog"),
    "obsidian_sentinel_wake": (1.8, "close up continuous dry rock grating and cracking for one second as a big stone statue shifts, gravel trickling, then one heavy stone footstep thud, natural rock only, no machinery"),
    "pit_brute_rise": (2.0, "continuous rocks and gravel tumbling as something huge hauls itself over a rocky ledge, hands scraping stone, heavy breathing, cavern echo"),
    "glacier_knight_step": (1.0, "single very heavy iron armored footstep on hard ice, frost crunch, metal plates clank, low thud"),
    "frost_troll_start": (1.8, "snow mound bursting open as a huge troll breaks out, snow explosion, ice chunks tumbling, deep rumble"),
    "mire_hag_stop": (1.5, "rusty lantern chain creaking and swinging close up, boots squelching to a stop in deep mud, swamp water dripping"),
    "croc_warrior_start": (1.8, "large crocodile surging out of swamp water onto muddy bank, big splash, water pouring off scales, mud slap"),
    "blood_duke_stop": (2.0, "swarm of bats converging and snapping shut into one shape, flutter of many leather wings, cloak flourish whoosh"),
    "dullahan_stop": (1.6, "iron armored horseless rider stopping, chains and plate settling, spectral green flame igniting with a whoosh"),
    "cursed_scarecrow_wake": (1.6, "close up thick rope creaking and snapping, dry wood stake splintering, loud straw rustling, burlap tearing free"),
    "hollow_farmer_stop": (1.2, "pitchfork tines dragging through dirt then stabbed into the ground with a heavy wooden thud"),
    "plague_rats_start": (1.6, "close up many small rodents scurrying over dry leaves and dirt, rapid tiny footsteps, loud squeaking, swarm"),
    "moon_gargoyle_wake": (1.8, "stone statue continuously cracking and crumbling, grinding stone, shards falling, ending with a heavy stone thud"),
    "ram_cultist_stop": (1.4, "arcane rune circle igniting with purple energy, low magical hum, robes settling on hill grass"),
    "storm_harpy_stop": (1.6, "large bird of prey wings flapping hard then landing, gust of wind through grass, rain"),
    "ember_imp_rise": (1.4, "fiery crack in the ground bursting open, jet of embers, small creature leaping out, cinders"),
    "hellhound_skid": (1.6, "big heavy paws of a huge dog pounding dry dirt at a run, then paws sliding in loose soil to a stop with a dust skid and a deep chest growl, animal only, no vehicles, no squeal"),
    "abyss_acolyte_stop": (1.4, "dark sigil igniting on cavern floor, low eerie hum, pages of a floating book fluttering"),
    "frost_wight_stop": (1.6, "howling arctic wind condensing with icy crackle, frost forming, ghostly whoosh"),
    "frost_wolf_start": (1.6, "large wolf trotting through deep snow toward the road, paws crunching, snow falling from branches"),
    "rime_shaman_stop": (1.6, "wooden staff planted in snow, ice spike growing out of ground with crackling frost"),
    "bog_ghoul_rise": (1.8, "undead body pulling itself out of thick mud, wet sucking squelch, bubbles, mud dripping"),
    "plague_toad_stop": (1.2, "giant toad landing in swamp puddle with a big wet splash, mud slap"),
    "leech_horror_rise": (1.8, "slimy mass gushing out of a stagnant pool, wet suction, slime dripping, bubbles"),
    "dusk_shade_stop": (1.6, "shadow condensing from the ground with a cold airy whoosh, flickering dark hiss"),
    "dusk_bat_stop": (1.2, "giant bat flapping leathery wings, distinct separate soft wing flaps, cloth-like flutter, small high squeak, no helicopter, no motor"),
    "grave_thrall_rise": (1.8, "continuous packed grave soil breaking and crumbling, claws scraping dirt, clods of earth falling, body dragging out, low groan"),
    "cursed_scarecrow_stop": (1.4, "straw stuffed body dropping onto a dirt road with a wooden clatter, straw scattering, several crows flapping away"),
    "plague_rats_stop": (1.0, "pile of rats squirming together, many squeaks, tiny claws scratching"),
    "frost_wolf_stop": (2.0, "single large wolf howling long into a blizzard wind, cold and distant echo"),
    "blight_bull_stop": (1.0, "huge bull snorting hard and stamping one hoof on dirt, breath steaming"),
    "hellhound_stop": (1.0, "low rumbling growl of a large hound, embers hissing on rock"),
    "pit_brute_stop": (1.2, "huge heavy body landing on cavern rock, rubble scattering, deep chest grunt"),
    "moon_gargoyle_stop": (1.0, "stone creature landing on hard ground, heavy stone thud, pebbles scattering"),
    "obsidian_sentinel_stop": (1.0, "single massive stone and metal footstep on volcanic rock, deep impact, gravel"),
    "storm_griffin_start": (1.5, "huge bird wings beating twice overhead, feathered flaps and air whoosh, rain falling, natural thunder rolling in the distance, no jet, no engine"),
    "storm_harpy_start": (1.5, "sharp thunder crack then large wings diving fast through rain, whoosh"),
    "fallen_angel_start": (2.0, "column of warm light opening from the sky, deep resonant tonal shimmer like a distant organ, no vocals, air pressure"),
    "frost_troll_stop": (1.2, "massive foot stomping onto a frozen road, snow crunch, deep rough grunt"),
    "croc_warrior_stop": (1.4, "huge crocodile hissing and growling low, wet scaled body dragging to a stop in mud"),
    "plague_toad_hop": (0.8, "giant toad hopping and landing on wet swamp ground, soft wet plop"),
    "rune_golem_mid": (1.5, "several boulders rolling and tumbling over hill ground toward one spot, rumble, gravel"),
    "glacier_knight_stop": (1.2, "heavy iron armored knight halting, plates settling with a clank, frost crackling on ice"),
}

ORDER = [
    "wicker_effigy_wake", "storm_griffin_stop", "abyss_watcher_stop", "ice_wyrm_rise", "spore_mother_rise", "fallen_angel_stop",
    "harvest_reaper_stop", "blight_bull_skid", "rune_golem_stop", "spectral_knight_stop", "obsidian_sentinel_wake", "pit_brute_rise",
    "glacier_knight_step", "frost_troll_start", "mire_hag_stop", "croc_warrior_start", "blood_duke_stop", "dullahan_stop",
    "cursed_scarecrow_stop", "hollow_farmer_stop", "plague_rats_stop", "moon_gargoyle_wake", "ram_cultist_stop", "storm_harpy_stop",
    "ember_imp_rise", "hellhound_skid", "abyss_acolyte_stop", "frost_wight_stop", "frost_wolf_stop", "rime_shaman_stop",
    "bog_ghoul_rise", "plague_toad_stop", "leech_horror_rise", "dusk_shade_stop", "dusk_bat_stop", "grave_thrall_rise",
]

LAYER = {
    "cursed_scarecrow_stop": [("scene-wood-knock.mp3", 0.0, 0.8, 1.0), ("scene-rustle.mp3", 0.05, 1.15, 0.9), ("boss/crow/flock_2.mp3", 0.35, 1.0, 0.7)],
    "hollow_farmer_stop": [("scene-grass-swish.mp3", 0.0, 0.7, 1.0), ("scene-stone-thud.mp3", 0.45, 0.85, 1.0), ("scene-wood-knock.mp3", 0.47, 0.75, 0.8)],
    "plague_rats_stop": [("scene-rustle.mp3", 0.0, 1.25, 1.0), ("scene-grass-swish.mp3", 0.2, 1.4, 0.9), ("scene-rustle.mp3", 0.5, 1.1, 0.8)],
    "moon_gargoyle_wake": [("boss/boss_frost_shatter.mp3", 0.0, 0.8, 0.9), ("boss/colossus_crack.mp3", 0.1, 0.9, 1.0), ("scene-stone-thud.mp3", 0.9, 0.7, 1.0)],
    "ram_cultist_stop": [("impact-arcane.mp3", 0.0, 0.8, 0.9), ("boss/boss_rune_ignite.mp3", 0.1, 1.1, 1.0), ("scene-rustle.mp3", 0.0, 0.9, 0.5)],
    "storm_harpy_stop": [("boss/boss_wing_pass.mp3", 0.0, 1.15, 1.0), ("scene-grass-swish.mp3", 0.3, 0.9, 0.9), ("scene-stone-thud.mp3", 0.55, 1.1, 0.7)],
    "ember_imp_rise": [("boss/boss_emerge_tear.mp3", 0.0, 1.3, 0.9), ("impact-fire.mp3", 0.15, 1.2, 1.0), ("scene-cloud-poof.mp3", 0.3, 1.3, 0.6)],
    "hellhound_skid": [("scene-grass-swish.mp3", 0.0, 0.6, 1.0), ("scene-stone-thud.mp3", 0.35, 0.8, 0.9), ("enemy-buff-roar.mp3", 0.25, 0.85, 1.0)],
    "abyss_acolyte_stop": [("impact-arcane.mp3", 0.0, 0.7, 0.9), ("boss/boss_eyes_ignite.mp3", 0.05, 0.95, 1.0), ("shop-book-flip.mp3", 0.3, 0.9, 0.7)],
    "frost_wight_stop": [("event-enter-wind.mp3", 0.0, 0.9, 1.0), ("boss/boss_ice_crackle.mp3", 0.4, 1.1, 0.9), ("impact-ice.mp3", 0.7, 0.8, 0.6)],
    "frost_wolf_stop": [("scene-rustle.mp3", 0.0, 0.85, 0.9), ("scene-cloud-poof.mp3", 0.2, 0.75, 0.8), ("enemy-buff-roar.mp3", 0.5, 1.15, 0.8)],
    "rime_shaman_stop": [("scene-wood-knock.mp3", 0.0, 0.75, 1.0), ("boss/boss_ice_crackle.mp3", 0.15, 1.0, 1.0), ("impact-ice.mp3", 0.5, 0.9, 0.6)],
    "bog_ghoul_rise": [("shop-potion-bubble.mp3", 0.0, 0.65, 1.0), ("impact-poison.mp3", 0.3, 0.8, 0.9), ("scene-cloud-poof.mp3", 0.5, 0.6, 0.7)],
    "plague_toad_stop": [("scene-cloud-poof.mp3", 0.0, 0.7, 1.0), ("shop-potion-bubble.mp3", 0.05, 0.8, 0.8), ("impact-poison.mp3", 0.1, 1.1, 0.6)],
    "leech_horror_rise": [("shop-potion-bubble.mp3", 0.0, 0.55, 1.0), ("shop-potion-drink.mp3", 0.2, 0.7, 0.8), ("impact-poison.mp3", 0.6, 0.75, 0.8)],
    "dusk_shade_stop": [("event-enter-wind.mp3", 0.0, 0.7, 0.9), ("impact-dark.mp3", 0.3, 0.85, 1.0), ("boss/boss_eclipse_fade.mp3", 0.0, 1.1, 0.6)],
    "dusk_bat_stop": [("boss/boss_wing_pass.mp3", 0.0, 1.35, 1.0), ("boss/boss_wing_pass.mp3", 0.25, 1.5, 0.8), ("scene-rustle.mp3", 0.4, 1.2, 0.5)],
    "grave_thrall_rise": [("scene-stone-thud.mp3", 0.0, 0.7, 1.0), ("scene-grass-swish.mp3", 0.1, 0.6, 0.9), ("impact-dark.mp3", 0.55, 0.8, 0.8)],
}


def key():
    k = os.environ.get("ELEVENLABS_API_KEY")
    if not k:
        print("[FAIL] ELEVENLABS_API_KEY ausente")
        sys.exit(1)
    return k


def balance():
    req = urllib.request.Request("https://api.elevenlabs.io/v1/user/subscription", headers={"xi-api-key": key()})
    with urllib.request.urlopen(req, timeout=30) as r:
        d = json.loads(r.read().decode())
    used, lim = d["character_count"], d["character_limit"]
    print("creditos usados=%d limite=%d restantes=%d" % (used, lim, lim - used))
    return lim - used


def generate(name):
    dur, prompt = GEN[name]
    os.makedirs(RAW_DIR, exist_ok=True)
    raw = os.path.join(RAW_DIR, name + ".mp3")
    body = json.dumps({"text": prompt, "duration_seconds": dur, "prompt_influence": 0.45}).encode()
    req = urllib.request.Request(API, data=body, method="POST",
                                 headers={"xi-api-key": key(), "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            data = r.read()
    except urllib.error.HTTPError as e:
        print("[FAIL] %s HTTP %d %s" % (name, e.code, e.read()[:200]))
        return None
    with open(raw, "wb") as f:
        f.write(data)
    print("[ok] gerado %s (%d bytes)" % (raw, len(data)))
    return raw


def volume(path):
    out = subprocess.run(["ffmpeg", "-hide_banner", "-i", path, "-af", "volumedetect", "-f", "null", "-"],
                         capture_output=True, text=True).stderr
    mean = peak = None
    for line in out.splitlines():
        if "mean_volume:" in line:
            mean = float(line.split("mean_volume:")[1].split("dB")[0])
        if "max_volume:" in line:
            peak = float(line.split("max_volume:")[1].split("dB")[0])
    return mean, peak


def duration(path):
    out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", path],
                         capture_output=True, text=True).stdout.strip()
    return float(out or 0)


def finish(src, name, maxdur=None):
    os.makedirs(OUT_DIR, exist_ok=True)
    tmp = os.path.join(RAW_DIR, name + "_trim.wav")
    trim = ("silenceremove=start_periods=1:start_threshold=-42dB:start_silence=0.02,"
            "areverse,silenceremove=start_periods=1:start_threshold=-48dB:start_silence=0.08,areverse")
    if maxdur:
        trim = "atrim=0:%.2f,%s,afade=t=out:st=%.2f:d=0.12" % (maxdur, trim, max(0.0, maxdur - 0.4))
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", src, "-af", trim, "-ac", "2", "-ar", "44100", tmp], check=True)
    mean, peak = volume(tmp)
    if mean is None:
        subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", src, "-ac", "2", "-ar", "44100", tmp], check=True)
        mean, peak = volume(tmp)
    if mean is None:
        print("[FAIL] %s sem sinal" % name)
        return None
    gain = min(TARGET_MEAN_DB - mean, PEAK_CEIL_DB + 6.0 - peak)
    out = os.path.join(OUT_DIR, name + ".mp3")
    for _ in range(4):
        subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", tmp, "-af",
                        "volume=%.2fdB,alimiter=limit=0.42:attack=4:release=60:level=0" % gain,
                        "-codec:a", "libmp3lame", "-b:a", "128k", out], check=True)
        m2, p2 = volume(out)
        if p2 is not None and p2 <= PEAK_CEIL_DB + 0.4:
            break
        gain -= 1.5
    os.remove(tmp)
    print("[ok] %s dur=%.2fs mean=%.1fdB peak=%.1fdB" % (out, duration(out), m2, p2))
    return out


def layer(name):
    parts = LAYER[name]
    os.makedirs(RAW_DIR, exist_ok=True)
    inputs, chains, names = [], [], []
    for i, (file, delay, pitch, gain) in enumerate(parts):
        inputs += ["-i", os.path.join(ROOT, "audio", "sfx", file)]
        chains.append("[%d]aformat=sample_rates=44100:channel_layouts=stereo,asetrate=44100*%.3f,aresample=44100,volume=%.2f,adelay=%d|%d[a%d]"
                      % (i, pitch, gain, int(delay * 1000), int(delay * 1000), i))
        names.append("[a%d]" % i)
    graph = ";".join(chains) + ";" + "".join(names) + "amix=inputs=%d:normalize=0:dropout_transition=0[out]" % len(parts)
    raw = os.path.join(RAW_DIR, name + "_layer.wav")
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y"] + inputs + ["-filter_complex", graph, "-map", "[out]", raw], check=True)
    out = finish(raw, name, maxdur=2.5)
    os.remove(raw)
    return out


def measure():
    rows = []
    for f in sorted(os.listdir(OUT_DIR)):
        if f.endswith(".mp3"):
            p = os.path.join(OUT_DIR, f)
            m, pk = volume(p)
            rows.append((f, duration(p), m, pk))
    for f, d, m, pk in rows:
        print("%-32s %.2fs mean=%6.1fdB peak=%6.1fdB" % (f, d, m, pk))
    return rows


def envelope(path):
    out = subprocess.run(["ffmpeg", "-hide_banner", "-i", path, "-af",
                          "astats=metadata=1:reset=1:length=0.05,aspectralstats=win_size=2048:measure=centroid,ametadata=mode=print:file=-",
                          "-f", "null", "-"], capture_output=True, text=True).stdout
    t, frames, cur = 0.0, [], {}
    for line in out.splitlines():
        if line.startswith("frame:"):
            if cur:
                frames.append(cur)
            cur = {"t": float(line.split("pts_time:")[1])}
        elif "Overall.RMS_level=" in line:
            v = line.split("=")[1]
            cur["rms"] = float(v) if v not in ("-inf", "inf", "nan") else -99.0
        elif ".centroid=" in line and "1.centroid" in line:
            cur["c"] = float(line.split("=")[1])
    if cur:
        frames.append(cur)
    rms = [f.get("rms", -99.0) for f in frames]
    if not rms:
        return None
    top = max(rms)
    onset = next((f["t"] for f in frames if f.get("rms", -99) >= top - 20), 0.0)
    tpeak = next((f["t"] for f in frames if f.get("rms", -99) >= top), 0.0)
    cs = sorted(f["c"] for f in frames if "c" in f and f.get("rms", -99) >= top - 25)
    cen = cs[len(cs) // 2] if cs else 0.0
    tail = next((f["t"] for f in reversed(frames) if f.get("rms", -99) >= top - 20), 0.0)
    return onset, tpeak, tail, cen


def tonal(names):
    print("%-28s %6s %6s %6s %6s" % ("arquivo", "flatMd", "tonal%", "entrMd", "cenCV"))
    rows = []
    for n in names:
        path = os.path.join(OUT_DIR, n + ".mp3")
        out = subprocess.run(["ffmpeg", "-hide_banner", "-i", path, "-af",
                              "astats=metadata=1:reset=1:length=0.05,aspectralstats=win_size=2048:measure=flatness+entropy+centroid,ametadata=mode=print:file=-",
                              "-f", "null", "-"], capture_output=True, text=True).stdout
        frames, cur = [], {}
        for line in out.splitlines():
            if line.startswith("frame:"):
                if cur:
                    frames.append(cur)
                cur = {}
            elif "Overall.RMS_level=" in line:
                v = line.split("=")[1]
                cur["rms"] = float(v) if v not in ("-inf", "inf", "nan") else -99.0
            elif "1.flatness=" in line:
                cur["f"] = float(line.split("=")[1])
            elif "1.entropy=" in line:
                cur["e"] = float(line.split("=")[1])
            elif "1.centroid=" in line:
                cur["c"] = float(line.split("=")[1])
        if cur:
            frames.append(cur)
        top = max((f.get("rms", -99) for f in frames), default=-99)
        loud = [f for f in frames if f.get("rms", -99) >= top - 18 and "f" in f]
        if not loud:
            continue
        fl = sorted(f["f"] for f in loud)
        en = sorted(f.get("e", 0) for f in loud)
        cs = [f.get("c", 0) for f in loud]
        mean_c = sum(cs) / len(cs)
        cv = (sum((c - mean_c) ** 2 for c in cs) / len(cs)) ** 0.5 / max(1.0, mean_c)
        tonal_frac = sum(1 for f in loud if f["f"] < 0.02) / len(loud)
        rows.append((n, fl[len(fl) // 2], tonal_frac, en[len(en) // 2], cv))
    rows.sort(key=lambda r: (-r[2], r[1]))
    for n, fm, tf, em, cv in rows:
        print("%-28s %6.3f %6.0f %6.3f %6.2f" % (n, fm, tf * 100, em, cv))


def report(names):
    print("%-28s %5s %6s %6s | %5s %6s %6s | %5s %5s %5s %6s" % ("arquivo", "raw_s", "rawMn", "rawPk", "out_s", "mean", "peak", "onset", "pico", "cauda", "centr"))
    for n in names:
        raw = os.path.join(RAW_DIR, n + ".mp3")
        out = os.path.join(OUT_DIR, n + ".mp3")
        if not os.path.exists(out):
            print("%-28s AUSENTE" % n)
            continue
        rd, (rm, rp) = (duration(raw), volume(raw)) if os.path.exists(raw) else (0.0, (0.0, 0.0))
        od, (om, op) = duration(out), volume(out)
        env = envelope(out) or (0, 0, 0, 0)
        print("%-28s %5.2f %6.1f %6.1f | %5.2f %6.1f %6.1f | %5.2f %5.2f %5.2f %6.0f" % (n, rd, rm or 0, rp or 0, od, om or 0, op or 0, env[0], env[1], env[2], env[3]))


def main(argv):
    cmd = argv[1] if len(argv) > 1 else "measure"
    if cmd == "balance":
        balance()
    elif cmd == "gen":
        names = argv[2:] or ORDER
        for n in names:
            raw = generate(n)
            if raw:
                finish(raw, n, maxdur=GEN[n][0] + 0.3)
    elif cmd == "post":
        for n in argv[2:]:
            finish(os.path.join(RAW_DIR, n + ".mp3"), n, maxdur=GEN[n][0] + 0.3)
    elif cmd == "layer":
        names = argv[2:] or list(LAYER.keys())
        for n in names:
            layer(n)
    elif cmd == "measure":
        measure()
    elif cmd == "tonal":
        tonal(argv[2:] or sorted(f[:-4] for f in os.listdir(OUT_DIR) if f.endswith(".mp3")))
    elif cmd == "report":
        report(argv[2:] or sorted(f[:-4] for f in os.listdir(OUT_DIR) if f.endswith(".mp3")))
    else:
        print("[FAIL] comando desconhecido: " + cmd)
        sys.exit(1)


if __name__ == "__main__":
    main(sys.argv)
