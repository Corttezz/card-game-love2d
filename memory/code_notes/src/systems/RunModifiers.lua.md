---
name: code_notes/src/systems/RunModifiers.lua
description: Comentários com decisão/regra/histórico colhidos de src/systems/RunModifiers.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/systems/RunModifiers.lua`

Origem: `src/systems/RunModifiers.lua` em `7dbdb60d` (7 de 13 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-25 (junto a `local Data = require("src.data.run_modifiers")`)

> src/systems/RunModifiers.lua
> REGRAS QUE MULTIPLICAM A CORRIDA (Out/2026): Selos do Grimório (dificuldade
> escolhida antes da run, cumulativa 1-10) e Maldições do endless (1-de-2 a
> cada ciclo de 8 andares, empilháveis). Dados em src/data/run_modifiers.lua;
> desenho e pesquisa em memory/endless_and_seals.md.
>
> REGRA DE OURO: isto só MULTIPLICA por cima dos números base. Nenhum valor
> de Config.Acts / cartas / inimigos muda aqui — o balanço base é das frentes
> de combate; um selo 0 sem maldição devolve exatamente o jogo base (os
> multiplicadores neutros são 1 e os somatórios 0).
>
> Estado na run (viaja no save, sem migração — leitura com default):
> run.seal    = 0..10
> run.endless = { cycle = n, curses = { [id] = acúmulos },
> order = { id, ... },          -- ordem de escolha (UI)
> pending = { idA, idB } | nil } -- escolha aberta do ciclo
>
> Quem consulta (um ponto de entrada por sistema):
> ActSystem/Game  → enemyStats + decorateEnemy (vida, dano, Bloqueio)
> MapManager      → eliteWeightMul
> ShopSystem      → priceMul
> RestScreen/Game → healMul("rest"|"act")
> Game            → startingGold, victoryGoldDelta
> ShopSystem      → rewardCardsDelta
> ScoreSystem     → scoreMul

## L47-48 (em `RunModifiers.seal`, junto a `function RunModifiers.rules(run)`)

> Todas as regras ativas, já compostas: multiplicativas em produto,
> aditivas em soma, startGold = o menor pedido (o mais duro vence).

## L96-98 (em `out`, junto a `function RunModifiers.decorateEnemy(run, enemy)`)

> Bloqueio inicial (maldição Couraça Abissal), em fração da vida máxima.
> Passa por cima do teto de armadura do inimigo de propósito: é o "escudo"
> com que ele entra na luta, não um ganho de turno.

## L107-111 (em `RunModifiers.decorateEnemy`, junto a `if enemy.refreshIntentVisibility then`)

> NÉVOA DE INTENÇÃO (Out/2026): o bioma do ato decide quanto do intent o
> HUD mostra (src/data/intent_fog.lua). O 1º golpe já rolou dentro do
> setKit, antes de o inimigo saber onde nasceu — re-resolve com o contexto.
> É o único ponto por onde TODO inimigo de run passa (batalha nova e
> Continuar), por isso mora aqui e não nos dois spawns do Game.

## L128 (em `RunModifiers.healMul`, junto a `function RunModifiers.price(run, cost)`)

> Preço com o multiplicador (arredonda pra cima: a casa nunca perde centavo).

## L145-146 (em `RunModifiers.rewardCardsDelta`, junto a `function RunModifiers.scoreMul(run)`)

> ===== Pontuação =====
> Selo +10%/nível; cada acúmulo de maldição soma o `score` dela.

## L197-200 (em `out`, junto a `function RunModifiers.beginEndlessCycle(run)`)

> Abre o ciclo seguinte: cycle+1 e sorteia 2 maldições DIFERENTES que ainda
> não bateram o teto (stream "event" do Rng da run — reprodutível por seed e
> salva junto). Chamado por RunManager:advanceFloorInAct ao entrar/girar o
> endless. Idempotente se já há escolha aberta.

