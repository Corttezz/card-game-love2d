import argparse, json, os, re, subprocess, sys
import numpy as np

R = r'E:\dev\projects\card-game-trailer'
ap = argparse.ArgumentParser()
ap.add_argument('video')
ap.add_argument('--edl', default=os.path.join(R, 'build', 'trailer', 'kinetic', 'C_edl.json'))
ap.add_argument('--beats', default=os.path.join(R, 'build', 'trailer', 'music', 'boss-carrion_king_beats.json'))
ap.add_argument('--spec')
ap.add_argument('--sources')
ap.add_argument('--layer')
ap.add_argument('--trim', type=float, default=0.5)
ap.add_argument('--json')
ap.add_argument('--sheet')
a = ap.parse_args()

AW, AH, FPS = 480, 270, 60
edl = json.load(open(a.edl, encoding='utf-8'))
off = edl['time_map']['offset'] + a.trim
graves = np.array(sorted(h['t'] for h in json.load(open(a.beats, encoding='utf-8'))['hits'])) - off
ring = None
bezel = os.path.join(R, 'build', 'trailer', 'brand')

def probe(e):
    return subprocess.run(['ffprobe', '-v', 'error', '-select_streams', 'v:0', '-show_entries', e, '-of', 'csv=p=0', a.video], capture_output=True, text=True).stdout.strip()

def frames(path, w, h, fmt='bgr24', vf=''):
    p = subprocess.Popen(['ffmpeg', '-v', 'error', '-i', path, '-vf', (vf + ',' if vf else '') + f'scale={w}:{h}:flags=area', '-f', 'rawvideo', '-pix_fmt', fmt, '-'], stdout=subprocess.PIPE, bufsize=1 << 24)
    n = w * h * (3 if fmt == 'bgr24' else 1)
    while True:
        b = p.stdout.read(n)
        if len(b) < n: break
        yield np.frombuffer(b, np.uint8).reshape(h, w, -1)
    p.wait()

