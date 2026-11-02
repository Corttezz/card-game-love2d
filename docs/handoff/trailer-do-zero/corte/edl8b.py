import json, os

APP = os.environ['APPDATA']
TAKES = os.path.join(APP, 'LOVE', 'card-game-trailer-v9', 'trailer_zero')
R = r'E:\dev\projects\card-game-trailer'
AI = os.path.join(R, 'build', 'trailer', 'ai_4k')
REAL = r'E:\dev\projects\card-game-trailer-zero\assets\sprites\scenes'
VARIANT = os.environ.get('TDZ_MUSIC', 'tirano')
MUSICS = {
    'tirano': dict(path='audio/music/boss-abyss_tyrant.mp3', off=18.0, entry=1.11),
    'rei': dict(path='audio/music/boss-carrion_king.mp3', off=2.57, entry=0.55),
}
M = MUSICS[VARIANT]
MUSIC, OFF, MUSIC_IN_FILM = M['path'], M['off'], M['entry']
OUT = os.path.join(R, 'build', 'trailer', 'zero8b')
FPS = 60
DUR = 64.5

HAND_TOP = (480, 420)
CLIPS = [
    dict(id='h_mao', src='zero_hand', t0=0.00, t1=2.55, s0=10.26, z=2, crop=HAND_TOP),
    dict(id='h_letal', src='zero_hand', t0=2.55, t1=4.18, s0=12.81, z=2, crop=(880, 300),
         fx=dict(flash=(3.69, 6, 0.45), shake=(3.69, 8, 6))),
    dict(id='h_cascata', src='zero_hand', t0=4.18, t1=7.48, s0=14.44, z=2, crop=(340, 200)),
    dict(id='h_morte', src='zero_hand', t0=7.48, t1=8.60, s0=17.74, z=2, crop=(180, 150)),
    dict(id='espolio', src='zero_hand', t0=8.60, t1=11.69, s0=28.23, z=2, crop=(715, 290)),
    dict(id='e2_gargula', src='entr_moon_gargoyle', t0=11.69, t1=13.03, s0=7.86, z=1),
    dict(id='ia_hall3', src='ai:hall3_tyrant:castle_hall_3', t0=13.03, t1=16.24, s0=1.0, z=1),
    dict(id='t_correntes', src='zero_tyrant', t0=16.24, t1=18.54, s0=5.00, z=2, crop=(480, 240)),
    dict(id='e4_serpente', src='entr_ice_wyrm', t0=18.54, t1=20.82, s0=10.40, z=1),
    dict(id='ia_hall4', src='ai:hall4_ice:castle_hall_4', t0=20.82, t1=22.27, s0=2.0, z=1),
    dict(id='m_geada', src='zero_monarch', t0=22.27, t1=25.38, s0=4.80, z=2, crop=(480, 540)),
    dict(id='e5_esporo', src='entr_spore_mother', t0=25.38, t1=26.71, s0=8.40, z=1),
    dict(id='e6_anjo', src='entr_fallen_angel', t0=26.71, t1=28.24, s0=7.40, z=1),
    dict(id='e6_pouso', src='entr_fallen_angel', t0=28.24, t1=29.95, s0=8.90, z=2, crop=(480, 300)),
    dict(id='k_porta', src='zero_carrion', t0=29.95, t1=32.55, s0=8.70, z=2, crop=(480, 0)),
    dict(id='ia_hall1', src='ai:hall1_carrion:castle_hall_1', t0=32.55, t1=34.71, s0=1.5, z=1),
    dict(id='k_escuro', src='zero_carrion', t0=34.71, t1=39.44, s0=12.15, z=1, fx=dict(lift=(34.71, 60, 22))),
    dict(id='k_nome', src='zero_carrion', t0=39.44, t1=41.67, s0=16.88, z=1),
    dict(id='k_guerreiro', src='zero_carrion', t0=41.67, t1=44.08, s0=22.53, z=1),
    dict(id='k_revoada_rei', src='zero_carrion', t0=44.08, t1=45.48, s0=36.00, z=1),
    dict(id='k_vida', src='zero_carrion', t0=45.48, t1=48.27, s0=37.40, z=2, crop=(0, 540)),
    dict(id='k_mao', src='zero_carrion', t0=48.27, t1=50.19, s0=45.84, z=1),
    dict(id='k_letal', src='zero_carrion', t0=50.19, t1=52.83, s0=47.76, z=2, crop=(900, 500)),
    dict(id='k_golpe', src='zero_carrion', t0=52.83, t1=53.85, s0=52.95, z=2, crop=(480, 370), hold=3,
         fx=dict(flash=(52.83, 5, 0.75), shake=(52.88, 12, 12), number=('48', 52.83, 0.75))),
    dict(id='k_queda', src='zero_carrion', t0=53.85, t1=56.98, s0=53.92, z=3, crop=(640, 460),
         fx=dict(freeze=(54.18, 30), shake2=(55.28, 9, 9), dust=(55.28, 50))),
    dict(id='k_coringa', src='zero_carrion', t0=56.98, t1=58.20, s0=57.81, z=2, crop=(475, 165)),
    dict(id='logo', src='logo', t0=58.20, t1=DUR, s0=0, z=1),
]

