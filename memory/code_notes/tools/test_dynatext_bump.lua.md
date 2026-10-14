---
name: code_notes/tools/test_dynatext_bump.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_dynatext_bump.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_dynatext_bump.lua`

Origem: `tools/test_dynatext_bump.lua` em `7dbdb60d` (6 de 10 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-23 (junto a `local TK = require("tools.testkit")`)

> tools/test_dynatext_bump.lua
> TRAVA do bump do DynaText: título que salta tem que ONDULAR, não ESPALHAR.
>
> O DEFEITO, três vezes
> O dono reclamou do "Pacote Bufão" com o P muito acima do resto. A causa é o
> default `bump_phase = 200`: 200 rad em módulo 2π dá ~-1,06 rad de defasagem
> entre letras VIZINHAS, o que espalha o texto em vez de propagar uma onda.
> Corrigido no pacote, o MESMO defeito continuou no `RoundEvalScreen`
> ("RUND E NAUSW E RTUNG") e nas `EndScreens` — porque consertar ocorrências
> não impede a próxima. Isto impede.
>
> A MÉTRICA
> Amplitude sozinha não separa os dois casos: a curva tem `max(0, ...)`, então
> a transição "no ar" → "na linha" é abrupta nos dois. O que o olho enxerga é
> CONTIGUIDADE — quantos GRUPOS separados de letras estão no ar ao mesmo
> tempo. Onda = um grupo que viaja; espalhamento = letras soltas em pontos
> distintos da palavra. Medido numa palavra de 19 letras:
>
> bump_phase = 200  (default) → até 4 grupos, degrau de 14px entre vizinhas
> bump_phase = 0.42           → até 2 grupos, degrau de ~5px
>
> love . test_one test_dynatext_bump
> love . test_all

## L31-32 (em `M`, junto a `local function yOff(i, t, phase, amount)`)

> Réplica da curva de DynaText:draw (mantida em sincronia de propósito: o
> teste mede a MATEMÁTICA da animação, que não dá pra observar num PNG).

## L38-39 (em `yOff`, junto a `local function measure(n, phase, amount)`)

> Ao longo de 12s: maior nº de grupos separados de letras no ar, e maior
> degrau de altura entre letras VIZINHAS.

## L62-64 (em `ys`, junto a `local SCAN = {`)

> ===== Varredura de consumidores ==========================================
> Qualquer DynaText com bump ligado precisa DECLARAR bump_phase. Sem isso cai
> no default histórico e espalha — que é como as três ocorrências nasceram.

## L110 (em `M.run`, junto a `local dg, ds = measure(19, 200, 1.0)`)

> ===== 1. A matemática: o default É o defeito =====

## L129 (em `M.run`, junto a `local offenders, checked = {}, 0`)

> ===== 3. A trava: nenhum consumidor no default =====

