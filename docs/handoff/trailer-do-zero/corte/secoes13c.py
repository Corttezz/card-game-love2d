import os, sys, importlib
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, r'E:\dev\projects\card-game-trailer\tools')
from medir12 import load, env, margin, ebur, B


def mod(name, **envs):
    for k, v in envs.items():
        os.environ[k] = v
    for m in [k for k in list(sys.modules) if k.startswith('trailer_c1')]:
        del sys.modules[m]
    return importlib.import_module(name)


def secs(c):
    T = c.TIMES
    return {'cartas': (c.CARD_T0, T[c.DECKB][1]), 'colecao': (T[c.COLL][0], T[c.CARDB][1]),
            'criaturas': (T[c.ENTR[0]][0], T[c.ENTR[-1]][1]), 'saloes': (T[c.HALLS[0]][0], T[c.HALLS[-1]][1]),
            'luta': (T[c.FIGHT][0], T[c.KILLSEG][0]), 'golpe->preto': (c.kt, c.END_FILM)}


def rms(e, t0, t1):
    x = e[int(t0 / 0.1):int(t1 / 0.1)]
    return 10 * np.log10(np.mean(10 ** (x / 10)))


if __name__ == '__main__':
    use_mp4 = sys.argv[1] if len(sys.argv) > 1 else os.path.join(B, 'grimoire_trailer_c13c.mp4')
    c12 = mod('trailer_c12_cut', C12_SHOP='1'); s12 = secs(c12)
    e12 = env(load(os.path.join(B, 'grimoire_trailer_c12_loja_720p.mp4')))
    c13 = mod('trailer_c13_cut'); s13 = secs(c13)
    e13 = env(load(os.path.join(B, 'grimoire_trailer_c13_720p.mp4')))
    cc = mod('trailer_c13c_cut'); sc = secs(cc)
    ec = env(load(use_mp4))
    out = ['ebur128 %s: %s' % (os.path.basename(use_mp4), ebur(use_mp4)),
           '| secao | c12 loja (o que o Daniel viu) | c13 rev 2 | c13 rev 3 | rev 3 - c12 |', '|---|---|---|---|---|']
    for k in s12:
        a, b, d = rms(e12, *s12[k]), rms(e13, *s13[k]), rms(ec, *sc[k])
        out.append('| %s | %.1f | %.1f | %.1f | %+.1f |' % (k, a, b, d, d - a))
    out.append('luta rev 3 acima dos saloes: %+.1f dB' % (rms(ec, *sc['luta']) - rms(ec, *sc['saloes'])))
    for w0, w1 in ((1.6, 0.15), (2.5, 0.5)):
        pk, bed, m = margin(ec, cc.kt, w0, w1)
        out.append('golpe letal %.3f s: pico %.1f, som %.1f a %.1f s antes %.1f, margem %+.1f dB' % (cc.kt, pk, w0, w1, bed, m))
    for w0, w1 in ((1.6, 0.15), (2.5, 0.5)):
        pk, bed, m = margin(ec, cc.kh_t, w0, w1)
        out.append('morte nas cartas %.3f s: margem (%.1f a %.1f s antes) %+.1f dB' % (cc.kh_t, w0, w1, m))
    print('\n'.join(out))
