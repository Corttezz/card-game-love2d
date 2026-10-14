---
name: code_notes/src/ui/GrimoirePage.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/GrimoirePage.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/GrimoirePage.lua`

Origem: `src/ui/GrimoirePage.lua` em `7dbdb60d` (1 de 9 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-9 (junto a `local Palette = require("src.ui.Palette")`)

> src/ui/GrimoirePage.lua
> Folha de grimório pintada em pixel (seleção de classe v4, Out/2026): papel
> em 4 tons com dither Bayer, borda rasgada coluna a coluna, beirada queimada
> e duas manchas de tinta velha. Gerada UMA vez por tamanho numa ImageData
> em meia resolução e desenhada ×2 com nearest — o grão do papel tem o mesmo
> tamanho de pixel do resto da UI, em qualquer proporção (o wear_overlay da
> carta é 2:3 fixo e esticá-lo deformava os rasgos).
>
> GrimoirePage.draw(x, y, w, h, seed)

