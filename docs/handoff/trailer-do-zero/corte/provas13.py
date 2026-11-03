import os, sys, json
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from provas10 import frames, sheet, scale_all

T = r'E:\dev\projects\card-game-trailer\build\trailer'
P = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'corte13_provas')
V = {'c13': os.path.join(T, 'grimoire_trailer_c13_720p.mp4'), 'c12': os.path.join(T, 'grimoire_trailer_c12_720p.mp4')}


def sh(k, t0, t1, step, name, cols=10, tw=240):
    it = [(t, f, '%.2fs' % t) for t, f in frames(V[k], t0, t1, step)]
    return sheet(it, cols, os.path.join(P, name), tw)


if __name__ == '__main__':
    os.makedirs(P, exist_ok=True)
    sys.path.insert(0, r'E:\dev\projects\card-game-trailer\tools')
    import trailer_c13_cut as c
    job = sys.argv[1]
    if job == 'folhas':
        S0, S1 = c.TIMES[c.SHOPSEG]
        sh('c13', 0, c.TIMES[-1][1], 30, 'p_c13_2qps.png')
        sh('c13', S0 - 1.0, S1 + 1.0, 6, 'p_loja_transicoes_10qps.png')
        a, b = c.TIMES[c.ENTR[0]]
        sh('c13', a, b, 6, 'p_espantalho_10qps.png')
        a, b = c.TIMES[c.ENTR[2]]
        sh('c13', a, b, 4, 'p_anjo_15qps.png')
        sh('c13', c.FADE0 - 0.5, c.TIMES[c.REVEAL][0] + 2.0, 6, 'p_portao_seq_10qps.png')
        a, b = c.TIMES[c.REVEAL]
        sh('c13', a, b, 12, 'p_entrada_chefe_5qps.png')
        sh('c13', c.kt - 1.0, c.END_FILM + 1.0, 6, 'p_final_10qps.png')
    if job == 'logo':
        L13 = c.TIMES[c.STING][0]
        a = [f for _, f in frames(V['c13'], L13, L13 + 6.5)]
        b = [f for _, f in frames(V['c12'], 62.995, 62.995 + 6.5)]
        n = min(len(a), len(b))
        d = [float(np.abs(a[i].astype(int) - b[i].astype(int)).mean()) for i in range(n)]
        r = {'c13_x_c12_quadros': n, 'media': round(float(np.mean(d)), 2), 'max': round(float(np.max(d)), 2)}
        print(r); json.dump(r, open(os.path.join(P, 'p_fecho_c13_x_c12.json'), 'w'))
    if job == 'escala':
        n, bad = scale_all(V['c13'])
        line = 'c13 pares medidos %d, mudancas de escala > 3%%: %d %s' % (n, len(bad), bad[:40])
        print(line); open(os.path.join(P, 'escala.txt'), 'w').write(line + '\n')
