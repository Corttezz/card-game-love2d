import subprocess, sys, numpy as np

def load(path, sr=22050):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-ac", "1", "-ar", str(sr), "-f", "f32le", "-"], capture_output=True).stdout
    return np.frombuffer(raw, np.float32), sr

def flux(x, sr, hop=256, n=2048, band=None):
    w = np.hanning(n)
    frames = np.lib.stride_tricks.sliding_window_view(x, n)[::hop] * w
    S = np.abs(np.fft.rfft(frames, axis=1))
    f = np.fft.rfftfreq(n, 1 / sr)
    if band:
        S = S[:, (f >= band[0]) & (f < band[1])]
    L = np.log1p(S * 10)
    d = np.maximum(L[1:] - L[:-1], 0).sum(1)
    d = np.concatenate([[0], d])
    t = (np.arange(len(d)) * hop + n / 2) / sr
    return t, d

def peaks(t, d, win=0.07):
    hop = t[1] - t[0]
    k = max(1, int(win / hop))
    out = []
    med = np.convolve(d, np.ones(int(1.0 / hop)) / int(1.0 / hop), mode="same") + 1e-9
    for i in range(k, len(d) - k):
        if d[i] == d[i - k:i + k + 1].max():
            out.append((t[i], d[i] / med[i]))
    return out

music, p0, cuts = sys.argv[1], float(sys.argv[2]), [float(c) for c in sys.argv[3].split()]
x, sr = load(music)
t, d = flux(x, sr)
tb, db = flux(x, sr, band=(20, 150))
P = peaks(t, d)
pt = np.array([p[0] for p in P]); ps = np.array([p[1] for p in P])
for c in cuts:
    tt = c - 12.6 + p0
    i = np.argmin(abs(pt - tt))
    near = (abs(pt - tt) < 1.0)
    rank = (ps[near] > ps[i]).sum() + 1
    bi = np.argmin(abs(tb - pt[i]))
    bass = db[bi] / (np.median(db[max(0, bi - 90):bi + 90]) + 1e-9)
    print("cut %7.3f  nearest onset off %+6.1f ms  strength %5.1fx  rank %d/%d in +-1s  bass %4.1fx" % (c, (pt[i] - tt) * 1000, ps[i], rank, near.sum(), bass))
