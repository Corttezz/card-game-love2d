---
name: code_notes/src/ui/Panel9.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/Panel9.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/Panel9.lua`

Origem: `src/ui/Panel9.lua` em `7dbdb60d` (3 de 10 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-15 (junto a `local Palette = require("src.ui.Palette")`)

> src/ui/Panel9.lua
> Painéis 9-slice com arte PixelLab (F0 do UI Overhaul —
> docs/plan/ui-ux-overhaul-v1.md §3.1). Cantos em escala fixa, bordas e
> centro esticados (as bordas dos assets atuais são faixas uniformes; se
> um asset futuro tiver padrão repetido, trocar por tiling).
>
> Assets em assets/sprites/ui/<name>.png (gerados por
> tools/pixellab_generate_ui.py). O PNG é TRIMADO no load (bbox de
> conteúdo) e fatiado pela margem do SPEC. Sem PNG → fallback procedural
> (padrão dual-border do projeto), então nenhuma tela depende do asset.
>
> Uso:
> local Panel9 = require("src.ui.Panel9")
> Panel9.draw("panel_main", x, y, w, h)          -- escala 2 default
> Panel9.draw("panel_inner", x, y, w, h, { scale = 2, fill = {0,0,0,0.6} })

## L21-22 (em `Panel9`, junto a `local SPECS = {`)

> margin = px do PNG trimado que conta como canto/borda; scale = fator
> de pixel default no draw (2 = cada pixel-fonte vira 2×2 na tela).

## L119-120 (em `Panel9.draw`, junto a `if opts.fill then`)

> preenchimento opcional POR BAIXO (para molduras de centro vazado
> como panel_inner)

