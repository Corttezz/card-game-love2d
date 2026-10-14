---
name: code_notes/src/systems/RunManager.lua
description: Comentários com decisão/regra/histórico colhidos de src/systems/RunManager.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/systems/RunManager.lua`

Origem: `src/systems/RunManager.lua` em `7dbdb60d` (67 de 111 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-2 (junto a `local RunManager = {}`)

> src/systems/RunManager.lua
> Gerencia a "corrida" atual (run) como no Slay the Spire

## L25-26 (em `RunManager:new`, junto a `function RunManager:startNewRun(classId, opts)`)

> Inicia uma nova corrida com a classe selecionada
> opts.seal = Selo do Grimório (0..10) escolhido na seleção de classe.

## L33-35 (em `RunManager:startNewRun`, junto a `local rng = Rng.setActive(Rng.new())`)

> RNG seedável da run (streams card/shop/map/event/enemy/misc). Toda
> decisão de run passa por ele — reprodutível por seed e à prova de
> save-scum (estado serializado em rngState no save).

## L49-52 (em `currentDeck`, junto a `jokers = {},`)

> Jokers da run (separados do deck — padrão Balatro G.jokers).
> Array de strings ou {id, edition?, seal?}. Persistem entre batalhas.
> COLEÇÃO possuída (ilimitada). Reconstruído em jokerSlots via
> buildJokerInstances() (só os ATIVOS).

## L54-56 (em `jokers`, junto a `jokerActive = {},`)

> Flags de "ativo" paralelas a jokers (jokerActive[i] ↔ jokers[i]).
> Só até MAX_JOKER_SLOTS podem estar ativos; o resto fica na bancada.
> O jogador troca quais ativar pelo Gerenciador de Coringas.

## L68 (em `jokerActive`, junto a `seal = math.max(0, math.floor((opts and opts.seal) or 0)),`)

> Selo do Grimório (Out/2026) — regras cumulativas, ver RunModifiers.

## L76-81 (em `mapHistory`, junto a `journal = {},`)

> ROTEIRO da run (Set/2026): uma entrada por NÓ VISITADO, com o que
> foi ESCOLHIDO ali. É o que a tela de Roteiro (RunJournalScreen) lê.
> Entrada aberta em journalBegin (chooseNode) e fechada em journalEnd
> (showMapSelection); as aquisições no meio caem na entrada aberta.
> Só tipos serializáveis (number/string/boolean/table) — o save é o
> currentRun inteiro via SaveManager.serialize.

## L90 (em `journal`, junto a `cardHistory = {},`)

> Histórico de cartas adicionadas

## L93-96 (em `cardHistory`, junto a `upgraded = {},`)

> LINHA DE BASE legada de forja: { cardId -> levelInt }. Desde a forja
> POR CÓPIA (Set/2026) nada escreve aqui — o nível novo mora em
> currentDeck[i].up. Fica pra saves antigos continuarem lendo o nível
> que tinham (ver getEntryLevel).

## L128-129 (em `RunManager:getCurrentDeck`, junto a `function RunManager:getDeckCardIds()`)

> Ids normalizados do deck (entries podem ser string OU {id, edition, seal}).
> Usado pelas ofertas (afinidade/anti-duplicata) e telas de forja.

## L140-142 (em `ids`, junto a `function RunManager:addCardToDeck(cardId, meta)`)

> Adiciona uma carta ao deck. meta opcional pra cartas com edition/seal vindas
> de booster packs. Quando meta presente, deck guarda objeto {id, edition, seal};
> caso contrário guarda só o id (back-compat com deck antigo).

## L162 (em `entry`, junto a `self:journalNote({ kind = "card", id = cardId,`)

> Roteiro: no-op silencioso no deck inicial (nenhum nó aberto ainda).

## L169-176 (em `entry`, junto a `function RunManager:getMaxJokerSlots()`)

> ===== Jokers (run-scoped, separados do deck — padrão Balatro G.jokers) =====
>
> MODELO COLEÇÃO + BANCADA (Jul/2026): a run POSSUI jokers ilimitados
> (currentRun.jokers). Só até MAX_JOKER_SLOTS ficam ATIVOS (jokerActive[i]);
> os demais ficam na bancada. jokerSlots (instâncias jogáveis) é construído
> SÓ dos ativos. Comprar um 4º joker NÃO o perde mais — entra na bancada, e o
> jogador troca os ativos pelo Gerenciador de Coringas. Isso vira estratégia:
> montar/ajustar o conjunto de coringas ao longo da run.

## L179-183 (em `RunManager:getMaxJokerSlots`, junto a `local base = (Config.Game and Config.Game.MAX_JOKER_SLOTS) or 3`)

> currentRun.maxJokerSlots é espelhado por Game:recomputeMaxJokerSlots
> (bancadas compradas na loja).
> Sem espelho (save recém-carregado, antes do primeiro startGame) o teto
> ainda tem que CONTAR as bancadas compradas, senão o jogador perde
> coringas ativos ao reabrir o jogo.

## L200-201 (em `RunManager:getActiveJokerCount`, junto a `function RunManager:_ensureJokerActive()`)

> Garante que jokerActive existe e tem o mesmo tamanho de jokers. Saves antigos
> (sem jokerActive) ativam os primeiros MAX_JOKER_SLOTS; o resto fica na bancada.

## L214 (em `act`, junto a `local cap = self:getMaxJokerSlots()`)

> normaliza tamanho + reforça o cap (nunca mais ativos que o teto)

## L227-229 (em `act`, junto a `function RunManager:addJokerToRun(jokerId, meta)`)

> Adiciona um joker à COLEÇÃO da run. Não passa pelo deck/hand. meta opcional
> para edition/seal vindos de Buffoon packs. Ativa automaticamente se houver
> slot livre; senão entra na bancada. Retorna (index, ativado?).

## L285-286 (em `RunManager:removeJokerFromRun`, junto a `function RunManager:setJokerActive(index, active)`)

> Ativa/desativa o joker de um índice, respeitando o teto de slots. Retorna
> (ok, motivo). Motivo "cap" = tentou ativar com os slots cheios.

## L325-326 (em `RunManager:_instanceFromJokerEntry`, junto a `function RunManager:buildJokerInstances()`)

> Reconstrói as instâncias de joker ATIVAS (as que vão pra jokerSlots).
> Aplica edition/seal por cópia. Não aplica upgrades (jokers não são forjados).

## L344-345 (em `instances`, junto a `function RunManager:buildAllJokerInstances()`)

> Constrói instâncias de TODOS os jokers possuídos (ativos + bancada), cada uma
> marcada com _ownedIndex e _active. Usado pelo Gerenciador de Coringas.

## L377-381 (em `RunManager:removeCardFromDeck`)

> P3.1 (rebalance Jul/2026): RunManager:completeBattle REMOVIDO — era caminho
> MORTO (único caller: Game:completeBattle, que também não tem caller nenhum)
> e usava o rollRarity default 37/37/25/1 fora do pipeline vivo de ofertas
> (CardRewardScreen → ShopSystem → pickRewardCard, com pesos POR ATO). O fluxo
> real de recompensa pós-batalha é showCardRewards em main.lua.

## L385-386 (em `RunManager:removeCardFromDeck`, junto a `function RunManager:generateNextNodes(numNodes)`)

> Gera pendingNodes para o proximo andar dentro do ato.
> floorsPerAct: Fase 5 tornara dinamico; por ora usa o default do MapManager.

## L394-395 (em `RunManager:generateNextNodes`, junto a `require("src.systems.EnemyRoster").assignNodes(self.currentRun,`)

> Inimigo de cada nó de combate decidido JÁ (stream "enemy", sem repetir
> o último): prévia, batalha e Continuar leem o mesmo (EnemyRoster).

## L401-405 (em `RunManager:generateNextNodes`, junto a `function RunManager:chooseNode(index, snapshot)`)

> Confirma a escolha de um node e avanca floorInAct. Se ultrapassar floorsPerAct,
> incrementa actNumber e zera floorInAct. Endless e disparado pelo ActSystem (Fase 5).
>
> snapshot opcional { hp, maxHp, gold }: abre a entrada do ROTEIRO com o estado
> do jogador ANTES do nó (o caller tem o Game; o RunManager não).

## L411-413 (em `RunManager:chooseNode`, junto a `local options = self.currentRun.pendingNodes`)

> Os ramos da encruzilhada (TODAS as opções, inclusive as não tomadas)
> vão pro roteiro ANTES de pendingNodes sumir: o mapa desenha os trilhos
> que existiam e qual foi seguido (Out/2026, mapa à mão).

## L428-447 (em `RunManager:chooseNode`, junto a `function RunManager:advanceFloorInAct(totalActs)`)

> Avanca floorInAct apos resolver um node (batalha vencida, loja saida, etc).
> Retorna "act_complete" se cruzou para novo ato, "endless_start" se saiu do ultimo,
> "advanced" caso normal.
> ATENCAO: `totalActs` e OVERRIDE DE TESTE, nao contrato de chamada.
>
> Este parametro nascia com default 3 e TODOS os chamadores passavam `3`
> cravado — inclusive o caminho real do jogo (main.lua, showMapSelection).
> Quando a campanha foi de 3 pra 6 atos (Set/2026), `Config.TotalActs` mudou
> e este 3 NAO: a run passava a endless ao fim do ato 3, `checkVictory`
> retorna false com `endlessMode`, e o jogo ficava IMPOSSIVEL DE VENCER —
> os atos 4-6 existiam, com a curva certa, mas rotulados como endless e sem
> tela de vitoria no fim. Pior que o defeito original, que ao menos vencia.
>
> Os testes nao pegaram porque TAMBEM passavam `3`: exercitavam o parametro,
> nunca a configuracao do jogo. Passar o mesmo literal errado dos dois lados
> e um teste que confirma a si mesmo.
>
> Agora o default e a FONTE UNICA (`Config.TotalActs`) e nenhum chamador de
> producao passa nada. Ver `tools/test_progression.lua`, que trava a chamada
> SEM argumento.

## L459-461 (em `RunManager:advanceFloorInAct`, junto a `local jaEndless = self.currentRun.actNumber > totalActs`)

> Ja estava no "ato endless": e so mais um ciclo de 8 andares
> (antes repetia "endless_start" e o aviso de desbloqueio a cada
> chefe do endless).

## L467-469 (em `RunManager:advanceFloorInAct`, junto a `require("src.systems.RunModifiers").beginEndlessCycle(self.currentRun)`)

> Ciclo novo do endless = escolha de maldição aberta (1 de 2).
> Mora AQUI (e não na tela) pra que piloto, testes e Continuar
> vejam o mesmo estado: a escolha pendente viaja no save.

## L477-480 (em `RunManager:advanceFloorInAct`, junto a `if self.currentRun.endlessMode then`)

> Andar ABSOLUTO do endless (1 = primeiro depois do ultimo chefe). Lido
> pelo ActSystem (expoente), ScoreSystem, UnlockSystem (XP) e tela final;
> antes nada escrevia este campo. Mesma conta do
> AchievementSystem.endlessFloor.

## L496-515 (em `RunManager:getPendingNodes`, junto a `function RunManager:_openJournalEntry()`)

> ============================================================================
> ROTEIRO DA RUN (journal) — Set/2026
> ============================================================================
> "um mapa de tudo o que a gente já fez, tudo o que a gente já escolheu, só
> para acompanhar ato por ato" (pedido do dono). O que existia antes era
> `mapHistory`, que guarda ato/andar/tipo e NUNCA foi lido por ninguém — o
> roteiro estende esse registro com o RESULTADO e as ESCOLHAS de cada nó.
>
> Ciclo de vida de uma entrada:
> journalBegin(node, snapshot)  ← chooseNode          (abre, grava hp/ouro de entrada)
> journalNote{...}              ← sinks do RunManager (carta/coringa/forja/remoção)
> journalEnd(snapshot)          ← showMapSelection    (fecha, grava hp/ouro de saída)
>
> Instrumentar os sinks DAQUI (addCardToDeck, addJokerToRun, upgradeCard,
> registerPaidForge, removeCardFromDeck) cobre loja, recompensa, fogueira,
> eventos e packs sem espalhar chamadas por cinco telas.
>
> Persistência: `journal` é só number/string/boolean/table, então viaja no
> save junto do resto do currentRun — sem migration. Save antigo entra com
> journal nil; getJournal() faz backfill a partir do mapHistory.

## L524-529 (em `RunManager:_openJournalEntry`, junto a `function RunManager:journalBegin(node, snapshot, options, pick)`)

> Abre a entrada do nó. snapshot = { hp, maxHp, gold } (opcional).
> options/pick (opcionais): a lista de nós oferecidos na encruzilhada e o
> índice escolhido. Viram `branches` (só os TIPOS, em ordem) e `pick` na
> entrada: é o que o mapa usa pra desenhar os ramos não tomados. Entrada
> sem `branches` (save anterior a Out/2026, backfill, teste) desenha só o
> caminho percorrido: o campo é aditivo, nenhuma migration.

## L546-547 (em `branches`, junto a `if run.journalOpen then`)

> Fecha uma entrada esquecida em aberto (nó que resolveu por um caminho
> que não passou pelo journalEnd) em vez de empilhar entradas zumbis.

## L555-556 (em `branches`, junto a `gfloor = run.currentFloor or 1,`)

> andar GLOBAL: em endless o par (act, floor) se repete (act trava em
> totalActs+1 e floor cicla 1..8), então ele não identifica um nó.

## L565-566 (em `gains`, junto a `at     = os.time(),`)

> os.time() e NAO love.timer.getTime(): getTime e relativo a sessao e
> vira lixo depois de um load (armadilha ja existente no cardHistory).

## L573-576 (em `gains`, junto a `function RunManager:journalNote(entry)`)

> Anexa uma escolha à entrada aberta. entry = { kind, id, lvl?, label? }.
> No-op LEGÍTIMO quando não há nó aberto: deck inicial da classe, efeitos de
> teste e qualquer aquisição fora de um nó. Não é fallback silencioso de
> recurso faltando — por isso vai em trace, não em warn.

## L600-601 (em `RunManager:journalEvent`, junto a `function RunManager:journalEnd(snapshot)`)

> Fecha a entrada aberta. Idempotente: showMapSelection pode rodar duas vezes
> (o guard de pendingNodes existe justamente porque isso acontece).

## L615-626 (em `RunManager:journalEnd`, junto a `function RunManager:getJournal()`)

> Roteiro pronto pra UI: os nós na ORDEM em que foram visitados, com backfill
> das runs que começaram antes deste sistema existir.
>
> Ordem cronológica (e não ordenação por ato/andar) porque em endless o par
> (act, floor) se repete e deixaria de ser chave.
>
> Backfill: `mapHistory` e `journal` são alimentados na MESMA chamada
> (chooseNode), então as J entradas do journal são sempre os J últimos nós.
> Os `#mapHistory - #journal` primeiros são os nós anteriores a esta feature:
> entram como entradas `partial = true` (a tela diz "sem detalhes" em vez de
> fingir que o nó não teve escolhas). Uma run em andamento ganha o caminho
> retroativo sem duplicar nada.

## L659 (em `RunManager:isJournalEntryOpen`)

> ===== Upgrade map (Fase 3.1 do refactor Balatro; infinito desde Jul/2026) =====

## L661-663 (em `RunManager:isJournalEntryOpen`, junto a `function RunManager.getUpgradeCap()`)

> Cap por carta vem de Config.Game.UPGRADE_LEVEL_CAP (0 = SEM CAP — forja
> infinita; o freio de balance é o custo: fogueira = 1 grátis por acampamento,
> loja = custo crescente por forja paga). Valor > 0 restaura o teto antigo.

## L670-686 (em `RunManager.getUpgradeCap`, junto a `function RunManager:getEntryLevel(entry)`)

> ===== Forja POR CÓPIA (Set/2026) =====
>
> ANTES: o nível morava em currentRun.upgraded[cardId] — um mapa POR ID. Duas
> "Golpe" no deck eram, pra forja, a MESMA carta: forjar uma subia as duas. Foi
> por isso que o picker da bigorna deduplicava a grade (mostrar duas cartas
> idênticas que sempre andam juntas é mentira de UI) — e a queixa do dono
> ("se eu tiver duas cartas iguais, na tela de forjar só aparece uma") é a
> ponta visível disso.
>
> AGORA: o nível mora NA CÓPIA, no próprio item de currentDeck (campo `up`).
> A identidade de uma cópia é o ÍNDICE dela em currentDeck — nunca o id.
>
> Back-compat SEM migração destrutiva: o nível efetivo de uma cópia é
> entry.up  OU  currentRun.upgraded[id]  OU  0
> (ver getEntryLevel). Save antigo continua lendo o mapa por id como LINHA DE
> BASE compartilhada; a primeira forja daquela cópia grava `up` e a partir daí
> ela anda sozinha. Nada se perde e nenhuma ordem de migração importa.

## L688-689 (em `RunManager.getUpgradeCap`, junto a `function RunManager:getEntryLevel(entry)`)

> Nível de forja de UMA CÓPIA. `entry` é um item de currentDeck: string (id)
> OU { id, edition, seal, up }.

## L714-715 (em `RunManager:getUpgradesAt`, junto a `function RunManager:_entryTableAt(index)`)

> Promove a entrada do índice a TABELA (é onde o nível por cópia mora) e
> devolve a tabela. Preserva edition/seal e a linha de base legada.

## L729-731 (em `t`, junto a `function RunManager:getDeckCopies()`)

> Lista NORMALIZADA de cópias do deck, uma entrada POR CÓPIA (duas "Golpe"
> viram duas entradas). É o que as telas de forja/remoção/duplicação devem
> percorrer — percorrer ids colapsa cópias.

## L750-751 (em `out`, junto a `function RunManager:hasAnyUpgrade()`)

> True se ALGUMA carta da run já foi forjada (conquista "sem_rascunhos").
> Precisa olhar as duas fontes: o mapa legado E o `up` por cópia.

## L761-762 (em `RunManager:hasAnyUpgrade`, junto a `function RunManager:upgradeCardAt(index)`)

> Forja UMA CÓPIA (índice em currentDeck). Retorna o novo nível, ou nil se a
> cópia não existe / já está no cap. Com cap 0 (infinito) nunca retorna nil.

## L778-780 (em `RunManager:upgradeCardAt`, junto a `self:journalNote({ kind = "forge", id = t.id, lvl = t.up })`)

> Roteiro: a forja é anotada AQUI e não em registerPaidForge — este é o
> ponto que sabe O QUÊ foi forjado (fogueira, loja e eventos passam todos
> por aqui); registerPaidForge só conta o custo e duplicaria a entrada.

## L800-802 (em `RunManager:canUpgradeAt`, junto a `function RunManager:removeCardAt(index)`)

> Remove UMA CÓPIA pelo índice (a que o jogador apontou, com o nível dela).
> removeCardFromDeck(id) remove a PRIMEIRA cópia — errado quando o jogador
> escolheu a terceira.

## L813-815 (em `RunManager:removeCardAt`, junto a `function RunManager:duplicateCardAt(index)`)

> Duplica UMA CÓPIA pelo índice. A cópia nova nasce igual à escolhida — mesmo
> edition/seal e MESMO nível de forja (duplicar "Golpe +2" entrega "Golpe +2",
> não uma Golpe crua). Retorna o índice da nova cópia.

## L835-838 (em `meta`, junto a `function RunManager:upgradeCard(cardId)`)

> Forja POR ID (legado — eventos, autoplay e a loja, que não têm índice em
> mão). Escolhe UMA cópia: a de MENOR nível entre as forjáveis, pra que forjar
> "Golpe" repetidamente espalhe os níveis em vez de empilhar tudo numa só.
> Retorna o novo nível, ou nil se nenhuma cópia dessa carta pode ser forjada.

## L856-858 (em `RunManager:upgradeCard`, junto a `function RunManager:canUpgrade(cardId)`)

> True se a carta pode ser forjada novamente (não atingiu o cap E a forja
> tem ALGO pra melhorar nela — carta sem stat básico nem effect upgradável
> não entra na bigorna).

## L867-868 (em `RunManager:canUpgrade`, junto a `local any = false`)

> Com cap finito: basta UMA cópia abaixo do teto. (Sem cópia no deck cai
> na linha de base legada — o comportamento antigo.)

## L881-882 (em `RunManager:canUpgrade`, junto a `function RunManager:getPaidForgeCost()`)

> Custo da PRÓXIMA forja comprada (oferta "Forja" da loja). Cresce por forja
> PAGA na run: base × mult^n, teto em FORGE_COST_MAX. A da fogueira é grátis.

## L896-898 (em `RunManager:registerPaidForge`, junto a `function RunManager:unregisterPaidForge()`)

> Desfaz uma forja paga: o jogador comprou e FECHOU o picker sem escolher
> carta nenhuma. Sem isto o preço da próxima forja subiria por uma compra
> que não aconteceu (ver CardRewardScreen:_refundDeckService).

## L904-912 (em `RunManager:unregisterPaidForge`, junto a `function RunManager:_services()`)

> ===== LEDGER DE SERVIÇOS DA LOJA (Set/2026) =====
>
> `currentRun.services = { [id] = compras }`. É o que faz o custo crescer e
> o que fecha a torneira dos serviços com teto (slot de coringa, compra
> extra). Mora no currentRun porque é ESTADO DE RUN: viaja no save junto com
> tudo (SaveManager serializa a tabela inteira) e morre com a run.
>
> Os NÚMEROS ficam em Config.Offers.SERVICES e a leitura deles em
> src/systems/ShopServices.lua; aqui mora só a contagem.

## L941-944 (em `RunManager:unregisterService`, junto a `function RunManager:getUpgrades(cardId)`)

> Lê nível de upgrade POR ID (legado). Com nível por cópia não existe "o"
> nível de uma carta: devolve o MAIOR entre as cópias no deck (é o que
> interessa a quem pergunta "essa carta já foi forjada?"). Quem precisa de uma
> cópia específica usa getUpgradesAt(index).

## L960-963 (em `RunManager:getUpgrades`, junto a `local UPGRADABLE_EFFECT_TYPES = {`)

> Aplica +N ao instance criado. Ganhos por nível vêm de Config.Offers
> (FORGE_ATK/DEF/EFFECT_PER_LVL — fonte única com a UI, que mostra o mesmo
> número no tooltip/preview). Cost permanece igual — você pagou pra upgradar,
> não vai pagar mais mana pra usar.

## L970-982 (em `UPGRADABLE_EFFECT_TYPES`, junto a `function RunManager.getForgeGains(cardData)`)

> ===== Regra de forja por CENÁRIO de carta (playtest Jul/2026) =====
> Bug original: `if instance.defense` é true até pra defense=0 (0 é truthy em
> Lua) — carta de ATAQUE PURO ganhava "+2 DEF" fantasma por nível e o tooltip
> mostrava fielmente o absurdo. A forja melhora O QUE A CARTA TEM:
> attack > 0      → +FORGE_ATK_PER_LVL por nível
> defense > 0     → +FORGE_DEF_PER_LVL por nível
> sem stat básico → +FORGE_EFFECT_PER_LVL no PRIMEIRO effect upgradável
> (cartas de efeito puro: poções, utilitárias)
> nenhum ganho    → carta NÃO forjável (canUpgrade barra; picker esconde)
> joker           → não forjável (invariante existente, nunca chega aqui)
> getForgeGains é a FONTE ÚNICA: applyUpgradesToInstance, CardInfoDisplay e
> RestScreen (preview + resultado) leem daqui — a UI nunca mente.
> Matriz completa em memory/rng_and_offers.md §forja.

## L1023-1025 (em `RunManager:applyUpgradesToInstance`, junto a `local ok, img = pcall(function()`)

> F5: re-renderiza a moldura DEPOIS dos stats upados — antes a arte era
> gerada no createCardInstance com os números base (carta forjada mentia
> na moldura) e sem o selo +N.

## L1033-1034 (em `RunManager:applyUpgradesToInstance`, junto a `function RunManager:_migrateJokersFromDeck()`)

> Migra qualquer joker que esteja em currentDeck (saves antigos) para currentRun.jokers.
> Idempotente: só roda quando encontra. Modifica currentDeck in-place.

## L1040 (em `RunManager:_migrateJokersFromDeck`, junto a `for i = 1, #self.currentRun.currentDeck do`)

> percorre em ordem crescente pra preservar a ordem original dos jokers

## L1047 (em `RunManager:_migrateJokersFromDeck`, junto a `local activated = self:getActiveJokerCount() < cap`)

> migrado ativa se ainda há slot livre (senão vai pra bancada)

## L1064-1065 (em `RunManager:_migrateJokersFromDeck`, junto a `function RunManager:buildPlayableDeck()`)

> Converte deck para instâncias de cartas jogáveis. Aplica upgrades + edition/seal
> por cópia individual (deck pode conter strings ou objetos {id, edition, seal}).

## L1069-1070 (em `RunManager:buildPlayableDeck`, junto a `self:_migrateJokersFromDeck()`)

> Migração defensiva: garante que nenhum joker esteja em currentDeck antes
> de construir o deck jogável (saves antigos pré-Fase joker-split).

## L1089-1090 (em `playableCards`, junto a `local lvl = (type(entry) == "table" and entry.up)`)

> Nível POR CÓPIA (entry.up); o mapa por id fica como linha de base
> pra saves anteriores à forja por cópia.

## L1096-1097 (em `playableCards`, junto a `if edition and edition ~= "negative" then cardInstance.edition = edition end`)

> Edition/seal por cópia (vindo de booster pack). "negative"
> saiu do jogo (Out/2026): cópia de save antigo vira carta comum.

## L1167-1168 (em `RunManager:saveRun`, junto a `self.currentRun.rngState = Rng.get():getState()`)

> Snapshot do RNG viaja no save: load restaura o estado EXATO de cada
> stream (getState/setState) — reabrir o jogo não re-rola nada.

## L1185-1186 (em `RunManager:loadRun`, junto a `Rng.setActive(Rng.fromState(runData.rngState))`)

> Restaura o RNG da run. Save antigo sem rngState: fromState devolve um
> Rng novo (seed fresca) — a run continua, só não reproduz o passado.

