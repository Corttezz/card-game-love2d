---
name: code_notes/tools/preview_card_art_fix.lua
description: Comentários com decisão/regra/histórico colhidos de tools/preview_card_art_fix.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/preview_card_art_fix.lua`

Origem: `tools/preview_card_art_fix.lua` em `7dbdb60d` (1 de 2 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-9 (junto a `local M = {}`)

> tools/preview_card_art_fix.lua
> Contact sheet de validacao do fix de arte repetida (2026-09).
> Renderiza as 12 cartas que estavam ORFAS no atlas `src/data/card_art.lua`
> lado a lado com as 4 cartas com que elas colidiam no fallback por tipo
> (potion_red / skull / dagger / shield_kite). Se alguma dupla ainda parecer
> a mesma foto, aparece no mesmo contact sheet.
>
> Roda: love . preview_card_art_fix
> Saida: <saveDir>/cardartfix_sheet.png

