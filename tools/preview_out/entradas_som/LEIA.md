# Sons de entrada por criatura (22/Out/2026)

Gerados com ElevenLabs sound-generation (`tools/gen_entrance_sfx.py`, conta FREE: 10 creditos por segundo pedido).
Instalados em `audio/sfx/entrances/<id>_<beat>.mp3`, registrados por scan no `main.lua` como `entrance_<id>_<beat>`
(volume 0,55) e referenciados em `src/data/enemy_entrances.lua` sempre como PRIMEIRO codigo da lista do beat, com o
generico antigo logo atras (fallback por `Sfx.has`). Pos-processo: corte de silencio (-42 dB na frente, -48 dB na cauda),
ganho para media -16 dB com limitador em -1,5 dB, reencode se o pico passar de -0,6 dB. Faixa dos corvos medida:
media -12 a -20,5 dB. A pasta `raw/` guarda o mp3 cru da API (fora do git).

Honestidade da "escuta": nao tenho saida de audio neste processo. O veredito de cada arquivo vem do envelope
(inicio audivel, instante do pico, onde a cauda cai 20 dB) e do centroide espectral (grave < 500 Hz, medio, agudo > 5 kHz),
cruzados com o que o prompt pediu. Arquivos cuja geracao saiu quase muda (media crua < -30 dB) foram REGERADOS com prompt
"close up / continuous"; os que ficaram em pe sao marcados. Quem ouvir de verdade: `lovec . entradas <id>`.

## Tabela (criatura x beat x arquivo)

