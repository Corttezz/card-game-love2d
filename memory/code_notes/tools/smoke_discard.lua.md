---
name: code_notes/tools/smoke_discard.lua
description: Comentários com decisão/regra/histórico colhidos de tools/smoke_discard.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/smoke_discard.lua`

Origem: `tools/smoke_discard.lua` em `7dbdb60d` (3 de 16 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-3 (junto a `local Game = require("src.core.Game")`)

> tools/smoke_discard.lua
> Valida pilha de descarte + reshuffle (fix do soft-lock com starter de 2 cartas).
> love . smoke_discard

## L77-82 (em `g4._exhaustedThisBattle`, junto a `local g5 = Game:new()`)

> 6. Joker NAO vai pro discard. Coringas = coleção + bancada (CLAUDE.md):
> o destino do joker é a coleção da run (via addJokerToRun), não o
> discard. Este é um smoke do DESCARTE — garante só que joker não polui
> a pilha. (Roteamento pra bancada/slots é coberto por test_combat.)
> Atualizado no merge Jul/2026 (o assert antigo "vai pra jokerSlots"
> encodava o roteamento direto pré-refactor).

## L105 (em `g6.selectedCards`, junto a `local Config = require("src.core.Config")`)

> 8. drawForTurn (F1): draw FIXO de CARDS_PER_TURN (5), mao ja descartada

