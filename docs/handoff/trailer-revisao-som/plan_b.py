import sys, os
sys.path.insert(0, os.path.dirname(__file__))
import remix_engine as E

SIL = -70
PLAN = {
    'name': 'B', 'edl': 'B_edl.json', 'dur': 65.3,
    'group_db': {'sfx': 0, 'ambient': 12},
    'code_db': {'hoverCard': -4, 'menuHover': -6, 'cardDraw': -2, 'castleGateOpen': 6, 'bossEyes': 3, 'bossEyesRumble': -9, 'bossLandImpact': 4,
                'bossRevealSting': 3, 'enemyVoice': 3, 'impact': 3, 'cardPlayAttack': -3, 'buttonClick': -2, 'comboTrigger': -3, 'entrance_': 4,
                'sting_': -2, 'wx:thunder': 6},
    'clip_db': {'porta_entrada_nome': -4, 'cartas_ladino': 5, 'recompensa': 2},
    'amb_clip_db': {'porta_entrada_nome': 4, 'luta_guerreiro': 2, 'ato_1': 6, 'ato_2': 4, 'ato_3': 6, 'ato_4': 8, 'ato_5': 6, 'ato_6': 6},
    'code_window': {'porta_entrada_nome': {'wx:': (0, 32.59)}, 'luta_guerreiro': {'wx:': (0, 0)}, 'entrada_grifo': {'sting_': (0, 0)}},
    'sidechain': {'thr': -26, 'max': 6, 'ratio': 0.5},
    'music_env': [
        (0, -6), (3.40, -6), (3.49, 0), (8.4, 0), (8.6, -2), (11.0, -2), (11.1, -8), (20.3, -8), (20.6, -7), (29.2, -7),
        (29.7, -14), (32.45, -14), (32.65, SIL), (37.37, SIL), (37.40, 0), (46.1, 0), (46.35, -6), (51.2, -6), (51.32, SIL),
        (52.13, SIL), (52.15, 1), (54.85, 0), (55.05, SIL), (57.16, SIL), (57.18, 0), (59.95, 0), (60.03, -5), (60.8, -5),
        (61.3, 0), (62.6, 0), (65.25, -30),
    ],
    'music_lp': [(0, 0), (20.3, 0), (20.8, 0.6), (32.5, 0.6), (32.6, 0)],
    'synth_drop': ['TV liga', 'golpe', 'pouso', 'castle_door', 'rangido', 'revelacao', 'serpente emerge', 'ato ', 'flash do logo'],
    'synth_db': {'salao': -5, 'cartao do nome': -4, 'entrada': -3},
    'synth_all_db': -3,
    'extra': [
        {'t': 0.0, 'file': 'audio/sfx/boot-tv-power-on.mp3', 'db': -12, 'what': 'TV liga (som do jogo)'},
        {'t': 20.40, 'file': 'audio/sfx/stingers/miniboss_entrance.mp3', 'db': -4, 'what': 'stinger de mini-chefe (grifo)'},
        {'t': 25.60, 'file': 'audio/sfx/boss/boss_frost_storm.mp3', 'in': 0.8, 'db': 2, 'what': 'sopro de gelo da serpente'},
        {'t': 38.70, 'file': 'audio/sfx/boss/boss_rune_ignite.mp3', 'db': 0, 'len': 1.2, 'what': 'salao do Lich: runa'},
        {'t': 38.70, 'file': 'audio/sfx/boss/boss_hold_ambience.mp3', 'db': -2, 'amb': True, 'len': 1.25, 'fade': 0.2, 'what': 'salao do Lich: leito'},
        {'t': 39.93, 'file': 'audio/sfx/boss/boss_hellfire_wall.mp3', 'in': 0.6, 'db': -3, 'len': 1.3, 'what': 'salao do Tirano: parede de fogo'},
        {'t': 41.17, 'file': 'audio/sfx/boss/boss_frost_storm.mp3', 'in': 0.6, 'db': 0, 'len': 1.3, 'what': 'salao do Monarca: tempestade de gelo'},
        {'t': 42.47, 'file': 'audio/sfx/boss/boss_heartbeat.mp3', 'db': 2, 'len': 1.2, 'what': 'salao do Colosso: coracao'},
        {'t': 42.80, 'file': 'audio/sfx/boss/boss_roots_crawl.mp3', 'db': 0, 'len': 0.9, 'fade': 0.3, 'what': 'salao do Colosso: raizes'},
        {'t': 43.72, 'file': 'audio/sfx/boss/crow/appear_1.mp3', 'db': -5, 'what': 'salao do Rei-Carnica: corvo'},
        {'t': 44.30, 'file': 'audio/sfx/boss/crow/flock_2.mp3', 'db': 2, 'what': 'salao do Rei-Carnica: corvos cruzando'},
        {'t': 52.15, 'file': 'audio/sfx/boss/boss_land_impact.mp3', 'db': -8, 'len': 1.0, 'what': 'peso no golpe de 42'},
        {'t': 54.95, 'file': 'audio/sfx/boot-card-whoosh.mp3', 'db': 2, 'what': 'bussola gira (som do boot do jogo)'},
        {'t': 55.30, 'file': 'audio/sfx/place/boss-room-1.mp3', 'db': -4, 'amb': True, 'fade_in': 0.2, 'what': 'salao ao fundo do logo'},
        {'t': 56.05, 'file': 'audio/sfx/boot-card-whoosh.mp3', 'db': -2, 'pitch': 0.85, 'what': 'bussola gira (2a volta)'},
        {'t': 56.40, 'file': 'audio/sfx/castle-gate-magic.mp3', 'db': -4, 'len': 1.4, 'what': 'magia subindo para o flash'},
        {'t': 56.73, 'file': 'audio/sfx/forge-reveal.mp3', 'db': -4, 'what': 'flash do logo'},
        {'t': 57.60, 'file': 'audio/sfx/pack-card-reveal.mp3', 'db': -2, 'what': 'letras GRIMOIRE'},
        {'t': 60.01, 'file': 'audio/sfx/card-discovered.mp3', 'db': 6, 'what': 'carta descoberta no WISHLIST'},
        {'t': 62.60, 'file': 'audio/sfx/boss/crow/appear_2.mp3', 'db': 0, 'what': 'corvo distante no fim'},
        {'t': 63.40, 'file': 'audio/sfx/card-draw.mp3', 'db': 8, 'what': 'ultima carta puxada'},
    ],
}

if __name__ == '__main__':
    E.run(PLAN)