| Criatura | Beat | Arquivo | Dur | Media | O que e | Veredito |
|---|---|---|---|---|---|---|
| cursed_scarecrow | wake | cursed_scarecrow_wake.mp3 | 1,02 s | -23,6 dB | corda estalando, estaca de madeira, palha (regerado; a 1a saiu muda) | agudo (7,5 kHz), pico em 0,44 s: estalo no meio do tremor, ok |
| cursed_scarecrow | land | cursed_scarecrow_stop.mp3 | 1,06 s | -20,4 dB | corpo de palha caindo na terra, corvos batendo asa | ataque em 0,09 s, cauda curta, ok |
| hollow_farmer | stop | hollow_farmer_stop.mp3 | 0,81 s | -17,4 dB | forcado riscando a terra e fincando com baque | ataque seco, agudo do risco + baque, ok |
| plague_rats | start | plague_rats_start.mp3 | 1,60 s | -18,9 dB | muitos roedores correndo e guinchando (regerado 2x; o modelo devolvia silencio com "tall grass") | agudo continuo ate 1,5 s, ok |
| plague_rats | stop | plague_rats_stop.mp3 | 0,88 s | -16,9 dB | pilha de ratos se mexendo, guinchos | curto e agudo, ok |
| harvest_reaper | form | harvest_reaper_stop.mp3 | 1,48 s | -16,5 dB | foice cantando no ar, vento em trigo seco | pico tardio (1,18 s) = a lamina desce no fim, combina com o form terminando, ok |
| blight_bull | skid | blight_bull_skid.mp3 | 0,37 s | -26,0 dB | cascos fendidos derrapando em terra solta e pedrisco, poeira (rodada 3) | raspado ruidoso de 0,3 s, 0 % tonal; o bufo fica no `stop` |
| blight_bull | stop | blight_bull_stop.mp3 | 0,85 s | -18,2 dB | bufo e casco batendo | curto, ok |
| wicker_effigy | wake | wicker_effigy_wake.mp3 | 1,96 s | -17,2 dB | vime e palha pegando fogo por dentro, crepitar, brasas | agudo (8,5 kHz) crescendo ate 1,2 s: fogo tomando, ok |
| moon_gargoyle | wake | moon_gargoyle_wake.mp3 | 1,76 s | -16,3 dB | pedra rachando continuamente, lascas, baque no fim (regerado; a 1a era um estalo so) | cheio ate 0,95 s, ok |
| moon_gargoyle | land | moon_gargoyle_stop.mp3 | 0,77 s | -18,2 dB | criatura de pedra pousando, baque, pedrinhas | ataque imediato, ok |
| ram_cultist | stop | ram_cultist_stop.mp3 | 1,30 s | -16,6 dB | circulo runico acendendo roxo, zumbido | sustentado ate 1,1 s, ok |
| storm_harpy | start | storm_harpy_start.mp3 | 0,98 s | -17,4 dB | trovao seco e asas mergulhando na chuva | ok |
| storm_harpy | stop | storm_harpy_stop.mp3 | 1,21 s | -17,8 dB | asas batendo forte e pouso, rajada na grama | ok |
| rune_golem | mid | rune_golem_mid.mp3 | 1,23 s | -19,7 dB | pedras rolando pela colina | grave-medio continuo, ok |
| rune_golem | stop | rune_golem_stop.mp3 | 2,00 s | -16,4 dB | pedras batendo e se empilhando, baque, poeira | ok (sem a runa acendendo: fica para o fallback visual) |
| spectral_knight | form | spectral_knight_stop.mp3 | 0,58 s | -18,8 dB | armadura fantasma assentando, clank abafado com reverb | curto, aceitavel para uma parada |
| storm_griffin | start | storm_griffin_start.mp3 | 1,12 s | -16,5 dB | asas enormes passando baixo, trovao distante | grave (176 Hz), ok |
| storm_griffin | stop | storm_griffin_stop.mp3 | 1,50 s | -16,4 dB | pouso pesado com trovao, asas dobrando | grave, ataque imediato, ok |
| ember_imp | rise | ember_imp_rise.mp3 | 1,13 s | -17,1 dB | rachadura incandescente abrindo, jato de brasas | inicio em 0,37 s (sobe com o bicho), ok |
| hellhound | skid | hellhound_skid.mp3 | 0,50 s | -23,9 dB | patas e garras derrapando em terra solta e cascalho, poeira (rodada 3) | cresce ate 0,35 s, 0 % tonal; o rosnado fica no `stop` |
| hellhound | stop | hellhound_stop.mp3 | 0,72 s | -16,5 dB | rosnado grave, brasas chiando | grave (281 Hz), ok |
| abyss_acolyte | stop | abyss_acolyte_stop.mp3 | 1,18 s | -16,8 dB | sigilo acendendo, zumbido, paginas | grave sustentado, ok |
| obsidian_sentinel | wake | obsidian_sentinel_wake.mp3 | 1,76 s | -16,7 dB | estatua de obsidiana despertando, pedra e metal rangendo | grave (175 Hz) continuo, ok |
| obsidian_sentinel | stop | obsidian_sentinel_stop.mp3 | 0,55 s | -17,6 dB | um passo de pedra e metal | curto, ok |
| pit_brute | rise | pit_brute_rise.mp3 | 1,85 s | -23,3 dB | pedras e cascalho caindo, maos raspando rocha, respiracao (regerado) | continuo ate 1,6 s, um pouco baixo, aceitavel |
| pit_brute | stop | pit_brute_stop.mp3 | 0,50 s | -17,9 dB | corpo pesado caindo na rocha, grunhido | curto, ok |
| abyss_watcher | form | abyss_watcher_stop.mp3 | 1,93 s | -16,4 dB | zumbido grave de entidade flutuante, drone | grave (128 Hz) 1,6 s; ideal seria no inicio do form (hook pedido ao lead) |
| frost_wight | form | frost_wight_stop.mp3 | 1,60 s | -17,0 dB | vento artico condensando, gelo estalando | pico em 0,95 s, ok |
| frost_wolf | start | frost_wolf_start.mp3 | 1,15 s | -18,8 dB | lobo trotando na neve, galhos soltando neve | agudo (neve), ok |
| frost_wolf | stop | frost_wolf_stop.mp3 | 1,81 s | -16,4 dB | um uivo longo na nevasca | grave-medio (493 Hz) sustentado, ok |
| rime_shaman | stop | rime_shaman_stop.mp3 | 1,26 s | -22,3 dB | cajado fincado na neve, espigao de gelo crescendo | agudo crescente, ok |
| glacier_knight | step | glacier_knight_step.mp3 | 0,52 s | -20,7 dB | um passo de ferro pesado no gelo | toca 3x com variacao de pitch, ok |
| glacier_knight | stop | glacier_knight_stop.mp3 | 0,93 s | -20,9 dB | cavaleiro parando, placas assentando, geada | ok |
| frost_troll | start | frost_troll_start.mp3 | 1,76 s | -16,5 dB | monte de neve explodindo, blocos de gelo | ataque imediato forte, ok |
| frost_troll | stop | frost_troll_stop.mp3 | 0,55 s | -16,4 dB | pisada na estrada congelada, grunhido | curto, ok |
| ice_wyrm | rise | ice_wyrm_rise.mp3 | 1,70 s | -23,1 dB | placa de gelo rachando e explodindo em geiser de neve | inicio em 0,44 s, pico em 0,72 s, ok |
| bog_ghoul | rise | bog_ghoul_rise.mp3 | 1,71 s | -16,8 dB | corpo saindo da lama, succao, bolhas | pico tardio (1,28 s) = corpo inteiro saindo, ok |
| plague_toad | hop | plague_toad_hop.mp3 | 0,65 s | -25,9 dB | plop umido de um salto | baixo de proposito (3 saltos seguidos) |
| plague_toad | stop | plague_toad_stop.mp3 | 1,02 s | -21,8 dB | sapo caindo na poca com respingo | ok |
| leech_horror | rise | leech_horror_rise.mp3 | 1,43 s | -19,0 dB | massa viscosa jorrando da poca, succao, gotas | ok |
| mire_hag | stop | mire_hag_stop.mp3 | 0,80 s | -21,1 dB | corrente do lampiao rangendo, botas na lama (regerado) | curto; a corrente e o que marca, aceitavel |
| croc_warrior | start | croc_warrior_start.mp3 | 1,55 s | -19,3 dB | crocodilo saindo da agua, respingo, agua escorrendo | ok |
| croc_warrior | stop | croc_warrior_stop.mp3 | 1,36 s | -16,4 dB | silvo e rosnado de crocodilo, corpo se arrastando | ok |
| spore_mother | rise | spore_mother_rise.mp3 | 1,87 s | -17,6 dB | cogumelo inchando com rangidos e abrindo com estalo umido, esporos (regerado) | cheio ate 1,67 s, ok |
| dusk_shade | form | dusk_shade_stop.mp3 | 1,28 s | -17,2 dB | sombra condensando, sopro frio, chiado | ok |
| dusk_bat | stop | dusk_bat_stop.mp3 | 0,85 s | -16,5 dB | morcego gigante pairando, asas de couro (regerado) | grave (123 Hz) de batida de asa, ok |
| grave_thrall | rise | grave_thrall_rise.mp3 | 1,40 s | -26,1 dB | terra de cova quebrando, garras, torroes caindo (regerado) | agudo; media baixa por pico unico, aceitavel |
| blood_duke | stop | blood_duke_stop.mp3 | 1,00 s | -20,5 dB | enxame de morcegos fechando em um corpo, floreio de capa | agudo (9 kHz) de asas, ok |
| dullahan | stop | dullahan_stop.mp3 | 1,34 s | -17,6 dB | armadura e correntes assentando, chama espectral acendendo | ok |
| fallen_angel | start | fallen_angel_start.mp3 | 2,00 s | -16,4 dB | coluna de luz abrindo, ressonancia grave tipo orgao, sem vozes | grave (418 Hz) sustentado 1,2 s, ok |
| fallen_angel | stop | fallen_angel_stop.mp3 | 1,78 s | -16,5 dB | asas enormes dobrando com baque macio, penas caindo | grave (154 Hz), pico em 0,67 s, ok |

