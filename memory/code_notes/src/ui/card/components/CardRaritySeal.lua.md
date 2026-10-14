---
name: code_notes/src/ui/card/components/CardRaritySeal.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/card/components/CardRaritySeal.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/card/components/CardRaritySeal.lua`

Origem: `src/ui/card/components/CardRaritySeal.lua` em `7dbdb60d` (1 de 8 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-6 (junto a `local Palette     = require("src.ui.Palette")`)

> src/ui/card/components/CardRaritySeal.lua
> Selo circular de raridade no canto superior direito (11px).
> Renderiza PNG do PixelLab (assets/sprites/ui/seal_<rarity>.png) quando disponível;
> fallback procedural simples (disco + cor + halo lendário).
>
> API: CardRaritySeal.draw(w, rarity)

