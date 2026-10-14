---
name: code_notes/src/ui/PixelIcons.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/PixelIcons.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/PixelIcons.lua`

Origem: `src/ui/PixelIcons.lua` em `7dbdb60d` (2 de 50 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-17 (junto a `local PixelIcons = {}`)

> src/ui/PixelIcons.lua
> Biblioteca de ~30 ícones 16×16 desenhados pixel-a-pixel como matrizes.
> Formato: cada ícone é tabela 2D {linha = {col1, col2, ...}} com valores:
> 0 = transparente
> 1..17 = índice em Palette.INDEXED (veja Palette.lua)
>
> Convenção de cores por função:
> 1  = VOID (outline escuro)
> 4  = BG_MID (outline soft / sombra metal)
> 7  = CYAN_PALE (metal claro / steel)
> 13  = YELLOW (dourado, magia, coroa)
> 14  = ORANGE (madeira, fogo quente)
> 15  = MAGENTA (sangue, energia rosa)
> 17  = WHITE (highlight)
>
> Para desenhar: use PixelCanvas.drawBitmap(PixelIcons.sword_short, ox, oy).
> Ou escalado 2x: PixelCanvas.drawBitmapScaled(PixelIcons.sword_short, ox, oy, 2).

## L819 (em `PixelIcons.check`, junto a `function PixelIcons.get(name)`)

> Retorna o ícone pedido, ou o ícone de fallback se não existir.

