---
name: code_notes/shaders/haze.glsl
description: Comentários com decisão/regra/histórico colhidos de shaders/haze.glsl antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `shaders/haze.glsl`

Origem: `shaders/haze.glsl` em `7dbdb60d` (1 de 3 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-24 (junto a `extern vec3 hazeColor;   // cor do céu atrás do objeto ('flat' é reservado)`)

> shaders/haze.glsl
> PERSPECTIVA ATMOSFÉRICA — véu de névoa na SILHUETA de um sprite.
>
> Irmão de shaders/occluder.glsl: usa SÓ o ALPHA da textura pra recortar a
> forma e pinta uma COR CHAPADA (a cor do céu). A diferença é uma linha —
> aqui o ALPHA DA VERTEX COLOR sobrevive, porque é ele que carrega o fator
> de névoa `k`. O occluder devolve alpha 1.0 fixo (ele quer apagar luz por
> completo); aqui o alpha é a dose.
>
> Uso: desenha o sprite normalmente (opaco) e DEPOIS o mesmo sprite por
> este shader, com setColor(1,1,1, k). Com blend alpha/alphamultiply o
> resultado no framebuffer é:
> dst = céu*k + sprite*(1-k)
> ou seja um LERP de verdade em direção à cor do céu — o longe clareia e
> perde contraste, como manda a perspectiva atmosférica.
>
> POR QUE NÃO setColor DIRETO NO SPRITE: setColor MULTIPLICA. Multiply só
> escurece e desvia matiz; nunca LEVANTA o objeto distante em direção ao
> céu. Um "duplo desenho" com setColor daria mix(sprite, sprite*céu, k),
> que continua sendo multiply. Daí a cor chapada.
>
> REGRA (ciclo 24, WorldRoad drawProps): o SPRITE nunca ganha alpha
> parcial — o domo vazaria através das árvores distantes. Quem tem alpha é
> ESTA camada por cima; a opacidade do dono continua 1.

