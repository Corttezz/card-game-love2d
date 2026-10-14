---
name: code_notes/tools/screenshot_crt_levels.lua
description: Comentários com decisão/regra/histórico colhidos de tools/screenshot_crt_levels.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/screenshot_crt_levels.lua`

Origem: `tools/screenshot_crt_levels.lua` em `7dbdb60d` (2 de 4 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-9 (junto a `local M = {}`)

> tools/screenshot_crt_levels.lua
> Os 3 NÍVEIS do CRT (Desligado / Baixo / Normal) SEM JANELA, em 1080p e
> 1440p, sobre uma tela cheia de TEXTO (o menu principal) — pra julgar
> legibilidade: scanlines, grille, aberração, curvatura, vinheta.
>
> CARDGAME_HEADLESS=1 love . test_one screenshot_crt_levels
>
> Saída (save dir): crt_<nivel>_<W>x<H>.png (6 arquivos) + crt_levels_sheet.png
> (recortes 1:1 do título e de um botão, lado a lado por nível/resolução).

## L57-58 (em `love.graphics.getDimensions`, junto a `crops[#crops + 1] = { data = data, W = W, H = H, lv = lv,`)

> recortes 1:1: título (centro-alto) e botão SAIR (centro-baixo)
> título centrado em (W/2, 0.22H); JOGAR começa em 0.5H (Menu:createButtons)

