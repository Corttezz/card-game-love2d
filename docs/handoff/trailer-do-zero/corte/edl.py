import json, os

APP = os.environ['APPDATA']
TAKES = os.path.join(APP, 'LOVE', 'card-game-trailer-v9', 'trailer_zero')
R = r'E:\dev\projects\card-game-trailer'
AI = os.path.join(R, 'build', 'trailer', 'ai_4k')
REAL = r'E:\dev\projects\card-game-trailer-zero\assets\sprites\scenes'
OUT = os.path.join(R, 'build', 'trailer', 'zero')
FPS = 60
DUR = 68.5
MUSIC = 'audio/music/boss-abyss_tyrant.mp3'
OFF = 1.60
MUSIC_IN_FILM = 0.89

HAND = (480, 540)
CLIPS = [
    dict(id='h_mao', src='zero_hand', t0=0.00, t1=2.07, s0=11.00, z=2, crop=HAND),
    dict(id='h_hud', src='zero_hand', t0=2.07, t1=3.07, s0=13.07, z=1),
    dict(id='h_cascata', src='zero_hand', t0=3.07, t1=7.24, s0=14.07, z=2, crop=(340, 200)),
    dict(id='h_morte', src='zero_hand', t0=7.24, t1=9.99, s0=18.24, z=2, crop=(180, 150)),
    dict(id='espolio', src='zero_hand', t0=9.99, t1=11.78, s0=28.80, z=2, crop=(640, 220)),
    dict(id='estrada_a1', src='night_a1', t0=11.78, t1=13.81, s0=2.50, z=1),
    dict(id='encruzilhada_a1', src='fork_a1', t0=13.81, t1=15.20, s0=2.00, z=1),
    dict(id='k_estrada', src='zero_carrion', t0=15.20, t1=19.15, s0=4.25, z=1),
    dict(id='k_porta', src='zero_carrion', t0=19.15, t1=22.60, s0=8.20, z=1),
    dict(id='ia_hall1', src='ai:hall1_carrion:castle_hall_1', t0=22.60, t1=23.60, s0=2.0, z=1),
    dict(id='k_escuro', src='zero_carrion', t0=23.60, t1=28.33, s0=12.15, z=1),
    dict(id='k_nome', src='zero_carrion', t0=28.33, t1=30.64, s0=16.92, z=1),
    dict(id='k_guerreiro', src='zero_carrion', t0=30.64, t1=33.24, s0=22.53, z=2, crop=HAND),
    dict(id='k_revoada_rei', src='zero_carrion', t0=33.24, t1=34.94, s0=42.85, z=2, crop=(480, 150)),
    dict(id='k_revoada_painel', src='zero_carrion', t0=34.94, t1=37.22, s0=44.55, z=2, crop=(0, 540)),
    dict(id='e2_gargula', src='entr_moon_gargoyle', t0=37.22, t1=38.67, s0=7.43, z=1),
    dict(id='ia_hall3', src='ai:hall3_tyrant:castle_hall_3', t0=38.67, t1=40.09, s0=2.0, z=1),
    dict(id='t_correntes', src='zero_tyrant', t0=40.09, t1=42.66, s0=4.40, z=2, crop=(480, 240)),
    dict(id='e4_serpente', src='entr_ice_wyrm', t0=42.66, t1=44.64, s0=10.10, z=1),
    dict(id='ia_hall4', src='ai:hall4_ice:castle_hall_4', t0=44.64, t1=46.35, s0=2.0, z=1),
    dict(id='m_geada', src='zero_monarch', t0=46.35, t1=49.50, s0=4.80, z=2, crop=HAND),
    dict(id='e5_esporo', src='entr_spore_mother', t0=49.50, t1=50.95, s0=10.00, z=1),
    dict(id='e6_anjo', src='entr_fallen_angel', t0=50.95, t1=52.08, s0=10.60, z=1),
    dict(id='k_volta', src='zero_carrion', t0=52.08, t1=53.23, s0=53.95, z=1),
    dict(id='k_letal', src='zero_carrion', t0=53.23, t1=55.84, s0=55.10, z=2, crop=(480, 150)),
    dict(id='k_golpe', src='zero_carrion', t0=55.84, t1=59.52, s0=60.80, z=2, crop=(480, 200), hold=3),
    dict(id='k_coringa', src='zero_carrion', t0=59.52, t1=62.07, s0=64.43, z=2, crop=(475, 165)),
    dict(id='logo', src='logo', t0=62.07, t1=DUR, s0=0, z=1),
]

TEXTS = [
    dict(id='cartas', lines=['145 LIVING CARDS.'], t0=9.99, t1=11.78, y=36, gold=[0], size=56),
    dict(id='regras', lines=['EVERY BOSS', 'BREAKS THE RULES.'], t0=30.64, t1=33.24, y=90, gold=[1], stagger=0.62),
    dict(id='atos', lines=['6 ACTS.'], t0=37.22, t1=38.67, y=110, gold=[0]),
    dict(id='criaturas', lines=['42 CREATURES.'], t0=42.66, t1=44.64, y=110, gold=[0]),
    dict(id='geada', lines=['FROST LOCKS', 'YOUR HAND.'], t0=46.74, t1=49.20, y=90, gold=[0]),
    dict(id='devolve', lines=['BREAK THEM BACK.'], t0=56.67, t1=59.30, y=110, gold=[0]),
]

LOGO = dict(spin0=62.07, seal_at=62.29, grimoire=62.83, genre=63.51, wishlist=64.37, fade0=66.0)


def take_path(shot):
    return os.path.join(TAKES, shot + '.mkv')


def clip_map(c):
    f0 = c['s0'] * FPS
    hold = c.get('hold', 0) / FPS
    if hold:
        return [(c['t0'] + hold, f0), (c['t1'], f0 + (c['t1'] - c['t0'] - hold) * FPS)]
    return [(c['t0'], f0), (c['t1'], f0 + (c['t1'] - c['t0']) * FPS)]


def audio_edl():
    clips = []
    for c in CLIPS:
        if c['src'] in ('logo',) or c['src'].startswith('ai:'):
            continue
        clips.append({'id': c['id'], 'src': 'take:' + c['src'], 't0': c['t0'], 't1': c['t1'], 'map': clip_map(c)})
    return {
        'music': {'path': MUSIC, 'in': MUSIC_IN_FILM + OFF, 'out': DUR + OFF, 't': MUSIC_IN_FILM,
                  'fade_out': {'t0': 66.0, 't1': DUR}, 'license': 'ACE-Step 1.5 local, uso comercial'},
        'clips': clips, 'sfx': [],
    }


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    json.dump(audio_edl(), open(os.path.join(OUT, 'zero_edl.json'), 'w', encoding='utf-8'), indent=1)
    prev = 0.0
    for c in CLIPS:
        assert abs(c['t0'] - prev) < 1e-6, c['id']
        prev = c['t1']
    print('ok', len(CLIPS), 'clipes', prev, 's')
