---
name: code_notes/tools/check_font_metrics.lua
description: Comentários com decisão/regra/histórico colhidos de tools/check_font_metrics.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/check_font_metrics.lua`

Origem: `tools/check_font_metrics.lua` em `7dbdb60d` (2 de 3 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-10 (junto a `local M = {}`)

> tools/check_font_metrics.lua
> Mede a fonte do projeto: altura REPORTADA vs altura DESENHADA.
>
> Existe porque a entrelinha do corpo de texto do evento sobrepunha as linhas
> em alemão e o palpite "multiplica por 1.1" não resolveu. Fonte pixel via TTF
> costuma reportar `getHeight()` menor que a caixa real dos glifos (acentos e
> descendentes ficam fora da métrica), e aí `printf` empilha linhas curtas
> demais. Medir a MANCHA DE PIXELS é o único jeito honesto de achar o fator.
>
> Roda: love . check_font_metrics [tamanhos separados por virgula]

## L14-15 (em `M`, junto a `local function inkBounds(font, txt, w)`)

> Desenha `txt` num canvas e devolve a primeira e a última linha de pixel
> efetivamente pintada.

