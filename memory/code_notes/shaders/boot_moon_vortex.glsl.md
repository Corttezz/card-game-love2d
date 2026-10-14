---
name: code_notes/shaders/boot_moon_vortex.glsl
description: Comentários com decisão/regra/histórico colhidos de shaders/boot_moon_vortex.glsl antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `shaders/boot_moon_vortex.glsl`

Origem: `shaders/boot_moon_vortex.glsl` em `7dbdb60d` (3 de 13 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-14 (junto a `extern number t;`)

> shaders/boot_moon_vortex.glsl — PORTAL NA LUA (entrada v14).
> v12 girava os PRÓPRIOS pixels do disco — rotação de pixel art vira sopa
> borrada/serrilhada (feedback do dono: "o estranho é a lua em si").
> v14: a arte da lua fica INTACTA; por cima, BRAÇOS DE ESPIRAL luminosos
> procedurais (espiral logarítmica, 2 braços — casa com a correnteza das
> cartas) travados na GRADE do pixel art (floor no px da arte = bandas
> chunky, não gradiente liso), + um OLHO de dreno escurecendo no centro.
> Lê como portal respirando, não liquidificador.
>
> t          — tempo do SPLASH (bounded; getTime() enrolaria o miolo infinito)
> moon_uv    — centro da lua em UV da textura
> tex_size   — dimensões da arte em px (256,192)
> radius_px  — raio do disco em px da ARTE
> strength   — 0..1 (carga da lua + flare)

## L23-24 (junto a `vec2 ap = floor(uv * tex_size) + 0.5;`)

> trava no GRID do pixel art: o padrão é calculado no CENTRO do texel —
> braços em degraus chunky, coerentes com a arte

## L45-47 (junto a `number gaps = 1.0 - arms;`)

> Num disco quase BRANCO, braço aditivo não aparece (satura) — a
> estrutura vem da SOMBRA: os VÃOS entre os braços escurecem (sombra
> quente de âmbar), os braços ficam na luz natural + toque dourado.