## Fallback por camadas
Nenhum. O orcamento (1.283 creditos no inicio) deu para gerar as 52 pecas (36 assinaturas + 16 segundos beats) e
regerar 8 fracas; a API fechou em 961 creditos gastos (contador atualiza com atraso), sobraram 322. O catalogo `LAYER` do `tools/gen_entrance_sfx.py` (mistura de 3 sons existentes com
pitch por criatura) ficou pronto como plano B (`python tools/gen_entrance_sfx.py layer <id_beat>`), nao foi usado.

## Pendente
- (feito em 56bb1837 + este commit) `form` no `K.condensar`: vigia, ceifador, espectro, cavaleiro e sombra agora soam
  no inicio da condensacao; espantalho e gargula ganharam `land` (corpo no chao) entre `wake` e `stop`.
- Licenca: tudo no plano FREE do ElevenLabs (sem uso comercial), igual aos outros SFX; regerar antes de vender.

## Rodada 2 (feedback do dono, 22/Out/2026)

1. "Altos demais": TODOS os arquivos renormalizados 6 dB abaixo (media alvo -22 dB em vez de -16, limitador em -7,5 dB,
   pico final <= -6,6 dB). Medias finais de -22,4 a -34,8 dB; a trava agora exige media -36..-15 dB e pico <= 0,5.
   O ganho por categoria do motor (entradas-motor) fica neutro em 1,0: a mistura certa ja esta nos arquivos.
