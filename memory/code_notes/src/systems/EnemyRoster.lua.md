---
name: code_notes/src/systems/EnemyRoster.lua
description: Comentários com decisão/regra/histórico colhidos de src/systems/EnemyRoster.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/systems/EnemyRoster.lua`

Origem: `src/systems/EnemyRoster.lua` em `7dbdb60d` (7 de 7 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-12 (junto a `local EnemyKits = require("src.data.enemies")`)

> src/systems/EnemyRoster.lua
> QUEM o jogador enfrenta em cada nó (Out/2026).
>
> Auditoria de conteúdo: o roster era UM monstro comum por ato pra toda
> batalha, e o sprite do elite servia de mini-chefe — uma run enfrentou o
> Ceifador do ato 1 cinco vezes. Agora cada ato tem um POOL por tipo de nó
> (src/data/enemies.lua, `ROSTER`), sorteado pelo stream "enemy" do Rng (a
> seed reproduz o combate) e sem repetir o último inimigo enfrentado.
>
> O inimigo é decidido quando o NÓ nasce (RunManager:generateNextNodes) e
> gravado nele (`node.enemyId`): a prévia da encruzilhada, a batalha e o
> Continuar leem o MESMO inimigo — o save não re-sorteia.

## L25-26 (em `EnemyRoster.isCombat`, junto a `function EnemyRoster.biomeAct(run)`)

> Ato do BIOMA (1..6). Endless cicla 4,5,6,1,2,3,... — mesmo wrap do
> WorldRoad.rawBiome e do EnemyRenderer.resolveSpriteId de antes.

## L41-42 (em `EnemyRoster.poolFor`, junto a `function EnemyRoster.pick(act, nodeType, recent)`)

> Sorteia o inimigo de um nó. `recent` = ids enfrentados por último (o mais
> recente no fim); o último nunca repete, o penúltimo só se não houver outro.

## L62-63 (em `out`, junto a `function EnemyRoster.assignNodes(run, nodes)`)

> Grava o inimigo nos nós de combate recém-gerados. Dois nós da MESMA
> encruzilhada também não repetem entre si (quando o pool deixa).

## L77-78 (em `recent`, junto a `function EnemyRoster.resolveNode(run, node, nodeType)`)

> Inimigo do nó corrente. Save antigo (nó sem enemyId) sorteia AGORA e
> grava no nó — o Continuar seguinte lê o mesmo.

## L88-89 (em `EnemyRoster.resolveNode`, junto a `function EnemyRoster.remember(run, id)`)

> Anota o inimigo enfrentado (alimenta o "sem repetir"). Guarda só os 4
> últimos — o filtro olha dois.

## L98-102 (em `EnemyRoster.remember`, junto a `function EnemyRoster.spawn(Enemy, id, stats, act)`)

> Monta o inimigo: escala vida/dano pelo kit e instala o kit (rola o 1º
> intent). `Enemy` vem por parâmetro pra este módulo não depender da
> entidade (testes injetam a classe real).
> `act` (opcional) aplica a escala de dano do ato (DAMAGE_SCALE_BY_ACT);
> endless usa a do último ato.

