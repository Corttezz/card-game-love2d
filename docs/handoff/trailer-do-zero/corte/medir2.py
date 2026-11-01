import sys, re, subprocess, json, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib
ED = importlib.import_module(os.environ.get('TDZ_EDL', 'edl2'))
mp4, wav = sys.argv[1], sys.argv[2]
r = subprocess.run(['ffmpeg', '-v', 'info', '-i', wav, '-af', 'ebur128', '-f', 'null', '-'], capture_output=True, text=True).stderr
rows = []
for l in r.splitlines():
    m = re.search(r't:\s*([\d.]+).*M:\s*(-?[\d.inf]+)\s+S:\s*(-?[\d.inf]+)', l)
    if m:
        rows.append(tuple(-99.0 if 'inf' in x else float(x) for x in m.groups()))
C = {c['id']: c for c in ED.CLIPS}
def mx(a, b, i=1): return max(r[i] for r in rows if a <= r[0] <= b)
s0, s1, g = C['ia_hall1']['t0'], C['k_nome']['t0'], C['k_golpe']['t0']
print('silencio S (curto prazo) 1 s a 1 s:', [round(mx(t, t + 0.99, 2), 1) for t in range(int(s0) + 1, int(s1))])
print('groove antes da porta S:', round(mx(C.get('k_estrada', C['k_porta'])['t0'] - 2, s0, 2), 1))
print('golpe M:', round(mx(g, g + 0.7), 1), ' maior M fora do golpe:', round(max(r[1] for r in rows if not g - 0.1 <= r[0] <= g + 1.5), 1))
pk = max(mx(t, t + 1, 2) for t in range(int(g), int(g) + 4)); out = max(mx(t, t + 1, 2) for t in range(2, int(g) - 1))
print('pico S', round(pk, 1), 'maior S fora', round(out, 1), 'margem', round(pk - out, 1))
out = subprocess.run(['ffmpeg', '-i', mp4, '-af', 'ebur128=peak=true', '-f', 'null', '-'], capture_output=True, text=True).stderr
print([l.strip() for l in out.splitlines() if re.match(r'\s+(I|LRA|Peak):', l)][-3:])
L = json.load(open(os.path.join(ED.OUT, os.path.basename(ED.OUT) + '_' + ED.VARIANT, 'mix_sources.json'), encoding='utf-8'))
for code in ['castleGateOpen', 'bossLandImpact', 'bossRevealSting']:
    print(code, [x['t'] for x in L if x['code'].startswith(code)])
inside = [(c['t0'], c['t1']) for c in ED.CLIPS if c['id'] in ('k_escuro', 'k_nome', 'k_guerreiro', 'k_revoada_rei', 'k_revoada_vida', 'k_volta', 'k_letal_mao', 'k_letal', 'k_golpe', 'k_coringa')]
print('clima externo no castelo:', [x['code'] for x in L if x['group'] == 'ambient' and not x['code'].startswith('pl:boss') and any(a <= x['t'] < b for a, b in inside)])
print('antes da musica:', [x['code'] for x in L if x['t'] < ED.MUSIC_IN_FILM])
import numpy as np
import onsets as O
stem = os.path.join(ED.OUT, os.path.basename(ED.OUT) + '_' + ED.VARIANT, 'stem_music.wav')
x = O.load_mono(stem)
hop = 240
n = len(x) // hop
rms = 20 * np.log10(np.sqrt((x[:n * hop].reshape(n, hop) ** 2).mean(1)) + 1e-9)
tt = np.arange(n) * hop / O.SR
def rise(t0):
    best = -99.0
    for i in np.flatnonzero((tt >= t0 - 0.03) & (tt <= t0 + 0.03)):
        lo = rms[max(0, i - 10):i].min() if i > 0 else rms[i]
        best = max(best, rms[i] - lo)
    return best
print('cortes x subida da musica no stem (dB em +-30 ms):')
fracos = []
for c in ED.CLIPS[1:]:
    v = rise(c['t0'])
    sil = s0 - 0.05 < c['t0'] < s1 - 0.05
    tag = 'silencio' if sil else ('ok' if v >= 10 else 'FRACO')
    if tag == 'FRACO':
        fracos.append((c['id'], round(v, 1)))
    print(f"  {c['t0']:6.2f} {c['id']:16s} {v:5.1f} dB {tag}")
print('fracos:', fracos)
