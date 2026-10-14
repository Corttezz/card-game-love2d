---
name: code_notes/tools/balance_sync_desc.lua
description: Comentários com decisão/regra/histórico colhidos de tools/balance_sync_desc.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/balance_sync_desc.lua`

Origem: `tools/balance_sync_desc.lua` em `7dbdb60d` (1 de 1 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-10 (junto a `local M = {}`)

> tools/balance_sync_desc.lua
> Reescreve o campo `description` (fallback PT) de cada carta em
> src/data/cards/*.lua com a descricao pt_BR RENDERIZADA dos locales.
>
> Por que: o `description` dos dados so aparece se a chave de traducao
> faltar — e por isso apodrecia a cada rebalance ("7 de dano" com attack 8).
> A fonte da verdade do texto e o locale; este campo vira espelho dele.
> Rodar depois de mexer em numero de carta:
> love . test_one balance_sync_desc
> (a trava test_card_audit cobra o espelho em dia).

