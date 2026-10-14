---
name: code_notes/engine/Utils.lua
description: Comentários com decisão/regra/histórico colhidos de engine/Utils.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `engine/Utils.lua`

Origem: `engine/Utils.lua` em `7dbdb60d` (3 de 8 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-3 (junto a `local Utils = {}`)

> engine/Utils.lua
> Helpers genéricos portados/inspirados em balatro-source/functions/misc_functions.lua.
> Sem dependências do Balatro (G global, etc) — só Lua puro + LÖVE.

## L55-56 (em `Utils.darken_colour`, junto a `function Utils.pseudorandom_element(t)`)

> Pega elemento aleatório de array. Retorna nil se vazio.
> (Sem seed dedicado por enquanto — usa math.random global.)

## L62 (em `Utils.pseudorandom_element`, junto a `function Utils.now()`)

> Wall-clock seconds (substitui G.TIMERS.REAL do Balatro).

