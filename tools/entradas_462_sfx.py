import os
import shutil
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_entrance_sfx as G

ROOT = G.ROOT
ENT = os.path.join(ROOT, "audio", "sfx", "entrances")
BACKUP = os.path.join(ROOT, "tools", "preview_out", "entradas_som", "antes_462")

RECIPES = {
    "blight_bull_charge": dict(maxdur=1.4, parts=[
        ("ent:blight_bull_charge", 0.00, 0.88, 1.0, "anull"),
    ]),
    "blight_bull_skid": dict(maxdur=0.7, parts=[
        ("ent:blight_bull_charge", 0.00, 0.80, 1.0, "atrim=0.42:0.80,asetpts=PTS-STARTPTS"),
        ("ent:blight_bull_skid", 0.04, 0.85, 0.55, "lowpass=f=3500"),
    ]),
    "hellhound_charge": dict(maxdur=1.2, parts=[
        ("ent:hellhound_charge", 0.00, 0.95, 1.0, "anull"),
    ]),
    "hellhound_skid": dict(maxdur=0.6, parts=[
        ("ent:hellhound_charge", 0.00, 0.92, 1.0, "atrim=0.25:0.55,asetpts=PTS-STARTPTS"),
        ("ent:hellhound_skid", 0.05, 0.90, 0.50, "lowpass=f=3500"),
    ]),
    "dullahan_step": dict(maxdur=0.75, parts=[
        ("ent:glacier_knight_step", 0.00, 0.85, 1.0, "lowpass=f=4500"),
        ("ent:obsidian_sentinel_stop", 0.00, 0.90, 0.55, "anull"),
        ("aud:punching-light-armour-87442.mp3", 0.04, 0.85, 0.35, "highpass=f=300"),
    ]),
}


def src(tag):
    kind, name = tag.split(":", 1)
    if kind == "ent":
        p = os.path.join(BACKUP, name + ".mp3")
        return p if os.path.exists(p) else os.path.join(ENT, name + ".mp3")
    if kind == "sfx":
        return os.path.join(ROOT, "audio", "sfx", name)
    return os.path.join(ROOT, "audio", name)


def build(name):
    os.makedirs(BACKUP, exist_ok=True)
    os.makedirs(G.RAW_DIR, exist_ok=True)
    cur = os.path.join(ENT, name + ".mp3")
    keep = os.path.join(BACKUP, name + ".mp3")
    if os.path.exists(cur) and not os.path.exists(keep):
        shutil.copyfile(cur, keep)
    r = RECIPES[name]
    inputs, chains, outs = [], [], []
    for i, (tag, delay, pitch, gain, flt) in enumerate(r["parts"]):
        inputs += ["-i", src(tag)]
        ms = int(delay * 1000)
        chains.append("[%d]aformat=sample_rates=44100:channel_layouts=stereo,asetrate=44100*%.3f,aresample=44100,%s,"
                      "volume=%.2f,adelay=%d|%d[a%d]" % (i, pitch, flt, gain, ms, ms, i))
        outs.append("[a%d]" % i)
    graph = ";".join(chains) + ";" + "".join(outs) + "amix=inputs=%d:normalize=0:dropout_transition=0[out]" % len(outs)
    raw = os.path.join(G.RAW_DIR, name + "_462.wav")
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y"] + inputs +
                   ["-filter_complex", graph, "-map", "[out]", raw], check=True)
    G.finish(raw, name, maxdur=r["maxdur"])
    os.remove(raw)


if __name__ == "__main__":
    for n in sys.argv[1:] or list(RECIPES):
        build(n)
