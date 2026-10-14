---
name: code_notes/tools/screenshot_upgrades.lua
description: Comentários com decisão/regra/histórico colhidos de tools/screenshot_upgrades.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/screenshot_upgrades.lua`

Origem: `tools/screenshot_upgrades.lua` em `7dbdb60d` (7 de 11 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-11 (junto a `local M = {}`)

> tools/screenshot_upgrades.lua
> Vitrine de UPGRADES (vouchers) da loja: forja, vida maxima, mana maxima.
>
> Captura o MESMO slot com os 3 upgrades do catalogo, em repouso e em hover,
> mais um zoom 3x do tile (o defeito mora no detalhe fino: hierarquia de
> nome/efeito/preco) e o painel de detalhe correspondente.
>
> love . test_one screenshot_upgrades
>
> Saida: save dir do LOVE (~/AppData/Roaming/LOVE/card-game/).
> Nomes: upg_<id>_repouso.png / upg_<id>_hover.png / upg_<id>_zoom.png

## L37-39 (em `M.run`, junto a `_G.TOOL_FORCE_LOCALE = (locale and locale ~= "-") and locale or "pt_BR"`)

> Captura DETERMINISTICA no idioma (o force tem que vir antes do init --
> ver o comentario em I18n.init). Roda por `test_one`, entao o force que
> o main.lua aplica aos tools screenshot_* nao chega aqui.

## L127-128 (em `snapZoom`, junto a `voucher.id = v.id`)

> Reescreve a oferta em cima do MESMO slot: o tile e o painel sao os
> mesmos, so muda o conteudo (e assim se compara maca com maca).

## L161-162 (em `snapZoom`, junto a `screen:clearSelection()`)

> Sem ouro: o tile inteiro escurece (2o canal, alem do preco vermelho) --
> mesma regra do saleDim das cartas.

## L171-173 (em `snapZoom`, junto a `do`)

> ESCALAS: o mesmo tile nos tamanhos que a janela produz, lado a lado.
> Mostra ONDE o chip cai e se o texto continua legivel sem depender de
> redimensionar a janela de verdade (setMode repetido trava o tool).

## L197-199 (em `sizes`, junto a `do`)

> reducedMotion: sem bob, sem brasas, sem pulinho -- MAS nome, chip,
> preco e destaque de foco continuam todos la (a flag remove movimento,
> nunca informacao).

## L221-222 (em `sizes`, junto a `voucher.effect = "increase_max_health"   -- sem abrir o picker da forja`)

> COMPRA: a reliquia sobe e se apaga, o efeito sobe escrito, o slot vira
> VENDIDO. Tres paradas pra ver o gesto inteiro.

