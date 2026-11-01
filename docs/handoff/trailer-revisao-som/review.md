# Revisão de som dos trailers B, A e C

_Revisor, 01/11/2026. Só análise: nada foi remixado. Tempos em segundos do filme, com duas casas._

## Método

- **Imagem:** 4 quadros por segundo de cada `*_1080p.mp4`, em folhas de contato com o tempo carimbado (`scratchpad/revisor/revisor_{B,A,C}_sheet_NN.jpg`), todas olhadas.
- **Som:** forma de onda (`revisor_*_wave.png`), espectrograma (`revisor_*_spec.png`) e RMS em janelas de 100 ms. A mixagem foi separada em dois stems, refazendo a conta do `mixdown.py`: stem de música e stem de SFX sintético (`revisor_*_loudness.png`: branco é a mixagem final, azul a música, vermelho os SFX e laranja os graves da faixa).
- **Sons do jogo:** os eventos do `audio.jsonl` foram levados ao tempo do filme pelo `map` de cada clipe, contando só os quadros dentro do trecho usado (`revisor_events_{B,A,C}.json`; script `revisor_map.py`). Quando o som do jogo caiu fora do trecho usado (por exemplo, os olhos do Rei no f730 em A e C), o relatório diz.
- **TRIM:** vale 0,0 nos três `mixdown.py`, então o tempo da EDL é o tempo do filme. Os graves vêm de `music/*_beats.json` com `t_filme = t_faixa - time_map.offset`.
- **Medição final** (mp4 = mix.wav): B −14,3 LUFS, LRA 6,8 LU, pico −0,8 dBTP; A −13,9 LUFS, LRA 4,0 LU; C −14,4 LUFS, LRA 6,6 LU.

## O diagnóstico em uma linha

**Nenhum dos três trailers tem um único som do jogo.** O `mixdown.py` só aceita `boss-*.mp3` e `build/trailer/sfx_synth/` (`ALLOWED`), e todos os SFX são sintéticos: `tv_on`, `impact_1/2`, `impact_heavy`, `whoosh_1/2`, `castle_door`, `glitch` e `logo_seal`. Nos trechos usados, o jogo tocou 273 eventos em B, 145 em A e 204 em C, e nenhum entrou. A música também nunca sai: o stem dela aparece em todas as janelas, da entrada até o fim. Nos momentos que o Daniel citou, o stem de SFX está vazio ou fica 5 a 6 dB abaixo do leito grave da faixa.

Problemas comuns aos três:
1. **Sem som do jogo** (acima).
2. **Sem ducking e sem silêncio.** As notas de B (LRA 6,8), C (6,6) e A (4,0) mostram um filme que roda o tempo todo na mesma altura.
3. **A porta está mascarada.** O `castle_door.wav` fica entre −28 e −29 dB RMS contra a música entre −23 e −23,5 dB, num leito contínuo de 20 a 120 Hz (dá para ver no espectrograma de B, de 17,6 a 37,2).
4. **A entrada do chefe está muda.** De 32,6 a 37,3 em B e de 41,8 a 46,1 em C (olhos, piscadas, três rasantes e pouso), o stem de SFX fica entre −117 e −72 dB.
5. **O loudnorm agiu de forma dinâmica.** O quarto mais baixo do filme subiu ~2 dB em relação ao quarto mais alto, comparado com o premix. Isso vai desfazer parte de qualquer ducking. Proposta: ganho linear fixo + limitador de pico, e medir o LUFS no fim.
6. **A bússola do logo não tem som** (2,2 s em B e C, 1,2 s em A) e o jogo não tem som para ela. Proposta: `boot-card-whoosh.mp3` ou um giro metálico sintetizado.

