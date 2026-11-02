import os, sys, subprocess, json, math
import numpy as np, cv2
from PIL import Image, ImageDraw, ImageFont
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib
E = importlib.import_module(os.environ.get('TDZ_EDL', 'edl'))

W, H, FPS = 1920, 1080, E.FPS
WORK = os.path.join(E.OUT, 'work')
RED = (226, 52, 44, 255)
FONT = r'E:\dev\projects\card-game-trailer-zero\assets\fonts\pixel.ttf'
LOGO = os.path.join(E.R, 'build', 'trailer', 'brand', 'logo_final.png')
ENC = ['-c:v', 'libx264', '-preset', 'veryfast', '-crf', '10', '-pix_fmt', 'yuv444p', '-r', str(FPS)]
PARCH = (244, 230, 200, 255)
GOLD = (232, 184, 80, 255)
INK = (22, 14, 20, 255)
CARD_BOX = (728, 178, 1216, 912)


def nframes(c):
    return int(round(c['t1'] * FPS)) - int(round(c['t0'] * FPS))


def run(cmd):
    subprocess.run(cmd, check=True)


def render_take(c, out):
    n = nframes(c)
    hold = c.get('hold', 0)
    vf = []
    if c['z'] == 3:
        x, y = c['crop']
        vf.append(f'crop=640:360:{x}:{y}')
        vf.append('scale=1920:1080:flags=neighbor')
    if c['z'] == 2:
        x, y = c['crop']
        if c.get('pan'):
            n0, v = c['pan']
            vf.append(f"crop=960:540:{x}:'min(540,{y}+max(0,n-{n0})*{v})'")
        else:
            vf.append(f'crop=960:540:{x}:{y}')
        vf.append('scale=1920:1080:flags=neighbor')
    if hold:
        vf.append(f'tpad=start={hold}:start_mode=clone')
    run(['ffmpeg', '-v', 'error', '-y', '-ss', f"{c['s0']:.4f}", '-i', E.take_path(c['src']), '-vf', ','.join(vf) if vf else 'null',
         '-frames:v', str(n), '-an'] + ENC + [out])


def hall_frames(spec, s0, n):
    import importlib.util
    _, ai, real = spec.split(':')
    realp = os.path.join(E.REAL, real + '.png')
    cap = cv2.VideoCapture(os.path.join(E.AI, ai + '.mp4'))
    cap.set(cv2.CAP_PROP_POS_MSEC, s0 * 1000)
    frames = []
    while len(frames) < n:
        ok, f = cap.read()
        if not ok:
            frames.append(frames[-1]); continue
        frames.append(f)
    return frames, cv2.imread(realp)


