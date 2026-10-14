---
name: code_notes/tools/smoke_combos.lua
description: Comentários com decisão/regra/histórico colhidos de tools/smoke_combos.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/smoke_combos.lua`

Origem: `tools/smoke_combos.lua` em `7dbdb60d` (4 de 10 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-4 (junto a `local TagSystem = require("src.systems.TagSystem")`)

> tools/smoke_combos.lua
> Smoke dos COMBOS SIMPLES (Out/2026): Saraivada (ataques), Muralha
> (defesas), Par (copias da mesma carta) e os coringas de combo.
> Roda via: love . smoke_combos

## L39 (em `solo`, junto a `local atks = {}`)

> 2. Saraivada: 2o ataque +step, 3o +2*step, teto em cap

## L77 (em `after`, junto a `local game = { jokerSlots = { { effects = {`)

> 6. coringa de combo dobra a regra (e so ela)

## L94 (em `five`, junto a `local g8 = { enemy = { addStatusEffect = function() error("nao devia") end } }`)

> 8. sem efeito de fim de jogada (eventos sairam com as regras por tag)

