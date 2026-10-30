# make_edl.py: EDL of concept C, second cut (grimoire_trailer_v9_kinetic): the v8 design on the graves of boss-carrion_king.mp3,
# now with the re-recorded takes: the griffin back, the castle door seen from outside, the fight tail with the number readable.
# Times are of the trimmed film (v9 started 0.50 s into the v8): t = p - 9.05.
import json, os
R = r'E:\dev\projects\card-game-trailer'
TAKES = os.path.join(os.environ['APPDATA'], 'LOVE', 'card-game-trailer-v9', 'trailer')
OFF, DUR = 9.05, 64.5
hits = sorted(h['t'] for h in json.load(open(os.path.join(R, 'build', 'trailer', 'music', 'boss-carrion_king_beats.json')))['hits'])
G = [round(h - OFF, 3) for h in hits]

def anchor(t, what=None):
    d = min(G, key=lambda g: abs(g - t))
    if abs(d - t) < 0.02: return {'type': 'grave', 'p': round(t + OFF, 2), 'delta': round(t - d, 3)}
    a = {'type': 'sem_grave', 'p': round(t + OFF, 2), 'nearest_grave': round(d + OFF, 2), 'delta': round(t - d, 3)}
    if what: a['what'] = what
    return a

def take(id_, shot, t0, t1, mp, tr=None, note='', events=()):
    c = {'id': id_, 'src': f'take:{shot}', 't0': t0, 't1': t1, 'map': mp, 'cut_anchor': anchor(t0), 'note': note}
    if tr: c['tr'] = tr
    if events: c['events'] = [{'what': w, 'frame': f, 't': t, 'anchor': anchor(t)} for w, f, t in events]
    return c

def mp4(id_, path, t0, t1, cin, speed=1.0, tr=None, note=''):
    c = {'id': id_, 'src': path, 't0': t0, 't1': t1, 'in': cin, 'out': cin + (t1 - t0) * speed + 2, 'speed': speed, 'cut_anchor': anchor(t0), 'note': note}
    if tr: c['tr'] = tr
    return c

H = 'build/trailer/kinetic/clips_v8/'
clips = [mp4('tv_estrada', H + 'poweron.mp4', 0.0, 3.51, 0.5, note='TV do v8 ligando (ponto, linha, imagem em 0,75) e estrada do ato 1; comeca 0,50 s dentro do v8')]
clips[0]['cut_anchor'] = {'type': 'inicio'}
clips[0]['out'] = 4.0
clips += [
    take('encruzilhada_a1', 'fork_a1', 3.51, 5.78, [[3.51, 100], [5.78, 236]], tr={'type': 'glitch_soft', 'd': 0.12}, note='encruzilhada do ato 1 sem texto (tomada nova; no v9 era o fork_a4)'),
    take('cartas_ladino', 'deck8', 5.78, 10.75, [[5.78, 795], [6.67, 830], [7.30, 868], [8.55, 946], [9.81, 1043], [10.75, 1099]], tr={'type': 'dissolve', 'd': 0.3},
         note='deck da tomada nova (faixa de coringas tapada); golpes 1, 2 e 4 nos graves das palavras BUILD / A LIVING / DECK.',
         events=[('JOGAR', 830, 6.67), ('golpe 1', 868, 7.30), ('golpe 2', 946, 8.55), ('golpe 3 (COMBO)', 989, 9.11), ('golpe 4', 1043, 9.81)]),
]
acc = [('hall1_carrion', 2.0, 'flash'), ('hall2_lich', 1.33, 'zoom'), ('hall3_tyrant', 1.0, 'zoom'), ('hall4_ice', 1.33, 'zoom'), ('hall5_heart', 4.0, 'zoom')]
at = [10.75, 12.30, 13.57, 14.83, 15.77, 17.33]
for i, (h, cin, tr) in enumerate(acc):
    clips.append(mp4(f'salao_acento_{h}', H + h + '.mp4', at[i], at[i + 1], cin, tr={'type': tr, 'd': 0.16 if tr == 'flash' else 0.1}, note='salao 4K Higgsfield (IA, declarar), um por grave'))
