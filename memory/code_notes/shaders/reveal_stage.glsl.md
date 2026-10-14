---
name: code_notes/shaders/reveal_stage.glsl
description: Comentários com decisão/regra/histórico colhidos de shaders/reveal_stage.glsl antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `shaders/reveal_stage.glsl`

Origem: `shaders/reveal_stage.glsl` em `7dbdb60d` (2 de 11 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-24 (junto a `extern vec2 size;`)

> shaders/reveal_stage.glsl
> PALCO da revelação (components/UnlockShowcase.lua): o brilho atrás do item
> desbloqueado, vivendo na GRADE DE PIXELS da arte — nada de gradiente liso
> nem triângulo vetorial girando (os "raios dourados" v1 eram isso, e o dono
> chamou de "muito tosco").
>
> Tudo é avaliado POR CÉLULA de `cell` px (2 px virtuais = 1 px da arte das
> cartas): o halo radial é posterizado em `levels` degraus com dither Bayer
> 4x4 na célula, e os raios são espinhos de UMA célula de largura com
> decaimento em 3 degraus (cheio / meio / pontilhado). Girar `rot` move os
> espinhos em saltos de célula — borda dura, sem anti-alias.
>
> Desenhado num quad branco 1x1 escalado pra `size` com blend alpha.
>
> Uniforms:
> size    (vec2)   — lado do quad em px (locais ao transform corrente)
> cell    (number) — célula da grade em px
> levels  (number) — degraus do halo (4)
> rays    (number) — nº de espinhos (12); rayOn 0 desliga (reducedMotion)
> rot     (number) — rotação dos espinhos (rad)
> rayOn   (number) — 1 = espinhos ligados
> pulse   (number) — multiplicador do halo (respiração; 1 = parado)
> glowCol (vec3)   — cor do halo
> rayCol  (vec3)   — cor dos espinhos

## L66-67 (junto a `float b = 0.5 + (bayer4(g) - 0.5) * 0.75;`)

> Bayer COMPRIMIDO (0.125..0.875): o limiar cheio (1.0) acendia 1 célula em
> 16 onde o halo já era zero — um pontilhado regular no quad inteiro.

