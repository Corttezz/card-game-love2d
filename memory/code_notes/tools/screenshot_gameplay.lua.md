---
name: code_notes/tools/screenshot_gameplay.lua
description: Comentários com decisão/regra/histórico colhidos de tools/screenshot_gameplay.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/screenshot_gameplay.lua`

Origem: `tools/screenshot_gameplay.lua` em `7dbdb60d` (3 de 20 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-4 (junto a `local M = {}`)

> tools/screenshot_gameplay.lua
> Captura screenshot de uma batalha do ato 1 (warrior floor 1) pra análise
> visual. Roda via: love . screenshot_gameplay
> Saída: /tmp/card-game-screenshot.png

## L44-45 (em `M.run`, junto a `local simDt = 1 / 30`)

> Avança ~2s de simulação pra anims idle entrarem em regime + partículas
> spawn + smoke denser

## L65-66 (em `M.run`, junto a `local width, height = love.graphics.getDimensions()`)

> Não podemos chamar main.drawGame() direto pq é local. Vamos replicar
> o essencial inline:

