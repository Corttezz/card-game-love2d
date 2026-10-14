---
name: code_notes/src/ui/PixelBackground.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/PixelBackground.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/PixelBackground.lua`

Origem: `src/ui/PixelBackground.lua` em `7dbdb60d` (6 de 16 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-9 (junto a `local Palette     = require("src.ui.Palette")`)

> src/ui/PixelBackground.lua
> Gera backgrounds tileáveis/procedurais em canvases pixel-perfect.
> Cacheados por (nome, w, h) — chamar uma vez e reutilizar.
>
> Presets:
> casinoTable(w, h) — verde escuro de mesa de cassino com textura
> voidStars(w, h)   — fundo escuro com estrelas piscantes
> dungeon(w, h)     — pedra tileada com runas
> parchment(w, h)   — bege com manchas (para telas de menu)

## L29-31 (em `seedRand`, junto a `function PixelBackground.casinoTable(w, h)`)

> =========================================================================
> CASINO TABLE
> =========================================================================

## L41 (em `PixelBackground.casinoTable`, junto a `for yy = 0, h - 1, 2 do`)

> Textura sutil de feltro via dither

## L62-64 (em `PixelBackground.casinoTable`, junto a `function PixelBackground.voidStars(w, h)`)

> =========================================================================
> VOID STARS
> =========================================================================

## L110-112 (em `PixelBackground.voidStars`, junto a `function PixelBackground.dungeon(w, h)`)

> =========================================================================
> DUNGEON STONES
> =========================================================================

## L146-148 (em `PixelBackground.dungeon`, junto a `function PixelBackground.parchment(w, h)`)

> =========================================================================
> PARCHMENT
> =========================================================================

