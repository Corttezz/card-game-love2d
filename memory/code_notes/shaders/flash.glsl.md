---
name: code_notes/shaders/flash.glsl
description: Comentários com decisão/regra/histórico colhidos de shaders/flash.glsl antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `shaders/flash.glsl`

Origem: `shaders/flash.glsl` em `7dbdb60d` (2 de 5 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-10 (junto a `extern number time;`)

> shaders/flash.glsl
> Flash branco fullscreen com pulse radial opcional. Implementação própria.
>
> Modos:
> • mid_flash > 0 → overlay branco; intensidade 0..1 controla opacidade.
> • Pulse radial sutil cresce do centro pra borda usando time como animador.
>
> Uniforms:
> time      (number) — segundos desde o início (alimenta a animação radial)
> mid_flash (number, 0..1) — intensidade global do flash (envelope externo)

## L23-24 (junto a `float ring = 0.0;`)

> Pulse radial: anel branco que expande conforme time cresce, com soft edge.
> Funciona como "ring expanding" sobreposto ao flash global.

