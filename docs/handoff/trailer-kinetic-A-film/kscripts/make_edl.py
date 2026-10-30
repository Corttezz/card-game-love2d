# make_edl.py: EDL of concept A (grimoire_kinetic_hook30, the 30 s hook) on the measured graves of boss-abyss_tyrant.mp3,
# first drop. t = p - 11.93. Takes are the 1080p TGA sequences of card-game-trailer-v9; `map` = [[t, take frame], ...].
import json, os
R = r'E:\dev\projects\card-game-trailer'
TAKES = os.path.join(os.environ['APPDATA'], 'LOVE', 'card-game-trailer-v9', 'trailer')
OFF, DUR = 11.93, 32.3
hits = sorted(h['t'] for h in json.load(open(os.path.join(R, 'build', 'trailer', 'music', 'boss-abyss_tyrant_beats.json')))['hits'])
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
    take('cartas_ladino', 'deck8', 0.0, 7.18, [[0.0, 780], [1.45, 830], [3.48, 946], [4.28, 989], [4.87, 1043], [7.18, 1138]],
         note='TV liga sintetizada com a mao do ladino no vidro (0 a 1,0); musica entra seca no JOGAR (1,45); golpes 2 a 4 nos graves 3,48/4,28/4,87 (0,9x a 1,5x); termina em 1138, antes do tooltip Shadow Dance (1140)',
         events=[('JOGAR', 830, 1.45), ('golpe 1', 868, 2.11), ('golpe 2 + numero', 946, 3.48), ('golpe 3 (COMBO)', 989, 4.28), ('golpe 4', 1043, 4.87)]),
    take('encruzilhada_a2', 'fork_a2', 7.18, 8.82, [[7.18, 100], [8.82, 198]], tr={'type': 'glitch_soft', 'd': 0.12}, note='encruzilhada do ato 2, castelo ao centro'),
    take('encruzilhada_a4', 'fork_a4', 8.82, 10.51, [[8.82, 100], [10.51, 201]], tr={'type': 'zoom', 'd': 0.1}, note='encruzilhada do ato 4'),
    take('entrada_grifo', 'entr_storm_griffin', 10.51, 13.55, [[10.51, 560], [13.55, 742]], tr={'type': 'glitch_soft', 'd': 0.12},
         note='grifo ja no quadro desde o 1o quadro do plano, pouso 661', events=[('pouso', 661, 12.19)]),
    take('entrada_serpente', 'entr_ice_wyrm', 13.55, 15.01, [[13.55, 470], [15.01, 558]], tr={'type': 'glitch_soft', 'd': 0.12}, note='serpente de gelo emergindo'),
    take('porta', 'boss8', 15.01, 17.76, [[15.01, 399], [17.76, 564]], tr={'type': 'dissolve', 'd': 0.3}, note='porta vista de fora; o portao abre no grave 17,76 (baque)',
         events=[('portao', 564, 17.76)]),
    take('olhos', 'boss8', 17.76, 18.00, [[17.76, 745], [18.00, 759]], note='corte seco para os olhos no escuro no baque'),
    take('pouso_nome', 'boss8', 18.00, 18.82, [[18.00, 990], [18.82, 1039]], tr={'type': 'flash', 'd': 0.16},
         note='drop p 29,93: Rei-Carnica pousa inteiro e o cartao do nome sobe', events=[('pouso', 1000, 18.17)]),
]
halls = [('hall1_carrion', 2.0, 18.82, 19.73), ('hall2_lich', 1.33, 19.73, 20.31), ('hall3_tyrant', 1.0, 20.31, 22.31)]
for i, (h, cin, a, b) in enumerate(halls):
    clips.append(mp4(f'salao_{h}', H + h + '.mp4', a, b, cin, tr={'type': 'zoom', 'd': 0.1}, note='salao 4K Higgsfield (IA, declarar), um por grave'))
clips.append(take('luta_guerreiro', 'boss8', 22.31, 26.89, [[22.31, 1310], [24.61, 1448], [26.89, 1585]],
                  note='luta do guerreiro: JOGAR 1422 em 24,18, golpe de 42 (o maior numero) no grave 24,61 = pico; 33 e 27+COMBO depois; para em 1585, antes do tooltip (1661)',
                  events=[('JOGAR', 1422, 24.18), ('golpe 1: 42, numero maior (pico)', 1448, 24.61), ('golpe 2: 33', 1519, 25.79), ('golpe 3: 27 + COMBO', 1564, 26.54)]))
clips.append({'id': 'glitch', 'kind': 'glitch', 't0': 26.89, 't1': 27.16, 'note': 'glitch do editor sobre o ultimo quadro da luta, do grave 26,89 ao 27,16'})
clips.append(mp4('logo', H + 'logo_sting.mp4', 27.16, DUR, 1.0, speed=1.373, note='logo_sting a partir de 1,0 s a 1,373x: impacto da arte no grave 28,34 (1o pulso do selo)'))
clips[-1]['out'] = 6.5
clips[-1]['hold_last_frame_until'] = DUR
clips[-1]['events'] = [{'what': 'impacto/flash do logo', 'clip_t': 2.62, 't': 28.34, 'anchor': anchor(28.34)}]

def phrase(name, words, out):
    ws = [{'text': w, 't': t, 'anchor': anchor(t, what)} | ({'line': ln} if ln else {}) for w, t, ln, what in words]
    return {'phrase': name, 'words': ws, 'out': out, 'chars': len(name), 'hold_after_last_word': round(out - ws[-1]['t'], 2),
            'hold_total': round(out - ws[0]['t'], 2), 'min_by_rule_13cps': round(len(name) / 13, 2)}
