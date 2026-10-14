---
name: code_notes/tools/smoke_upgrades.lua
description: Comentários com decisão/regra/histórico colhidos de tools/smoke_upgrades.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/smoke_upgrades.lua`

Origem: `tools/smoke_upgrades.lua` em `7dbdb60d` (2 de 12 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-3 (junto a `local RunManager = require("src.systems.RunManager")`)

> tools/smoke_upgrades.lua
> Valida pipeline de upgrades + editions + seals (Fase 3 do refactor Balatro).
> love . smoke_upgrades

## L63-65 (em `dummyContext`, junto a `g.enemy.health = 999`)

> Testa que applyEditionToValue ta aplicando.
> (não exposta, mas processCardInCombat usa internamente.)
> Validacao indireta: uma carta foil (+5 flat) com base 10 deveria virar >= 15.

