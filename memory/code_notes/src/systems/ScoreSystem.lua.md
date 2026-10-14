---
name: code_notes/src/systems/ScoreSystem.lua
description: Comentários com decisão/regra/histórico colhidos de src/systems/ScoreSystem.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/systems/ScoreSystem.lua`

Origem: `src/systems/ScoreSystem.lua` em `7dbdb60d` (5 de 11 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-23 (junto a `local I18n = require("src.i18n.I18n")`)

> src/systems/ScoreSystem.lua
> Pontuação "TINTA × SELO" (F3 do gameplay-overhaul-v1) — o chips×mult do
> grimório, na gramática do Balatro:
>
> ScoreBatalha = floor(TINTA × SELO)
> TINTA (base)  = maxHP do inimigo + 10·andar + 50·(ato−1)
> ×2 boss · ×1.25 elite · ×1.18^n no endless
> SELO (mult)   = 1.0
> + 0.30 por turno ABAIXO do par (par = 3 + ato)      [eficiência]
> − 0.10 por turno acima (piso 0.5)
> + 0.25 por combo de tag DISTINTO na batalha          [estilo]
> + 0.50 se 3+ combos dispararam no MESMO turno
> + 0.50 se terminou com HP ≤ 25%                      [risco]
> + 1.00 flawless (nenhum dano tomado)
>
> O score da RUN é a soma das batalhas (+ bônus de ato via caller).
> Recorde histórico vive no ProfileStats (bestScore).
>
> Integração (Game.lua):
> startBattle()            — startGame / nextPhase / resumeRun
> recordTurnCombos(ctx)    — playSelectedCards (turnContext.activeCombos)
> recordDamageTaken(n)     — enemyTurn (dano que chegou no player)
> finishBattle(game)       — _onEnemyDeath → retorna breakdown pro RoundEval

## L27-28 (junto a `local function sl(key, vars, fallback)`)

> Recibo traduzido (score.*). As linhas do breakdown sao exibidas na
> RoundEvalScreen; saiam em PT cravado dentro da tela ja traduzida.

## L80-81 (em `ScoreSystem:recordDamageTaken`, junto a `function ScoreSystem:finishBattle(game)`)

> Fecha a batalha vencida e soma no score da run.
> Retorna { tinta, selo, total, turns, combos, flawless, lowHp }.

## L103-104 (em `ScoreSystem:finishBattle`, junto a `if run then`)

> Selo do Grimório (+10%/nível) e maldições do endless (+N% por acúmulo):
> quem aceita a regra mais dura pontua mais (RunModifiers.scoreMul).

## L137-138 (em `ScoreSystem:finishBattle`, junto a `local breakdown = {}`)

> Recibo LEGÍVEL (feedback do dono: "TINTA×SELO não ficou claro").
> Cada linha nomeia O QUE o jogador fez; a matemática fica implícita.

