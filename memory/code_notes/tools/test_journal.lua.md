---
name: code_notes/tools/test_journal.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_journal.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_journal.lua`

Origem: `tools/test_journal.lua` em `7dbdb60d` (7 de 22 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-5 (junto a `local TK = require("tools.testkit")`)

> tools/test_journal.lua
> Roteiro da run (RunManager journal*): abertura/fecho por nó, captura das
> escolhas pelos sinks, idempotência do journalEnd, backfill de mapHistory,
> endless (o par ato/andar repete) e sobrevivência ao save/load.
> love . test_one test_journal

## L45 (em `M.run`, junto a `t:falsy("journalEnd repetido é no-op", rm:journalEnd({ hp = 1, gold = 1 }))`)

> Idempotente: showMapSelection pode rodar duas vezes.

## L50 (em `M.run`, junto a `rm:journalNote({ kind = "card", id = "warrior_strike" })`)

> Depois de fechado, nota volta a ser no-op.

## L95-97 (em `kinds`, junto a `do`)

> ===== encruzilhada: os ramos NÃO tomados ficam gravados (Out/2026) =====
> O mapa à mão desenha os trilhos que existiam; sem isto só o caminho
> percorrido sobreviveria. Só os TIPOS viajam (save pequeno, aditivo).

## L137-140 (em `opts`, junto a `do`)

> ===== nó que resolve sem passar pelo journalEnd =====
> O autoplay (tools/autoplay.lua) chama chooseNode direto e nunca fecha a
> entrada. Sem o auto-fecho do journalBegin isso empilharia entradas
> zumbis e todas as escolhas seguintes cairiam no nó errado.

## L209-212 (em `run.journal`, junto a `do`)

> ===== gatilho: clique no bloco de ATO da TopBar =====
> O bloco "ATO N / andar X" não tinha clique nenhum; a TopBar engolia o
> evento e devolvia true. Este teste fixa a zona: clicar no progresso
> chama o callback do Roteiro, e clicar no DECK continua chamando o dele.

## L240 (em `hits`, junto a `local screen = require("components.RunJournalScreen"):new()`)

> A tela em si tem que abrir/fechar sem estado de run montado à mão.

