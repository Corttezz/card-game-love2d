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
OUT = os.path.join(R, 'build', 'trailer', 'zero2')
FPS = 60
DUR = 64.5

HAND_TOP = (480, 420)
CLIPS = [
    dict(id='h_mao', src='zero_hand', t0=0.00, t1=2.55, s0=10.26, z=2, crop=HAND_TOP),
    dict(id='h_letal', src='zero_hand', t0=2.55, t1=4.18, s0=12.81, z=2, crop=(880, 300),
         fx=dict(flash=(3.69, 6, 0.45), shake=(3.69, 8, 6))),
    dict(id='h_cascata', src='zero_hand', t0=4.18, t1=7.48, s0=14.44, z=2, crop=(340, 200)),
    dict(id='h_morte', src='zero_hand', t0=7.48, t1=9.60, s0=17.74, z=2, crop=(180, 150)),
    dict(id='espolio', src='zero_hand', t0=9.60, t1=11.69, s0=28.53, z=2, crop=(640, 180)),
    dict(id='e2_gargula', src='entr_moon_gargoyle', t0=11.69, t1=13.03, s0=7.86, z=1),
    dict(id='ia_hall3', src='ai:hall3_tyrant:castle_hall_3', t0=13.03, t1=16.24, s0=1.0, z=1),
    dict(id='t_correntes', src='zero_tyrant', t0=16.24, t1=18.54, s0=5.00, z=2, crop=(480, 240)),
    dict(id='e4_serpente', src='entr_ice_wyrm', t0=18.54, t1=20.82, s0=10.40, z=1),
    dict(id='ia_hall4', src='ai:hall4_ice:castle_hall_4', t0=20.82, t1=22.27, s0=2.0, z=1),
    dict(id='m_geada', src='zero_monarch', t0=22.27, t1=25.38, s0=4.80, z=2, crop=(480, 540)),
    dict(id='e5_esporo', src='entr_spore_mother', t0=25.38, t1=26.53, s0=10.40, z=1),
    dict(id='e6_anjo', src='entr_fallen_angel', t0=26.53, t1=27.99, s0=10.60, z=1),
    dict(id='k_estrada', src='zero_carrion', t0=27.99, t1=29.95, s0=6.89, z=1),
    dict(id='k_porta', src='zero_carrion', t0=29.95, t1=32.55, s0=8.85, z=1),
    dict(id='ia_hall1', src='ai:hall1_carrion:castle_hall_1', t0=32.55, t1=34.71, s0=1.5, z=1),
    dict(id='k_escuro', src='zero_carrion', t0=34.71, t1=39.44, s0=12.15, z=1),
    dict(id='k_nome', src='zero_carrion', t0=39.44, t1=41.67, s0=16.88, z=1),
    dict(id='k_guerreiro', src='zero_carrion', t0=41.67, t1=44.08, s0=22.53, z=2, crop=(480, 540)),
    dict(id='k_revoada_rei', src='zero_carrion', t0=44.08, t1=47.97, s0=42.85, z=2, crop=(480, 150)),
    dict(id='k_volta', src='zero_carrion', t0=47.97, t1=49.10, s0=52.84, z=1),
    dict(id='k_letal', src='zero_carrion', t0=49.10, t1=52.83, s0=53.97, z=2, crop=(480, 150)),
    dict(id='k_golpe', src='zero_carrion', t0=52.83, t1=55.96, s0=60.95, z=2, crop=(480, 200), hold=3, pan=(10, 1),
         fx=dict(flash=(52.83, 5, 0.75), shake=(52.88, 12, 12), number=('47', 52.83, 0.75))),
    dict(id='k_coringa', src='zero_carrion', t0=55.96, t1=57.77, s0=65.17, z=2, crop=(475, 165)),
    dict(id='logo', src='logo', t0=57.77, t1=DUR, s0=0, z=1),
]

TEXTS = [
    dict(id='cartas', lines=['145 LIVING CARDS.'], t0=9.60, t1=11.69, y=40, gold=[0], size=56),
    dict(id='atos', lines=['6 ACTS.'], t0=11.69, t1=13.03, y=110, gold=[0]),
    dict(id='regras', lines=['EVERY BOSS', 'BREAKS THE RULES.'], t0=13.03, t1=16.24, y=110, gold=[1], stagger=0.62),
    dict(id='correntes', lines=['CHAINS.'], t0=17.24, t1=18.54, y=880, gold=[0]),
    dict(id='criaturas', lines=['42 CREATURES.'], t0=18.54, t1=20.82, y=110, gold=[0]),
    dict(id='geada', lines=['FROST.'], t0=22.97, t1=25.20, y=110, gold=[0]),
    dict(id='devolve', lines=['BREAK THEM BACK.'], t0=53.60, t1=55.90, y=110, gold=[0]),
]

REI = dict(cA=2.57, jB=55.54, sil=(32.55, 39.44), snap=0.45)


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
    keep = {0.0, s0, s1, DUR}
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


LOGO = dict(spin0=57.77, seal_at=58.00, grimoire=58.60, genre=59.40, wishlist=61.98, fade0=63.0)
CARD_BG_T = 63.20
TV_SKIP = 240
HALL_GRID = (960, 540)


for _tx in TEXTS:
    _h = [c for c in CLIPS if c['t0'] - 1e-6 <= _tx['t0'] and _tx['t1'] <= c['t1'] + 1e-6][0]
    _tx['host'], _tx['dt'], _tx['len'] = _h['id'], round(_tx['t0'] - _h['t0'], 3), round(_tx['t1'] - _tx['t0'], 3)
if VARIANT == 'rei':
    _rei_snap()
    _shift = {}
    for _k in ('spin0', 'seal_at', 'grimoire', 'genre', 'wishlist'):
        pass
    _lg = [c for c in CLIPS if c['id'] == 'logo'][0]
    _d = _lg['t0'] - 57.77
    LOGO = {k: round(v + _d, 3) for k, v in LOGO.items()}
    OUT = os.path.join(R, 'build', 'trailer', 'zero2_rei')


def take_path(shot):
    return os.path.join(TAKES, shot + '.mkv')


def clip_map(c):
    f0 = c['s0'] * FPS
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
    if VARIANT == 'rei':
        return {
            'music': {'path': 'build/trailer/zero2_rei/music_rei.wav', 'in': 0.0, 'out': DUR, 't': 0.0,
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
        assert c['t1'] - c['t0'] >= 1.0 or c['id'] == 'none', c['id']
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
    json.dump(audio_edl(), open(os.path.join(OUT, f'{os.path.basename(OUT)}_{VARIANT}_edl.json'), 'w', encoding='utf-8'), indent=1)
    print('ok', VARIANT, len(CLIPS), 'clipes', prev, 's')
