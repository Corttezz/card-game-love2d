---
name: bestiary
description: Bestiário (21/Out/2026): criaturas descobertas no perfil, quantas vezes enfrentada/derrotada/te derrotou, "!" de novidade, contagem de inéditas da run e os ganchos do jogo que contam uma vez por luta
type: subsystem
---

# Bestiário (`src/systems/Bestiary.lua`), 21/Out/2026

Pedido do dono: "coleção de criaturas encontradas... ao final de cada campanha... mostrar as novas criaturas". Decisões do lead: aba "Criaturas" dentro da Coleção (frente de UI), modelo de descoberta = o das cartas (`unlocks.md`, "Descobrir não é desbloquear"): ver em luta DESCOBRE, calado, sem toast, sem UnlockQueue; "!" até passar o mouse; no fim da run só a CONTAGEM "Novas criaturas: N".

## Dados
- Catálogo = `src/data/enemies.lua` `ROSTER` (42 ids: 6 atos × 3 comuns, 2 elites, mini-chefe, chefe). `entries()` ordena por ato e, dentro do ato, comum → elite → mini-chefe → chefe, na ordem do ROSTER. `tier` = `common|elite|miniboss|boss` (o nó `mini_boss` vira `miniboss`); `biome` = `id` de `src/data/biomes.lua[ato]`; `spriteId` = id.
- Os corvos invocados do rei-carniça NÃO têm entrada própria no roster, então não contam.
- Nome da criatura: `I18n.t("end_screen.enemy." .. id)` (`Bestiary.nameKey`), a mesma chave do HUD e do fim de run. Não criar outra chave de nome. Golpes: `Bestiary.kit(id).moves[i].id` → `enemy_kit` nos locales.

## Persistência
- Mora DENTRO do `profile.lua` (`ProfileStats.get().bestiary = { seen, defeated, killedYou, fresh }`, mapas id → n / id → true), como o `unlocks.discovered`. Sem arquivo novo, então `Release.MIGRATE_FILES` não muda.
- Cada `mark*` chama `ProfileStats.flush()` (uma vez por luta, barato). Sob `_G.HEADLESS_TOOL` o `ProfileStats` não grava (só com `_setPathForTests`): ferramenta e suíte nunca tocam o perfil real.
- Perfil antigo começa vazio: o perfil nunca guardou abates por id (contadores do `AchievementSystem` são genéricos), não há o que retroagir.

## Uma vez por luta (o que impede recontar)
- `run.fightSerial` sobe em `Game:nextPhase` (`Bestiary.beginFight`); `run.bestiaryFight = { serial, id, seen, defeated, killedYou }` marca o que essa luta já contou. Os dois vão no save da run, então Continuar no meio da luta, no cash out ou em qualquer estágio não reconta.
- `Game:noteBestiary(kind)` é o único ponto do jogo (só em run): chama `Bestiary.onFight(run, enemy.spriteId, kind)`.
- Vista: no `nextPhase` (comum, elite, mini-chefe); o CHEFE só quando a entrada começa (`GameplayScene._onBossEntered`); a 1ª luta da run no fim do `Game:startGame` (o `startGame` do Continuar é pulado por `_resumingRun`, porque o inimigo dali é provisório); no `resumeRun` em luta (cobre quem saiu antes da entrada do chefe: Continuar nunca repete a entrada).
- Derrotada: `Game:_onEnemyDeath` (já protegido por `_deathHandled`). Te derrotou: `Game:checkGameOver`, dentro do bloco `_saveDeleted` (uma vez). Vitória/morte sem vista anterior conta a vista junto (derrotada ≤ vista sempre).
- Abandonar não conta nada. Endless conta normal. Cheat conta pelo fluxo real (save isolado em `card-game-cheat`); pulos que só setam `_deathHandled` (estágio retomado, salto de nó do cheat) não contam vitória.

## Contagem da run
- `run.bestiaryNew` = lista das criaturas vistas pela 1ª vez no perfil nesta run. `resetRun(run)` no `Game:startNewRun`, `attachRun(run)` no `resumeRun`. O módulo segura a referência, então `runNewCount()` ainda vale na tela final depois que a run é apagada, até a próxima run.

## Trava
`love . test_one test_bestiary`: entries (42, uma vez cada, ato/tipo/bioma, ordem), vista/derrota/te derrotou por fluxo real, Continuar sem recontar (luta, cash out, chefe), endless, abandono, isNew/clearNew/anyNew, reset do runNewCount, ida e volta pelo disco e a sandbox (zero escrita em `profile.lua`).
