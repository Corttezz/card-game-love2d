---
name: code_notes/tools/preview_shop_props.lua
description: Comentários com decisão/regra/histórico colhidos de tools/preview_shop_props.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/preview_shop_props.lua`

Origem: `tools/preview_shop_props.lua` em `7dbdb60d` (2 de 8 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-17 (junto a `local M = {}`)

> tools/preview_shop_props.lua
> Prancha HEADLESS dos props vivos da loja (src/ui/shop/ShopProps.lua), sem
> depender da cena da loja: renderiza cada prop num canvas em instantes
> escolhidos e salva PNGs no diretório de save (e copia pra
> tools/preview_out/shop_props/ quando o caminho do projeto é gravável).
>
> lovec . test_one preview_shop_props            -- prancha completa
> PROPS_SCALE=3 lovec . test_one preview_shop_props
>
> Saída:
> shop_props_sheet.png   lanterna (3 quadros + luz nos 3 níveis + poça nos
> 5 passos), copo (repouso / chacoalho / deitado com
> os dados 3+4), mariposa em 4 instantes da
> travessia, teia, etiqueta — em movimento normal
> shop_props_reduced.png a mesma prancha com reducedMotion ligado
> shop_props_scene.png   a FACHADA (update/drawBack/drawLantern/
> drawDiceCup/drawFront) num layout fake de balcão

## L106-107 (em `scribeDice`, junto a `local my = foot + 24`)

> ===== mariposa: 4 instantes da travessia =====
> d = posição ao longo do voo (px de sprite, -SPAN..SPAN); t = d/velocidade