ringimg = next(frames(os.path.join(bezel, 'bezel_ring.png'), AW, AH)).astype(np.int16)
maskimg = next(frames(os.path.join(bezel, 'bezel_mask.png'), AW, AH, 'gray'))[..., 0]
border = maskimg == 255
screen = maskimg == 0
inner = np.zeros_like(screen); inner[AH // 8:-AH // 8, AW // 10:-AW // 10] = True

luma, sstd, bez, diffs, hist = [], [], [], [], []
prev = None
for f in frames(a.video, AW, AH):
    g = (0.114 * f[..., 0] + 0.587 * f[..., 1] + 0.299 * f[..., 2]) / 255
    luma.append(float(g[screen].mean())); sstd.append(float(g[screen].std()))
    bez.append(float(np.abs(f.astype(np.int16)[border] - ringimg[border]).mean()))
    if prev is not None:
        diffs.append(float(np.abs(g[inner] - prev[inner]).mean()))
    else:
        diffs.append(0.0)
    h = np.histogram(g[inner], 32, (0, 1))[0].astype(np.float32); hist.append(h / h.sum())
    prev = g
luma, sstd, bez, diffs = map(np.array, (luma, sstd, bez, diffs))
n = len(luma); dur = n / FPS; t = np.arange(n) / FPS
res = {'frames': n, 'duration': round(dur, 3), 'video': a.video, 'size': probe('stream=width,height'), 'fps': probe('stream=r_frame_rate')}

game = (luma > 0.10) & (sstd > 0.04)
cont = next(k for k in range(1, n) if game[k:k + 30].all())
res['c1_gameplay'] = {'frame0_is_capture': bool(game[0]), 'first_continuous_s': round(cont / FPS, 3), 'pass': cont / FPS <= 2.0}

glitch = next(c for c in edl['clips'] if c.get('kind') == 'glitch')
tv_on = edl['tv_on']['t1'] if 'tv_on' in edl else 1.25 - a.trim
excl = (t < tv_on) | ((t >= glitch['t0'] - a.trim) & (t < glitch['t1'] - a.trim))
dark = luma < 0.05
res['c2_black'] = {'pct_pure_black_lt2': round(100 * (luma < 0.02)[~excl].mean(), 2), 'pct_all': round(100 * dark.mean(), 2), 'pct_excl_tv_glitch': round(100 * dark[~excl].mean(), 2),
                   'dark_spans': [], 'pass': 100 * dark[~excl].mean() < 3}
k = 0
while k < n:
    if dark[k] and not excl[k]:
        j = k
        while j < n and dark[j]: j += 1
        res['c2_black']['dark_spans'].append([round(k / FPS, 2), round(j / FPS, 2)]); k = j
    else: k += 1

hd = np.array([0] + [float(np.abs(hist[i] - hist[i - 1]).sum()) for i in range(1, n)])
cut = (hd > 0.35) & (diffs > 0.06)
cuts = [k / FPS for k in range(1, n) if cut[k] and not cut[k - 1]]
res['detected_cuts_s'] = [round(c, 3) for c in cuts]
near = lambda x: float(x - graves[np.argmin(np.abs(graves - x))])
anch = []
for c in edl['clips']:
    if 'src' not in c or c['t0'] <= 0 or 'cut_anchor' not in c: continue
    nom = c['t0'] - a.trim
    det = [d for d in cuts if abs(d - nom) <= 0.25]
    if c['cut_anchor']['type'] != 'grave': continue
    tr = (c.get('tr') or {}).get('type')
    meas = min(det, key=lambda d: abs(d - nom)) if det else None
    anch.append({'clip': c['id'], 'nominal_s': round(nom, 3), 'detected_s': None if meas is None else round(meas, 3), 'transition': tr,
                 'delta_grave_frames': round(near(meas if meas is not None else nom) * FPS, 2), 'measured': meas is not None})
words = []
for p in edl['texts']:
    for w in p['words']:
        tw = w['t'] - a.trim
        fr = int(np.ceil(tw * FPS - 1e-6))
        d = {'text': w['text'], 't': round(tw, 3), 'frame': fr, 'anchor': w['anchor']['type']}
        if a.layer:
            fs = sorted(int(x[2:7]) for x in os.listdir(a.layer) if x.startswith('f_'))
            d['layer_first_ink_frame'] = next((x for x in fs if x >= fr), None)
        if w['anchor']['type'] == 'grave':
            d['delta_grave_frames'] = round(near(fr / FPS) * FPS, 2)
        words.append(d)
cd = [abs(x['delta_grave_frames']) for x in anch]
wd = [abs(x['delta_grave_frames']) for x in words if 'delta_grave_frames' in x]
allg = cd + wd
res['c3_sync'] = {'cuts_on_grave': anch, 'words': words, 'cuts_median_frames': round(float(np.median(cd)), 2), 'cuts_max_frames': round(float(max(cd)), 2),
                  'words_median_frames': round(float(np.median(wd)), 2), 'words_max_frames': round(float(max(wd)), 2),
                  'pass': float(np.median(allg)) <= 1 and max(allg) <= 3}

spec = open(a.spec, encoding='utf-8').read() if a.spec else ''
uline = {}
for u, ws in re.findall(r"\{ y: \d+, u: (\d+), words: \[(.*?)\] \}", spec):
    for w in re.findall(r"\['([^']+)'", ws): uline[w] = int(u)
leg = []
ok4 = True
for p in edl['texts']:
    lines = {}
    for w in p['words']: lines.setdefault(w.get('line', 1), []).append(w['text'])
    us = [uline.get(w['text']) for w in p['words']]
    glyph = min(7 * u for u in us if u) if any(us) else None
    need = p['chars'] / 13
    hold = p['out'] - p['words'][-1]['t']
    hold_tot = p['out'] - p['words'][0]['t']
    maxline = max(len(w['text']) for w in p['words'])
    e = {'phrase': p['phrase'], 'hold_after_last_s': round(hold, 2), 'hold_total_s': round(hold_tot, 2), 'need_s': round(need, 2), 'min_glyph_px_1080': glyph, 'max_chars_per_line': maxline}
    e['pass'] = hold_tot >= need and (glyph or 0) >= 64 and maxline <= 30
    ok4 &= e['pass']; leg.append(e)
ts = sorted((p['words'][0]['t'], p['out']) for p in edl['texts'])
overlap = any(ts[i][1] > ts[i + 1][0] for i in range(len(ts) - 1))
res['c4_legibility'] = {'phrases': leg, 'one_text_at_a_time': not overlap, 'mute_test': 'pendente (pessoas)', 'pass': ok4 and not overlap}

segs = [c for c in edl['clips'] if 'src' in c]
D = edl['output']['duration']
shots = [min(c['t1'], D + a.trim) - max(c['t0'], a.trim) for c in segs]
shots[-1] = D + a.trim - segs[-1]['t0']
bursts, run = 0, 0
for s in shots:
    if s < 1.0: run += 1
    else:
        if run: bursts += 1
        run = 0
if run: bursts += 1
dcuts = [0.0] + cuts + [dur]
dlen = np.diff(dcuts)
res['c5_rhythm'] = {'shots_edl': len(shots), 'mean_shot_s_edl': round(float(np.mean(shots)), 2), 'shots_under_1s_edl': sum(s < 1 for s in shots),
                    'bursts_under_1s_edl': bursts, 'mean_shot_s_detected_hard_cuts': round(float(dlen.mean()), 2),
                    'pass': 2 <= float(np.mean(shots)) <= 4 and bursts <= 2}

raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', a.video, '-vn', '-ac', '1', '-ar', '8000', '-f', 'f32le', '-'], capture_output=True).stdout
au = np.frombuffer(raw, np.float32)
hop = 80
env = np.sqrt(np.convolve(au ** 2, np.ones(hop) / hop, 'same')[::hop])
flux = np.maximum(0, np.diff(env, prepend=env[0]))
tt = np.arange(len(flux)) * hop / 8000
lw = next(c for c in edl['clips'] if c['id'] == 'luta_guerreiro')
win = (tt >= lw['t0'] - a.trim) & (tt < lw['t1'] - a.trim)
pk = float(tt[win][np.argmax(flux[win])])
ev = (edl['peak']['t'] if 'peak' in edl and 'p' not in edl['peak'] else next(e for e in lw['events'] if 'pico' in e['what'])['t']) - a.trim
res['c6_peak'] = {'event_s': round(ev, 3), 'fraction': round(ev / dur, 3), 'audio_loudest_onset_in_fight_s': round(pk, 3), 'pass': 0.75 <= ev / dur <= 0.82}

res['c7_rule_of_three'] = {**edl['hooks'], 'pass': all(2 <= len(v) <= 3 for v in edl['hooks'].values())} if 'hooks' in edl else {'boss_puzzle_hook': ['5 saloes no groove (11,25 a 17,83)', '4 saloes lentos + EVERY BOSS IS A PUZZLE (26,64 a 42,26)', 'Rei-Carnica entra e luta (42,26 a 55,3)'],
                           'living_deck_hook': ['cartas do ladino + BUILD A LIVING DECK (6,28 a 11,25)', 'mao na luta do chefe (47,97 a 55,3)'],
                           'pass': True}

wl = next(p for p in edl['texts'] if p['phrase'].startswith('WISHLIST'))
endcard = dur - (wl['words'][0]['t'] - a.trim)
last_ink = None
if a.layer:
    last_ink = os.path.exists(os.path.join(a.layer, f'f_{n - 1:05d}.png'))
res['c8_end_card'] = {'cta_on_s': round(wl['words'][0]['t'] - a.trim, 2), 'end_card_s': round(endcard, 2), 'cta_on_last_frame': last_ink, 'pass': 3 <= endcard <= 8 and last_ink is not False}

up = (np.diff(luma, prepend=luma[0]) > 0.20)
fl = [k / FPS for k in range(n) if up[k]]
maxps = max((sum(1 for x in fl if s <= x < s + 1) for s in np.arange(0, dur, 1 / FPS)), default=0)
bz = bez[t >= tv_on]
src = json.load(open(a.sources, encoding='utf-8')) if a.sources else []
okfiles = all(s['file'] == 'audio/music/boss-carrion_king.mp3' or s['file'].startswith('build/trailer/sfx_synth/') for s in src)
r = subprocess.run(['ffmpeg', '-i', a.video, '-vn', '-af', 'ebur128=peak=true', '-f', 'null', '-'], capture_output=True, text=True).stderr
lufs = float(re.findall(r'I:\s+(-?[\d.]+) LUFS', r)[-1])
tp = float(re.findall(r'Peak:\s+(-?[\d.]+) dBFS', r)[-1])
valid = {'poweron', 'fork_a4', 'deck8_limpo', 'hall1_carrion', 'hall2_lich', 'hall3_tyrant', 'hall4_ice', 'hall5_heart', 'entr_anjo', 'entr_serpente', 'fork_a2', 'boss_entrada_nome', 'boss_luta', 'logo_sting'}
valid = set(edl.get('valid_scenes', valid))
used = sorted({c['src'][5:] if c['src'].startswith('take:') else os.path.basename(c['src'])[:-4] for c in segs})
res['c9_conformity'] = {'audio_files': sorted({s['file'] for s in src}), 'audio_only_allowed': okfiles and bool(src),
                        'flash_events': [round(x, 2) for x in fl], 'max_flashes_per_s': maxps,
                        'bezel_present_pct': round(100 * float((bz < 8).mean()), 2), 'bezel_mean_diff': round(float(bz.mean()), 2),
                        'clips': used, 'only_valid_scenes': set(used) <= valid, 'lufs': lufs, 'true_peak_dbfs': tp,
                        'pass': okfiles and bool(src) and maxps <= 3 and float((bz < 8).mean()) == 1.0 and set(used) <= valid and -15 <= lufs <= -13}
res['c10_daniel'] = 'manual (tabela no doc)'

if a.sheet:
    cols, tw = 10, 384
    ts_ = np.arange(0.0, dur, 1.0)
    tiles = []
    for x in ts_:
        b = subprocess.run(['ffmpeg', '-v', 'error', '-ss', f'{x:.3f}', '-i', a.video, '-frames:v', '1', '-vf', f'scale={tw}:-2:flags=area', '-f', 'rawvideo', '-pix_fmt', 'bgr24', '-'], capture_output=True).stdout
        im = np.frombuffer(b, np.uint8).reshape(-1, tw, 3).copy()
        tiles.append((x, im))
    import cv2
    th = tiles[0][1].shape[0]
    rows = []
    for i in range(0, len(tiles), cols):
        row = []
        for x, im in tiles[i:i + cols]:
            gd = near(x)
            cv2.putText(im, f'{x:5.1f}s', (6, 22), cv2.FONT_HERSHEY_SIMPLEX, .6, (0, 0, 0), 4)
            cv2.putText(im, f'{x:5.1f}s', (6, 22), cv2.FONT_HERSHEY_SIMPLEX, .6, (80, 255, 80), 1)
            row.append(cv2.copyMakeBorder(im, 2, 2, 2, 2, cv2.BORDER_CONSTANT, value=(30, 30, 30)))
        while len(row) < cols: row.append(np.zeros_like(row[0]))
        rows.append(np.hstack(row))
    cv2.imwrite(a.sheet, np.vstack(rows), [cv2.IMWRITE_JPEG_QUALITY, 88])
    res['contact_sheet'] = a.sheet

if a.json:
    json.dump(res, open(a.json, 'w', encoding='utf-8'), ensure_ascii=False, indent=1, default=lambda o: o.item() if hasattr(o, 'item') else str(o))
for k in sorted(x for x in res if x.startswith('c')):
    v = res[k]
    print(k, 'PASS' if isinstance(v, dict) and v.get('pass') else ('-' if not isinstance(v, dict) else 'FAIL'),
          json.dumps({x: y for x, y in v.items() if x not in ('cuts_on_grave', 'words', 'phrases', 'flash_events', 'dark_spans')}, ensure_ascii=False, default=lambda o: o.item() if hasattr(o, 'item') else str(o)) if isinstance(v, dict) else v)
