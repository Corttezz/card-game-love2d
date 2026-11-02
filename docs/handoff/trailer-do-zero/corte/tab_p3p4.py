import sys, os, numpy as np, librosa
B = r'E:/dev/projects/card-game-trailer/build/trailer/zero6_rei'
def onsets(path, a, b):
    y, sr = librosa.load(path, sr=22050, mono=True)
    env = librosa.onset.onset_strength(y=y, sr=sr, hop_length=256)
    on = librosa.onset.onset_detect(onset_envelope=env, sr=sr, hop_length=256)
    t = librosa.frames_to_time(on, sr=sr, hop_length=256); s = env[on]
    p75 = np.percentile(s, 75)
    m = (t >= a) & (t <= b)
    return [(round(float(x), 3), round(float(v), 2), v >= p75) for x, v in zip(t[m], s[m])], round(float(p75), 2)
print('### Ponto 3: onsets da variante do Rei entre 49,3 e 51,3 s')
for nome, f in (('faixa montada (music_rei.wav, sem automacao)', B + '/music_rei.wav'), ('mixagem final (mix.wav, com o respiro em -inf)', B + '/zero6_rei_rei/mix.wav')):
    L, p = onsets(f, 49.3, 51.3)
    print(f'\n{nome}, p75 = {p}\n\n| onset (s) | forca | forte | distancia ao golpe 50,36 (quadros) |\n|---|---|---|---|')
    for t, s, fo in L:
        print(f'| {t:.3f} | {s:.2f} | {"sim" if fo else ""} | {(t - 50.36) * 60:+.1f} |')