TEXTS = [
    dict(id='cartas', lines=['145 LIVING CARDS.'], t0=8.60, t1=11.69, y=944, gold=[0], size=48),
    dict(id='atos', lines=['6 ACTS.'], t0=11.69, t1=13.03, y=110, gold=[0]),
    dict(id='regras', lines=['EVERY BOSS', 'BREAKS THE RULES.'], t0=13.03, t1=16.24, y=110, gold=[1], stagger=0.62),
    dict(id='correntes', lines=['CHAINS.'], t0=17.24, t1=18.54, y=880, gold=[0]),
    dict(id='criaturas', lines=['42 CREATURES.'], t0=18.54, t1=20.82, y=110, gold=[0]),
    dict(id='geada', lines=['FROST.'], t0=22.97, t1=25.20, y=110, gold=[0], xc=1500),
    dict(id='devolve', lines=['BREAK THEM BACK.'], t0=55.32, t1=56.98, y=60, gold=[0]),
]

D6 = 2.47
SIL6 = (30.08, 36.97)


def _c6():
    global LOGO
    out = []
    for c in CLIPS:
        if c['id'] == 'e6_anjo':
            continue
        if c['id'] == 'e5_esporo':
            c.update(t0=25.38, t1=26.38)
        elif c['id'] == 'e6_pouso':
            c.update(t0=26.38, t1=27.38, s0=8.95)
        elif c['id'] == 'k_porta':
            c.update(t0=27.38, t1=30.08)
        elif c['t0'] >= 32.55 - 1e-6:
            c['t0'] = round(c['t0'] - D6, 3); c['t1'] = round(c['t1'] - D6, 3)
            if c.get('fx'):
                c['fx'] = {k: ((round(v[0] - D6, 3),) + tuple(v[1:]) if k != 'number' else (v[0], round(v[1] - D6, 3)) + tuple(v[2:])) for k, v in c['fx'].items()}
        if c['id'] == 'ia_hall1':
            c['t0'] = 30.08
        out.append(c)
    CLIPS[:] = out
    C = {c['id']: c for c in CLIPS}
    g0 = C['k_golpe']['t0']
    C['k_golpe'].update(t1=round(g0 + 0.6, 3), hold=35, crop=(480, 370),
                        fx=dict(flash=(g0, 5, 0.75), shake=(g0 + 0.05, 12, 12), number=('48', g0, 0.6)))
    q0 = C['k_golpe']['t1']
    tf = round(q0 + 0.80, 3); imp = round(tf + 0.5 + 0.60, 3)
    C['k_queda'].update(t0=q0, t1=(55.22 if VARIANT == 'tirano' else 54.88), s0=53.45, fx=dict(freeze=(tf, 30), shake2=(imp, 9, 9), dust=(imp, 50), freeze2=(round(imp + 0.9, 3), 80 if VARIANT == 'tirano' else 50)))
    cr0 = C['k_queda']['t1']
    C['k_coringa'].update(t0=cr0, t1=(58.35 if VARIANT == 'tirano' else 58.30), s0=56.93, fx=dict(freeze=(57.70, 30)))
    C['logo']['t0'] = C['k_coringa']['t1']; C['logo']['t1'] = DUR
    for tx in TEXTS:
        if tx['t0'] >= 32.55 - 1e-6:
            tx['t0'] = round(tx['t0'] - D6, 3); tx['t1'] = round(tx['t1'] - D6, 3)
        if tx['id'] == 'devolve':
            tx['t0'] = round(imp + 0.88, 3); tx['t1'] = C['k_queda']['t1']
    l0 = C['logo']['t0']
    LOGO = dict(spin0=l0, seal_at=round(l0 + 0.23, 3), grimoire=round(l0 + 0.83, 3), genre=round(l0 + 1.63, 3), wishlist=round(l0 + 3.87, 3), fade0=63.0)



