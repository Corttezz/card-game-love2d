---
name: code_notes/shaders/boot_seal_glow.glsl
description: Comentários com decisão/regra/histórico colhidos de shaders/boot_seal_glow.glsl antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `shaders/boot_seal_glow.glsl`

Origem: `shaders/boot_seal_glow.glsl` em `7dbdb60d` (1 de 4 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-10 (junto a `extern vec2 center;`)

> shaders/boot_seal_glow.glsl — CARGA DO SELO (entrada v9, Jul/2026).
> Nada de textura por cima do pixel art: este shader redesenha A PRÓPRIA ARTE
> em blend aditivo, realçando só os pixels CLAROS (entalhes/inlay dourado)
> dentro do disco do selo. Efeito: o selo "carrega" — os sulcos acendem e
> respiram, pulsam a cada carta absorvida e estouram no flash. 100% pixel-
> nativo (o glow É a arte), coeso com o resto da tela.
>
> center   — centro do selo em px de TELA
> radius   — raio do disco em px de TELA (falloff suave até a borda)
> strength — 0..1 intensidade (respiração + flare vêm do Lua)

