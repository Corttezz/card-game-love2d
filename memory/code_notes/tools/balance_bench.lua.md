---
name: code_notes/tools/balance_bench.lua
description: Comentários com decisão/regra/histórico colhidos de tools/balance_bench.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/balance_bench.lua`

Origem: `tools/balance_bench.lua` em `7dbdb60d` (2 de 6 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-15 (junto a `local M = {}`)

> tools/balance_bench.lua
> BANCO DE BATALHAS (Out/2026): mede a qualidade do COMBATE do piloto sem o
> ruido da run inteira.
>
> Por que existe: uma run tem ~10-30 batalhas, decisoes de deck, mapa e loja
> — comparar duas politicas de combate pelo winrate de 30 runs e medir
> sorteio. Aqui: (1) grava o RETRATO do comeco de cada batalha de runs reais
> (deck, forja, coringas, ato/andar/no), (2) rejoga CADA retrato com cada
> politica, mesma seed, vida cheia, e (3) compara HP perdido e mortes.
> Mesma batalha, mesmo embaralhamento, mesmos intents: so a decisao muda.
>
> love . balance_bench [runsGravadas] [classes] [seed] [politicas]
> ex: love . balance_bench 6 all 700000 v5,v6
>
> Saida: console + BALANCE_OUT (ou <save>/balance_bench_report.md).

## L58-59 (em `res`, junto a `local trace = os.getenv("BENCH_TRACE")`)

> BENCH_TRACE=classe:ato liga o diario so dessas batalhas
> (diagnostico: ver turno a turno ONDE a politica perde HP)

