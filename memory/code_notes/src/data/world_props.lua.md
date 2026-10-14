---
name: code_notes/src/data/world_props.lua
description: Comentários com decisão/regra/histórico colhidos de src/data/world_props.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/data/world_props.lua`

Origem: `src/data/world_props.lua` em `7dbdb60d` (12 de 29 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-20 (junto a `return {`)

> src/data/world_props.lua
> ============================================================================
> METADATA POR SPRITE dos props do mundo (WorldRoad). Tabela pura, sem lógica.
> ============================================================================
> `sink` = quantas linhas de ARTE (px do PNG) ficam ENTERRADAS no chão: o
> WorldRoad recorta essas linhas (quad) e apoia a linha recortada na
> latitude do chão, e a fatia de capim na frente do pé desenha por cima.
>
> Origem (13/Out/2026, pedido do dono): "no primeiro ato as árvores ficam
> com as raízes muito expostas; enfiar um pouquinho mais no chão". Até
> então toda vegetação afundava 4% da altura (ciclo 27), medida pensada
> pra esconder raiz CORTADA no canvas, não pra assentar raiz desenhada.
>
> Régua (medida sprite a sprite, perfil de largura das linhas de baixo):
> enterra a LEVA mais larga das raízes e deixa o alargamento de cima
> aparecendo, pra ler como tronco saindo da terra, sem cortar o tronco.
> Chave = nome do PNG sem extensão (variante 1/2 sem PNG cai na 0 pelo
> getSprite e herda a entrada da 0). Sprite sem entrada = SINK_DEFAULT_FRAC.
> Trava: tools/test_world_props.lua (PNG existe, sink dentro do teto,
> tronco opaco na linha de contato).

## L23-24 (junto a `SINK_DEFAULT_FRAC = 0.04,`)

> fração da altura enterrada quando o sprite não está na tabela
> (arbustos, procedurais): a regra antiga do ciclo 27

## L26 (junto a `SINK_MAX_FRAC = 0.15,`)

> teto: acima disso a árvore perde tronco, não raiz

## L30-33 (em `sink`, junto a `fields_tree_0 = 11,`)

> ATO 1 (fields): raízes em leque, ponta de raiz solta embaixo.
> tree_0 60x89: larguras de baixo pra cima 2,3,7,12,19,30,42,48,47,
> 43,38 → tronco ~18. 11 linhas enterram a leva de 48 px e deixam
> um alargamento de 33 px à vista.

## L35-36 (em `sink`, junto a `fields_tree_1 = 11,`)

> tree_1 104x106: 9,22,44,76,94,86,81,70,66,54,47 → tronco ~20.
> 11 linhas enterram a leva de 94 px; sobra o contraforte de 45 px.

## L39-40 (em `sink`, junto a `highlands_pine_0 = 9,`)

> ATO 2 (highlands): pinheiro com montinho de raiz/neve nas 9
> linhas de baixo (29,57,88,83,74,68,59,52,43 → tronco ~16).

## L43-44 (em `sink`, junto a `abyss_deadtree_0 = 11,`)

> ATO 3 (abyss): garras de raiz em brasa (2,8,18,35,79,100,95,91,
> 88,83,73 → tronco ~34). 11 linhas enterram a leva de 100 px.

## L47-48 (em `sink`, junto a `frost_pine_0 = 5,`)

> ATO 4 (frost): a base é a ponta fina do tronco sob a saia de neve
> (5,14,27,39,48) — não há raiz exposta; mantém ~4%.

## L51-52 (em `sink`, junto a `marsh_deadtree_0 = 7,`)

> ATO 5 (marsh): a arte já traz o montinho de musgo (8,32,63,75,81,
> 95,97) — o montinho É o chão; só a ponta de baixo afunda.

## L55-57 (em `sink`, junto a `dusk_tree_0 = 9,`)

> ATO 6 (dusk): torrão de terra pintado nas 4 linhas de baixo
> (33,70,87,106,101,93,86,81,74 → tronco ~20). 9 linhas enterram o
> torrão e a leva de raiz.

## L60-63 (em `sink`, junto a `fields_tree_2 = 9,          -- carvalho bifurcado 84x106 (…43,50,55,53)`)

> VARIANTES NOVAS (Out/2026, tools/pixellab_trees.py — geradas com a
> árvore do bioma como referência de estilo; julgadas lado a lado em
> tools/preview_out/arvores/variantes_bioma_N.png). Perfil medido
> do mesmo jeito: enterra a leva mais larga da raiz.

## L79-82 (em `sink`, junto a `sizeK = {`)

> Escala RELATIVA por sprite (padrão 1): o WorldRoad normaliza toda
> variante de um kind pra MESMA altura de tela (scaleAt divide pela
> altura do PNG), então um abeto jovem desenhado menor que o adulto
> nasceria do tamanho dele. Fator < 1 = espécie menor de verdade.

