import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from edl10c import *
import edl10c as _E10c

OUT = os.path.join(R, 'build', 'trailer', 'zero10d_rei' if VARIANT == 'rei' else 'zero10d')
OUT_NAME = 'corte10d'
AUDIO_LOG = os.path.join(OUT, 'audio_merged.jsonl')
_E10c.OUT, _E10c.AUDIO_LOG = OUT, AUDIO_LOG
GOLPE_TXT = '33'
MOC_T, MOC_N = 30.433, 42

if VARIANT == 'tirano':
    Q = [
        dict(id='k_guerreiro', t1=42.343, s0=25.432),
        dict(id='k_inimigo', t1=43.794, s0=29.80, fz=True),
        dict(id='k_vida', t1=47.498, s0=30.95),
        dict(id='k_vida_b', t1=48.067, s0=35.00),
        dict(id='k_letal', t1=49.216, s0=39.55),
        dict(id='k_letal_b', t1=50.36, s0=None),
    ]
else:
    Q = [
        dict(id='k_guerreiro', t1=41.993, s0=25.635),
        dict(id='k_inimigo', t1=43.27, s0=29.95, fz=True),
        dict(id='k_vida', t1=48.274, s0=30.90),
        dict(id='k_letal', t1=49.528, s0=39.55),
        dict(id='k_letal_b', t1=50.36, s0=None),
    ]


def _c10d():
    C = {c['id']: c for c in CLIPS}
    g = C['k_golpe']
    i0 = CLIPS.index(C['k_guerreiro'])
    i1 = CLIPS.index(g)
    t = C['k_nome']['t1']
    novos = []
    for q in Q:
        s0 = q['s0'] if q['s0'] is not None else round(PLAY_END - (q['t1'] - t), 3)
        c = dict(id=q['id'], src=NEW, t0=t, t1=q['t1'], s0=s0, z=1)
        if q.get('fz'):
            c['fx'] = dict(freeze=(round(t + (MOC_T - s0), 3), MOC_N))
        novos.append(c)
        t = q['t1']
    CLIPS[i0:i1] = novos
    f = g['fx']
    f['number'] = (GOLPE_TXT,) + tuple(f['number'][1:])


_c10d()


def audio_edl():
    return _E10c.audio_edl()


def merge_log():
    _E10c.merge_log()


if __name__ == '__main__':
    import json
    merge_log()
    prev = 0.0
    for c in CLIPS:
        assert abs(c['t0'] - prev) < 1e-6, c['id']
        assert c['t1'] - c['t0'] >= 0.4, c['id']
        prev = c['t1']
    assert abs(prev - DUR) < 1e-6
    json.dump(audio_edl(), open(os.path.join(OUT, f'{os.path.basename(OUT)}_{VARIANT}_edl.json'), 'w', encoding='utf-8'), indent=1)
    for c in CLIPS[16:]:
        fz = c.get('fx', {}).get('freeze') if c.get('fx') else None
        live = c['t1'] - c['t0'] - (fz[1] / FPS if fz else 0)
        print(c['id'], c['src'], c['t0'], c['t1'], c['s0'], 'fim_tomada', round(c['s0'] + live, 3), c.get('fx') or '')
    print('ok', VARIANT, len(CLIPS), 'clipes', prev, 's')
