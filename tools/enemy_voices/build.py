import os, sys, zlib
import numpy as np
from scipy import signal
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dsp as D

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
AUDIO = os.path.join(ROOT, 'audio')
SFX = os.path.join(AUDIO, 'sfx')
OUT = os.path.join(SFX, 'enemies')
RAW = os.path.join(ROOT, 'tools', 'preview_out', 'vozes_inimigos', 'raw')
SR = D.SR

HURT_LUFS = -17.0
DEATH_LUFS = -16.0
CEIL = -2.0
EVENTS = {'hurt': 3, 'death': 2}
RISE_MAX = 1.05

FX = {
    'beast':  dict(drive=2.2, shelf=5.0, lp=4000, room=0.12, breath=0.15),
    'undead': dict(drive=1.8, shelf=4.0, lp=5000, room=0.18, breath=0.18),
    'ghost':  dict(drive=1.5, shelf=4.0, lp=4000, room=0.42, breath=0.45),
    'stone':  dict(drive=1.8, shelf=6.0, lp=6000, room=0.16, breath=0.08),
    'metal':  dict(drive=1.8, shelf=4.0, lp=5500, room=0.22, breath=0.15),
    'wet':    dict(drive=1.8, shelf=5.0, lp=3600, room=0.12, breath=0.12),
    'vermin': dict(drive=3.0, shelf=2.5, lp=5600, room=0.10, breath=0.28),
    'fire':   dict(drive=2.4, shelf=4.0, lp=5600, room=0.12, breath=0.25),
}

CENTROID_CAP = {'beast': 420, 'undead': 650, 'wet': 560, 'ghost': 620, 'stone': 520, 'metal': 560,
                'vermin': 850, 'fire': 560}

ARMOR = 'aud:punching-light-armour-87442.mp3'
SWORD = 'aud:sword-sound-260274.mp3'

