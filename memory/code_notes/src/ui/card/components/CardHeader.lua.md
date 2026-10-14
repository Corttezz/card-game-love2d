---
name: code_notes/src/ui/card/components/CardHeader.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/card/components/CardHeader.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/card/components/CardHeader.lua`

Origem: `src/ui/card/components/CardHeader.lua` em `7dbdb60d` (10 de 56 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-10 (junto a `local Palette     = require("src.ui.Palette")`)

> src/ui/card/components/CardHeader.lua
> Banner ornamentado do nome da carta. Estilo varia por raridade:
> common    → ouro envelhecido + diamante simples
> uncommon  → ouro + acento musgo, gemas verdes facetadas, vinheta inferior
> rare      → ouro + sangue, rubis 5×3 com brilho, coroa de gemas no topo
> legendary → dourado claro + escuro (filete duplo), medalhões 5×5, sparkles
> animados-friendly + curls laterais que vazam pra fora do banner
>
> A altura do banner se adapta ao nome (HEIGHT_SINGLE ou HEIGHT_WRAP).
> CardFrame chama computeHeight() pra saber o top do art slot.

## L19-22 (em `CardHeader`, junto a `local _bannerCache  = {}`)

> Cache de fundos de banner por raridade (PNG gerados via PixelLab).
> Paths: assets/sprites/ui/banner_<rarity>.png
> Retorna { image, quad } — quad recorta a borda inferior do PNG (4 linhas) que
> aparecia como "shelf" abaixo do banner colidindo com o art slot.

## L40-41 (em `CardHeader._getBannerBg`, junto a `local iw, ih = img:getWidth(), img:getHeight()`)

> Crop: pega rows 0..28 (drop bottom 4 rows que são a borda inferior pesada).
> Isso elimina a "prateleira" gerada pela borda decorativa do PNG.

## L50-52 (em `entry`, junto a `CardHeader.HEIGHT_SINGLE = 18`)

> Mantido em 18/24 (original) pra não comer espaço do art slot.
> O PNG do PixelLab é 64×32 — sofre compressão vertical (~0.56x) mas a borda
> ornamental sobrevive bem em nearest-filter.

## L78-80 (em `CardHeader.computeHeight`, junto a `local function styleFor(rarity)`)

> ===== Paletas de raridade =====
> outerColor: filete principal | innerHi/innerLo: relevo top/bottom
> accent: cor secundária dos ornamentos | gem: cor da gema central

## L315-317 (em `CardHeader.draw`, junto a `local bgEntry = CardHeader._getBannerBg(rarity)`)

> ===== ESTRUTURA DO BANNER (minimal — prioriza legibilidade) =====
> Será substituída por PNG de fundo por raridade (gerado via PixelLab).
> Se o PNG não existir, cai de volta pro procedural simples.

## L326-327 (em `CardHeader.draw`, junto a `else`)

> NÃO desenha sombra externa nem ornamentos procedurais por cima
> (PNG já tem borda + sombra próprias).

## L431-433 (em `lines`, junto a `local opticalOffset = singleLine and 0 or -2`)

> Offset -2px só pra multi-linha: o PNG do PixelLab tem borda inferior
> visualmente pesada que empurra o centro óptico pra cima. Pra single-line
> o centro matemático já fica certo (mover pra cima deixa muito alto).

## L437-438 (em `lines`, junto a `local textHi = Palette.AGED_GOLD_LIGHT`)

> Texto sempre dourado clássico (independente de raridade — mantém legibilidade
> consistente; a raridade muda só os ornamentos do banner).

## L442-444 (em `lines`, junto a `for i, line in ipairs(lines) do`)

> Usa printf com align="center" pra centralizar consistentemente sem
> arredondamento manual (math.floor((bw-tw)/2) lean pra esquerda quando
> tw é ímpar, gerando bias visual de 1px).

