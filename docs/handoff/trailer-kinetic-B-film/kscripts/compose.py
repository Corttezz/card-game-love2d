# compose.py <film> --res 1080|4k [--fast] [--from F --to F] [--out path] [--frames f1,f2 --png dir]
# Concept B: the 1080p TGA takes (proxied to lossless-ish mp4 once) time-remapped by the EDL `map`, the 4K halls and the logo,
# a CRT power-on synthesized over the first shot, transitions, the type layer from layer.py, the bezel over every frame.
import sys, os, json, math, argparse, subprocess, time
import numpy as np, cv2
sys.path.insert(0, r'E:\dev\_orquestracao\skills-externas\kinetic-film\patches')
import fx
R = r'E:\dev\projects\card-game-trailer'
ap = argparse.ArgumentParser(); ap.add_argument('film'); ap.add_argument('--res', default='1080', choices=['1080', '4k'])
ap.add_argument('--fast', action='store_true'); ap.add_argument('--from', dest='f0', type=int, default=0); ap.add_argument('--to', dest='f1', type=int)
ap.add_argument('--out'); ap.add_argument('--frames'); ap.add_argument('--png')
a = ap.parse_args()
edl = json.load(open(os.path.join(R, 'build', 'trailer', 'kinetic', 'B_edl.json'), encoding='utf-8'))
FPS, DUR = 60, edl['output']['duration']
POSTER = round(edl['poster_frame_t'] * FPS)
total = round(DUR * FPS)
S = 2 if a.res == '4k' else 1
W, H = 1920 * S, 1080 * S
ring = cv2.imread(os.path.join(R, 'build', 'trailer', 'brand', 'bezel_ring.png'))
mask = cv2.imread(os.path.join(R, 'build', 'trailer', 'brand', 'bezel_mask.png'), cv2.IMREAD_GRAYSCALE) == 255
if S == 2:
    ring = cv2.resize(ring, (W, H), interpolation=cv2.INTER_NEAREST)
    mask = cv2.resize(mask.astype(np.uint8), (W, H), interpolation=cv2.INTER_NEAREST).astype(bool)
proxy = os.path.join(a.film, 'out', 'proxy')
screen_small = cv2.resize((~mask).astype(np.uint8), (480, 270), interpolation=cv2.INTER_NEAREST) > 0
PATCH_FROM = {'deck8': 585, 'boss8': 1200}
patches = {k: fx.JokerPatch(k, W, H) for k in PATCH_FROM}
lift_log = []
os.makedirs(proxy, exist_ok=True)

def take_proxy(shot, f0, f1):
    q = os.path.join(proxy, f'{shot}_{f0}_{f1}.mp4')
    if not os.path.exists(q):
        src = os.path.join(edl['takes'], shot, '%05d.tga')
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-start_number', str(f0), '-framerate', '60', '-i', src, '-frames:v', str(f1 - f0 + 1),
                        '-c:v', 'libx264', '-crf', '4', '-preset', 'veryfast', '-pix_fmt', 'yuv444p', q], check=True)
    return q

def mp4_proxy(p):
    full = os.path.join(R, p)
    if S == 2: return full
    q = os.path.join(proxy, os.path.basename(p))
    if not os.path.exists(q):
        w = int(subprocess.run(['ffprobe', '-v', 'error', '-select_streams', 'v:0', '-show_entries', 'stream=width', '-of', 'csv=p=0', full], capture_output=True, text=True).stdout)
        flt = 'scale=1920:1080:flags=area' if w > 1920 else 'null'
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', full, '-vf', flt, '-c:v', 'libx264', '-crf', '8', '-preset', 'veryfast', '-an', q], check=True)
    return q

class Src:
    def __init__(self, p, base=0):
        self.p = p; self.base = base; self.cap = None; self.i = -1; self.f = None
        c = cv2.VideoCapture(p); self.fps = c.get(cv2.CAP_PROP_FPS); self.n = int(c.get(cv2.CAP_PROP_FRAME_COUNT)); c.release()
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

clips = [c for c in edl['clips'] if 'src' in c]
glitch = next(c for c in edl['clips'] if c.get('kind') == 'glitch')
srcs = {}
for c in clips:
    if c['src'].startswith('take:'):
        fr = [f for _, f in c['map']]
        f0, f1 = max(1, int(min(fr)) - 2), int(max(fr)) + 3
        c['_src'] = Src(take_proxy(c['src'][5:], f0, f1)); c['_base'] = f0
    else:
        p = mp4_proxy(c['src'])
        if p not in srcs: srcs[p] = Src(p)
        c['_src'] = srcs[p]

