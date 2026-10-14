---
name: code_notes/tools/test_world_props.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_world_props.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_world_props.lua`

Origem: `tools/test_world_props.lua` em `7dbdb60d` (2 de 5 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-17 (junto a `local TK = require("tools.testkit")`)

> tools/test_world_props.lua
> Trava dos PROPS DE ÁRVORE do WorldRoad (Out/2026 — "raízes muito expostas
> no primeiro ato; enfiar um pouquinho mais no chão").
>
> love . test_one test_world_props
>
> (a) toda espécie de árvore sorteável em cada bioma (TREE_KIND + kinds de
> árvore/arbusto em propWeights) tem PNG da variante 0 em
> assets/sprites/world/ — sem isso o sorteio cai no procedural tosco;
> (b) toda entrada de `sink` em src/data/world_props.lua aponta pra PNG
> existente, enterra entre 1 px e SINK_MAX_FRAC da altura, e a linha de
> CONTATO (primeira linha visível) tem tronco opaco — a árvore apoia no
> chão, não flutua sobre um recorte vazio;
> (c) o PNG não tem margem transparente embaixo (crop obrigatório — prop
> com sobra "flutua", ciclo v3.3);
> (d) WorldRoad.propCutInfo segue a cascata de variante do getSprite
> (variante 2 sem PNG herda o sink da 0) e kinds que não enterram dão 0.

## L40-42 (em `M.run`, junto a `local TREE_KIND = { fields = "tree", highlands = "pine", abyss = "deadtree",`)

> (a) espécies por bioma com arte. A espécie da PAREDE (TREE_KIND, a
> mais vista) é obrigatória; outro kind de árvore/arbusto do sorteio
> sem PNG cai no procedural e só AVISA (dívida de arte, não regressão).

