---
name: code_notes/src/ui/Theme.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/Theme.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/Theme.lua`

Origem: `src/ui/Theme.lua` em `7dbdb60d` (2 de 61 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-3 (junto a `local Palette = require("src.ui.Palette")`)

> src/Theme.lua
> Sistema de design profissional — paleta grimório sépia (alinhada com Palette.lua).
> Todas as cores derivam dos tons PARCHMENT / INK / BLOOD / STEEL / AGED_GOLD / MOSS / RUST.

## L194 (em `interpolateColor`, junto a `local c1 = {`)

> Garante que as cores tenham 4 componentes (RGBA)

