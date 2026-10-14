---
name: code_notes/tools/test_endless_seals.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_endless_seals.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_endless_seals.lua`

Origem: `tools/test_endless_seals.lua` em `7dbdb60d` (2 de 18 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-14 (junto a `local TK = require("tools.testkit")`)

> tools/test_endless_seals.lua
> Trava do PÓS-JOGO (Out/2026): Selos do Grimório + endless em ciclos com
> maldições. memory/endless_and_seals.md tem o desenho.
>
> 1. Selo 0 sem maldição = JOGO BASE (todo multiplicador neutro).
> 2. Selos são CUMULATIVOS e cada regra chega no sistema certo (mapa, loja,
> cura, ouro, recompensa, inimigo) pelo Game de verdade.
> 3. Desbloqueio por classe: vencer no selo k abre o k+1, só dessa classe.
> 4. Endless: ciclo novo abre escolha 1-de-2 (distintas, reprodutível por
> seed), escolha empilha e respeita o teto, viaja no save; curva cresce
> e é justa no começo e impiedosa depois.
> 5. Telas: layout da escolha de maldição e da banda de selo sem
> sobreposição; tela de maldição escolhe por teclado e grava.
> love . test_one test_endless_seals

## L157 (em `r2`, junto a `local rt = { endless = { cycle = 0, curses = { fome = 3 }, order = { "fome" } } }`)

> teto de acumulo

