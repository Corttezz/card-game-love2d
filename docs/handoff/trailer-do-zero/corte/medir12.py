import os, sys, subprocess, re
import numpy as np
SR = 22050
B = r'E:\dev\projects\card-game-trailer\build\trailer'
sys.path.insert(0, r'E:\dev\projects\card-game-trailer\tools')


def load(p, raw=False):
    if raw:
        a = np.fromfile(p, np.float32).reshape(-1, 2).mean(1)
        idx = np.arange(0, len(a), 48000 / SR).astype(int)
        return a[idx]
    r = subprocess.run(['ffmpeg', '-v', 'error', '-i', p, '-f', 'f32le', '-ac', '1', '-ar', str(SR), '-'], capture_output=True).stdout
    return np.frombuffer(r, np.float32)


def env(a, hop=0.1):
    n = int(hop * SR); k = len(a) // n
    return 20 * np.log10(np.sqrt((a[:k * n].reshape(k, n) ** 2).mean(1)) + 1e-9)


def margin(e, t, w0, w1):
    i = int(t / 0.1)
    pk = e[max(0, i - 1):i + 4].max()
    bed = float(np.median(e[int((t - w0) / 0.1):int((t - w1) / 0.1)]))
    return pk, bed, pk - bed


def ebur(p):
    o = subprocess.run(['ffmpeg', '-nostats', '-i', p, '-af', 'ebur128=peak=true', '-f', 'null', '-'], capture_output=True, text=True).stderr
    s = o[o.rfind('Summary:'):]
    return ' '.join(l.strip() for l in s.splitlines() if re.search(r'I:|LRA:|Peak:', l))


def cut_report(name, shop):
    os.environ['C12_SHOP'] = '1' if shop else '0'
    for m in [k for k in list(sys.modules) if k.startswith('trailer_c1')]:
        del sys.modules[m]
    import trailer_c12_cut as c
    f = os.path.join(B, name + '_720p.mp4')
    g = float(open(os.path.join(B, name + '_gain.txt')).read())
    a = load(f); e = env(a)
    st = load(os.path.join(B, name + '_music.f32'), raw=True) * 10 ** (g / 20)
    es = env(st)
    out = ['## %s' % name, 'ebur128 (720p final): ' + ebur(f)]
    D0 = c.TIMES[c.DOOR][0]; F0 = c.TIMES[c.FIGHT][0]; L0 = c.TIMES[c.STING][0]; L1 = c.TIMES[c.STING][1]
    es = env(st, 0.02)

    def win(t0, t1):
        x = es[int(t0 / 0.02):int(t1 / 0.02)]
        return x.max(), np.median(x)
    out.append('musica isolada (stem com o mesmo ganho), RMS 20 ms:')
    for lab, t0, t1 in (('portao + entrada do chefe (ate 50 ms antes da luta)', D0, F0 - 0.05), ('fim inteiro (preto + logo)', c.END_FILM, L1), ('luta (referencia)', F0, F0 + 2)):
        mx, md = win(t0, t1)
        out.append('- %s %.2f a %.2f s: max %.1f dBFS, mediana %.1f dBFS' % (lab, t0, t1, mx, md))
    for lab, t in (('morte nas cartas', c.kh_t), ('golpe letal', c.kt)):
        for w0, w1 in ((1.6, 0.15), (2.5, 0.5)):
            pk, bed, m = margin(e, t, w0, w1)
            out.append('- %s %.3f s: pico %.1f dB, musica %.1f a %.1f s antes %.1f dB, margem %+.1f dB' % (lab, t, pk, w0, w1, bed, m))
    if shop:
        S0, S1 = c.TIMES[c.SHOPSEG]
        out.append('- loja %.2f a %.2f s: o stem nesse trecho e so a musica da loja (Rei pausado com env -90 dB): max %.1f dBFS' % (S0, S1, win(S0 + 0.3, S1 - 0.1)[0]))
    return out


def old(f, kh, kt):
    a = load(os.path.join(B, f)); e = env(a)
    out = ['## %s' % f, 'ebur128: ' + ebur(os.path.join(B, f))]
    for lab, t in (('morte nas cartas', kh), ('golpe letal', kt)):
        for w0, w1 in ((1.6, 0.15), (2.5, 0.5)):
            pk, bed, m = margin(e, t, w0, w1)
            out.append('- %s %.3f s: pico %.1f, musica %.1f dB, margem %+.1f dB' % (lab, t, pk, bed, m))
    return out


if __name__ == '__main__':
    rows = []
    for v in sys.argv[1:]:
        rows += cut_report('grimoire_trailer_c12' + ('_loja' if v == 'loja' else ''), v == 'loja')
    rows += old('grimoire_trailer_c11g_rei_720p.mp4', 24.096, 58.23)
    if os.path.exists(os.path.join(B, 'grimoire_trailer_c11f_rei_720p.mp4')):
        rows += old('grimoire_trailer_c11f_rei_720p.mp4', float(os.environ.get('C11F_KH', '0')) or 24.10, float(os.environ.get('C11F_KT', '0')) or 0)
    print('\n'.join(rows))
