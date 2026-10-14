---
name: code_notes/tools/demo_worldroad.lua
description: Comentários com decisão/regra/histórico colhidos de tools/demo_worldroad.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/demo_worldroad.lua`

Origem: `tools/demo_worldroad.lua` em `7dbdb60d` (14 de 27 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-18 (junto a `local M = {}`)

> tools/demo_worldroad.lua
> Demo do WorldRoad com o VISUAL REAL de batalha (game + enemy + HUD).
>
> Interativo (love . demo_worldroad):
> SPACE = viagem com encounter (inimigo vem lá de trás)
> 1-6   = troca bioma (com blend)
> V     = pula pra perto do marco (vista alta)
> R     = reset camZ
> ESC   = sair
>
> Tour (love . demo_worldroad tour): captura 6 keyframes automáticos no save
> dir (worldroad_k1..k6.png) e sai — pipeline de validação visual da LLM.
> k1 battle    — inimigo PLANTADO na estrada (getRoadAnchor) + HUD
> k2 depart    — viagem 15%: herói surge, encounter na crista
> k3 mid       — viagem 55%: inimigo desce a estrada crescendo
> k4 arrive    — viagem 92%: quase em posição de batalha
> k5 blend     — transição bioma 1→2 no meio (cores lerpando)
> k6 vista     — perto do marco: castelo da vista totalmente revelado

## L28-30 (em `M`, junto a `local _postKindCache = {}`)

> POSTGATE: força TODO prop a virar luminária da beira da estrada, pra
> validar a margem inteira ao vivo (viajando, trocando bioma). Escolhe um
> kind roadside do catálogo do bioma (lantern se houver, senão o 1º).

## L58-60 (em `forcePosts`, junto a `local function setupAudio()`)

> v9.7.2: áudio mínimo do demo (o love.load do main.lua NÃO roda em modo
> tool) — registra só os sons do cenário interativo + fork, pra validar
> o MATERIAL de cada elemento por bioma ao vivo

## L104-105 (em `setupGame`, junto a `local function drawBattleFrame(showEnemy)`)

> Frame de batalha completo (mesma composição do GameplayScene).
> LightEngine v1: mundo → inimigo → composite/fork overlay → HUD/UI

## L112-113 (em `drawBattleFrame`, junto a `local bbox, cx, cy`)

> v9.2: inimigo via callback do painter (mesma ordem do GameplayScene —
> postes mais próximos que ele ficam na frente)

## L139-142 (em `sim`, junto a `local function runTour()`)

> ============================================================================
> TOUR: keyframes automáticos (frame-driven — captureScreenshot só funciona
> de forma confiável dentro do loop real de frames, não em presents manuais)
> ============================================================================

## L219-223 (em `love.keypressed`, junto a `local MONSTER_ROSTER = {`)

> ============================================================================
> INTERATIVO
> ============================================================================
> GALERIA DE MONSTROS (tecla M): roster completo v5, idle rodando no
> cenário real; setas trocam, H = hurt, K = morte, J = revive.

## L245-247 (em `MONSTER_ROSTER`, junto a `local FORK_SETS = {`)

> v9.7.2: F cicla conjuntos de fork — os 6 tipos de lugar testáveis em
> qualquer bioma (hover acelera anim + som, porta da casa abre, clique
> converge de verdade)

## L261 (em `runInteractive`, junto a `WorldRoad._segBase = 0`)

> v10.4: progress do castelo conta daqui

## L358 (em `love.keypressed`, junto a `forkSet = forkSet % #FORK_SETS + 1`)

> v9.7.2: encruzilhada de teste — cicla os conjuntos de lugares

## L363-364 (em `love.keypressed`, junto a `WorldRoad._segBase = 0`)

> v10.2: ENTRADA DO BOSS INSTANTÂNEA — pula pro ponto de chegada
> e abre a porta direto (atalho pra testar a cutscene isolada).

## L374-378 (em `onComplete`, junto a `WorldRoad.travel({`)

> v10.4: SIMULA O FLUXO REAL — cada SPACE anda um passo rumo ao
> castelo (a esfera avança, o castelo CRESCE, monotônico). Quando
> chega PERTO o suficiente, a cerimônia de entrada dispara SOZINHA
> (porta abrindo + som + fade). Ao terminar, reseta pra andar de
> novo. É exatamente o fluxo do jogo (andar → perto → entrar).

## L405-406 (em `onComplete`, junto a `local cur = WorldRoad._timeOfDayTarget or 1`)

> F6.1: cicla o tempo do dia (dia → tarde → anoitecer), com
> a transição ease real do jogo

## L424-426 (em `WorldRoad._props`, junto a `love.mousepressed = function(mx, my, button)`)

> v9.7.2: mouse REAL no demo — fork clicável + cenário interativo
> (árvore/poste/cerca/nuvem reagem; rajada da grama já polla o mouse
> dentro do WorldRoad.update)

