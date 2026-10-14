---
name: code_notes/tools/test_combat.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_combat.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_combat.lua`

Origem: `tools/test_combat.lua` em `7dbdb60d` (6 de 20 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-5 (junto a `local TK = require("tools.testkit")`)

> tools/test_combat.lua
> Integração de combate (Game.lua): seleção/mana, remoção da mão, pipeline de
> dano/defesa, ciclo de turno, vitória/derrota, slots de joker.
> Usa pump() pro combate diferido (apex), como smoke_turn_order.
> love . test_combat

## L89-92 (em `M.run`, junto a `do`)

> ===== COMBOS SIMPLES no combate real (Out/2026) =====
> 3 Golpes iguais: Impeto (+1 Forca antes das cartas, 3 ataques) e, do 2o
> em diante, Saraivada (+step por ataque anterior) e Par (+step por copia
> anterior). Bonus plano, linear.

## L117 (em `strikes`, junto a `do`)

> ===== Passivas que CRESCEM na luta (balanceamento de classe, Out/2026) =====

## L165-167 (em `go.player.buffs`, junto a `g = TK.newRunGame("warrior"); TK.pump(g, 0.5)`)

> checkVictory: precisa do ULTIMO ato, andar 8, boss, inimigo morto.
> Ancorado em Config.TotalActs — a campanha foi de 3 pra 6 atos em
> Set/2026 e um "3" cravado aqui passaria a testar o meio do jogo.

## L190-193 (em `run.currentNode`, junto a `t:truthy("aceita joker mesmo com 3 ativos (bancada)", g:canAcceptJoker())`)

> Coringas = COLEÇÃO + BANCADA (CLAUDE.md): joker NUNCA é rejeitado por
> slots cheios — o 4º entra na BANCADA (nunca se perde). jokerSlots =
> só os ATIVOS (até MAX_JOKER_SLOTS). Atualizado no merge Jul/2026 (o
> assert antigo encodava a rejeição pré-refactor).

## L199-200 (em `run.currentNode`, junto a `local function focusAt(act)`)

> ===== Passivas que crescem com a run (Out/2026) =====
> Conduite (Foco) e Toxinas (Veneno) sobem 1 degrau a cada 2 atos.

