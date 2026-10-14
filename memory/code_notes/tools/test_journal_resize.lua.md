---
name: code_notes/tools/test_journal_resize.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_journal_resize.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_journal_resize.lua`

Origem: `tools/test_journal_resize.lua` em `7dbdb60d` (6 de 17 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-26 (junto a `local TK = require("tools.testkit")`)

> tools/test_journal_resize.lua
> Auditoria de RESIZE do Roteiro da jornada (components/RunJournalScreen.lua,
> versão MAPA À MÃO, Out/2026).
>
> memory/ui_layout_invariants.md §2: "NASCER grande ≠ CRESCER". A tela é
> criada num tamanho e o layout é REAPROVEITADO noutro — é aí que o defeito
> mora. A mesma memória registra que `love.window.setMode` repetido dentro de
> um tool TRAVA, então a janela é FALSIFICADA (monkey-patch em
> love.graphics.getWidth/getHeight), igual ao tools/test_forge_resize.lua.
>
> O que este teste garante, em 7 tamanhos × 5 idiomas × run curta (2 atos) e
> longa (6 atos + endless), com o acordeão no estado inicial (só o ato atual
> aberto), todo aberto e todo fechado, no fim e no topo da rolagem — via
> RunJournalLayout.validate (src/ui/RunJournalLayout.lua):
> • as zonas não se cruzam (folhas abaixo do cabeçalho, uma por ato, sem
> encostar na seguinte); numerais / mapa / margem / legenda dentro da folha;
> • toda parada e todo ramo (tomado, não tomado, à frente) dentro do mapa;
> o caminho percorrido contínuo; o castelo dentro do mapa;
> • o detalhe (hover) de TODA parada visível cabe na folha ∩ zona ∩ janela
> sem tapar a própria parada;
> • o scroll nunca aponta pra fora do conteúdo recém-medido;
> • a altura da linha do mapa fica entre ROW_MIN e ROW_MAX (quem cede é a
> escala, nunca a posição das bandas).
>
> love . test_one test_journal_resize
> love . test_all

## L45-46 (em `restoreWindow`, junto a `local function resizeTo(screen, w, h)`)

> Espelha o que love.resize faz de verdade: limpa o cache de fontes ANTES de
> avisar a tela. Teste mais leniente que o jogo não vale nada.

## L53 (em `resizeTo`, junto a `local function auditLayout(screen)`)

> Invariantes do layout resolvido + o detalhe de CADA parada e ramo visível.

## L125 (em `states`, junto a `fakeW, fakeH = 800, 600`)

> NASCE pequeno (o caminho do bug)

## L185-186 (em `states`, junto a `resizeTo(long, 640, 480)`)

> abrir um ato rola até ele ficar visível do topo (em janela baixa,
> onde há o que rolar: com tudo cabendo o scroll fica em zero)

## L198 (em `states`, junto a `local empty = Screen:new()`)

> Roteiro vazio não pode explodir em nenhum tamanho.

