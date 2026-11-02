import os, sys, json
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, '..', '..', 'trailer-revisao-som'))
import importlib
ED = importlib.import_module(os.environ.get('TDZ_EDL', 'edl2'))
import remix_engine as E
import mix as M0

E.LOG = os.path.join(ED.TAKES, 'audio.jsonl')
E.OUT = ED.OUT
E.events = M0.events_last
C = {c['id']: c for c in ED.CLIPS}
SIL = -70
ROOM_DB = float(os.environ.get('TDZ_ROOM_DB', '-26'))
GATE = [json.loads(l)['path'] for l in open(E.LOG, encoding='utf-8') if '"castleGateOpen"' in l][-1]
INSIDE = ['k_escuro', 'k_escuro_b', 'k_nome', 'k_guerreiro', 'k_revoada_rei', 'k_vida', 'k_mao', 'k_queda', 'k_ajoelha', 'k_revoada_vida', 'k_vida3', 'k_volta', 'k_letal_mao', 'k_letal', 'k_golpe', 'k_coringa']
L = ED.LOGO
g = C['k_golpe']['t0']; door = C['k_porta']['t0']; s0 = C['ia_hall1']['t0']; s1 = C['k_nome']['t0']
rv0 = C['k_revoada_rei']['t0']
rv1 = C['k_vida']['t1'] if 'k_vida' in C else (C['k_vida3']['t1'] if 'k_vida3' in C else (C['k_revoada_vida']['t1'] if 'k_revoada_vida' in C else C['k_revoada_rei']['t1']))
lt0 = C['k_mao']['t0'] if 'k_mao' in C else (C['k_letal_mao']['t0'] if 'k_letal_mao' in C else C['k_letal']['t0'])
PLAN = {
    'name': os.path.basename(ED.OUT) + '_' + ED.VARIANT, 'edl': os.path.join(ED.OUT, f'{os.path.basename(ED.OUT)}_{ED.VARIANT}_edl.json'), 'dur': ED.DUR,
    'group_db': {'sfx': 0, 'ambient': 10},
    'code_db': dict(M0.PLAN['code_db'], castleGateOpen=9 if getattr(ED, 'CUT', '') in ('corte5', 'corte6', 'corte7', 'corte8') else 0, bossEyes=-2, bossLandImpact=9, bossRevealSting=-3),
    'clip_db': {'h_mao': 2, 'k_escuro': -10, 'k_escuro_b': -10, 'k_nome': -8, 'k_revoada_rei': 3, 'k_revoada_vida': 4, 'k_vida3': 4, 'k_vida': 4, 'k_porta_a': -40, 'k_golpe': 10, 'k_queda': 4, 'k_coringa': -11, 'e2_gargula': -11, 'h_letal': 2},
    'amb_clip_db': {'k_estrada': 4, 'k_porta': 2, 'k_escuro': -6, 'e2_gargula': -4, 'e4_serpente': 8, 'e5_esporo': 6, 'e6_anjo': 6},
    'code_window': {'k_porta': {'wx:': (0, s0 - 0.1)}},
    'no_carry': True,
    'clip_mute_until': {'h_mao': ED.MUSIC_IN_FILM},
    'amb_only': {c: ['pl:boss'] for c in INSIDE},
    'sidechain': {'thr': -26, 'max': 6, 'ratio': 0.5},
    'music_env': [
        (0, 0), (door + 0.4, 0), (door + 1.0, -8), (s0 - 0.15, -8), (s0, SIL), (s1 - 0.03, SIL), (s1, -2),
        (rv0, -2), (rv0 + 0.25, -7), (rv1 - 0.2, -7), (rv1, -3),
        (lt0, -3), (lt0 + 0.9, -6), (g - 0.62, -6), (g - 0.58, SIL), (g - 0.02, SIL), (g, 3), (g + 2.2, 3), (g + 4.6, 0), (L['spin0'], -1),
    ],
    'music_lp': [(0, 0), (door + 0.4, 0), (door + 1.0, 0.5), (s0 - 0.1, 0.5), (s0, 0)],
    'extra': [
        {'t': 0.0, 'file': 'audio/sfx/boot-tv-power-on.mp3', 'db': -10, 'what': 'TV liga (som do jogo)'},
        {'t': C['ia_hall3']['t0'] + 0.07, 'file': 'audio/sfx/boss/boss_hellfire_wall.mp3', 'in': 0.6, 'db': -20, 'len': C['ia_hall3']['t1'] - C['ia_hall3']['t0'], 'what': 'salao IA do Tirano: parede de fogo'},
        {'t': C['ia_hall4']['t0'] + 0.07, 'file': 'audio/sfx/boss/boss_frost_storm.mp3', 'in': 0.6, 'db': -11, 'len': C['ia_hall4']['t1'] - C['ia_hall4']['t0'], 'what': 'salao IA do Monarca: tempestade de gelo'},
        *([] if getattr(ED, 'CUT', '') in ('corte5', 'corte6', 'corte7', 'corte8') else [{'t': C.get('k_porta_a', C['k_porta'])['t0'], 'file': GATE, 'in': max(0.0, C.get('k_porta_a', C['k_porta'])['s0'] - 9.40), 'db': 6, 'what': 'portao do castelo (cabeca aparada no corte)'}]),
        {'t': g, 'file': 'audio/sfx/boss/boss_land_impact.mp3', 'db': 5, 'len': 1.2, 'what': 'peso no golpe LETAL'},
        *([{'t': C['e6_anjo']['t0'], 'file': 'audio/sfx/entrances/fallen_angel_start.mp3', 'in': max(0.0, C['e6_anjo']['s0'] - 6.35), 'db': 0, 'what': 'anjo descendo (cabeca aparada)'}] if 'e6_anjo' in C else []),
        *([           {'t': C['e6_pouso']['t0'] + (9.50 - C['e6_pouso']['s0']), 'file': 'audio/sfx/entrances/fallen_angel_stop.mp3', 'db': 2, 'what': 'pouso do anjo'}] if 'e6_pouso' in C else []),
        *([{'t': C['k_queda']['fx']['shake2'][0], 'file': 'audio/sfx/boss/boss_land_impact.mp3', 'db': 0, 'len': 1.0, 'what': 'corpo do Rei no chao'}] if 'k_queda' in C else []),
        {'t': C['h_letal']['fx']['flash'][0], 'file': 'audio/sfx/boss/boss_land_impact.mp3', 'db': -8, 'len': 0.8, 'what': 'peso no LETAL do gancho'},
        {'t': L['spin0'], 'file': 'audio/sfx/boot-card-whoosh.mp3', 'db': 0, 'what': 'coringa gira'},
        {'t': L['seal_at'], 'file': 'audio/sfx/forge-reveal.mp3', 'db': -9, 'what': 'o coringa vira o selo'},
        {'t': L['grimoire'], 'file': 'audio/sfx/pack-card-reveal.mp3', 'db': -7, 'what': 'letras GRIMOIRE'},
        {'t': L['wishlist'], 'file': 'audio/sfx/card-discovered.mp3', 'db': -2, 'what': 'WISHLIST'},
        {'t': L['spin0'] + 0.9, 'file': 'audio/sfx/place/boss-room-1.mp3', 'db': -12, 'amb': True, 'fade_in': 0.4, 'len': ED.DUR - L['spin0'] - 0.9, 'fade': 1.5, 'what': 'salao ao fundo do logo'},
        {'t': ED.DUR - 2.1, 'file': 'audio/sfx/boss/crow/appear_2.mp3', 'db': -2, 'what': 'corvo distante no fim'},
        {'t': ED.DUR - 0.9, 'file': 'audio/sfx/card-draw.mp3', 'db': 8, 'what': 'ultima carta puxada'},
    ],
}