clips += [
    take('entrada_grifo', 'entr_storm_griffin', 17.33, 19.86, [[17.33, 585], [18.59, 661], [19.86, 737]], tr={'type': 'glitch_soft', 'd': 0.12},
         note='o grifo volta (tomada nova): rasante e pouso no grave de DECIDE', events=[('pouso', 661, 18.59)]),
    take('entrada_anjo', 'entr_fallen_angel', 19.86, 21.10, [[19.86, 582], [21.10, 656]], tr={'type': 'glitch_soft', 'd': 0.12}, note='anjo caido pousando', events=[('pouso', 620, 20.49)]),
    take('entrada_serpente', 'entr_ice_wyrm', 21.10, 22.36, [[21.10, 470], [22.36, 546]], tr={'type': 'glitch_soft', 'd': 0.12}, note='serpente de gelo emergindo'),
    take('estrada_a_noite', 'fork_a2', 22.36, 26.14, [[22.36, 100], [26.14, 327]], tr={'type': 'dissolve', 'd': 0.4}, note='encruzilhada do ato 2 a noite, castelo ao centro, a 1,0x (no v9 era o clipe do v8 a 0,56x)'),
]
pad = [('hall2_lich', 3.0, 26.14, 30.045), ('hall3_tyrant', 2.4, 30.045, 33.95), ('hall4_ice', 2.4, 33.95, 37.855), ('hall1_carrion', 3.8, 37.855, 39.01)]
for h, cin, a, b in pad:
    clips.append(mp4(f'salao_pad_{h}', H + h + '.mp4', a, b, cin, tr={'type': 'dissolve', 'd': 0.6}, note='pad sem grave: passada lenta nos saloes'))
clips += [
    take('porta', 'boss8', 39.01, 41.76, [[39.01, 399], [41.76, 564]], tr={'type': 'dissolve', 'd': 0.6},
         note='porta do castelo vista de fora (tomada nova): o rangido comeca no IS A PUZZLE. e o portao abre no baque', events=[('portao', 564, 41.76)]),
    take('luta_guerreiro', 'boss8', 41.76, 55.94, [[41.76, 745], [46.21, 1015], [52.49, 1448], [53.67, 1519], [54.42, 1564], [55.94, 1655]],
         note='corte seco no baque para os olhos no escuro, rasantes, pouso, cartao do nome no grave 55,26, luta sem corte (faixa de coringas tapada); golpe de 42 no pico (grave 61,54); 27+COMBO em 54,42 e 1,52 s de numero legivel ate o glitch no grave 64,99 (antes do tooltip 1661)',
         events=[('cartao do nome', 1015, 46.21), ('JOGAR', 1422, 52.06), ('golpe 1: 42, numero maior (pico)', 1448, 52.49), ('golpe 2: 33', 1519, 53.67), ('golpe 3: 27 + COMBO', 1564, 54.42)]),
    {'id': 'glitch', 'kind': 'glitch', 't0': 55.94, 't1': 56.13, 'note': 'glitch do editor, do grave 64,99'},
]
clips.append(mp4('logo', H + 'logo_sting.mp4', 56.13, DUR, 0.0, speed=1.0, note='logo_sting 1,0x: impacto da arte (2,62 s) no grave 67,79'))
clips[-1]['out'] = 6.5
clips[-1]['hold_last_frame_until'] = DUR
clips[-1]['events'] = [{'what': 'impacto/flash do logo', 'clip_t': 2.62, 't': 58.75, 'anchor': anchor(58.75)}]

def phrase(name, words, out):
    ws = [{'text': w, 't': t, 'anchor': anchor(t, what)} | ({'line': ln} if ln else {}) for w, t, ln, what in words]
    return {'phrase': name, 'words': ws, 'out': out, 'chars': len(name), 'hold_after_last_word': round(out - ws[-1]['t'], 2),
            'hold_total': round(out - ws[0]['t'], 2), 'min_by_rule_13cps': round(len(name) / 13, 2)}
texts = [
    phrase('SIX ACTS. ONE ROAD TO THE CASTLE.', [('SIX', 1.0, 0, None), ('ACTS.', 2.28, 0, None), ('ONE ROAD TO THE CASTLE.', 3.51, 2, None)], 5.75),
    phrase('BUILD A LIVING DECK.', [('BUILD', 7.30, 0, None), ('A LIVING', 8.55, 0, None), ('DECK.', 9.81, 2, None)], 10.70),
    phrase('YOUR CARDS DECIDE WHAT SURVIVES.', [('YOUR CARDS', 17.33, 0, None), ('DECIDE', 18.59, 0, None), ('WHAT SURVIVES.', 19.86, 2, None)], 22.30),
    phrase('EVERY BOSS IS A PUZZLE.', [('EVERY BOSS', 37.855, 0, 'corte do salao, pad sem grave'), ('IS A PUZZLE.', 39.01, 2, 'rangido da porta')], 41.45),
    phrase('WISHLIST ON STEAM.', [('WISHLIST ON STEAM.', 60.01, 0, None)], DUR),
]
manifest = json.load(open(os.path.join(R, 'build', 'trailer', 'sfx_synth', 'manifest.json')))['files']
def sfx(f, t, g, what):
    hit = manifest[f]['hit']
    return {'file': 'build/trailer/sfx_synth/' + f, 'attack_offset': hit, 'event_t': t, 'start_t': round(t - hit, 3), 'gain_db': g, 'what': what, 'anchor': anchor(t)}
