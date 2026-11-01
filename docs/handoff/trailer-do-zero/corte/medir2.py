import sys, re, subprocess, json, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import edl2 as ED
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
print('groove antes da porta S:', round(mx(C['k_estrada']['t0'], s0, 2), 1))
print('golpe M:', round(mx(g, g + 0.7), 1), ' maior M fora do golpe:', round(max(r[1] for r in rows if not g - 0.1 <= r[0] <= g + 1.5), 1))
pk = max(mx(t, t + 1, 2) for t in range(int(g), int(g) + 4)); out = max(mx(t, t + 1, 2) for t in range(2, int(g) - 1))
print('pico S', round(pk, 1), 'maior S fora', round(out, 1), 'margem', round(pk - out, 1))
out = subprocess.run(['ffmpeg', '-i', mp4, '-af', 'ebur128=peak=true', '-f', 'null', '-'], capture_output=True, text=True).stderr
print([l.strip() for l in out.splitlines() if re.match(r'\s+(I|LRA|Peak):', l)][-3:])
L = json.load(open(os.path.join(ED.OUT, 'zero2_' + ED.VARIANT, 'mix_sources.json'), encoding='utf-8'))
for code in ['castleGateOpen', 'bossLandImpact', 'bossRevealSting']:
    print(code, [x['t'] for x in L if x['code'].startswith(code)])
inside = [(c['t0'], c['t1']) for c in ED.CLIPS if c['id'] in ('k_escuro', 'k_nome', 'k_guerreiro', 'k_revoada_rei', 'k_volta', 'k_letal', 'k_golpe', 'k_coringa')]
print('clima externo no castelo:', [x['code'] for x in L if x['group'] == 'ambient' and not x['code'].startswith('pl:boss') and any(a <= x['t'] < b for a, b in inside)])
print('antes da musica:', [x['code'] for x in L if x['t'] < ED.MUSIC_IN_FILM])
