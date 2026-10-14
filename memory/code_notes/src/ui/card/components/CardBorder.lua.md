---
name: code_notes/src/ui/card/components/CardBorder.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/card/components/CardBorder.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/card/components/CardBorder.lua`

Origem: `src/ui/card/components/CardBorder.lua` em `7dbdb60d` (6 de 50 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-13 (junto a `local Palette     = require("src.ui.Palette")`)

> src/ui/card/components/CardBorder.lua
> Moldura pixel art densa com ASIMETRIA e DESGASTE orgânico.
> Cada carta tem variação única (seed via card id) evitando padrão uniforme.
>
> Camadas:
> 1) Outline INK 1px
> 2) Banda sépia 3 tons
> 3) Filete AGED_GOLD
> 4) Knotwork seccionado (com gaps deliberados — "desgastado")
> 5) Bolts irregulares nos meios (1-2 por lado, não 1 fixo)
> 6) Scrollwork nos cantos
> 7) Aging agressivo: cracks, chunks, tarnish, faded spots (asymétrico)
> 8) Rare/legendary: detalhes extras

## L159-165 (em `drawDamage`, junto a `local function drawCorner(ox, oy, dx, dy, size, mainColor, highlightColor, gem, sparkle)`)

> ===== Rarity corner brackets (substitui filete colorido full-perimeter) =====
> Desenha 4 brackets em L nos cantos do art slot (offset interno 9,9).
> Complexidade escala por raridade:
> uncommon  → L simples 5×5 verde MOSS
> rare      → L 7×7 BLOOD + curl pixel + gem central
> legendary → L 8×8 AGED_GOLD c/ borda interna AGED_GOLD_LIGHT + gem dupla + 2 sparkles
> common/basic não desenha (cartas limpas).

## L167-168 (em `drawCorner`, junto a `for i = 0, size - 1 do`)

> L-bracket: arm horizontal e vertical de comprimento `size`, com outline INK
> Arm horizontal (size px)

## L243-244 (em `CardBorder.draw`, junto a `PixelCanvas.rectOutline(0, 0, w, h, Palette.INK)`)

> CAMADAS BASE (mais espessas — borda 8px total com 6 filetes)
> 1) Outline externo INK

## L320 (em `CardBorder.draw`, junto a `if sprites.wear_overlay then`)

> WEAR OVERLAY (PNG multiply bem sutil cobrindo toda a carta — dá aparência antiga)

## L329-331 (em `CardBorder.draw`, junto a `drawRarityCorners(w, h, rarity, seed)`)

> RARITY: substitui o filete interno por CORNER-PIECES ornamentais.
> Cada raridade tem brackets em L nos 4 cantos com complexidade crescente.
> (Não desenha nada para common/basic — cartas comuns ficam clean.)

