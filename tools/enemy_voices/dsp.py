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


def centroid(x, floor_db=-40):
    n, hop = 2048, 512
    if len(x) < n:
        x = np.pad(x, (0, n - len(x)))
    win = np.hanning(n)
    freqs = np.fft.rfftfreq(n, 1 / SR)
    num, den = 0.0, 0.0
    frames = [x[i:i + n] for i in range(0, len(x) - n + 1, hop)]
    rms = np.array([np.sqrt(np.mean(f ** 2)) for f in frames])
    thr = rms.max() * 10 ** (floor_db / 20)
    for f, r in zip(frames, rms):
        if r < thr:
            continue
        mag = np.abs(np.fft.rfft(f * win)) ** 2
        num += np.sum(freqs * mag)
        den += np.sum(mag)
    return num / den if den > 0 else 0.0


def f0_track(x, fmin=55, fmax=2000, frame=0.04, hop=0.01, thresh=0.55):
    n, h = int(frame * SR), int(hop * SR)
    lo, hi = int(SR / fmax), int(SR / fmin)
    y = signal.sosfilt(signal.butter(2, 3000 / (SR / 2), output="sos"), x)
    e = env(x, hop)
    pk = e.max() + 1e-12
    out = []
    for k, i in enumerate(range(0, len(y) - n - hi, h)):
        f = y[i:i + n + hi]
        if k < len(e) and e[k] < pk * 0.15:
            out.append(0.0)
            continue
        a = f[:n] - f[:n].mean()
        best, lag = 0.0, 0
        den0 = np.sqrt(np.sum(a * a)) + 1e-12
        for L in range(lo, hi):
            b = f[L:L + n] - f[L:L + n].mean()
            c = np.sum(a * b) / (den0 * (np.sqrt(np.sum(b * b)) + 1e-12))
            if c > best:
                best, lag = c, L
        out.append(SR / lag if best >= thresh and lag else 0.0)
    return np.array(out)


def max_rise(x, minrun=6):
    f = f0_track(x, thresh=0.7)
    runs, cur = [], []
    for v in f:
        if v > 0 and (not cur or 0.85 < v / cur[-1] < 1.18):
            cur.append(v)
        else:
            if len(cur) >= minrun:
                runs.append(cur)
            cur = [v] if v > 0 else []
    if len(cur) >= minrun:
        runs.append(cur)
    worst = 1.0
    for r in runs:
        s = signal.medfilt(np.array(r), 5)[2:-2]
        if len(s) < 2:
            continue
        lowest = s[0]
        for v in s[1:]:
            worst = max(worst, v / lowest)
            lowest = min(lowest, v)
    return worst
