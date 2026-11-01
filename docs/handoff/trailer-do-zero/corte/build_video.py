import os, sys, subprocess, json, math
import numpy as np, cv2
from PIL import Image, ImageDraw, ImageFont
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import edl as E

W, H, FPS = 1920, 1080, E.FPS
WORK = os.path.join(E.OUT, 'work')
FONT = r'E:\dev\projects\card-game-trailer-zero\assets\fonts\pixel.ttf'
LOGO = os.path.join(E.R, 'build', 'trailer', 'brand', 'logo_final.png')
ENC = ['-c:v', 'libx264', '-preset', 'veryfast', '-crf', '10', '-pix_fmt', 'yuv444p', '-r', str(FPS)]
PARCH = (244, 230, 200, 255)
GOLD = (232, 184, 80, 255)
INK = (22, 14, 20, 255)
CARD_BOX = (730, 175, 1210, 905)


def nframes(c):
    return int(round(c['t1'] * FPS)) - int(round(c['t0'] * FPS))


def run(cmd):
    subprocess.run(cmd, check=True)


def render_take(c, out):
    n = nframes(c)
    hold = c.get('hold', 0)
    vf = []
    if c['z'] == 2:
        x, y = c['crop']
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
    lr = cv2.cvtColor(real[y0:y0 + gh], cv2.COLOR_BGR2LAB).astype(np.float32)
    P = [0.5, 2, 10, 25, 50, 75, 90, 98, 99.5]
    dst = np.percentile(lr[..., 0], P)
    first = cv2.resize(frames[0], (Ww, gh), interpolation=cv2.INTER_AREA)
    ls0 = cv2.cvtColor(first, cv2.COLOR_BGR2LAB).astype(np.float32)
    src = np.percentile(ls0[..., 0], P); thr = np.percentile(ls0[..., 0], 97)
    emis0 = ls0[..., 0] > thr
    pal_src = np.concatenate([real.reshape(-1, 3), first[emis0].reshape(-1, 3)]).astype(np.float32)
    crit = (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 30, 0.5)
    _, _, pal = cv2.kmeans(pal_src, 64, None, crit, 3, cv2.KMEANS_PP_CENTERS)
    out = []
    for f in frames:
        small = cv2.resize(f, (Ww, gh), interpolation=cv2.INTER_AREA)
        ls = cv2.cvtColor(small, cv2.COLOR_BGR2LAB).astype(np.float32)
        emis = ls[..., 0] > thr
        L = np.interp(ls[..., 0], src, dst)
        L[emis] = np.maximum(L[emis], np.interp(ls[..., 0][emis], [src[-2], 255], [dst[-1], 255]))
        ca = ls[..., 1] - 128; cb = ls[..., 2] - 128
        kk = np.where(emis, 1.0, np.where(ca > 14, kr, k))
        lab = np.stack([L, 128 + ca * kk, 128 + cb * kk], -1)
        img = cv2.cvtColor(np.clip(lab, 0, 255).astype(np.uint8), cv2.COLOR_LAB2BGR).astype(np.float32)
        d = ((img[:, :, None, :] - pal[None, None, :, :]) ** 2).sum(-1)
        q = pal[d.argmin(-1)].astype(np.uint8)
        out.append(cv2.resize(q, (W, H), interpolation=cv2.INTER_NEAREST))
    return out


def write_frames(frames, out):
    p = subprocess.Popen(['ffmpeg', '-v', 'error', '-y', '-f', 'rawvideo', '-pix_fmt', 'bgr24', '-s', f'{W}x{H}', '-r', str(FPS), '-i', '-']
                         + ENC + [out], stdin=subprocess.PIPE)
    for f in frames:
        p.stdin.write(np.ascontiguousarray(f).tobytes())
    p.stdin.close(); p.wait()


def text_layer(lines, y, gold, size=64):
    font = ImageFont.truetype(FONT, size)
    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img); d.fontmode = '1'
    px = size // 8
    yy = y
    for i, line in enumerate(lines):
        bb = d.textbbox((0, 0), line, font=font)
        tw = bb[2] - bb[0]
        x = (W - tw) // 2 // px * px
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
    run(['ffmpeg', '-v', 'error', '-y', '-ss', '63.20', '-i', E.take_path('zero_carrion'), '-vf',
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
            text_layer(tx['lines'], tx['y'], tx['gold'], tx.get('size', 64)).save(p)
            inputs += ['-i', p]
            ia = len(inputs) // 2 - 1
            chain.append(f"[{last}][{ia}:v]overlay=enable='between(t,{tx['t0']},{tx['t1']})'[v{i}]")
        last = f'v{i}'
    final = os.path.join(E.OUT, 'zero_semcrt.mp4')
    run(['ffmpeg', '-v', 'error', '-y'] + inputs + ['-filter_complex', ';'.join(chain), '-map', f'[{last}]'] + ENC + [final])
    print('[ok] montagem sem CRT', final)


if __name__ == '__main__':
    main()
