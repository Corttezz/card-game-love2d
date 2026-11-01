import sys, os
sys.path.insert(0, os.path.dirname(__file__))
import remix_engine as E

SIL = -70
PLAN = {
    'name': 'A', 'edl': 'A_edl.json', 'dur': 32.3,
    'group_db': {'sfx': 0, 'ambient': 12},
    'code_db': {'hoverCard': -4, 'menuHover': -6, 'cardDraw': -2, 'bossEyes': 3, 'bossEyesRumble': -9, 'bossLandImpact': 4, 'bossRevealSting': 3,
                'enemyVoice': 3, 'impact': 3, 'cardPlayAttack': -3, 'buttonClick': -2, 'comboTrigger': -3, 'entrance_': 4, 'sting_': -2, 'wx:thunder': 2,
                'fork': 2, 'coin': -2},
    'clip_db': {'cartas_ladino': 5, 'porta': -4, 'olhos': -2, 'pouso_nome': -2},
    'amb_clip_db': {'cartas_ladino': 4, 'encruzilhada_a2': 4, 'encruzilhada_a4': 8, 'entrada_grifo': 2, 'entrada_serpente': 4, 'porta': 2,
                    'luta_guerreiro': 2},
    'code_window': {'porta': {'castleGateOpen': (0, 0), 'wx:': (0, 17.6)}, 'olhos': {'wx:': (0, 0)}, 'pouso_nome': {'wx:': (0, 0)},
                    'luta_guerreiro': {'wx:': (0, 0)}, 'entrada_grifo': {'sting_': (0, 0)}},
    'sidechain': {'thr': -26, 'max': 6, 'ratio': 0.5},
    'music_env': [
        (0, 0), (7.1, 0), (7.25, -7), (10.45, -7), (10.6, -6), (14.9, -8), (15.3, -12), (16.6, -12), (16.8, SIL), (17.97, SIL),
        (18.0, 0), (22.2, 0), (22.45, -6), (24.18, -6), (24.27, SIL), (24.59, SIL), (24.61, 1), (26.8, 0), (26.95, SIL),
        (28.32, SIL), (28.34, 0), (29.1, 0), (29.19, -5), (29.9, -5), (30.3, 0), (30.6, 0), (32.25, -30),
    ],
    'music_lp': [(0, 0), (10.4, 0), (10.8, 0.5), (16.7, 0.6), (16.8, 0)],
    'synth_drop': ['TV liga', 'golpe', 'pouso', 'castle_door', 'rangido', 'drop: pouso', 'flash do logo'],
    'synth_db': {'encruzilhada': -6, 'salao': -5, 'entrada': -3, 'serpente': -3},
    'synth_all_db': -3,
    'extra': [
        {'t': 0.0, 'file': 'audio/sfx/boot-tv-power-on.mp3', 'db': -12, 'what': 'TV liga (som do jogo)'},
        {'t': 10.51, 'file': 'audio/sfx/stingers/miniboss_entrance.mp3', 'db': -4, 'what': 'stinger de mini-chefe (grifo)'},
        {'t': 14.10, 'file': 'audio/sfx/boss/boss_frost_storm.mp3', 'in': 0.8, 'db': 2, 'len': 1.6, 'what': 'sopro de gelo da serpente'},
        {'t': 17.76 - 1.45, 'file': 'audio/sfx/castle-gate-open.mp3', 'db': -4, 'what': 'portao do castelo (baque no corte 17,76)'},
        {'t': 17.76, 'file': 'audio/sfx/boss/boss_eyes_ignite.mp3', 'db': -4, 'what': 'olhos do Rei acendem'},
        {'t': 18.00 - 0.15, 'file': 'audio/sfx/boss/boss_land_impact.mp3', 'db': -6, 'what': 'pouso do Rei no drop'},
        {'t': 18.10, 'file': 'audio/sfx/boss/crow/flock_1.mp3', 'db': -6, 'what': 'corvos no pouso'},
        {'t': 18.82, 'file': 'audio/sfx/boss/crow/appear_2.mp3', 'db': 0, 'what': 'salao do Rei-Carnica: corvo'},
        {'t': 19.75, 'file': 'audio/sfx/boss/boss_rune_ignite.mp3', 'db': 0, 'len': 0.55, 'what': 'salao do Lich: runa'},
        {'t': 20.33, 'file': 'audio/sfx/boss/boss_hellfire_wall.mp3', 'in': 0.4, 'db': -3, 'len': 1.95, 'what': 'salao do Tirano: parede de fogo'},
        {'t': 24.61, 'file': 'audio/sfx/boss/boss_land_impact.mp3', 'db': -8, 'len': 1.0, 'what': 'peso no golpe de 42'},
        {'t': 26.90, 'file': 'audio/sfx/boot-card-whoosh.mp3', 'db': 2, 'what': 'bussola gira (som do boot do jogo)'},
        {'t': 27.10, 'file': 'audio/sfx/place/boss-room-1.mp3', 'db': -4, 'amb': True, 'fade_in': 0.2, 'what': 'salao ao fundo do logo'},
        {'t': 27.60, 'file': 'audio/sfx/castle-gate-magic.mp3', 'db': -4, 'len': 1.4, 'what': 'magia subindo para o clarao'},
        {'t': 28.34 - 0.45, 'file': 'audio/sfx/forge-reveal.mp3', 'db': 0, 'what': 'clarao do logo'},
        {'t': 28.90, 'file': 'audio/sfx/pack-card-reveal.mp3', 'db': -2, 'what': 'letras GRIMOIRE'},
        {'t': 29.17, 'file': 'audio/sfx/card-discovered.mp3', 'db': 6, 'what': 'carta descoberta no WISHLIST'},
        {'t': 30.70, 'file': 'audio/sfx/boss/crow/appear_2.mp3', 'db': 0, 'what': 'corvo distante no fim'},
        {'t': 31.30, 'file': 'audio/sfx/card-draw.mp3', 'db': 8, 'what': 'ultima carta puxada'},
    ],
}

if __name__ == '__main__':
    E.run(PLAN)
