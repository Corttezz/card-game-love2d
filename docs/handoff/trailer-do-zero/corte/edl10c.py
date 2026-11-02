import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from edl10b import *
import edl10b as _E10b
import edl9 as _E9

OUT = os.path.join(R, 'build', 'trailer', 'zero10c_rei' if VARIANT == 'rei' else 'zero10c')
OUT_NAME = 'corte10c'
NEW = 'zero_carrion_c10c'
NEW_DIR = os.path.join(APP, 'LOVE', 'card-game-trailer-v9', 'trailer_zero_c10c')
AUDIO_LOG = os.path.join(OUT, 'audio_merged.jsonl')
OLD_DEATH, NEW_DEATH = 52.90, 44.15
DD = round(OLD_DEATH - NEW_DEATH, 3)
GOLPE_TXT = '21'

_take_old = _E9.take_path


def take_path(shot):
    if shot == NEW:
        return os.path.join(NEW_DIR, NEW + '.mkv')
    return _take_old(shot)


for _m in (_E9, _E10b._E10 if hasattr(_E10b, '_E10') else None):
    if _m is not None:
        _m.take_path = take_path

if VARIANT == 'tirano':
    P = dict(nome_t1=38.93, g1=41.495, g_s0=25.432, e1=42.343, e_s0=29.85, e_fz=(42.095, 12),
             v_s0=30.60, v1=47.207, la_s0=39.55, lb=48.647, lb_s0=None)
else:
    P = dict(nome_t1=38.895, g1=41.379, g_s0=25.397, e1=42.656, e_s0=29.45, e_fz=(42.379, 12),
             v_s0=30.53, v1=47.672, la_s0=39.55, lb=48.926, lb_s0=None)
PLAY_END = 43.62
CORINGA_S0, CORINGA_LIVE = 49.60, 1.30


def _c10c():
    C = {c['id']: c for c in CLIPS}
    n, g = C['k_nome'], C['k_golpe']
    i0, i1 = CLIPS.index(n) + 1, CLIPS.index(g)
    n['t1'] = P['nome_t1']
    lb_s0 = round(PLAY_END - (g['t0'] - P['lb']), 3)
    novos = [
        dict(id='k_guerreiro', src=NEW, t0=P['nome_t1'], t1=P['g1'], s0=P['g_s0'], z=1),
        dict(id='k_inimigo', src=NEW, t0=P['g1'], t1=P['e1'], s0=P['e_s0'], z=1, fx=dict(freeze=P['e_fz'])),
        dict(id='k_vida', src=NEW, t0=P['e1'], t1=P['v1'], s0=P['v_s0'], z=1),
        dict(id='k_letal', src=NEW, t0=P['v1'], t1=P['lb'], s0=P['la_s0'], z=1),
        dict(id='k_letal_b', src=NEW, t0=P['lb'], t1=g['t0'], s0=lb_s0, z=1),
    ]
    CLIPS[i0:i1] = novos
    C = {c['id']: c for c in CLIPS}
    for cid in ('k_golpe', 'k_queda', 'k_coringa'):
        C[cid]['src'] = NEW
        C[cid]['s0'] = round(C[cid]['s0'] - DD, 3)
    f = C['k_golpe']['fx']
    f['number'] = (GOLPE_TXT,) + tuple(f['number'][1:])
    cr = C['k_coringa']
    cr['s0'] = CORINGA_S0
    tf = round(cr['t0'] + CORINGA_LIVE, 3)
    n = int(round((cr['t1'] - tf) * FPS))
    cr['fx'] = dict(freeze=(tf, n), card_depth=(tf, n), glint=(tf, 72))


_c10c()


def audio_edl():
    a = _E9.audio_edl()
    a['clips'] = [{'id': c['id'], 'src': 'take:' + c['src'], 't0': c['t0'], 't1': c['t1'], 'map': clip_map(c)}
                  for c in CLIPS if c['src'] != 'logo' and not c['src'].startswith('ai:')]
    return a


def merge_log():
    os.makedirs(OUT, exist_ok=True)
    with open(AUDIO_LOG, 'w', encoding='utf-8') as fo:
        for p in (os.path.join(TAKES, 'audio.jsonl'), os.path.join(NEW_DIR, 'audio.jsonl')):
            fo.write(open(p, encoding='utf-8').read())


if __name__ == '__main__':
    import json
    merge_log()
    prev = 0.0
    for c in CLIPS:
        assert abs(c['t0'] - prev) < 1e-6, c['id']
        assert c['t1'] - c['t0'] >= 0.4, c['id']
        prev = c['t1']
    assert abs(prev - DUR) < 1e-6
    for tx in TEXTS:
        assert [c for c in CLIPS if c['t0'] - 1e-6 <= tx['t0'] and tx['t1'] <= c['t1'] + 1e-6], tx['id']
    json.dump(audio_edl(), open(os.path.join(OUT, f'{os.path.basename(OUT)}_{VARIANT}_edl.json'), 'w', encoding='utf-8'), indent=1)
    for c in CLIPS:
        print(c['id'], c['src'], c['t0'], c['t1'], c['s0'], c.get('fx') or '')
    print('ok', VARIANT, len(CLIPS), 'clipes', prev, 's')
