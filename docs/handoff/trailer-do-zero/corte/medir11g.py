import os, sys, subprocess, json
import numpy as np

SR = 22050
B = r'E:\dev\projects\card-game-trailer\build\trailer'
sys.path.insert(0, r'E:\dev\projects\card-game-trailer\tools')


def load(p):
    raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', p, '-f', 'f32le', '-ac', '1', '-ar', str(SR), '-'], capture_output=True).stdout
    return np.frombuffer(raw, np.float32)


def rms_env(a, hop=0.1):
    n = int(hop * SR)
    k = len(a) // n
    x = a[:k * n].reshape(k, n)
    return 20 * np.log10(np.sqrt((x ** 2).mean(1)) + 1e-9)


def lowband(a):
    import scipy.signal as ss
    b, aa = ss.butter(4, 150 / (SR / 2))
    return ss.lfilter(b, aa, a)


def bass_onset(low, t, win=1.0):
    n = int(0.02 * SR)
    k = len(low) // n
    e = np.sqrt((low[:k * n].reshape(k, n) ** 2).mean(1))
    d = np.maximum(0, np.diff(e, prepend=e[0]))
    med = float(np.median(d[d > 0])) or 1e-9
    i = int(t / 0.02)
    loc = d[max(0, i - 2):i + 4].max()
    ring = d[max(0, i - int(win / 0.02)):i + int(win / 0.02)]
    rank = int((ring > loc).sum()) + 1
    return round(float(loc / med), 1), rank


def hit_margin(env, t):
    i = int(t / 0.1)
    peak = env[i:i + 4].max()
    bed = float(np.median(env[max(0, i - 10):i - 2]))
    return round(float(peak), 1), round(bed, 1), round(float(peak - bed), 1)


if __name__ == '__main__':
    out = []
    for v in ('tirano', 'rei'):
        os.environ['C11_MUSIC'] = v
        for m in [k for k in list(sys.modules) if k.startswith('trailer_c11')]:
            del sys.modules[m]
        import trailer_c11g_cut as c
        f = os.path.join(B, 'grimoire_trailer_c11g%s_720p.mp4' % ('_rei' if v == 'rei' else ''))
        a = load(f)
        env = rms_env(a)
        low = lowband(a)
        out.append('## %s' % v)
        out.append('| corte de salao | t (s) | grave no mix (x mediana) | posicao em +-1 s |')
        out.append('|---|---|---|---|')
        for t in [c.TIMES[c.HALLS[0]][0]] + c.HALL_CUTS:
            x, r = bass_onset(low, t)
            out.append('| | %.3f | %.1fx | %d |' % (t, x, r))
        p, bed, mg = hit_margin(env, c.kt)
        out.append('golpe letal %.3f s: pico %.1f dB, cama 1 s antes %.1f dB, margem %+.1f dB' % (c.kt, p, bed, mg))
        dk = c.TIMES[c.DECKB][0] + (c.kh_t - c.TIMES[c.DECKB][0])
        p, bed, mg = hit_margin(env, dk)
        out.append('golpe que mata nas cartas %.3f s: pico %.1f, cama %.1f, margem %+.1f dB' % (dk, p, bed, mg))
    txt = '\n'.join(out)
    print(txt)
    open(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'corte11g_provas', 'golpes_e_grave.md'), 'w', encoding='utf-8').write(txt + '\n')
