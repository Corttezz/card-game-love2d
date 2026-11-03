import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from medir12 import load, env, margin, ebur, B


def stem_of(name):
    g = float(open(os.path.join(B, name + '_gain.txt')).read())
    return load(os.path.join(B, name + '_music.f32'), raw=True) * 10 ** (g / 20)


def win(es, t0, t1, hop=0.02):
    x = es[int(t0 / hop):int(t1 / hop)]
    return float(x.max()), float(np.median(x))


def first_below(es, t0, t1, lim, hop=0.02):
    for i in range(int(t0 / hop), int(t1 / hop)):
        if es[i] < lim and es[i:i + 10].max() < lim:
            return i * hop
    return None


if __name__ == '__main__':
    import trailer_c13_cut as c
    n = 'grimoire_trailer_c13'
    f = os.path.join(B, n + '_720p.mp4')
    a = load(f); e = env(a)
    es = env(stem_of(n), 0.02)
    out = ['## ' + n, 'ebur128 (720p final): ' + ebur(f)]
    D0 = c.TIMES[c.DOOR][0]; A0 = c.TIMES[c.APPR][0]; F0 = c.TIMES[c.FIGHT][0]; L1 = c.TIMES[c.STING][1]
    R0 = c.TIMES[c.REVEAL][0]
    ref = float(np.median(es[int((c.FADE0 - 1.0) / 0.02):int(c.FADE0 / 0.02)]))
    t50 = first_below(es, c.FADE0, F0, -50)
    out.append('fade antes do portao: comeca em %.2f s (musica %.1f dBFS no segundo anterior), passa de -50 dBFS em %.2f s; duracao %.2f s' % (c.FADE0, ref, t50, t50 - c.FADE0))
    for lab, t0, t1 in (('plano de aproximacao + portao + entrada inteira do chefe (ate 50 ms antes da luta)', t50, F0 - 0.05),
                        ('portao (corte do portao) ate o fim da entrada', D0, F0 - 0.05),
                        ('fim inteiro (preto + logo)', c.END_FILM + 0.3, L1)):
        mx, md = win(es, t0, t1)
        out.append('- musica isolada %s %.2f a %.2f s: max %.1f dBFS, mediana %.1f dBFS' % (lab, t0, t1, mx, md))
    out.append('- aproximacao %.2f s, portao %.2f s, entrada do chefe %.2f s (olhos acendem no quadro 730 = %.2f s), luta %.2f s' % (A0, D0, R0, R0 + (730 - c.REV_A) / 60.0, F0))
    for lab, t in (('morte nas cartas', c.kh_t), ('golpe letal', c.kt)):
        for w0, w1 in ((1.6, 0.15), (2.5, 0.5)):
            pk, bed, m = margin(e, t, w0, w1)
            out.append('- %s %.3f s: pico %.1f dB, musica %.1f a %.1f s antes %.1f dB, margem %+.1f dB' % (lab, t, pk, w0, w1, bed, m))
    S0, S1 = c.TIMES[c.SHOPSEG]
    out.append('- loja %.2f a %.2f s, crossfade de musica de %.2f a %.2f s e de %.2f a %.2f s, dissolve 0,5 s na entrada e 0,45 s na saida' % (S0, S1, S0 - c.XF, S0 + c.XF, S1 - c.XF, S1 + 0.3))
    g12 = os.path.join(B, 'grimoire_trailer_c12_720p.mp4')
    e12 = env(load(g12))
    k0, k1 = c.CARD_T0, c.TIMES[c.CARDB][1]
    def rms(ev, t0, t1):
        x = ev[int(t0 / 0.1):int(t1 / 0.1)]
        return 10 * np.log10(np.mean(10 ** (x / 10)))
    r13 = rms(e, k0, k1); r12 = rms(e12, k0, k1)
    out.append('- cartas + Colecao %.2f a %.2f s: RMS %.1f dB no 13 contra %.1f dB no 12, diferenca %+.1f dB' % (k0, k1, r13, r12, r13 - r12))
    out.append('- final: corte para o preto em %.3f s (onset da faixa), musica abaixo de -50 dBFS a partir de %.2f s, logo de %.2f a %.2f s' % (c.END_FILM, first_below(es, c.END_FILM - 0.1, L1, -50), c.END_FILM + 0.3, L1))
    txt = '\n'.join(out)
    print(txt)
    os.makedirs(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'corte13_provas'), exist_ok=True)
    open(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'corte13_provas', 'medidas.txt'), 'w', encoding='utf-8').write(txt + '\n')
