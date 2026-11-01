import subprocess, re, os, sys
import numpy as np
for n in sys.argv[1:]:
    d = os.path.join(r'E:\dev\projects\card-game-trailer\build\trailer\som', n)
    rd = lambda p: np.frombuffer(subprocess.run(['ffmpeg', '-v', 'error', '-i', p, '-f', 'f32le', '-ac', '2', '-ar', '48000', '-'], capture_output=True).stdout, np.float32).reshape(-1, 2)
    pre = rd(os.path.join(d, 'mix_pre.wav')); out = rd(os.path.join(d, 'mix.wav'))
    r = subprocess.run(['ffmpeg', '-i', os.path.join(d, 'mix_pre.wav'), '-af', 'ebur128', '-f', 'null', '-'], capture_output=True, text=True).stderr
    I = float(re.findall(r'I:\s+(-?[\d.]+) LUFS', r)[-1]); g = 10 ** ((-14 - I) / 20)
    a = np.abs(pre * g).max(1); b = np.abs(out[:len(a)]).max(1); a = a[:len(b)]
    h = 2400; k = len(a) // h
    ga = a[:k * h].reshape(k, h).max(1); gb = b[:k * h].reshape(k, h).max(1)
    gr = 20 * np.log10(gb / np.maximum(ga, 1e-9) + 1e-12)
    idx = np.argsort(gr)[:6]
    print(n, 'ganho %.1f dB' % (20 * np.log10(g)), 'piores reducoes:', [(round(i * 0.05, 2), round(float(gr[i]), 1)) for i in sorted(idx)], 'janelas >3 dB:', int((gr < -3).sum()))
