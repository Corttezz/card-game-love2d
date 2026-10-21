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

## Tela (frente bestiario-tela, 21/Out/2026; refeita no mesmo dia: "muito com cara de IA")
- Coleção com duas abas de seção no topo esquerdo (Cartas | Criaturas, `bestiary.ui.tab_cards`/`tab`). Em Criaturas a faixa de filtros vira FITAS marcadoras por ato (cor de cera por ato, numeral + nome do bioma em até 2 linhas, a do ato à vista desce); clique rola até a página. Lógica em `src/ui/BestiaryGrid.lua`, ficha em `src/ui/BestiaryCard.lua`, zonas puras em `src/ui/BestiaryLayout.lua` (`grid`/`validateGrid`, `card`/`validateCard`), traço de pena/cera/gravura em `src/ui/BestiaryInk.lua` (por cima do `RunJournalInk`), sprites em `src/ui/BestiarySprites.lua`.
- Livro do caçador, uma PÁGINA de pergaminho por ato: numeral em tinta vermelha, "Ato N" + nome do bioma + "n de 7" e marcas de contagem; vinheta GRAVADA (montanhas + castelo do bioma pelo shader de gravura sépia com dither, `BInk.engrave`). Vagas de tamanho por tipo: 3 comuns presos com fita (sem moldura), 2 elites com moldura a pena e selo de cera aço, mini-chefe com moldura dupla e cera bronze, chefe numa prancha grande à direita (sprite ~2x, moldura dupla com cantoneiras, cera vermelha, epíteto embaixo). Derrotada ganha um visto em tinta vermelha.
- NÃO descoberta: nada da criatura (sem silhueta, sem selo, sem nome): moldura apagada e um "?" a tinta que balança devagar. O sprite dela nem é carregado. A ficha não abre.
- Página estática assada num canvas por ato (resolução física: canvas k× e `scale(k)` dentro), no máximo uma assada por quadro, cache de 4; só o vivo vai por quadro (sprites, "?", "!" a tinta pulsando, hover: sobe 3 px, sombra e cantoneiras a tinta, nome escurece). Papel = `Ink.paper` com 2 sementes alternadas (o ruído é preaquecido no `Grid.new`, que roda no boot). Medido: troca para a aba 14 a 16 ms nos 3 primeiros quadros, depois 0 a 5 ms.
- Rolagem suave (alvo + easing; reducedMotion = direto). Teclado: alvo do NavCursor do chefe é só a faixa de cima da prancha (senão a seta para a direita caía nas fitas); seta para baixo sem vizinho visível rola até a próxima vaga da MESMA coluna aparecer (`Grid:columnNeighbor`).
- Ficha = página de bestiário: nome em tinta (chefe 24 px) com selo de cera, epíteto em ferrugem, criatura desenhada na página sobre montanhas gravadas com chão hachurado e sombra, aura do chefe (`BossAura.update/drawBack/drawFront` com o rect do sprite), livro-caixa com marcas de contagem, registro em tinta, assinatura como nota de margem em tinta vermelha, golpes com marcadores de tinta, e no canto inferior direito o esboço do habitat (marco/castelo gravado) com `bestiary.ui.habitat`. Abre com borrifo de tinta e poeira e a página sobe; trocar de criatura desliza para o lado. reducedMotion: sem borrifo, sem aura, sem deslizar, quadro 0.
- Nome do bioma do ato: `bestiary.ui.biome.<id>` (id de `src/data/biomes.lua`), NUNCA `acts.actN` ("Catacumbas" não bate com a arte de campos).
- Sprite em escala INTEIRA de tela: `smallScale`/`bossScale`/`spriteScale` escolhem P inteiro de pixels físicos e desenham com `P/k`; ancorado pelo pé (bbox alfa do quadro 0).
- Scissor dentro do UiScale é VIRTUAL e soma o translate: use `BestiaryLayout.scissor` (transformPoint / activeK).
- `GrimoirePage` custa 465 ms por tamanho: não usar em overlay aberto por clique.
- Texto corrido com entrelinha 1,5 (`BestiaryLayout.printWrapped`/`wrapH`).
- Ficha aberta toma a navegação: `CollectionScreen:ownsNavigation()` (o main.lua usa isso no lugar de `inspectedCard ~= nil`); setas trocam de criatura descoberta, Esc/B fecha só a ficha.
- Fim da corrida: célula `bestiary.ui.end_label` só quando `Bestiary.runNewCount() > 0` (o `test_end_screens` zera a lista antes de contar as 9 células). Menu: "!" da Coleção também com `Bestiary.anyNew()`.
- Trava: `test_bestiary_ui` (layout em 7 tamanhos × 5 idiomas × 42 fichas e fitas em até 2 linhas, não descoberta sem sprite desenhado nem carregado, "!" some no hover, linha do fim só com n > 0, cada vaga a uma seta da vizinha, Enter abre a ficha, reducedMotion). Capturas: `BESTIARIO_SIZES=2 lovec . test_one screenshot_bestiario <locale>` → copiar para `tools/preview_out/bestiario/`.
