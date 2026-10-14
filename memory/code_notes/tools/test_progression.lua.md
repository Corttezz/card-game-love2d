---
name: code_notes/tools/test_progression.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_progression.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_progression.lua`

Origem: `tools/test_progression.lua` em `7dbdb60d` (6 de 19 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-5 (junto a `local TK = require("tools.testkit")`)

> tools/test_progression.lua
> Progressão da run: RunManager (deck/jokers/atos), MapManager (nós),
> ActSystem (curvas de HP/dano por ato/andar, endless, cura inter-ato).
> Conferido em RunManager.lua, MapManager.lua, ActSystem.lua.
> love . test_progression

## L49 (em `M.run`, junto a `local deckSizeBefore = #run.currentDeck`)

> jokers: separados do deck (invariante Balatro)

## L63-71 (em `M.run`, junto a `local rm2 = RunManager:new(); rm2:startNewRun("mage")`)

> advanceFloorInAct: transições.
>
> SEM ARGUMENTO, DE PROPOSITO. Estas asserções passavam `3` cravado — o
> mesmo literal que os chamadores de produção passavam — e por isso
> exercitavam o PARAMETRO, nunca a configuração do jogo. Quando a
> campanha foi pra 6 atos, a run virava endless ao fim do ato 3, o
> `checkVictory` (que retorna false em endless) deixava o jogo
> IMPOSSIVEL DE VENCER, e estes testes seguiram verdes. Passar o mesmo
> literal errado dos dois lados é um teste que confirma a si mesmo.

## L82-84 (em `M.run`, junto a `local rmFull = RunManager:new(); rmFull:startNewRun("warrior")`)

> A CAMPANHA INTEIRA, ato a ato: nenhum ato do meio pode virar endless.
> É a trava que faltava — o defeito não estava no fim, estava em CADA
> fronteira depois do 3.

## L123-126 (em `fa`, junto a `local savedPower = Config.Game.ENEMY_POWER`)

> ===================== ACTSYSTEM =====================
> battle: curva do ato (HP e dano floored). A CURVA crua e testada sem a
> forca global do inimigo (Config.Game.ENEMY_POWER); o knob tem teste
> proprio logo abaixo.

## L165-167 (em `Config.Game.ENEMY_POWER_BY_ACT`, junto a `local primeiroEndless = Config.TotalActs + 1`)

> endless: floor 1 == base do ULTIMO ato (fator 1.0), depois 1.18^(f-1).
> Ancorado em Config.TotalActs: a campanha foi de 3 pra 6 atos em Set/2026
> e um "4" cravado aqui virou silenciosamente um ato normal.

