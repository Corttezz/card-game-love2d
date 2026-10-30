# make_edl.py: EDL of concept B (grimoire_kinetic_new) on the measured graves of boss-carrion_king.mp3.
# t = p - 17.86. Takes are the 1080p TGA sequences of card-game-trailer-v9; `map` = [[t, take frame], ...] piecewise linear.
import json, os
R = r'E:\dev\projects\card-game-trailer'
TAKES = os.path.join(os.environ['APPDATA'], 'LOVE', 'card-game-trailer-v9', 'trailer')
OFF, DUR = 17.86, 65.3
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
clips = [
    take('cartas_ladino', 'deck8', 0.0, 8.52, [[0.0, 560], [3.49, 830], [4.76, 868], [6.02, 946], [6.96, 989], [8.52, 1083]],
         note='TV liga sintetizada sobre o combate (0 a 1,0); JOGAR e 3 golpes nos graves, time-remap por trecho',
         events=[('JOGAR', 830, 3.49), ('golpe 1', 868, 4.76), ('golpe 2', 946, 6.02), ('golpe 3 (COMBO)', 989, 6.96), ('golpe 4', 1043, 7.86)]),
    take('recompensa', 'reward', 8.52, 11.05, [[8.52, 548], [9.78, 624], [11.05, 700]], tr={'type': 'glitch_soft', 'd': 0.12},
         note='Spoils of Battle; revelacao rara da 3a carta (clarão 624) no grave', events=[('revelacao rara', 624, 9.78)]),
]
acts = [(11.05, 12.29), (12.29, 13.55), (13.55, 14.81), (14.81, 16.07), (16.07, 17.33), (17.33, 20.40)]
for i, (a, b) in enumerate(acts, 1):
    clips.append(take(f'ato_{i}', f'night_a{i}', a, b, [[a, 110], [b, 110 + (b - a) * 60]], tr={'type': 'zoom', 'd': 0.1} if i > 1 else {'type': 'glitch_soft', 'd': 0.12},
                      note=f'viagem do ato {i}, castelo ao centro (sem o clarão dos primeiros quadros)'))
clips += [
    take('entrada_grifo', 'entr_storm_griffin', 20.40, 22.70, [[20.40, 540], [22.70, 678]], tr={'type': 'dissolve', 'd': 0.3},
         note='grifo ja no quadro, rasante e pouso (661)', events=[('pouso', 661, 22.42)]),
    take('entrada_anjo', 'entr_fallen_angel', 22.70, 25.00, [[22.70, 520], [25.00, 658]], tr={'type': 'glitch_soft', 'd': 0.12},
         note='anjo caido descendo e pousando (~620)', events=[('pouso', 620, 24.37)]),
    take('entrada_serpente', 'entr_ice_wyrm', 25.00, 27.10, [[25.00, 470], [27.10, 596]], tr={'type': 'glitch_soft', 'd': 0.12},
         note='serpente de gelo emergindo e soprando'),
    take('loja', 'shop', 27.10, 29.29, [[27.10, 40], [29.29, 171]], tr={'type': 'dissolve', 'd': 0.3},
         note='so a chegada ao mercador por fora (40 a 171): o balcao com a carta de caveira e os coringas de rosto entra em ~180 e fica fora'),
    take('porta_entrada_nome', 'boss8', 29.29, 38.66, [[29.29, 497], [32.59, 695], [32.89, 745], [37.40, 1015.6], [38.66, 1091]], tr={'type': 'dissolve', 'd': 0.3},
         note='porta vista de fora (portao 564), salao escuro, olhos, rasantes, pouso e cartao do nome no grave 37,40 (drop 55,07 em 37,21)',
         events=[('portao', 564, 30.41), ('escuro comprimido 695-745 em 0,3 s', 695, 32.59), ('olhos', 745, 32.89), ('cartao do nome', 1015, 37.40)]),
]
halls = [('hall2_lich', 1.33), ('hall3_tyrant', 1.0), ('hall4_ice', 1.33), ('hall5_heart', 4.0), ('hall1_carrion', 2.0)]
ht = [38.66, 39.91, 41.15, 42.43, 43.68, 46.18]
for i, (h, cin) in enumerate(halls):
    clips.append(mp4(f'salao_{h}', H + h + '.mp4', ht[i], ht[i + 1], cin, tr={'type': 'flash', 'd': 0.16} if i == 0 else {'type': 'zoom', 'd': 0.1},
                     note='salao 4K Higgsfield (IA, declarar), um por grave'))
