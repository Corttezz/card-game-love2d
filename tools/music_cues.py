#!/usr/bin/env python3
import argparse
import os
import subprocess
import sys

import numpy as np
from scipy.signal import butter, sosfiltfilt
from scipy.ndimage import uniform_filter1d, maximum_filter1d, minimum_filter1d

SR = 12000
HOP = 120
FPS = SR // HOP

LOW_BAND = (20.0, 150.0)
HIT_MIN_GAP = 0.35
HIT_WINDOW = 2.0
HIT_PER_WINDOW = 2
HIT_MIN_POWER = 0.30
HIT_NEAR_DROP = 0.35
SWELL_SPAN = 2.5
SWELL_RISE_DB = 6.0
SWELL_MIN_DUR = 1.5
DROP_GAP = 12.0
DROP_RISE_DB = 7.0

MUSIC_DIR = os.path.join("audio", "music")
OUT_DIR = os.path.join("src", "data", "music_cues")
PREVIEW_DIR = os.path.join("tools", "preview_out", "musica_reativa")
GENERIC_BOSS_FILES = ("music-boss.mp3", "music-boss-eclipse.mp3")


def decode(path):
    cmd = ["ffmpeg", "-v", "error", "-i", path, "-ac", "1", "-ar", str(SR),
           "-f", "f32le", "-"]
    raw = subprocess.run(cmd, check=True, capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.float32).astype(np.float64)


def frame_energy(x):
    n = len(x) // HOP
    fr = x[: n * HOP].reshape(n, HOP)
    e = (fr * fr).mean(axis=1)
    return uniform_filter1d(e, 4, mode="nearest")


def to_db(e):
    return 10.0 * np.log10(e + 1e-10)


def pct_rank(v, ref):
    s = np.sort(ref)
    return np.searchsorted(s, v) / max(1, len(s))


