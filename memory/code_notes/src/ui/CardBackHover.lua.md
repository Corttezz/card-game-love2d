---
name: code_notes/src/ui/CardBackHover.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/CardBackHover.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/CardBackHover.lua`

Origem: `src/ui/CardBackHover.lua` em `7dbdb60d` (3 de 8 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-16 (junto a `local Config = require("src.core.Config")`)

> src/ui/CardBackHover.lua
> State machine de hover pra CardBack — replica a lógica de Card:updateMouse
> (src/cards/base/Card.lua:394+) num formato standalone reutilizável.
>
> Como Card.lua tem ~700 LOC com lifecycle de gameplay (drag, drop, dissolve,
> juice, etc), aqui extraímos só a parte de hover/tilt pra usar em cartas
> decorativas (menu floaters, splash flying cards) sem precisar instanciar
> Card real.
>
> Uso:
> Por carta, mantém um state table:
> local state = CardBackHover.new()
>
> Por frame:
> CardBackHover.update(state, mx, my, cx, cy, w, h, dt)
> CardBack.draw(cx, cy, w, h, state)   -- state já tem tiltX/tiltY/hoverStrength/etc

## L41-46 (em `CardBackHover.new`, junto a `function CardBackHover.update(state, mx, my, cx, cy, w, h, dt, liftDir)`)

> Calcula tilts/lift/etc baseado em mouse + bounding box.
> mx, my       = posição do mouse
> cx, cy       = centro da carta
> w, h         = dimensões renderizadas
> dt           = delta time (pra ambient breathing)
> liftDir      = "up" (default) ou "down" (cartas da mão descem no hover)

## L83-84 (em `CardBackHover.update`, junto a `local AMBIENT_SPEED  = Config.Cards.AMBIENT_TILT_SPEED  or 1.4`)

> Ambient tilt (Balatro-style breathing, mesmo Card.lua faz).
> Onda senoidal defasada por seed (evita sincronia entre cartas).