texts = [
    phrase('PLAY.', [('PLAY.', 1.45, 0, None)], 3.30),
    phrase('BREAK.', [('BREAK.', 3.48, 0, None)], 6.95),
    phrase('SIX ACTS. ONE ROAD TO THE CASTLE.', [('SIX ACTS.', 7.18, 0, None), ('ONE ROAD', 8.82, 2, None), ('TO THE CASTLE.', 8.82, 3, None)], 10.40),
    phrase('YOUR CARDS DECIDE WHAT SURVIVES.', [('YOUR CARDS', 10.51, 0, None), ('DECIDE', 10.81, 2, None), ('WHAT SURVIVES.', 11.19, 3, None)], 13.40),
    phrase('EVERY BOSS IS A PUZZLE.', [('EVERY BOSS', 18.82, 0, None), ('IS A PUZZLE.', 19.73, 2, None)], 22.20),
    phrase('WISHLIST ON STEAM.', [('WISHLIST ON STEAM.', 29.17, 0, None)], DUR),
]
manifest = json.load(open(os.path.join(R, 'build', 'trailer', 'sfx_synth', 'manifest.json')))['files']
def sfx(f, t, g, what):
    hit = manifest[f]['hit']
    return {'file': 'build/trailer/sfx_synth/' + f, 'attack_offset': hit, 'event_t': t, 'start_t': round(t - hit, 3), 'gain_db': g, 'what': what, 'anchor': anchor(t)}
S = [sfx('tv_on.wav', 0.0, -8, 'TV liga'),
     sfx('impact_2.wav', 2.11, -12, 'golpe 1 das cartas'), sfx('impact_1.wav', 3.48, -6, 'golpe 2 + BREAK.'), sfx('impact_2.wav', 4.28, -9, 'golpe 3'), sfx('impact_1.wav', 4.87, -9, 'golpe 4'),
     sfx('whoosh_2.wav', 7.18, -3, 'encruzilhada a2'), sfx('whoosh_2.wav', 8.82, -3, 'encruzilhada a4'),
     sfx('whoosh_1.wav', 10.51, -4, 'entrada do grifo'), sfx('impact_2.wav', 12.19, -10, 'pouso do grifo'), sfx('whoosh_1.wav', 13.55, -4, 'serpente'),
     sfx('castle_door.wav', 17.76, -4, 'rangido sobre a porta, baque no portao (grave 17,76)'),
     sfx('impact_heavy.wav', 18.00, -6, 'drop: pouso do Rei-Carnica'),
     sfx('whoosh_2.wav', 18.82, -3, 'salao 1'), sfx('whoosh_2.wav', 19.73, -3, 'salao 2'), sfx('whoosh_2.wav', 20.31, -3, 'salao 3'),
     sfx('whoosh_2.wav', 22.31, -6, 'corte para a luta'),
     sfx('impact_heavy.wav', 24.61, -4, 'golpe 42, pico'), sfx('impact_2.wav', 25.79, -9, 'golpe 33'), sfx('impact_1.wav', 26.54, -8, 'golpe 27 + COMBO'),
     sfx('glitch.wav', 26.89, -9, 'glitch'), sfx('impact_1.wav', 28.34, -6, 'flash do logo'), sfx('logo_seal.wav', 29.17, -2, 'selo + WISHLIST')]
edl = {'id': 'grimoire_kinetic_hook30', 'concept': 'A: gancho de 30 s (redes / 2o video), tomadas regravadas nos graves do Tirano (1o drop)',
       'root': 'E:/dev/projects/card-game-trailer', 'takes': TAKES.replace('\\', '/'),
       'output': {'size': [3840, 2160], 'fps': 60, 'duration': DUR, 'loudness_lufs': -14},
       'time_map': {'rule': 't = p - 11.93', 'offset': OFF},
       'music': {'path': 'audio/music/boss-abyss_tyrant.mp3', 'license': 'ACE-Step 1.5 local, uso comercial', 'in': 13.38, 'out': 13.38 + DUR - 1.45, 't': 1.45,
                 'fade_out': {'t0': 31.78, 't1': DUR}, 'beats': 'build/trailer/music/boss-abyss_tyrant_beats.json'},
       'tv_on': {'t0': 0.0, 't1': 1.0},
       'poster_frame_t': 3.9,
       'peak': {'t': 24.61, 'fraction': round(24.61 / DUR, 3), 'what': 'golpe de 42 no Rei-Carnica'},
       'hooks': {'boss_puzzle_hook': ['porta, olhos e pouso do Rei-Carnica (15,01 a 18,82)', '3 saloes + EVERY BOSS IS A PUZZLE (18,82 a 22,31)', 'luta e golpe de 42 (22,31 a 26,89)'],
                 'cards_hook': ['PLAY. no JOGAR', 'BREAK. no golpe com numero']},
       'valid_scenes': ['deck8', 'fork_a2', 'fork_a4', 'entr_storm_griffin', 'entr_ice_wyrm', 'boss8', 'hall1_carrion', 'hall2_lich', 'hall3_tyrant', 'logo_sting'],
       'clips': clips, 'texts': texts, 'sfx': S}
out = os.path.join(R, 'build', 'trailer', 'kinetic', 'A_edl.json')
json.dump(edl, open(out, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print(out, len(clips), 'clips', len(texts), 'phrases', len(S), 'sfx')
