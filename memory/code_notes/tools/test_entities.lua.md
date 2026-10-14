---
name: code_notes/tools/test_entities.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_entities.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_entities.lua`

Origem: `tools/test_entities.lua` em `7dbdb60d` (3 de 30 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-5 (junto a `local TK = require("tools.testkit")`)

> tools/test_entities.lua
> Testes unitários de Player e Enemy: dano/armadura, mana, buffs, orbs,
> status effects (poison/weak/vulnerable), fúria, intents.
> Números conferidos em src/entities/Player.lua e src/entities/Enemy.lua.
> love . test_entities

## L172 (em `M.run`, junto a `e = Enemy:new(100, 8); e.armor = 2`)

> poison IGNORA armadura (Out/2026, padrao StS — Enemy:_applyDot)

## L185 (em `M.run`, junto a `e = Enemy:new(100, 8)`)

> rollIntent sempre produz um intent válido

