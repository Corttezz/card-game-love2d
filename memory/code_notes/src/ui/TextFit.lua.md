---
name: code_notes/src/ui/TextFit.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/TextFit.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/TextFit.lua`

Origem: `src/ui/TextFit.lua` em `7dbdb60d` (3 de 4 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-15 (junto a `local FontManager = require("src.ui.FontManager")`)

> src/ui/TextFit.lua
> Helper ÚNICO de "texto que cabe" (design system Jul/2026). Toda string de
> UI dentro de um retângulo de largura fixa passa por aqui — a mesma receita
> do Button e da HintBar, exportada pra labels soltos:
> 1) tenta o tamanho pedido; desce de 1 em 1 até minSize;
> 2) se nem no mínimo couber, TRUNCA com "..." (UTF-8 safe).
> Contrato: o retorno NUNCA é mais largo que maxW. Chega de texto vazando
> por idioma (playtest Jul/2026 — DE/FR estouravam labels de coluna fixa).
>
> Uso:
> local font, text = TextFit.fit(label, 12, colW)
> love.graphics.setFont(font); love.graphics.print(text, x, y)
> ou direto:
> TextFit.print(label, x, y, { size = 12, maxW = colW })
> TextFit.print(label, x, y, { size = 12, maxW = colW, align = "center" })

## L38 (em `ellipsize`, junto a `function TextFit.fit(text, desiredSize, maxW, minSize)`)

> Retorna (font, drawText, size). drawText SEMPRE cabe em maxW.

## L55-58 (em `TextFit.fit`, junto a `function TextFit.print(text, x, y, opts)`)

> Print protegido: seta a fonte fitted e imprime. opts:
> size (default 12), maxW (obrigatório pra proteger), minSize,
> align = "left" (default) | "center" | "right"  — relativo a x..x+maxW
> shadow = {r,g,b,a} opcional (imprime 1px offset antes)

