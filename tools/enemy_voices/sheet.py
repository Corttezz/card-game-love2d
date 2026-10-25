import sys, os, numpy as np
from PIL import Image, ImageDraw, ImageFont
sys.path.insert(0, os.path.dirname(__file__))
import dsp as D
from scipy import signal

W_PX_PER_S = 300
WAVE_H = 60
SPEC_H = 90


def spec_img(x, width):
    f, t, S = signal.spectrogram(x, D.SR, nperseg=1024, noverlap=768)
    S = 10 * np.log10(S + 1e-12)
    S = np.clip((S + 100) / 70, 0, 1)
    fmax = 12000
    keep = f <= fmax
    S = S[keep][::-1]
    img = Image.fromarray((S * 255).astype(np.uint8)).resize((max(1, width), SPEC_H))
    cm = np.array(img).astype(np.float64) / 255
    rgb = np.stack([np.clip(cm * 3, 0, 1), np.clip(cm * 3 - 1, 0, 1), np.clip(cm * 3 - 2, 0, 1)], axis=-1)
    return Image.fromarray((rgb * 255).astype(np.uint8))


def wave_img(x, width):
    img = Image.new('RGB', (width, WAVE_H), (16, 16, 24))
    d = ImageDraw.Draw(img)
    n = len(x)
    mid = WAVE_H // 2
    for px in range(width):
        a, b = int(px * n / width), int((px + 1) * n / width)
        seg = x[a:max(b, a + 1)]
        if len(seg) == 0:
            continue
        lo, hi = seg.min(), seg.max()
        col = (230, 80, 80) if max(abs(lo), abs(hi)) > 0.97 else (120, 200, 255)
        d.line([(px, mid - hi * mid), (px, mid - lo * mid)], fill=col)
    d.line([(0, mid), (width, mid)], fill=(50, 50, 70))
    return img


def sheet(rows, out, title):
    maxdur = max(len(x) / D.SR for _, x, _ in rows)
    wcol = int(maxdur * W_PX_PER_S) + 10
    label_w = 300
    rh = WAVE_H + SPEC_H + 6
    img = Image.new('RGB', (label_w + wcol, 30 + rh * len(rows)), (8, 8, 12))
    d = ImageDraw.Draw(img)
    d.text((6, 8), title, fill=(255, 255, 255))
    for i, (name, x, info) in enumerate(rows):
        y = 30 + i * rh
        w = max(1, int(len(x) / D.SR * W_PX_PER_S))
        img.paste(wave_img(x, w), (label_w, y))
        img.paste(spec_img(x, w), (label_w, y + WAVE_H))
        d.text((6, y + 4), name, fill=(240, 240, 200))
        d.text((6, y + 22), info, fill=(180, 180, 180))
        for s in range(int(maxdur) + 1):
            d.line([(label_w + s * W_PX_PER_S, y), (label_w + s * W_PX_PER_S, y + 4)], fill=(255, 255, 0))
    img.save(out)


def grid(rows, out, title, cols=5, px_per_s=420):
    label_w = 170
    colw = [int(0.62 * px_per_s)] * 3 + [int(1.55 * px_per_s)] * 2
    rh = WAVE_H + SPEC_H + 22
    n = (len(rows) + cols - 1) // cols
    img = Image.new('RGB', (label_w + sum(colw) + 8 * cols, 30 + rh * n), (8, 8, 12))
    d = ImageDraw.Draw(img)
    d.text((6, 8), title, fill=(255, 255, 255))
    for i, (name, x, info) in enumerate(rows):
        r, c = divmod(i, cols)
        y = 30 + r * rh
        xo = label_w + sum(colw[:c]) + 8 * c
        if c == 0:
            d.text((6, y + 30), name.split(' ')[0], fill=(240, 240, 200))
        w = max(1, int(len(x) / D.SR * px_per_s))
        img.paste(wave_img(x, w), (xo, y + 16))
        img.paste(spec_img(x, w), (xo, y + 16 + WAVE_H))
        d.text((xo, y + 2), name.split(' ')[-1] + '  ' + info, fill=(180, 180, 180))
        for s10 in range(0, 16):
            px = xo + int(s10 * 0.1 * px_per_s)
            if px - xo <= colw[c]:
                d.line([(px, y + 16 + WAVE_H - 3), (px, y + 16 + WAVE_H)], fill=(255, 255, 0) if s10 % 5 == 0 else (90, 90, 0))
    img.save(out)


def ab_grid(groups, out, title, px_per_s=360):
    label_w = 190
    colw = [int(0.62 * px_per_s)] * 3 + [int(1.55 * px_per_s)] * 2
    rh = WAVE_H + SPEC_H + 20
    img = Image.new('RGB', (label_w + sum(colw) + 40, 30 + rh * len(groups)), (8, 8, 12))
    d = ImageDraw.Draw(img)
    d.text((6, 8), title, fill=(255, 255, 255))
    for r, (label, items) in enumerate(groups):
        y = 30 + r * rh
        if label.endswith('(v2)'):
            d.line([(0, y + rh - 1), (img.width, y + rh - 1)], fill=(90, 90, 110))
        d.text((6, y + 30), label, fill=(240, 240, 200) if label.endswith('(v2)') else (150, 150, 150))
        for c, (name, x, info) in enumerate(items):
            xo = label_w + sum(colw[:c]) + 8 * c
            w = max(1, min(colw[c], int(len(x) / D.SR * px_per_s)))
            img.paste(wave_img(x, w), (xo, y + 16))
            img.paste(spec_img(x, w), (xo, y + 16 + WAVE_H))
            d.text((xo, y + 2), info, fill=(180, 180, 180))
            for s10 in range(0, 16):
                px = xo + int(s10 * 0.1 * px_per_s)
                if px - xo <= w:
                    d.line([(px, y + 16 + WAVE_H - 3), (px, y + 16 + WAVE_H)], fill=(255, 255, 0) if s10 % 5 == 0 else (90, 90, 0))
    img.save(out)


if __name__ == '__main__':
    out = sys.argv[1]
    rows = []
    for f in sys.argv[2:]:
        x = D.load(f)
        rows.append((os.path.basename(f), x, '%.2fs  %.1f LUFS  pk %.1f dB' % (len(x) / D.SR, D.active_lufs(x), D.peak_db(x))))
    sheet(rows, out, 'sources')
