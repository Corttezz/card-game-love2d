import os, sys, json, subprocess
import cv2, numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from provas10 import frames, sheet, scale_all

T = r'E:\dev\projects\card-game-trailer\build\trailer'
P = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'corte11_provas')
V = {'t': os.path.join(T, 'grimoire_trailer_c11.mp4'), 'r': os.path.join(T, 'grimoire_trailer_c11_rei.mp4'),
     't720': os.path.join(T, 'grimoire_trailer_c11_720p.mp4'), 'r720': os.path.join(T, 'grimoire_trailer_c11_rei_720p.mp4'),
     'v8': os.path.join(T, 'grimoire_trailer_v8.mp4'), 'd10': os.path.join(T, 'grimoire_zero_corte10d_720p.mp4')}
LOGO = os.path.join(T, 'brand', 'logo_sting.mp4')


def dur(p):
    return float(subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', p], capture_output=True, text=True).stdout)


def tail_frames(p, secs):
    d = dur(p)
    return [f for _, f in frames(p, d - secs, d)]


LOGO_T0 = {'t': float(os.environ.get('C11_LOGO_T', '0')), 'r': float(os.environ.get('C11_LOGO_R', '0'))}


def logo_frames(k):
    if k == 'v8':
        return tail_frames(V[k], 6.5)
    return [f for _, f in frames(V[k], LOGO_T0[k], LOGO_T0[k] + 6.5)]


def logo_cmp():
    src = [f for _, f in frames(LOGO, 0, 6.5)]
    out = {}
    for k in ('t', 'r', 'v8'):
        fr = logo_frames(k)
        n = min(len(src), len(fr))
        d = []
        for i in range(n):
            a = src[i].astype(int); b = fr[i].astype(int)
            d.append(float(np.abs(a - b).mean()))
        out[k] = dict(quadros=n, dif_media=round(float(np.mean(d)), 2), dif_max=round(float(np.max(d)), 2))
    v8 = logo_frames('v8'); t = logo_frames('t')
    n = min(len(v8), len(t))
    out['c11_x_v8'] = round(float(np.mean([np.abs(v8[i].astype(int) - t[i].astype(int)).mean() for i in range(n)])), 2)
    pick = [0.3, 1.5, 2.6, 3.2, 4.4, 6.2]
    it = []
    for lab, p in (('v8', V['v8']), ('c11', V['t'])):
        t0 = dur(p) - 6.5 if lab == 'v8' else LOGO_T0['t']
        for s in pick:
            for _, f in frames(p, t0 + s, t0 + s + 0.02):
                it.append((s, f, f'{lab} logo +{s:.1f}s'))
                break
    sheet(it, len(pick), os.path.join(P, 'p_fecho_v8_x_c11.png'), 300)
    return out


def sharp(p, t):
    c = cv2.VideoCapture(p); c.set(cv2.CAP_PROP_POS_MSEC, t * 1000); ok, f = c.read()
    if f.shape[0] != 1080:
        f = cv2.resize(f, (1920, 1080), interpolation=cv2.INTER_LANCZOS4)
    g = cv2.cvtColor(f[200:880, 300:1620], cv2.COLOR_BGR2GRAY)
    return round(float(cv2.Laplacian(g, cv2.CV_64F).var()), 1)


def probe(p):
    o = subprocess.run(['ffprobe', '-v', 'error', '-select_streams', 'v:0', '-show_entries', 'stream=width,height,bit_rate,r_frame_rate', '-of', 'csv=p=0', p], capture_output=True, text=True).stdout.strip()
    return o


def dark(p):
    c = cv2.VideoCapture(p); n = b = 0; fade = []
    while True:
        ok, f = c.read()
        if not ok:
            break
        if f.mean() < 0.05 * 255:
            b += 1; fade.append(round(n / 60, 2))
        n += 1
    return n, b, fade


if __name__ == '__main__':
    os.makedirs(P, exist_ok=True)
    job = sys.argv[1]
    if job == 'logo':
        r = logo_cmp(); print(json.dumps(r, indent=1)); json.dump(r, open(os.path.join(P, 'p_fecho_quadro_a_quadro.json'), 'w'), indent=1)
    if job == 'qual':
        rows = []
        for k in ('t', 'r', 't720', 'r720', 'v8', 'd10'):
            rows.append((k, probe(V[k])))
        hall = {'t720 hall 37.5s': sharp(V['t720'], 37.5), 't1080 hall 37.5s': sharp(V['t'], 37.5), 'd10 720 hall 14.0s': sharp(V['d10'], 14.0), 'd10 720 hall 15.5s': sharp(V['d10'], 15.5)}
        txt = '\n'.join(f'{k}: {v}' for k, v in rows) + '\n' + json.dumps(hall, indent=1)
        print(txt); open(os.path.join(P, 'p_qualidade.txt'), 'w').write(txt + '\n')
    if job == 'escala':
        with open(os.path.join(P, 'escala_filme_inteiro.txt'), 'w') as fo:
            for k in ('t', 'r'):
                n, bad = scale_all(V[k])
                line = f'{k} pares medidos {n} mudancas de escala > 3%: {len(bad)} {bad[:40]}'
                print(line); fo.write(line + '\n')
    if job == 'escuro':
        for k in ('t720', 'r720'):
            print(k, dark(V[k]))
    if job == 'folha':
        for k, n in (('t720', 'tirano'), ('r720', 'rei')):
            it = [(t, f, f'{t:.1f}s') for t, f in frames(V[k], 0, 60, 30)]
            print(sheet(it, 10, os.path.join(P, f'folha_{n}_2qps.png'), 240))