REI = dict(cA=2.57, jB=55.26, sil=SIL6, snap=0.8)


def _rei_snap():
    import numpy as np
    H = np.array([h['t'] for h in json.load(open(os.path.join(R, 'build', 'trailer', 'music', 'boss-carrion_king_beats.json')))['hits']])
    s0, s1 = REI['sil']
    def fmap(t):
        if t <= s0:
            return t + REI['cA']
        if t >= s1:
            return t - s1 + REI['jB']
        return None
    def snap(t):
        m = fmap(t)
        if m is None:
            return t
        d = H - m
        k = int(np.argmin(np.abs(d)))
        return round(t + d[k], 3) if abs(d[k]) <= REI['snap'] else t
    keep = {0.0, s0, s1, DUR} | {c['t0'] for c in CLIPS if c['id'] in ('k_golpe', 'k_queda', 'k_coringa', 'logo')}
    bounds = sorted({c['t0'] for c in CLIPS} | {CLIPS[-1]['t1']})
    new = {}
    prev = None
    for i, bd in enumerate(bounds):
        v = bd if bd in keep else snap(bd)
        nxt = bounds[i + 1] if i + 1 < len(bounds) else None
        if prev is not None and v - prev < 1.0:
            v = bd
        if nxt is not None and nxt - v < 1.0 and nxt not in keep and snap(nxt) - v < 1.0:
            v = bd
        new[bd] = v
        prev = v
    for c in CLIPS:
        d0 = new[c['t0']] - c['t0']
        if c.get('fx') and c.get('hold'):
            c['fx'] = {k: (v[0] if k == 'number' else round(v[0] + d0, 3),) + tuple(v[1:]) if k != 'number' else (v[0], round(v[1] + d0, 3)) + tuple(v[2:]) for k, v in c['fx'].items()}
        if c['src'] not in ('logo',) and not c['src'].startswith('ai:') and not c.get('hold'):
            c['s0'] = round(c['s0'] + d0, 3)
        c['t0'], c['t1'] = new[c['t0']], new[c['t1']]
    for tx in TEXTS:
        host = [c for c in CLIPS if c['id'] == tx['host']][0]
        need = max(1.2, len(' '.join(tx['lines'])) / 13.0 + 0.4)
        t0 = max(host['t0'], snap(host['t0'] + tx['dt'])) if tx['dt'] else host['t0']
        if host['t1'] - t0 < need:
            t0 = max(host['t0'], min(host['t0'] + tx['dt'], host['t1'] - need))
        tx['t0'], tx['t1'] = round(t0, 3), round(min(host['t1'], t0 + max(tx['len'], need)), 3)


LOGO = dict(spin0=58.20, seal_at=58.43, grimoire=59.03, genre=59.83, wishlist=62.07, fade0=63.0)
_c6()
CARD_BG_T = 55.25
TV_SKIP = 240
CUT = 'corte8'
OUT_NAME = 'corte8b'
FACE_T = 54.92 if VARIANT == 'rei' else None
NUMBER_Y = 40
HALL_GRID = (384, 216)
HALL_COLORS = 32
HALL_CLEAN = True
HALL_OUTLINE = 'silhueta'


for _tx in TEXTS:
    _h = [c for c in CLIPS if c['t0'] - 1e-6 <= _tx['t0'] and _tx['t1'] <= c['t1'] + 1e-6][0]
    _tx['host'], _tx['dt'], _tx['len'] = _h['id'], round(_tx['t0'] - _h['t0'], 3), round(_tx['t1'] - _tx['t0'], 3)
if VARIANT == 'rei':
    _rei_snap()
    _shift = {}
    for _k in ('spin0', 'seal_at', 'grimoire', 'genre', 'wishlist'):
        pass
    OUT = os.path.join(R, 'build', 'trailer', 'zero8b_rei')


WIN = {'e2_gargula': 0.8, 'ia_hall3': 0.8}


