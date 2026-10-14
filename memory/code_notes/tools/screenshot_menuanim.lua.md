---
name: code_notes/tools/screenshot_menuanim.lua
description: Comentários com decisão/regra/histórico colhidos de tools/screenshot_menuanim.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/screenshot_menuanim.lua`

Origem: `tools/screenshot_menuanim.lua` em `7dbdb60d` (2 de 7 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-7 (junto a `local M = {}`)

> tools/screenshot_menuanim.lua
> Valida a ANIMAÇÃO DE VELA do menu (ciclo de crossfade entre frames).
> love . screenshot_menuanim
> Monkeypatcha love.timer.getTime pra amostrar o ciclo inteiro em pontos
> controlados, renderiza o Menu REAL em cada ponto e monta um grid pra ver
> a sequência (7 "holds") + um crossfade intermediário numa imagem só.
> Salva menuanim_grid.png no save dir.

## L32-33 (em `labels`, junto a `local samples = {}`)

> pontos de amostragem: o "hold" (alvo cheio) de cada um dos 7 estados,
> + 2 crossfades no meio (menu→normal e menu_1→menu_2) pra ver o blend.

