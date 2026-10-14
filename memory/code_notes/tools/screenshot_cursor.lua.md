---
name: code_notes/tools/screenshot_cursor.lua
description: Comentários com decisão/regra/histórico colhidos de tools/screenshot_cursor.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/screenshot_cursor.lua`

Origem: `tools/screenshot_cursor.lua` em `7dbdb60d` (2 de 8 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-5 (junto a `local M = {}`)

> tools/screenshot_cursor.lua
> Valida o cursor pixel-art:  love . screenshot_cursor
> Desenha o menu real de fundo + os 2 cursores em escala de jogo (2×) em
> posições de contexto, e ampliados 8× num canto pra inspeção da arte.
> Salva cursor_preview.png no save dir.

## L31-34 (em `love.window.hasMouseFocus`, junto a `local W, H = love.graphics.getDimensions()`)

> acessa as imagens internas via draw() com mouse fake: em vez disso,
> redesenha direto (inspeção): pega via package.loaded (upvalues não
> são expostos), então simplesmente chama draw() 2x com estados.
> Pra inspeção ampliada, reconstruímos as imagens aqui:

