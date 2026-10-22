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
- Beats de som que o motor dispara (contrato com `test_entrance_sfx`): andar stop/step1..3, investida skid/stop, brotar
  rise/stop, acordar wake/land(so espantalho e gargula, 50 % do assentamento)/stop, mergulho start/stop, condensar
  start(enxame em dur-2 s; sem enxame em u1)/form(u1, uma vez)/stop, flanco start/stop/hop, montar mid/stop.

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