SPEC = {
    'cursed_scarecrow': dict(fam='undead',
        voice=[('el:undead', 0.70, 0.8), ('ent:cursed_scarecrow_wake', 0.80, 0.6)],
        mats=[('sfx:scene-rustle.mp3', 0.80, 0.5), ('sfx:scene-wood-knock.mp3', 0.70, 0.6)],
        death=[('ent:cursed_scarecrow_stop', 0.85, 0.8), ('el:undead', 0.60, 0.9)]),
    'hollow_farmer': dict(fam='undead',
        voice=[('el:undead', 0.72, 1.0)],
        mats=[('sfx:scene-stone-thud.mp3', 0.75, 0.8), ('sfx:scene-wood-knock.mp3', 0.65, 0.3)],
        death=[('el:undead', 0.62, 1.0), ('ent:hollow_farmer_stop', 0.75, 0.5)]),
    'plague_rats': dict(fam='vermin',
        voice=[('ent:plague_rats_stop', 0.70, 0.8), ('el:beast', 0.95, 0.45)],
        mats=[('sfx:scene-rustle.mp3', 0.80, 0.5)],
        death=[('ent:plague_rats_start', 0.75, 0.8), ('ent:plague_rats_stop', 0.70, 0.7), ('el:beast', 0.85, 0.4)]),
    'harvest_reaper': dict(fam='ghost',
        voice=[('el:undead', 0.65, 0.9), ('ent:harvest_reaper_stop', 0.80, 0.5)],
        mats=[(SWORD, 0.70, 0.5)],
        death=[('el:undead', 0.55, 1.0), ('ent:harvest_reaper_stop', 0.70, 0.6), ('sfx:event-enter-wind.mp3', 0.80, 0.5)]),
    'blight_bull': dict(fam='beast',
        voice=[('el:beast', 0.70, 1.0), ('ent:blight_bull_stop', 0.75, 0.5)],
        mats=[('sfx:scene-stone-thud.mp3', 0.75, 0.8)],
        death=[('el:beast', 0.65, 1.0), ('sfx:boss/boss_land_impact.mp3', 0.80, 0.7)]),
    'wicker_effigy': dict(fam='fire',
        voice=[('ent:wicker_effigy_wake', 0.80, 0.8), ('el:undead', 0.60, 0.55)],
        mats=[('sfx:impact-fire.mp3', 0.80, 0.6), ('sfx:scene-wood-knock.mp3', 0.70, 0.5)],
        death=[('ent:wicker_effigy_wake', 0.70, 0.8), ('sfx:boss/boss_hellfire_wall.mp3', 0.80, 0.6), ('el:undead', 0.55, 0.6)]),
    'carrion_king': dict(fam='undead',
        voice=[('el:undead', 0.70, 1.0), ('sfx:boss/crow/appear_2.mp3', 0.70, 0.4)],
        mats=[('sfx:boss/boss_wing_pass.mp3', 0.80, 0.5)],
        death=[('el:undead', 0.60, 1.0), ('sfx:boss/crow/cine_2.mp3', 0.75, 0.5), ('sfx:boss/boss_death_thud.mp3', 0.90, 0.7)]),

    'moon_gargoyle': dict(fam='stone',
        voice=[('ent:moon_gargoyle_wake', 0.80, 0.8), ('el:beast', 0.80, 0.6)],
        mats=[('sfx:boss/colossus_crack.mp3', 0.85, 0.7), ('sfx:scene-stone-thud.mp3', 0.80, 0.6)],
        death=[('sfx:boss/colossus_crumble.mp3', 0.85, 0.9), ('el:beast', 0.70, 0.7)]),
    'ram_cultist': dict(fam='undead', cap=500,
        voice=[('el:undead', 0.80, 0.8), ('el:beast', 0.95, 0.5)],
        mats=[('sfx:impact-dark.mp3', 0.80, 0.5)],
        death=[('el:undead', 0.70, 1.0), ('ent:ram_cultist_stop', 0.80, 0.6)]),
    'storm_harpy': dict(fam='vermin',
        voice=[('el:beast', 0.95, 0.9), ('ent:storm_harpy_stop', 0.85, 0.5)],
        mats=[('sfx:boss/boss_wing_pass.mp3', 0.85, 0.6)],
        death=[('el:beast', 0.80, 1.0), ('sfx:weather/thunder-near.mp3', 0.90, 0.5), ('sfx:boss/boss_feather_burst.mp3', 0.80, 0.5)]),
    'rune_golem': dict(fam='stone',
        voice=[('ent:rune_golem_stop', 0.80, 0.9), ('sfx:boss/boss_eyes_rumble.mp3', 0.85, 0.5)],
        mats=[('sfx:boss/colossus_crack.mp3', 0.80, 0.7)],
        death=[('sfx:boss/colossus_crumble.mp3', 0.80, 0.9), ('ent:rune_golem_stop', 0.70, 0.6)]),
    'spectral_knight': dict(fam='ghost',
        voice=[('el:undead', 0.60, 0.9), ('ent:spectral_knight_stop', 0.85, 0.6)],
        mats=[(ARMOR, 0.80, 0.6)],
        death=[('el:undead', 0.50, 1.0), ('ent:spectral_knight_stop', 0.70, 0.6), ('sfx:event-enter-wind.mp3', 0.80, 0.5)]),
    'storm_griffin': dict(fam='beast',
        voice=[('el:beast', 0.85, 1.0), ('ent:storm_griffin_stop', 0.85, 0.5)],
        mats=[('sfx:boss/boss_wing_pass.mp3', 0.80, 0.6)],
        death=[('el:beast', 0.70, 1.0), ('ent:storm_griffin_stop', 0.80, 0.6), ('sfx:weather/thunder-mid.mp3', 0.90, 0.4)]),
    'tower_lich': dict(fam='ghost',
        voice=[('el:undead', 0.60, 1.0), ('sfx:boss/boss_rune_ignite.mp3', 0.80, 0.35)],
        mats=[('sfx:scene-wood-knock.mp3', 0.60, 0.6)],
        death=[('el:undead', 0.50, 1.0), ('sfx:boss/boss_death_thud.mp3', 0.85, 0.7), ('sfx:boss/boss_ice_crackle.mp3', 0.80, 0.4)]),

    'ember_imp': dict(fam='fire',
        voice=[('el:beast', 1.00, 0.9), ('ent:ember_imp_rise', 0.85, 0.5)],
        mats=[('sfx:impact-fire.mp3', 0.85, 0.6)],
        death=[('el:beast', 0.85, 1.0), ('sfx:boss/boss_lava_implosion.mp3', 0.90, 0.6)]),
    'hellhound': dict(fam='beast',
        voice=[('ent:hellhound_stop', 0.85, 0.8), ('el:beast', 0.85, 0.9)],
        mats=[('sfx:impact-fire.mp3', 0.80, 0.4)],
        death=[('el:beast', 0.70, 1.0), ('ent:hellhound_stop', 0.75, 0.6), ('sfx:impact-fire.mp3', 0.70, 0.4)]),
    'abyss_acolyte': dict(fam='undead', cap=440,
        voice=[('el:undead', 0.60, 1.0)],
        mats=[('sfx:scene-stone-thud.mp3', 0.70, 0.5)],
        death=[('el:undead', 0.65, 1.0), ('ent:abyss_acolyte_stop', 0.75, 0.5), ('sfx:boss/boss_eyes_rumble.mp3', 0.85, 0.5)]),
    'obsidian_sentinel': dict(fam='stone',
        voice=[('ent:obsidian_sentinel_wake', 0.80, 0.8), ('sfx:boss/boss_eyes_rumble.mp3', 0.80, 0.4)],
        mats=[(ARMOR, 0.75, 0.6), ('sfx:boss/colossus_crack.mp3', 0.85, 0.6)],
        death=[('sfx:boss/colossus_crumble.mp3', 0.80, 0.9), ('ent:obsidian_sentinel_stop', 0.80, 0.6)]),
    'pit_brute': dict(fam='beast',
        voice=[('el:beast', 0.65, 1.0), ('ent:pit_brute_stop', 0.85, 0.6)],
        mats=[('sfx:scene-stone-thud.mp3', 0.75, 0.6)],
        death=[('el:beast', 0.55, 1.0), ('ent:pit_brute_rise', 0.80, 0.5), ('sfx:boss/boss_land_impact.mp3', 0.80, 0.7)]),
    'abyss_watcher': dict(fam='wet',
        voice=[('ent:abyss_watcher_stop', 0.80, 0.8), ('el:undead', 0.55, 0.6)],
        mats=[('sfx:impact-poison.mp3', 0.75, 0.6)],
        death=[('sfx:boss/boss_death_thud.mp3', 0.85, 0.7), ('ent:abyss_watcher_stop', 0.70, 0.8), ('sfx:boss/boss_spore_collapse.mp3', 0.80, 0.6), ('el:undead', 0.50, 0.7)]),
    'abyss_tyrant': dict(fam='beast',
        voice=[('el:beast', 0.55, 1.0), ('sfx:boss/tyrant_unchained.mp3', 0.80, 0.35)],
        mats=[('sfx:boss/tyrant_chain_snap.mp3', 0.80, 0.5)],
        death=[('el:beast', 0.50, 1.0), ('sfx:boss/tyrant_chain_snap.mp3', 0.80, 0.5), ('sfx:boss/boss_lava_implosion.mp3', 0.85, 0.6)]),

    'frost_wight': dict(fam='ghost',
        voice=[('el:undead', 0.60, 0.9), ('ent:frost_wight_stop', 0.80, 0.6)],
        mats=[('sfx:boss/boss_ice_crackle.mp3', 0.80, 0.5)],
        death=[('sfx:impact-ice.mp3', 0.70, 0.7), ('el:undead', 0.50, 1.0), ('ent:frost_wight_stop', 0.70, 0.6), ('sfx:boss/boss_frost_shatter.mp3', 0.80, 0.5)]),
    'frost_wolf': dict(fam='beast',
        voice=[('el:beast', 0.95, 1.0), ('ent:frost_wolf_stop', 0.80, 0.35)],
        mats=[('sfx:scene-rustle.mp3', 0.75, 0.4)],
        death=[('ent:frost_wolf_stop', 0.85, 0.8), ('el:beast', 0.80, 0.9)]),
    'rime_shaman': dict(fam='undead',
        voice=[('el:undead', 0.80, 1.0)],
        mats=[('sfx:boss/boss_ice_crackle.mp3', 0.80, 0.5), ('sfx:scene-wood-knock.mp3', 0.70, 0.4)],
        death=[('el:undead', 0.70, 1.0), ('ent:rime_shaman_stop', 0.80, 0.5), ('sfx:impact-ice.mp3', 0.75, 0.5)]),
    'glacier_knight': dict(fam='metal',
        voice=[('el:undead', 0.65, 0.7), ('ent:glacier_knight_stop', 0.80, 0.7)],
        mats=[(ARMOR, 0.75, 0.7), ('sfx:impact-ice.mp3', 0.80, 0.4)],
        death=[(ARMOR, 0.75, 0.7), ('ent:glacier_knight_stop', 0.70, 0.8), ('el:undead', 0.55, 0.8), ('sfx:boss/boss_frost_shatter.mp3', 0.80, 0.5)]),
    'frost_troll': dict(fam='beast',
        voice=[('el:beast', 0.70, 1.0), ('ent:frost_troll_stop', 0.85, 0.6)],
        mats=[('sfx:scene-stone-thud.mp3', 0.75, 0.6), ('sfx:impact-ice.mp3', 0.75, 0.3)],
        death=[('el:beast', 0.60, 1.0), ('ent:frost_troll_start', 0.80, 0.6), ('sfx:boss/boss_land_impact.mp3', 0.80, 0.6)]),
    'ice_wyrm': dict(fam='beast',
        voice=[('el:beast', 0.75, 1.0), ('ent:ice_wyrm_rise', 0.80, 0.5)],
        mats=[('sfx:boss/boss_ice_crackle.mp3', 0.75, 0.5)],
        death=[('el:beast', 0.60, 1.0), ('ent:ice_wyrm_rise', 0.75, 0.6), ('sfx:boss/boss_frost_shatter.mp3', 0.80, 0.5)]),
    'winter_monarch': dict(fam='ghost',
        voice=[('el:undead', 0.60, 1.0), ('sfx:boss/monarch_strike.mp3', 0.80, 0.5)],
        mats=[('sfx:boss/boss_ice_crackle.mp3', 0.75, 0.5)],
        death=[('el:undead', 0.50, 1.0), ('sfx:boss/boss_frost_shatter.mp3', 0.75, 0.6), ('sfx:boss/boss_blizzard_whiteout.mp3', 0.85, 0.4)]),

    'bog_ghoul': dict(fam='wet',
        voice=[('el:undead', 0.72, 1.0), ('ent:bog_ghoul_rise', 0.70, 0.4)],
        mats=[('sfx:impact-poison.mp3', 0.75, 0.6)],
        death=[('el:undead', 0.65, 1.0), ('ent:bog_ghoul_rise', 0.75, 0.7)]),
    'plague_toad': dict(fam='wet',
        voice=[('el:beast', 0.65, 1.0), ('ent:plague_toad_stop', 0.80, 0.6)],
        mats=[('ent:plague_toad_hop', 0.75, 0.6)],
        death=[('el:beast', 0.55, 1.0), ('ent:plague_toad_stop', 0.70, 0.7), ('sfx:boss/boss_spore_collapse.mp3', 0.80, 0.5)]),
    'leech_horror': dict(fam='wet',
        voice=[('ent:leech_horror_rise', 0.75, 0.9), ('el:undead', 0.60, 0.5)],
        mats=[('sfx:impact-poison.mp3', 0.70, 0.6)],
        death=[('ent:leech_horror_rise', 0.65, 0.9), ('sfx:boss/boss_spore_collapse.mp3', 0.75, 0.6), ('el:undead', 0.50, 0.6)]),
    'mire_hag': dict(fam='undead',
        voice=[('el:undead', 0.90, 1.0)],
        mats=[('ent:mire_hag_stop', 0.80, 0.5)],
        death=[('sfx:boss/boss_death_thud.mp3', 0.85, 0.7), ('ent:mire_hag_stop', 0.75, 0.6), ('el:undead', 0.80, 1.0), ('sfx:impact-poison.mp3', 0.75, 0.4)]),
    'croc_warrior': dict(fam='beast',
        voice=[('ent:croc_warrior_stop', 0.80, 0.8), ('el:beast', 0.75, 0.9)],
        mats=[('ent:croc_warrior_start', 0.80, 0.4)],
        death=[('el:beast', 0.60, 1.0), ('ent:croc_warrior_start', 0.75, 0.6)]),
    'spore_mother': dict(fam='wet',
        voice=[('ent:spore_mother_rise', 0.75, 0.9), ('el:undead', 0.55, 0.5)],
        mats=[('sfx:boss/boss_spore_collapse.mp3', 0.80, 0.5)],
        death=[('ent:spore_mother_rise', 0.65, 0.9), ('sfx:boss/boss_spore_collapse.mp3', 0.75, 0.6), ('el:undead', 0.50, 0.6)]),
    'rot_colossus': dict(fam='beast',
        voice=[('el:beast', 0.55, 1.0), ('sfx:boss/colossus_crack.mp3', 0.80, 0.5)],
        mats=[('sfx:boss/boss_roots_crawl.mp3', 0.80, 0.5)],
        death=[('sfx:boss/colossus_crumble.mp3', 0.80, 0.8), ('el:beast', 0.50, 1.0)]),

    'dusk_shade': dict(fam='ghost',
        voice=[('el:undead', 0.55, 0.9), ('ent:dusk_shade_stop', 0.80, 0.6)],
        mats=[('sfx:event-enter-wind.mp3', 0.80, 0.5)],
        death=[('sfx:boss/boss_death_thud.mp3', 0.85, 0.8), ('el:undead', 0.45, 1.0), ('ent:dusk_shade_stop', 0.70, 0.6), ('sfx:boss/boss_eclipse_fade.mp3', 0.80, 0.5)]),
    'dusk_bat': dict(fam='vermin',
        voice=[('ent:dusk_bat_stop', 0.70, 0.8), ('el:beast', 0.90, 0.6)],
        mats=[('sfx:boss/boss_wing_pass.mp3', 0.85, 0.6)],
        death=[('ent:dusk_bat_stop', 0.65, 0.8), ('el:beast', 0.75, 0.8), ('sfx:boss/boss_feather_burst.mp3', 0.80, 0.5)]),
    'grave_thrall': dict(fam='undead',
        voice=[('el:undead', 0.70, 1.0), ('ent:grave_thrall_rise', 0.80, 0.5)],
        mats=[('sfx:scene-wood-knock.mp3', 0.65, 0.6), (ARMOR, 0.80, 0.4)],
        death=[('el:undead', 0.60, 1.0), ('ent:grave_thrall_rise', 0.75, 0.6), ('sfx:boss/boss_death_thud.mp3', 0.85, 0.6)]),
    'blood_duke': dict(fam='undead',
        voice=[('el:undead', 0.75, 1.0), ('ent:blood_duke_stop', 0.80, 0.4)],
        mats=[('sfx:impact-dark.mp3', 0.80, 0.5)],
        death=[('el:undead', 0.60, 1.0), ('ent:blood_duke_stop', 0.75, 0.6), ('sfx:boss/boss_wing_pass.mp3', 0.80, 0.5)]),
    'dullahan': dict(fam='metal',
        voice=[('el:undead', 0.55, 0.9), ('ent:dullahan_stop', 0.80, 0.7)],
        mats=[(ARMOR, 0.75, 0.7)],
        death=[('ent:dullahan_stop', 0.70, 0.8), ('el:undead', 0.45, 0.9), ('sfx:boss/tyrant_chain_snap.mp3', 0.80, 0.5)]),
    'fallen_angel': dict(fam='ghost',
        voice=[('el:undead', 0.70, 1.0), ('ent:fallen_angel_stop', 0.80, 0.5)],
        mats=[('sfx:boss/boss_feather_burst.mp3', 0.80, 0.5)],
        death=[('el:undead', 0.60, 1.0), ('ent:fallen_angel_start', 0.75, 0.6), ('sfx:boss/boss_feathers_settle.mp3', 0.85, 0.5)]),
    'eclipse_queen': dict(fam='ghost',
        voice=[('el:undead', 0.75, 1.0), ('sfx:boss/boss_eclipse_hum.mp3', 0.80, 0.35)],
        mats=[('sfx:impact-arcane.mp3', 0.75, 0.5)],
        death=[('sfx:boss/boss_death_thud.mp3', 0.85, 0.8), ('el:undead', 0.60, 1.0), ('sfx:boss/boss_eclipse_break.mp3', 0.80, 0.6), ('sfx:boss/boss_eclipse_fade.mp3', 0.80, 0.5)]),
}

