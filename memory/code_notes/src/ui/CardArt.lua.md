---
name: code_notes/src/ui/CardArt.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/CardArt.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/CardArt.lua`

Origem: `src/ui/CardArt.lua` em `7dbdb60d` (4 de 23 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-11 (junto a `local atlas = require("src.data.card_art")`)

> src/ui/CardArt.lua
> Lookup de arte por carta (com fallback derivado).
> Recebe `card` (instância ou dados-raw) e retorna tabela normalizada:
> { icon, bg, accent (color table), effect, decoration, artScale, artOffsetY }
>
> artScale:
> nil    → cover-fit padrão (preenche o slot, scale inteiro via CardArtSlot)
> <num>  → scale fixo (ex: 1 = ícone nativo sem zoom, 1.5 = meio-zoom, 2 = igual cover)
> artOffsetY:
> <num>  → empurra o ícone pra cima (-) ou pra baixo (+), em pixels do canvas (96×144).
> útil pra cartas onde o subject do sprite não fica no centro vertical.

## L20-24 (em `CardArt`, junto a `local warnedMissing = {}`)

> Cartas sem entrada no atlas caem num fallback por (tipo, classe) — e TODAS as
> cartas do mesmo tipo passam a dividir o MESMO ícone. Foi exatamente assim que
> Adrenalina virou a Poção de Cura (2026-09). O fallback continua existindo pra
> não quebrar o render, mas avisa alto: arte repetida é bug, não estilo.
> `tools/validate_cards.lua` transforma isso em falha de suite.

## L51-55 (em `RARITY_EFFECT`, junto a `local MID = 1.4`)

> Scale padrão por ícone quando a entrada do atlas não especifica `artScale`.
> Armas + fogo: ausentes (=nil) → cover-fit (scale 2, preenchem o slot).
> Resto: scale 1.4 (~90×90 em slot 86×106 — preenche quase tudo com leve ar).
> Fracional só funciona pra PNG; matriz 16×16 cairia pra 1 (integer), mas
> todos os ícones listados aqui têm PNG correspondente em assets/sprites/icons.

## L71-72 (em `ICON_DEFAULT_SCALE`, junto a `}`)

> Fogo e armas ficam AUSENTES de propósito → cover-fit padrão (scale 2):
> flame, fireball, sword_short, sword_great, dagger, axe, bolt

