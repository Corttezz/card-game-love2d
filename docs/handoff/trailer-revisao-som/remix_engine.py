import os, json, subprocess, re
import numpy as np
from scipy.signal import butter, sosfiltfilt

R = r'E:\dev\projects\card-game-trailer'
KF = r'E:\dev\_orquestracao\skills-externas\kinetic-film'
LOG = os.path.join(os.environ['APPDATA'], 'LOVE', 'card-game-trailer-v9', 'trailer', 'audio.jsonl')
OUT = os.path.join(R, 'build', 'trailer', 'som')
SR = 48000
_cache = {}

ELEVEN = ('audio/sfx/',)
LICENSE = {
    'audio/music/boss-': 'ACE-Step 1.5 local, uso comercial',
    'build/trailer/sfx_synth/': 'sintese local (tools/synth_trailer_sfx.py), sem licenca de terceiros',
    'audio/sfx/': 'SFX do jogo gerado no ElevenLabs free: SEM uso comercial confirmado',
    'audio/hoverCard.wav': 'origem nao documentada',
    'audio/clickselect2-92097.mp3': 'padrao Pixabay pelo nome, origem nao documentada',
    'audio/sword-sound-260274.mp3': 'padrao Pixabay pelo nome, origem nao documentada',
    'audio/punching-light-armour-87442.mp3': 'padrao Pixabay pelo nome, origem nao documentada',
}


def license_of(rel):
    for k, v in LICENSE.items():
        if rel.startswith(k):
            return v
    return 'origem nao documentada'


def load(rel):
    if rel not in _cache:
        raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', os.path.join(R, rel), '-f', 'f32le', '-ac', '2', '-ar', str(SR), '-'],
                             capture_output=True, check=True).stdout
        _cache[rel] = np.frombuffer(raw, np.float32).reshape(-1, 2).copy()
    return _cache[rel]


def repitch(x, p):
    if p is None or p <= 0 or abs(p - 1) < 1e-3:
        return x
    n = int(len(x) / p)
    src = np.arange(n) * p
    i = np.arange(len(x))
    return np.stack([np.interp(src, i, x[:, c]) for c in range(2)], 1).astype(np.float32)


def db(v):
    return 10 ** (v / 20)


def frame_to_t(mp, f):
    ts = [a for a, _ in mp]; fs = [b for _, b in mp]
    if f <= fs[0]:
        k = (ts[1] - ts[0]) / (fs[1] - fs[0]); return ts[0] + (f - fs[0]) * k
    if f >= fs[-1]:
        k = (ts[-1] - ts[-2]) / (fs[-1] - fs[-2]); return ts[-1] + (f - fs[-1]) * k
    return float(np.interp(f, fs, ts))


def events():
    ev = {}
    for line in open(LOG, encoding='utf-8'):
        d = json.loads(line)
        if d.get('kind') == 'sfx' and d.get('path'):
            ev.setdefault(d['shot'], []).append(d)
    return ev


def envelope(keys, n, default=0.0):
    if not keys:
        return np.full(n, default, np.float32)
    ts = np.array([k[0] for k in keys]) * SR
    vs = np.array([k[1] for k in keys], np.float64)
    return np.interp(np.arange(n), ts, vs).astype(np.float32)


def place(buf, x, p, fade_in=0, fade_out_at=None, fade_len=0):
    x = x.copy()
    if fade_in > 0:
        m = min(fade_in, len(x)); x[:m] *= np.linspace(0, 1, m, dtype=np.float32)[:, None]
    if fade_out_at is not None and fade_out_at < len(x):
        e = min(len(x), fade_out_at + fade_len)
        if e > fade_out_at:
            x[fade_out_at:e] *= np.linspace(1, 0, e - fade_out_at, dtype=np.float32)[:, None]
        x[e:] = 0; x = x[:e]
    skip = max(0, -p); p = max(0, p)
    x = x[skip:]
    x = x[:max(0, len(buf) - p)]
    buf[p:p + len(x)] += x


