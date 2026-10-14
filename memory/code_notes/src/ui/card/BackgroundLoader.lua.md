---
name: code_notes/src/ui/card/BackgroundLoader.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/card/BackgroundLoader.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/card/BackgroundLoader.lua`

Origem: `src/ui/card/BackgroundLoader.lua` em `7dbdb60d` (1 de 1 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-8 (junto a `local BackgroundLoader = {}`)

> src/ui/card/BackgroundLoader.lua
> Carrega PNGs de fundo (patterns) gerados via PixelLab.
> Preferência: PNG em assets/sprites/backgrounds/patterns/<name>.png
> Fallback: nil (o compositor então desenha o pattern procedural legado).
>
> Uso:
> local img = BackgroundLoader.get("stone")  -- love.Image ou nil
> if img then love.graphics.draw(img, x, y) end

