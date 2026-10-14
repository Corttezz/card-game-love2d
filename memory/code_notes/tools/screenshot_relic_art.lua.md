---
name: code_notes/tools/screenshot_relic_art.lua
description: Comentários com decisão/regra/histórico colhidos de tools/screenshot_relic_art.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/screenshot_relic_art.lua`

Origem: `tools/screenshot_relic_art.lua` em `7dbdb60d` (3 de 5 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-10 (junto a `local M = {}`)

> tools/screenshot_relic_art.lua
> Confere a ARTE das 4 reliquias de servico que nasceram sem PNG (o tile
> mostrava so o halo): bancada, tesoura, duplicar e cofre. Mesmo slot da
> vitrine, repouso + zoom 3x + hover (hover liga o loop de vouchers_anim).
> Derivado de screenshot_upgrades.lua (so troca as variantes).
>
> love . test_one screenshot_relic_art
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

