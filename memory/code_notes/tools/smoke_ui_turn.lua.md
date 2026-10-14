---
name: code_notes/tools/smoke_ui_turn.lua
description: Comentários com decisão/regra/histórico colhidos de tools/smoke_ui_turn.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/smoke_ui_turn.lua`

Origem: `tools/smoke_ui_turn.lua` em `7dbdb60d` (16 de 28 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-5 (junto a `local M = {}`)

> tools/smoke_ui_turn.lua
> Regressão do CAMINHO DO CLIQUE (nasceu do bug "encerro o turno e nada
> acontece"): testa o ciclo de turno como o JOGADOR faz — mousepressed +
> mousereleased nos botões reais, via GameplayScene — não só a API do Game.
> love . smoke_ui_turn

## L64-65 (em `pump`, junto a `local function click(btn)`)

> CLIQUE de verdade: hover (via update com mouse simulado) não dá pra
> forçar sem love.mouse — seta hover/pressed pelo caminho dos handlers.

## L81-82 (em `click`, junto a `pump(4.0)`)

> 2.0 -> 4.0 (Set/2026): o turno do inimigo virou cadeia de beats
> (~2.4s). Ver comentario gemeo em smoke_turn_order.

## L103 (em `click`, junto a `click(endTurnButton)`)

> clica encerrar IMEDIATAMENTE (animação no ar) — precisa ENFILEIRAR

## L107-108 (em `click`, junto a `pump(7.0)`)

> 3.0 -> 7.0: resolucao da carta (impacto > procs > efeitos > dissolve)
> + turno inteiro do inimigo, agora tudo em sequencia estrita.

## L114-116 (em `click`, junto a `local GameplayScene = require("src.scenes.GameplayScene")`)

> ===== 4. ABANDONO: a cena REBINDA pro game novo (bug Jul/2026:
> GameplayScene capturava deps.game e seguia na run abandonada —
> "abandonei, escolhi mago e caí na run antiga, tudo bugado") =====

## L128 (em `hide`, junto a `GameplayScene._endTurnCallout = true`)

> estado sujo per-run que precisa morrer no rebind

## L130-132 (em `hide`, junto a `local WorldRoad = require("src.ui.WorldRoad")`)

> CENÁRIO sujo da run "abandonada": mundo avançado no bioma 3 com
> viagem no ar + attackFx do inimigo com apex PENDENTE (o callback
> do game morto não pode disparar na run nova)

## L152-153 (em `hide`, junto a `pump(1.0)`)

> pump: se o attackFx da run morta tivesse sobrevivido, o apex
> dispararia aqui dentro da run nova

## L169-171 (em `hide`, junto a `WorldRoad.restoreProgress(2, 5)`)

> ===== 5. CONTINUAR: o mundo retoma no exato lugar do save =====
> (pedido do dono: progresso/proximidade do castelo/cenário — o
> progresso é emergente, restoreProgress reconstrói por ato+andar)

## L184 (em `hide`, junto a `do`)

> ===== 5b. MÃO CENTRALIZADA NA TELA (feedback Jul/2026) =====

## L200-202 (em `hide`, junto a `local gmA = Game:new()`)

> ===== 6. SAVE NA ENCRUZILHADA: os nós pendentes sobrevivem ao
> save/load (bug: 'salvei escolhendo caminho, voltei e apareceu um
> inimigo do nada' — o Continuar roteia pro mapa SE há pendentes) =====

## L209-212 (em `hide`, junto a `gmA.player.maxHealth = 123`)

> GANHOS PERMANENTES da run (evento +vida máxima / +mana base) e a
> pontuação — bug Set/2026: 'acumulo mana ou vida máxima, saio e
> entro, os valores resetam'. Salva via checkpointRun (que SINCRONIZA
> — saveRun cru gravava o snapshot velho, o outro lado do bug).

## L233-235 (em `hide`, junto a `local gmJ = Game:new()`)

> ===== 7. PROC VISUAL fora do pipeline de carta (bug 'Aprendizado
> de Máquina não triga visualmente' — jokers de turn_start eram MUDOS;
> pushJokerProc sem sink agora dispara direto no JokerProcFx) =====

## L252-257 (em `hide`, junto a `local gmC = Game:new()`)

> ===== 8. CERIMONIA DO CASTELO esconde a MAO (pedido do dono Set/2026:
> "quando tiver na animacao de entrar no castelo, nao pode aparecer as
> cartas na mao"). A guarda em GameplayScene.draw usa a MESMA flag que o
> EnemyHud ja usava (WorldRoad.isEntering()); este check existe pra que
> ninguem remova o `if not entering` sem o teste gritar. Espionamos
> Card.draw e contamos as chamadas com e sem a cerimonia no ar. =====

## L265-267 (em `hide`, junto a `local noop = function() end`)

> Stubs COM draw: os do bloco 4 só tinham update/show/hide, então
> GameplayScene.draw() estourava e o pcall mascarava como "0 cartas" —
> o baseline passava a falhar e o check da cerimônia passava à toa.

