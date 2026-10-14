---
name: code_notes/tools/test_balance_pipeline.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_balance_pipeline.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_balance_pipeline.lua`

Origem: `tools/test_balance_pipeline.lua` em `7dbdb60d` (4 de 11 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-19 (junto a `local TK = require("tools.testkit")`)

> tools/test_balance_pipeline.lua
> Trava da PIPELINE de balanceamento (Out/2026): pilotos, determinismo,
> throughput e o registro que alimenta tools/balance.py.
>
> 1. Os tres pilotos existem como PERFIL (dado) e jogam uma run sem crash
> no relogio instantaneo.
> 2. Sanidade NAIVE < AVERAGE < EXPERT: medida em BATALHAS IGUAIS (mesmo
> retrato, mesma seed, vida cheia — o banco do balance_bench), nao em
> winrate de poucas runs (que e sorteio). O naive tem que perder mais
> vida que o expert_fast no agregado dos retratos.
> 3. Determinismo: mesma seed → mesmo registro (resultado, batalhas, deck).
> 4. Throughput: run do piloto `average` no relogio instantaneo em menos de
> N segundos de CPU (teto FOLGADO — mede regressao de ordem de grandeza,
> nao ms; o numero real vai no relatorio da bateria).
> 5. Registro: campos que o relatorio Python le estao presentes e coerentes
> (battleLog soma as batalhas, dano por fonte > 0, deck por batalha).
> 6. jsonlite codifica o registro e o Lua le de volta o mesmo numero de runs.
>
> love . test_one test_balance_pipeline

## L97-98 (em `recs`, junto a `do`)

> 2) sanidade por BATALHAS IGUAIS: retratos de uma run do average,
> rejogados por naive e expert_fast com a mesma seed, vida cheia.

## L134 (em `bench`, junto a `do`)

> 4) throughput (teto folgado)

## L160-161 (em `bench`, junto a `function M.run()`)

> Os stubs do balance_sim.setup() sao desfeitos mesmo se o corpo falhar:
> as suites seguintes do test_all rodam no mesmo processo.

