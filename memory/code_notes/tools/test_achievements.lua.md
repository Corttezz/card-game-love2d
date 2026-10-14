---
name: code_notes/tools/test_achievements.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_achievements.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_achievements.lua`

Origem: `tools/test_achievements.lua` em `7dbdb60d` (4 de 24 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-10 (junto a `local TK = require("tools.testkit")`)

> tools/test_achievements.lua
> Conquistas: CADA gatilho dispara (e nao dispara fora da condicao),
> persistencia, API names da Steam unicos e CONGELADOS, emblemas existentes
> (liberado + bloqueado, jogo + Steam 256x256), chaves de UI nos 5 idiomas,
> ponte Steam (no-op avisado / backend fake) e a geometria da galeria.
>
> love . test_one test_achievements
>
> Sandbox: qualquer arg de tool seta HEADLESS_TOOL -> ProfileStats.flush() e
> no-op. Mexemos no perfil EM MEMORIA e zeramos entre casos.

## L16-17 (em `M`, junto a `local FROZEN = {`)

> API names publicados NAO podem mudar (a Steam nao renomeia). Conquista nova
> entra aqui; remover/renomear uma daqui e decisao consciente.

## L33 (em `FROZEN`, junto a `ciclo_3 = "ACH_CICLO_3", ciclo_5 = "ACH_CICLO_5", ciclo_10 = "ACH_CICLO_10",`)

> Out/2026: pos-jogo (ciclos do endless + Selos do Grimorio)

## L242 (em `g.jokerSlots`, junto a `AS.onCardsPlayed(g, { allSelectedCards = {}, activeCombos = { 1, 2 } })`)

> combos simples (Out/2026): sao 3 regras — Tinta Viva = as 3 na jogada

