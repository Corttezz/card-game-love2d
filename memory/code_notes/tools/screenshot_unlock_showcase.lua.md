---
name: code_notes/tools/screenshot_unlock_showcase.lua
description: Comentários com decisão/regra/histórico colhidos de tools/screenshot_unlock_showcase.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/screenshot_unlock_showcase.lua`

Origem: `tools/screenshot_unlock_showcase.lua` em `7dbdb60d` (2 de 4 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-12 (junto a `local M = {}`)

> tools/screenshot_unlock_showcase.lua
> Capturas das REVELAÇÕES DO MENU (components/UnlockShowcase.lua): um painel
> de cada tipo (carta, classe, maestria, selo, conquista) sobre o menu, com a
> janela FALSIFICADA (mesmo truque do screenshot_uiscale).
>
> love . test_one screenshot_unlock_showcase          → pt_BR + de
> love . test_one screenshot_unlock_showcase fr       → um idioma
> SHOWCASE_T=0.45 …                                   → instante da captura
> (segundos desde a entrada do painel; padrão 1.0 = assentado. Um valor
> no meio da revelação mostra pop, varredura de luz e clarão.)
>
> Saída: showcase_<tipo>_<W>x<H>_<loc>[_t<ms>].png no save dir.

## L70-71 (em `love.graphics.getDimensions`, junto a `local mode = ""`)

> SHOWCASE_HOVER=1: mouse sobre a carta revelada (sobe + tooltip);
> SHOWCASE_INSPECT=1: a inspeção da Coleção aberta nela.

