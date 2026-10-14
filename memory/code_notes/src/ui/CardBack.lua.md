---
name: code_notes/src/ui/CardBack.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/CardBack.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/CardBack.lua`

Origem: `src/ui/CardBack.lua` em `7dbdb60d` (7 de 19 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-21 (junto a `local Palette  = require("src.ui.Palette")`)

> src/ui/CardBack.lua
> Desenha a "costa" (verso) de uma carta usando o MESMO pipeline 3D que
> Card.lua usa em hover (CardMesh + shader card_perspective.glsl + sombra
> direcional). Diferença vs Card.lua: aqui é só uma textura PNG estática,
> sem mesh de art slot / banner / overlay holo. Mas o WARP de perspectiva
> e a sombra são idênticos.
>
> Estratégia:
> 1. Tenta carregar `assets/cards/back.png` (gerado via PixelLab).
> 2. Se ausente, fallback geométrico (corpo INK + borda gold + sigilo).
>
> Compartilhado por BootScene (cascade do splash) e Menu (cartas flutuantes).
>
> Uso (com hover state):
> CardBack.draw(cx, cy, w, h, {
> alpha = 1, scale = 1, rot = 0, dissolve = 0,
> tiltX = 0, tiltY = 0,             -- radianos (em TILT_RANGE units)
> hoverStrength = 0,                -- 0..1 (intensidade do warp)
> liftOffset = 0,                   -- pixels (negativo = sobe)
> perspectiveRotation = 0,          -- radianos (Z tilt)
> })

## L34-37 (em `CardBack`, junto a `local CORNER_RADIUS = 5`)

> Raio em pixels do chamfer dos 4 cantos (na resolução nativa do PNG).
> 5 px no PNG 192x288 = ~3 px quando renderizado a 96x144. Suficiente pra
> esconder o pixel preto no canto e fazer a sombra acompanhar a borda
> arredondada (sombra herda alpha mask do mesh + textura).

## L40-42 (em `CardBack`, junto a `local function roundCorners(imgData, r)`)

> Aplica alpha-mask circular em cada canto da ImageData. Pixels fora do
> arco viram (0,0,0,0) — assim a textura passa a ter cantos transparentes,
> e o shader (que multiplica color * texel) propaga isso pro shadow também.

## L70 (em `loadBackImage`, junto a `local okData, imgData = pcall(love.image.newImageData, BACK_PATH)`)

> Load ImageData (mutável) pra arredondar cantos antes de virar Image.

## L89-90 (em `loadBackImage`, junto a `function CardBack.getImage()`)

> Imagem do verso (nil se o PNG não existir) — quem precisa compor o verso
> num canvas próprio (Coleção: carta não descoberta) usa direto.

## L100-101 (em `CardBack.reload`, junto a `local TILT_RANGE              = 0.15`)

> Constantes de hover/sombra. Mesmos valores que Card.lua usa via
> Config.Cards (TILT_RANGE 0.15, SHADOW_BASE_OFFSET_Y 6, etc).

## L139-140 (em `mouseUV`, junto a `local totalLift = liftOffset - BASE_LIFT`)

> Baseline lift: BASE_LIFT (carta flutua) + liftOffset (hover lift).
> Negativo = carta sobe.

