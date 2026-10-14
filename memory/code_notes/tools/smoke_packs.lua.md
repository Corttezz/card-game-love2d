---
name: code_notes/tools/smoke_packs.lua
description: Comentários com decisão/regra/histórico colhidos de tools/smoke_packs.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/smoke_packs.lua`

Origem: `tools/smoke_packs.lua` em `7dbdb60d` (4 de 11 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-3 (junto a `local BoosterPackSystem = require("src.systems.BoosterPackSystem")`)

> tools/smoke_packs.lua
> Valida BoosterPackSystem + persistência de edition/seal por cópia.
> love . smoke_packs

## L39-40 (em `pack`, junto a `math.randomseed(42); love.math.setRandomSeed(42)`)

> Edition + seal probabilísticos (Standard só).
> Roda muitos packs e conta — deve haver alguma carta com edition.

## L87-91 (em `pack`, junto a `local BPS = require("src.systems.BoosterPackSystem")`)

> ===== ESPECTRAL: piso de raridade (decisao do dono, Set/2026) =====
> Ele da 2 cartas onde Arcano/Celestial dao 3, pelo mesmo $4, e e o mais
> raro de aparecer. A contrapartida e NENHUMA COMUM. Sem esta trava, uma
> refatoracao futura no gerador o devolve a condicao de "pacote pior",
> que e um defeito que so aparece pra quem faz a conta.

## L109-110 (em `pesosA3`, junto a `local comunsArcana = 0`)

> E o irmao de 3 cartas CONTINUA podendo trazer comum: o piso e do
> Espectral, nao do gerador inteiro.

