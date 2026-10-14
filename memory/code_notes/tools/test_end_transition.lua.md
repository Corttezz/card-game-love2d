---
name: code_notes/tools/test_end_transition.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_end_transition.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_end_transition.lua`

Origem: `tools/test_end_transition.lua` em `7dbdb60d` (3 de 9 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-13 (junto a `local TK = require("tools.testkit")`)

> tools/test_end_transition.lua
> A trava de reentrada da transição de fim de run.
>
> Reproduz o defeito que o dono viu: "ao morrer no jogo a tela fica preta e
> não tem como voltar pro menu, só fechando o jogo". O fim de run é disparado
> por CONDIÇÃO (`checkGameOver()` continua verdadeiro todo frame), e sem trava
> cada frame reiniciava o desligamento do CRT — o callback que troca o estado
> nunca chegava ao fim.
>
> O teste simula o desligamento como o CRTShader faz de verdade: guarda o
> callback e só o chama quando a duração pedida se esgota. Uma chamada nova
> SUBSTITUI a anterior e zera o cronômetro — é exatamente esse
> comportamento que transformava a chamada repetida em travamento.

## L41 (em `M.run`, junto a `ET.clear()`)

> ===== O caso do bug: a condição dispara todo frame =====

## L48 (em `M.run`, junto a `for _ = 1, 120 do`)

> 2 segundos a 60fps, com a morte sempre verdadeira

