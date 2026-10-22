---
name: enemy_entrances
description: Entradas por inimigo (36 comuns/elites/mini-chefes): motor EnemyEntrance sobre a viagem do WorldRoad, dados por criatura, ancoras como props, clipes com fallback no idle, galeria e travas
type: project
---

# Entradas por inimigo (22/Out/2026)

Design: `docs/superpowers/specs/2026-10-22-entradas-inimigos-design.md`. Pedido do dono: cada bicho chega de um jeito
(sai do chao, desce do ceu, acorda de estatua, condensa da nevoa, entra pelo flanco), sem quebrar a continuidade.

## Onde mora
- Dados: `src/data/enemy_entrances.lua` (`BY_ID[id] = { kind, clips, extra, settle, anchor, fx, sfx, bounce, ... }`,
  `BASE = 6.5`, `MAX_EXTRA = 3`). Sem entrada = `andar` com idle (comportamento antigo).
- Motor: `src/ui/EnemyEntrance.lua`. O `WorldRoad.lua` esta no teto de 200 locals, entao TODO o estado da entrada vive
  no modulo (`st`), e o WorldRoad so chama hooks: `begin` (em `travel`), `update` (dentro do bloco da viagem, DEPOIS de
  `tr.t += dt`), `pose`/`dxPx`/`drawUnder`/`notePos` (em `drawEncounterFront`), `relOff` (fatia de profundidade
  `encMark`), `drawProp` (props `anchor` no painter), `finish` (handoff), `reset`.
- O billboard do encontro (`WorldRoad._encounter.anim`) vira um `View` do motor: `draw` aplica alpha, tom (estatua/apagada)
  e `riseK` (quad do topo do sprite para o bicho que sai do chao); `getSize` devolve o canvas do idle.

## Tempo
- `WorldRoad._travel.duration = 6.5 + (extra - settle)` e `_travel.settle = settle`; a camera para em `duration` e a viagem
  so termina (`isTraveling()` false, handoff, `onComplete`) em `duration + settle`. Cortina da mao e `isQuiet` seguem
  `isTraveling()` sem mudar.
- Depois do handoff, `EnemyRenderer.triggerArrival(nil, { still = not EnemyEntrance.endsWithLanding() })`: a quicada de
  0,55 s so para quem POUSA (`bounce = true`: harpia, grifo, sapo, anjo); os outros ficam parados o mesmo tempo
  (`EnemyRenderer.isArriving()`), que e o que `test_hand_deal` exige (cartas so 0,5 s depois da chegada).
- `reducedMotion`: viagem base, assentamento <= 0,5 s, sem particula/tremor/relampago; luz e ancora continuam.

## Clipes
- `assets/sprites/characters/enemies/<id>/animations/<clipe>/south/N.png`, mesmo canvas do idle, ULTIMO quadro = idle 0
  byte a byte (contrato das frentes de arte; `test_enemy_entrances` mede a diferenca, tolerancia 2 % dos pixels).
- Quadro 0 de awaken/assemble/form/emerge = estado inerte/escondido, mostrado congelado durante a viagem.
- Clipe ausente: `Debug.warn` uma vez por id|clipe e o idle entra no lugar; o movimento (subir do chao, arco do mergulho,
  entrada pelo lado, alpha, investida com derrapada, estatua que acende, pedras que se juntam) e feito pelo motor, o clipe
  so melhora. Sem clipe o idle congela no quadro 1 na janela final (`FREEZE_WIN`) quando alcanca; senao o handoff
  continua no quadro corrente (continuidade garantida pelo `adoptHandoff`).
- Clipes em loop (walk/charge/trot/crawl/hop/swoop) sao dirigidos por FASE (andar = ease da viagem, investida =
  ease da derrapada), nunca por relogio solto. O laco roda nos quadros 1..n-1 e no fim segura o quadro n (= idle 0):
  as duas convencoes convivem (frente A: 9 quadros, primeiro e ultimo = idle; frente B: 8 quadros, so o ultimo = idle).
