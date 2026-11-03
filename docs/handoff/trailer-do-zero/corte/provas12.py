import os, sys, json
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from provas10 import frames, sheet, scale_all

T = r'E:\dev\projects\card-game-trailer\build\trailer'
P = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'corte12_provas')
V = {'main': os.path.join(T, 'grimoire_trailer_c12_720p.mp4'), 'loja': os.path.join(T, 'grimoire_trailer_c12_loja_720p.mp4'),
     'g': os.path.join(T, 'grimoire_trailer_c11g_rei_720p.mp4')}
LOGO = os.path.join(T, 'brand', 'logo_sting.mp4')
L0 = {'main': 62.995, 'loja': 65.995, 'g': 61.73}


def logo(k):
    src = [f for _, f in frames(LOGO, 0, 6.5)]
    fr = [f for _, f in frames(V[k], L0[k], L0[k] + 6.5)]
    n = min(len(src), len(fr))
    import cv2
    d = [float(np.abs(cv2.resize(src[i], (fr[i].shape[1], fr[i].shape[0]), interpolation=cv2.INTER_AREA).astype(int) - fr[i].astype(int)).mean()) for i in range(n)]
    return dict(quadros=n, dif_media=round(float(np.mean(d)), 2), dif_max=round(float(np.max(d)), 2))


def sh(k, t0, t1, step, name, cols=10, tw=240):
    it = [(t, f, '%.2fs' % t) for t, f in frames(V[k], t0, t1, step)]
    return sheet(it, cols, os.path.join(P, name), tw)


if __name__ == '__main__':
    os.makedirs(P, exist_ok=True)
    job = sys.argv[1]
    if job == 'logo':
        r = {k: logo(k) for k in ('main', 'loja', 'g')}
        print(json.dumps(r)); json.dump(r, open(os.path.join(P, 'p_fecho_logo.json'), 'w'), indent=1)
    if job == 'folhas':
        sh('main', 0, 70, 30, 'p_main_2qps.png')
        sh('loja', 0, 73, 30, 'p_loja_2qps.png')
        sh('main', 44.2, 51.2, 6, 'p_main_portao_entrada_10qps.png')
        sh('main', 23.6, 25.0, 3, 'p_main_cartas_morte_20qps.png')
        sh('main', 58.9, 60.4, 3, 'p_main_golpe_letal_20qps.png')
        sh('loja', 28.9, 33.0, 12, 'p_loja_loja_5qps.png')
    if job == 'escala':
        with open(os.path.join(P, 'escala.txt'), 'w') as fo:
            for k in ('main', 'loja'):
                n, bad = scale_all(V[k])
                line = '%s pares medidos %d, mudancas de escala > 3%%: %d %s' % (k, n, len(bad), bad[:40])
                print(line); fo.write(line + '\n')