def find_hits(low_db, full_db):
    n = len(low_db)
    lag = 3
    on = np.zeros(n)
    on[lag:] = np.maximum(0.0, low_db[lag:] - low_db[:-lag])
    local = maximum_filter1d(on, size=21, mode="nearest")
    base = uniform_filter1d(on, size=3 * FPS, mode="nearest")
    level_ref = np.percentile(low_db, 98)
    loud_floor = np.percentile(low_db, 45)
    cands = []
    for t in range(max(lag, FPS // 4), n - 6):
        if on[t] <= 0 or on[t] < local[t]:
            continue
        if on[t] < base[t] * 2.2 + 1.5:
            continue
        peak_lvl = low_db[t:t + 6].max()
        if peak_lvl < loud_floor:
            continue
        cands.append((t, on[t], peak_lvl))
    if not cands:
        return [], on
    ons = np.array([c[1] for c in cands])
    o_ref = np.percentile(ons, 95)
    out = []
    for t, o, lvl in cands:
        o_n = min(1.0, o / max(1e-6, o_ref))
        l_n = float(np.clip((lvl - (level_ref - 18.0)) / 18.0, 0.0, 1.0))
        power = float(np.sqrt(o_n * l_n))
        out.append({"f": t, "t": t / FPS, "kind": "hit", "power": power, "score": o_n * l_n})
    return out, on


def select_hits(cands, drops):
    keep = []
    for c in sorted(cands, key=lambda c: -c["score"]):
        if c["power"] < HIT_MIN_POWER:
            continue
        t = c["t"]
        if any(abs(t - d["t"]) < HIT_NEAR_DROP for d in drops):
            continue
        if any(abs(t - k["t"]) < HIT_MIN_GAP for k in keep):
            continue
        near = sorted([k["t"] for k in keep if abs(t - k["t"]) < HIT_WINDOW] + [t])
        if any(near[i + HIT_PER_WINDOW] - near[i] < HIT_WINDOW
               for i in range(len(near) - HIT_PER_WINDOW)):
            continue
        keep.append(c)
    keep.sort(key=lambda c: c["t"])
    return keep


def find_swells(full_db):
    smooth = uniform_filter1d(full_db, size=FPS, mode="nearest")
    span = int(SWELL_SPAN * FPS)
    n = len(smooth)
    rise = np.full(n, -99.0)
    rise[: n - span] = smooth[span:] - smooth[: n - span]
    slope = np.diff(smooth, prepend=smooth[0])
    on = rise >= SWELL_RISE_DB
    swells = []
    t = 0
    while t < n:
        if not on[t]:
            t += 1
            continue
        s = t
        while t < n and on[t]:
            t += 1
        e = min(n - 1, t + span)
        top = s + int(np.argmax(smooth[s:e + 1]))
        seg = slope[s:top + 1]
        mono = float((seg > 0).mean()) if len(seg) else 0.0
        dur = (top - s) / FPS
        gain = smooth[top] - smooth[s]
        if dur >= SWELL_MIN_DUR and mono >= 0.6:
            swells.append({"f": s, "t": s / FPS, "kind": "swell",
                           "power": float(min(1.0, gain / 15.0)), "dur": float(dur)})
        t = max(t, top)
    return swells


def find_drops(full_db, full_on, low_db):
    n = len(full_db)
    fast = uniform_filter1d(full_db, size=FPS // 4, mode="nearest")
    fast_low = uniform_filter1d(low_db[:n], size=FPS // 4, mode="nearest")
    long_w = 4 * FPS
    before_w = int(1.5 * FPS)
    after_w = int(0.8 * FPS)
    loud = np.percentile(fast, 60)
    cands = []
    for t in range(before_w, n - after_w):
        after = fast[t:t + after_w].mean()
        if after < loud:
            continue
        before = fast[t - before_w:t - FPS // 10].mean()
        dip = fast[t - before_w:t].min()
        jump = after - before
        if jump < DROP_RISE_DB:
            continue
        lb = fast_low[max(0, t - long_w):t - FPS // 10].mean()
        la = fast_low[t:t + after_w].mean()
        score = jump + 0.5 * max(0.0, la - lb)
        cands.append((t, jump, score))
    out = []
    for t, jump, score in sorted(cands, key=lambda c: -c[2]):
        if any(abs(t / FPS - d["t"]) < DROP_GAP for d in out):
            continue
        lo = max(0, t - FPS // 5)
        hi = min(n, t + FPS // 5)
        snap = lo + int(np.argmax(full_on[lo:hi] + 0.5 * np.maximum(0, np.diff(low_db[lo:hi + 1]))))
        out.append({"f": snap, "t": snap / FPS, "kind": "drop",
                    "power": float(min(1.0, 0.55 + (jump - DROP_RISE_DB) / 20.0)),
                    "jump": float(jump)})
    out.sort(key=lambda c: c["t"])
    return out


def full_onset(full_db):
    lag = 3
    on = np.zeros(len(full_db))
    on[lag:] = np.maximum(0.0, full_db[lag:] - full_db[:-lag])
    return on


def lua_number(v):
    s = "%.3f" % v
    s = s.rstrip("0").rstrip(".")
    return s if s not in ("", "-0") else "0"


def write_lua(path, track, duration, cues):
    lines = ["return {"]
    lines.append('    track = "%s",' % track)
    lines.append("    duration = %s," % lua_number(duration))
    lines.append("    cues = {")
    for c in cues:
        extra = ""
        if c["kind"] == "swell":
            extra = ", dur = %s" % lua_number(c["dur"])
        lines.append('        { t = %s, kind = "%s", power = %s%s },'
                     % (lua_number(c["t"]), c["kind"], lua_number(round(c["power"], 2)), extra))
    lines.append("    },")
    lines.append("}")
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(lines) + "\n")


def plot(path, x, low_db, cues, t0=0.0, t1=None, width=2400, height=520):
    from PIL import Image, ImageDraw
    dur = len(x) / SR
    if t1 is None:
        t1 = dur
    img = Image.new("RGB", (width, height), (18, 16, 22))
    d = ImageDraw.Draw(img)
    wave_top, wave_h = 60, 220
    low_top, low_h = 300, 180
    s0, s1 = int(t0 * SR), int(t1 * SR)
    seg = x[s0:s1]
    per = max(1, len(seg) // width)
    peak = np.abs(seg[: per * width].reshape(-1, per)).max(axis=1) if len(seg) >= width else np.abs(seg)
    gmax = max(1e-6, float(np.abs(x).max()))
    for i, p in enumerate(peak[:width]):
        h = int(p / gmax * wave_h / 2)
        cy = wave_top + wave_h // 2
        d.line([(i, cy - h), (i, cy + h)], fill=(110, 110, 130))
    f0, f1 = int(t0 * FPS), int(t1 * FPS)
    ld = low_db[f0:f1]
    lo, hi = np.percentile(low_db, 5), low_db.max()
    pts = []
    for i in range(width):
        k = min(len(ld) - 1, int(i / width * len(ld)))
        v = (ld[k] - lo) / max(1e-6, hi - lo)
        pts.append((i, low_top + low_h - int(np.clip(v, 0, 1) * low_h)))
    d.line(pts, fill=(90, 200, 120), width=2)
    for i in range(int(np.ceil(t0)), int(t1) + 1):
        xx = int((i - t0) / (t1 - t0) * width)
        col = (60, 60, 70) if i % 5 else (110, 110, 120)
        d.line([(xx, height - 20), (xx, height - (12 if i % 5 else 4))], fill=col)
        if i % 5 == 0:
            d.text((xx + 2, height - 18), "%ds" % i, fill=(150, 150, 160))
    for c in cues:
        if c["t"] < t0 or c["t"] > t1:
            continue
        xx = int((c["t"] - t0) / (t1 - t0) * width)
        if c["kind"] == "hit":
            h = int(20 + c["power"] * 30)
            d.line([(xx, 4), (xx, 4 + h)], fill=(230, 70, 60), width=3)
            d.line([(xx, low_top), (xx, low_top + low_h)], fill=(120, 40, 40), width=1)
        elif c["kind"] == "drop":
            d.line([(xx, 0), (xx, height - 24)], fill=(250, 210, 60), width=4)
            d.text((xx + 4, 40), "DROP", fill=(250, 210, 60))
        elif c["kind"] == "swell":
            x2 = int((c["t"] + c["dur"] - t0) / (t1 - t0) * width)
            d.rectangle([(xx, 52), (x2, 58)], fill=(80, 140, 250))
    d.text((6, 20), "%s   hits(red) swells(blue) drops(yellow)   green = low band 20-150 Hz dB"
           % os.path.basename(path), fill=(220, 220, 230))
    img.save(path)


def measure(low_db, hits):
    if not hits:
        return 0.0, 0.0, 0.0
    on_peak = 0
    lvl_hits = []
    for h in hits:
        f = h["f"]
        lo, hi = max(0, f - 2), min(len(low_db), f + 10)
        win = low_db[lo:hi]
        p = lo + int(np.argmax(win))
        wide = low_db[max(0, f - 20):min(len(low_db), f + 25)]
        if low_db[p] >= wide.max() - 1.0:
            on_peak += 1
        lvl_hits.append(low_db[p])
    rank = float(np.mean([pct_rank(v, low_db) for v in lvl_hits]))
    return on_peak / len(hits), rank, float(np.mean(lvl_hits) - np.median(low_db))


def analyze(track_id, path, write=True, png=True):
    x = decode(path)
    duration = len(x) / SR
    sos = butter(4, LOW_BAND, btype="bandpass", fs=SR, output="sos")
    low = sosfiltfilt(sos, x)
    low_db = to_db(frame_energy(low))
    full_db = to_db(frame_energy(x))
    n = min(len(low_db), len(full_db))
    low_db, full_db = low_db[:n], full_db[:n]
    hit_cands, _ = find_hits(low_db, full_db)
    f_on = full_onset(full_db)
    drops = find_drops(full_db, f_on, low_db)
    hits = select_hits(hit_cands, drops)
    swells = find_swells(full_db)
    cues = sorted(hits + swells + drops, key=lambda c: c["t"])
    out_path = os.path.join(OUT_DIR, track_id + ".lua")
    if write:
        os.makedirs(OUT_DIR, exist_ok=True)
        write_lua(out_path, os.path.basename(path), duration, cues)
    on_peak, rank, above = measure(low_db, hits)
    gaps = np.diff([h["t"] for h in hits]) if len(hits) > 1 else np.array([99.0])
    print("%s: %.1fs | hit %d swell %d drop %d | hits/s %.2f | gap min %.2fs | "
          "hit no pico grave %.0f%% | nivel grave no hit pct %.0f (+%.1f dB sobre a mediana)"
          % (track_id, duration, len(hits), len(swells), len(drops),
             len(hits) / duration, float(gaps.min()), on_peak * 100, rank * 100, above))
    if write:
        print("  -> " + out_path)
    if png:
        os.makedirs(PREVIEW_DIR, exist_ok=True)
        p = os.path.join(PREVIEW_DIR, "cues_%s.png" % track_id)
        plot(p, x, low_db, cues)
        print("  -> " + p)
        if drops:
            t = drops[0]["t"]
            pz = os.path.join(PREVIEW_DIR, "cues_%s_drop.png" % track_id)
            plot(pz, x, low_db, cues, max(0.0, t - 6.0), min(duration, t + 6.0), width=1600)
            print("  -> " + pz)
    return cues


def boss_tracks():
    out = []
    if not os.path.isdir(MUSIC_DIR):
        return out
    for name in sorted(os.listdir(MUSIC_DIR)):
        if name.startswith("boss-") and name.endswith(".mp3"):
            out.append((name[len("boss-"):-len(".mp3")], os.path.join(MUSIC_DIR, name)))
        elif name in GENERIC_BOSS_FILES:
            out.append((name[:-len(".mp3")].replace("-", "_"), os.path.join(MUSIC_DIR, name)))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("ids", nargs="*")
    ap.add_argument("--no-png", action="store_true")
    ap.add_argument("--dry", action="store_true")
    ap.add_argument("--drop-db", type=float, default=None)
    a = ap.parse_args()
    if a.drop_db is not None:
        global DROP_RISE_DB
        DROP_RISE_DB = a.drop_db
    tracks = boss_tracks()
    if a.ids:
        tracks = [t for t in tracks if t[0] in a.ids]
    if not tracks:
        print("[FAIL] nenhuma faixa boss-<id>.mp3 em " + MUSIC_DIR)
        return 1
    for tid, path in tracks:
        analyze(tid, path, write=not a.dry, png=not a.no_png)
    return 0


if __name__ == "__main__":
    sys.exit(main())
