import sys, os, cv2, json, numpy as np
from PIL import Image, ImageDraw

T = r'E:\dev\projects\card-game-trailer\build\trailer'
P = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'corte10_provas')


def frames(v, t0, t1, step=1):
    cap = cv2.VideoCapture(v)
    fps = cap.get(cv2.CAP_PROP_FPS)
    cap.set(cv2.CAP_PROP_POS_FRAMES, int(round(t0 * fps)))
    i = int(round(t0 * fps))
    while i < int(round(t1 * fps)):
        ok, f = cap.read()
        if not ok:
            break
        if f.shape[0] != 1080:
            f = cv2.resize(f, (1920, 1080), interpolation=cv2.INTER_NEAREST)
        if (i - int(round(t0 * fps))) % step == 0:
            yield i / fps, f
        i += 1


def sheet(items, cols, out, tw):
    th = int(tw * items[0][1].shape[0] / items[0][1].shape[1])
    rows = (len(items) + cols - 1) // cols
    im = Image.new('RGB', (cols * tw, rows * (th + 16)), (10, 10, 10))
    dr = ImageDraw.Draw(im)
    for k, (t, f, lab) in enumerate(items):
        x, y = (k % cols) * tw, (k // cols) * (th + 16)
        im.paste(Image.fromarray(cv2.cvtColor(cv2.resize(f, (tw, th), interpolation=cv2.INTER_AREA), cv2.COLOR_BGR2RGB)), (x, y))
        dr.text((x + 3, y + th + 2), lab, fill=(230, 230, 230))
    im.save(out)
    return out


def hp_sheet(v, name):
    it = [(t, f[880:1010, 90:400], f'{t:.2f}s') for t, f in frames(v, 39.0, 50.4, 6)]
    return sheet(it, 12, os.path.join(P, name), 200)


LINES = {'grimoire': (580, 750, 480, 1450), 'genero': (790, 840, 540, 1400), 'wishlist': (870, 930, 560, 1360)}


def logo_times(v, t0=56.5):
    cnt = {k: [] for k in LINES}
    ts = []
    for t, f in frames(v, t0, 64.5):
        h = f.astype(int)
        gold = (h[:, :, 2] > 170) & (h[:, :, 1] > 120) & (h[:, :, 0] < 140)
        ts.append(t)
        for k, (y0, y1, x0, x1) in LINES.items():
            cnt[k].append(int(gold[y0:y1, x0:x1].sum()))
    ts = np.array(ts)
    res = {}
    for k in ('grimoire', 'genero', 'wishlist'):
        c = np.array(cnt[k], float)
        fin = np.median(c[(ts > 63.0) & (ts < 63.8)])
        idx = np.flatnonzero((c >= 0.5 * fin) & (ts >= (res['grimoire'] if k != 'grimoire' else 0)))
        res[k] = round(float(ts[idx[0]]), 3) if len(idx) else None
    res['wishlist_na_tela'] = round(64.5 - res['wishlist'], 3) if res['wishlist'] else None
    return res


def scale_all(v, step=2):
    sift = cv2.SIFT_create(nfeatures=600)
    bf = cv2.BFMatcher()
    prev = None
    bad = []
    n = 0
    for t, f in frames(v, 0.0, 64.5, step):
        g = cv2.cvtColor(cv2.resize(f, (960, 540), interpolation=cv2.INTER_AREA), cv2.COLOR_BGR2GRAY)
        k, d = sift.detectAndCompute(g, None)
        if prev is not None and d is not None and prev[1] is not None and len(k) > 8 and len(prev[0]) > 8:
            mm = [a for a, b in bf.knnMatch(d, prev[1], k=2) if a.distance < 0.7 * b.distance]
            if len(mm) >= 12:
                a = np.float32([k[x.queryIdx].pt for x in mm]); b = np.float32([prev[0][x.trainIdx].pt for x in mm])
                M, inl = cv2.estimateAffinePartial2D(a, b, method=cv2.RANSAC, ransacReprojThreshold=3)
                if M is not None and inl is not None and inl.sum() >= 12:
                    s = 1 / np.hypot(M[0, 0], M[1, 0])
                    n += 1
                    if abs(s - 1) > 0.03:
                        bad.append((round(t, 3), round(float(s), 3), int(inl.sum())))
        prev = (k, d)
    return n, bad


def logo_diff(a, b, out):
    da = dict((round(t, 3), f) for t, f in frames(a, 57.77, 64.5, 1))
    rows = []
    for t, f in frames(b, 57.77, 64.5, 1):
        g = da.get(round(t, 3))
        if g is not None:
            rows.append((round(t, 3), float(np.abs(f.astype(int) - g.astype(int)).mean())))
    pick = [58.0, 58.6, 59.0, 59.4, 60.5, 62.0, 62.5, 63.5]
    ca = {round(t, 2): f for t, f in frames(a, 57.9, 63.6, 1) if round(t, 2) in pick}
    cb = {round(t, 2): f for t, f in frames(b, 57.9, 63.6, 1) if round(t, 2) in pick}
    it = [(t, ca[t], f'corte 2 {t:.2f}s') for t in pick if t in ca] + [(t, cb[t], f'corte 10 {t:.2f}s') for t in pick if t in cb]
    sheet(it, len(pick), out, 300)
    return rows


if __name__ == '__main__':
    os.makedirs(os.path.join(P, 'tirano'), exist_ok=True); os.makedirs(os.path.join(P, 'rei'), exist_ok=True)
    job = sys.argv[1]
    V = {'t': os.path.join(T, 'grimoire_zero_corte10_720p.mp4'), 'r': os.path.join(T, 'grimoire_zero_corte10_rei_720p.mp4'),
         't2': os.path.join(T, 'grimoire_zero_corte2_720p.mp4'), 'r2': os.path.join(T, 'grimoire_zero_corte2_rei_720p.mp4'),
         't9': os.path.join(T, 'grimoire_zero_corte9_720p.mp4'), 'r9': os.path.join(T, 'grimoire_zero_corte9_rei_720p.mp4')}
    if job == 'hp':
        print(hp_sheet(V['t'], 'tirano/p1_vida_hero_39.0-50.4s_10qps.png'))
        print(hp_sheet(V['r'], 'rei/p1_vida_hero_39.0-50.4s_10qps.png'))
    if job == 'logo':
        R = {k: logo_times(V[k]) for k in ('t2', 't9', 't', 'r2', 'r9', 'r')}
        json.dump(R, open(os.path.join(P, 'p2_tempos_logo.json'), 'w'), indent=1)
        for k, v in R.items():
            print(k, v)
        for a, b, n in (('t2', 't', 'tirano/p2_logo_corte2_x_corte10.png'), ('r2', 'r', 'rei/p2_logo_corte2_x_corte10.png')):
            rows = logo_diff(V[a], V[b], os.path.join(P, n))
            d = np.array([x[1] for x in rows])
            print(n, 'quadros', len(rows), 'diferenca media', round(float(d.mean()), 2), 'mediana', round(float(np.median(d)), 2), 'max', round(float(d.max()), 2))
    if job == 'escala':
        for k in ('t', 'r'):
            n, bad = scale_all(V[k])
            print(k, 'pares medidos', n, 'mudancas de escala > 3%:', len(bad), bad[:30])


def gold_mask(f):
    h = f[540:960].astype(int)
    return (h[:, :, 2] > 170) & (h[:, :, 1] > 110) & (h[:, :, 0] < 150)


def logo_mask_cmp(a, b, t0=58.3, t1=64.5):
    ma = {round(t, 3): gold_mask(f) for t, f in frames(a, t0, t1)}
    res = []
    for t, f in frames(b, t0, t1):
        m = ma.get(round(t, 3))
        if m is None:
            continue
        mb = gold_mask(f)
        u = (m | mb).sum()
        res.append((round(t, 3), float((m & mb).sum() / u) if u else 1.0, int(m.sum()), int(mb.sum())))
    return res
