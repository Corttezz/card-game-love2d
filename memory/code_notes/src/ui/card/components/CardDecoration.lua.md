---
name: code_notes/src/ui/card/components/CardDecoration.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/card/components/CardDecoration.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/card/components/CardDecoration.lua`

Origem: `src/ui/card/components/CardDecoration.lua` em `7dbdb60d` (3 de 47 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-8 (junto a `local Palette     = require("src.ui.Palette")`)

> src/ui/card/components/CardDecoration.lua
> Overlay decorativo sobre a art slot. Desenhado DEPOIS da ilustração,
> antes da borda externa — não contamina header/footer.
>
> Presets existentes: sparks, dust, smoke, flash
> Novos: blood_drips (bg=blood), embers (bg=fire/rage), frost (bg=ice), runes (bg=arcane)
>
> API: CardDecoration.draw(x, y, w, h, name, accentColor)

## L17 (em `registry`, junto a `function registry.sparks(x, y, w, h, accent)`)

> Sparks densos: 2 por canto = 8 pontos ao todo

## L146 (em `pos`, junto a `function registry.poison_bubbles(x, y, w, h, accent)`)

> ===== Tier A decorations (2026-04-20) =====

