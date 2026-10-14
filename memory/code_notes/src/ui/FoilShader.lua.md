---
name: code_notes/src/ui/FoilShader.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/FoilShader.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/FoilShader.lua`

Origem: `src/ui/FoilShader.lua` em `7dbdb60d` (1 de 1 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-6 (junto a `local FoilShader = {}`)

> src/ui/FoilShader.lua
> Wrapper do shaders/foil.glsl. Edition "Foil": brilho metálico frio.
> Diferente de Holo (rainbow) — Foil é prata-azulada, mais sutil.
>
> Uso típico em Card:draw quando card.edition == "foil":
> FoilShader.draw(cardImage, x, y, 0.6)

