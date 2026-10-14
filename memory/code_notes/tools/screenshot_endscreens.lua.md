---
name: code_notes/tools/screenshot_endscreens.lua
description: Comentários com decisão/regra/histórico colhidos de tools/screenshot_endscreens.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/screenshot_endscreens.lua`

Origem: `tools/screenshot_endscreens.lua` em `7dbdb60d` (2 de 2 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-14 (junto a `local M = {}`)

> tools/screenshot_endscreens.lua
> Capturas das telas de fim (src/scenes/EndScreens.lua): GAME OVER e VITÓRIA.
>
> love . screenshot_endscreens          → pt_BR
> love . screenshot_endscreens de       → outro idioma
>
> POR QUE EXISTE: os títulos usam DynaText com `bump`, e o bump no default
> (bump_phase=200) ESPALHA as letras em vez de ondular — o mesmo defeito do
> título do pacote e do Round Eval. Não havia tool pra olhar essas duas telas,
> então o defeito nunca apareceu numa captura.
>
> Captura DOIS instantes de cada tela: com um frame só não dá pra distinguir
> "onda viajando" de "letras espalhadas". Em dois instantes a onda MOVE o
> grupo elevado; o espalhamento troca letras soltas de lugar.

## L51-53 (em `M.run`, junto a `for _, screen in ipairs({`)

> Cada tela é desenhada do zero a partir de t=0 (o DynaText guarda timer
> interno e o ensureTitle reseta ao reentrar), então avançamos o relógio
> por desenhos sucessivos em vez de saltar.

