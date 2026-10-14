---
name: code_notes/src/ui/IconLoader.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/IconLoader.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/IconLoader.lua`

Origem: `src/ui/IconLoader.lua` em `7dbdb60d` (2 de 7 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-11 (junto a `local PixelIcons  = require("src.ui.PixelIcons")`)

> src/ui/IconLoader.lua
> Resolve um nome de ícone para um "handle" desenhável.
> Prefere PNGs em assets/sprites/icons/<name>.png (alta qualidade via pixel-mcp).
> Fallback: matrizes em PixelIcons.lua (arte base feita a mão).
>
> Handle retornado:
> {
> kind = "image" | "matrix",
> draw = function(x, y, scale?) -- desenha o ícone em (x, y) com escala opcional
> size = { w, h }               -- dimensões naturais (antes da escala)
> }

## L73-77 (em `handleCache`, junto a `function IconLoader.computeScale(iconH, targetSize)`)

> Calcula o scale pra desenhar um ícone `iconH` px de altura cabendo em `targetSize` px.
> Se source é menor/igual ao target: usa inteiro pra manter pixel art sharp.
> Se source é maior: scale fracional (nearest filter mantém qualidade).
> PNGs do projeto são tipicamente 64×64; a maioria dos targets é < 64, então cai no
> branch fracional. Matrix icons são 16×16 e ganham scale inteiro.

