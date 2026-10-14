---
name: code_notes/tools/screenshot_joker_manager.lua
description: Comentários com decisão/regra/histórico colhidos de tools/screenshot_joker_manager.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/screenshot_joker_manager.lua`

Origem: `tools/screenshot_joker_manager.lua` em `7dbdb60d` (2 de 3 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-6 (junto a `local M = {}`)

> tools/screenshot_joker_manager.lua
> Valida o Gerenciador de Coringas alinhado ao DeckViewer/Coleção
> (feedback Jul/2026: "não está parecido com o deck e a coleção").
> joker_manager.png       — grid parado (ativos + bancada)
> joker_manager_hover.png — hover num coringa da bancada
> love . screenshot_joker_manager

## L52-53 (em `jokerIds`, junto a `if #screen._cardRects >= 2 then`)

> hover num card da 1ª FILEIRA (posiciona o mouse de verdade):
> valida o tooltip ABAIXO da carta (feedback: acima cobria o topo)

