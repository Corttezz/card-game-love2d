import subprocess, numpy as np, sys, os, json, re
sys.path.insert(0, '.')
import edl5
C = {c['id']: c for c in edl5.CLIPS}; v = edl5.VARIANT
T = os.path.join(edl5.OUT, os.path.basename(edl5.OUT) + '_' + v)
def rms(f, a, b):
    x = np.frombuffer(subprocess.run(['ffmpeg', '-v', 'error', '-ss', str(a), '-t', str(b - a), '-i', f, '-f', 'f32le', '-ac', '1', '-'], capture_output=True).stdout, np.float32)
    return round(float(20 * np.log10(np.sqrt((x ** 2).mean()) + 1e-9)), 1)
cr = C['k_coringa']
m, s = rms(T + '/stem_music.wav', cr['t0'], cr['t1']), rms(T + '/stem_game_sfx.wav', cr['t0'], cr['t1'])
S = json.load(open(T + '/mix_sources.json', encoding='utf-8'))
print(v, 'coringa: musica', m, 'sfx', s, 'musica abaixo do sfx', round(s - m, 1), '| revelacao em', [x['t'] for x in S if 'revelacao do coringa' in x['code']], 'plano', cr['t0'])
r = subprocess.run(['ffmpeg', '-v', 'info', '-i', T + '/mix.wav', '-af', 'ebur128', '-f', 'null', '-'], capture_output=True, text=True).stderr
rows = [tuple(float(x) for x in mm) for mm in re.findall(r't:\s*([\d.]+).*?S:\s*(-?[\d.]+)', r)]
g = C['k_golpe']['t0']
pk = max(sv for t, sv in rows if g <= t <= g + 4); out = max(sv for t, sv in rows if 2 <= t <= g - 1)
print(' pico S', pk, 'maior fora', out, 'margem', round(pk - out, 1), '| LRA', re.findall(r'LRA:\s+([\d.]+)', r)[-1])
