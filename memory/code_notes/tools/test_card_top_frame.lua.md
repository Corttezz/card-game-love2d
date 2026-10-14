---
name: code_notes/tools/test_card_top_frame.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_card_top_frame.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_card_top_frame.lua`

Origem: `tools/test_card_top_frame.lua` em `7dbdb60d` (2 de 7 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-13 (junto a `local TK = require("tools.testkit")`)

> tools/test_card_top_frame.lua
> O TOPO DA CARTA NÃO PODE SUMIR (dono, Out/2026: "o topo das cartas está
> cortado — não é só na loja"). Duas réguas:
>
> 1. CANVAS (CardFrame): as 3 linhas do topo, no vão do banner do nome,
> são a MOLDURA — idênticas a um render só da CardBorder. Antes o banner
> nascia em y=0 e cobria a faixa de nó (y=1); a gema de custo colava na
> borda. Vale pra carta comum e pra coringa.
> 2. TELA (Card:draw): a carta desenhada em escala inteira, em repouso, tem
> as linhas do topo do canvas presentes no lugar certo — nenhum
> recorte/deslocamento no caminho de desenho (mesh/shader, lift, escala).
>
> love . test_one test_card_top_frame

## L93-97 (em `M.run`, junto a `do`)

> 3. ENQUADRAMENTO (dono: "onde começa a sombra do título ela corta"):
> NENHUMA linha do sujeito pode ficar acima do topo do slot — a
> primeira linha com conteúdo do ícone (bbox) cai dentro do slot;
> o corte do cover-fit vai pro pé. Exceção declarada: carta com
> artOffsetY/artScale no atlas (sujeito no pé da arte).

