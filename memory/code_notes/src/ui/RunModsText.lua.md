---
name: code_notes/src/ui/RunModsText.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/RunModsText.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/RunModsText.lua`

Origem: `src/ui/RunModsText.lua` em `7dbdb60d` (3 de 3 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-4 (junto a `local I18n = require("src.i18n.I18n")`)

> src/ui/RunModsText.lua
> TEXTO dos modificadores da run (Selo do Grimório + maldições do endless)
> pra TopBar, pausa, roteiro e tela final. Um lugar só: as quatro telas
> dizem a MESMA coisa com as mesmas palavras (ver RunModifiers).

## L11-13 (em `M`, junto a `function M.short(run, compact)`)

> Curto, pra caber numa linha de 9px: "Selo 3 · Ciclo 2 · maldições: 3".
> `compact` (TopBar) deixa as maldições de fora — a lista mora no tooltip.
> Vazio quando a run é o jogo base.

## L27-29 (em `parts`, junto a `function M.long(run)`)

> Longo, pra tooltip / resumo: "Selo 3: Mercado Caro. Maldições: Fome x1 ·
> Dízimo x2. Pontos x1.75". Começa com espaço quando não é vazio (vai
> colado no fim de outra frase).

