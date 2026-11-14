"""Faixa no formato do jogo (memory: 'Introdução + ponto de loop'): começa no início natural da geração, o loop vai de
loopStart a loopEnd (src/data/music_loops.lua) e o arquivo segue 6 s além do loopEnd com a cópia do que vem depois do
loopStart. A emenda é o crossfade equal-power a[j:j+xf] -> a[i:i+xf], com o par (i, j) escolhido como no music_loopify.
uso: python looppoints.py in.mp3 out.mp3 xf_s min_loop_s gain_db"""
import subprocess, sys, numpy as np
src, dst, XF, MINLOOP, GAIN = sys.argv[1], sys.argv[2], float(sys.argv[3]), float(sys.argv[4]), float(sys.argv[5])
SR = 44100; TAIL = 6.0
def dec(p):
    raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', p, '-f', 'f32le', '-ac', '2', '-ar', str(SR), '-'], capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.float32).reshape(-1, 2).copy()
a = dec(src); L = len(a)
# silêncio inicial da geração (> -60 dBFS) sai
lead = int(np.argmax(np.abs(a).max(1) > 1e-3)); a = a[lead:]; L = len(a)
H = SR // 4; nw = L // H
def feat(k):
    x = a[k * H:(k + 4) * H].mean(1)
    s = np.abs(np.fft.rfft(x * np.hanning(len(x))))
    e = np.geomspace(20, len(s) - 1, 25)
    return np.log1p(np.array([s[int(lo):int(hi)].mean() for lo, hi in zip(e[:-1], e[1:])]) * 100), np.sqrt((x ** 2).mean())
F = [feat(k) for k in range(nw - 4)]
xfw = int(XF * SR / H); tailw = int(TAIL * SR / H)
best = None
for i in range(0, min(int(25 * SR / H), nw)):
    fi, ri = F[i]
    if ri < 0.03 or i + xfw + tailw >= len(F): continue
    for j in range(i + int(MINLOOP * SR / H), len(F) - xfw):
        fj, rj = F[j]
        ri2 = F[i + xfw][1]; rj2 = F[j + xfw][1] if j + xfw < len(F) else rj
        cost = np.linalg.norm(fi - fj) + 25 * abs(np.log((ri2 + 1e-4) / (rj + 1e-4))) + 10 * abs(np.log((ri + 1e-4) / (rj + 1e-4)))
        if best is None or cost < best[0]: best = (cost, i, j)
_, i, j = best
si, sj, n, tl = i * H, j * H, int(XF * SR), int(TAIL * SR)
t = np.linspace(0, np.pi / 2, n, dtype=np.float32)[:, None]
mixed = a[sj:sj + n] * np.cos(t) + a[si:si + n] * np.sin(t)
out = np.concatenate([a[:sj], mixed, a[si + n: si + n + tl]])
out *= np.float32(10 ** (GAIN / 20)); out /= max(1.0, np.abs(out).max() / 0.98)
fi = int(0.05 * SR); out[:fi] *= np.linspace(0, 1, fi, dtype=np.float32)[:, None]  # 50 ms de entrada, só no início natural
subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 'f32le', '-ac', '2', '-ar', str(SR), '-i', '-', '-c:a', 'libmp3lame', '-b:a', '192k', dst],
               input=out.astype(np.float32).tobytes(), check=True)
ls, le = (si + n) / SR, (sj + n) / SR
print(f'LOOP {ls:.6f} {le:.6f} file {len(out)/SR:.2f}s loop {le-ls:.2f}s intro {ls:.2f}s')
