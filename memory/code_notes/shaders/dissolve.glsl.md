---
name: code_notes/shaders/dissolve.glsl
description: Comentários com decisão/regra/histórico colhidos de shaders/dissolve.glsl antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `shaders/dissolve.glsl`

Origem: `shaders/dissolve.glsl` em `7dbdb60d` (5 de 19 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-20 (junto a `extern number dissolve;`)

> shaders/dissolve.glsl
> Dissolve / materialize com value noise FBM + threshold animado + edge glow.
> Implementação própria — não derivada do código do Balatro.
>
> Algoritmo:
> 1) Calcula UV centralizado (0..1) e distância radial pra centro.
> 2) FBM (4 oitavas de value noise hash-based) lentamente animado em time.
> 3) threshold = dissolve com bias radial (cantos saem antes do centro).
> 4) Pixels com noise < threshold são "queimados" (alpha=0).
> 5) Banda fina ao redor do threshold recebe burn_colour_1/2 (chama).
> 6) Tint global em direção a burn_colour_2 conforme dissolve cresce.
>
> Uniforms expostos (compat com src/ui/DissolveShader.lua):
> dissolve        (number, 0..1)  — 0 visível, 1 sumiu.
> time            (number)        — segundos (fonte de animação)
> texture_details (vec4)          — (off_x, off_y, w, h) em pixels do quad
> image_details   (vec2)          — (image.w, image.h) — não usado, mantido p/ compat
> shadow          (bool)          — true → tudo vira sombra preta semitransparente
> burn_colour_1   (vec4)          — cor primária da chama (banda interna)
> burn_colour_2   (vec4)          — cor secundária (banda externa)

## L29-32 (junto a `extern vec2 noise_scale;`)

> Escala do campo de noise em CÉLULAS por eixo. (0,0) = legado (5.5 iso,
> cartas). Quads muito largos (banner full-width) passam escala anisotrópica
> pra célula ficar ~quadrada em pixels — sem isso a queima vira "faixas
> fantasmas" esticadas em vez de buracos de fogo.

## L89 (junto a `n += 0.08 * sin(uv.x * 9.0 + time * 0.6) * cos(uv.y * 7.0 - time * 0.5);`)

> Pequena ondulação extra pra borda mais "viva" (não copia 3-sines do Balatro).

## L93-94 (junto a `float biased = dissolve + (radial - 0.5) * 0.35 * dissolve;`)

> Threshold com bias: dissolve efetivo cresce mais nas bordas.
> Quando dissolve=1, threshold sempre > n: tudo sumiu.

## L98-99 (junto a `float band = 0.10 + 0.06 * (1.0 - abs(dissolve - 0.5) * 2.0);`)

> Banda de queima: largura proporcional, mas mínima fixa pra não sumir
> visualmente quando dissolve está em 0.95+.