- `EE.END_LEAD` (0,12 s, ou 30 % do assentamento se for menor): toda fase chega a 1 esse tanto ANTES do handoff, entao o
  ultimo quadro do clipe e de fato exibido e parado antes da troca (sem isso o quadro na tela na troca era o n-1: a
  gargula trocava do olho roxo para o idle). O mesmo lead zera relOff/lift/deslocamento.
- Emissivos do bilhete do encontro em `z = min(rel, 9)` (a batalha usa 9), para a luz do bicho nao mudar na troca.
- Troll (flanco com clipe `emerge` e monte de neve na beira): quadro 0 congelado SOBRE o monte durante a viagem, emerge
  uma vez nos primeiros 40 % do caminho e segue no idle ate o palco; nunca em loop.
- Investida: `lead = 5` unidades (7 deixava o touro invisivel ate o 4o segundo).
- Sombra de quem sai do chao (brotar/montar): `shadowA = 0,35 + rise` do comeco ao fim, nunca "1 na viagem e 0,35 na
  parada" (a trava `::entradas` pegou o salto de alpha no quadro da parada em 8 criaturas). Sentinela: o passo
  (`step`) ja vale durante a viagem (relOff = step), senao a estatua pula 0,6 unidade na parada.
- Ancora que CRESCE (espigao do xama) nasce na crista com altura 0 e e tracada com alpha 0: a trava considera o
  primeiro traco (qualquer alpha) como nascimento. O espigao e o `frost_crystal_0` recortado
  (`anchors/rime_shaman_anchor.png`), nao um placeholder.
- **Sem micro-luz na entrada** (dono, 22/Out: "blocos quadrados de luz" em volta do bicho que somem no handoff): o motor
  NAO chama `LightEngine.submitMicro` para brilho/lanterna/coluna nem para a ancora; luz do bicho e so o emissivo dele
  (`EnemyEmissives`), que a batalha tambem desenha. Os campos `glow/lantern/column` dos dados ficaram inertes.
- **Ancora de palco ABRACA a linha dos pes** (dono: "sai na frente do buraco"): o prop principal desenha a metade de
  cima da PNG atras do corpo (z = palco + 0,25) e um segundo prop `front` (z = palco - 0,5, `ref` = o principal) desenha
  a metade de baixo POR CIMA dos pes, na viagem e na batalha. O bicho sai do meio do buraco/poca/circulo e fica dentro
  dele. Ancoras de beira (estaca, pedra, monte, espigao) nao abracam.
- **Andar com peso**: inclinacao (`crouch` 3 % na velocidade maxima), balanco vertical sincronizado com o ciclo do walk,
  quadro do walk preso a fase eased da viagem (pe nao desliza), e um assentamento de 1-2 px (`squashPulse`) na parada
  quando ha assentamento. Flanco vem da linha das arvores em diagonal (`relOff` 1,4 -> 0) e nao em deslize lateral.
- Sapo: 3 saltos pelo motor (o clipe `hop` so agacha) com esmagamento nos pousos intermediarios; o ultimo pouso e a
  quicada de chegada. Espantalho/gargula: tremem na estaca (0-30 % do assentamento), CAEM (30-50 %, ease-in),
  esmagam ao pousar com poeira, e pulam para o centro (58-100 %).
- Clima pelo `wx` do motor (ramps de 0,7 s, decaem sozinhos depois do handoff pelo tick em `dimAmbient`):
  `rain`/`blizzard` = `WeatherEngine.setIntensityOverride(base + 0,5)`, `fireflies` = `WeatherEngine.ffMute`
  (vagalumes do ceifador apagam), `dim` = ambiente x 0,55 (vigia). Relampago da harpia/grifo por `WeatherEngine.strike`.
- Ratos: 14 copias escuras do idle a 0,30-0,40 convergindo das duas bordas da tela, grama cutucada alternando os lados a
  cada 0,22 s. Sombra do crepusculo tem poca propria (`dusk_shade_anchor.png`, frente B), que abraca os pes e fica.
