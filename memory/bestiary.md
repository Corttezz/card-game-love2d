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

## Tela (frente bestiario-tela, 21/Out/2026)
- Coleção com duas abas de seção no topo esquerdo (Cartas | Criaturas, `bestiary.ui.tab_cards`/`tab`). Em Criaturas a faixa de filtros vira atalhos por ato (numeral + nome do bioma, tamanho de fonte único entre os seis). Lógica em `src/ui/BestiaryGrid.lua`, ficha em `src/ui/BestiaryCard.lua`, zonas puras em `src/ui/BestiaryLayout.lua` (`grid`/`validateGrid`, `card`/`validateCard`), sprites em `src/ui/BestiarySprites.lua`.
- Nome do bioma do ato: `bestiary.ui.biome.<id>` (id de `src/data/biomes.lua`), NUNCA `acts.actN` ("Catacumbas" não bate com a arte de campos).
- Grade: 7 colunas por ato (comum, elite, mini-chefe, chefe). Sprite em escala INTEIRA de tela: `spriteScale` escolhe P inteiro de pixels físicos e desenha com `P/k` no espaço virtual; ancorado pelo pé (bbox alfa do quadro 0). Não descoberta = quadro 0 multiplicado por cor escura (silhueta), nome "???", ficha não abre.
- Carga progressiva: `BestiarySprites.pump` por quadro (2,5 ms ou 6 imagens), visíveis primeiro; não descoberta só carrega o quadro 0. reducedMotion = quadro 0 e nada além dele é carregado.
- Scissor dentro do UiScale é VIRTUAL e soma o translate: use `BestiaryLayout.scissor` (transformPoint / activeK). transformPoint cru no setScissor dobrava ×k em 1080p e sumia com os sprites.
- Página da ficha = `RunJournalInk.paper` (75 ms só na 1ª vez, depois ~5 ms). `GrimoirePage` custa 465 ms por tamanho: não usar em overlay aberto por clique.
- Texto corrido com entrelinha 1,5 (`BestiaryLayout.printWrapped`/`wrapH`): a Press Start em 1,0 encosta as linhas.
- Ficha aberta toma a navegação: `CollectionScreen:ownsNavigation()` (o main.lua usa isso no lugar de `inspectedCard ~= nil`); setas trocam de criatura descoberta, Esc/B fecha só a ficha.
- Fim da corrida: célula `bestiary.ui.end_label` só quando `Bestiary.runNewCount() > 0` (o `test_end_screens` zera a lista antes de contar as 9 células). Menu: "!" da Coleção também com `Bestiary.anyNew()`.
- Trava: `test_bestiary_ui` (layout em 7 tamanhos × 5 idiomas × 42 fichas, silhueta por pixel, "!" some no hover, linha do fim só com n > 0, teclado alcança as 42 células e abre a ficha, reducedMotion). Capturas: `lovec . test_one screenshot_bestiario <locale>` → copiar para `tools/preview_out/bestiario/`.
