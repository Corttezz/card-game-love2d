---
name: code_notes/tools/screenshot_cartas_vivas.lua
description: Comentários com decisão/regra/histórico colhidos de tools/screenshot_cartas_vivas.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/screenshot_cartas_vivas.lua`

Origem: `tools/screenshot_cartas_vivas.lua` em `7dbdb60d` (3 de 9 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-14 (junto a `local M = {}`)

> tools/screenshot_cartas_vivas.lua
> PROVA VISUAL da regra "carta visível = carta viva" (dono, 13/Out/2026):
> cada cena é capturada DUAS vezes, com o relógio simulado avançado entre as
> capturas e o mouse LONGE das cartas (sem hover), e a diferença de pixels
> entre as duas capturas é contada e gravada como imagem. Ícone animado em
> repouso = diferença > 0; com reducedMotion = diferença 0.
>
> Cenas: grade da Coleção, Deck Viewer (CardGridRender), fileira de cartas
> pelo Card:draw (mão/espólios/loja/pacote passam por ele), espólios
> (CardRewardScreen) e a Coleção com reducedMotion.
>
> CARDGAME_HEADLESS=1 love . screenshot_cartas_vivas
> Saída: <save dir>/cartas_vivas_<cena>_t1.png, _t2.png, _diff.png
> + cartas_vivas_relatorio.txt (contagem por cena)

## L142-143 (em `drawRow`, junto a `local nRow = shoot("mao_carddraw", function() end, drawRow, 2 * math.pi / 0.666)`)

> Δt = UM período exato do balanço idle da carta (sin(t*0.666)): o
> balanço volta ao mesmo pixel e só o ícone muda entre as capturas.

## L177-178 (em `drwRw`, junto a `local nRw = shoot("espolios", updRw, drwRw)`)

> (aqui o balanço idle das cartas também entra na diferença: a prova
> limpa do ícone é a da fileira acima; esta mostra a tela real)

