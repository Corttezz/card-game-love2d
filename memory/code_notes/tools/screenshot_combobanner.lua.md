---
name: code_notes/tools/screenshot_combobanner.lua
description: Comentários com decisão/regra/histórico colhidos de tools/screenshot_combobanner.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/screenshot_combobanner.lua`

Origem: `tools/screenshot_combobanner.lua` em `7dbdb60d` (8 de 13 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-15 (junto a `local M = {}`)

> tools/screenshot_combobanner.lua
> Valida o ComboBanner:  love . screenshot_combobanner
>
> v2 (feedback do dono Set/2026): a versao 1 desenhava o banner ISOLADO
> sobre o cenario, o que nao testava nada do que ele reclamou. Agora o tool
> dirige o GameplayScene DE VERDADE — mesma ordem de painter do jogo — com
> cartas na MAO e cartas VOANDO pro centro, que era exatamente quem estava
> cobrindo o banner.
>
> Saidas:
> combobanner_impact.png    banner + cartas voando + mao (prova de z-order)
> combobanner_impact_in.png meio da queima de entrada
> combobanner_multi.png     3 combos no mesmo turno (banner unico)
> combobanner_reduced.png   com reducedMotion (aparece igual, sem queima)
> combobanner_small.png     janela estreita (zona aperta → conteudo cede)

## L75 (em `buildScene`, junto a `local WorldRoad = require("src.ui.WorldRoad")`)

> deixa a estrada assentar (camera/vegetacao) antes de qualquer captura

## L87 (em `buildScene`, junto a `local function playCombo(game, ids, nPlay)`)

> Monta a mao com cartas que garantem o combo pedido e joga `nPlay` delas.

## L111-113 (em `game.selectedCards`, junto a `local function frame(GameplayScene, dt)`)

> Um frame do jogo: o love.update do main tica o EventManager ANTES da
> scene (o combate inteiro e diferido pra fila de eventos). Sem isso as
> cartas nunca voam e o impacto — que e quem levanta o banner — nao chega.

## L119-120 (em `frame`, junto a `local function drain(GameplayScene, game)`)

> Espera a jogada anterior terminar: playSelectedCards e ignorado enquanto o
> combatAnimationSystem estiver bloqueando (mesma guarda do jogo).

## L129-130 (em `drain`, junto a `local function pumpUntilBanner(GameplayScene, extra)`)

> Avanca a cena ate o banner subir (ele sobe no IMPACTO, nao no clique),
> e depois mais `extra` segundos. Retorna false se nunca subiu.

## L165-166 (em `strikeHand`, junto a `drain(GameplayScene, game)`)

> 3. tres combos no mesmo turno: 3 golpes (strike_combo + triple_strike)
> + uma carta de lifesteal (lifesteal_burst)

## L193-195 (em `strikeHand`, junto a `local realH = love.graphics.getHeight`)

> 5. ZONA APERTADA: janela baixa (o conteudo cede, a banda nao).
> Falsifica a janela em vez de setMode — padrao de
> memory/ui_layout_invariants.md (setMode repetido em tool nao retorna).

