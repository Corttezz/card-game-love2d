---
name: code_notes/tools/test_tooltip_order.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_tooltip_order.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_tooltip_order.lua`

Origem: `tools/test_tooltip_order.lua` em `7dbdb60d` (1 de 5 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-7 (junto a `local TK = require("tools.testkit")`)

> tools/test_tooltip_order.lua
> ORDEM DE DESENHO DA MÃO (dono, Out/2026: "o +COMBO da carta ao lado fica
> POR CIMA do tooltip da carta em hover"). O tooltip da carta em hover é o
> ÚLTIMO desenho da mão: depois dos selos +COMBO, da prévia de dano e dos
> toasts. Mede a ordem real no GameplayScene.draw instrumentando as funções.
>
> love . test_one test_tooltip_order

