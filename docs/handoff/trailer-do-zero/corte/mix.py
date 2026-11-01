import os, sys, json
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, '..', '..', 'trailer-revisao-som'))
import edl as ED
import remix_engine as E

E.LOG = os.path.join(ED.TAKES, 'audio.jsonl')
E.OUT = ED.OUT


def events_last():
    seqs = {}
    for line in open(E.LOG, encoding='utf-8'):
        d = json.loads(line)
        s = seqs.setdefault(d['shot'], [])
        if s and d['f'] < s[-1]['f'] - 5:
            s.clear()
        s.append(d)
    ev = {}
    for shot, s in seqs.items():
        seen = set()
        for d in s:
            if d.get('kind') == 'sfx' and d.get('path'):
                key = (d['code'], d['f'] // 3)
                if key in seen:
                    continue
                seen.add(key)
                ev.setdefault(shot, []).append(d)
    return ev


E.events = events_last

SIL = -70
PLAN = {
    'name': 'zero', 'edl': os.path.join(ED.OUT, 'zero_edl.json'), 'dur': ED.DUR,
    'group_db': {'sfx': 0, 'ambient': 10},
    'code_db': {'hoverCard': -6, 'menuHover': -8, 'cardDraw': -3, 'cardSelect': -2, 'castleGateOpen': 0, 'bossEyes': -2, 'bossEyesRumble': -10,
                'bossLandImpact': 9, 'bossRevealSting': -3, 'enemyVoice': 3, 'impact': 3, 'cardPlayAttack': -3, 'buttonClick': -2,
                'comboTrigger': -3, 'entrance_': 0, 'sting_heartbeat': 2, 'crow': 2, 'shopOpen': -40, 'cashOutChime': -40,
                'sting_act_complete': -40, 'debuffApplied': -4},
    'clip_db': {'h_mao': 2, 'k_escuro': -10, 'k_nome': -8, 'k_revoada_rei': 3, 'k_golpe': 6, 'e2_gargula': -3},
    'amb_clip_db': {'estrada_a1': 6, 'encruzilhada_a1': 6, 'k_estrada': 4, 'k_porta': 2, 'k_escuro': -6, 'e2_gargula': 2, 'e5_esporo': 6,
                    'e4_serpente': 8, 'e6_anjo': 6},
    'code_window': {'k_porta': {'wx:': (0, 22.5)}},
    'no_carry': True,
    'clip_mute_until': {'h_mao': 0.89},
    'amb_only': {c: ['pl:boss'] for c in ['k_escuro', 'k_nome', 'k_guerreiro', 'k_revoada_rei', 'k_volta', 'k_letal', 'k_golpe', 'k_coringa']},
    'sidechain': {'thr': -26, 'max': 6, 'ratio': 0.5},
    'music_env': [
        (0, 0), (21.0, 0), (21.6, -8), (22.45, -8), (22.6, SIL), (28.30, SIL), (28.33, -2),
        (33.24, -2), (33.5, -7), (37.05, -7), (37.22, -2), (38.6, -2), (39.6, 0),
        (52.08, 0), (53.0, -5), (55.20, -5), (55.25, SIL), (55.82, SIL), (55.84, 3), (58.0, 3), (59.5, 0), (62.0, -1),
    ],
    'music_lp': [(0, 0), (21.0, 0), (21.6, 0.5), (22.5, 0.5), (22.6, 0)],
    'extra': [
        {'t': 0.0, 'file': 'audio/sfx/boot-tv-power-on.mp3', 'db': -10, 'what': 'TV liga (som do jogo)'},
        {'t': 22.60, 'file': 'audio/sfx/place/boss-room-1.mp3', 'db': -14, 'amb': True, 'len': 1.0, 'fade': 0.3, 'what': 'salao IA do Rei: leito'},
        {'t': 38.67, 'file': 'audio/sfx/boss/boss_hellfire_wall.mp3', 'in': 0.6, 'db': -4, 'len': 1.42, 'what': 'salao IA do Tirano: parede de fogo'},
        {'t': 44.64, 'file': 'audio/sfx/boss/boss_frost_storm.mp3', 'in': 0.6, 'db': -2, 'len': 1.71, 'what': 'salao IA do Monarca: tempestade de gelo'},
        {'t': 55.84, 'file': 'audio/sfx/boss/boss_land_impact.mp3', 'db': 5, 'len': 1.2, 'what': 'peso no golpe LETAL'},
        {'t': 62.07, 'file': 'audio/sfx/boot-card-whoosh.mp3', 'db': 0, 'what': 'coringa gira (som do boot do jogo)'},
        {'t': 62.29, 'file': 'audio/sfx/forge-reveal.mp3', 'db': -9, 'what': 'o coringa vira o selo'},
        {'t': 62.83, 'file': 'audio/sfx/pack-card-reveal.mp3', 'db': -7, 'what': 'letras GRIMOIRE'},
        {'t': 64.37, 'file': 'audio/sfx/card-discovered.mp3', 'db': -2, 'what': 'WISHLIST'},
        {'t': 63.0, 'file': 'audio/sfx/place/boss-room-1.mp3', 'db': -12, 'amb': True, 'fade_in': 0.4, 'len': 5.5, 'fade': 1.5, 'what': 'salao ao fundo do logo'},
        {'t': 66.40, 'file': 'audio/sfx/boss/crow/appear_2.mp3', 'db': -2, 'what': 'corvo distante no fim'},
        {'t': 67.60, 'file': 'audio/sfx/card-draw.mp3', 'db': 8, 'what': 'ultima carta puxada'},
    ],
}

if __name__ == '__main__':
    import edl
    json.dump(edl.audio_edl(), open(os.path.join(ED.OUT, 'zero_edl.json'), 'w', encoding='utf-8'), indent=1)
    E.run(PLAN)