_cache = {}


def source(ref):
    if ref in _cache:
        return _cache[ref]
    kind, name = ref.split(':', 1)
    path = {
        'el': lambda: os.path.join(RAW, 'el_%s_pain.mp3' % name),
        'ent': lambda: os.path.join(SFX, 'entrances', name + '.mp3'),
        'sfx': lambda: os.path.join(SFX, name),
        'aud': lambda: os.path.join(AUDIO, name),
    }[kind]()
    x = D.load(path)
    x = x / (np.max(np.abs(x)) + 1e-12)
    _cache[ref] = x
    return x


def peaks(x, k=3, sep=0.15):
    e = D.env(x, 0.01)
    order = np.argsort(e)[::-1]
    out = []
    for i in order:
        if e[i] < e.max() * 0.25:
            break
        if all(abs(i - j) * 0.01 >= sep for j in out):
            out.append(i)
        if len(out) == k:
            break
    return [i * 0.01 for i in out] or [0.0]


def warp(x, r0, r1):
    n = len(x)
    approx = int(n / ((r0 + r1) / 2))
    rate = np.linspace(r0, r1, approx)
    pos = np.concatenate([[0.0], np.cumsum(rate)[:-1]])
    pos = pos[pos < n - 1]
    return np.interp(pos, np.arange(n), x)


