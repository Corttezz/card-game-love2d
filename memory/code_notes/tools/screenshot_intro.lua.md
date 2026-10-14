---
name: code_notes/tools/screenshot_intro.lua
description: Comentários com decisão/regra/histórico colhidos de tools/screenshot_intro.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/screenshot_intro.lua`

Origem: `tools/screenshot_intro.lua` em `7dbdb60d` (2 de 4 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-5 (junto a `local M = {}`)

> tools/screenshot_intro.lua
> Capturas da ABERTURA (página + televisor + mergulho) quadro a quadro,
> numa janela falsificada, e a fita do menu.
> love . test_one screenshot_intro [locale] [WxH]
> Saída: intro_<fase>_<W>x<H>_<loc>.png e intro_menu_ribbon_<W>x<H>_<loc>.png

## L26-27 (em `love.graphics.getDimensions`, junto a `if os.getenv("INTRO_DATA") then IntroTube.DATA_PATH = os.getenv("INTRO_DATA"); IntroTube.reloadArt() end`)

> INTRO_DATA=<caminho relativo à fonte> força outra arte de computador
> (ex.: tools/preview_out/intro_synth/intro_computer.lua)

