---
name: code_notes/tools/test_sustain_knobs.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_sustain_knobs.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_sustain_knobs.lua`

Origem: `tools/test_sustain_knobs.lua` em `7dbdb60d` (3 de 10 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-4 (junto a `local TK = require("tools.testkit")`)

> tools/test_sustain_knobs.lua
> wip/sustain (Out/2026): os flags das 3 propostas de sustento DISPARAM de
> verdade (senão a bateria mede um no-op) e, desligados, o jogo é o de antes.
> love . test_one test_sustain_knobs

## L20 (em `body`, junto a `t:truthy("SUSTAIN_GUARANTEE ligado por padrão", CO.SUSTAIN_GUARANTEE)`)

> Sustento garantido foi ADOTADO (13/Out/2026): o default é LIGADO.

## L114-115 (em `g.runManager.currentRun.currentNode`, junto a `local sustainId`)

> Carta de DECK (coringa bifurca pra jokers e não conta no deck) e ordem
> determinística: `pairs` já sorteou um coringa aqui e derrubou a suíte.