def excerpt(x, at, length, tau):
    a = max(0, int((at - 0.02) * SR))
    seg = x[a:a + int(length * SR)]
    tt = np.arange(len(seg)) / SR
    return D.fade(seg * np.exp(-tt / tau), 0.004, min(0.06, length * 0.3))


def layer(ref, p, g, variant, death, transient=False, droop=1.0):
    assert p <= 1.0 + 1e-9, ref
    x = source(ref)
    if death:
        ev = D.events(x, 0.12, -30, 0.05) or [(0.0, len(x) / SR)]
        a, b = max(ev, key=lambda e: e[1] - e[0])
        at = max(0.0, a - 0.01) + (0.08 if variant % 2 == 1 and b - a > 1.0 else 0.0)
        p = p * (1.0, 0.93)[variant % 2]
        seg = excerpt(x, at, 1.3 * p, 0.55 * p)
        return warp(seg, p, p * 0.82 * droop) * g
    pk = peaks(x, 3)
    at = pk[variant % len(pk)]
    p = p * (1.0, 0.95, 0.90)[variant % 3]
    length = (0.3 if transient else 0.44) * p
    seg = excerpt(x, at, length, (0.08 if transient else 0.14) * p)
    return warp(seg, p, p * 0.9 * droop) * g


def hpf(x, f=75):
    return signal.sosfilt(signal.butter(4, f / (SR / 2), btype='high', output='sos'), x)


