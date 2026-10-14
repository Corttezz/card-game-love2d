---
name: code_notes/tools/screenshot_holo.lua
description: Comentários com decisão/regra/histórico colhidos de tools/screenshot_holo.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/screenshot_holo.lua`

Origem: `tools/screenshot_holo.lua` em `7dbdb60d` (2 de 4 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-9 (junto a `local M = {}`)

> tools/screenshot_holo.lua
> Prancha do reflexo das cartas raras/lendárias, sem janela: desenha pelo
> caminho AO VIVO (Card:draw) uma rara "glow", uma rara "holo", uma lendária
> e uma comum com edition "holo" — em REPOUSO (tem que ser a carta crua, ou
> quase) e no HOVER em três instantes da varredura. Canvas 1920x1080.
>
> love . test_one screenshot_holo
>
> Saída: holo_rest_hover_1920x1080.png no save dir.

## L52-53 (em `make`, junto a `local ROWS = { { label = "REPOUSO (estatica)", time = 1.0, hover = false },`)

> Instantes escolhidos pela posicao da faixa (34 px/s, ciclo ~6.7 s):
> t=1.5 canto superior esquerdo, t=2.9 meio da carta, t=4.2 canto inferior.