def _rise(t0):
    import numpy as np
    global _RMS
    if '_RMS' not in globals():
        import onsets as O
        src = os.path.join(OUT, 'music_rei.wav') if VARIANT == 'rei' else os.path.join(R, MUSIC)
        x = O.load_mono(src, 0.0 if VARIANT == 'rei' else OFF, DUR)
        hop = 240; n = len(x) // hop
        _RMS = (np.arange(n) * hop / O.SR, 20 * np.log10(np.sqrt((x[:n * hop].reshape(n, hop) ** 2).mean(1)) + 1e-9))
    tt, rms = _RMS
    best = -99.0
    for i in np.flatnonzero((tt >= t0 - 0.03) & (tt <= t0 + 0.03)):
        lo = rms[max(0, i - 10):i].min() if i > 0 else rms[i]
        best = max(best, rms[i] - lo)
    return best


def _snap_real(ids):
    import onsets as O
    cache = os.path.join(OUT, f'onsets_{VARIANT}.json')
    if os.path.exists(cache):
        d = json.load(open(cache))
        t, fl = __import__('numpy').array(d['t']), __import__('numpy').array(d['f'])
    else:
        if VARIANT == 'rei':
            t, fl = O.onset_curve(os.path.join(OUT, 'music_rei.wav'), 0.0, DUR)
        else:
            t, fl = O.onset_curve(os.path.join(R, MUSIC), OFF, DUR)
            t = t + 0.0
        os.makedirs(OUT, exist_ok=True)
        json.dump({'t': [float(v) for v in t], 'f': [float(v) for v in fl]}, open(cache, 'w'))
    for cid in ids:
        i = [k for k, c in enumerate(CLIPS) if c['id'] == cid][0]
        a, b = CLIPS[i - 1], CLIPS[i]
        lo, hi = a['t0'] + 1.25, b['t1'] - 1.25
        cand = [round(c, 3) for c in __import__('numpy').arange(b['t0'] - WIN.get(cid, 0.45), b['t0'] + WIN.get(cid, 0.45), 1 / FPS)]
        nt = max(cand, key=lambda c: _rise(c))
        nt = min(max(nt, lo), hi)
        d0 = nt - b['t0']
        if b['src'] not in ('logo',) and not b['src'].startswith('ai:') and not b.get('hold'):
            b['s0'] = round(b['s0'] + d0, 3)
        a['t1'] = b['t0'] = round(nt, 3)
    for tx in TEXTS:
        host = [c for c in CLIPS if c['id'] == tx['host']][0]
        need = max(1.2, len(' '.join(tx['lines'])) / 13.0 + 0.4)
        t0 = max(host['t0'], min(max(tx['t0'], host['t0']), host['t1'] - need))
        tx['t0'], tx['t1'] = round(t0, 3), round(min(host['t1'], max(tx['t1'], t0 + need)), 3)


if os.environ.get('TDZ_NO_SNAP') != '1' and (VARIANT == 'tirano' or os.path.exists(os.path.join(OUT, 'music_rei.wav'))):
    _snap_real(['ia_hall4'] if VARIANT == 'tirano' else ['e2_gargula', 'ia_hall3', 'ia_hall4', 'k_revoada_rei'])


REI_FIX = {'e2_gargula': 12.50}
TIR_B = 39.44 + 18.0
TIR_R = 65.97
if VARIANT == 'rei' and os.environ.get('TDZ_NO_SNAP') != '1' and os.path.exists(os.path.join(OUT, 'music_rei.wav')):
    for _cid, _t in REI_FIX.items():
        _i = [k for k, c in enumerate(CLIPS) if c['id'] == _cid][0]
        _a, _b = CLIPS[_i - 1], CLIPS[_i]
        _d = _t - _b['t0']
        _b['s0'] = round(_b['s0'] + _d, 3)
        _a['t1'] = _b['t0'] = _t
    for _tx in TEXTS:
        _h = [c for c in CLIPS if c['id'] == _tx['host']][0]
        _need = max(1.2, len(' '.join(_tx['lines'])) / 13.0 + 0.4)
        _t0 = max(_h['t0'], min(_tx['t0'], _h['t1'] - _need))
        _tx['t0'], _tx['t1'] = round(_t0, 3), round(min(_h['t1'], max(_tx['t1'], _t0 + _need)), 3)


