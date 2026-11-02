import sys, os, json, cv2, numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import provas10 as P10
from provas10 import frames, sheet, logo_times, scale_all, logo_mask_cmp

T = P10.T
P = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'corte10b_provas')
V = {'t': os.path.join(T, 'grimoire_zero_corte10b_720p.mp4'), 'r': os.path.join(T, 'grimoire_zero_corte10b_rei_720p.mp4'),
     't10': os.path.join(T, 'grimoire_zero_corte10_720p.mp4'), 'r10': os.path.join(T, 'grimoire_zero_corte10_rei_720p.mp4'),
     't2': os.path.join(T, 'grimoire_zero_corte2_720p.mp4'), 'r2': os.path.join(T, 'grimoire_zero_corte2_rei_720p.mp4')}


def hp_sheets(v, sub):
    it_h, it_r = [], []
    for t, f in frames(v, 39.0, 50.4, 6):
        it_h.append((t, f[880:1010, 0:400], f'{t:.2f}s'))
        it_r.append((t, f[290:400, 650:1250], f'{t:.2f}s'))
    a = sheet(it_h, 12, os.path.join(P, sub, 'p1_vida_hero_39.0-50.4s_10qps.png'), 200)
    b = sheet(it_r, 8, os.path.join(P, sub, 'p1_barra_rei_39.0-50.4s_10qps.png'), 300)
    return a, b


def plano(v, t0, t1, sub, nome, fps_step=4):
    it = [(t, f, f'{t:.2f}s') for t, f in frames(v, t0, t1, fps_step)]
    return sheet(it, 6, os.path.join(P, sub, nome), 320)


def diff_por_segundo(a, b):
    ca, cb = cv2.VideoCapture(a), cv2.VideoCapture(b)
    out, i, acc = [], 0, []
    while True:
        oa, fa = ca.read(); ob, fb = cb.read()
        if not (oa and ob):
            break
        acc.append(float(np.abs(fa.astype(np.int16) - fb.astype(np.int16)).mean()))
        i += 1
        if i % 60 == 0:
            out.append((i // 60 - 1, round(max(acc), 2))); acc = []
    return out


if __name__ == '__main__':
    for s in ('tirano', 'rei'):
        os.makedirs(os.path.join(P, s), exist_ok=True)
    job = sys.argv[1]
    if job == 'hp':
        print(hp_sheets(V['t'], 'tirano')); print(hp_sheets(V['r'], 'rei'))
    if job == 'planos':
        print(plano(V['t'], 38.85, 43.35, 'tirano', 'p3_guerreiro_turno_inimigo_dreno_38.85-43.35s.png'))
        print(plano(V['r'], 38.80, 43.40, 'rei', 'p3_guerreiro_turno_inimigo_dreno_38.80-43.40s.png'))
    if job == 'logo':
        R = {k: logo_times(V[k]) for k in ('t2', 't', 'r2', 'r')}
        m = {}
        for a, b in (('t2', 't'), ('r2', 'r')):
            rows = [x for x in logo_mask_cmp(V[a], V[b]) if x[0] >= 59.0]
            iou = np.array([x[1] for x in rows])
            m[b] = dict(media=round(float(iou.mean()), 3), minimo=round(float(iou.min()), 3), quadros=len(rows))
        R['mascara_dourada_vs_corte2_depois_59s'] = m
        json.dump(R, open(os.path.join(P, 'p2_tempos_logo.json'), 'w'), indent=1)
        print(json.dumps(R, indent=1))
    if job == 'escala':
        with open(os.path.join(P, 'escala_filme_inteiro.txt'), 'w') as fo:
            for k in ('t', 'r'):
                n, bad = scale_all(V[k])
                line = f'{k} pares medidos {n} mudancas de escala > 3%: {len(bad)} {bad[:40]}'
                print(line); fo.write(line + '\n')
    if job == 'diff':
        with open(os.path.join(P, 'p0_diferenca_corte10_x_corte10b_por_segundo.txt'), 'w') as fo:
            for a, b, n in (('t10', 't', 'tirano'), ('r10', 'r', 'rei')):
                d = diff_por_segundo(V[a], V[b])
                line = n + ' ' + ' '.join(f'{s}:{x}' for s, x in d)
                print(line); fo.write(line + '\n')