clips.append(take('luta_guerreiro', 'boss8', 46.18, 54.99, [[46.18, 1160], [51.20, 1422], [52.15, 1448], [53.72, 1564], [54.99, 1640]],
                  note='luta sem corte (volta ao salao do Rei depois dos saloes, ja sem o cartao do nome, 0,87x ate o JOGAR); JOGAR no grave, golpe de 42 (o maior numero) no pico 52,15 = drop 70,01; termina antes do tooltip (1661)',
                  events=[('JOGAR', 1422, 51.20), ('golpe 1: 42, numero maior (pico)', 1448, 52.15), ('golpe 2: 33', 1519, 53.13), ('golpe 3: 27 + COMBO', 1564, 53.72)]))
clips.append({'id': 'glitch', 'kind': 'glitch', 't0': 54.99, 't1': 55.29, 'note': 'glitch do editor sobre o ultimo quadro da luta'})
clips.append(mp4('logo', H + 'logo_sting.mp4', 55.29, DUR, 0.0, speed=1.386, note='logo_sting 1080p (2x vizinho no 4K) a 1,386x: impacto da arte (2,62 s) no grave 57,18, termina em 59,98 e segura ate o fim'))
clips[-1]['out'] = 6.5
clips[-1]['hold_last_frame_until'] = DUR
clips[-1]['events'] = [{'what': 'impacto/flash do logo', 'clip_t': 2.62, 't': 57.18, 'anchor': anchor(57.18)}]

def phrase(name, words, out):
    ws = [{'text': w, 't': t, 'anchor': anchor(t, what)} | ({'line': ln} if ln else {}) for w, t, ln, what in words]
    chars = len(name)
    return {'phrase': name, 'words': ws, 'out': out, 'chars': chars, 'hold_after_last_word': round(out - ws[-1]['t'], 2),
            'hold_total': round(out - ws[0]['t'], 2), 'min_by_rule_13cps': round(chars / 13, 2)}
texts = [
    phrase('BUILD A LIVING DECK.', [('BUILD', 3.49, 0, None), ('A LIVING', 4.76, 0, None), ('DECK.', 6.02, 2, None)], 8.30),
    phrase('EVERY CARD IS ALIVE.', [('EVERY CARD', 8.52, 0, None), ('IS ALIVE.', 9.78, 2, None)], 10.95),
    phrase('SIX ACTS.', [('SIX', 11.05, 0, None), ('ACTS.', 12.29, 0, None)], 14.70),
    phrase('ONE ROAD TO THE CASTLE.', [('ONE ROAD', 17.33, 0, None), ('TO THE CASTLE.', 17.33, 2, None)], 20.30),
    phrase('YOUR CARDS DECIDE WHAT SURVIVES.', [('YOUR CARDS', 21.30, 0, 'rasante do grifo'), ('DECIDE', 22.42, 2, 'pouso do grifo'), ('WHAT SURVIVES.', 24.37, 3, 'pouso do anjo')], 26.90),
    phrase('BEND EVERY HAND.', [('BEND', 27.10, 0, 'corte para a loja'), ('EVERY HAND.', 27.80, 2, 'loja')], 29.15),
    phrase('EVERY BOSS IS A PUZZLE.', [('EVERY BOSS', 38.66, 0, None), ('IS A PUZZLE.', 39.91, 2, None)], 42.30),
    phrase('WISHLIST ON STEAM.', [('WISHLIST ON STEAM.', 60.01, 0, None)], DUR),
]
manifest = json.load(open(os.path.join(R, 'build', 'trailer', 'sfx_synth', 'manifest.json')))['files']
def sfx(f, t, g, what):
    hit = manifest[f]['hit']
    return {'file': 'build/trailer/sfx_synth/' + f, 'attack_offset': hit, 'event_t': t, 'start_t': round(t - hit, 3), 'gain_db': g, 'what': what, 'anchor': anchor(t)}
