---
name: code_notes/tools/test_forge.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_forge.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_forge.lua`

Origem: `tools/test_forge.lua` em `7dbdb60d` (8 de 21 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-13 (junto a `local TK = require("tools.testkit")`)

> tools/test_forge.lua
> Forja/upgrade: getForgeGains (regra por cenário), applyUpgradesToInstance
> (aritmética +ATQ/+DEF/+efeito por nível), upgradeCard (cap infinito),
> getPaidForgeCost (custo crescente 1.35^n, cap 60), canUpgrade.
>
> + CÓPIAS REPETIDAS (Set/2026): o deck pode ter N cópias do MESMO id e cada
> uma é uma carta própria. Cobre as duas metades do defeito reportado pelo
> dono ("se eu tiver duas cartas iguais, na tela de forjar só aparece uma"):
> (a) DADOS  — forjar/remover/duplicar A CÓPIA escolhida não toca nas outras
> (RunManager: upgradeCardAt / removeCardAt / duplicateCardAt);
> (b) TELA   — o picker da bigorna (RestScreen) lista UMA ENTRADA POR CÓPIA.
> Conferido em RunManager.lua + Config.Offers + components/RestScreen.lua.
> love . test_forge

## L84-89 (em `M.run`, junto a `local rc = RunManager:new()`)

> =====================================================================
> CÓPIAS REPETIDAS DO MESMO ID
> =====================================================================
> Regressão: enquanto o nível morava em currentRun.upgraded[cardId],
> forjar uma "Golpe" subia TODAS as "Golpe" do deck — e por isso o picker
> deduplicava a grade. Reverter para o mapa por id derruba os eq() abaixo.

## L93-94 (em `M.run`, junto a `rc:addCardToDeck("warrior_strike")`)

> Starter do guerreiro = warrior_strike + warrior_defend. Mais duas
> cópias de warrior_strike: três no total (índices 1, 3 e 4).

## L120-121 (em `lvls`, junto a `local newIdx = rc:duplicateCardAt(3)`)

> DUPLICAR a cópia forjada entrega uma cópia NO MESMO nível, e a original
> segue sozinha (forjar a nova não mexe na velha).

## L137-138 (em `lvls`, junto a `rc:saveRun()`)

> SAVE/LOAD: o nível por cópia viaja no save (é campo do item de
> currentDeck, serializado junto com edition/seal).

## L161-165 (em `loadedLvls`, junto a `local game = TK.newRunGame("warrior")`)

> =====================================================================
> A GRADE DA BIGORNA MOSTRA TODAS AS CÓPIAS
> =====================================================================
> É a metade visível do defeito: com o dedupe por id, um deck de 4 cartas
> com 3 "Golpe" rendia 2 entradas na tela.

## L179-180 (em `loadedLvls`, junto a `local seenIdx = {}`)

> Cada entrada aponta pra um índice DIFERENTE do deck (identidade da
> cópia é o índice, nunca o id).

## L189 (em `seenIdx`, junto a `local picked = nil`)

> Forjar pela TELA (o caminho do jogador) mexe só na cópia clicada.

