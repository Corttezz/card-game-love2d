---
name: code_notes/tools/probe_shop_shadow.lua
description: Comentários com decisão/regra/histórico colhidos de tools/probe_shop_shadow.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/probe_shop_shadow.lua`

Origem: `tools/probe_shop_shadow.lua` em `7dbdb60d` (3 de 7 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-6 (junto a `local M = {}`)

> tools/probe_shop_shadow.lua
> Sonda da SOMBRA PROJETADA da loja (v5 r4): pra cada objeto da mesa,
> renderiza a sombra sozinha num canvas na resolução da arte e compara com
> a referência em Lua da mesma projeção (ShopPerspective.castShadowRef):
> pixels pintados, IoU, caixa, altura/largura relativas ao objeto.
> CARDGAME_HEADLESS=1 lovec . test_one probe_shop_shadow

## L25-26 (em `M.alphaReader`, junto a `function M.render(o, what)`)

> Desenha SÓ a sombra projetada de `o` num canvas 640x360 (arte) e devolve
> o conjunto de pixels pintados ({[y*4096+x]=true}), a contagem e a caixa.

## L116-117 (em `M.RELICS`, junto a `function M.objects(scene)`)

> Lista de objetos a sondar: {name, o, alphaAt} (relíquias com cada arte,
> o pacote, o sino e o copo)