- O motor nao assume numero de quadros: `clipFrame`/`loopFrame` leem `#frames` (as frentes regeraram walk/charge/form/
  awaken/trot/crawl/hop/swoop com 12-13 quadros em 22/Out). Sentinela: plinto (`plinth`, `back = 0,6`, `lift = 22`) atras
  do palco; a estatua fica EM CIMA dele e desce ao chao no passo (`step`), com esmagamento e poeira.
- **Lado desde o primeiro pixel** (dono: "teleporta" para a estaca): `drawEncounterBehind` aplica o mesmo `dxPx` do caminho
  da frente (t = 0) e o lift do poleiro; o chao do corpo na frente e `g.latY(lat, t)` (igual ao da estaca), nao a formula
  do centro da estrada. Flanco (lobo, sapo, croc, troll) nasce VISIVEL na faixa lateral (`sideFrac = 1`, meio sprite
  fora da borda da estrada) e anda em diagonal ate o centro; nada mais nasce escondido fora da tela. A trava `::entradas`
  compara o `lat` (x relativo ao centro da estrada) quadro a quadro, atras e na frente da crista.
- Brilho igual na troca: o caminho do encontro aplica a mesma respiracao de tom do `EnemyRenderer` (0,94 a 1,0), senao
  o handoff escurece 3 %. Salto da estaca com antecipacao (agacha 8 % nos 30 % iniciais), estica no ar (`squash` negativo)
  e esmaga no pouso (beat `land`) e de novo ao chegar ao centro, com poeira nos dois.
- Ancoras altas (estaca, pedra, plinto, monte, cogumelos, espigao): silhueta pelo `ShadowEngine.queue` + faixa de contato;
  chatas (lama, poca, cova, lombada, poca da sombra, fosso, rachadura): so faixa de contato a 0,45; circulo/sigilo nada
  (sao brilho). Toda ancora entra em `WorldRoad._hitScene` como `kind = "anchor"`: clique = `EE.poke` (balanco
  amortecido como o `pokeRot` das arvores, particula e som por nome: palha na estaca, lascas na pedra, neve no monte).
- **Rodada 2 do dono (23/Out)**:
  - Ancora visivel desde a crista: `drawPropsBehind` desenha a ancora (PNG inteiro, afundada `(1-em)*ih*s*0,95` como o
    corpo) na faixa de emergencia antes do domo; na frente a mesma posicao em t = 0, sem pop.
  - Sombra de ancora: a PNG passa por `ContactShadow.scan` ao carregar (sem o scan a faixa de contato era descartada em
    silencio) e a projetada usa `ShadowEngine.silhouette` com a propria imagem (o `queue` nao aparecia). Trava em
    `test_enemy_entrances` (silhueta com a imagem da ancora alta, contato em toda ancora alta/chata).
  - Pernas pela distancia: quem anda/investe ANDA no mundo (`relOff` de `WALK_DIST` 10 / `CHARGE_DIST` 16 unidades ate 0),
    quadro do clipe = distancia / passada, passada = 0,8 x largura do corpo em unidades do mundo no palco
    (`EE.strideUnits`), arredondada para o ciclo terminar inteiro (pe no idle). Antes o quadro seguia o ease da camera:
    parado longe, rajada no meio (pico 3x a media), parado no fim. Andar: posicao ease-out quad (comeca andando, freia).
    Investida: velocidade constante e os ultimos 0,3 s (`SKID`) derrapando com as pernas paradas, poeira a cada 0,05 s
    e um estica-agacha (cabecada) no `stop`. Flanco: ciclos = `flankDist` (4) / passada sobre a posicao eased.
  - Ratos: 10 ratos (clipe `rat_run` da frente de arte, quadro pela distancia corrida, passada 1,2 x largura do rato;
    reserva = recorte `RAT_QUAD` do `form` com anca arredondada) correm das bordas da tela
    em arco ate pontos do monte, escalonados entre `dur-2,7` e `u1+0,3`, cada um cutuca a grama ao passar; somem com o
    alpha do monte. Emissivo dos olhos dos ratos removido de `enemy_emissives` (era o "brilho quadriculado").
  - Ceifador: a nevoa virou ancora de palco (`mist = true`, abraca os pes): engrossa com a aproximacao (`mistThick`),
    pulsa devagar, motas escuras subindo, vagalumes apagam; o corpo entra por alpha so no ultimo 1,2 s DENTRO dela e a
    nevoa vira um anel baixo (`mistRing`) que fica na luta. Sem brilho na foice (exigiria saber a ponta: pendente).
  - Som: `ENTRANCE_GAIN = 1,0` neutro (frente de som baixou os arquivos 6 dB).
