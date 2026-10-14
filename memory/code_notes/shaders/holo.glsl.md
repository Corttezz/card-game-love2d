---
name: code_notes/shaders/holo.glsl
description: Comentários com decisão/regra/histórico colhidos de shaders/holo.glsl antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `shaders/holo.glsl`

Origem: `shaders/holo.glsl` em `7dbdb60d` (3 de 7 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-27 (junto a `extern number time;`)

> shaders/holo.glsl
> Brilho das cartas raras/lendárias (src/ui/HoloShader.lua) — v2, Out/2026.
>
> A v1 (Abr/2026) era um arco-íris multi-banda misturado na carta INTEIRA,
> animado o tempo todo. Nunca tinha sido vista em jogo (o load() não era
> chamado); quando foi ligada, lavava a cor da arte e punha a mesma listra em
> todas as cartas — contra duas regras do dono: "idle = estático" e "foil que
> lava a cor, nunca".
>
> v2 = REFLEXO, não sobreposição de cor:
> • só acende no ARO da carta (silhueta medida pelo alpha: faixa de 6 px,
> meia-luz até 9 px) e, DENTRO da faixa de varredura, nos pixels de
> brilho da arte (luminância alta — metal, papel claro). O resto da
> ilustração sai IDÊNTICO ao texel: nada de hue-shift sobre a arte.
> • ADITIVO (base + tinta × quantidade), nunca mix — a matiz da arte fica.
> • varredura em DEGRAUS na grade de pixels da carta (núcleo 2 px, meia-luz
> 2 px, rastro em dither 2x2), diagonal "\" como a da carta inédita.
> Só se move com `anim` > 0 (hover/selecionada); em repouso é estática.
> • rara (kind 0) = glint prata-azulado; lendária (kind 1) = dourado
> prismático (3 matizes em degraus ao longo da faixa).
>
> Uniforms:
> time     (number) — segundos (só move a faixa quando anim > 0)
> strength (number) — 0..1 (rara ~0.25 no hover; lendária 0.08 repouso → 0.5)
> kind     (number) — 0 rara, 1 lendária
> anim     (number) — 0..1 (hover/selecionada)
> cardSize (vec2)   — tamanho da textura em px (grade da arte)

## L43-44 (junto a `float nearEdge(Image tex, vec2 uv, vec2 ts, float d) {`)

> 1 se algum vizinho a `d` px (4 direções) é transparente — ou seja, o pixel
> está a menos de `d` px da borda da silhueta.

## L86-88 (junto a `float amt = strength * (frame * 0.6 + max(frame, hi) * band * anim * 1.2);`)

> aro: 0.6 × força (rara no hover 0.15, lendária 0.05 em repouso → 0.3) —
> com 0.35 o glint prata da rara sumia dentro do dourado da moldura e
> rara/lendária só se distinguiam pela faixa. Faixa: 1.2 × força.

