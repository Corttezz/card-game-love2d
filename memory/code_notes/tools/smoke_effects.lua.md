---
name: code_notes/tools/smoke_effects.lua
description: Comentários com decisão/regra/histórico colhidos de tools/smoke_effects.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/smoke_effects.lua`

Origem: `tools/smoke_effects.lua` em `7dbdb60d` (3 de 19 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-4 (junto a `local Player = require("src.entities.Player")`)

> tools/smoke_effects.lua
> Smoke test da Fase 2: strength_scaling, channel_orb/evoke_orb, poison DoT via onTurnEnd,
> gain_strength, apply_buff, exhaust tracking.
> Roda via: love . smoke_effects

## L45-47 (em `attackCard`, junto a `local g2 = makeMockGame()`)

> 2. strength_scaling é flag-only após o fix de double-application (Abril/2026):
> applyCardEffects não soma strength (Game:processCardInCombat já passa via statBonus).
> Antes desse fix, declarar strength_scaling causava aplicação dupla.

## L85 (em `multiCard`, junto a `local g7 = makeMockGame()`)

> 7. evoke_all_orbs evoca todos