- **Rodada 3 (23/Out)**: ancora animada = `anchors/<id>_anchor_0..N.png` (`EE.anchorFrames`, `ANCHOR_FPS` 5, fase pela
  posicao no mundo; reducedMotion = quadro 0; a PNG unica fica de reserva). Nevoa do ceifador: os quadros sao opacos e
  quase pretos, entao o motor desenha a `MIST_ALPHA` 0,7 misturada 30 % na cor da neblina do grade; um veu (quadro inteiro,
  sem esticar) cobre o terco de baixo do corpo so durante a condensacao (pico no meio) e o corpo fica escurecido
  (`MIST_BODY_TINT` 0,45 -> 1) enquanto o form passa pela silhueta cinza da arte.
  **Causa do "brilho quadriculado" em quem condensa (ratos, ceifador, vigia...)**: o encontro enviava o corpo como oclusor
  do `LightEngine` (cor chapada no lightmap de 1/4) mesmo com alpha baixo, acendendo uma mancha em blocos no formato do
  sprite. Oclusor e contorno de luz (`drawRim`) agora so com o corpo opaco, como na batalha.
- **Sombra de ancora na batalha (23/Out, dono: "a estaca nao tem sombra")**: a silhueta projetada cai NA FRENTE da ancora
  (em direcao a camera), sobre chao cuja grama so e desenhada DEPOIS do composite de sombras do meio do quadro (o
  `ShadowEngine.endFrame` antes do inimigo); a grama cobria a sombra inteira. Solucao: a ancora nao enfileira sombra no
  desenho; `EE.deferShadow` guarda e `EE.flushShadows()` enfileira tudo logo antes do ultimo `flushGrassTo(-1)` +
  `endFrame` do `drawProps` (silhueta pelo `ShadowEngine.queue`, como arvore e poste, alpha 1,0; faixa de contato idem).
  Trava por PIXEL em `test_enemy_entrances` (`M.battleShadow`): cena real apos o handoff, com e sem a ancora, conta pixels
  >= 3 % mais escuros fora da caixa dela; espantalho (tod 0,85 e 0,62) e gargula >= 1500 (medidos 5841 a 14986; antes
  ~200, so o monte). A trava antiga contava chamadas e passava com a sombra invisivel.
- **Ordem na crista**: o `drawEncounterBehind` vinha ANTES do `drawPropsBehind`, entao a estaca era pintada por cima do
  espantalho. As ancoras sairam do `drawPropsBehind` e sao desenhadas por `EE.drawBehindAnchors` no comeco do
  `drawEncounterBehind`, antes do corpo. Na frente a ordem ja vinha do z (ancora 0,25 atras do corpo).
- Beats de som que o motor dispara (contrato com `test_entrance_sfx`): andar stop/step1..3, investida skid/stop, brotar
  rise/stop, acordar wake/land(so espantalho e gargula, 50 % do assentamento)/stop, mergulho start/stop, condensar
  start(enxame em dur-2 s; sem enxame em u1)/form(u1, uma vez)/stop, flanco start/stop/hop, montar mid/stop; investida tambem `charge` (uma vez, quando o corpo passa 2 unidades da crista correndo).

