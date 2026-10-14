---
name: code_notes/shaders/light_dither.glsl
description: Comentários com decisão/regra/histórico colhidos de shaders/light_dither.glsl antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `shaders/light_dither.glsl`

Origem: `shaders/light_dither.glsl` em `7dbdb60d` (2 de 10 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-7 (junto a `extern number levels;      // degraus de posterização (4 = poça; 2 = pequena)`)

> shaders/light_dither.glsl
> Sprite de luz do LightEngine: falloff radial (1-d²)² POSTERIZADO em degraus
> + dither Bayer 4x4 opcional, alinhado ao pixel do LIGHTMAP (canvas 1/4 —
> screen_coords aqui são os pixels do render target ativo).
> Desenhado num quad branco 2x2 escalado (UV [0,1]) com blend "add".
> Bayer via if-chain: o GLSL do LÖVE (compat ES/1.20) não aceita
> inicializador de array const (padrão glsl-dither/hughsk).

## L42-43 (junto a `float b = 0.5 + (bayer4(sc) - 0.5) * ditherAmt;`)

> Bayer comprimido pro centro por ditherAmt: reduz o contraste entre
> células vizinhas (xadrez menos gritante), mantendo a quebra de banda

