---
name: code_notes/src/ui/card/components/joker/JokerFooter.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/card/components/joker/JokerFooter.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/card/components/joker/JokerFooter.lua`

Origem: `src/ui/card/components/joker/JokerFooter.lua` em `7dbdb60d` (8 de 16 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-5 (junto a `local Palette          = require("src.ui.Palette")`)

> src/ui/card/components/joker/JokerFooter.lua
> Rodapé do joker v2 (Jul/2026, "mais trabalhado"): placa navy com bevel
> direcional ouro-tarot e uma CONSTELAÇÃO — sol, estrela e lua conectados
> por um fio pontilhado, com sombra projetada e faíscas entre eles.
> A v1 era um rectOutline uniforme (pillow) com símbolos flutuando.

## L76-77 (em `JokerFooter.draw`, junto a `local navyTop = Palette.lerp(Palette.TAROT_NAVY, Palette.TAROT_GOLD_DARK, 0.10)`)

> Fundo navy em DEGRADÊ contínuo (v3.4: o split 2-tons tinha emenda
> horizontal dura — mesma "reta" do rodapé standard).

## L85 (em `JokerFooter.draw`, junto a `for y = by + 1, by + bh - 2 do`)

> Grão do material (denso e muito sutil — matéria, não ruído)

## L97 (em `JokerFooter.draw`, junto a `local tex = BackgroundLoader.get("void")`)

> Textura "void" sobre o navy (v3.4: alpha 0.14→0.24)

## L107-108 (em `JokerFooter.draw`, junto a `PixelCanvas.hline(bx + 1, by - 1, bw - 2, Palette.TAROT_GOLD_DARK)`)

> v3: filete de ouro ACIMA da placa (a v1 tinha e ligava o rodapé à
> moldura; a v2 tirou e a placa ficou "solta" na base da carta).

## L111-113 (em `JokerFooter.draw`, junto a `local bronze = Palette.lerp(Palette.TAROT_GOLD_DARK, Palette.INK, 0.45)`)

> Bevel direcional ouro-tarot (era rectOutline uniforme = pillow).
> v3.2: linha interna de baixo era preta — vala entre placa e moldura;
> agora bronze-tarot (flush).

## L122-124 (em `JokerFooter.draw`, junto a `for y = by, by + bh - 1 do`)

> Desgaste sutil (v3.3, realista): lascas de 2px CONCENTRADAS nas
> bordas (onde a mão gasta), centro quase intocado — nada de
> pixel-confete solto (feedback do dono). Determinístico.

## L141 (em `JokerFooter.draw`, junto a `PixelCanvas.pixel(bx - 1, cy, Palette.TAROT_GOLD)`)

> Diamantes de engaste nas pontas (ligam a placa à moldura)

