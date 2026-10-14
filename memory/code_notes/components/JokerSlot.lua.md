---
name: code_notes/components/JokerSlot.lua
description: Comentários com decisão/regra/histórico colhidos de components/JokerSlot.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `components/JokerSlot.lua`

Origem: `components/JokerSlot.lua` em `7dbdb60d` (3 de 19 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-2 (junto a `local JokerSlot = {}`)

> components/JokerSlot.lua
> Componente de slot de joker com design clean e moderno inspirado no Balatro

## L54-55 (em `JokerSlot:update`, junto a `local glowEase = 1 - math.exp(-8 * dt)`)

> Animações suaves via exp decay (consistente com Card e resto do jogo).
> ease = 1 - exp(-k*dt) é mais estável que lerp*dt em frame drops.

## L88 (em `JokerSlot:drawOccupiedSlot`, junto a `local img = require("src.ui.CardFrame").displayImage(self.joker) or self.joker.image`)

> icone vivo como toda carta visivel (dono, 13/Out/2026)

