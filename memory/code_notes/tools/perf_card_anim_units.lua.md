---
name: code_notes/tools/perf_card_anim_units.lua
description: Comentários com decisão/regra/histórico colhidos de tools/perf_card_anim_units.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/perf_card_anim_units.lua`

Origem: `tools/perf_card_anim_units.lua` em `7dbdb60d` (1 de 5 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-6 (junto a `local M = {}`)

> tools/perf_card_anim_units.lua
> RÉGUA do custo unitário das peças da animação de carta (Out/2026, carta
> visível = viva): decodificação de um PNG de frame, render estático pelas
> camadas, render direto (carta inteira) e composição de um frame. São estes
> números que dimensionam BUILD_PER_FRAME/BUILD_BUDGET_MS no CardFrame.
> Não é teste (não falha): love . test_one perf_card_anim_units

