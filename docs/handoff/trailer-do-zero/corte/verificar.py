import os, sys, subprocess
import numpy as np, cv2
V = sys.argv[1]
P = sys.argv[2]
os.makedirs(P, exist_ok=True)
cap = cv2.VideoCapture(V)
fps = cap.get(cv2.CAP_PROP_FPS)
dark = []
n = 0
while True:
    ok, f = cap.read()
    if not ok:
        break
    if cv2.cvtColor(f, cv2.COLOR_BGR2GRAY)[60:1020, 90:1830].mean() / 255 < 0.05:
        dark.append(round(n / fps, 3))
    n += 1
print('quadros < 5% de luma:', len(dark), dark[:20])
def grab(t, name, crop=None):
    out = os.path.join(P, f'{name}_{t:.2f}s.png')
    vf = ['scale=iw:ih']
    if crop:
        vf = [f'crop={crop}']
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-ss', f'{t:.3f}', '-i', V, '-frames:v', '1', '-vf', ','.join(vf), out], check=True)
    return out
def sheet(t0, t1, step, name, crop=None, w=320):
    vf = f'fps={1/step},' + (f'crop={crop},' if crop else '') + f'scale={w}:-2,tile={int(round((t1-t0)/step))}x1'
    out = os.path.join(P, f'{name}_{t0:.2f}-{t1:.2f}s.png')
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-ss', f'{t0:.3f}', '-t', f'{t1-t0:.3f}', '-i', V, '-vf', vf, '-frames:v', '1', out], check=True)
    return out
for a in sys.argv[3:]:
    kind, rest = a.split('=', 1)
    if kind == 'grab':
        t, name = rest.split(':')[:2]; crop = ':'.join(rest.split(':')[2:]) or None
        print(grab(float(t), name, crop))
    elif kind == 'sheet':
        t0, t1, step, name = rest.split(':')[:4]; crop = ':'.join(rest.split(':')[4:]) or None
        print(sheet(float(t0), float(t1), float(step), name, crop))