def shelf(x, db, f=170):
    g = 10 ** (db / 20) - 1
    return x + g * signal.sosfilt(signal.butter(2, f / (SR / 2), output='sos'), x)


def drive(x, k):
    pk = np.max(np.abs(x)) + 1e-12
    return np.tanh(k * x / pk) / np.tanh(k)


def room(x, wet, rng, tail=0.32):
    if wet <= 0:
        return x
    n = int(tail * SR)
    ir = rng.standard_normal(n) * np.exp(-np.arange(n) / (tail / 5 * SR))
    ir = signal.sosfilt(signal.butter(2, 3500 / (SR / 2), output='sos'), ir)
    ir[:int(0.012 * SR)] = 0
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-12
    w = signal.fftconvolve(x, ir)
    w *= (np.max(np.abs(x)) / (np.max(np.abs(w)) + 1e-12))
    out = np.zeros(len(w))
    out[:len(x)] += x * (1 - wet * 0.5)
    out += w * wet
    return out


def breath(x, amt, rng):
    if amt <= 0:
        return x
    e = D.env(x, 0.01)
    e = np.repeat(e, int(0.01 * SR))
    e = np.pad(e, (0, max(0, len(x) - len(e))))[:len(x)]
    e = signal.sosfilt(signal.butter(1, 15 / (SR / 2), output='sos'), e)
    nz = signal.sosfilt(signal.butter(2, [180 / (SR / 2), 1000 / (SR / 2)], btype='band', output='sos'),
                        rng.standard_normal(len(x)))
    nz /= np.max(np.abs(nz)) + 1e-12
    return x + amt * nz * e / (e.max() + 1e-12) * np.max(np.abs(x))