LONG_TAIL = ('castleGateOpen', 'bossLandImpact', 'bossRevealSting', 'bossEyesIgnite', 'crow', 'enemyVoice', 'impact', 'sting_',
             'entrance_', 'wx:thunder', 'bossWingPass', 'bossFeathersSettle', 'cashOutChime', 'packSealBreak', 'cardDiscovered')


def game_stem(edl, plan, n, log):
    ev = events()
    sfx = np.zeros((n, 2), np.float32); amb = np.zeros((n, 2), np.float32)
    code_db = plan.get('code_db', {}); clip_db = plan.get('clip_db', {}); mute = plan.get('mute_codes', [])
    amb_clip_db = plan.get('amb_clip_db', {})
    for clip in edl['clips']:
        src = clip.get('src') or ''
        if not src.startswith('take:') or clip['id'] in plan.get('skip_clips', []):
            continue
        shot = src[5:]; t0, t1 = clip['t0'], clip['t1']
        cut_ext = plan.get('clip_tail', {}).get(clip['id'], 0.0)
        for e in ev.get(shot, []):
            code = e['code']
            group = e.get('group')
            if any(code.startswith(m) for m in mute):
                continue
            t = frame_to_t(clip['map'], e['f'])
            if plan.get('no_carry') and group != 'ambient' and t < t0 - 0.02:
                continue
            if t < plan.get('clip_mute_until', {}).get(clip['id'], -1e9):
                continue
            only = plan.get('amb_only', {}).get(clip['id'])
            if only is not None and group == 'ambient' and not any(code.startswith(k) for k in only):
                continue
            cw = [w for k, w in plan.get('code_window', {}).get(clip['id'], {}).items() if code.startswith(k)]
            ct1 = min([w[1] for w in cw] + [t1])
            if t >= ct1:
                continue
            x = repitch(load(e['path']), e.get('pitch'))
            dur = len(x) / SR
            if t >= t1 or t + dur <= t0:
                continue
            group = e.get('group')
            is_amb = group == 'ambient'
            vol = e['volume'] if e.get('volume', -1) >= 0 else e['base']
            g = vol * db(plan.get('group_db', {}).get(group, 0))
            g *= db(clip_db.get(clip['id'], 0))
            if is_amb:
                g *= db(amb_clip_db.get(clip['id'], 0))
            for k, v in code_db.items():
                if code.startswith(k):
                    g *= db(v)
            if g <= 0:
                continue
            p = int(round(t * SR))
            head = int(round(max(0.0, t0 - t) * SR))
            if ct1 < t1:
                tail, flen = ct1, 0.25
            elif is_amb:
                tail, flen = t1 + cut_ext, 0.06
            else:
                long = any(k in code for k in LONG_TAIL)
                tail, flen = t1 + (plan.get('long_tail', 1.2) if long else 0.12), (0.5 if long else 0.08)
            fo = int(round((tail - t) * SR))
            y = x * g
            if head > 0:
                y = y[head:]; p += head; fo -= head
            place(amb if is_amb else sfx, y, p, fade_in=int(0.03 * SR) if head > 0 else 0, fade_out_at=fo, fade_len=int(flen * SR))
            log.append({'t': round(max(t, t0), 3), 'clip': clip['id'], 'code': code, 'file': e['path'], 'group': group,
                        'gain_db': round(20 * np.log10(g), 1), 'license': license_of(e['path'])})
    return sfx, amb


