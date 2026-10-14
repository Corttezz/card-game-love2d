---
name: code_notes/tools/smoke_exhaust_pool.lua
description: Comentários com decisão/regra/histórico colhidos de tools/smoke_exhaust_pool.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/smoke_exhaust_pool.lua`

Origem: `tools/smoke_exhaust_pool.lua` em `7dbdb60d` (3 de 6 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-5 (junto a `local TK = require("tools.testkit")`)

> tools/smoke_exhaust_pool.lua — regressao da anomalia "cartas sumiram"
> (autoplay v3): carta EXHAUST jogada apos o inimigo morrer na mesma leva
> caia no guard "batendo no cadaver" sem bookkeeping — sumia de todas as
> pilhas e escapava da remocao permanente da run.
> Roda isolado: lovec . test_one smoke_exhaust_pool

## L34 (em `body`, junto a `local guard = 0`)

> garante as 2 na mão (innate já promove; se faltar, compra)

## L83 (em `M.run`, junto a `local ok, result = pcall(body)`)

> pcall: erro Lua NUNCA pode cair no error screen do LÖVE (trava headless)

