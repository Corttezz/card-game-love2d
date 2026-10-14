---
name: code_notes/tools/preview_card_live.lua
description: Comentários com decisão/regra/histórico colhidos de tools/preview_card_live.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/preview_card_live.lua`

Origem: `tools/preview_card_live.lua` em `7dbdb60d` (2 de 11 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-4 (junto a `local M = {}`)

> tools/preview_card_live.lua
> Renderiza cartas em cenários que exercitam: sombra direcional, perspective warp,
> wobble, holo composition.
> Saída: ~/.local/share/love/card-game/preview_card_live.png

## L49-50 (em `xs`, junto a `local cardY2 = h * 0.18`)

> ===== LINHA 2: warp simulando mouse em 5 cantos diferentes =====
> top-left, top-right, center, bottom-left, bottom-right

