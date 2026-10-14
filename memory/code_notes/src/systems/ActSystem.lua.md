---
name: code_notes/src/systems/ActSystem.lua
description: Comentários com decisão/regra/histórico colhidos de src/systems/ActSystem.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/systems/ActSystem.lua`

Origem: `src/systems/ActSystem.lua` em `7dbdb60d` (9 de 14 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-9 (junto a `local Config = require("src.core.Config")`)

> src/systems/ActSystem.lua
> Utilitarios para calcular stats de inimigos/bosses baseado no ato e no floor.
> Consume Config.Acts (Fase 5) + Config.Endless.
>
> Funcao principal:
> ActSystem.getEnemyStats(actNumber, floorInAct, nodeType) -> {health, damage, kind}
> Retorna HP e dano apropriados para o tipo de no.
> nodeType: "battle" | "elite" | "mini_boss" | "boss"
> Em endless (actNumber > TotalActs), aplica scaling exponencial.

## L15-16 (em `ActSystem`, junto a `function ActSystem.getActConfig(actNumber)`)

> Retorna a configuracao do ato N. Em endless (N > total), retorna config do ultimo
> ato mas sinalizando via `endless = true` e expoente calculado.

## L27-32 (em `ActSystem.getActConfig`, junto a `function ActSystem.getEnemyStats(actNumber, floorInAct, nodeType, endlessFloor)`)

> Calcula (health, damage) para um inimigo segundo (act, floor, nodeType).
> floorInAct: 1..act.floors. Em endless, floorInAct funciona como contador de
> andares dentro do endless (1, 2, 3, ...).
> endlessFloor (opcional): andar ABSOLUTO do endless (run.floorsInEndless).
> O floorInAct volta a 1 a cada ciclo de 8 andares; sem este argumento o
> expoente zerava a cada chefe do endless e a dificuldade nao crescia.

## L52-56 (em `ActSystem.getEnemyStats`, junto a `if Config.Game and Config.Game.ELITE_RAMP and hpMul > (Config.Game.ELITE_RAMP_START or hpMul) then`)

> wip/sustain (Config.Game.ELITE_RAMP): a elite do 1º andar vale
> ELITE_RAMP_START e sobe linearmente até eliteHPMul no 8º — hoje
> a elite entra com ×1,7 já no 1º andar do A3 (280 de vida, mais
> que o chefe do A2). Só rebaixa; ato com eliteHPMul menor que o
> START fica como está.

## L67-68 (em `ActSystem.getEnemyStats`, junto a `if isEndless then`)

> Endless: curva exp(LIN*n + QUAD*n²) sobre a base do ultimo ato
> (ActSystem.endlessFactors — fonte unica, lida tambem pelos testes).

## L71-75 (em `ActSystem.getEnemyStats`, junto a `if (nodeType == "boss" or nodeType == "mini_boss") and endlessFloor and floorInAct then`)

> Chefe e mini-chefe escalam pelo INÍCIO do ciclo, não pelo andar:
> o chefe do ciclo N é o chefe do ato 6 refeito na força do ciclo N.
> Medido (balance_sim BALANCE_ENDLESS): pelo andar, o chefe do ciclo 1
> já vinha x1,4 sobre o chefe que o jogador ACABOU de vencer e virava
> o muro da primeira volta.

## L84-87 (em `ActSystem.getEnemyStats`, junto a `local pw = Config.Game and Config.Game.ENEMY_POWER`)

> força global do inimigo (Config.Game.ENEMY_POWER — combos simples) e
> curva POR ATO (Config.Game.ENEMY_POWER_BY_ACT[ato] = {damage, health},
> opcional; endless herda o último ato). Os dois compõem e arredondam
> UMA vez, pra não perder ponto de vida duas vezes no floor.

## L100-101 (em `ActSystem.getEnemyStats`, junto a `function ActSystem.endlessFactors(n)`)

> Multiplicadores (vida, dano) do endless no andar absoluto `n` (1 = primeiro
> andar depois do ultimo chefe). Ver a curva em Config.Endless.

## L124-128 (em `ActSystem.getInterActHealPercent`, junto a `function ActSystem.getActName(actNumber, endlessFloor)`)

> Retorna o nome amigavel do ato atual (ex: "Catacumbas", ou "Endless #3").
>
> O nome vem do i18n (`acts.act<N>`); `Config.Acts[n].name` fica como fallback
> de dev. Antes o nome saia cravado em PT do Config e a tela aparecia bilingue
> ("AKT 1 - Catacumbas") em qualquer locale estrangeiro.