- **Rodada 4 (24/Out, feedback do dono atos 1 a 6)**:
  - **Flash do corpo no palco** (todas as criaturas): o quadro em que o andar ja mudou e a viagem ainda nao comecou
    desenhava o corpo de BATALHA no palco. `GameplayScene.travelPending()` (andar mudou e a viagem nao comecou, ou 1a luta
    pedida por `requestArrival`) conta como viagem no `draw`: nenhum `EnemyRenderer.draw` antes da entrada. A galeria
    (`tools/entradas.lua mount`) ja deixa o andar 3 pendente. Trava `M.firstFrames` em `test_enemy_entrances`.
  - **Ancora chata e decalque de chao** (`EE.FLAT_ANCHORS`: circulo, sigilo, rachadura, fosso, lombada, lama, poca, cova,
    poca da sombra, nevoa): a metade de tras e desenhada por `EE.drawFlatUnder` no `drawEncounterFront` ANTES do corpo
    sempre que o painter a desenharia depois (bicho atras dela andando); o painter pula (`p._early`). A ancora de palco e
    POSICIONADA no z do corpo (`stopZ + BATTLE_REL`), o +0,25 so ordena: com o +0,25 a borda da frente subia acima dos pes
    (pes "cortados" do bruto, da sanguessuga, pes "afundados" do ceifador). A metade da frente comeca na linha do chao e
    so cobre os 2 px do `FOOT_SINK`.
  - Trava por PIXEL (`M.flatOcclusion`): a cada 4 quadros da chegada e 6 da batalha, 4 capturas da cena (com ancora, corpo
    magenta, corpo verde, sem ancora; relogio congelado); mascara do corpo = onde magenta e verde diferem (corpo opaco,
    erodido 1 px); falha se a ancora muda QUALQUER pixel do corpo acima da linha do chao - 2 px. Amostras com corpo
    translucido (condensar) ou veu da nevoa ficam de fora. Medido 0 px nas 10 criaturas.
  - **Sombra de ancora alta**: perfil de pegada por ancora (`EE.ANCHOR_SHADOW_PROFILE`, rocha 0,30/0,48 como
    `WorldRoad.SHADOW_PROFILE`) e a propria ancora entra como MASCARA do `ShadowEngine` (`maskAdd` + `deferShadow(..., mk)`,
    quads proprios por ancora), entao a sombra adiada nao pinta a pedra/monte/plinto/cogumelos. Estaca sem perfil (aprovada).
  - **Quem sai do chao fica 100% escondido na viagem** (`K.brotar`; excecao `inertStart`: a mae dos esporos, cujo quadro 0 e a propria moita de cogumelos, aparece desde a crista e a ancora de cogumelos saiu porque cobria as pernas dela): so a ancora treme (`_pokeT`) e solta particula a cada
    0,7 s nos ultimos 2,6 s; na parada o corpo sobe da linha do chao (`riseK` em 40 % da subida) com o clipe emerge junto.
    Sombra nasce em 0 na parada.
  - Golem: o quadro 0 do `assemble` (pilha de entulho, lia como um bloco) virou 7 FRAGMENTOS irregulares (Voronoi com ruido
    sobre os pixels do proprio quadro, `EE.fragments`) que rolam das bordas girando em passos de 90 graus e se encaixam
    exatamente no quadro 0 na parada; o corpo so aparece ali.
  - Sentinela: plinto na BEIRA (`at = "side"`), desce e salta para o centro como o espantalho.
  - Troll: `sit = { clip, stand, walk, inset }` (`sitFlank`): sentado de pernas cruzadas ao lado do monte (quadro 0 do
    `stand` da frente de arte; `sit` se um dia existir), na parada levanta e ruge no `stand` (50 % do assentamento), anda
    ao centro com o `walk` pela distancia e o `stop` toca o rugido. Lado fixo pela pose da arte: troll vem da esquerda,
    lobo e crocodilo da direita.
  - `stopClip` (andar): clipe tocado no assentamento depois da caminhada: `laugh` do dullahan (ergue a cabeca e ri),
    `cackle` da bruxa (gargalha de mao erguida).
  - Cavaleiro da geleira refeito (`fogbank`): nevasca grossa na viagem, silhueta escura que ganha cor e opacidade andando,
    rodamoinho de geada e grama cutucada, 3 passos com geada e tremor, nevasca afina na parada e fica uma nevoa de geada.
  - Bruxa: `wisps` (fogos-fatuos em pixel, aditivo, orbitando o corpo, `EE.drawOver` depois do corpo) que mergulham na mao
    no assentamento, cena escurece na viagem e clareia na parada, passos com respingo e junco.
  - Duque: gotas de sangue girando com o enxame, cena escurece, na parada lampejo carmesim (`spec.flash`), petalas de sangue
    no chao (`blood`), floreio da capa (`flourish`). Dullahan: rastro de fogo-fantasma roxo (cor da arte), 3 passos pesados,
    lampejo roxo na parada.
  - **Mini-chefes marcantes** (`spec.marquee`, so tier mini_boss, `EE.isMini`): extra ate `MAX_EXTRA_MINI` 5 s; cena
    escurece 1,6 s antes da parada; no beat `marquee.hit` tremor forte, rajada na grama em 7 pontos, particulas do tema e
    lampejo da cor do bicho; camera EMPURRA ate +6 % no assentamento e volta a 1 antes do handoff (`EE.worldZoom`, aplicado
    no `GameplayScene` como o zoom do chefe); cartao de nome (`end_screen.enemy.<id>` + `bestiary.creature.<id>.epithet`,
    sem string nova) a 30 % do assentamento por 1,6 s no relogio do jogo (`WorldRoad._time`), a 87 % da altura (abaixo dos pes, na faixa da mao que esta escondida), pulavel com Enter/Espaco/clique
    (`EE.skipCard`). Corpo 15 % maior (`EE.sizeK`: billboard, batalha, sombra e HUD juntos); cavaleiro da geleira +10 %.
  - **Cadeia de clipes** (`chain = true`, contrato com a frente de arte): `clips` ordenada, so o ultimo termina no idle 0 e
    `last(i) == first(i+1)` (trava). `chainFrame` toca a cadeia por fase; no mergulho com cadeia o 1o clipe toca UMA vez no
    ar (em laco com `swoopLoop = true`, voo loopavel da harpia e do morcego), o pouso comeca em 60 % e o toque no chao em 70 % (beat `touch`).

