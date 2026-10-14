---
name: code_notes/tools/test_navcursor.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_navcursor.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_navcursor.lua`

Origem: `tools/test_navcursor.lua` em `7dbdb60d` (2 de 5 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-9 (junto a `local TK = require("tools.testkit")`)

> tools/test_navcursor.lua
> Cursor de foco do teclado/pad (src/ui/NavCursor.lua), isolado: registro de
> alvos em pixels da tela, vizinho espacial, camadas do InputFocus, foco
> automático fora da barra do topo, clique sintético no foco, mouse que
> devolve o controle, recorte por scissor/janela.
>
> love . test_one test_navcursor
>
> O fluxo de run inteiro (jogo de verdade) é `love . nav_flow`.

## L28-29 (em `love.mousereleased`, junto a `NC.beginFrame()`)

> grade 2x2 + item da barra do topo
> registra e "fecha" o quadro (beginFrame do próximo)

