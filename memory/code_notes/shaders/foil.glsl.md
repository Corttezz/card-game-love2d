---
name: code_notes/shaders/foil.glsl
description: Comentários com decisão/regra/histórico colhidos de shaders/foil.glsl antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `shaders/foil.glsl`

Origem: `shaders/foil.glsl` em `7dbdb60d` (2 de 8 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-7 (junto a `extern number time;`)

> shaders/foil.glsl
> Edition "Foil" — brilho metálico frio, sem cores rainbow (vs Holo).
> Faixa de luz cinzenta-azul deslizando lentamente + ruído metálico fino.
>
> Uniforms:
> time     (number) — segundos
> strength (number) — 0..1 (default 0.6)

## L48 (junto a `outRgb = clamp(outRgb * (1.0 + strength * 0.05), 0.0, 1.4);`)

> Boost de luminância sutil.

