---
name: code_notes/tools/screenshot_uiscale_battle.lua
description: Comentários com decisão/regra/histórico colhidos de tools/screenshot_uiscale_battle.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/screenshot_uiscale_battle.lua`

Origem: `tools/screenshot_uiscale_battle.lua` em `7dbdb60d` (1 de 10 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-12 (junto a `local M = {}`)

> tools/screenshot_uiscale_battle.lua
> A BATALHA com a escala de UI (src/ui/UiScale.lua): mão, carta em hover com
> descrição ao lado, prévia de dano, intent/pills do inimigo, orbes, toast e
> TopBar — em 5 tamanhos, janela FALSIFICADA + canvas (sem setMode).
>
> love . test_one screenshot_uiscale_battle          → pt_BR
> love . test_one screenshot_uiscale_battle de       → outro idioma
>
> Saída: uiscale_battle_<cena>_<W>x<H>_<loc>.png
> warrior  2 cartas selecionadas + hover numa 3ª + toast
> mage     orbes canalizados + 3 selecionadas
> boss     salão do chefe do ato 2 (laje baixa) + hover

