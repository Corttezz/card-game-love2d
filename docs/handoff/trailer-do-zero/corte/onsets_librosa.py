import os, sys, json
import numpy as np
import librosa

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import importlib
ED = importlib.import_module(os.environ.get('TDZ_EDL', 'edl7'))

FPS = 60
CUTS = {'h_letal': 'LETHAL do gancho', 'e6_pouso': 'pouso do anjo', 'k_porta': 'portao', 'k_revoada_rei': 'Revoada', 'k_golpe': 'golpe', 'k_queda': 'queda', 'k_coringa': 'coringa', 'logo': 'logo'}
src = os.path.join(ED.OUT, 'music_rei.wav' if ED.VARIANT == 'rei' else 'music_tirano.wav')
y, sr = librosa.load(src, sr=22050, mono=True)
hop = 256
env = librosa.onset.onset_strength(y=y, sr=sr, hop_length=hop)
on = librosa.onset.onset_detect(onset_envelope=env, sr=sr, hop_length=hop, units='frames', backtrack=False)
ot = librosa.frames_to_time(on, sr=sr, hop_length=hop)
os_ = env[on]
p75 = float(np.percentile(os_, 75))
C = {c['id']: c for c in ED.CLIPS}
sil = getattr(ED, 'SIL6', None)
rows = []
for cid, nome in CUTS.items():
    t = C[cid]['t0']
    near = np.abs(ot - t) <= 0.6
    if near.any():
        cand = np.flatnonzero(near)
        k = cand[np.argmax(os_[cand])]
        kk = cand[np.argmin(np.abs(ot[cand] - t))]
    else:
        k = kk = int(np.argmin(np.abs(ot - t)))
    nt, ns = float(ot[kk]), float(os_[kk])
    bt, bs = float(ot[k]), float(os_[k])
    dist = round((nt - t) * FPS, 1)
    forte = ns >= p75
    bdist = round((bt - t) * FPS, 1)
    if abs(bdist) <= 2 and bs >= p75 - 0.005:
        acao = 'manter (no ataque forte)'
    elif bs < p75 - 0.005:
        acao = f'manter (nenhum ataque forte em +-0,6 s; o mais forte tem {bs:.2f})'
    else:
        acao = f'mover para {bt:.3f} s (ataque mais forte em +-0,6 s, forca {bs:.2f})'
    rows.append(dict(corte=nome, id=cid, t=round(t, 3), onset_proximo=round(nt, 3), dist_quadros=dist, forca=round(ns, 2), forte=bool(forte),
                     melhor=round(bt, 3), forca_melhor=round(bs, 2), acao=acao))
out = os.path.join(ED.OUT, f'onsets_librosa_{ED.VARIANT}.json')
json.dump(dict(p75=round(p75, 2), rows=rows), open(out, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print('| corte | t do corte (s) | onset mais proximo (s) | distancia (quadros) | forca (p75 = %.2f) | acao |' % p75)
print('|---|---|---|---|---|---|')
for r in rows:
    print(f"| {r['corte']} | {r['t']:.3f} | {r['onset_proximo']:.3f} | {r['dist_quadros']:+.1f} | {r['forca']:.2f}{' (forte)' if r['forte'] else ''} | {r['acao']} |")
