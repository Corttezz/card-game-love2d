---
name: code_notes/src/ui/card/IconAnimations.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/card/IconAnimations.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/card/IconAnimations.lua`

Origem: `src/ui/card/IconAnimations.lua` em `7dbdb60d` (9 de 25 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-3 (junto a `local Palette = require("src.ui.Palette")`)

> src/ui/card/IconAnimations.lua
> Animações procedurais MUITO SUTIS — apenas sensação de movimento, não transformação visual.
> Alpha baixo (0.2-0.4 max), cycles longos, poucos pixels.

## L10 (em `CATEGORY`, junto a `sword_short = "weapon_shine",`)

> Armas: shine sutil diagonal

## L14 (em `CATEGORY`, junto a `dagger      = "blood_drip",`)

> Adaga/garras/presa: drip sutil

## L36 (em `CATEGORY`, junto a `skull       = "soft_pulse",`)

> Esquelético/lunar: glow sutil

## L47 (em `CATEGORY`, junto a `joker_abyss   = "deity_eyes",`)

> Jokers: imposing cosmic face com eye pulse sutil

## L82 (em `Effects.weapon_shine`, junto a `function Effects.blood_drip(x, y, w, h, t)`)

> Drip sutil: 1 gotinha rara

## L120 (em `Effects.flicker`, junto a `function Effects.soft_pulse(x, y, w, h, t)`)

> Soft pulse: glow muito sutil oscilando

## L140 (em `Effects.shimmer`, junto a `function Effects.deity_eyes(x, y, w, h, t)`)

> Deity eyes pulsing: 2 olhos com glow alternando sutil

## L156 (em `points`, junto a `function Effects.bubble(x, y, w, h, t)`)

> Bubble (poção): bolha muito sutil ocasional

