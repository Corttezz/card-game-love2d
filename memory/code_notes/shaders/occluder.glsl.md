---
name: code_notes/shaders/occluder.glsl
description: Comentários com decisão/regra/histórico colhidos de shaders/occluder.glsl antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `shaders/occluder.glsl`

Origem: `shaders/occluder.glsl` em `7dbdb60d` (1 de 2 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-10 (junto a `extern vec3 flatColor;   // cor chapada ('flat' é palavra reservada GLSL!)`)

> shaders/occluder.glsl
> Oclusor de silhueta do LightEngine: usa SÓ o ALPHA da textura pra recortar
> o formato e pinta uma COR CHAPADA (flat) — nunca a cor interna do sprite.
>
> BUG que isso corrige: desenhar o sprite com setColor multiplicava
> ambiente × cor-do-sprite no lightmap; no multiply final virava
> sprite × (ambiente × cor) = COR AO QUADRADO → partes escuras do dono
> (corpo do monstro, tronco de árvore) esmagavam pra quase preto. Com a
> cor chapada, o lightmap na silhueta = flat (ambiente ou ambiente×lift),
> e o dono fica em sprite × flat = cor padrão levantada, sem esmagar.

