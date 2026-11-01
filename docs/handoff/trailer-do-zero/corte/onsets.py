import os, json, subprocess
import numpy as np

SR = 48000
HOP = 240


def load_mono(path, start=0.0, dur=None):
    cmd = ['ffmpeg', '-v', 'error', '-ss', str(start), '-i', path]
    if dur:
        cmd += ['-t', str(dur)]
    cmd += ['-f', 'f32le', '-ac', '1', '-ar', str(SR), '-']
    return np.frombuffer(subprocess.run(cmd, capture_output=True, check=True).stdout, np.float32)


def flux(x):
    n = 2048
    win = np.hanning(n).astype(np.float32)
    frames = (len(x) - n) // HOP
    out = np.zeros(frames, np.float32)
    prev = None
    f = np.fft.rfftfreq(n, 1 / SR)
    band = (f >= 30) & (f <= 2500)
    for i in range(frames):
        s = np.abs(np.fft.rfft(x[i * HOP:i * HOP + n] * win))[band]
        d = 20 * np.log10(s + 1e-6)
        if prev is not None:
            out[i] = np.maximum(d - prev, 0).mean()
        prev = d
    return out


def onset_curve(path, film_offset, film_dur):
    x = load_mono(path, max(0.0, film_offset), film_dur)
    fl = flux(x)
    t = np.arange(len(fl)) * HOP / SR + 1024 / SR
    return t, fl


def best(t, fl, center, win=0.45):
    m = (t >= center - win) & (t <= center + win)
    if not m.any():
        return center, 0.0
    i = np.flatnonzero(m)[np.argmax(fl[m])]
    return round(float(t[i]), 3), float(fl[i])


def strength_at(t, fl, center, w=0.03):
    m = (t >= center - w) & (t <= center + w)
    return float(fl[m].max()) if m.any() else 0.0