REI_ONSET = {'k_queda': 50.78, 'k_coringa': 54.555}
if VARIANT == 'rei' and os.environ.get('TDZ_NO_SNAP') != '1':
    _C = {c['id']: c for c in CLIPS}
    _gq = REI_ONSET['k_queda']
    _d = _gq - _C['k_queda']['t0']
    _C['k_golpe']['t1'] = _gq
    _C['k_golpe']['hold'] = int(round((_gq - _C['k_golpe']['t0']) * FPS)) - 1
    _f = _C['k_golpe']['fx']; _f['number'] = (_f['number'][0], _f['number'][1], round(_gq - _C['k_golpe']['t0'], 3))
    _C['k_queda']['t0'] = _gq
    _C['k_queda']['fx'] = {k: (round(v[0] + _d, 3),) + tuple(v[1:]) for k, v in _C['k_queda']['fx'].items()}
    _gc = REI_ONSET['k_coringa']
    _dc = _gc - _C['k_coringa']['t0']
    _C['k_queda']['t1'] = _gc
    _C['k_coringa']['t0'] = _gc
    _C['k_coringa']['s0'] = round(_C['k_coringa']['s0'] + _dc, 3)
    _C['k_coringa']['s0'] = round(_C['k_coringa']['s0'] + 0.37, 3)
    _C['k_coringa']['fx'] = dict(freeze=(57.15, 69))


if VARIANT == 'rei' and os.environ.get('TDZ_NO_SNAP') != '1':
    _C = {c['id']: c for c in CLIPS}
    _e5 = _C['e5_esporo']['t0']
    for _cid, _t in (('e6_pouso', 26.31), ('k_porta', 27.31)):
        _i = [k for k, c in enumerate(CLIPS) if c['id'] == _cid][0]
        _a, _b = CLIPS[_i - 1], CLIPS[_i]
        _b['s0'] = round(_b['s0'] + (_t - _b['t0']), 3)
        _a['t1'] = _b['t0'] = _t


def _c8():
    C = {c['id']: c for c in CLIPS}
    m, l = C['k_mao'], C['k_letal']
    l.update(t0=m['t0'], s0=m['s0'], z=2, crop=(860, 460))
    CLIPS.remove(m)
    g = C['k_golpe']
    g.update(z=3, crop=(640, 330))
    q = C['k_queda']
    q.update(crop=(640, 330), pan=(0, 1, 460))
    rv = C['k_revoada_rei']
    rv.update(z=2, crop=(480, 200), s0=36.55, fx=dict(freeze=(round(rv['t0'] + 0.40, 3), 36)))
    cr = C['k_coringa']
    fz = cr['fx']['freeze']
    cr['fx'] = dict(cr['fx'], glint=(fz[0], 72))


_c8()


def _fix_devolve():
    C = {c['id']: c for c in CLIPS}
    imp = C['k_queda']['fx']['shake2'][0]
    for tx in TEXTS:
        if tx['id'] == 'devolve':
            tx['t0'], tx['t1'] = round(imp + (0.6 if VARIANT == 'rei' else 0.65), 3), C['k_queda']['t1']


_fix_devolve()


def take_path(shot):
    return os.path.join(TAKES, shot + '.mkv')


def clip_map(c):
    f0 = c['s0'] * FPS
    fz = (c.get('fx') or {}).get('freeze')
    fz2 = (c.get('fx') or {}).get('freeze2')
    if fz and fz2:
        tf, n = fz
        t2, n2 = fz2
        ff = f0 + (tf - c['t0']) * FPS
        f2 = ff + (t2 - tf - n / FPS) * FPS
        return [(c['t0'], f0), (tf, ff), (tf + n / FPS, ff + 0.001), (t2, f2), (t2 + n2 / FPS, f2 + 0.001),
                (c['t1'], f2 + (c['t1'] - t2 - n2 / FPS) * FPS)]
    if fz:
        tf, n = fz
        ff = f0 + (tf - c['t0']) * FPS
        return [(c['t0'], f0), (tf, ff), (tf + n / FPS, ff + 0.001), (c['t1'], f0 + (c['t1'] - c['t0'] - n / FPS) * FPS)]
    hold = c.get('hold', 0) / FPS
    if hold:
        return [(c['t0'] + hold, f0), (c['t1'], f0 + (c['t1'] - c['t0'] - hold) * FPS)]
    return [(c['t0'], f0), (c['t1'], f0 + (c['t1'] - c['t0']) * FPS)]


def clip(i):
    return [c for c in CLIPS if c['id'] == i][0]


