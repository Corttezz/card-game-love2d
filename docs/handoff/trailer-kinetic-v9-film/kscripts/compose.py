# compose.py <film> --res 1080|4k [--fast] [--from F --to F] [--out path] [--frames f1,f2,..]
# The v8 clips laid out by the EDL (speeds, transitions, glitch, holds), the type layer from layer.py on top,
# the CRT bezel over every frame, a poster frame at frame 0, then the encoder (skill settings for masters).
import sys, os, json, math, argparse, subprocess, time
import numpy as np, cv2
R = r'E:\dev\projects\card-game-trailer'
ap = argparse.ArgumentParser(); ap.add_argument('film'); ap.add_argument('--res', default='1080', choices=['1080', '4k'])
ap.add_argument('--fast', action='store_true'); ap.add_argument('--from', dest='f0', type=int, default=0); ap.add_argument('--to', dest='f1', type=int)
ap.add_argument('--out'); ap.add_argument('--frames'); ap.add_argument('--png')
a = ap.parse_args()
TRIM, FPS, DUR = 0.5, 60, 64.5
POSTER = 204
total = round(DUR * FPS)
S = 2 if a.res == '4k' else 1
W, H = 1920 * S, 1080 * S
edl = json.load(open(os.path.join(R, 'build', 'trailer', 'kinetic', 'C_edl.json'), encoding='utf-8'))
ring = cv2.imread(os.path.join(R, 'build', 'trailer', 'brand', 'bezel_ring.png'))
mask = cv2.imread(os.path.join(R, 'build', 'trailer', 'brand', 'bezel_mask.png'), cv2.IMREAD_GRAYSCALE) == 255
if S == 2:
    ring = cv2.resize(ring, (W, H), interpolation=cv2.INTER_NEAREST)
    mask = cv2.resize(mask.astype(np.uint8), (W, H), interpolation=cv2.INTER_NEAREST).astype(bool)
proxy = os.path.join(a.film, 'out', 'proxy1080')

def src_path(p):
    full = os.path.join(R, p)
    if S == 2:
        return full
    os.makedirs(proxy, exist_ok=True)
    q = os.path.join(proxy, os.path.basename(p))
    if not os.path.exists(q):
        w, h = map(int, subprocess.run(['ffprobe', '-v', 'error', '-select_streams', 'v:0', '-show_entries', 'stream=width,height', '-of', 'csv=p=0', full], capture_output=True, text=True).stdout.strip().split(','))
        flt = 'scale=1920:1080:flags=neighbor' if 'clips_v8' in p and 'hall' not in p and w == 3840 else 'scale=1920:1080:flags=area'
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', full, '-vf', flt, '-c:v', 'libx264', '-crf', '8', '-preset', 'veryfast', '-an', q], check=True)
    return q

class Src:
    def __init__(self, p):
        self.p = src_path(p); self.cap = None; self.i = -1; self.f = None
        c = cv2.VideoCapture(self.p); self.fps = c.get(cv2.CAP_PROP_FPS); self.n = int(c.get(cv2.CAP_PROP_FRAME_COUNT)); c.release()
    def get(self, idx):
        idx = max(0, min(self.n - 1, idx))
        if idx == self.i: return self.f
        if self.cap is None or idx < self.i:
            if self.cap is not None: self.cap.release()
            self.cap = cv2.VideoCapture(self.p); self.i = -1
        while self.i < idx - 1:
            self.cap.grab(); self.i += 1
        ok, f = self.cap.read(); self.i += 1
        if not ok: raise RuntimeError(f'{self.p} frame {idx}')
        if f.shape[1] != W: f = cv2.resize(f, (W, H), interpolation=cv2.INTER_AREA if f.shape[1] > W else cv2.INTER_NEAREST)
        self.f = f
        return f
    def at(self, t):
        return self.get(int(math.floor(t * self.fps + 1e-6)))

clips = [c for c in edl['clips'] if 'src' in c]
glitch = next(c for c in edl['clips'] if c.get('kind') == 'glitch')
srcs = {}
def src(c):
    if c['src'] not in srcs: srcs[c['src']] = Src(c['src'])
    return srcs[c['src']]

def clip_frame(c, T):
    s = src(c)
    ct = c['in'] + (T - c['t0']) * c['speed']
    last = (s.n - 1) / s.fps
    ct = min(ct, c['out'] - 1 / s.fps, last)
    return s.at(max(0.0, ct))