def extras(plan, n, log):
    buf = np.zeros((n, 2), np.float32); amb = np.zeros((n, 2), np.float32)
    for x in plan.get('extra', []):
        y = repitch(load(x['file']), x.get('pitch'))
        if x.get('in'):
            y = y[int(x['in'] * SR):]
        if x.get('loop') and x.get('len'):
            xf = int(0.5 * SR); need = int(x['len'] * SR); z = y.copy()
            while len(z) < need:
                r = np.linspace(0, 1, xf, dtype=np.float32)[:, None]
                z = np.concatenate([z[:-xf], z[-xf:] * (1 - r) + y[:xf] * r, y[xf:]])
            y = z
        if x.get('len'):
            y = y[:int(x['len'] * SR)]
            m = min(len(y), int(x.get('fade', 0.3) * SR)); y = y.copy(); y[len(y) - m:] *= np.linspace(1, 0, m, dtype=np.float32)[:, None]
        g = db(x.get('db', 0))
        if x.get('lp'):
            y = lowpass(y, x['lp'])
        place(amb if x.get('amb') else buf, y * g, int(round(x['t'] * SR)), fade_in=int(x.get('fade_in', 0) * SR))
        log.append({'t': x['t'], 'clip': 'extra', 'code': x.get('what', ''), 'file': x['file'], 'group': 'extra',
                    'gain_db': x.get('db', 0), 'license': license_of(x['file'])})
    return buf, amb


def lowpass(x, hz):
    sos = butter(4, hz / (SR / 2), 'low', output='sos')
    return sosfiltfilt(sos, x, axis=0).astype(np.float32)


def sidechain(drive, n, thr_db, max_db, ratio, att=0.015, rel=0.35):
    hop = int(0.005 * SR)
    m = np.abs(drive).max(1)
    k = len(m) // hop
    pk = m[:k * hop].reshape(k, hop).max(1)
    lv = 20 * np.log10(pk + 1e-9)
    want = -np.clip((lv - thr_db) * ratio, 0, max_db)
    out = np.zeros(k); g = 0.0
    a = np.exp(-hop / (att * SR)); r = np.exp(-hop / (rel * SR))
    for i in range(k):
        c = a if want[i] < g else r
        g = c * g + (1 - c) * want[i]; out[i] = g
    gr = np.interp(np.arange(n), np.arange(k) * hop, out)
    return gr.astype(np.float32)