## Ancoras
- Prop `kind = "anchor"` em `WorldRoad._props` criado no `begin` em `stopZ + BATTLE_REL + 0.25` (atras do bicho na
  profundidade: o decalque fica sob os pes), `side = 0` (palco) ou `+-1` (beira: estaca, pedra, monte de neve, espigao).
  Nasce na crista como todo prop, atravessa a luta e e reaproveitado pelo laco de re-rolagem (`p.anchor = nil`).
- Arte: `assets/sprites/world/anchors/<id>_anchor.png` (1 px da ancora = 1 px do idle, base = contato com o chao); sem o
  PNG o motor pinta um reserva em canvas (`EE.ANCHOR_SIZE`). `getSprite` devolve `false` para `anchor`.
- Veus (`anchor.veil`: nevoa do ceifador, borrao do vigia) nao sao props: o motor desenha no caminho do encontro com
  alpha cruzado (veu some enquanto o corpo aparece).

## Travas
- `test_enemy_entrances`: 36 entradas declaradas, tipos/clipes/fx validos, extra <= 3, clipes instalados com ultimo
  quadro = idle 0, simulacao seca do motor (termina no palco, sem lift/alpha/deslocamento, handoff idle, reducedMotion).
- `test_scene_continuity ::entradas` (ou `1::entradas`, `CONT_ID=<id>`): 36 criaturas no ato real, corpo e sombra sem
  salto no handoff, ancora nascida na crista sem pop, viagem <= 9,5 s, 1o quadro da batalha = idle 0 quando houve clipe.
- Galeria: `lovec . entradas [id]` (setas trocam, R repete, 1-6 ato). Capturas: `CARDGAME_HEADLESS=1 lovec . test_one
  screenshot_entradas [id|atoN]` -> `%APPDATA%/LOVE/<identidade>/entradas/atoN/<id>.png` (tira 6x2), `<id>_handoff.png`
  (recorte 1:1 do ultimo quadro do encontro e do 1o da batalha) e `folha.png`; copiar para `tools/preview_out/entradas/`.

