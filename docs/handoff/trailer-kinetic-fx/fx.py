# fx.py: shared by the compose.py of A, B and C.
# JokerPatch hides the combat HUD's joker strip (face jokers) with a clean frame of the same still camera, gain-matched on a
# band around the mask (the HUD dims the scene) and feathered. lift() raises dark screens by an adaptive gamma until the
# screen mean reaches TARGET (criterion 2), screen pixels only, never inside the CRT bezel.
import os, numpy as np, cv2
HERE = os.path.dirname(os.path.abspath(__file__))
TARGET = 0.062

class JokerPatch:
    def __init__(self, shot, W, H):
        m = cv2.imread(os.path.join(HERE, f'{shot}_mask.png'), cv2.IMREAD_GRAYSCALE)
        c = cv2.imread(os.path.join(HERE, f'{shot}_clean.png'))
        if W != 1920:
            m = cv2.resize(m, (W, H), interpolation=cv2.INTER_NEAREST); c = cv2.resize(c, (W, H), interpolation=cv2.INTER_NEAREST)
        s = W // 1920
        self.mask = m > 0
        ys, xs = np.where(self.mask)
        pad = 40 * s
        self.y0, self.y1, self.x0, self.x1 = max(0, ys.min() - pad), ys.max() + pad, max(0, xs.min() - pad), xs.max() + pad
        sl = (slice(self.y0, self.y1), slice(self.x0, self.x1))
        mk = self.mask[sl].astype(np.uint8)
        self.alpha = cv2.GaussianBlur(cv2.erode(mk, np.ones((5 * s, 5 * s), np.uint8)).astype(np.float32), (0, 0), 6 * s)[..., None]
        band = cv2.dilate(mk, np.ones((30 * s, 30 * s), np.uint8)) - cv2.dilate(mk, np.ones((8 * s, 8 * s), np.uint8))
        self.band = band > 0
        self.clean = c[sl].astype(np.float32)
        self.s = s
        self.sx0, self.sw = xs.max() + 12 * s, 36 * s

    def apply(self, f):
        sl = (slice(self.y0, self.y1), slice(self.x0, self.x1))
        cur = f[sl].astype(np.float32)
        a, b = cur[self.band], self.clean[self.band]
        ok = np.abs(a - b).max(axis=1) < 60
        if ok.sum() < 200: ok[:] = True
        g = np.clip(np.median(a[ok] + 1, axis=0) / np.median(b[ok] + 1, axis=0), 0.4, 1.6)
        ref = np.clip(self.clean * g, 0, 255)
        out = cur * (1 - self.alpha) + ref * self.alpha
        sx0 = self.sx0 - self.x0
        strip = slice(sx0, sx0 + self.sw)
        r = np.median((cur[:, strip] + 4) / (ref[:, strip] + 4), axis=1)
        rows = np.abs(r - 1).mean(axis=1) > 0.1
        if rows.sum() >= 6 * self.s:
            k = np.where(rows)[0]
            al = self.alpha[k, :sx0]
            out[k, :sx0] = np.clip(ref[k, :sx0] * r[k][:, None, :], 0, 255) * al + out[k, :sx0] * (1 - al)
        f = f.copy(); f[sl] = out.astype(np.uint8)
        return f

_luts = {}
def lut(g):
    k = round(g, 3)
    if k not in _luts: _luts[k] = np.clip(255 * (np.arange(256) / 255.0) ** k + 0.5, 0, 255).astype(np.uint8)
    return _luts[k]

def screen_mean(f, screen_small):
    g = cv2.cvtColor(cv2.resize(f, (480, 270), interpolation=cv2.INTER_AREA), cv2.COLOR_BGR2GRAY)
    return g, float(g[screen_small].mean()) / 255

def lift(f, screen_small):
    g, m = screen_mean(f, screen_small)
    if m >= TARGET: return f, 1.0, m
    lo, hi = 0.25, 1.0
    for _ in range(14):
        mid = (lo + hi) / 2
        if lut(mid)[g][screen_small].mean() / 255 >= TARGET: lo = mid
        else: hi = mid
    gam = round(lo, 3)
    return cv2.LUT(f, lut(gam)), gam, m
