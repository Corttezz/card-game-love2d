import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "audio", "sfx", "stingers")
RAW = os.path.join(ROOT, "tools", "stingers_src")
SFX = os.path.join(ROOT, "audio", "sfx")

PLAN = {
    "boss_pass": {"target": -14.0, "src": [("raw", "boss_pass.mp3", {})]},
    "player_death": {"target": -14.0, "src": [("raw", "player_death.mp3", {})]},
    "act_complete": {"target": -16.0, "src": [("raw", "act_complete.mp3", {})]},
    "miniboss_entrance": {"target": -14.5, "rise": 1.35,
                          "src": [("raw", "miniboss_entrance.mp3", {})]},
    "elite_entrance": {"target": -17.0, "src": [("raw", "miniboss_entrance.mp3", {"pitch": 0.88, "cut": 1.3})]},
    "victory_small": {"target": -18.5, "src": [("sfx", "boss/boss_death_thud.mp3", {"pitch": 1.12, "echo": True})]},
    "victory_elite": {"target": -16.5, "src": [("sfx", "boss/boss_death_thud.mp3", {"pitch": 0.94}),
                                               ("sfx", "act-complete.mp3", {"pitch": 0.84, "gain": -7, "delay": 0.12})]},
    "run_victory": {"target": -15.0, "src": [("raw", "boss_pass.mp3", {"pitch": 0.78, "echo": True}),
                                             ("raw", "act_complete.mp3", {"pitch": 0.84, "gain": -2, "delay": 2.7, "echo": True})]},
}


def ffmpeg(args):
    subprocess.run(["ffmpeg", "-v", "error", "-y"] + args, check=True)


def integrated(path):
    err = subprocess.run(["ffmpeg", "-nostats", "-i", path, "-af", "ebur128=peak=true", "-f", "null", "-"],
                         capture_output=True, text=True).stderr
    i = re.findall(r"I:\s+(-?[\d.]+) LUFS", err)
    p = re.findall(r"Peak:\s+(-?[\d.]+) dBFS", err)
    return float(i[-1]), float(p[-1])


def duration(path):
    out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", path],
                         capture_output=True, text=True).stdout.strip()
    return float(out)


def layer_filter(i, opts):
    f = []
    pitch = opts.get("pitch")
    if pitch:
        f.append(f"asetrate=44100*{pitch},aresample=44100")
    if opts.get("cut"):
        f.append(f"atrim=0:{opts['cut']},afade=t=out:st={opts['cut'] - 0.35}:d=0.35")
    if opts.get("echo"):
        f.append("aecho=0.8:0.6:180|420:0.35|0.2")
    if opts.get("gain"):
        f.append(f"volume={opts['gain']}dB")
    if opts.get("delay"):
        ms = int(opts["delay"] * 1000)
        f.append(f"adelay={ms}|{ms}")
    f.append("aformat=channel_layouts=stereo:sample_rates=44100")
    return f"[{i}:a]" + ",".join(f) + f"[l{i}]"


def build(name, spec, tmp):
    inputs, chains = [], []
    for i, (kind, rel, opts) in enumerate(spec["src"]):
        inputs += ["-i", os.path.join(RAW if kind == "raw" else SFX, rel)]
        chains.append(layer_filter(i, opts))
    n = len(spec["src"])
    mix = "".join(f"[l{i}]" for i in range(n))
    graph = ";".join(chains) + ";" + mix + (f"amix=inputs={n}:normalize=0:duration=longest" if n > 1 else "anull")
    if spec.get("rise"):
        r = spec["rise"]
        graph += f",asplit=2[m1][m2];[m2]atrim=0:{r},areverse,afade=t=in:st=0:d={r * 0.8},volume=-3dB[rv];[rv][m1]concat=n=2:v=0:a=1"
    graph += ",silenceremove=stop_periods=-1:stop_duration=0.25:stop_threshold=-55dB[o]"
    stage = os.path.join(tmp, name + "_a.wav")
    ffmpeg(inputs + ["-filter_complex", graph, "-map", "[o]", stage])
    d = duration(stage)
    fade = min(0.4, d * 0.2)
    stage2 = os.path.join(tmp, name + "_b.wav")
    ffmpeg(["-i", stage, "-af", f"afade=t=out:st={d - fade}:d={fade}", stage2])
    li, _ = integrated(stage2)
    gain = spec["target"] - li
    out = os.path.join(OUT, name + ".mp3")
    ffmpeg(["-i", stage2, "-af", f"volume={gain}dB,alimiter=limit=0.89:level=disabled",
            "-ar", "44100", "-b:a", "128k", out])
    fi, fp = integrated(out)
    return out, duration(out), fi, fp


def main():
    only = sys.argv[1:]
    os.makedirs(OUT, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        for name, spec in PLAN.items():
            if only and name not in only:
                continue
            out, d, i, p = build(name, spec, tmp)
            print(f"{os.path.relpath(out, ROOT)}\t{d:.2f}s\t{i:.1f} LUFS\tpeak {p:.1f} dBFS")


if __name__ == "__main__":
    main()
