import subprocess, numpy as np
from scipy import signal

SR = 44100


def load(path):
    p = subprocess.run(['ffmpeg', '-v', 'error', '-i', path, '-f', 'f32le', '-ac', '1', '-ar', str(SR), '-'],
                       capture_output=True)
    return np.frombuffer(p.stdout, dtype=np.float32).astype(np.float64)


def save_mp3(x, path):
    x = np.clip(x, -1, 1).astype(np.float32)
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 'f32le', '-ar', str(SR), '-ac', '1', '-i', '-',
                    '-c:a', 'libmp3lame', '-b:a', '128k', '-ar', str(SR), path], input=x.tobytes(), check=True)


def env(x, win=0.01):
    n = max(1, int(SR * win))
    m = len(x) // n
    if m == 0:
        return np.zeros(0)
    return np.sqrt(np.mean(x[:m * n].reshape(m, n) ** 2, axis=1))


def kweight(x):
    f0, G, Q = 1681.974450955533, 3.999843853973347, 0.7071752369554196
    K = np.tan(np.pi * f0 / SR)
    Vh = 10 ** (G / 20)
    Vb = Vh ** 0.4996667741545416
    a0 = 1 + K / Q + K * K
    b = [(Vh + Vb * K / Q + K * K) / a0, 2 * (K * K - Vh) / a0, (Vh - Vb * K / Q + K * K) / a0]
    a = [1, 2 * (K * K - 1) / a0, (1 - K / Q + K * K) / a0]
    y = signal.lfilter(b, a, x)
    f0, Q = 38.13547087602444, 0.5003270373238773
    K = np.tan(np.pi * f0 / SR)
    a0 = 1 + K / Q + K * K
    a = [1, 2 * (K * K - 1) / a0, (1 - K / Q + K * K) / a0]
    return signal.lfilter([1, -2, 1], a, y)


def lufs(x):
    y = kweight(x)
    blk = int(0.4 * SR)
    hop = int(0.1 * SR)
    if len(y) < blk:
        ms = np.mean(y ** 2)
        return -0.691 + 10 * np.log10(ms + 1e-12)
    pw = np.array([np.mean(y[i:i + blk] ** 2) for i in range(0, len(y) - blk + 1, hop)])
    l = -0.691 + 10 * np.log10(pw + 1e-12)
    pw = pw[l > -70]
    if len(pw) == 0:
        return -70.0
    rel = -0.691 + 10 * np.log10(np.mean(pw)) - 10
    l = -0.691 + 10 * np.log10(pw + 1e-12)
    pw2 = pw[l > rel]
    return -0.691 + 10 * np.log10(np.mean(pw2) + 1e-12)


def active_lufs(x, floor_db=-40):
    e = env(x, 0.01)
    if len(e) == 0:
        return -70.0
    pk = e.max()
    idx = np.where(e > pk * 10 ** (floor_db / 20))[0]
    a, b = idx[0] * int(SR * 0.01), (idx[-1] + 1) * int(SR * 0.01)
    return lufs(x[a:b])


def peak_db(x):
    return 20 * np.log10(np.max(np.abs(x)) + 1e-12)


def trim(x, thr_db=-45, pad=0.004):
    e = env(x, 0.002)
    if len(e) == 0 or e.max() <= 0:
        return x
    idx = np.where(e > e.max() * 10 ** (thr_db / 20))[0]
    a = max(0, idx[0] * int(SR * 0.002) - int(pad * SR))
    b = min(len(x), (idx[-1] + 1) * int(SR * 0.002) + int(pad * SR))
    return x[a:b]


def fade(x, fin=0.003, fout=0.03):
    x = x.copy()
    n1, n2 = min(len(x), int(fin * SR)), min(len(x), int(fout * SR))
    if n1 > 0:
        x[:n1] *= np.linspace(0, 1, n1)
    if n2 > 0:
        x[-n2:] *= np.linspace(1, 0, n2) ** 2
    return x


def resample(x, factor):
    if abs(factor - 1) < 1e-4:
        return x
    n = int(len(x) / factor)
    return signal.resample_poly(x, n, len(x)) if len(x) < 200000 else np.interp(np.linspace(0, len(x) - 1, n), np.arange(len(x)), x)


def pitch(x, factor):
    if abs(factor - 1) < 1e-4:
        return x
    from fractions import Fraction
    fr = Fraction(factor).limit_denominator(100)
    return signal.resample_poly(x, fr.denominator, fr.numerator)


def limit(x, ceil_db=-1.5):
    c = 10 ** (ceil_db / 20)
    pk = np.max(np.abs(x)) + 1e-12
    if pk <= c:
        return x
    y = np.tanh(x / c * 0.9) * c / np.tanh(0.9)
    return np.clip(y, -c, c)


def normalize(x, target_lufs, ceil_db=-1.5):
    l = active_lufs(x)
    g = 10 ** ((target_lufs - l) / 20)
    y = x * g
    for _ in range(3):
        y = limit(y, ceil_db)
        l2 = active_lufs(y)
        if abs(l2 - target_lufs) < 0.5:
            break
        y = y * 10 ** ((target_lufs - l2) / 20)
    return limit(y, ceil_db)


def events(x, min_gap=0.12, thr_db=-24, minlen=0.08):
    e = env(x, 0.005)
    pk = e.max()
    on = e > pk * 10 ** (thr_db / 20)
    segs, start, last = [], None, None
    for i, v in enumerate(on):
        t = i * 0.005
        if v:
            if start is None:
                start = t
            elif last is not None and t - last > min_gap:
                segs.append((start, last + 0.005))
                start = t
            last = t
    if start is not None:
        segs.append((start, last + 0.005))
    return [(a, b) for a, b in segs if b - a >= minlen]


def mix(*layers):
    n = max(len(l[1]) + int(l[0] * SR) for l in layers)
    out = np.zeros(n)
    for off, sig, g in layers:
        o = int(off * SR)
        out[o:o + len(sig)] += sig * g
    return out


def ascii_env(x, win=0.02):
    e = env(x, win)
    pk = e.max() + 1e-12
    return ''.join(' .:-=+*#%@'[min(9, int(9 * v / pk))] for v in e)
