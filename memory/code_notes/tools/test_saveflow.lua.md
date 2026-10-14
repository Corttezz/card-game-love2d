---
name: code_notes/tools/test_saveflow.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_saveflow.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_saveflow.lua`

Origem: `tools/test_saveflow.lua` em `7dbdb60d` (3 de 7 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-8 (junto a `local M = {}`)

> tools/test_saveflow.lua
> Reproduz o fluxo de save/abandono reportado como bugado:
> love . test_saveflow
> Cenários:
> A) abandonar run → save some do disco → run nova nasce LIMPA
> B) "restart" do app (novos objetos) → sem save → run nova limpa
> C) save de run antiga presente → Jogar (não Continuar) → run nova limpa
> Sai com código de erro e [FAIL] no stdout se qualquer invariante quebrar.

## L44 (em `M.run`, junto a `g1.runManager:deleteSave()`)

> ABANDONO (mesma sequência do onAbandon + returnToMenu do main.lua)

## L98-99 (em `M.run`, junto a `return not M._failed`)

> Devolve o resultado (contrato do run_all_tests) em vez de fechar o
> processo: com love.event.quit aqui, a suite inteira parava neste teste.