Os caminhos de arquivo abaixo são relativos a `E:\dev\projects\card-game-trailer\`. Nos JSON a lista vai completa, com cada arquivo de ambiente por extenso.

---

## B, principal de 65,3 s (`grimoire_kinetic_new_1080p.mp4`)

Faixa: `boss-carrion_king.mp3`, de 18,86 a 83,16, entrando em 1,00 (offset 17,86). Graves fortes em 1,00, 3,49, 4,76, 6,02, 6,96, 8,52, 9,78 e de 1,26 em 1,26 s até 17,33. **Não há nenhum grave de 17,33 a 37,40** (o pad grave cobre as entradas, a loja, a porta e o escuro). Depois vêm os drops em 37,21 (0,56) e 52,15 (0,72), e graves em 37,40, 38,66 … 46,18, 51,20, 52,15, 57,18 e 60,01.

### O que se vê
| tempo | imagem |
|---|---|
| 0,00 a 0,62 | TV liga (linha, depois imagem) na luta do ladino contra o Bruto |
| 0,74 a 3,12 | hover e seleção de 4 cartas, cursor no JOGAR |
| 3,49 a 8,11 | JOGAR, 4 golpes (BUILD / A LIVING / DECK.) |
| 8,52 a 11,05 | Spoils of Battle: brilho cresce em 9,1, clarão da rara em 9,76 (EVERY CARD IS ALIVE.) |
| 11,05 a 20,40 | 6 atos de 1,26 s (SIX ACTS / ONE ROAD TO THE CASTLE.): noite, chuva, brasas vermelhas, neve, pântano verde e crepúsculo |
| 20,40 a 27,10 | grifo na chuva, anjo caído e serpente de gelo soprando (26,4) |
| 27,10 a 29,29 | chegada ao mercador (BEND EVERY HAND.) |
| 29,29 a 32,59 | castelo de fora, à noite; o portão abre em 30,41 |
| 32,59 a 35,1 | salão escuro; os olhos acendem em 32,8 |
| 35,24 a 36,1 | rasantes com rastro |
| 36,79 a 36,9 | pouso com clarão roxo |
| 37,40 | cartão CARRION KING |
| 38,66 a 46,18 | salões IA: Lich, Tirano (lava), gelo, coração e Carniça (corvos cruzando de 43,9 a 45,4) |
| 46,18 a 54,99 | luta: mão dada, seleção, JOGAR 51,20, 42 em 52,15, 33 em 53,11, 27 com COMBO 53,72 |
| 54,99 a 55,29 | glitch |
| 55,3 a 57,1 | bússola surge e gira |
| 57,18 | flash |
| 57,6 | letras GRIMOIRE |
| 60,01 | WISHLIST |

### SFX do jogo em primeiro plano
| t | momento | arquivo do jogo | prio |
|---|---|---|---|
| 0,00 | TV liga | `audio/sfx/boot-tv-power-on.mp3` (no lugar de `tv_on.wav`) | alta |
| 1,05 a 2,68 | seleção ×4, hover entre elas | `audio/clickselect2-92097.mp3`, `audio/hoverCard.wav` | média |
| 3,49 | JOGAR | `button-click.mp3` + `combo-trigger.mp3` | alta |
| 3,56 a 4,06 | 4 cartas voam | `card-play-attack.mp3` | média |
| 4,76 / 6,02 | golpes 1 e 2 | `audio/sword-sound-260274.mp3` + `enemies/pit_brute/hurt_3` / `hurt_1` (+ `card-exhaust` no 1º) | alta |
| 6,96 / 7,86 | golpes 3 e 4 (veneno) | `impact-poison.mp3` + `pit_brute/hurt_*`; `debuff-applied` em 7,21 e 8,11 | média |
| 9,02 | brilho carregando | `shop-crystal-hum.mp3` | média |
| 9,76 | revelação rara | `pack-seal-break.mp3` + `card-discovered.mp3` | alta |
| 10,31 | rara assenta | `joker-sig/rogue_envenom.mp3` | média |
| 16,92 | trovão do ato 5 | `weather/thunder-mid.mp3` | média |
| 20,40 | entrada do grifo | `stingers/miniboss_entrance.mp3` (jogo em f427, antes do trecho) | alta |
| 21,72 | grifo para no ar | `entrances/storm_griffin_stop.mp3` | alta |
| 22,70 / 24,85 | anjo desce / para | `entrances/fallen_angel_start.mp3` / `fallen_angel_stop.mp3` (a EDL marca pouso em 24,37; conferir) | média/alta |
| 25,00 | serpente emerge | `entrances/ice_wyrm_rise.mp3`, entrando 0,38 s dentro do arquivo | alta |
| 26,38 | sopro de gelo | `boss/boss_frost_storm.mp3` (não tocou na tomada) | média |
| 27,10 a 27,42 | moedas no mercador | `coin-clink.mp3` ×9 | média |
| **30,41** | **portão abre** | `castle-gate-open.mp3` | **alta** |
| **32,80** | **olhos acendem** | `boss/boss_eyes_ignite.mp3` + `boss_eyes_rumble.mp3` | **alta** |
| 33,62 / 34,39 | piscadas | `boss/boss_blink_click.mp3` | média |
| **35,24 / 35,69 / 36,07** | **rasantes** | `boss/boss_wing_pass.mp3` (+ `crow/cine_3.mp3` no 1º) | **alta** |
| **36,79** | **pouso** | `boss/boss_land_impact.mp3`, `crow/flock_1` em 36,94, `boss_feathers_settle` em 37,24 | **alta** |
| 37,39 | cartão do nome | `boss/boss_reveal_sting.mp3` (+ `impact_heavy` existente) | alta |
| 38,66 a 43,90 | salões IA (um por grave) | Lich `boss_rune_ignite`, Tirano `boss_hellfire_wall`, gelo `boss_frost_storm`, coração `boss_heartbeat`, Carniça `crow/appear_1` + `flock_2` (44,6) | média |
| 46,28 a 46,66 | mão dada | `card-draw.mp3` ×4 | média |
| 48,35 a 49,99 | seleção ×3 | `clickselect2`, `hoverCard` | média |
| 51,20 | JOGAR | `button-click` + `combo-trigger` | alta |
| 51,27 a 51,64 | cartas voam | `card-play-attack` ×3 | alta |
| **52,15** | **42** | `impact-fire.mp3` + `enemies/carrion_king/hurt_2.mp3` + `card-exhaust` (somar ao `impact_heavy`) | **alta** |
| 53,11 / 53,72 | 33 / 27 | `sword-sound` + `carrion_king/hurt_1` / `hurt_2`; `combo-trigger` em 53,38 (faixa COMBO!), `joker_001` em 52,30, 53,26 e 53,90 | alta |
| 55,60 | bússola gira | sem som no jogo: `boot-card-whoosh.mp3` ou sintetizar | média |
| 57,18 | flash do logo | `impact_1` existente + `forge-reveal.mp3` | média |
| 57,60 | letras | `pack-card-reveal.mp3` | baixa |

### Ambiente (o que o jogo tocou em cada plano)
| trecho | ambiente |
|---|---|
| 0,00 a 8,52 | brasas e vento (`weather/ember-crackle-1`, `wind-2`, `ember-pop-1`) |
| 11,05 a 20,40 | um leito por ato: noite (grilos, vento, vagalume), chuva, brasas, nevasca, pântano com chuva e trovão, vento com grilos |
| 20,40 a 27,10 | chuva forte (grifo), vento com grilos (anjo), nevasca (serpente) |
| 27,10 a 29,29 | brasas e vento |
| 29,29 a 32,59 | noite fora do castelo: grilos, vento, `cricket-chirp-1` em 32,42 |
| 32,59 a 38,66 | `place/boss-room-1.mp3`, + `boss/boss_hold_ambience.mp3` no escuro |
| 38,66 a 46,18 | salões IA: `boss_hold_ambience` (Lich), `ember-crackle` (Tirano), `blizzard-2` (gelo), `boss_roots_crawl` (coração), `boss-room-1` (Carniça) |
| 46,18 a 54,99 | `place/boss-room-1.mp3` |

### Música: onde sai e onde volta
| início | fim | ação | dB | por quê | volta |
|---|---|---|---|---|---|
| 1,00 | 3,49 | duck | −6 | seleção da mão legível | 3,49 (grave BUILD) |
| 20,40 | 29,29 | duck | −6 | stinger e paradas dos mini-chefes, chuva e neve | — |
| 29,29 | 32,59 | duck (rampa de 1 s) | −14 | noite lá fora e o portão em 30,41 | — |
| **32,59** | **37,40** | **silêncio** | — | olhos, piscadas, rasantes, pouso e corvos só com o jogo | **37,40** (grave 1,0, logo depois do drop 37,21, no cartão do nome) |
| 46,18 | 51,25 | duck | −6 | mão dada e escolha sobre o salão | — |
| **51,25** | **52,15** | **corte** | — | respiro depois do JOGAR: só as cartas voando | **52,15** (drop 0,72, golpe de 42) |
| **54,99** | **57,18** | **silêncio** | — | glitch e bússola | **57,18** (grave 1,0, flash) |

### Problemas na mixagem atual
- **Porta:** `castle_door.wav` −28 dB contra a música −23,5 dB (27,7 a 32,5). O rangido começa em 27,66, ainda na loja.
- **Entrada do Rei:** de 32,6 a 37,3 o stem de SFX está vazio. O jogo tocou 12 sons ali.
- `whoosh_2.wav` repete a mesma amostra 11 vezes (6 atos e 5 salões) e soa mecânico.
- **O 42 (52,15)** cai no drop sem silêncio antes: o stem de música está em −10 dB e o de SFX em −8,6 dB, então o golpe disputa com a faixa.
- **O fim** tem fade de só 0,64 s (64,66 a 65,30) e soa como corte. Alongar de 63,76 a 65,30 ou terminar no grave de 65,03.
- Em 22,14 o whoosh do anjo começa antes do pouso do grifo (22,42).

---

## A, gancho de 32,3 s (`grimoire_kinetic_hook30_1080p.mp4`)

Faixa: `boss-abyss_tyrant.mp3`, de 13,38 a 44,23, entrando em 1,45 (offset 11,93). Drop em 18,00 (0,94). Graves em 1,45, 7,18, 8,82 … 13,55, 17,76, 18,00, 18,17, 18,82, 19,73, 20,31, 22,31, 24,61, 27,16 e 28,34. **Não há nenhum grave de 13,55 a 17,76** (é a porta).

### O que se vê
| tempo | imagem |
|---|---|
| 0 a 1,0 | TV liga |
| 0,6 a 1,45 | cursor indo ao JOGAR |
| 1,45 | PLAY. |
| 2,12 a 5,2 | golpes (BREAK. em 3,48) |
| 7,18 / 8,82 | encruzilhadas a2 (chuva) e a4 (neve) |
| 10,51 a 13,55 | grifo |
| 13,55 a 15,01 | serpente; sopro em 14,9 |
| 15,01 a 17,76 | castelo de fora |
| 17,76 | corte seco para os olhos |
| 18,00 | pouso com clarão branco |
| 18,4 a 18,8 | cartão do nome |
| 18,82 a 22,31 | salões IA: Carniça (corvos), Lich e Tirano |
| 22,31 a 26,89 | luta: JOGAR 24,18, 42 em 24,61, 33 em 25,79, COMBO em 26,12, 27 em 26,54 |
| 27,2 a 28,3 | bússola |
| 28,34 | clarão branco |
| 28,9 | GRIMOIRE |
| 29,17 | WISHLIST |

### SFX do jogo em primeiro plano
| t | momento | arquivo do jogo | prio |
|---|---|---|---|
| 0,00 | TV liga | `boot-tv-power-on.mp3` | alta |
| 0,61 / 0,67 | cursor no JOGAR | `menu-hover.mp3` | baixa |
| 1,45 | JOGAR (PLAY.) | `button-click` + `combo-trigger` | alta |
| 2,12 / 3,48 | golpes 1 e 2 (BREAK.) | `sword-sound` + `pit_brute/hurt_3` / `hurt_1` | alta |
| 4,28 / 4,87 | golpes de veneno | `impact-poison` + `pit_brute/hurt_*` | média |
| 7,40 / 9,10 | encruzilhadas | `fork-hover-door` / `fork-hover-flag` | baixa |
| 10,51 | grifo | `stingers/miniboss_entrance.mp3` | alta |
| 11,50 | grifo para | `entrances/storm_griffin_stop.mp3` | alta |
| 13,55 | serpente | `entrances/ice_wyrm_rise.mp3` (entrar em 0,38 s do arquivo) | alta |
| 14,88 | sopro | `boss/boss_frost_storm.mp3` | média |
| **17,26** | **portão** | `castle-gate-open.mp3`: o jogo o toca em 17,76, no próprio quadro do corte; adiantar 0,5 s para ser ouvido na porta | **alta** |
| **17,76** | **olhos** | `boss_eyes_ignite` + `boss_eyes_rumble` (o jogo tocou em f730, fora do trecho) | **alta** |
| **18,00** | **pouso (drop)** | `boss_land_impact` + `crow/flock_1` (jogo em f979, fora do trecho) | **alta** |
| 18,42 | cartão do nome | `boss_reveal_sting.mp3` (no log) | alta |
| 18,82 / 19,73 / 20,31 | salões IA | `crow/appear_2` / `boss_rune_ignite` / `boss_hellfire_wall` | média |
| 22,41 a 23,13 | seleção | `clickselect2`, `hoverCard` | média |
| 24,18 | JOGAR | `button-click` + `combo-trigger`; `card-play-attack` de 24,21 a 24,38 | alta |
| **24,61** | **42** | `impact-fire` + `carrion_king/hurt_2` + `card-exhaust`; `joker_001` em 24,79 | **alta** |
| 25,79 / 26,54 | 33 / 27 | `sword-sound` + `carrion_king/hurt_1` / `hurt_2`; `combo-trigger` em 26,12 | alta |
| 27,38 | bússola | sem som no jogo: `boot-card-whoosh` ou sintetizar | média |
| 28,34 | clarão | `impact_1` existente + `forge-reveal.mp3` | média |

### Ambiente
Brasas e vento (0 a 7,18); chuva (7,18 a 8,82); nevasca (8,82 a 10,51); chuva forte (10,51 a 13,55); nevasca (13,55 a 15,01); noite com grilos e vento (15,01 a 17,76); `place/boss-room-1` (17,76 a 18,82 e 22,31 a 26,89); salões IA com `ember-crackle` e `boss_hold_ambience` (18,82 a 22,31).

### Música
| início | fim | ação | dB | por quê | volta |
|---|---|---|---|---|---|
| 0,00 | 1,45 | (já sem música) | — | manter, mas preencher com a TV, brasas e o hover | 1,45 (já está certo) |
| 10,51 | 15,01 | duck | −5 | mini-chefes e clima | — |
| 15,01 | 16,76 | duck | −12 | porta: noite e rangido | — |
| **16,76** | **18,00** | **silêncio** | — | fim da porta, portão e olhos só com o jogo | **18,00** (drop 0,94, pouso) |
| 22,31 | 24,25 | duck | −6 | seleção legível | — |
| **24,25** | **24,61** | **corte** | — | respiro de 0,36 s | **24,61** (grave, 42) |
| **26,89** | **28,34** | **silêncio** | — | glitch e bússola | **28,34** (grave, clarão) |

### Problemas
- **Buraco no início:** de 0 a 1,45 só toca o `tv_on.wav`, com a mixagem em ~−33 dB, enquanto a mão e o cursor já estão na tela.
- **Porta:** `castle_door.wav` −29 dB contra a música −23 dB (15,0 a 17,7).
- **Olhos e pouso (17,76 e 18,00):** só o `impact_heavy`. O drop chega sem preparo.
- **LRA 4,0 LU:** o mais achatado dos três.

---

## C, segundo corte de 64,5 s (`grimoire_trailer_v9_kinetic_1080p.mp4`)

Faixa: `boss-carrion_king.mp3`, de 10,05 a 73,55, entrando em 1,00 (offset 9,05). Drops em 46,02 (0,56) e 60,96 (0,72). Graves de 1,00 até 26,14. **Não há nenhum grave de 26,14 a 46,21** (20 s de pad: salões lentos, porta e entrada do Rei). Depois vêm 46,21, 47,47 … 52,49, 53,73, 55,94, 57,50, 58,74 e 60,01.

### O que se vê
| tempo | imagem |
|---|---|
| 0 a 0,88 | TV liga (clipe do v8) |
| 0,88 a 5,78 | estrada e encruzilhada do ato 1 (SIX ACTS.) |
| 5,78 a 10,75 | luta do ladino: JOGAR 6,67, golpes em 7,30, 8,55, 9,11 e 9,81, COMBO em 8,9 |
| 10,75 a 17,33 | 5 salões IA no groove; o coração explode em raízes em 17,1 |
| 17,33 a 22,36 | grifo, anjo e serpente (YOUR CARDS DECIDE WHAT SURVIVES.) |
| 22,36 a 26,14 | estrada à noite com chuva |
| 26,14 a 39,01 | 4 salões lentos: Lich com runas acendendo (26,6 a 30), Tirano com coluna de fogo (32,9 a 34,1), gelo com flocos (34,6 a 38) e Carniça (38,1 a 39,4) (EVERY BOSS IS A PUZZLE.) |
| 39,01 a 41,76 | castelo de fora |
| 41,88 a 44,1 | olhos |
| 44,1 a 45,1 | rasantes |
| 45,62 | pouso |
| 46,21 | cartão do nome |
| 48,3 a 55,9 | luta: JOGAR 52,11, 42 em 52,49, COMBO em 53,88, 33 em 53,67, 27 em 54,42 |
| 55,94 | glitch |
| 56,4 a 58,7 | bússola |
| 58,74 a 58,9 | clarão |
| 59,4 | GRIMOIRE |
| 60,01 | WISHLIST |

### SFX do jogo em primeiro plano
| t | momento | arquivo do jogo | prio |
|---|---|---|---|
| 0,00 | TV liga | `boot-tv-power-on.mp3` | alta |
| 3,79 / 5,38 | encruzilhada | `fork-hover-flag` / `fork-hover-tent` | média/baixa |
| 6,67 | JOGAR | `button-click` + `combo-trigger`; `card-play-attack` de 6,70 a 6,95 | alta |
| 7,30 / 8,55 | golpes (BUILD / A LIVING) | `sword-sound` + `pit_brute/hurt_3` / `hurt_1` | alta |
| 9,11 / 9,81 | veneno (DECK.) | `impact-poison` + `pit_brute/hurt_*` | média |
| 10,75 a 15,77 | salões IA no groove | `crow/appear_1`, `boss_rune_ignite`, `boss_hellfire_wall`, `boss_frost_storm`, `boss_heartbeat` | média |
| 17,12 | coração explode | `boss/boss_roots_crawl.mp3` | média |
| 17,33 | grifo | `stingers/miniboss_entrance.mp3`; `storm_griffin_stop` em 17,89 | alta |
| 19,86 / 20,98 | anjo | `fallen_angel_start` / `fallen_angel_stop` | média/alta |
| 21,10 | serpente | `ice_wyrm_rise` (entrar em 0,38 s do arquivo) | alta |
| **24,36** | **trovão na estrada** | `weather/thunder-roll.mp3` (está no log) | **alta** |
| 26,60 a 29,9 | runas acendendo | `boss_rune_ignite` ×2 a 3 | média |
| **32,85** | **coluna de fogo** | `boss/boss_hellfire_wall.mp3` | **alta** |
| 34,60 | gelo | `boss_frost_storm` + `weather/ice-tinkle-1` | média |
| 38,20 | corvos | `crow/flock_2` | média |
| **41,26** | **portão** | `castle-gate-open.mp3` (o jogo o toca em 41,76, no quadro do corte; adiantar 0,5 s) | **alta** |
| **41,76** | **olhos** | `boss_eyes_ignite` + `boss_eyes_rumble` (jogo em f730, antes do trecho); piscadas em 42,49 e 43,24 | **alta** |
| **44,08 / 44,53 / 44,91** | **rasantes** | `boss_wing_pass` (+ `crow/cine_3` no 1º) | **alta** |
| **45,62** | **pouso** | `boss_land_impact` + `crow/flock_1` (45,77) | **alta** |
| 46,21 | cartão do nome | `boss_reveal_sting` (+ `impact_heavy`) | alta |
| 48,30 a 51,20 | mão e seleção | `card-draw` ×5, `clickselect2`, `hoverCard` | média |
| 52,11 | JOGAR | `button-click` + `combo-trigger`; `card-play-attack` ×3 | alta |
| **52,49** | **42** | `impact-fire` + `carrion_king/hurt_2` + `card-exhaust` | **alta** |
| 53,67 / 54,42 | 33 / 27 | `sword-sound` + `carrion_king/hurt_1` / `hurt_2`; `combo-trigger` em 53,88 | alta |
| 56,62 | bússola | sem som no jogo: `boot-card-whoosh` ou sintetizar | média |
| 58,74 | clarão | `impact_1` + `forge-reveal` | média |

### Ambiente
Noite do ato 1 (0,88 a 5,78); brasas (5,78 a 10,75); leitos dos salões (10,75 a 17,33); chuva forte (17,33 a 19,86); vento com grilos (19,86 a 21,10); nevasca (21,10 a 22,36); chuva com trovão (22,36 a 26,14); salões lentos com `boss_hold_ambience` (Lich), `ember-crackle` + `tyrant_chain_drag` (Tirano), `blizzard-2` + `wind-3` (gelo) e `ember-crackle` (Carniça) (26,14 a 39,01); noite (39,01 a 41,76); `place/boss-room-1` (41,76 a 55,94).

### Música
| início | fim | ação | dB | por quê | volta |
|---|---|---|---|---|---|
| 17,33 | 22,36 | duck | −5 | mini-chefes | — |
| 22,36 | 26,14 | duck | −8 | chuva e trovão (24,36) | 26,14 (grave) |
| 26,14 | 39,01 | duck | −6 | salões lentos sobre um pad sem grave: o som de cada salão conta a mecânica | — |
| 39,01 | 41,26 | duck | −14 | porta: noite e rangido | — |
| **41,26** | **46,21** | **silêncio** | — | portão, olhos, rasantes e pouso só com o jogo | **46,21** (grave, depois do drop 46,02, no cartão do nome) |
| 48,30 | 52,15 | duck | −6 | mão e seleção | — |
| **52,15** | **52,49** | **corte** | — | respiro depois do JOGAR | **52,49** (grave, 42) |
| **55,94** | **58,74** | **silêncio** | — | glitch e bússola | **58,74** (grave, clarão) |

### Problemas
- **Salões lentos de 26,2 a 38,9:** 12,7 s sem nenhum SFX, só o pad em ~−23 dB. Nem a coluna de fogo nem as runas têm som.
- **Porta:** −29 dB contra −23 dB (39,0 a 41,7).
- **Olhos, rasantes e pouso (41,8 a 46,1):** o stem de SFX fica em ~−72 dB, ou seja, praticamente mudo.
- O `tv_on.wav` entra em 0,0, embora a EDL marque `tv_on.synth = false` (o clipe do v8 já traz a TV ligando).
- Os hovers do jogo de 55,77 a 55,91 caem logo antes do glitch. Não colocar.
- O fade final dura 0,6 s e soa como corte.

---

## Os 5 momentos mais importantes de cada trailer

**B**
1. **32,59 a 37,40:** música fora. Olhos (32,80), rasantes (35,24, 35,69, 36,07) e pouso (36,79) com os sons do chefe; a música volta no cartão do nome (37,40).
2. **30,41:** portão (`castle-gate-open`) sobre a noite (grilos, vento), com a música a −14 dB.
3. **51,25 a 52,15:** corte de música depois do JOGAR; o 42 em 52,15 com `impact-fire` + voz do Rei, e a música volta no drop.
4. **54,99 a 57,18:** silêncio na bússola, giro sonoro, e a música volta no flash em 57,18.
5. **9,76:** a revelação rara (`pack-seal-break` + `card-discovered`) e os golpes do ladino com som real (3,49 a 7,86).

**A**
1. **16,76 a 18,00:** música fora; portão (17,26), olhos (17,76) e a volta no drop do pouso em 18,00.
2. **24,25 a 24,61:** respiro e o 42 com o som do jogo.
3. **0 a 1,45:** preencher o buraco com a TV do jogo, as brasas e o hover até o PLAY.
4. **26,89 a 28,34:** silêncio na bússola e volta no clarão branco.
5. **10,51 a 13,55:** grifo com stinger de mini-chefe e chuva forte, com a música a −5 dB.

**C**
1. **41,26 a 46,21:** silêncio; portão, olhos, três rasantes e pouso, e a volta no cartão do nome em 46,21.
2. **26,14 a 39,01:** salões lentos com som próprio (runas, coluna de fogo em 32,85, gelo, corvos) e a música a −6 dB.
3. **52,15 a 52,49:** respiro e o 42.
4. **24,36:** trovão na estrada à noite, com a música a −8 dB.
5. **55,94 a 58,74:** silêncio na bússola e volta no clarão.

## Arquivos
- `review_B.json`, `review_A.json` e `review_C.json` (este diretório): mesmos dados, no formato `{sfx, ambience, music, issues}`.
- Imagens e scripts em `C:\Users\corte\AppData\Local\Temp\claude\E--dev-projects-card-game-love2d\fe2f9e5c-7f88-40d3-853e-36666b269943\scratchpad\revisor\`: `revisor_{B,A,C}_loudness.png`, `_wave.png`, `_spec.png`, `_sheet_NN.jpg`, `revisor_events_{B,A,C}.json` (eventos do jogo no tempo do filme), `revisor_audio.json` (RMS por janela dos stems), `revisor_map.py`, `revisor_audio.py`, `revisor_sheets.py` e `revisor_write_json.py`.