S = [sfx('tv_on.wav', 0.0, -8, 'TV liga'), sfx('whoosh_2.wav', 3.51, -3, 'encruzilhada'),
     sfx('impact_1.wav', 7.30, -8, 'golpe 1'), sfx('impact_2.wav', 8.55, -9, 'golpe 2'), sfx('impact_1.wav', 9.11, -10, 'golpe 3'), sfx('impact_2.wav', 9.81, -9, 'golpe 4')]
S += [sfx('whoosh_2.wav', t, -3, 'salao') for t in at[:5]]
S += [sfx('whoosh_1.wav', 17.33, -3, 'entrada do grifo'), sfx('impact_2.wav', 18.59, -9, 'pouso do grifo'), sfx('whoosh_1.wav', 19.86, -3, 'entrada do anjo'),
      sfx('impact_2.wav', 20.49, -10, 'pouso do anjo'), sfx('whoosh_1.wav', 21.10, -3, 'serpente'), sfx('whoosh_1.wav', 22.36, -8, 'estrada a noite'),
      sfx('castle_door.wav', 41.76, -4, 'rangido sobre o salao e a porta, baque no portao'), sfx('impact_heavy.wav', 46.21, -6, 'cartao do nome'),
      sfx('impact_heavy.wav', 52.49, -4, 'golpe 42, pico'), sfx('impact_2.wav', 53.67, -9, 'golpe 33'), sfx('impact_1.wav', 54.42, -7, 'golpe 27 + COMBO'),
      sfx('glitch.wav', 55.94, -9, 'glitch'), sfx('impact_1.wav', 58.75, -6, 'flash do logo'), sfx('logo_seal.wav', 60.01, -2, 'selo + WISHLIST')]
edl = {'id': 'grimoire_trailer_v9_kinetic', 'concept': 'C (2o corte): desenho do v8 nos graves do Rei-Carnica, com grifo, porta vista de fora e cauda da luta das tomadas novas',
       'root': 'E:/dev/projects/card-game-trailer', 'takes': TAKES.replace('\\', '/'),
       'output': {'size': [3840, 2160], 'fps': 60, 'duration': DUR, 'loudness_lufs': -14},
       'time_map': {'rule': 't = p - 9.05 (v9 aparado em 0,50 s)', 'offset': OFF},
       'music': {'path': 'audio/music/boss-carrion_king.mp3', 'license': 'ACE-Step 1.5 local, uso comercial', 'in': 10.05, 'out': 73.55, 't': 1.0,
                 'fade_out': {'t0': 63.9, 't1': DUR}, 'beats': 'build/trailer/music/boss-carrion_king_beats.json'},
       'tv_on': {'t0': 0.0, 't1': 0.75, 'synth': False},
       'poster_frame_t': 3.4,
       'peak': {'t': 52.49, 'fraction': round(52.49 / DUR, 3), 'what': 'golpe de 42 no Rei-Carnica'},
       'hooks': {'boss_puzzle_hook': ['5 saloes no groove (10,75 a 17,33)', '4 saloes lentos + EVERY BOSS IS A PUZZLE + porta (26,14 a 41,76)', 'Rei-Carnica entra e luta, golpe de 42 (41,76 a 55,94)'],
                 'living_deck_hook': ['cartas do ladino + BUILD A LIVING DECK (5,78 a 10,75)', 'mao na luta do chefe (46,21 a 55,94)']},
       'valid_scenes': ['poweron', 'fork_a1', 'deck8', 'hall1_carrion', 'hall2_lich', 'hall3_tyrant', 'hall4_ice', 'hall5_heart', 'entr_storm_griffin', 'entr_fallen_angel', 'entr_ice_wyrm', 'fork_a2', 'boss8', 'logo_sting'],
       'clips': clips, 'texts': texts, 'sfx': S}
out = os.path.join(R, 'build', 'trailer', 'kinetic', 'C2_edl.json')
json.dump(edl, open(out, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print(out, len(clips), 'clips', len(texts), 'phrases', len(S), 'sfx')