def clip_frame(c, T):
    s = c['_src']
    if 'map' in c:
        m = c['map']
        T = min(max(T, m[0][0]), m[-1][0])
        for (ta, fa), (tb, fb) in zip(m, m[1:]):
            if T <= tb + 1e-9:
                f = fa + (fb - fa) * (T - ta) / (tb - ta)
                break
        fi = int(math.floor(f + 1e-6))
        img = s.get(fi - c['_base'])
        shot = c['src'][5:]
        if shot in PATCH_FROM and fi >= PATCH_FROM[shot]:
            img = patches[shot].apply(img)
        return img
    ct = c['in'] + (T - c['t0']) * c['speed']
    ct = min(ct, c['out'] - 1 / s.fps, (s.n - 1) / s.fps)
    return s.get(int(math.floor(max(0.0, ct) * s.fps + 1e-6)))

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

def bright(img, k):
    return np.clip(img.astype(np.float32) * k, 0, 255).astype(np.uint8)

def tv_on(img, T):
    t0, t1 = edl['tv_on']['t0'], edl['tv_on']['t1']
    u = step((T - t0) / (t1 - t0), d=t1 - t0)
    out = np.zeros_like(img)
    cy = H // 2
    if u < 0.2:
        w = int(W * 0.9 * (u + 1 / 15) / 0.2)
        out[cy - S:cy + S, (W - w) // 2:(W + w) // 2] = 235
        return out
    if u < 0.5:
        h = max(2 * S, int(H * (u - 0.2) / 0.3))
        sq = cv2.resize(img, (W, h), interpolation=cv2.INTER_AREA)
        out[cy - h // 2:cy - h // 2 + h] = bright(sq, 1.8 - (u - 0.2) * 1.5)
        return out
    return bright(img, 1.0 + 0.5 * (1 - (u - 0.5) / 0.5))

def plate(T):
    if glitch['t0'] <= T < glitch['t1']:
        u = (T - glitch['t0']) / (glitch['t1'] - glitch['t0'])
        luta = next(c for c in clips if c['id'] == 'luta_guerreiro')
        f = clip_frame(luta, luta['t1'] - 1e-3)
        g = bands(f, 64 * (1 - u * .3), int(T * 60), 10 + 6 * u)
        return bright(g, 1 - .75 * step(u, d=glitch['t1'] - glitch['t0']))
    i = max(k for k, c in enumerate(clips) if c['t0'] <= T + 1e-9)
    c = clips[i]
    f = clip_frame(c, T)
    tr = c.get('tr')
    if tr and i > 0 and T < c['t0'] + tr['d']:
        u = (T - c['t0']) / tr['d']
        if tr['type'] == 'dissolve':
            f = cv2.addWeighted(f, u, clip_frame(clips[i - 1], T), 1 - u, 0)
        elif tr['type'] == 'flash':
            v = .55 * (1 - step(u, d=tr['d']))
            f = (f.astype(np.float32) + (255 - f.astype(np.float32)) * v).astype(np.uint8)
        elif tr['type'] == 'zoom':
            f = zoom(f, 1 + .06 * (1 - step(u, d=tr['d'])))
        elif tr['type'] == 'glitch_soft':
            v = 1 - step(u, d=tr['d'])
            f = bands(f, 24 * v, int(T * 60), 6 * v)
    if edl['tv_on']['t0'] <= T < edl['tv_on']['t1'] and edl['tv_on'].get('synth', True):
        f = tv_on(f, T)
    return f

layer_dir = os.path.join(a.film, 'out', 'layer')
def compose(k):
    kk = POSTER if k == 0 else k
    T = kk / FPS
    f = plate(T).copy()
    if not (edl['tv_on']['t0'] <= T < edl['tv_on']['t1'] and edl['tv_on'].get('synth', True)) and not (glitch['t0'] <= T < glitch['t1']):
        f, gam, m0 = fx.lift(f, screen_small)
        if gam < 1: lift_log.append((round(T, 3), round(m0, 4), gam))
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
json.dump(lift_log, open(os.path.join(a.film, 'out', f'lift_{a.res}.json'), 'w'))
print(f'{out}: {f1 - a.f0} frames in {time.time() - st:.0f}s; lifted {len(lift_log)} frames, min gamma {min([g for _, _, g in lift_log], default=1)}')
