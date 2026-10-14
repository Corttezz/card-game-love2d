---
name: code_notes/tools/screenshot_round_eval.lua
description: Comentários com decisão/regra/histórico colhidos de tools/screenshot_round_eval.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/screenshot_round_eval.lua`

Origem: `tools/screenshot_round_eval.lua` em `7dbdb60d` (3 de 8 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-9 (junto a `local M = {}`)

> tools/screenshot_round_eval.lua
> Captura screenshot da RoundEvalScreen (cash out estilo Balatro).
> Roda: love . screenshot_round_eval [phase]
> phase: 0..3 — diferentes momentos da timeline.
> 0 = slide-in (0.4s)
> 1 = primeira coin saiu (1.0s)
> 2 = todas coins (2.5s)
> 3 = botão Resgatar pronto (3.5s)
> Saída: ~/.local/share/love/card-game/round_eval_phase_<n>.png

## L29-31 (em `PHASE_TIMES`, junto a `function M.run(phase, locale)`)

> locale opcional (2o arg): a tela era BILINGUE — titulo e TOTAL cravados em
> PT com o botao traduzido. Capturar em idioma estrangeiro e o que prova o
> conserto; em pt_BR os dois casos ficam iguais.

## L67-69 (em `game.scoreSystem.lastBattle`, junto a `breakdown = {`)

> MESMAS chaves que ScoreSystem:finishBattle usa. Com os rotulos
> cravados em PT aqui a captura MENTIA: mostrava o recibo em portugues
> mesmo depois do codigo real ja estar traduzido.

