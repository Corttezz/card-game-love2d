---
name: code_notes/tools/test_balance_ai.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_balance_ai.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_balance_ai.lua`

Origem: `tools/test_balance_ai.lua` em `7dbdb60d` (3 de 8 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-6 (junto a `local TK = require("tools.testkit")`)

> tools/test_balance_ai.lua
> Trava do CEREBRO v6 do piloto (tools/balance_ai.lua): situacoes de turno
> com resposta certa conhecida. O piloto e o instrumento de balanceamento —
> se ele joga mal, o relatorio de winrate mede o piloto, nao o jogo.
>
> love . test_one test_balance_ai

## L46 (em `M.run`, junto a `do`)

> 1) Turno LIVRE (inimigo vai se buffar): gastar a mana em DANO, nunca passar.

## L97-98 (em `g.player.orbs`, junto a `do`)

> 6) Mao de CICLO + 1 ataque contra inimigo que nao bate: o ataque entra
> no plano (o caso que travava o piloto v5 e que o T capado escondia).

