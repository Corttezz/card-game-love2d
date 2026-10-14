---
name: code_notes/tools/test_hand_deal.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_hand_deal.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_hand_deal.lua`

Origem: `tools/test_hand_deal.lua` em `7dbdb60d` (9 de 19 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-15 (junto a `local TK = require("tools.testkit")`)

> tools/test_hand_deal.lua
> TRAVA da cortina da mão + distribuição das cartas (src/ui/HandDeal) e do
> jeito que o GameplayScene a usa.
>
> Bug do dono (Out/2026): a mão, os botões, os coringas e o HUD apareciam
> no meio da porta do castelo e da entrada do chefe. Regra fixada:
> * ZERO carta visível da viagem/porta até o FIM da cinemática;
> * depois as cartas são DADAS uma a uma (escalonadas), da pilha do deck;
> * botões/coringas/prévia e (no salão) o HUD só DEPOIS da última carta;
> * na estrada: inimigo chega → cartas; o HUD do herói fica (é o status
> dele, não cutscene);
> * chefe SEM roteiro próprio ganha a entrada genérica (salão vazio →
> impacto → nome) — nunca mais "luta como antes" com a mão na tela.
>
> love . test_one test_hand_deal

## L97 (em `enemy`, junto a `HandDeal.update(0, g)`)

> carta jogada no meio da distribuição não quebra nada

## L103-104 (em `enemy`, junto a `local gd = { hand = { fakeCard() }, enemy = { isAlive = function() return false end } }`)

> inimigo morto atrás da cortina (morte do chefe): MESA FECHADA — nada
> de carta nem botão por cima do corpo; a próxima cortina reabre

## L212-215 (em `run.currentNode`, junto a `t:eq("salão aberto: mundo-só = salão", GS.worldOnlyMode(), "hall")`)

> ===== 2b. depois do chefe: cash out e espólios DENTRO do salão =====
> (dono, Out/2026): o "só o mundo" atrás das telas de espólios é o
> salão com o cadáver enquanto o nó for o do chefe; a estrada só volta
> quando a encruzilhada troca o nó.

## L224-228 (em `run.currentNode`, junto a `local WorldRoad = require("src.ui.WorldRoad")`)

> A ENCRUZILHADA abre ANTES de o nó trocar (showMapSelection avança o
> ato e chama showFork; o nó só muda quando o jogador escolhe). Com o
> fork ativo o mundo-só é a ESTRADA — é lá que os marcos são desenhados.
> Regressão do dono (13/Out): preso no salão do ato 2 com o cadáver do
> chefe do ato 1 e o fork invisível.

## L305-308 (em `run4.currentNode`, junto a `local g5 = TK.newRunGame("warrior")`)

> ===== 6. run NOVA: a 1ª luta CHEGA pela estrada (dono, 13/Out) =====
> "quando clica em Jogar a tela já é o inimigo com as cartas, sem
> animação": startGame pede requestArrival e o 1º andar viaja como
> qualquer outro; Continuar (resumeWorld) nunca repete a chegada.

## L332 (em `run5.currentNode`, junto a `local g6 = TK.newRunGame("warrior")`)

> Continuar: sem pedido, ancorado, nada viaja

## L343 (em `run6.currentNode`, junto a `local g7 = TK.newRunGame("warrior")`)

> sem pedido (testes/tools): como sempre, nasce pronta

## L352-353 (em `g7.runManager.currentRun.currentNode`, junto a `if _G.EventManager and _G.EventManager.clear then _G.EventManager.clear() end`)

> higiene: cada cena montada deixa ~8 eventos pendentes pra sempre no
> EventManager (quicada/distribuição); não vazar pras suítes seguintes

