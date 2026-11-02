import os, sys, json, importlib
import numpy as np, librosa
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault('TDZ_NO_SNAP', '0')
ED = importlib.import_module('edl10')
FPS = 60
src = os.path.join(ED.R, 'build', 'trailer', 'zero9_rei' if ED.VARIANT == 'rei' else 'zero9', 'music_rei.wav' if ED.VARIANT == 'rei' else 'music_tirano.wav')
y, sr = librosa.load(src, sr=22050, mono=True)
env = librosa.onset.onset_strength(y=y, sr=sr, hop_length=256)
tt = librosa.frames_to_time(np.arange(len(env)), sr=sr, hop_length=256)
med = float(np.median(env))
import scipy.signal as ss
pk, _ = ss.find_peaks(env, distance=6)
pk = pk[env[pk] / med >= 2.0]
ot, os_ = tt[pk], env[pk] / med
_, beats = librosa.beat.beat_track(onset_envelope=env, sr=sr, hop_length=256)
bt = librosa.frames_to_time(beats, sr=sr, hop_length=256)
sil = ED.SIL6 if ED.VARIANT == 'tirano' else ED.REI['sil']
EV = {'h_letal': ('LETHAL aparece', 2.817 if ED.VARIANT == 'tirano' else 2.633), 'k_dreno': ('vida 70 comeca a cair', round([c for c in ED.CLIPS if c['id'] == 'k_dreno'][0]['t0'] + 0.014 if ED.VARIANT == 'tirano' else 40.739, 3))}
rows = []
for c in ED.CLIPS[1:]:
    t = c['t0']
    if sil[0] + 0.05 < t < sil[1] - 0.05:
        rows.append((c['id'], t, None, None, None, 'silencio da entrada do chefe (sem musica)'))
        continue
    w = np.abs(ot - t) <= 0.3
    if w.any():
        j = np.flatnonzero(w)[np.argmin(np.abs(ot[w] - t))]
        on = (round(float(ot[j]), 3), round((ot[j] - t) * FPS, 1), round(float(os_[j]), 1))
    else:
        on = (None, None, None)
    b = bt[np.argmin(np.abs(bt - t))]
    rows.append((c['id'], t, *on, f'batida {b:.3f} ({(b - t) * FPS:+.1f} q)'))
out = [f'# Cortes x onsets, {ED.VARIANT} (corte 10)', '', f'Faixa: `{src}` (a mesma do corte 9; o corte 10 nao mexe na musica). Onset = pico do fluxo espectral (librosa, >= 2x a mediana) mais proximo em +-0,3 s; batida = `beat_track`.', '',
       '| plano | corte (s) | onset (s) | desvio (quadros) | forca (x mediana) | observacao |', '|---|---|---|---|---|---|']
for r in rows:
    out.append('| ' + ' | '.join('' if x is None else str(x) for x in r) + ' |')
out += ['', '| evento | t (s) | onset mais proximo | desvio (quadros) |', '|---|---|---|---|']
for k, (nome, t) in EV.items():
    j = int(np.argmin(np.abs(ot - t)))
    out.append(f'| {nome} | {t} | {ot[j]:.3f} ({os_[j]:.1f}x) | {(ot[j] - t) * FPS:+.1f} |')
p = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'corte10_provas', f'onsets_{ED.VARIANT}_corte10.md')
os.makedirs(os.path.dirname(p), exist_ok=True)
open(p, 'w', encoding='utf-8').write('\n'.join(out) + '\n')
print('\n'.join(out))
