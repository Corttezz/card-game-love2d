---
name: code_notes/tools/screenshot_guide.lua
description: Comentários com decisão/regra/histórico colhidos de tools/screenshot_guide.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/screenshot_guide.lua`

Origem: `tools/screenshot_guide.lua` em `7dbdb60d` (1 de 1 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-5 (junto a `local M = {}`)

> tools/screenshot_guide.lua
> Captura o GUIA (combos + glossário) num tamanho de janela FALSIFICADO.
> love . test_one screenshot_guide pt_BR:1920x1080:1
> (locale : WxH : aba 1=combos 2=glossário) — PNG no save dir:
> guide_<locale>_<W>x<H>_<aba>.png

