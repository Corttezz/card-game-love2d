---
name: code_notes/src/ui/card/components/joker/JokerHeader.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/card/components/joker/JokerHeader.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/card/components/joker/JokerHeader.lua`

Origem: `src/ui/card/components/joker/JokerHeader.lua` em `7dbdb60d` (4 de 16 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-7 (junto a `local Palette     = require("src.ui.Palette")`)

> src/ui/card/components/joker/JokerHeader.lua
> Banner ornamentado do nome em tema TAROT (navy + dourado).
> Compartilha o mesmo padrão de raridade do CardHeader, mas com paleta diferente:
> Fundo TAROT_NAVY em vez de INK
> Filete TAROT_GOLD em vez de AGED_GOLD
> Texto TAROT_CREAM
> Ornamentos por raridade (diamond / leaf / ruby / medallion)

## L17-20 (em `JokerHeader`, junto a `local _bannerCache  = {}`)

> Cache de fundos PNG de banner joker por raridade.
> Paths: assets/sprites/ui/banner_joker_<rarity>.png (fallback: banner_<rarity>.png)
> Retorna { image, quad, srcW, srcH } com bottom 4 rows recortados (mesma razão
> do CardHeader: a borda inferior do PNG cria "shelf" feio sob o art slot).

## L263-264 (em `JokerHeader.draw`, junto a `local utf8 = require("utf8")`)

> ===== TEXTO =====
> Tenta tamanhos 10 → 9 → 8 → 7 antes de truncar (preserva nome quando possivel).

## L303 (em `JokerHeader.draw`, junto a `love.graphics.setColor(Palette.TAROT_CREAM)`)

> Texto sempre cream (mantém legibilidade — raridade muda só os ornamentos)

