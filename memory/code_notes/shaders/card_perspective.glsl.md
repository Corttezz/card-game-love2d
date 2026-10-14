---
name: code_notes/shaders/card_perspective.glsl
description: Comentários com decisão/regra/histórico colhidos de shaders/card_perspective.glsl antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `shaders/card_perspective.glsl`

Origem: `shaders/card_perspective.glsl` em `7dbdb60d` (7 de 10 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-20 (junto a `extern vec2 mouse;`)

> shaders/card_perspective.glsl
> Perspective warp estilo Balatro pra cartas — aplica deformação per-vertex
> baseada em mouse position + hover intensity + wobble idle sutil.
>
> Uso: draw com love.graphics.draw(mesh, ...) com este shader ativo.
> Mesh deve ter tessellação suficiente (~8×12 = 96 verts) pra distorção suave.
>
> Uniforms:
> mouse    (vec2)   — posição do mouse em [-1, 1] relativo ao centro da carta
> (-1,-1 top-left; +1,+1 bottom-right; 0,0 = centro/neutro)
> hover    (number) — intensidade 0..1 do efeito (smoothed)
> time     (number) — segundos acumulados pro wobble
> cardSize (vec2)   — largura/altura do canvas em pixels
> quadOn   (number) — 1 = modo QUADRILÁTERO (Loja v3c: carta no cavalete
> em perspectiva real). A carta inteira é mapeada pela
> homografia hRow0..2 (quadrado unitário → 4 cantos em
> coordenadas do mundo); o press/wobble somam por cima.
> 0 = comportamento antigo. CardMesh.setUniforms zera
> SEMPRE (o shader é compartilhado: quem não usa o modo
> nunca herda o quadrilátero da loja).

## L30-31 (junto a `extern number silhouette;`)

> Loja v5: 1 = desenha só a SILHUETA da carta na cor do setColor (contorno
> de hover/seleção que acompanha o tilt). CardMesh.setUniforms zera sempre.

## L41-42 (junto a `float proj = dot(centered, mouse);`)

> Projeção do vertex no vetor mouse: vertex "atrás" do mouse (mesmo lado)
> tem proj positiva; vertex oposto tem proj negativa.

## L45-47 (junto a `float pressAmount = -proj * hover * 0.12;`)

> Press effect: canto COM mouse AFUNDA (contrai em direção ao centro);
> canto oposto LEVANTA (se afasta). Sinal NEGATIVO inverte a direção.
> Amplitude 0.12 — Balatro-like sutil, não exagera.

## L50 (junto a `float wobble = sin(time * 2.0 + centered.x * 4.0) * 0.005 * hover`)

> Wobble idle sutil — só quando hover > 0.

## L54-55 (junto a `vec2 disp = centered * cardSize * (pressAmount + wobble);`)

> Vertex próximo do mouse: pressAmount negativo → vertex CONTRAI (move pro centro).
> Vertex oposto: pressAmount positivo → vertex EXPANDE (afasta do centro).

## L57-61 (junto a `if (quadOn > 0.5) disp *= (1.0 - uv.y);`)

> Loja v5: no modo quad a carta está EM PÉ num cavalete — a base fica
> PRESA no trilho e o tilt gira em torno dela (peso 0 na base, 1 no
> topo). Sem isso o press subia a base 3% da altura: fresta entre a
> carta e o suporte, a carta "levitando". Espelho em Lua:
> ShelfItem.warpUV (test_shop_scene trava a base parada).