## Som proprio por criatura (22/Out/2026)
- Dono: "sons genericos... quero sons especificos para cada monstro". 52 mp3 gerados no ElevenLabs (free, 10 creditos por
  segundo pedido; 961 gastos, 322 sobraram) em `audio/sfx/entrances/<id>_<beat>.mp3`: 36 assinaturas (uma por criatura, no
  beat principal: skid do touro, wake da efigie, rise de quem sai do chao, stop de quem pousa/condensa) + 16 segundos beats
  (bull/hound/troll/croc/brute `stop` no lugar do `enemyBuffRoar`, griffin/harpy/anjo `start`, gargula/sentinela/glacier
  `stop`, golem `mid`, sapo `hop`, ratos `start`, lobo `start`+uivo no `stop`, scarecrow `wake`+`stop`).
- Registro por SCAN no `main.lua` (`entrance_<arquivo>`, volume `Data.SFX_VOLUME` 0,55, pasta `Data.SFX_DIR`, prefixo
  `Data.SFX_PREFIX`), igual ao joker-sig; nos dados o som proprio e SEMPRE o 1o codigo da lista do beat e o generico antigo
  fica atras como fallback (`playFirst` toca o primeiro que `Sfx.has`). Tool sem boot do main.lua cai no generico.
- Beat tem de EXISTIR no motor para o tipo: andar stop/step, investida skid/stop, brotar rise/stop, acordar wake/stop,
  mergulho start/stop, condensar start(so swarm)/stop, flanco start/stop/hop, montar mid/stop. O scarecrow tinha `flock`,
  que nenhum lugar dispara (corvos nunca tocavam): removido. Desde 56bb1837 o motor dispara `form` (condensar, em u1, quando
  o corpo comeca a aparecer; `start` tambem dispara ai para quem nao tem enxame, entao so UM dos dois por criatura) e `land`
  (espantalho e gargula, 50 % do assentamento, corpo no chao): ceifador/cavaleiro espectral/vigia/espectro/sombra usam
  `form`; espantalho = wake (corda) → land (corpo na terra) → stop (crowFlock); gargula = wake → land (baque) → stop.
- Pos-processo (`tools/gen_entrance_sfx.py`: `balance`, `gen`, `post`, `layer`, `measure`, `report`): corte de silencio,
  media -16 dB com limitador -1,5 dB, reencode se o pico passar de -0,6 dB (mp3 estoura o limitador). Geracao quase muda
  (media crua < -30 dB) = prompt "close up / continuous" e regerar; "tall grass" devolveu silencio 2x.
- Trava `test_entrance_sfx`: toda criatura com som proprio, arquivo da criatura e do beat, 1o da lista, fallback conhecido
  (SOUNDS/CrowSfx/main.lua), beat disparado pelo tipo, mp3 decodifica, 0,35 a 3 s, media -28 a -9 dB, pico < 1,0.
  Notas por arquivo em `tools/preview_out/entradas_som/LEIA.md` (veredito por envelope/centroide, sem escuta real).
- Rodada 2 (dono: "altos demais", touro/cao "parecem carro manobrando"): arquivos 6 dB abaixo (media -22 dB, pico
  <= -6,6 dB; trava -36..-15 dB e pico <= 0,5), ganho por categoria do motor neutro. Touro e cao regerados como cascos/patas
  em terra seca ("animal only, no vehicles, no rubber"). Detector de "cara de maquina": `gen_entrance_sfx.py tonal` (flatness
  espectral < 0,02 = tom sustentado de motor/rotor/turbina); grifo start, morcego e sentinela wake regerados por isso.
- Rodada 3: com a investida nova (`skid` no inicio dos 0,3 s finais de derrapada, `stop` no fim) o `skid` do touro e do
  cao virou SO o deslizar na terra (0,37 e 0,50 s); som de galope tocado no `skid` cairia com as pernas ja paradas. Bufo e
  rosnado ficam no `stop`. Galopes guardados em `tools/preview_out/entradas_som/raw/*_r2.mp3` para um beat de corrida.
- Rodada 4: investida tem `charge` (2 unidades depois da crista, ~2,5-3 s antes da parada): touro e cao tocam ali o
  galope da rodada 2 cortado so nas batidas (`<id>_charge.mp3`); linha do tempo charge -> skid (deslize) -> stop (bufo/rosnado).
