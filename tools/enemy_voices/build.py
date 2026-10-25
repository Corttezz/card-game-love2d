import os, sys, json, zlib
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dsp as D
import synth as S

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
SFX = os.path.join(ROOT, 'audio', 'sfx')
OUT = os.path.join(SFX, 'enemies')
RAW = os.path.join(ROOT, 'tools', 'preview_out', 'vozes_inimigos', 'raw')
SR = D.SR

HURT_LUFS = -17.0
DEATH_LUFS = -16.0
CEIL = -2.0

SRC = {
    'beast': os.path.join(RAW, 'el_beast_pain.mp3'),
    'undead': os.path.join(RAW, 'el_undead_pain.mp3'),
}

SPEC = {
    'cursed_scarecrow': dict(voice=[('ent:cursed_scarecrow_wake', 1.0, 0.8), ('syn:hiss', 1.0, 0.2, {'lo': 1200, 'hi': 4000})],
                             mats=[('straw', 0.4, {}), ('wood', 0.8, {})],
                             death=[('ent:cursed_scarecrow_stop', 1.0, 1.0), ('straw', 0.5, {'dur': 0.6})]),
    'hollow_farmer': dict(voice=[('src:undead', 1.05, 1.0)], mats=[('wood', 0.4, {}), ('thud', 0.45, {})],
                          death=[('src:undead', 0.9, 1.0), ('thud', 0.7, {'dur': 0.5, 'f0': 50})]),
    'plague_rats': dict(voice=[('syn:squeak', 1.0, 0.55), ('ent:plague_rats_stop', 1.1, 0.9)], mats=[('straw', 0.4, {})],
                        death=[('ent:plague_rats_stop', 1.0, 1.0), ('squeak', 0.6, {'dur': 0.5, 'n': 4})]),
    'harvest_reaper': dict(voice=[('syn:ghost', 1.0, 0.8, {'f0': 300}), ('ent:harvest_reaper_stop', 1.1, 0.6)],
                           mats=[('metal', 0.35, {'base': 700})],
                           death=[('ent:harvest_reaper_stop', 0.85, 0.8), ('ghost', 0.8, {'dur': 1.0, 'f0': 320, 'fall': 0.45})]),
    'blight_bull': dict(voice=[('src:beast', 0.85, 1.0)], mats=[('thud', 0.5, {}), ('wet', 0.25, {})],
                        death=[('src:beast', 0.75, 1.0), ('thud', 0.9, {'dur': 0.6, 'f0': 45})]),
    'wicker_effigy': dict(voice=[('ent:wicker_effigy_wake', 1.0, 0.9), ('syn:wood', 1.0, 0.5)], mats=[('fire', 0.6, {}), ('straw', 0.4, {})],
                          death=[('ent:wicker_effigy_wake', 0.85, 1.0), ('fire', 0.7, {'dur': 0.9}), ('straw', 0.5, {'dur': 0.7})]),
    'carrion_king': dict(voice=[('file:boss/crow/appear_2.mp3', 0.8, 0.7), ('src:undead', 0.8, 0.8)], mats=[('feathers', 0.6, {})],
                         death=[('file:boss/crow/cine_2.mp3', 0.9, 0.7), ('src:undead', 0.7, 1.0), ('feathers', 0.6, {'dur': 0.8})]),

    'moon_gargoyle': dict(voice=[('syn:shriek', 1.0, 0.7, {'f0': 1200, 'harsh': 0.9}), ('ent:moon_gargoyle_wake', 1.0, 0.6), ('src:beast', 1.6, 0.35)],
                          mats=[('stone', 0.6, {})],
                          death=[('ent:moon_gargoyle_wake', 0.9, 1.0), ('stone', 0.9, {'dur': 0.8, 'bright': 1.6})]),
    'ram_cultist': dict(voice=[('src:beast', 1.45, 0.8)], mats=[('hum', 0.3, {'f0': 110})],
                        death=[('src:beast', 1.2, 0.9), ('ent:ram_cultist_stop', 0.85, 0.6)]),
    'storm_harpy': dict(voice=[('syn:shriek', 1.0, 0.8, {'f0': 2000}), ('src:beast', 1.9, 0.4)], mats=[('feathers', 0.6, {})],
                        death=[('shriek', 0.9, {'dur': 0.7, 'f0': 1900}), ('ent:storm_harpy_start', 0.9, 0.7), ('feathers', 0.5, {'dur': 0.6})]),
    'rune_golem': dict(voice=[('ent:rune_golem_stop', 1.1, 0.8), ('syn:hum', 1.0, 0.5, {'f0': 90})], mats=[('stone', 0.8, {})],
                       death=[('ent:rune_golem_stop', 0.8, 1.0), ('stone', 0.9, {'dur': 0.9, 'bright': 1.4})]),
    'spectral_knight': dict(voice=[('syn:ghost', 1.0, 0.8, {'f0': 260}), ('ent:spectral_knight_stop', 1.0, 0.6)],
                            mats=[('metal', 0.5, {'hollow': True})],
                            death=[('ghost', 0.9, {'dur': 1.1, 'f0': 270, 'fall': 0.5}), ('ent:spectral_knight_stop', 0.85, 0.8), ('metal', 0.5, {'dur': 0.8, 'hollow': True})]),
    'storm_griffin': dict(voice=[('syn:shriek', 1.0, 0.7, {'f0': 1400}), ('src:beast', 1.3, 0.55)], mats=[('feathers', 0.6, {})],
                          death=[('ent:storm_griffin_stop', 0.9, 0.9), ('shriek', 0.8, {'dur': 0.7, 'f0': 1300})]),
    'tower_lich': dict(voice=[('syn:ghost', 1.0, 0.7, {'f0': 220}), ('src:undead', 0.8, 0.7)], mats=[('bone', 0.7, {})],
                       death=[('src:undead', 0.7, 1.0), ('bone', 0.8, {'dur': 0.9, 'n': 16}), ('ghost', 0.6, {'dur': 1.2, 'f0': 230, 'fall': 0.4})]),

    'ember_imp': dict(voice=[('syn:shriek', 1.0, 0.8, {'f0': 2600}), ('src:beast', 1.7, 0.5)], mats=[('fire', 0.6, {})],
                      death=[('shriek', 0.8, {'dur': 0.6, 'f0': 2400}), ('ent:ember_imp_rise', 1.1, 0.7), ('fire', 0.7, {'dur': 0.8})]),
    'hellhound': dict(voice=[('ent:hellhound_stop', 1.05, 0.8), ('src:beast', 1.15, 0.8)], mats=[('fire', 0.3, {})],
                      death=[('src:beast', 0.95, 1.0), ('ent:hellhound_stop', 0.9, 0.6), ('fire', 0.5, {'dur': 0.8})]),
    'abyss_acolyte': dict(voice=[('src:undead', 1.2, 0.85)], mats=[('hum', 0.4, {'f0': 65})],
                          death=[('src:undead', 1.0, 1.0), ('ent:abyss_acolyte_stop', 0.85, 0.6), ('hum', 0.4, {'dur': 0.9, 'f0': 60})]),
    'obsidian_sentinel': dict(voice=[('ent:obsidian_sentinel_wake', 1.1, 0.7)], mats=[('stone', 0.6, {'bright': 1.5}), ('metal', 0.6, {'base': 300})],
                              death=[('ent:obsidian_sentinel_wake', 0.85, 0.9), ('stone', 1.0, {'dur': 0.9, 'bright': 1.8})]),
    'pit_brute': dict(voice=[('src:beast', 0.75, 1.0), ('ent:pit_brute_stop', 1.0, 0.5)], mats=[('thud', 0.6, {})],
                      death=[('src:beast', 0.65, 1.0), ('ent:pit_brute_stop', 0.85, 0.7), ('thud', 1.0, {'dur': 0.7, 'f0': 42})]),
    'abyss_watcher': dict(voice=[('syn:ghost', 1.0, 0.5, {'f0': 180, 'breath': 1.0}), ('ent:abyss_watcher_stop', 1.2, 0.7)],
                          mats=[('wet', 0.7, {})],
                          death=[('ent:abyss_watcher_stop', 0.9, 1.0), ('wet', 0.8, {'dur': 0.8})]),
    'abyss_tyrant': dict(voice=[('src:beast', 0.6, 1.0)], mats=[('chain', 0.5, {}), ('fire', 0.3, {})],
                         death=[('src:beast', 0.55, 1.0), ('file:boss/tyrant_chain_snap.mp3', 0.9, 0.6), ('thud', 1.0, {'dur': 0.8, 'f0': 38})]),

    'frost_wight': dict(voice=[('syn:ghost', 1.0, 0.8, {'f0': 450}), ('ent:frost_wight_stop', 1.1, 0.5)], mats=[('ice', 0.6, {})],
                        death=[('ghost', 0.9, {'dur': 1.1, 'f0': 460, 'fall': 0.45}), ('ent:frost_wight_stop', 0.9, 0.7), ('ice', 0.6, {'dur': 0.6})]),
    'frost_wolf': dict(voice=[('src:beast', 1.3, 0.9), ('ent:frost_wolf_stop', 1.15, 0.4)], mats=[('straw', 0.25, {})],
                       death=[('ent:frost_wolf_stop', 0.95, 0.9), ('src:beast', 1.1, 0.7)]),
    'rime_shaman': dict(voice=[('src:undead', 1.15, 0.85)], mats=[('ice', 0.6, {}), ('wood', 0.3, {})],
                        death=[('src:undead', 1.0, 1.0), ('ent:rime_shaman_stop', 0.9, 0.6), ('ice', 0.6, {'dur': 0.6})]),
    'glacier_knight': dict(voice=[('src:undead', 0.95, 0.5)], mats=[('metal', 0.8, {}), ('ice', 0.5, {})],
                           death=[('ent:glacier_knight_stop', 0.85, 1.0), ('metal', 0.7, {'dur': 0.9}), ('ice', 0.6, {'dur': 0.7})]),
    'frost_troll': dict(voice=[('src:beast', 0.8, 1.0), ('ent:frost_troll_stop', 1.0, 0.5)], mats=[('ice', 0.3, {}), ('thud', 0.4, {})],
                        death=[('src:beast', 0.7, 1.0), ('ent:frost_troll_start', 0.9, 0.6), ('thud', 0.9, {'dur': 0.7, 'f0': 42})]),
    'ice_wyrm': dict(voice=[('src:beast', 0.9, 0.9), ('syn:hiss', 1.0, 0.5)], mats=[('ice', 0.6, {})],
                     death=[('src:beast', 0.75, 1.0), ('ent:ice_wyrm_rise', 0.9, 0.7), ('ice', 0.7, {'dur': 0.7})]),
    'winter_monarch': dict(voice=[('syn:ghost', 1.0, 0.6, {'f0': 300}), ('src:undead', 0.85, 0.7)], mats=[('ice', 0.7, {})],
                           death=[('file:boss/boss_frost_shatter.mp3', 0.9, 0.7), ('ghost', 0.8, {'dur': 1.2, 'f0': 300, 'fall': 0.4}), ('src:undead', 0.75, 0.8)]),

    'bog_ghoul': dict(voice=[('src:undead', 1.0, 1.0)], mats=[('wet', 0.6, {})],
                      death=[('src:undead', 0.85, 1.0), ('ent:bog_ghoul_rise', 0.9, 0.6), ('wet', 0.7, {'dur': 0.7})]),
    'plague_toad': dict(voice=[('syn:croak', 1.0, 0.9)], mats=[('wet', 0.7, {})],
                        death=[('croak', 1.0, {'dur': 0.8, 'f0': 30}), ('ent:plague_toad_stop', 0.9, 0.8), ('wet', 0.6, {'dur': 0.6})]),
    'leech_horror': dict(voice=[('syn:hiss', 1.0, 0.5, {'lo': 1200, 'hi': 5000}), ('ent:leech_horror_rise', 1.15, 0.8)], mats=[('wet', 0.9, {})],
                         death=[('ent:leech_horror_rise', 0.9, 1.0), ('wet', 0.9, {'dur': 0.9})]),
    'mire_hag': dict(voice=[('src:undead', 1.35, 0.9)], mats=[('wet', 0.4, {}), ('wood', 0.3, {})],
                     death=[('src:undead', 1.2, 1.0), ('ent:mire_hag_stop', 0.9, 0.7)]),
    'croc_warrior': dict(voice=[('ent:croc_warrior_stop', 1.0, 0.8), ('src:beast', 0.95, 0.7)], mats=[('wet', 0.5, {})],
                         death=[('src:beast', 0.8, 1.0), ('ent:croc_warrior_start', 0.9, 0.7)]),
    'spore_mother': dict(voice=[('syn:hiss', 1.0, 0.6, {'lo': 1500, 'hi': 7000}), ('ent:spore_mother_rise', 1.1, 0.8)], mats=[('wet', 0.7, {})],
                         death=[('ent:spore_mother_rise', 0.85, 1.0), ('file:boss/boss_spore_collapse.mp3', 1.0, 0.6), ('wet', 0.6, {'dur': 0.8})]),
    'rot_colossus': dict(voice=[('src:beast', 0.6, 0.9), ('file:boss/colossus_crack.mp3', 1.0, 0.6)], mats=[('wet', 0.4, {}), ('wood', 0.4, {'f0': 80})],
                         death=[('file:boss/colossus_crumble.mp3', 0.9, 0.9), ('src:beast', 0.55, 1.0)]),

    'dusk_shade': dict(voice=[('syn:ghost', 1.0, 0.8, {'f0': 500}), ('ent:dusk_shade_stop', 1.1, 0.6)], mats=[('hiss', 0.4, {'lo': 1500, 'hi': 6000})],
                       death=[('ghost', 0.9, {'dur': 1.1, 'f0': 520, 'fall': 0.4}), ('ent:dusk_shade_stop', 0.85, 0.8)]),
    'dusk_bat': dict(voice=[('syn:squeak', 1.0, 0.6, {'n': 2}), ('ent:dusk_bat_stop', 1.15, 0.9)], mats=[('feathers', 0.6, {})],
                     death=[('ent:dusk_bat_stop', 0.95, 0.9), ('squeak', 0.7, {'dur': 0.5, 'n': 3}), ('feathers', 0.5, {'dur': 0.6})]),
    'grave_thrall': dict(voice=[('src:undead', 0.95, 0.8)], mats=[('bone', 0.8, {})],
                         death=[('bone', 1.0, {'dur': 0.9, 'n': 16}), ('src:undead', 0.85, 0.8), ('ent:grave_thrall_rise', 0.9, 0.5)]),
    'blood_duke': dict(voice=[('src:undead', 1.1, 0.8), ('syn:hiss', 1.0, 0.4)], mats=[('feathers', 0.5, {})],
                       death=[('ent:blood_duke_stop', 0.9, 0.9), ('src:undead', 1.0, 0.8), ('hiss', 0.5, {'dur': 0.8})]),
    'dullahan': dict(voice=[('syn:ghost', 1.0, 0.6, {'f0': 200}), ('ent:dullahan_stop', 1.05, 0.6)], mats=[('metal', 0.7, {})],
                     death=[('ent:dullahan_stop', 0.85, 1.0), ('metal', 0.6, {'dur': 0.9}), ('ghost', 0.6, {'dur': 1.0, 'f0': 210, 'fall': 0.45})]),
    'fallen_angel': dict(voice=[('src:undead', 1.05, 0.6), ('syn:shimmer', 1.0, 0.4, {'base': 660})], mats=[('feathers', 0.6, {})],
                         death=[('ent:fallen_angel_start', 0.85, 0.8), ('feathers', 0.6, {'dur': 0.8}), ('ghost', 0.6, {'dur': 1.1, 'f0': 400, 'fall': 0.5})]),
    'eclipse_queen': dict(voice=[('syn:ghost', 1.0, 0.7, {'f0': 600}), ('src:undead', 1.2, 0.6)], mats=[('shimmer', 0.4, {'base': 520})],
                          death=[('file:boss/boss_eclipse_break.mp3', 0.9, 0.8), ('ghost', 0.8, {'dur': 1.3, 'f0': 600, 'fall': 0.4}), ('shimmer', 0.4, {'dur': 1.0, 'base': 440})]),
}

