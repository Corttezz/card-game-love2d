import os, sys, re, subprocess
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dsp as D
import sheet as SH
import build as B

ROOT = B.ROOT
OUTDIR = os.path.join(ROOT, 'tools', 'preview_out', 'vozes_inimigos')

ROSTER = {
    1: ['cursed_scarecrow', 'hollow_farmer', 'plague_rats', 'harvest_reaper', 'blight_bull', 'wicker_effigy', 'carrion_king'],
    2: ['moon_gargoyle', 'ram_cultist', 'storm_harpy', 'rune_golem', 'spectral_knight', 'storm_griffin', 'tower_lich'],
    3: ['ember_imp', 'hellhound', 'abyss_acolyte', 'obsidian_sentinel', 'pit_brute', 'abyss_watcher', 'abyss_tyrant'],
    4: ['frost_wight', 'frost_wolf', 'rime_shaman', 'glacier_knight', 'frost_troll', 'ice_wyrm', 'winter_monarch'],
    5: ['bog_ghoul', 'plague_toad', 'leech_horror', 'mire_hag', 'croc_warrior', 'spore_mother', 'rot_colossus'],
    6: ['dusk_shade', 'dusk_bat', 'grave_thrall', 'blood_duke', 'dullahan', 'fallen_angel', 'eclipse_queen'],
}


def ff_lufs(path):
    p = subprocess.run(['ffmpeg', '-hide_banner', '-nostats', '-stream_loop', '3', '-i', path, '-af', 'ebur128=peak=true',
                        '-f', 'null', '-'], capture_output=True, text=True)
    s = p.stderr[p.stderr.rfind('Summary:'):]
    m = re.search(r'I:\s+(-?[\d.]+) LUFS', s)
    return float(m.group(1)) if m else None


def onset(x):
    e = D.env(x, 0.002)
    return float(np.argmax(e > e.max() * 0.5) * 0.002)


def main():
    lines = ['| criatura | arquivo | dur (s) | LUFS ativo | LUFS ebur128 (loop 4x) | pico dBFS | ataque (s) | veredito |',
             '|---|---|---|---|---|---|---|---|']
    bad = 0
    for act, ids in ROSTER.items():
        rows = []
        for cid in ids:
            for ev, n in B.EVENTS.items():
                for v in range(1, n + 1):
                    path = os.path.join(B.OUT, cid, '%s_%d.mp3' % (ev, v))
                    x = D.load(path)
                    dur = len(x) / D.SR
                    la = D.active_lufs(x)
                    lf = ff_lufs(path)
                    pk = D.peak_db(x)
                    on = onset(x)
                    lo, hi = (0.2, 0.62) if ev == 'hurt' else (0.6, 1.55)
                    ok = lo <= dur <= hi and pk <= -0.5 and on <= (0.06 if ev == 'hurt' else 0.12)
                    if not ok:
                        bad += 1
                    lines.append('| %s | %s_%d | %.2f | %.1f | %s | %.1f | %.3f | %s |' % (
                        cid, ev, v, dur, la, '%.1f' % lf if lf is not None else '-', pk, on, 'ok' if ok else 'FORA'))
                    rows.append(('%s %s_%d' % (cid, ev, v), x, '%.2fs %.1f LUFS pk %.1f' % (dur, la, pk)))
        SH.grid(rows, os.path.join(OUTDIR, 'ato%d.png' % act), 'vozes dos inimigos - ato %d (hurt_1..3, death_1..2; marca amarela = 0,5 s)' % act)
    with open(os.path.join(OUTDIR, 'tabela.md'), 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines) + '\n')
    print('[ok] tabela e folhas em %s, fora da faixa: %d' % (OUTDIR, bad))


if __name__ == '__main__':
    main()
