import os, sys, re, subprocess
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dsp as D
import sheet as SH
import build as B

OUTDIR = os.path.join(B.ROOT, 'tools', 'preview_out', 'vozes_inimigos', 'v2')
OLD = os.environ.get('ENEMY_VOICES_OLD')

ROSTER = {
    1: ['cursed_scarecrow', 'hollow_farmer', 'plague_rats', 'harvest_reaper', 'blight_bull', 'wicker_effigy', 'carrion_king'],
    2: ['moon_gargoyle', 'ram_cultist', 'storm_harpy', 'rune_golem', 'spectral_knight', 'storm_griffin', 'tower_lich'],
    3: ['ember_imp', 'hellhound', 'abyss_acolyte', 'obsidian_sentinel', 'pit_brute', 'abyss_watcher', 'abyss_tyrant'],
    4: ['frost_wight', 'frost_wolf', 'rime_shaman', 'glacier_knight', 'frost_troll', 'ice_wyrm', 'winter_monarch'],
    5: ['bog_ghoul', 'plague_toad', 'leech_horror', 'mire_hag', 'croc_warrior', 'spore_mother', 'rot_colossus'],
    6: ['dusk_shade', 'dusk_bat', 'grave_thrall', 'blood_duke', 'dullahan', 'fallen_angel', 'eclipse_queen'],
}
RISE_MAX = 1.06


def ff_lufs(path):
    p = subprocess.run(['ffmpeg', '-hide_banner', '-nostats', '-stream_loop', '3', '-i', path, '-af', 'ebur128=peak=true',
                        '-f', 'null', '-'], capture_output=True, text=True)
    s = p.stderr[p.stderr.rfind('Summary:'):]
    m = re.search(r'I:\s+(-?[\d.]+) LUFS', s)
    return float(m.group(1)) if m else None


def onset(x):
    e = D.env(x, 0.002)
    return float(np.argmax(e > e.max() * 0.5) * 0.002)


def files(cid):
    return [(ev, v) for ev, n in B.EVENTS.items() for v in range(1, n + 1)]


def main():
    os.makedirs(OUTDIR, exist_ok=True)
    lines = ['| criatura | familia | arquivo | dur (s) | LUFS ativo | LUFS ebur128 (loop 4x) | pico dBFS | ataque (s) | centroide v1 (Hz) | centroide v2 (Hz) | subida de pitch | veredito |',
             '|---|---|---|---|---|---|---|---|---|---|---|---|']
    fam_old, fam_new = {}, {}
    creature = ['', '| criatura | familia | centroide medio v1 (Hz) | centroide medio v2 (Hz) | veredito |', '|---|---|---|---|---|']
    bad = 0
    for act, ids in ROSTER.items():
        rows = []
        for cid in ids:
            fam = B.SPEC[cid]['fam']
            new_row, old_row = [], []
            for ev, v in files(cid):
                path = os.path.join(B.OUT, cid, '%s_%d.mp3' % (ev, v))
                x = D.load(path)
                dur = len(x) / D.SR
                la, lf, pk, on = D.active_lufs(x), ff_lufs(path), D.peak_db(x), onset(x)
                cn, rise = D.centroid(x), D.max_rise(x)
                co = None
                if OLD:
                    xo = D.load(os.path.join(OLD, cid, '%s_%d.mp3' % (ev, v)))
                    co = D.centroid(xo)
                    fam_old.setdefault(fam, []).append(co)
                    old_row.append(('v1 %s_%d' % (ev, v), xo, 'v1 %s_%d  c=%.0f Hz' % (ev, v, co)))
                fam_new.setdefault(fam, []).append(cn)
                lo, hi = (0.2, 0.62) if ev == 'hurt' else (0.6, 1.55)
                ok = lo <= dur <= hi and pk <= -0.5 and on <= (0.06 if ev == 'hurt' else 0.15) and rise <= RISE_MAX
                bad += 0 if ok else 1
                lines.append('| %s | %s | %s_%d | %.2f | %.1f | %s | %.1f | %.3f | %s | %.0f | %.2f | %s |' % (
                    cid, fam, ev, v, dur, la, '%.1f' % lf if lf is not None else '-', pk, on,
                    '%.0f' % co if co is not None else '-', cn, rise, 'ok' if ok else 'FORA'))
                new_row.append(('v2 %s_%d' % (ev, v), x, 'v2 %s_%d  c=%.0f Hz  %.1f LUFS' % (ev, v, cn, la)))
            if OLD:
                mo = np.mean([D.centroid(x) for _, x, _ in old_row])
                mn = np.mean([D.centroid(x) for _, x, _ in new_row])
                okc = mn < mo
                bad += 0 if okc else 1
                creature.append('| %s | %s | %.0f | %.0f | %s |' % (cid, fam, mo, mn, 'ok' if okc else 'FORA'))
            rows.append((cid + ' (v1)', old_row))
            rows.append((cid + ' (v2)', new_row))
        SH.ab_grid(rows, os.path.join(OUTDIR, 'ato%d_ab.png' % act),
                   'vozes v1 (rejeitada) x v2 - ato %d  (hurt_1..3, death_1..2; marca amarela = 0,5 s)' % act)
    lines += creature
    lines += ['', '| familia | centroide medio v1 (Hz) | centroide medio v2 (Hz) | arquivos |', '|---|---|---|---|']
    for fam in sorted(fam_new):
        o = np.mean(fam_old[fam]) if fam in fam_old else float('nan')
        lines.append('| %s | %.0f | %.0f | %d |' % (fam, o, np.mean(fam_new[fam]), len(fam_new[fam])))
    allo = [c for v in fam_old.values() for c in v]
    alln = [c for v in fam_new.values() for c in v]
    lines.append('| TODAS | %.0f | %.0f | %d |' % (np.mean(allo) if allo else float('nan'), np.mean(alln), len(alln)))
    with open(os.path.join(OUTDIR, 'tabela.md'), 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines) + '\n')
    print('[ok] tabela e folhas em %s, fora da faixa: %d' % (OUTDIR, bad))


if __name__ == '__main__':
    main()
