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
- Clipes em loop (walk/charge/trot/crawl/hop/swoop) sao dirigidos por FASE (andar = distancia da camera, investida =
  ease da derrapada), nunca por relogio solto, para terminarem exatamente no quadro final.

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