S = [sfx('tv_on.wav', 0.0, -8, 'TV liga'),
     sfx('impact_1.wav', 4.76, -8, 'golpe 1 das cartas'), sfx('impact_2.wav', 6.02, -9, 'golpe 2 das cartas'), sfx('impact_1.wav', 6.96, -8, 'golpe 3 das cartas'),
     sfx('impact_2.wav', 7.86, -12, 'golpe 4 das cartas'),
     sfx('whoosh_2.wav', 8.52, -3, 'corte recompensa'), sfx('impact_1.wav', 9.78, -10, 'revelacao rara')]
S += [sfx('whoosh_2.wav', a, -3 if i == 0 else -6, f'ato {i + 1}') for i, (a, b) in enumerate(acts)]
S += [sfx('whoosh_1.wav', 20.40, -6, 'entrada do grifo'), sfx('impact_2.wav', 22.42, -9, 'pouso do grifo'),
      sfx('whoosh_1.wav', 22.70, -6, 'entrada do anjo'), sfx('impact_2.wav', 24.37, -9, 'pouso do anjo'),
      sfx('whoosh_1.wav', 25.00, -4, 'serpente emerge'), sfx('whoosh_1.wav', 27.10, -6, 'loja'),
      sfx('castle_door.wav', 30.41, -4, 'rangido na loja, baque no portao (boss8 564)'),
      sfx('impact_heavy.wav', 37.40, -6, 'cartao do nome')]
S += [sfx('whoosh_2.wav', t, -3, 'salao') for t in ht[:5]] + [sfx('whoosh_2.wav', 46.18, -6, 'volta a luta')]
S += [sfx('impact_heavy.wav', 52.15, -4, 'golpe 42, pico'), sfx('impact_2.wav', 53.13, -9, 'golpe 33'), sfx('impact_1.wav', 53.72, -7, 'golpe 27 + COMBO'),
      sfx('glitch.wav', 54.99, -9, 'glitch'), sfx('impact_1.wav', 57.18, -6, 'flash do logo'), sfx('logo_seal.wav', 60.01, -2, 'selo + WISHLIST'),
      sfx('impact_1.wav', 62.21, -14, 'brilho final')]
edl = {'id': 'grimoire_kinetic_new', 'concept': 'B: principal 65 s, tomadas regravadas (card-game-trailer-v9) nos graves do Rei-Carnica',
       'root': 'E:/dev/projects/card-game-trailer', 'takes': TAKES.replace('\\', '/'),
       'output': {'size': [3840, 2160], 'fps': 60, 'duration': DUR, 'loudness_lufs': -14},
       'time_map': {'rule': 't = p - 17.86', 'offset': OFF},
       'music': {'path': 'audio/music/boss-carrion_king.mp3', 'license': 'ACE-Step 1.5 local, uso comercial', 'in': 18.86, 'out': 18.86 + DUR - 1.0, 't': 1.0,
                 'fade_out': {'t0': 64.66, 't1': DUR}, 'beats': 'build/trailer/music/boss-carrion_king_beats.json'},
       'tv_on': {'t0': 0.0, 't1': 1.0},
       'poster_frame_t': 6.6,
       'peak': {'t': 52.15, 'fraction': round(52.15 / DUR, 3), 'what': 'golpe de 42 no Rei-Carnica'},
       'hooks': {'boss_puzzle_hook': ['porta, salao escuro e entrada do Rei-Carnica (29,29 a 38,66)', '5 saloes + EVERY BOSS IS A PUZZLE (38,66 a 46,18)', 'luta e golpe de 42 (46,18 a 54,99)'],
                 'living_deck_hook': ['cartas do ladino + BUILD A LIVING DECK (0 a 8,52)', 'carta rara viva + EVERY CARD IS ALIVE (8,52 a 11,05)', 'loja + BEND EVERY HAND (27,10 a 29,29)']},
       'valid_scenes': ['deck8', 'reward', 'night_a1', 'night_a2', 'night_a3', 'night_a4', 'night_a5', 'night_a6', 'entr_storm_griffin', 'entr_fallen_angel', 'entr_ice_wyrm',
                        'shop', 'boss8', 'hall1_carrion', 'hall2_lich', 'hall3_tyrant', 'hall4_ice', 'hall5_heart', 'logo_sting'],
       'clips': clips, 'texts': texts, 'sfx': S}
out = os.path.join(R, 'build', 'trailer', 'kinetic', 'B_edl.json')
json.dump(edl, open(out, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print(out, len(clips), 'clips', len(texts), 'phrases', len(S), 'sfx')