def treat_halls(frames, real, kr=0.80, k=0.30):
    Hh, Ww = real.shape[:2]; gh = round(Ww * 9 / 16); y0 = (Hh - gh) // 2
    GW, GH = getattr(E, 'HALL_GRID', (Ww, gh))
    lr = cv2.cvtColor(real[y0:y0 + gh], cv2.COLOR_BGR2LAB).astype(np.float32)
    P = [0.5, 2, 10, 25, 50, 75, 90, 98, 99.5]
    dst = np.percentile(lr[..., 0], P)
    first = cv2.resize(frames[0], (GW, GH), interpolation=cv2.INTER_AREA)
    ls0 = cv2.cvtColor(first, cv2.COLOR_BGR2LAB).astype(np.float32)
    src = np.percentile(ls0[..., 0], P); thr = np.percentile(ls0[..., 0], 97)
    emis0 = ls0[..., 0] > thr
    pal_src = np.concatenate([real.reshape(-1, 3), first[emis0].reshape(-1, 3)]).astype(np.float32)
    crit = (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 30, 0.5)
    _, _, pal = cv2.kmeans(pal_src, getattr(E, 'HALL_COLORS', 64), None, crit, 3, cv2.KMEANS_PP_CENTERS)
    out = []
    for f in frames:
        small = cv2.resize(f, (GW, GH), interpolation=cv2.INTER_AREA)
        ls = cv2.cvtColor(small, cv2.COLOR_BGR2LAB).astype(np.float32)
        emis = ls[..., 0] > thr
        L = np.interp(ls[..., 0], src, dst)
        L[emis] = np.maximum(L[emis], np.interp(ls[..., 0][emis], [src[-2], 255], [dst[-1], 255]))
        ca = ls[..., 1] - 128; cb = ls[..., 2] - 128
        kk = np.where(emis, 1.0, np.where(ca > 14, kr, k))
        lab = np.stack([L, 128 + ca * kk, 128 + cb * kk], -1)
        img = cv2.cvtColor(np.clip(lab, 0, 255).astype(np.uint8), cv2.COLOR_LAB2BGR).astype(np.float32)
        if getattr(E, 'HALL_CLEAN', False):
            img = cv2.bilateralFilter(img.astype(np.uint8), 5, 18, 3).astype(np.float32)
        d = ((img[:, :, None, :] - pal[None, None, :, :]) ** 2).sum(-1)
        q = pal[d.argmin(-1)].astype(np.uint8)
        if getattr(E, 'HALL_CLEAN', False):
            q2 = cv2.medianBlur(q, 3).astype(np.float32)
            d = ((q2[:, :, None, :] - pal[None, None, :, :]) ** 2).sum(-1)
            q = pal[d.argmin(-1)].astype(np.uint8)
        out.append(cv2.resize(q, (W, H), interpolation=cv2.INTER_NEAREST))
    return out


