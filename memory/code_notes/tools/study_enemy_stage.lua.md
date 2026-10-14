---
name: code_notes/tools/study_enemy_stage.lua
description: Comentários com decisão/regra/histórico colhidos de tools/study_enemy_stage.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/study_enemy_stage.lua`

Origem: `tools/study_enemy_stage.lua` em `7dbdb60d` (2 de 12 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-20 (junto a `local M = {}`)

> tools/study_enemy_stage.lua
> ESTUDO do palco da batalha: onde o inimigo para na estrada e o quanto ele
> colide com a mão (carta em hover + tooltip da carta) em 3 tamanhos.
>
> love . test_one study_enemy_stage            -> distâncias 9,10,11,12,13
> love . test_one study_enemy_stage 9,11,13    -> lista própria
> love . test_one study_enemy_stage auto,shots -> + PNG de toda cena
>
> Pra cada (tamanho × distância × ato × tipo de nó) desenha o GameplayScene
> REAL num canvas com a janela FALSIFICADA (setMode repetido trava tool —
> CLAUDE.md), com o mouse falso sobre a carta do meio, e mede:
> enemy  = sprite + cluster do EnemyHud (EnemyHud.layout().rect)
> card   = Card.lastDrawRect da carta em hover
> tip    = CardInfoDisplay.lastRect (descrição da carta)
> Saída: tabela no console + stage_<W>x<H>_rel<R>_<ato>_<no>.png no save dir
> (só as cenas da prancha, ou todas com "shots").
>
> Distância 'rel' é a WorldRoad.BATTLE_REL candidata; o tamanho do inimigo
> segue a perspectiva do mundo (WorldRoad.battleSizeK). Chefe luta no salão:
> lá a distância não se aplica, só entra pra medir.

## L133-134 (em `love.graphics.getDimensions`, junto a `if type(rel) == "number" then`)

> número = palco FIXO (near = far = rel); "auto" = o palco real
> (battleRelFor pela zona da mão em hover)

