---
name: code_notes/tools/orb_anim_compare.lua
description: Comentários com decisão/regra/histórico colhidos de tools/orb_anim_compare.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/orb_anim_compare.lua`

Origem: `tools/orb_anim_compare.lua` em `7dbdb60d` (2 de 3 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-16 (junto a `local M = {}`)

> tools/orb_anim_compare.lua
> A imagem de aprovação do loop idle das gemas: PARADO x VIVO, no tamanho de
> uso (48px, 1:1) e sobre o fundo escuro da HUD — porque ampliado tudo parece
> bom, e é a 48px que o dono olha.
>
> love . orb_anim_compare [zoom]   -> <save>/orbes_animacao.png
>
> Cada linha é um elemento:
> PARADO   a arte de hoje (assets/sprites/orbs/<t>.png), 1:1;
> VIVO     os frames do loop, 1:1, na ordem em que passam — a fileira
> inteira é o ciclo de 2s;
> ZOOM     frame parado x frame de pico, ampliados, pra conferir que a
> silhueta e a borda escura não mexeram;
> ONDE     mapa do que muda: pixel alterado marcado em branco sobre a
> silhueta apagada. É a medida honesta da dosagem — numa imagem
> parada não dá pra "ver" sutileza, mas dá pra ver QUANTO muda.

## L46-47 (em `framesData`, junto a `local pico, picoN = 1, -1`)

> Frame de PICO: o que mais difere do parado. É o pior caso da dosagem,
> e é ele que tem que continuar parecendo a mesma pedra.

