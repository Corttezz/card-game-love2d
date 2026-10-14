---
name: code_notes/tools/test_shop_sale.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_shop_sale.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_shop_sale.lua`

Origem: `tools/test_shop_sale.lua` em `7dbdb60d` (3 de 10 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-17 (junto a `local TK = require("tools.testkit")`)

> tools/test_shop_sale.lua
> Trava da OFERTA DO DIA (Loja v3 F4, Out/2026 — ShopSystem:applyDailySale,
> Config.Offers.DAILY_SALE):
> 1. flag DESLIGADA (setada à mão: o default é LIGADA desde 13/Out/2026,
> decisão de UX do dono após a bateria shop-sale): nenhuma oferta traz
> saleDiscount e os streams do Rng não andam;
> 2. flag LIGADA (default): UMA e só uma oferta da loja com saleDiscount = pct,
> preço = floor(preço cheio × (1 - pct)), basePrice guardado;
> 3. a recompensa pós-batalha (grátis) NUNCA ganha etiqueta;
> 4. o reroll sorteia de novo (continua 1 e só 1; muda de objeto ao longo
> das seeds); mesma seed → mesma oferta e mesmo preço;
> 5. a etiqueta viaja no save: exportState/importState e o checkpoint
> real (RunManager save → load) devolvem a mesma oferta com o mesmo
> preço e a mesma marca;
> 6. o asset da etiqueta (price_tag_sale.png) existe;
> 7. o knob BALANCE_SHOP_SALE do balance_sim liga a flag.
> love . test_one test_shop_sale

## L77-78 (em `saved`, junto a `local same = true`)

> toda oferta sem etiqueta ficou com o preço de antes (comparando com a
> vitrine gerada com a flag desligada na mesma seed, até a etiqueta)

## L86 (em `saved`, junto a `TK.seedRng(31337)`)

> ===== 3) recompensa nunca =====

