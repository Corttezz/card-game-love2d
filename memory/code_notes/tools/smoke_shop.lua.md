---
name: code_notes/tools/smoke_shop.lua
description: Comentários com decisão/regra/histórico colhidos de tools/smoke_shop.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/smoke_shop.lua`

Origem: `tools/smoke_shop.lua` em `7dbdb60d` (4 de 11 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-3 (junto a `local ShopSystem = require("src.systems.ShopSystem")`)

> tools/smoke_shop.lua
> Valida ShopSystem em modos rewards/shop + booster packs + reroll exponencial.
> love . smoke_shop

## L44-45 (em `typeCounts`, junto a `check("shop: 3 vagas de reliquia", cfg.upgrades == 3)`)

> 3 desde Out/2026: tesoura e bancada de coringa FIXAS + uma rotativa;
> packs 2 -> 1 pra fileira 2 seguir com 4 celulas. Ver test_shop_services.

## L57-60 (em `typeCounts`, junto a `check("sem run, nenhuma vaga vira servico",`)

> Esta loja foi aberta SEM contexto de run (setContext nunca chamado):
> serviço é estado de run, então a tesoura nao tem onde existir e as duas
> vagas caem no pool clássico. Degradar assim é o comportamento certo —
> o que NAO pode é gerar oferta de serviço sem ledger pra cobrá-la.

## L78 (em `typeCounts`, junto a `shop = ShopSystem:new()`)

> Reroll linear Balatro-style: 5 → 7 → 9 → 11 (base + 2/reroll).

