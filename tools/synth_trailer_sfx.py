import json
import os
import sys
import wave

import numpy as np
from scipy.signal import butter, lfilter, sosfilt

SR = 48000
DEFAULT_OUT = r"E:\dev\projects\card-game-trailer\build\trailer\sfx_synth"


def rng(seed):
    return np.random.default_rng(seed)


def t_axis(dur):
    return np.arange(int(SR * dur)) / SR


def env_ad(n, attack, decay_tau):
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    return a * np.exp(-np.maximum(t - attack, 0) / decay_tau)


def band(x, lo, hi, order=4):
    sos = butter(order, [lo, hi], btype="bandpass", fs=SR, output="sos")
    return sosfilt(sos, x)


def lowpass(x, fc, order=4):
    return sosfilt(butter(order, fc, btype="lowpass", fs=SR, output="sos"), x)


def highpass(x, fc, order=4):
    return sosfilt(butter(order, fc, btype="highpass", fs=SR, output="sos"), x)


def sweep_sine(f0, f1, dur, curve=3.0):
    t = t_axis(dur)
    f = f1 + (f0 - f1) * np.exp(-t * curve)
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def reverb(x, size=1.0, mix=0.25, damp=3500):
    combs = [1557, 1617, 1491, 1422, 1277, 1356]
    gains = [0.80, 0.79, 0.78, 0.77, 0.76, 0.75]
    wet = np.zeros(len(x))
    for d, g in zip(combs, gains):
        d = int(d * size * SR / 44100)
        a = np.zeros(d + 1)
        a[0], a[-1] = 1.0, -g
        wet += lfilter([1.0], a, x)
    for d in (225, 556, 441):
        d = int(d * SR / 44100)
        b = np.zeros(d + 1); b[0], b[-1] = -0.5, 1.0
        a = np.zeros(d + 1); a[0], a[-1] = 1.0, -0.5
        wet = lfilter(b, a, wet)
    wet = lowpass(wet, damp, 2) / len(combs)
    return x * (1 - mix) + wet * mix


def pad(x, secs):
    return np.concatenate([x, np.zeros(int(SR * secs))])


def stereo(x, width=0.0, seed=0):
    if width <= 0:
        return np.stack([x, x], axis=1)
    d = int(SR * 0.011 * width)
    r = np.concatenate([np.zeros(d), x[:-d]]) if d else x
    return np.stack([x * (1 - 0.15 * width) + r * 0.15 * width, r * (1 - 0.15 * width) + x * 0.15 * width], axis=1)


def norm(x, peak_db=-1.0):
    p = np.max(np.abs(x))
    return x if p == 0 else x * (10 ** (peak_db / 20) / p)


def fade_out(x, secs):
    n = min(len(x), int(SR * secs))
    x = x.copy()
    x[-n:] *= np.linspace(1, 0, n) ** 2
    return x


def write(path, x):
    if x.ndim == 1:
        x = stereo(x)
    data = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def tv_on():
    r = rng(11)
    n = int(SR * 1.6)
    t = np.arange(n) / SR
    click = band(r.standard_normal(n), 800, 6000) * env_ad(n, 0.0005, 0.012) * 1.2
    thunk = sweep_sine(180, 55, 1.6, 9.0) * env_ad(n, 0.002, 0.09) * 0.9
    hum_f = 50 + 6 * np.exp(-t * 3)
    degauss = np.sin(2 * np.pi * np.cumsum(hum_f) / SR) * (0.5 + 0.5 * np.sin(2 * np.pi * 7 * t)) * env_ad(n, 0.04, 0.45) * 0.55
    whine = np.sin(2 * np.pi * 15625 * t) * np.clip((t - 0.05) / 0.25, 0, 1) * np.exp(-np.maximum(t - 0.3, 0) / 0.5) * 0.035
    crackle = np.zeros(n)
    for k in r.choice(int(SR * 0.9), 70, replace=False):
        crackle[k + int(SR * 0.02)] = r.uniform(-1, 1)
    crackle = band(crackle, 1500, 9000, 2) * 6 * np.exp(-t / 0.35)
    blip = np.sin(2 * np.pi * 1240 * t) * env_ad(n, 0.001, 0.035) * 0.25
    x = click + thunk + degauss + whine + crackle + blip
    return stereo(norm(fade_out(reverb(x, 0.6, 0.12), 0.2), -1.0), 0.4), {"hit": 0.0}


