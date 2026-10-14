---
name: code_notes/tools/test_toasts.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_toasts.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_toasts.lua`

Origem: `tools/test_toasts.lua` em `7dbdb60d` (1 de 2 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-10 (junto a `local TK = require("tools.testkit")`)

> tools/test_toasts.lua
> Toasts (src/systems/MessageSystem.lua) como PLACA numa zona definida:
> coluna esquerda entre o pé do quadro de coringas e o topo da mão.
> Antes eram texto cru de 12px em x=10,y=244, sem fundo e sem quebra —
> uma frase longa atravessava a tela por cima do inimigo.
>
> love . test_one test_toasts            → só asserções
> love . test_one test_toasts shots      → + capturas toasts_<W>x<H>.png
>
> Janela FALSIFICADA (getWidth/getHeight), sem setMode.

