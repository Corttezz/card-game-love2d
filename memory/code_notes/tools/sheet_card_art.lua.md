---
name: code_notes/tools/sheet_card_art.lua
description: Comentários com decisão/regra/histórico colhidos de tools/sheet_card_art.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/sheet_card_art.lua`

Origem: `tools/sheet_card_art.lua` em `7dbdb60d` (1 de 1 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-8 (junto a `local M = {}`)

> tools/sheet_card_art.lua
> Folha de contato de TODAS as cartas (canvas estático do CardFrame) em 2x,
> pra revisar o enquadramento da ilustração no slot (topo × base cortados).
>
> love . test_one sheet_card_art [tag]   → card_art_sheet_<tag>_<n>.png
> SHEET_IDS=a,b,c SHEET_SCALE=4 → só essas cartas, na escala pedida
>
> 10 colunas × 5 linhas por folha (50 cartas), ordem por id.

