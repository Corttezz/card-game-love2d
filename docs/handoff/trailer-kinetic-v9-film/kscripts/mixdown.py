# mixdown.py <film>: the soundtrack from the EDL: boss-carrion_king.mp3 (ACE-Step, the only music) and build/trailer/sfx_synth
# (local synthesis), shifted by TRIM, then a two-pass loudnorm to -14 LUFS. Writes out/mix.wav and out/mix_sources.json.
import sys, os, json, subprocess, re
import numpy as np
R = r'E:\dev\projects\card-game-trailer'
film = sys.argv[1]
TRIM, DUR, SR = 0.5, 64.5, 48000
ALLOWED = ('audio/music/boss-carrion_king.mp3', 'build/trailer/sfx_synth/')
edl = json.load(open(os.path.join(R, 'build', 'trailer', 'kinetic', 'C_edl.json'), encoding='utf-8'))

def load(rel):
    assert rel.startswith(ALLOWED), rel
    raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', os.path.join(R, rel), '-f', 'f32le', '-ac', '2', '-ar', str(SR), '-'], capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.float32).reshape(-1, 2)

n = round(DUR * SR)
mix = np.zeros((n, 2), np.float32)
sources = []
m = edl['music']
music = load(m['path'])
t_in = m['t'] - TRIM
seg = music[round(m['in'] * SR):round(m['out'] * SR)]
a = round(t_in * SR)
seg = seg[:n - a].copy()
f0, f1 = round((m['fade_out']['t0'] - TRIM) * SR) - a, round((m['fade_out']['t1'] - TRIM) * SR) - a
env = np.ones(len(seg), np.float32)
env[f0:f1] = np.linspace(1, 0, f1 - f0, dtype=np.float32); env[f1:] = 0
mix[a:a + len(seg)] += seg * env[:, None]
sources.append({'file': m['path'], 'kind': 'music', 'license': m['license'], 'track_in': m['in'], 'track_out': m['out'], 't': round(t_in, 3)})
cache = {}
# gain trims after measuring each hit against the music under it (whooshes sat ~20 dB under the grave)
TRIMDB = {'whoosh_2.wav': 11, 'whoosh_1.wav': 10, 'logo_seal.wav': 4, 'glitch.wav': 3, 'impact_1.wav': 2}
for s in edl['sfx']:
    if s['file'] not in cache: cache[s['file']] = load(s['file'])
    g = s['gain_db'] + TRIMDB.get(os.path.basename(s['file']), 0)
    x = cache[s['file']] * (10 ** (g / 20))
    st = s['start_t'] - TRIM
    skip = max(0, round(-st * SR)); p = max(0, round(st * SR))
    x = x[skip:skip + n - p]
    mix[p:p + len(x)] += x
    sources.append({'file': s['file'], 'kind': 'sfx', 'license': 'sintese local (tools/synth_trailer_sfx.py)', 't': round(max(st, 0), 3), 'event_t': round(s['event_t'] - TRIM, 3), 'gain_db_edl': s['gain_db'], 'gain_db': g, 'what': s['what']})
os.makedirs(os.path.join(film, 'out'), exist_ok=True)
pre = os.path.join(film, 'out', 'mix_pre.wav')
subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 'f32le', '-ar', str(SR), '-ac', '2', '-i', '-', '-c:a', 'pcm_f32le', pre], input=mix.tobytes(), check=True)
r = subprocess.run(['ffmpeg', '-i', pre, '-af', 'loudnorm=I=-14:TP=-1:LRA=11:print_format=json', '-f', 'null', '-'], capture_output=True, text=True).stderr
j = json.loads(r[r.rindex('{'):r.rindex('}') + 1])
flt = (f"loudnorm=I=-14:TP=-1:LRA=11:measured_I={j['input_i']}:measured_TP={j['input_tp']}:measured_LRA={j['input_lra']}"
       f":measured_thresh={j['input_thresh']}:offset={j['target_offset']}:linear=true")
out = os.path.join(film, 'out', 'mix.wav')
subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', pre, '-af', flt + f',aresample={SR}', '-t', str(DUR), '-c:a', 'pcm_s24le', out], check=True)
json.dump(sources, open(os.path.join(film, 'out', 'mix_sources.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
r = subprocess.run(['ffmpeg', '-i', out, '-af', 'ebur128=peak=true', '-f', 'null', '-'], capture_output=True, text=True).stderr
print(out, 'I', re.findall(r'I:\s+(-?[\d.]+) LUFS', r)[-1], 'LUFS; peak', re.findall(r'Peak:\s+(-?[\d.]+) dBFS', r)[-1], 'dBTP; input was', j['input_i'])
