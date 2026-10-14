---
name: code_notes/tools/preview_cards.lua
description: Comentários com decisão/regra/histórico colhidos de tools/preview_cards.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/preview_cards.lua`

Origem: `tools/preview_cards.lua` em `7dbdb60d` (4 de 13 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-5 (junto a `local M = {}`)

> tools/preview_cards.lua
> Renderiza algumas cartas e salva PNGs pra inspeção. Usar: love . preview_cards
>
> Inclui pelo menos uma carta de cada raridade (common/uncommon/rare/legendary)
> pra validar o styling ornamentado do CardHeader.

## L21-22 (em `M.run`, junto a `local jobs = {`)

> Cada entry: {id, rarityOverride?} — rarityOverride permite testar a mesma
> carta em raridades diferentes (já que não existem attack/defense legendary).

## L24 (em `jobs`, junto a `{ "warrior_bastion",         nil },`)

> NOVAS (gameplay-overhaul Jul/2026)

## L90-91 (em `cloned`, junto a `if override then CardFrame.invalidate(cloned) end`)

> Bypass cache do CardFrame quando há override (ID modificado já evita,
> mas garantimos chamando invalidate antes).

