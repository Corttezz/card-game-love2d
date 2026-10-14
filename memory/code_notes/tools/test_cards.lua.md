---
name: code_notes/tools/test_cards.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_cards.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_cards.lua`

Origem: `tools/test_cards.lua` em `7dbdb60d` (3 de 15 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-6 (junto a `local TK = require("tools.testkit")`)

> tools/test_cards.lua
> Catálogo + registry + deck: integridade do catálogo (toda carta instancia),
> createCardInstance (tipos, flags exhaust/innate/retain), rollRarity
> (determinístico nos extremos + distribuição), pools por classe, starter decks.
> Conferido em CardDatabase.lua, CardRegistry.lua, DeckManager.lua.
> love . test_cards

## L34 (em `M.run`, junto a `local ok = pcall(function() return db:createCardInstance(cd) end)`)

> Toda carta precisa instanciar sem erro (renderiza moldura procedural).

## L54 (em `M.run`, junto a `local strikeInst = db:createCardInstance(db:getCard("warrior_strike"))`)

> tags sempre presentes (derivadas se vazio)

