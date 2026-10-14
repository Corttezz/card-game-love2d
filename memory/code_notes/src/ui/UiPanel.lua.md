---
name: code_notes/src/ui/UiPanel.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/UiPanel.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/UiPanel.lua`

Origem: `src/ui/UiPanel.lua` em `7dbdb60d` (1 de 5 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-17 (junto a `local Palette     = require("src.ui.Palette")`)

> src/ui/UiPanel.lua
> Painel canônico do design system (Jul/2026): o idioma ESCURO-DOURADO da
> loja, extraído pra fonte única. Antes, CardRewardScreen._drawPanel,
> PauseMenu.drawDarkPanel e RoundEvalScreen redesenhavam a mesma gramática
> com valores hardcoded levemente diferentes — agora todos leem daqui e dos
> tokens Palette.PANEL_*.
>
> Gramática (ver memory/ui_design_system.md):
> sombra INK (offset 4,4 α0.45)
> → miolo PANEL_FILL (via Panel9 "panel_inner" quando o asset existe)
> → outline AGED_GOLD (lw3) + inner-outline AGED_GOLD_DARK (lw1)
> → bevel-highlight no topo
> → 4 cantos ornamentais AGED_GOLD_LIGHT (só depth "main")
>
> Uso:
> UiPanel.draw(x, y, w, h)                      -- painel principal
> UiPanel.draw(x, y, w, h, { depth = "inner" }) -- subpainel (sem ornamento)

