---
name: code_notes/shaders/posterize.glsl
description: Comentários com decisão/regra/histórico colhidos de shaders/posterize.glsl antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `shaders/posterize.glsl`

Origem: `shaders/posterize.glsl` em `7dbdb60d` (1 de 6 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-9 (junto a `extern number levels;   // degraus por canal (4)`)

> shaders/posterize.glsl — POSTERIZA um canvas em `levels` degraus por canal
> (cor e alpha) com dither Bayer 4×4 na grade de `block` px de tela.
>
> Uso (BossCinematic, névoa colorida da cinemática de chefe): a névoa é a
> soma de dezenas de puffs translúcidos e o resultado da soma é um
> gradiente LISO ("forma vetorial suave", a cara de IA que o dono aponta em
> pixel art). Desenhada num canvas e composta por aqui, vira degraus na
> grade da arte, como a bruma do WeatherEngine e a poça da lanterna da loja.
> Matemática própria (Bayer recursivo 2×2 → 4×4), nada copiado.