def audio_edl():
    clips = []
    for c in CLIPS:
        if c['src'] in ('logo',) or c['src'].startswith('ai:'):
            continue
        clips.append({'id': c['id'], 'src': 'take:' + c['src'], 't0': c['t0'], 't1': c['t1'], 'map': clip_map(c)})
    if VARIANT == 'tirano':
        return {
            'music': {'path': 'build/trailer/zero8b/music_tirano.wav', 'in': 0.0, 'out': DUR, 't': 0.0,
                      'fade_out': {'t0': DUR - 2.0, 't1': DUR}, 'license': 'ACE-Step 1.5 local, uso comercial (boss-abyss_tyrant.mp3 em dois trechos, passagem dentro do silencio)'},
            'clips': clips, 'sfx': [],
        }
    if VARIANT == 'rei':
        return {
            'music': {'path': 'build/trailer/zero8b_rei/music_rei.wav', 'in': 0.0, 'out': DUR, 't': 0.0,
                      'fade_out': {'t0': DUR - 2.0, 't1': DUR}, 'license': 'ACE-Step 1.5 local, uso comercial (boss-carrion_king.mp3 em dois trechos, passagem dentro do silencio)'},
            'clips': clips, 'sfx': [],
        }
    return {
        'music': {'path': MUSIC, 'in': MUSIC_IN_FILM + OFF, 'out': DUR + OFF, 't': MUSIC_IN_FILM,
                  'fade_out': {'t0': DUR - 2.0, 't1': DUR}, 'license': 'ACE-Step 1.5 local, uso comercial'},
        'clips': clips, 'sfx': [],
    }


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    prev = 0.0
    for c in CLIPS:
        assert abs(c['t0'] - prev) < 1e-6, c['id']
        assert c['t1'] - c['t0'] >= 1.0 or c['id'] == 'k_golpe', c['id']
        prev = c['t1']
    for tx in TEXTS:
        host = [c for c in CLIPS if c['t0'] - 1e-6 <= tx['t0'] and tx['t1'] <= c['t1'] + 1e-6]
        assert host, tx['id']
    if VARIANT == 'rei':
        import subprocess
        s0, s1 = REI['sil']
        a0 = MUSIC_IN_FILM
        w = os.path.join(OUT, 'music_rei.wav')
        fc = (f"[0:a]atrim=start={a0 + REI['cA']}:end={s0 + REI['cA']},asetpts=PTS-STARTPTS,adelay={int(a0*1000)}|{int(a0*1000)}[a];"
              f"[0:a]atrim=start={REI['jB']}:end={REI['jB'] + DUR - s1},asetpts=PTS-STARTPTS,adelay={int(s1*1000)}|{int(s1*1000)}[b];"
              f"[a][b]amix=inputs=2:normalize=0,apad=whole_dur={DUR}")
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', os.path.join(R, MUSIC), '-filter_complex', fc, '-ar', '48000', '-ac', '2', '-t', str(DUR), w], check=True)
    if VARIANT == 'tirano':
        import subprocess
        s0, s1 = SIL6
        a0 = MUSIC_IN_FILM
        w = os.path.join(OUT, 'music_tirano.wav')
        g = [c for c in CLIPS if c['id'] == 'k_golpe'][0]['t0']
        fc = (f"[0:a]atrim=start={a0 + OFF}:end={s0 + OFF},asetpts=PTS-STARTPTS,adelay={int(a0*1000)}|{int(a0*1000)}[a];"
              f"[0:a]atrim=start={TIR_B}:end={TIR_B + g - s1},asetpts=PTS-STARTPTS,adelay={int(s1*1000)}|{int(s1*1000)}[b];"
              f"[0:a]atrim=start={TIR_R},asetpts=PTS-STARTPTS,adelay={int(round(g*1000))}|{int(round(g*1000))}[c];"
              f"[a][b][c]amix=inputs=3:normalize=0,apad=whole_dur={DUR}")
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', os.path.join(R, MUSIC), '-filter_complex', fc, '-ar', '48000', '-ac', '2', '-t', str(DUR), w], check=True)
    json.dump(audio_edl(), open(os.path.join(OUT, f'{os.path.basename(OUT)}_{VARIANT}_edl.json'), 'w', encoding='utf-8'), indent=1)
    print('ok', VARIANT, len(CLIPS), 'clipes', prev, 's')