def run(plan):
    name = plan['name']
    od = os.path.join(OUT, name); os.makedirs(od, exist_ok=True)
    edl = json.load(open(os.path.join(R, 'build', 'trailer', 'kinetic', plan['edl']), encoding='utf-8'))
    dur = plan['dur']; n = int(round(dur * SR))
    log = []
    m = edl['music']
    music = np.zeros((n, 2), np.float32)
    seg = load(m['path'])[int(round(m['in'] * SR)):int(round(m['out'] * SR))]
    a = int(round(m['t'] * SR)); seg = seg[:n - a]
    music[a:a + len(seg)] = seg
    fo = m['fade_out']; fe = np.ones(n, np.float32)
    i0, i1 = int(fo['t0'] * SR), min(n, int(fo['t1'] * SR)); fe[i0:i1] = np.linspace(1, 0, i1 - i0); fe[i1:] = 0
    if plan.get('music_fade_out'):
        t0, t1 = plan['music_fade_out']; i0, i1 = int(t0 * SR), min(n, int(t1 * SR))
        fe = np.minimum(fe, np.concatenate([np.ones(i0), np.linspace(1, 0, i1 - i0) ** 2, np.zeros(n - i1)]).astype(np.float32))
    music *= fe[:, None]
    log.append({'t': m['t'], 'clip': 'music', 'code': 'music', 'file': m['path'], 'group': 'music', 'gain_db': 0, 'license': m['license']})
    muff = lowpass(music, plan.get('lp_hz', 700))
    lpmix = envelope(plan.get('music_lp', []), n)
    music = music * (1 - lpmix)[:, None] + muff * lpmix[:, None]
    gsfx, gamb = game_stem(edl, plan, n, log)
    xs, xa = extras(plan, n, log)
    gsfx += xs; gamb += xa
    synth = np.zeros((n, 2), np.float32)
    drop = plan.get('synth_drop', []); sdb = plan.get('synth_db', {})
    for s in edl['sfx']:
        w = s['what']
        if any(d in w for d in drop):
            continue
        g = s['gain_db'] + sum(v for k, v in sdb.items() if k in w) + plan.get('synth_all_db', 0)
        place(synth, load(s['file']) * db(g), int(round(s['start_t'] * SR)))
        log.append({'t': s['event_t'], 'clip': 'synth', 'code': w, 'file': s['file'], 'group': 'synth', 'gain_db': g, 'license': license_of(s['file'])})
    menv = envelope(plan.get('music_env', []), n)
    sc = plan.get('sidechain')
    if sc:
        menv = menv + sidechain(gsfx, n, sc['thr'], sc['max'], sc['ratio'])
    music *= db(menv)[:, None]
    gsfx *= db(plan.get('sfx_db', 0) + envelope(plan.get('sfx_env', []), n))[:, None]
    gamb *= db(plan.get('amb_db', 0) + envelope(plan.get('amb_env', []), n))[:, None]
    synth *= db(plan.get('synth_bus_db', 0))
    mix = music * db(plan.get('music_db', 0)) + gsfx + gamb + synth
    for nm, b in (('music', music * db(plan.get('music_db', 0))), ('game_sfx', gsfx), ('game_amb', gamb), ('synth', synth)):
        wav(os.path.join(od, f'stem_{nm}.wav'), b)
    pre = os.path.join(od, 'mix_pre.wav'); wav(pre, mix)
    out = os.path.join(od, 'mix.wav')
    I0, _ = measure(pre)
    g = -14.0 - I0
    for _ in range(4):
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', pre, '-af',
                        f'volume={g:.3f}dB,aresample=192000,alimiter=limit={db(plan.get('ceiling', -1.3)):.4f}:attack=1:release=60:level=disabled,aresample={SR}',
                        '-t', str(dur), '-c:a', 'pcm_s24le', out], check=True)
        I, P = measure(out)
        if abs(I + 14.0) <= 0.1 and P <= -1.0:
            break
        g += -14.0 - I
    j2 = {'normalization_type': 'ganho linear + limitador'}
    j = {'input_i': I0}
    json.dump(log, open(os.path.join(od, 'mix_sources.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    print(name, out, 'I', I, 'LUFS peak', P, 'dBTP norm', j2.get('normalization_type'), 'in', j['input_i'])
    return out


def measure(path):
    r = subprocess.run(['ffmpeg', '-i', path, '-af', 'ebur128=peak=true', '-f', 'null', '-'], capture_output=True, text=True).stderr
    return float(re.findall(r'I:\s+(-?[\d.]+) LUFS', r)[-1]), float(re.findall(r'Peak:\s+(-?[\d.]+) dBFS', r)[-1])


def wav(path, x):
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 'f32le', '-ar', str(SR), '-ac', '2', '-i', '-', '-c:a', 'pcm_f32le', path],
                   input=np.ascontiguousarray(x, np.float32).tobytes(), check=True)


def mux(video, audio, out, scale=None):
    if scale:
        cmd = ['ffmpeg', '-v', 'error', '-y', '-i', video, '-i', audio, '-map', '0:v', '-map', '1:a', '-vf', f'scale={scale}:flags=area',
               '-c:v', 'libx264', '-preset', 'slow', '-crf', '18', '-profile:v', 'high', '-pix_fmt', 'yuv420p', '-movflags', '+faststart',
               '-c:a', 'aac', '-b:a', '320k', '-ar', '48000', out]
    else:
        cmd = ['ffmpeg', '-v', 'error', '-y', '-i', video, '-i', audio, '-map', '0:v', '-map', '1:a', '-c:v', 'copy',
               '-c:a', 'aac', '-b:a', '320k', '-ar', '48000', '-movflags', '+faststart', out]
    subprocess.run(cmd, check=True)
    print('mux', out)
