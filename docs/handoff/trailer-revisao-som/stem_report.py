import sys, os, subprocess, json
import numpy as np
from PIL import Image, ImageDraw

SR = 48000
name = sys.argv[1]
marks = json.loads(sys.argv[2]) if len(sys.argv) > 2 else []
od = os.path.join(r'E:\dev\projects\card-game-trailer\build\trailer\som', name)


def rd(p):
    raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', p, '-f', 'f32le', '-ac', '1', '-ar', str(SR), '-'], capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.float32)


def curve(x, win=0.1):
    h = int(win * SR); k = len(x) // h
    return 10 * np.log10((x[:k * h].reshape(k, h) ** 2).mean(1) + 1e-10)


names = ['music', 'game_sfx', 'game_amb', 'synth']
st = {n: curve(rd(os.path.join(od, f'stem_{n}.wav'))) for n in names}
mix = curve(rd(os.path.join(od, 'mix.wav')))
t = np.arange(len(mix)) * 0.1
W, H, X = 2400, 700, 40
im = Image.new('RGB', (W, H), 'white'); d = ImageDraw.Draw(im)
px = lambda tt: X + tt / t[-1] * (W - 2 * X)
py = lambda v, top, h: top + h * (min(0, max(-60, v)) / -60)
for s_ in range(int(t[-1]) + 1):
    d.line([(px(s_), 0), (px(s_), H)], fill=(225, 225, 225)); d.text((px(s_) + 2, H - 12), str(s_), fill='black')
for n, c in zip(names, [(140, 140, 140), (220, 40, 40), (40, 160, 40), (50, 90, 210)]):
    v = st[n]; d.line([(px(i * 0.1), py(v[i], 10, 380)) for i in range(len(v))], fill=c, width=2)
v = mix; d.line([(px(i * 0.1), py(v[i], 420, 250)) for i in range(len(v))], fill='black', width=2)
for m in marks:
    d.line([(px(m[0]), 0), (px(m[0]), H - 14)], fill=(255, 150, 0)); d.text((px(m[0]) + 2, 12), m[1][:12], fill=(200, 100, 0))
d.text((5, 395), 'cinza=musica vermelho=sfx jogo verde=ambiente azul=sintese | preto=mix (0 a -60 dB)', fill='black')
p = os.path.join(od, 'stems.png'); im.save(p)
print(p)
for m in marks:
    i = int(m[0] / 0.1)
    sl = slice(i, i + 4)
    row = {n: round(float(st[n][sl].max()), 1) for n in names}
    print(f"{m[0]:6.2f} {m[1][:28]:28s} " + ' '.join(f"{n}={v:6.1f}" for n, v in row.items()), 'game-music', round(max(row['game_sfx'], row['game_amb']) - row['music'], 1))
