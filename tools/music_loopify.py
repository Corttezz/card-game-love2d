"""Loop sem emenda: procura o par (início i, fim j) em que volume e timbre mais combinam, cruza a[j:j+xf] com a[i:i+xf]
(equal-power) e mede a emenda no MP3 já decodificado. uso: python loopify2.py in.mp3 out.mp3 [xf_s] [min_loop_s]"""
import subprocess, sys, numpy as np
src, dst = sys.argv[1], sys.argv[2]
XF = float(sys.argv[3]) if len(sys.argv) > 3 else 6.0
MINLOOP = float(sys.argv[4]) if len(sys.argv) > 4 else 85.0
SR = 44100
def dec(p):
    raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', p, '-f', 'f32le', '-ac', '2', '-ar', str(SR), '-'], capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.float32).reshape(-1, 2).copy()
a = dec(src); L = len(a)
H = SR // 4  # janela de 0,25 s
nw = L // H
def feat(k):
    x = a[k * H:(k + 4) * H].mean(1)  # 1 s de contexto
    s = np.abs(np.fft.rfft(x * np.hanning(len(x))))
    bands = np.array([s[int(lo):int(hi)].mean() for lo, hi in zip(np.geomspace(20, len(s) - 1, 25)[:-1], np.geomspace(20, len(s) - 1, 25)[1:])])
    return np.log1p(bands * 100), np.sqrt((x ** 2).mean())
F = [feat(k) for k in range(nw - 4)]
xfw = int(XF * SR / H)
best = None
for i in range(0, min(int(25 * SR / H), nw)):           # início do loop nos primeiros 25 s
    fi, ri = F[i]
    if ri < 0.03: continue
    for j in range(i + int(MINLOOP * SR / H), nw - 4 - xfw):  # fim: o cruzamento a[j:j+xf] tem de caber no arquivo
        fj, rj = F[j]
        # nível no ponto de entrada (depois do cruzamento) e timbre no início do cruzamento
        ri2 = F[i + xfw][1]; rj2 = F[j + xfw][1] if j + xfw < len(F) else rj
        cost = np.linalg.norm(fi - fj) + 25 * abs(np.log((ri2 + 1e-4) / (rj + 1e-4))) + 10 * abs(np.log((ri + 1e-4) / (rj + 1e-4)))
        if best is None or cost < best[0]: best = (cost, i, j)
_, i, j = best
si, sj, n = i * H, j * H, int(XF * SR)
t = np.linspace(0, np.pi / 2, n, dtype=np.float32)[:, None]
mixed = a[sj:sj + n] * np.cos(t) + a[si:si + n] * np.sin(t)
out = np.concatenate([a[si + n:sj], mixed])
out /= max(1.0, np.abs(out).max() / 0.98)
subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 'f32le', '-ac', '2', '-ar', str(SR), '-i', '-', '-c:a', 'libmp3lame', '-b:a', '192k', dst],
               input=out.astype(np.float32).tobytes(), check=True)
b = dec(dst)
def rms(x): return float(np.sqrt((x ** 2).mean()))
db = lambda p, q: 20 * np.log10((p + 1e-6) / (q + 1e-6))
print(f'{dst.split("/")[-1]}: original {L/SR:.1f}s -> loop {len(b)/SR:.1f}s (de {si/SR:.1f}s a {sj/SR+XF:.1f}s, crossfade {XF:.0f}s)')
print(f'  emenda decodificada: salto {np.abs(b[0]-b[-1]).max():.4f} (passo normal p99.9 {np.percentile(np.abs(np.diff(b,axis=0)),99.9):.4f}); '
      f'nível 1s fim->começo {db(rms(b[:SR]), rms(b[-SR:])):+.1f} dB; 0,25s {db(rms(b[:SR//4]), rms(b[-SR//4:])):+.1f} dB; '
      f'variação típica de 1s para 1s no meio {np.median([abs(db(rms(b[k+SR:k+2*SR]), rms(b[k:k+SR]))) for k in range(SR*5, len(b)-SR*7, SR*3)]):.1f} dB')
