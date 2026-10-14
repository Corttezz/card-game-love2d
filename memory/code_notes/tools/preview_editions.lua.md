---
name: code_notes/tools/preview_editions.lua
description: Comentários com decisão/regra/histórico colhidos de tools/preview_editions.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/preview_editions.lua`

Origem: `tools/preview_editions.lua` em `7dbdb60d` (5 de 5 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-13 (junto a `local M = {}`)

> tools/preview_editions.lua
> As DUAS editions com shader proprio (Foil e Polychrome) na MESMA carta, lado
> a lado com a carta limpa. (A Negative saiu do jogo em Out/2026.)
>
> love . preview_editions            -- 1024x768, pt_BR
> love . preview_editions <card_id>  -- outra cobaia
>
> Por que existe: edition e hierarquia. Julgar o Polychrome sozinho nao diz
> nada -- a pergunta e se ele le como MAIS raro que Foil sem sair
> da paleta do jogo. So o lado a lado responde isso.
>
> Saida: <save dir>/editions_comparativo.png
> <save dir>/editions_1to1_<nome>.png  (recorte 1:1 pra medicao)

## L23-27 (em `LABELS`, junto a `function M.run(cardId)`)

> Gera SEMPRE as duas variantes (normal e reducedMotion). Nao e preguica de
> fazer argumento: `test_one` nao repassa argumentos pro run(), e enquanto este
> tool nao tiver despacho proprio em main.lua e a unica forma de invoca-lo.
> Duas imagens tambem e o certo pra um tool de comparacao: reducedMotion faz
> parte do que precisa ser julgado, nao e um caso especial escondido.

## L50-51 (em `M.run`, junto a `local shots = {}`)

> Uma instancia POR edition, todas da mesma carta: a unica variavel e o
> shader. Sem isso a comparacao mede arte diferente, nao edition.

## L70-71 (em `cd`, junto a `love.graphics.clear(0.20, 0.16, 0.12, 1)`)

> Fundo sepia do jogo: o teste e "destoa da tela?", entao o fundo tem que
> ser o da tela, nao preto neutro.

## L102-103 (em `cd`, junto a `for _, sdef in ipairs(shots) do`)

> Recortes 1:1 (sem escala, sem reamostragem) pra medir desvio vs a arte
> crua pixel a pixel -- mesmo teste objetivo que validou o foil do sleeve.

