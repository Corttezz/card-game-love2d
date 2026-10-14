---
name: code_notes/tools/test_journal_map.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_journal_map.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_journal_map.lua`

Origem: `tools/test_journal_map.lua` em `7dbdb60d` (3 de 16 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-20 (junto a `local TK = require("tools.testkit")`)

> tools/test_journal_map.lua
> TRAVA do Roteiro como MAPA À MÃO (components/RunJournalScreen.lua +
> src/ui/RunJournalLayout.lua + src/ui/RunJournalInk.lua), Out/2026.
>
> O que fixa (pedido do dono: "literalmente um mapa... à mão, só tinta preta
> e no máximo um círculo vermelho, folha envelhecida, abre e fecha por ato"):
> • a encruzilhada grava os ramos NÃO tomados e o mapa os DESENHA
> (pixels de tinta no retângulo de cada ramo);
> • o caminho percorrido é CONTÍNUO: cada parada liga à anterior (estrutura
> do layout + amostragem de pixels ao longo de cada trecho);
> • exatamente UM círculo vermelho, em volta da parada atual;
> • nenhuma cor fora da família papel/tinta/vermelho na captura inteira;
> • atos anteriores nascem FECHADOS e o atual ABERTO; clique e teclado
> abrem/fecham; o layout valida em todo estado;
> • entrada sem `branches` (save antigo) desenha só o caminho.
>
> Render em canvas com janela FALSIFICADA (sem setMode), como o
> tools/screenshot_journal.lua; a escala de UI fica em 1 (testkit).
>
> love . test_one test_journal_map

## L62-64 (em `render`, junto a `local function classify(r, g, b)`)

> ===== classificação de cor =====
> papel/tinta: família sépia (r >= g >= b, com as razões do PARCHMENT ao INK);
> vermelho: r dominante (BLOOD); preto: a mesa. Fora disso é cor estranha.

## L223-225 (em `counts`, junto a `screen._openedAt = 0`)

> ===== abrir/fechar: clique e teclado =====
> (abre no ato atual; em janela baixa o título do ato 1 está
> rolado pra fora da zona, então primeiro HOME)

