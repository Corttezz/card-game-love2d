import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from edl9 import *
import edl9 as _E9

OUT = os.path.join(R, 'build', 'trailer', 'zero10_rei' if VARIANT == 'rei' else 'zero10')
OUT_NAME = 'corte10'
CUT = 'corte8'
FACE_T = None
LOGO = dict(spin0=57.77, seal_at=58.00, grimoire=58.60, genre=59.40, wishlist=61.98, fade0=63.0)
HOOK_D = 0.183


def _c10():
    C = {c['id']: c for c in CLIPS}
    g, ft = C['k_guerreiro'], C['k_revoada_rei']
    g_end = round(g['s0'] + (g['t1'] - g['t0']), 3)
    if VARIANT == 'tirano':
        cut, s_dr, fx = 40.90, 35.219, dict(shake=(40.90, 8, 6))
    else:
        cut, s_dr = 40.72, 35.214
        tf = round(cut + (35.70 - s_dr), 3)
        fx = dict(shake=(cut, 8, 6), freeze=(tf, 34))
    dr = dict(id='k_dreno', src='zero_carrion', t0=cut, t1=g['t1'], s0=s_dr, z=1, fx=fx)
    g.update(t1=cut, s0=round(g_end - (cut - g['t0']), 3))
    CLIPS.insert(CLIPS.index(g) + 1, dr)

    if VARIANT == 'tirano':
        for cid in ('h_mao', 'h_letal', 'h_cascata', 'h_morte'):
            C[cid]['s0'] = round(C[cid]['s0'] - HOOK_D, 3)
        f = C['h_letal']['fx']
        C['h_letal']['fx'] = dict(flash=(round(f['flash'][0] + HOOK_D, 3),) + f['flash'][1:], shake=(round(f['shake'][0] + HOOK_D, 3),) + f['shake'][1:])
        v = C['k_vida']
        nv = 43.212
        rv = C['k_revoada_rei']
        fz = rv['fx']['freeze']
        rv['fx'] = dict(freeze=(fz[0], fz[1] + int(round((nv - v['t0']) * FPS))))
        rv['t1'] = v['t0'] = nv
        for cid, nt in (('espolio', 8.533), ('k_revoada_rei', 41.506)):
            b = C[cid]
            a = CLIPS[CLIPS.index(b) - 1]
            b['s0'] = round(b['s0'] + (nt - b['t0']), 3)
            a['t1'] = b['t0'] = nt
        for tx in TEXTS:
            if tx['id'] == 'cartas':
                tx['t0'] = 8.533

    cr = C['k_coringa']
    if VARIANT == 'tirano':
        d, cut_hold = 0.583, 0
    else:
        d, cut_hold = 0.483, 3
    fz = cr['fx']['freeze']
    nf = (round(fz[0] - d, 3), fz[1] - cut_hold)
    cr['s0'] = round(cr['s0'] + d, 3)
    cr['fx'] = dict(freeze=nf, card_depth=nf, glint=(nf[0], cr['fx']['glint'][1]))
    cr['t1'] = C['logo']['t0'] = LOGO['spin0']


_c10()


def audio_edl():
    a = _E9.audio_edl()
    a['clips'] = [{'id': c['id'], 'src': 'take:' + c['src'], 't0': c['t0'], 't1': c['t1'], 'map': clip_map(c)}
                  for c in CLIPS if c['src'] != 'logo' and not c['src'].startswith('ai:')]
    return a


if __name__ == '__main__':
    import json
    os.makedirs(OUT, exist_ok=True)
    prev = 0.0
    for c in CLIPS:
        assert abs(c['t0'] - prev) < 1e-6, c['id']
        assert c['t1'] - c['t0'] >= 1.0 or c['id'] in ('k_golpe', 'k_dreno'), c['id']
        prev = c['t1']
    assert abs(prev - DUR) < 1e-6
    for tx in TEXTS:
        assert [c for c in CLIPS if c['t0'] - 1e-6 <= tx['t0'] and tx['t1'] <= c['t1'] + 1e-6], tx['id']
    json.dump(audio_edl(), open(os.path.join(OUT, f'{os.path.basename(OUT)}_{VARIANT}_edl.json'), 'w', encoding='utf-8'), indent=1)
    for c in CLIPS:
        print(c['id'], c['t0'], c['t1'], c['s0'], c.get('fx') or '')
    print(LOGO)
    print('ok', VARIANT, len(CLIPS), 'clipes', prev, 's')
