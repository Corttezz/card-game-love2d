---
name: code_notes/src/ui/DissolveShader.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/DissolveShader.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/DissolveShader.lua`

Origem: `src/ui/DissolveShader.lua` em `7dbdb60d` (5 de 17 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-17 (junto a `local DissolveShader = {}`)

> src/ui/DissolveShader.lua
> Wrapper do shaders/dissolve.glsl. Faz uma imagem "queimar" gradualmente
> com uma mask de noise field + borda colorida (burn colours).
>
> Uso canônico em Card:draw (já integrado se self.dissolve > 0):
> DissolveShader.apply(cardImage, dissolve, burnColors)
> love.graphics.draw(cardImage, x, y, ...)
> DissolveShader.clear()
>
> Ou direto:
> DissolveShader.draw(image, x, y, dissolveAmount, burnColors)
>
> dissolve = 0 → carta visível normal
> dissolve = 0.5 → meio queimada, borda de queima no meio
> dissolve = 1 → sumiu totalmente
>
> burnColors: {c1, c2} — cada c = {r, g, b, a} em [0..1]. Default: laranja/vermelho.

## L43-44 (em `DissolveShader.isAvailable`, junto a `function DissolveShader.apply(image, dissolve, burnColors, isShadow, noiseScale)`)

> Seta o shader como ativo e envia uniforms. Chame antes do love.graphics.draw
> e DissolveShader.clear() depois.

## L53-54 (em `DissolveShader.apply`, junto a `shader:send("noise_scale", noiseScale or { 0, 0 })`)

> noise_scale: {0,0} = legado (cartas). Quads muito largos (banner)
> passam escala anisotrópica pra célula de noise ficar ~quadrada.

## L59-60 (em `DissolveShader.apply`, junto a `shader:send("texture_details", {0, 0, w, h})`)

> texture_details: (offset_x, offset_y, size_x, size_y) em unidades UV
> do atlas; pra textura inteira, offset=0 e size=w,h em pixels.

## L86-87 (em `DissolveShader.draw`, junto a `function DissolveShader.palette(kind)`)

> Paletas canônicas por tipo de carta (mesma filosofia do Balatro).
> Use em Card:start_dissolve(DissolveShader.palette("attack"))

