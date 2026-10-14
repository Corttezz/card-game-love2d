---
name: code_notes/tools/test_combat_reentry.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_combat_reentry.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_combat_reentry.lua`

Origem: `tools/test_combat_reentry.lua` em `7dbdb60d` (3 de 6 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-22 (junto a `local TK = require("tools.testkit")`)

> tools/test_combat_reentry.lua
> Mexer na MÃO enquanto as cartas resolvem.
>
> O defeito (Set/2026, crash na cara do dono no meio de um turno):
>
> src/systems/CombatSequence.lua:170: attempt to index local 'g' (a nil value)
>
> `Game:playSelectedCards` passava `self.selectedCards` — a tabela VIVA — para
> o CombatSequence, que monta a geometria UMA vez e depois percorre a lista
> carta a carta. Enquanto isso `Game:selectCard` continuava aceitando cliques
> e fazendo `table.insert`/`table.remove` NA MESMA TABELA.
>
> Antes do ritmo por beats a resolução durava fração de segundo e ninguém
> conseguia clicar no meio. Com cada acontecimento ocupando seu instante ela
> passou a durar SEGUNDOS, e a janela virou o tamanho de um turno inteiro:
> era só clicar numa carta da mão.
>
> Dois estragos, e o silencioso é o pior:
> SELECIONAR: a carta nova existe em `cards[idx]` e não em `geom[idx]` —
> crash, combate morto no meio do turno.
> DESSELECIONAR: nada quebra. A mana de uma carta que já está sendo
> jogada volta pro jogador, e os índices desalinham.

## L31 (em `M.run`, junto a `local game = TK.newRunGame("warrior")`)

> ===== A mão trava durante a resolução =====

## L56-58 (em `M.run`, junto a `local CombatSequence = require("src.systems.CombatSequence")`)

> ===== A sequencia sobrevive a lista mutando por fora =====
> Mesmo que alguem contorne o guard (outro call site, um teste, um mod), a
> CombatSequence tem que aguentar: ela copia a lista na entrada.

