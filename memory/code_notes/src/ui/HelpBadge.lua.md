---
name: code_notes/src/ui/HelpBadge.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/HelpBadge.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/HelpBadge.lua`

Origem: `src/ui/HelpBadge.lua` em `7dbdb60d` (2 de 3 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-4 (junto a `local FontManager = require("src.ui.FontManager")`)

> src/ui/HelpBadge.lua
> O "?" de ajuda no estilo do grimório: disco tinta + aro dourado + "?"
> (o MESMO desenho do "?" de regras da loja). Uma peça só pra todo "?" que
> abre explicação sob demanda — dados da loja, modal dos dados.

## L16-17 (em `HelpBadge.rect`, junto a `function HelpBadge.draw(cx, cy, r, hot, font)`)

> `font` (opcional): a tela que tem orçamento de tamanhos de fonte (seleção
> de classe: só dois) passa a fonte de corpo dela.

