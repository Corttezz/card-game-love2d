import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, r'E:\dev\projects\card-game-trailer\tools')
import secoes13c as S
from medir12 import load, env, B
from medir13 import win, first_below

if __name__ == '__main__':
    f = os.path.join(B, 'grimoire_trailer_c13c_720p.mp4')
    sys.argv = ['x', f]
    import io, contextlib
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        exec(open(S.__file__, encoding='utf-8').read().split("if __name__ == '__main__':")[1].replace('\n    ', '\n'), {**S.__dict__, 'use_mp4': f})
    out = [buf.getvalue().rstrip()]
    c = S.mod('trailer_c13c_cut')
    g = float(open(os.path.join(B, 'grimoire_trailer_c13c_gain.txt')).read())
    st = load(os.path.join(B, 'grimoire_trailer_c13c_music.f32'), raw=True) * 10 ** (g / 20)
    es = env(st, 0.02)
    D0 = c.TIMES[c.DOOR][0]; F0 = c.TIMES[c.FIGHT][0]; L0, L1 = c.TIMES[c.STING]
    t50 = first_below(es, c.FADE0, F0, -50)
    out.append('fade antes do portao: %.2f s -> abaixo de -50 dBFS em %.2f s (%.2f s)' % (c.FADE0, t50, t50 - c.FADE0))
    out.append('musica isolada do portao (%.2f s) ate 50 ms antes da luta (%.2f s): max %.1f dBFS' % (D0, F0, win(es, D0, F0 - 0.05)[0]))
    out.append('musica isolada no logo (%.2f a %.2f s): max %.1f dBFS' % (L0, L1, win(es, L0, L1)[0]))
    e = env(load(f), 0.05)
    A0 = c.TIMES[c.APPR][0]
    x = e[int((A0 + 0.2) / 0.05):int((A0 + 1.3) / 0.05)]
    out.append('vale do portao %.2f a %.2f s (som total, 50 ms): min %.1f, mediana %.1f dB' % (A0 + 0.2, A0 + 1.3, x.min(), np.median(x)))
    S1 = c.TIMES[c.SHOPSEG][1]
    x = e[int((S1 - 0.5) / 0.05):int((S1 + 0.1) / 0.05)]
    out.append('saida da loja %.2f a %.2f s (som total, 50 ms): min %.1f dB, max subida %+.1f dB' % (S1 - 0.5, S1 + 0.1, x.min(), np.diff(x).max()))
    txt = '\n'.join(out)
    print(txt)
    open(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'corte13_provas', 'medidas_rev3.txt'), 'w', encoding='utf-8').write(txt + '\n')
