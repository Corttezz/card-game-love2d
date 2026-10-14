---
name: code_notes/tools/test_instant_parity.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_instant_parity.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_instant_parity.lua`

Origem: `tools/test_instant_parity.lua` em `7dbdb60d` (5 de 8 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-19 (junto a `local TK = require("tools.testkit")`)

> tools/test_instant_parity.lua
> PARIDADE do relogio instantaneo (tools/instant_engine.lua) com o relogio de
> quadros do piloto: as MESMAS seeds, jogadas pelas MESMAS decisoes, tem que
> produzir o MESMO jogo — vida, escudo, mana, intent, status, mao, ouro e o
> estado exato dos 6 streams do Rng, no inicio de cada turno de cada
> batalha — e o mesmo resultado final.
>
> Por que o teste existe: o instant_engine so vale se "mais rapido" nao
> significar "outro jogo". Qualquer coisa cosmetica que contamine regra
> (random global alimentando embaralhamento, animacao que aplica dano fora
> de ordem, timeout de beat disparando cedo) aparece aqui como divergencia
> no primeiro turno em que o estado se separa — com a linha exata.
>
> Tambem cobre DETERMINISMO: a mesma seed duas vezes no relogio instantaneo
> da o mesmo traco, e seeds diferentes dao tracos diferentes (senao a seed
> nao estaria mandando em nada).
>
> love . test_one test_instant_parity
> PARITY_BATTLES=12 PARITY_SEEDS=3 love . test_one test_instant_parity   (mais fundo)

## L55-57 (em `body`, junto a `local Autoplay = BS.setup("average")`)

> AVERAGE (heuristica, sem simulacao de deck): o teste mede o RELOGIO, nao
> o cerebro; o piloto por simulacao faria cada run custar minutos no
> relogio de quadros.

## L101 (em `classes`, junto a `do`)

> seed diferente muda o jogo (senao a seed nao manda em nada)

## L111-114 (em `classes`, junto a `if tInstant > tFrames then`)

> Tempo e BENCHMARK, nao trava: com outras suites em paralelo a medida
> oscila (0,83 s x 1,28 s numa rodada de 3 suites) e a asserção flipava.
> A paridade (acima) e o que o teste garante; throughput mora no
> tools/balance.py (runs/s/core no rodape do relatorio).

## L126-127 (em `classes`, junto a `function M.run()`)

> Os stubs do balance_sim.setup() sao desfeitos mesmo se o corpo falhar:
> as suites seguintes do test_all rodam no mesmo processo.

