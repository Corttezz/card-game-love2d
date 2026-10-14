---
name: code_notes/tools/screenshot_uiscale.lua
description: Comentários com decisão/regra/histórico colhidos de tools/screenshot_uiscale.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/screenshot_uiscale.lua`

Origem: `tools/screenshot_uiscale.lua` em `7dbdb60d` (2 de 4 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-10 (junto a `local M = {}`)

> tools/screenshot_uiscale.lua
> Capturas da ESCALA DE UI (src/ui/UiScale.lua) em vários tamanhos, num só
> processo, com a janela FALSIFICADA (getWidth/getHeight) e render em
> canvas — sem love.window.setMode (repetido dentro de tool trava).
>
> love . test_one screenshot_uiscale             → pt_BR, todas as telas, 5 tamanhos
> love . test_one screenshot_uiscale de          → outro idioma
> love . test_one screenshot_uiscale pt_BR:shop  → só uma tela
>
> Saída: uiscale_<tela>_<W>x<H>_<loc>.png no save dir.

## L88-89 (em `add`, junto a `_G.openScribeDice = _G.openScribeDice or function() end`)

> Dados do Escriba: o tool não passa pelo love.load; o stub deixa a
> loja registrar o botão (o copo é desenhado mesmo sem ele)