2. Touro e cao "pareciam carro manobrando / pneu cantando": regerados como cascos pesados (touro) e patas grandes (cao)
   batendo em terra seca, com bufo/rosnado e derrapada de poeira no fim, prompt com "animal only, no vehicles, no rubber".
   Medido: espectro ruidoso (flatness 0,07 e 0,04, 0 a 7 % de quadros tonais; o pneu e um tom sustentado), touro com 4
   batidas crescendo e pico em 0,93 s (cai na derrapada do beat `skid`), cao com pico em 0,37 s e rosnado no fim.
3. Re-escuta com o ouvido do dono: ranqueei os 52 por conteudo TONAL (flatness espectral < 0,02 nos quadros altos), que
   e o que soa a motor, turbina, zumbido eletronico ou rotor. 10 arquivos deram >= 86 % tonal:
   - REGERADOS (lidos como maquina): `storm_griffin_start` (drone de 176 Hz sustentado = turbina; agora asas batendo +
     trovao natural, 0 % tonal), `dusk_bat_stop` (123 Hz continuo = rotor de helicoptero; agora batidas de asa separadas +
     guincho, 0 % tonal), `obsidian_sentinel_wake` (175 Hz com "metal joints" = motor/engrenagem; agora rocha rangendo e um
     passo de pedra, 0 % tonal; ficou baixo, media -34,8 dB, porque o corpo e o passo e o resto e cascalho).
   - MANTIDOS (o tom e a voz/drone pedido, nao maquina): `fallen_angel_start` (ressonancia tipo orgao, sem vozes),
     `fallen_angel_stop` (baque grave de asas), `abyss_watcher_stop` (zumbido grave da entidade, e o roteiro), `abyss_acolyte_stop`
     (zumbido do sigilo), `hellhound_stop` (rosnado), `frost_wolf_stop` (uivo), `pit_brute_stop` (grunhido).
   - Os outros 42 sao ruidosos (terra, pedra, agua, palha, fogo, asas): sem cara de maquina pela medida.
   Mesma ressalva da rodada 1: veredito por medida (tonalidade, envelope, centroide), sem escuta real neste processo.

Creditos: 322 -> 225 (rodada 2: 6 geracoes, 97 creditos).

## Rodada 3 (motor novo da investida)

O entradas-motor mudou a investida: corrida em velocidade constante desde a crista, e so os ULTIMOS 0,3 s sao uma
derrapada real (pernas paradas, poeira a cada 0,05 s); `skid` dispara no INICIO desses 0,3 s e `stop` no fim. O galope
da rodada 2 (1,6 s de cascos/patas batendo) tocaria depois que as pernas ja pararam. Regerado so o deslizar: touro 0,37 s
(raspado de terra e pedrisco), cao 0,50 s (patas e garras na terra); o bufo do touro e o rosnado do cao continuam no
`stop` (rodada 1). Os galopes da rodada 2 ficaram em `raw/blight_bull_gallop_r2.mp3` e `raw/hellhound_run_r2.mp3`,
prontos se o motor ganhar um beat no inicio da corrida. Creditos: 225 -> 209 (2 geracoes de 0,8 s).

## Rodada 4 (beat `charge` do motor, 2c1d2817)

A investida ganhou `charge`: dispara uma vez quando o bicho correndo esta 2 unidades depois da crista, cerca de 2,5 a 3 s
antes da parada. Linha do tempo: charge (galope) -> skid (inicio do deslize de 0,3 s) -> stop (fim, bufo/rosnado).

| Criatura | Beat | Arquivo | Dur | Media | O que e | Veredito |
|---|---|---|---|---|---|---|
| blight_bull | charge | blight_bull_charge.mp3 | 1,30 s (1,0 s de som) | -23,1 dB | 5 batidas de casco em terra seca (galope da rodada 2, cortado antes do deslize e do bufo) | ruidoso, sem tom, ok |
| hellhound | charge | hellhound_charge.mp3 | 1,10 s (0,8 s de som) | -24,3 dB | patas pesadas batendo na terra (corrida da rodada 2, cortada antes da derrapada) | ruidoso, ok |

Sem credito novo: reaproveitados os brutos da rodada 2. Fallback do `charge`: `sceneStoneThud`.