_cache = {}


def source(ref):
    if ref in _cache:
        return _cache[ref]
    kind, name = ref.split(':', 1)
    if kind == 'src':
        path = SRC[name]
    elif kind == 'ent':
        path = os.path.join(SFX, 'entrances', name + '.mp3')
    else:
        path = os.path.join(SFX, name)
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


def excerpt(x, at, length, tau):
    a = max(0, int((at - 0.02) * SR))
    seg = x[a:a + int(length * SR)]
    tt = np.arange(len(seg)) / SR
    shaped = seg * np.exp(-tt / tau)
    return D.fade(shaped, 0.004, min(0.06, length * 0.3))


def synth_voice(name, rng, dur, kw):
    kw = dict(kw)
    kw.setdefault('dur', dur)
    return S.norm1(S.MATERIALS[name](rng, **kw))


def build_layer(item, rng, variant, death):
    ref, p, g = item[0], item[1], item[2]
    kw = item[3] if len(item) > 3 else {}
    jitter = [1.0, 0.94, 1.07][variant % 3]
    if ref.startswith('syn:'):
        dur = 0.9 if death else rng.uniform(0.3, 0.42)
        sig = synth_voice(ref[4:], rng, dur, kw)
        return D.pitch(sig, jitter) * g
    x = source(ref)
    if death:
        ev = D.events(x, 0.12, -30, 0.05) or [(0.0, len(x) / SR)]
        a, b = max(ev, key=lambda e: e[1] - e[0])
        at = max(0.0, a - 0.01)
        if variant % 2 == 1 and b - a > 1.0:
            at += 0.08
        sig = excerpt(x, at, 1.25, 0.5)
        return D.pitch(sig, p * (1.0, 0.93)[variant % 2]) * g
    pk = peaks(x, 3)
    at = pk[variant % len(pk)]
    sig = excerpt(x, at, 0.42, 0.11)
    return D.pitch(sig, p * jitter) * g


