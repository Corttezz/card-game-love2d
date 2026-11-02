import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from edl10 import *
import edl10 as _E10

OUT = os.path.join(R, 'build', 'trailer', 'zero10b_rei' if VARIANT == 'rei' else 'zero10b')
OUT_NAME = 'corte10b'

T_BASH = 27.233
T_TICK = 31.800
T_DRENO = 35.225
T_MOC = 36.950

if VARIANT == 'tirano':
    P = dict(nome_t1=38.93, g1=39.789, hit=39.498, e1=40.358, tick=40.926, c1=41.495, d1=42.064,
             m_s0=36.70, m_fz=36, vida_s0=37.40)
else:
    P = dict(nome_t1=38.895, g1=40.16, hit=39.498, e1=40.741, tick=41.379, c1=41.879, d1=42.42,
             m_s0=36.80, m_fz=24, vida_s0=37.30)


def _c10b():
    C = {c['id']: c for c in CLIPS}
    n, v = C['k_nome'], C['k_vida']
    i0, i1 = CLIPS.index(n) + 1, CLIPS.index(v)
    n['t1'] = P['nome_t1']
    m_t0 = P['d1']
    fz_t = round(m_t0 + (T_MOC - P['m_s0']), 3)
    novos = [
        dict(id='k_guerreiro', src='zero_carrion', t0=P['nome_t1'], t1=P['g1'], s0=round(T_BASH - (P['hit'] - P['nome_t1']), 3), z=1),
        dict(id='k_inimigo', src='zero_carrion', t0=P['g1'], t1=P['e1'], s0=29.75, z=1),
        dict(id='k_corvos', src='zero_carrion', t0=P['e1'], t1=P['c1'], s0=round(T_TICK - (P['tick'] - P['e1']), 3), z=1),
        dict(id='k_dreno', src='zero_carrion', t0=P['c1'], t1=P['d1'], s0=T_DRENO, z=1, fx=dict(shake=(P['c1'], 8, 6))),
        dict(id='k_revoada_rei', src='zero_carrion', t0=m_t0, t1=v['t0'], s0=P['m_s0'], z=1, fx=dict(freeze=(fz_t, P['m_fz']))),
    ]
    CLIPS[i0:i1] = novos
    v['s0'] = P['vida_s0']


_c10b()


def audio_edl():
    a = _E10._E9.audio_edl()
    a['clips'] = [{'id': c['id'], 'src': 'take:' + c['src'], 't0': c['t0'], 't1': c['t1'], 'map': clip_map(c)}
                  for c in CLIPS if c['src'] != 'logo' and not c['src'].startswith('ai:')]
    return a


if __name__ == '__main__':
    import json
    os.makedirs(OUT, exist_ok=True)
    prev = 0.0
    for c in CLIPS:
        assert abs(c['t0'] - prev) < 1e-6, c['id']
        assert c['t1'] - c['t0'] >= 1.0 or c['id'] in ('k_golpe', 'k_dreno', 'k_guerreiro', 'k_inimigo', 'k_corvos', 'k_revoada_rei'), c['id']
        prev = c['t1']
    assert abs(prev - DUR) < 1e-6
    for tx in TEXTS:
        assert [c for c in CLIPS if c['t0'] - 1e-6 <= tx['t0'] and tx['t1'] <= c['t1'] + 1e-6], tx['id']
    json.dump(audio_edl(), open(os.path.join(OUT, f'{os.path.basename(OUT)}_{VARIANT}_edl.json'), 'w', encoding='utf-8'), indent=1)
    for c in CLIPS:
        print(c['id'], c['t0'], c['t1'], c['s0'], c.get('fx') or '')
    print('ok', VARIANT, len(CLIPS), 'clipes', prev, 's')