if getattr(ED, 'CUT', '') in ('corte4', 'corte5', 'corte6', 'corte7', 'corte8'):
    h3 = C['ia_hall3']; cr = C['k_coringa']
    env = PLAN['music_env']
    env += [(h3['t0'] - 1.2, -4), (h3['t0'] - 0.02, -4), (h3['t0'], 5), (h3['t1'] - 0.2, 5), (h3['t1'], 0)]
    CDB = float(os.environ.get('TDZ_CORINGA_DB', '16' if ED.VARIANT == 'tirano' else '-18'))
    env += [(cr['t0'] - 0.1, 3), (cr['t0'], CDB), (cr['t1'], CDB), (L['spin0'] + 0.3, -1)]
    env = [(t, v) for t, v in env if not (cr['t0'] - 0.1 < t < cr['t1'] + 0.05)]
    CDB = float(os.environ.get('TDZ_CORINGA_DB', ('-2' if getattr(ED, 'CUT', '') in ('corte7', 'corte8') else '6' if getattr(ED, 'CUT', '') == 'corte6' else '11') if ED.VARIANT == 'tirano' else ('-6' if getattr(ED, 'CUT', '') in ('corte6', 'corte7', 'corte8') else '2')))
    env = [(t, v + (2 if g <= t <= g + 2.3 else 0)) for t, v in env]
    env += [(cr['t0'] - 0.1, 3), (cr['t0'], CDB), (cr['t1'], CDB)]
    PLAN['music_env'] = sorted(env, key=lambda k: k[0])
    PLAN['code_window'] = dict(PLAN.get('code_window', {}), k_coringa={'bossRevealSting': (0, 0), 'jokerSig': (0, 0)})
    FT = getattr(ED, 'FACE_T', None) or cr['t0'] + 0.02
    PLAN['extra'] += [{'t': FT, 'file': 'audio/sfx/boss/boss_reveal_sting.mp3', 'db': 0, 'what': 'revelacao do coringa na face da carta'},
                      {'t': FT, 'file': 'audio/sfx/joker-sig/joker_boss_carrion.mp3', 'db': 0, 'what': 'assinatura do coringa na face da carta'}]
    PLAN['extra'].append({'t': s0, 'file': 'audio/sfx/boss/boss_hold_ambience.mp3', 'db': ROOM_DB, 'in': 0.5, 'loop': True, 'len': C['ia_hall1']['t1'] - s0 + 0.3, 'fade': 0.3, 'what': 'tom de sala no trono vazio (-45 a -50 dBFS)'})

