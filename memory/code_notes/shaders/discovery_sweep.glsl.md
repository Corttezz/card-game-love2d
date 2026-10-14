---
name: code_notes/shaders/discovery_sweep.glsl
description: Comentários com decisão/regra/histórico colhidos de shaders/discovery_sweep.glsl antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `shaders/discovery_sweep.glsl`

Origem: `shaders/discovery_sweep.glsl` em `7dbdb60d` (1 de 4 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-15 (junto a `extern vec2 mouse;`)

> shaders/discovery_sweep.glsl
> Varredura de luz da carta INÉDITA (src/ui/DiscoveryMark.lua). Desenhada em
> modo "add" por cima da carta, pelo MESMO mesh do card_perspective — o vertex
> shader é o mesmo warp, então a luz acompanha o tilt do hover.
>
> A luz mora na GRADE DE PIXELS da carta (96x144): a faixa é diagonal em
> degraus inteiros, núcleo cheio, meia-luz e um rastro em dither Bayer 2x2 —
> nada de gradiente liso (forma vetorial lisa sobre arte pixel lê como
> "cara de IA"). Só acende onde a carta é opaca: segue a silhueta da moldura.
>
> Uniforms:
> mouse, hover, time, cardSize — idem card_perspective.glsl
> sweep    (number) — posição da faixa ao longo da diagonal (px da carta)
> strength (number) — 0..1
> tint     (vec3)   — cor da luz