def mat_layer(name, g, kw, rng, death):
    kw = dict(kw)
    if not death:
        kw.setdefault('dur', rng.uniform(0.28, 0.4))
    return S.norm1(S.MATERIALS[name](rng, **kw)) * g


def render(cid, event, variant):
    spec = SPEC[cid]
    seed = zlib.crc32(('%s:%s:%d' % (cid, event, variant)).encode())
    rng = np.random.default_rng(seed)
    death = event == 'death'
    layers = []
    if death:
        for item in spec['death']:
            if ':' in item[0]:
                layers.append((0.0, build_layer(item, rng, variant, True), 1.0))
            else:
                layers.append((0.0, mat_layer(item[0], item[1], item[2], rng, True), 1.0))
        for name, g, kw in spec['mats'][:1]:
            layers.append((0.0, mat_layer(name, g * 0.8, {}, rng, False), 1.0))
    else:
        for item in spec['voice']:
            layers.append((0.0, build_layer(item, rng, variant, False), 1.0))
        for name, g, kw in spec['mats']:
            layers.append((rng.uniform(0, 0.012), mat_layer(name, g, kw, rng, False), 1.0))
    x = D.mix(*layers)
    x = D.trim(x, -50)
    maxlen = 1.5 if death else 0.6
    if len(x) > maxlen * SR:
        x = D.fade(x[:int(maxlen * SR)], 0.003, 0.15 if death else 0.06)
    x = D.fade(x, 0.002, 0.08 if death else 0.03)
    return D.normalize(x, DEATH_LUFS if death else HURT_LUFS, CEIL)


EVENTS = {'hurt': 3, 'death': 2}


def main(only=None):
    rows = []
    for cid in SPEC:
        if only and cid not in only:
            continue
        d = os.path.join(OUT, cid)
        os.makedirs(d, exist_ok=True)
        for ev, n in EVENTS.items():
            for v in range(n):
                x = render(cid, ev, v)
                path = os.path.join(d, '%s_%d.mp3' % (ev, v + 1))
                D.save_mp3(x, path)
                rows.append((cid, ev, v + 1, path))
    return rows


if __name__ == '__main__':
    rows = main(sys.argv[1:] or None)
    print('[ok] %d arquivos em %s' % (len(rows), OUT))
