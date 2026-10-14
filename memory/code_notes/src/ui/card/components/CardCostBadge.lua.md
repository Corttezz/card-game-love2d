---
name: code_notes/src/ui/card/components/CardCostBadge.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/card/components/CardCostBadge.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/card/components/CardCostBadge.lua`

Origem: `src/ui/card/components/CardCostBadge.lua` em `7dbdb60d` (5 de 16 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-15 (junto a `local Palette     = require("src.ui.Palette")`)

> src/ui/card/components/CardCostBadge.lua
> Badge de custo de mana no canto superior esquerdo: GEMA DE MANA lapidada
> (losango facetado azul-arcano com engaste dourado), número em bone white
> contornado em tinta.
>
> Redesign Jul/2026: o disco aço 11×11 era ilegível e "morto" — a gema usa o
> MESMO azul do ManaOrb do HUD (Palette.MANA*, identidade única de mana no
> jogo) e o idioma de joalheria dos banners (facetas + engaste AGED_GOLD,
> como os rubis/medalhões do CardHeader). Pixel colocado à mão: a este
> tamanho (13px), PNG rebaixado vira borrão — procedural nítido ganha.
>
> Geometria: gema em x∈[1,13] + engastes em x=0/x=14 — o banner do nome
> começa em x=15 (CardHeader bx), então nada colide.
>
> API: CardCostBadge.draw(cost)

## L25-27 (em `CardCostBadge`, junto a `local HW = { 1, 2, 3, 4, 5, 6, 6, 6, 5, 4, 3, 2, 1 }`)

> Meia-largura por linha (13 linhas): losango "cushion cut" — pontas de 3px
> (1px fica fino demais em outline) e cintura cheia de 13px nas 3 linhas
> centrais, onde mora o número.

## L69-70 (em `CardCostBadge.draw`, junto a `PixelCanvas.pixel(cx,     oy - 1,    Palette.AGED_GOLD_LIGHT) -- norte`)

> Engaste dourado nos 4 pontos do losango (garras de joalheiro — liga a
> gema ao ouro envelhecido da moldura/banners).

## L76-77 (em `CardCostBadge.draw`, junto a `local font = PixelFont.get(8)`)

> Número do custo: bone white com outline INK 4-direções (legível sobre
> qualquer faceta da gema).

## L83-85 (em `CardCostBadge.draw`, junto a `local ty = oy + 1`)

> oy+1 (era oy+3): a fonte default do LÖVE imprime o dígito ~2px abaixo
> do y do print (folga de ascender) — com oy+3 o número caía visivelmente
> abaixo do centro da gema (feedback do dono, Jul/2026).