def body(x, fam, rng):
    fx = FX[fam]
    y = shelf(x, fx['shelf'])
    y = drive(y, fx['drive'])
    y = signal.sosfilt(signal.butter(4, fx['lp'] / (SR / 2), output='sos'), y)
    y = breath(y, fx['breath'], rng)
    return hpf(room(y, fx['room'], rng))


def render(cid, event, variant, attempt=0):
    spec = SPEC[cid]
    rng = np.random.default_rng(zlib.crc32(('%s:%s:%d:%d' % (cid, event, variant, attempt)).encode()))
    droop = 0.9 ** attempt
    death = event == 'death'
    layers = []
    if death:
        for ref, p, g in spec['death']:
            layers.append((0.0, layer(ref, p, g, variant, True, False, droop), 1.0))
        ref, p, g = spec['mats'][0]
        layers.append((0.0, layer(ref, p, g * 0.9, variant, False, True, droop), 1.0))
    else:
        for ref, p, g in spec['voice']:
            layers.append((0.0, layer(ref, p, g, variant, False, False, droop), 1.0))
        for ref, p, g in spec['mats']:
            layers.append((rng.uniform(0, 0.01), layer(ref, p, g, variant, False, True, droop), 1.0))
    x = D.mix(*layers)
    x = body(x, spec['fam'], rng)
    cut = FX[spec['fam']]['lp']
    cap = spec.get('cap', CENTROID_CAP[spec['fam']])
    while D.centroid(x) > cap and cut > 1200:
        cut *= 0.85
        x = hpf(shelf(signal.sosfilt(signal.butter(2, cut / (SR / 2), output='sos'), x), 1.0))
    x = D.trim(x, -50)
    maxlen = 1.5 if death else 0.6
    if len(x) > maxlen * SR:
        x = D.fade(x[:int(maxlen * SR)], 0.003, 0.18 if death else 0.08)
    x = D.fade(x, 0.002, 0.10 if death else 0.04)
    return D.normalize(x, DEATH_LUFS if death else HURT_LUFS, CEIL)


def main(only=None):
    rows = []
    for cid in SPEC:
        if only and cid not in only:
            continue
        d = os.path.join(OUT, cid)
        os.makedirs(d, exist_ok=True)
        for ev, n in EVENTS.items():
            for v in range(n):
                path = os.path.join(d, '%s_%d.mp3' % (ev, v + 1))
                for attempt in range(5):
                    x = render(cid, ev, v, attempt)
                    if D.max_rise(x) <= RISE_MAX:
                        break
                D.save_mp3(x, path)
                rows.append(path)
    return rows


if __name__ == '__main__':
    rows = main(sys.argv[1:] or None)
    print('[ok] %d arquivos em %s' % (len(rows), OUT))