B4 = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], np.float32) / 16
BLK = 4 * S
dither = np.tile(np.kron(B4, np.ones((BLK, BLK), np.float32)), (H // (4 * BLK) + 1, W // (4 * BLK) + 1))[:H, :W]

def step(u, fps=15, d=1.0):
    n = max(1, round(d * fps))
    return min(1.0, math.floor(u * n + 1e-6) / n)

def bands(img, amt, seed, chroma):
    out = img.copy()
    rng = np.random.default_rng(seed)
    bh = 8 * S
    for y in range(0, H, bh):
        if rng.random() < 0.45:
            dx = int(rng.integers(-1, 2) * amt * S * rng.random())
            out[y:y + bh] = np.roll(img[y:y + bh], dx, axis=1)
    if chroma:
        c = int(chroma * S)
        out[..., 2] = np.roll(out[..., 2], c, axis=1); out[..., 0] = np.roll(out[..., 0], -c, axis=1)
    return out

def zoom(img, z):
    if z <= 1.0001: return img
    M = cv2.getRotationMatrix2D((W / 2, H / 2), 0, z)
    return cv2.warpAffine(img, M, (W, H), flags=cv2.INTER_NEAREST, borderMode=cv2.BORDER_REPLICATE)

def plate(T):
    if glitch['t0'] <= T < glitch['t1']:
        u = (T - glitch['t0']) / (glitch['t1'] - glitch['t0'])
        luta = next(c for c in clips if c['id'] == 'luta_guerreiro')
        f = clip_frame(luta, luta['t1'] - 1e-3)
        g = bands(f, 64 * (1 - u * .3), int(T * 60), 10 + 6 * u)
        return (g.astype(np.float32) * (1 - .75 * step(u, d=glitch['t1'] - glitch['t0']))).astype(np.uint8)
    i = max(k for k, c in enumerate(clips) if c['t0'] <= T + 1e-9) if T >= clips[0]['t0'] else 0
    c = clips[i]
    f = clip_frame(c, T)
    tr = c.get('tr')
    if tr and i > 0 and T < c['t0'] + tr['d']:
        u = (T - c['t0']) / tr['d']
        if tr['type'] == 'dissolve':
            prev = clip_frame(clips[i - 1], T)
            f = cv2.addWeighted(f, u, prev, 1 - u, 0)
        elif tr['type'] == 'flash':
            v = .55 * (1 - step(u, d=tr['d']))
            f = (f.astype(np.float32) + (255 - f.astype(np.float32)) * v).astype(np.uint8)
        elif tr['type'] == 'zoom':
            f = zoom(f, 1 + .06 * (1 - step(u, d=tr['d'])))
        elif tr['type'] == 'glitch_soft':
            v = 1 - step(u, d=tr['d'])
            f = bands(f, 24 * v, int(T * 60), 6 * v)
    return f

layer_dir = os.path.join(a.film, 'out', 'layer')
def compose(k):
    kk = POSTER if k == 0 else k
    T = kk / FPS + TRIM
    f = plate(T).copy()
    lp = os.path.join(layer_dir, f'f_{kk:05d}.png')
    if os.path.exists(lp):
        L = cv2.imread(lp, cv2.IMREAD_UNCHANGED)
        if S == 2: L = cv2.resize(L, (W, H), interpolation=cv2.INTER_NEAREST)
        m = L[..., 3] > 127
        f[m] = L[..., :3][m]
    f[mask] = ring[mask]
    return f

if a.frames:
    os.makedirs(a.png, exist_ok=True)
    for k in map(int, a.frames.split(',')):
        cv2.imwrite(os.path.join(a.png, f'k{k:05d}_t{k / FPS:06.2f}.png'), compose(k))
    sys.exit(0)

f1 = a.f1 or total
out = a.out or os.path.join(a.film, 'out', f'video_{a.res}.mp4')
os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
if a.fast:
    enc = ['-c:v', 'libx264', '-crf', '16', '-preset', 'veryfast']
else:
    enc = ['-c:v', 'libx264', '-crf', '12.4', '-preset', 'slower', '-level', '5.2' if S == 2 else '4.2', '-rc-lookahead', '40', '-threads', '8']
ff = subprocess.Popen(['ffmpeg', '-v', 'error', '-y', '-f', 'rawvideo', '-pix_fmt', 'bgr24', '-s', f'{W}x{H}', '-r', str(FPS), '-i', '-', *enc,
                       '-pix_fmt', 'yuv420p', '-color_primaries', 'bt709', '-color_trc', 'bt709', '-colorspace', 'bt709', '-movflags', '+faststart', out], stdin=subprocess.PIPE)
st = time.time()
for k in range(a.f0, f1):
    ff.stdin.write(compose(k).tobytes())
    if (k - a.f0) % 300 == 0: print(f'frame {k} {time.time() - st:.0f}s', flush=True)
ff.stdin.close(); ff.wait()
print(f'{out}: {f1 - a.f0} frames in {time.time() - st:.0f}s')