def apply_fx_from(c, src, out):
    fx = c['fx']
    cap = cv2.VideoCapture(src)
    frames = []
    while True:
        ok, f = cap.read()
        if not ok:
            break
        frames.append(f)
    cap.release()
    def idx(t):
        return int(round((t - c['t0']) * FPS))
    if 'number' in fx:
        txt, t, dur = fx['number']
        font = ImageFont.truetype(FONT, 192)
        k0, n = idx(t), int(round(dur * FPS))
        for i in range(n):
            if not 0 <= k0 + i < len(frames):
                continue
            im = Image.fromarray(cv2.cvtColor(frames[k0 + i], cv2.COLOR_BGR2RGB)).convert('RGBA')
            lay = Image.new('RGBA', im.size, (0, 0, 0, 0))
            d = ImageDraw.Draw(lay); d.fontmode = '1'
            bb = d.textbbox((0, 0), txt, font=font)
            x = (W - (bb[2] - bb[0])) // 2 // 8 * 8
            y = (getattr(E, 'NUMBER_Y', 96) - (i // 4) * 4) // 8 * 8
            for dx in (-16, 0, 16):
                for dy in (-16, 0, 16):
                    if dx or dy:
                        d.text((x + dx, y + dy + 8), txt, font=font, fill=INK)
            d.text((x, y), txt, font=font, fill=RED)
            a = 1.0 if i < n - 12 else max(0.0, (n - i) / 12)
            if a < 1:
                arr = np.array(lay); arr[..., 3] = (arr[..., 3] * a).astype(np.uint8); lay = Image.fromarray(arr)
            im.alpha_composite(lay)
            frames[k0 + i] = cv2.cvtColor(np.array(im.convert('RGB')), cv2.COLOR_RGB2BGR)
    if 'freeze' in fx:
        t, n = fx['freeze']
        k = idx(t)
        if 0 <= k < len(frames):
            L0 = len(frames)
            frames = frames[:k] + [frames[k]] * n + frames[k:]
            frames = frames[:L0]
    if 'freeze2' in fx:
        t, n = fx['freeze2']
        k = idx(t)
        if 0 <= k < len(frames):
            L0 = len(frames)
            frames = (frames[:k] + [frames[k]] * n + frames[k:])[:L0]
    if 'shake2' in fx:
        t, n, amp = fx['shake2']
        k0 = idx(t)
        for i in range(n):
            k = k0 + i
            if not 0 <= k < len(frames):
                continue
            a = amp * (1 - i / n)
            dy = int(round(a * (1 if i % 2 == 0 else -1) / 2)) * 2
            frames[k] = cv2.warpAffine(frames[k], np.float32([[1, 0, 0], [0, 1, dy]]), (W, H), flags=cv2.INTER_NEAREST, borderMode=cv2.BORDER_REPLICATE)
    if 'dust' in fx:
        t, n = fx['dust']
        k0 = idx(t)
        rng = np.random.default_rng(5)
        P = [(rng.uniform(760, 1780), rng.uniform(960, 1010), rng.uniform(-2.5, 2.5), rng.uniform(-3.2, -0.8), rng.integers(2, 4)) for _ in range(46)]
        for i in range(n):
            k = k0 + i
            if not 0 <= k < len(frames):
                continue
            a = 1 - i / n
            f = frames[k]
            for (x, y, vx, vy, sz) in P:
                px = int((x + vx * i) // 6 * 6); py = int((y + vy * i + 0.03 * i * i) // 6 * 6)
                s = int(sz) * 6
                if 0 <= px < W - s and 0 <= py < H - s:
                    roi = f[py:py + s, px:px + s].astype(np.float32)
                    f[py:py + s, px:px + s] = (roi * (1 - 0.7 * a) + np.array([150, 160, 170], np.float32) * 0.7 * a).astype(np.uint8)
    if 'zoom' in fx:
        z0, z1 = fx['zoom']
        n = len(frames)
        for i in range(n):
            z = z0 + (z1 - z0) * (i / max(1, n - 1))
            if z <= 1.0001:
                continue
            cw, ch = W / z, H / z
            x0, y0 = (W - cw) / 2, (H - ch) / 2
            big = cv2.resize(frames[i], (W * 4, H * 4), interpolation=cv2.INTER_NEAREST)
            sub = big[int(round(y0 * 4)):int(round((y0 + ch) * 4)), int(round(x0 * 4)):int(round((x0 + cw) * 4))]
            frames[i] = cv2.resize(sub, (W, H), interpolation=cv2.INTER_AREA)
    if 'lift' in fx:
        t, n, amt = fx['lift']
        k0 = idx(t)
        for i in range(n):
            k = k0 + i
            if not 0 <= k < len(frames):
                continue
            a = amt * (1 - i / n)
            f = frames[k].astype(np.float32)
            frames[k] = np.clip(f + a * (1 - f / 255.0), 0, 255).astype(np.uint8)
    if 'shake' in fx:
        t, n, amp = fx['shake']
        k0 = idx(t)
        for i in range(n):
            k = k0 + i
            if not 0 <= k < len(frames):
                continue
            a = amp * (1 - i / n)
            dx = int(round(a * (1 if i % 2 == 0 else -1) / 2)) * 2
            dy = int(round(a * 0.6 * (1 if i % 4 < 2 else -1) / 2)) * 2
            f = frames[k]
            frames[k] = cv2.warpAffine(f, np.float32([[1, 0, dx], [0, 1, dy]]), (W, H), flags=cv2.INTER_NEAREST, borderMode=cv2.BORDER_REPLICATE)
    if 'flash' in fx:
        t, n, alpha = fx['flash']
        k0 = idx(t)
        for i in range(n):
            k = k0 + i
            if not 0 <= k < len(frames):
                continue
            a = alpha * (1 - i / n)
            frames[k] = cv2.addWeighted(frames[k], 1 - a, np.full_like(frames[k], 255), a, 0)
    write_frames(frames, out)


def write_frames(frames, out):
    p = subprocess.Popen(['ffmpeg', '-v', 'error', '-y', '-f', 'rawvideo', '-pix_fmt', 'bgr24', '-s', f'{W}x{H}', '-r', str(FPS), '-i', '-']
                         + ENC + [out], stdin=subprocess.PIPE)
    for f in frames:
        p.stdin.write(np.ascontiguousarray(f).tobytes())
    p.stdin.close(); p.wait()


def text_layer(lines, y, gold, size=64, xc=None):
    font = ImageFont.truetype(FONT, size)
    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img); d.fontmode = '1'
    px = size // 8
    yy = y
    for i, line in enumerate(lines):
        bb = d.textbbox((0, 0), line, font=font)
        tw = bb[2] - bb[0]
        x = ((W - tw) // 2 if xc is None else int(xc - tw / 2)) // px * px
        col = GOLD if i in gold else PARCH
        for dx in (-px, 0, px):
            for dy in (-px, 0, px):
                if dx or dy:
                    d.text((x + dx, yy + dy + px), line, font=font, fill=INK)
        d.text((x, yy), line, font=font, fill=col)
        yy += int(size * 1.35)
    return img


def logo_segment(c, last_frame, out):
    n = nframes(c)
    L = E.LOGO
    logo = Image.open(LOGO).convert('RGBA')
    la = np.array(logo)
    seal = logo.crop((730, 90, 1195, 550))
    word = logo.crop((440, 570, 1485, 775))
    font = ImageFont.truetype(FONT, 40)
    font2 = ImageFont.truetype(FONT, 48)
    lf = cv2.cvtColor(last_frame, cv2.COLOR_BGR2RGB)
    card = Image.fromarray(lf).crop(CARD_BOX).convert('RGBA')
    cx, cy = (CARD_BOX[0] + CARD_BOX[2]) // 2, (CARD_BOX[1] + CARD_BOX[3]) // 2
    bgp = os.path.join(WORK, 'logo_bg.png')
    x0, y0 = 475, 165
    run(['ffmpeg', '-v', 'error', '-y', '-ss', f"{getattr(E, 'CARD_BG_T', 63.20):.2f}", '-i', E.take_path('zero_carrion'), '-vf',
         f'crop=960:540:{x0}:{y0},scale=1920:1080:flags=neighbor', '-frames:v', '1', bgp])
    bg = cv2.cvtColor(cv2.imread(bgp), cv2.COLOR_BGR2RGB)
    gray = (bg.astype(np.float32) * 0.28).astype(np.uint8)
    frames = []
    for i in range(n):
        t = c['t0'] + i / FPS
        a = min(1.0, max(0.0, (t - c['t0']) / 0.35))
        base = (bg.astype(np.float32) * (1 - a) + gray.astype(np.float32) * a).astype(np.uint8)
        if t < c['t0'] + 1.0 / FPS:
            base = lf
        im = Image.fromarray(base).convert('RGBA')
        if t < L['seal_at']:
            k = (t - c['t0']) / (L['seal_at'] - c['t0'])
            sx = max(0.02, abs(math.cos(k * math.pi / 2)))
            cw = max(2, int(card.width * sx) // 2 * 2)
            cc = card.resize((cw, card.height), Image.NEAREST)
            im.alpha_composite(cc, (cx - cw // 2, cy - card.height // 2))
        else:
            k = min(1.0, (t - L['seal_at']) / 0.35)
            sx = max(0.02, abs(math.sin(k * math.pi / 2)))
            m = min(1.0, (t - L['seal_at']) / 0.6)
            m = 1 - (1 - m) ** 3
            size = int(round(card.height * (1 - m) + seal.height * m))
            sw = max(2, int(size * seal.width / seal.height * sx) // 2 * 2)
            ss = seal.resize((sw, size), Image.NEAREST)
            px = int(round(cx * (1 - m) + 962 * m)); py = int(round(cy * (1 - m) + 320 * m))
            im.alpha_composite(ss, (px - sw // 2, py - size // 2))
            if t >= L['grimoire']:
                k2 = min(1.0, (t - L['grimoire']) / 0.5)
                cols = int(word.width * k2) // 8 * 8
                if cols > 0:
                    im.alpha_composite(word.crop((0, 0, cols, word.height)), (440, 570))
            d = ImageDraw.Draw(im); d.fontmode = '1'
            if t >= L['genre']:
                s = 'A ROGUELIKE DECKBUILDER'
                bb = d.textbbox((0, 0), s, font=font); x = (W - (bb[2] - bb[0])) // 2
                for dx, dy in ((-5, 0), (5, 0), (0, -5), (0, 5), (5, 5)):
                    d.text((x + dx, 815 + dy), s, font=font, fill=INK)
                d.text((x, 815), s, font=font, fill=PARCH)
            if t >= L['wishlist']:
                s = 'WISHLIST ON STEAM'
                bb = d.textbbox((0, 0), s, font=font2); x = (W - (bb[2] - bb[0])) // 2
                for dx, dy in ((-6, 0), (6, 0), (0, -6), (0, 6), (6, 6)):
                    d.text((x + dx, 905 + dy), s, font=font2, fill=INK)
                d.text((x, 905), s, font=font2, fill=GOLD)
        frames.append(cv2.cvtColor(np.array(im.convert('RGB')), cv2.COLOR_RGB2BGR))
    write_frames(frames, out)


def main():
    os.makedirs(WORK, exist_ok=True)
    only = set(sys.argv[1:])
    parts = []
    for c in E.CLIPS:
        out = os.path.join(WORK, f"c_{c['id']}.mp4")
        parts.append(out)
        if only and c['id'] not in only and os.path.exists(out):
            continue
        if c['src'].startswith('ai:'):
            fr, real = hall_frames(c['src'], c['s0'], nframes(c))
            write_frames(treat_halls(fr, real), out)
        elif c['src'] == 'logo':
            prev = [p for p in E.CLIPS if p['t1'] == c['t0']][0]
            pv = os.path.join(WORK, f"c_{prev['id']}.mp4")
            cap = cv2.VideoCapture(pv); cap.set(cv2.CAP_PROP_POS_FRAMES, nframes(prev) - 1); ok, lf = cap.read()
            logo_segment(c, lf, out)
        else:
            render_take(c, out)
            if c.get('fx'):
                tmp = out.replace('.mp4', '_fx.mp4')
                os.replace(out, tmp)
                cap = None
                apply_fx_from(c, tmp, out)
        print('[ok] clip', c['id'], nframes(c))
    lst = os.path.join(WORK, 'lista.txt')
    open(lst, 'w').write(''.join(f"file '{p}'\n" for p in parts))
    cat = os.path.join(WORK, 'montagem.mp4')
    run(['ffmpeg', '-v', 'error', '-y', '-f', 'concat', '-safe', '0', '-i', lst, '-c', 'copy', cat])
    inputs = ['-i', cat]; chain = []; last = '0:v'
    for i, tx in enumerate(E.TEXTS):
        p = os.path.join(WORK, f"t_{tx['id']}.png")
        st = tx.get('stagger')
        if st:
            a = text_layer(tx['lines'][:1], tx['y'], tx['gold'])
            b = text_layer(tx['lines'], tx['y'], tx['gold'])
            pa = p.replace('.png', '_a.png'); a.save(pa); b.save(p)
            inputs += ['-i', pa, '-i', p]
            ia = len(inputs) // 2 - 2; ib = ia + 1
            chain.append(f"[{last}][{ia}:v]overlay=enable='between(t,{tx['t0']},{tx['t0'] + st})'[v{i}a]")
            chain.append(f"[v{i}a][{ib}:v]overlay=enable='between(t,{tx['t0'] + st},{tx['t1']})'[v{i}]")
        else:
            text_layer(tx['lines'], tx['y'], tx['gold'], tx.get('size', 64), tx.get('xc')).save(p)
            inputs += ['-i', p]
            ia = len(inputs) // 2 - 1
            chain.append(f"[{last}][{ia}:v]overlay=enable='between(t,{tx['t0']},{tx['t1']})'[v{i}]")
        last = f'v{i}'
    final = os.path.join(E.OUT, 'zero_semcrt.mp4')
    run(['ffmpeg', '-v', 'error', '-y'] + inputs + ['-filter_complex', ';'.join(chain), '-map', f'[{last}]'] + ENC + [final])
    print('[ok] montagem sem CRT', final)


if __name__ == '__main__':
    main()