if getattr(ED, 'OUT_NAME', '') == 'corte9':
    PLAN['sfx_env'] = [(0, 0), (g - 0.66, 0), (g - 0.58, -32), (g - 0.02, -32), (g, 0)]
    PLAN['amb_env'] = [(0, 0), (g - 0.66, 0), (g - 0.58, -40), (g - 0.02, -40), (g, 0)]

if ED.VARIANT == 'rei':
    REI_UP = 6 if getattr(ED, 'CUT', '') not in ('corte4', 'corte5', 'corte6', 'corte7', 'corte8') else 3
    PLAN['music_env'] = [(t, v + REI_UP if t >= s1 and v > SIL else v) for t, v in PLAN['music_env']]
    if getattr(ED, 'CUT', '') in ('corte4', 'corte5', 'corte6', 'corte7', 'corte8'):
        PLAN['music_env'] = sorted([(t, v) for t, v in PLAN['music_env'] if t < L['spin0'] + 0.3]
                                   + [(L['spin0'] + 0.3, -2), (L['grimoire'], -4), (ED.DUR, -4)], key=lambda k: k[0])

if __name__ == '__main__':
    json.dump(ED.audio_edl(), open(PLAN['edl'], 'w', encoding='utf-8'), indent=1)
    E.run(PLAN)
