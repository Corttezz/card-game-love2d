---
name: code_notes/tools/smoke_map.lua
description: Comentários com decisão/regra/histórico colhidos de tools/smoke_map.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/smoke_map.lua`

Origem: `tools/smoke_map.lua` em `7dbdb60d` (3 de 9 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-2 (junto a `local MapManager = require("src.systems.MapManager")`)

> tools/smoke_map.lua
> Smoke test da Fase 4: MapManager gera nodes com tipos esperados.

## L28 (em `check`, junto a `local bossNodes = MapManager.generate(MapManager.FLOORS_PER_ACT, 1, 3)`)

> 3. Floor final do ato sempre gera BOSS (apenas 1 no)

## L51-52 (em `seen`, junto a `check("BATTLE aparece em maioria das rolagens", seen.battle and seen.battle >= 60)`)

> Cada call gera ate 3 tipos distintos, entao BATTLE aparece no maximo 1x por call.
> Com weight 55-70, deve aparecer em pelo menos 60/100 calls.