def impact(seed, f0=140, f1=38, body=0.22, bright=1.0):
    r = rng(seed)
    dur = 1.1
    n = int(SR * dur)
    sub = sweep_sine(f0, f1, dur, 14.0) * env_ad(n, 0.001, body)
    crack = band(r.standard_normal(n), 900, 7000) * env_ad(n, 0.0004, 0.018) * 0.9 * bright
    thud = lowpass(r.standard_normal(n), 400) * env_ad(n, 0.001, 0.06) * 1.6
    x = np.tanh((sub * 1.4 + crack + thud) * 1.8)
    x = reverb(x, 0.8, 0.18, 2500)
    return stereo(norm(fade_out(x, 0.3), -1.0), 0.3), {"hit": 0.0}


def whoosh(seed, dur=0.9, rise=0.62):
    r = rng(seed)
    n = int(SR * dur)
    t = np.arange(n) / SR
    noise = r.standard_normal(n)
    pos = t / dur
    amp = np.where(pos < rise, (pos / rise) ** 2.2, np.exp(-(pos - rise) / 0.09))
    out = np.zeros(n)
    blk = 512
    centers = 250 + 3800 * np.where(pos < rise, pos / rise, 1 - (pos - rise) / (1 - rise) * 0.6)
    for i in range(0, n, blk):
        c = centers[min(i + blk // 2, n - 1)]
        seg = noise[max(0, i - 2048):i + blk]
        y = band(seg, c * 0.6, min(c * 1.6, SR / 2 - 100), 2)
        out[i:i + blk] = y[-len(noise[i:i + blk]):]
    x = out * amp
    pan = np.clip(pos * 1.2, 0, 1)
    st = np.stack([x * np.cos(pan * np.pi / 2) * 1.2 + x * 0.3, x * np.sin(pan * np.pi / 2) * 1.2 + x * 0.3], axis=1)
    return norm(st, -2.0), {"hit": round(rise * dur, 3)}


def castle_door():
    r = rng(23)
    creak_dur, slam_at, total = 2.6, 2.75, 5.2
    n = int(SR * total)
    t = np.arange(n) / SR
    creak = np.zeros(n)
    pos = 0.0
    while pos < creak_dur:
        prog = pos / creak_dur
        rate = 26 + 34 * np.sin(np.pi * prog) + r.normal(0, 6)
        k = int(SR * pos)
        creak[k] = r.uniform(0.6, 1.0) * (0.4 + 0.6 * np.sin(np.pi * min(prog * 1.15, 1)))
        pos += 1.0 / max(rate, 8)
    res = band(creak, 140, 320, 2) * 1.0 + band(creak, 420, 700, 2) * 0.6 + band(creak, 900, 1300, 2) * 0.25
    groan = sweep_sine(62, 48, total, 0.4) * 0.25 * np.clip(t / 0.4, 0, 1) * np.clip((creak_dur + 0.1 - t) / 0.3, 0, 1)
    creak_sig = (res * 5 + groan) * (t < creak_dur + 0.2)
    m = int(SR * (total - slam_at))
    slam = np.zeros(n)
    s_sub = sweep_sine(85, 32, total - slam_at, 6.0) * env_ad(m, 0.002, 0.45) * 1.3
    s_body = lowpass(r.standard_normal(m), 260) * env_ad(m, 0.001, 0.12) * 2.2
    s_wood = band(r.standard_normal(m), 300, 2400) * env_ad(m, 0.0005, 0.04) * 0.6
    chain = band(r.standard_normal(m), 3000, 9000, 2) * env_ad(m, 0.05, 0.25) * 0.08
    slam[int(SR * slam_at):] = np.tanh((s_sub + s_body + s_wood + chain) * 1.5)
    x = reverb(creak_sig * 1.1 + slam, 1.35, 0.32, 1800)
    return stereo(norm(fade_out(x, 0.8), -1.0), 0.6), {"hit": slam_at, "creak_start": 0.0}


def logo_seal():
    r = rng(31)
    dur = 3.4
    n = int(SR * dur)
    t = np.arange(n) / SR
    thump = sweep_sine(110, 42, dur, 10.0) * env_ad(n, 0.001, 0.28) * 1.0
    bell = np.zeros(n)
    for ratio, amp, tau in ((1.0, 0.5, 1.6), (2.76, 0.28, 0.9), (5.40, 0.16, 0.5), (8.93, 0.08, 0.3)):
        f = 220 * ratio
        mod = np.sin(2 * np.pi * f * 1.41 * t) * 2.0 * np.exp(-t / 0.15)
        bell += np.sin(2 * np.pi * f * t + mod) * amp * env_ad(n, 0.002, tau)
    shimmer = band(r.standard_normal(n), 5000, 11000, 2) * env_ad(n, 0.15, 0.6) * 0.12
    shimmer *= 0.6 + 0.4 * np.sin(2 * np.pi * 9 * t)
    x = np.tanh(thump * 1.3) + bell * 0.7 + shimmer
    return stereo(norm(fade_out(reverb(x, 1.2, 0.3, 4500), 0.6), -1.0), 0.7), {"hit": 0.0}


def glitch(seed=41, dur=0.55):
    r = rng(seed)
    n = int(SR * dur)
    x = np.zeros(n)
    i = 0
    while i < n:
        L = int(SR * r.uniform(0.012, 0.06))
        kind = r.integers(0, 4)
        seg_t = np.arange(L) / SR
        if kind == 0:
            seg = np.sign(np.sin(2 * np.pi * r.uniform(90, 1800) * seg_t)) * 0.6
        elif kind == 1:
            hold = int(r.integers(8, 90))
            seg = np.repeat(r.uniform(-1, 1, L // hold + 1), hold)[:L] * 0.8
        elif kind == 2:
            seg = np.zeros(L)
        else:
            seg = np.sin(2 * np.pi * r.uniform(2000, 6000) * seg_t) * 0.4 + r.standard_normal(L) * 0.2
        x[i:i + L] = seg[: n - i]
        i += L
    x = np.round(x * 12) / 12
    x = highpass(x, 60, 2)
    return stereo(norm(fade_out(x, 0.05), -3.0), 0.8), {"hit": 0.0}


def build(out):
    os.makedirs(out, exist_ok=True)
    items = {
        "tv_on": tv_on(),
        "impact_1": impact(51),
        "impact_2": impact(52, 160, 44, 0.18, 1.2),
        "impact_heavy": impact(53, 120, 30, 0.42, 0.7),
        "whoosh_1": whoosh(61),
        "whoosh_2": whoosh(62, 0.65, 0.55),
        "castle_door": castle_door(),
        "logo_seal": logo_seal(),
        "glitch": glitch(),
    }
    manifest = {"sr": SR, "origin": "tools/synth_trailer_sfx.py, sintese local numpy/scipy, sem amostra externa", "files": {}}
    for name, (x, meta) in items.items():
        p = os.path.join(out, name + ".wav")
        write(p, x)
        manifest["files"][name + ".wav"] = {"dur": round(len(x) / SR, 3), **meta}
        print("[ok] %s %.2fs" % (p, len(x) / SR))
    with open(os.path.join(out, "manifest.json"), "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=1)
    print("[ok] %s" % os.path.join(out, "manifest.json"))


if __name__ == "__main__":
    build(sys.argv[1] if len(sys.argv) > 1 else DEFAULT_OUT)
