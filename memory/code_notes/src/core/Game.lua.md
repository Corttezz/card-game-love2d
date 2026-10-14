---
name: code_notes/src/core/Game.lua
description: Comentários com decisão/regra/histórico colhidos de src/core/Game.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/core/Game.lua`

Origem: `src/core/Game.lua` em `7dbdb60d` (193 de 296 blocos de comentário tinham marcador de decisão/regra/histórico).

## L22-24 (junto a `local I18nMod = require("src.i18n.I18n")`)

> Helper de mensagem traduzida (mesmo contrato do msg() do EffectSystem):
> os toasts do feed sao TEXTO DE JOGADOR e precisam sair no idioma da sessao.
> Antes eram literais PT no meio de um HUD traduzido.

## L33-39 (em `Game`, junto a `Game.DEATH_HOLD = 1.1`)

> Quanto tempo a MORTE do inimigo segura o combate: o clipe de death rodando
> (DEATH_FPS x ~7 frames ~= 0.7s) mais o respiro que separa "ele morreu" de
> "acabou". Serve ao beat da morte E ao relogio da cena — uma duracao so.
> PENDENCIA ASSUMIDA: valor de ritmo deveria morar em `CombatBeats.HOLD`
> (tabela de tempos UNICA do combate) como `DEATH`. Vai como numero cru
> enquanto nao entra la; `CombatBeats.hold` aceita numero e aplica
> `CombatBeats.speed` igual, entao o knob global continua valendo.

## L56-57 (em `instance.jokerSlots`, junto a `instance._exhaustedThisBattle = {}`)

> IDs de cartas com `exhaust=true` jogadas nesta batalha. Removidas do
> deck da run quando a batalha termina (nextPhase).

## L59-60 (em `instance._exhaustedThisBattle`, junto a `instance.discard = {}`)

> Pilha de descarte. Cartas jogadas (exceto joker/exhaust) entram aqui
> e sao reembaralhadas no deck quando drawCard encontra deck vazio.

## L62-65 (em `instance.discard`, junto a `instance._deathPauseTimer = 0`)

> Atraso após morte do inimigo até abrir cardReward. Dá tempo da death
> anim (~0.7s) tocar visivelmente. Setado em processCardInCombat quando
> enemy.health <= 0; main.lua updateGame só chama showCardRewards quando
> esse timer expira.

## L67-69 (em `instance.discard`, junto a `instance._deathHandled = false`)

> Flag idempotencia pra _onEnemyDeath: evita disparar anim/sfx duplicado
> se tanto processCardInCombat quanto enemyTurn detectam morte no mesmo tick.
> Resetado em startGame/nextPhase pra proxima batalha disparar normalmente.

## L71-72 (em `instance.discard`, junto a `instance._deathStaged = false`)

> Par do anterior: AGENDADA (existe beat) x ACONTECEU (o beat rodou).
> Ver Game:announceDeathIfPending — confundir os dois travou o jogo.

## L79-80 (em `instance.discard`, junto a `instance.combatAnimationSystem = CombatSequence:new()`)

> Nome do campo mantido pra compat com main.lua/GameUI. A classe é nova
> (CombatSequence via EventManager; antiga CombatAnimationSystem deletada).

## L83-85 (em `instance.discard`, junto a `instance.economySystem = EconomySystem:new()`)

> Sistema de economia e loja. ShopSystem é singleton-na-run: criado uma
> vez aqui e injetado em CardRewardScreen. Evita re-init de pools por
> raridade a cada open/refresh.

## L89-90 (em `instance.discard`, junto a `instance.scoreSystem = ScoreSystem:new()`)

> Pontuação TINTA×SELO (F3 gameplay-overhaul). game.score espelha
> scoreSystem.runScore pra compat com EndScreens/telas antigas.

## L93 (em `instance.discard`, junto a `instance.selectedClass = nil`)

> Sistema de classes (Slay the Spire style)

## L104 (em `Game:initializeDeck`, junto a `self.deck = self.runManager:buildPlayableDeck()`)

> Modo Slay the Spire: usa deck dinâmico da corrida

## L117-118 (em `Game:shuffleDeck`, junto a `local rng = require("src.systems.Rng").get()`)

> Stream "misc" do Rng da run (Out/2026): com love.math.random a mesma
> seed não reproduzia o combate — a mão de cada turno saía diferente.

## L127-129 (em `Game:startGame`, junto a `CombatBeats.clear()`)

> Batalha nova: nenhum acontecimento da anterior pode vazar pra ca
> (beats da morte, veneno, upkeep). A fila de beats e a espinha do
> combate — limpa-la e parte de zerar o combate.

## L164 (em `self._exhaustedThisBattle`, junto a `self:recomputeMaxJokerSlots()`)

> Teto de coringas ativos = base + bancadas compradas na loja.

## L167-168 (em `self._exhaustedThisBattle`, junto a `self:_syncJokersFromRun()`)

> Restaura jokers da run (em saves antigos vinham de currentDeck → migrados
> pelo RunManager:_migrateJokersFromDeck). Em runs novas, jokers={} vazio.

## L172-173 (em `self._exhaustedThisBattle`, junto a `self:promoteInnateCardsToTop()`)

> Reordena o deck para que cartas com flag `innate` fiquem no topo e sejam
> compradas primeiro na mao inicial. Em Slay, innate = sempre comeca na mao.

## L176-180 (em `self._exhaustedThisBattle`, junto a `for i = 1, Config.Game.INITIAL_HAND_SIZE + self:getShopServiceCount("card_draw_upgrade") do`)

> Stagger no draw inicial pra entrada ficar elegante em vez de pop-in.
> A mão inicial acompanha o grimório de compra extra (serviço da loja):
> INITIAL_HAND_SIZE e CARDS_PER_TURN são o mesmo número por design
> (F1: "mão inicial = draw por turno"), e separá-los faria do primeiro
> turno o único turno sem o benefício comprado.

## L186-187 (em `self._exhaustedThisBattle`, junto a `function Game:promoteInnateCardsToTop()`)

> Move cartas com `innate=true` para o topo do deck (ordem preservada entre elas).
> Chamado apos shuffleDeck para garantir que innate sejam as primeiras compradas.

## L203-204 (em `self.deck`, junto a `function Game:getDeckOrigin()`)

> Coordenadas visuais da pilha de deck (canto inferior direito).
> Cartas novas começam aqui visualmente antes de voar pro slot na mão.

## L211-213 (em `Game:getDeckOrigin`, junto a `function Game:drawCard(staggerDelay)`)

> staggerDelay: segundos antes de iniciar a materialização visual. Usado por
> callers que sacam múltiplas cartas pra criar cascata (Balatro-style).
> nil ou 0 = materializa imediato.

## L215-216 (em `Game:drawCard`, junto a `if #self.deck == 0 and #self.discard > 0 then`)

> Se o deck esvaziou mas ha discard, reembaralha (Slay-style). Sem isso,
> starter de 2 cartas trava o jogador no turno 2.

## L223 (em `self.discard`, junto a `self:promoteInnateCardsToTop()`)

> Innate sempre fica no topo: shuffleDeck embaralhou junto, então re-promover.

## L229-231 (em `self.discard`, junto a `if card.cancelDissolveAnim then`)

> Reset estado visual residual. cancelDissolveAnim zera dissolve E mata
> os eventos pendentes (ease de 0→1) — sem isso, a carta recém-sacada
> vê o ease continuar e some visualmente. Ver Card:cancelDissolveAnim.

## L241-244 (em `self.discard`, junto a `local EM = _G.EventManager`)

> ===== Animação de draw (Balatro-style) =====
> Carta começa invisível na posição do deck (canto inf. direito),
> depois materializa com partículas e voa pro slot. setTargetPos do
> GameplayScene (chamado todo frame) ease renderX→slot.

## L258-259 (em `self.discard`, junto a `pcall(Sfx.playWithVariation, "cardDraw", 1.0, 0.15)`)

> Pitch variado por carta drawn pra evitar fadiga (sequência de
> 4-5 draws no início de cada turno seria muito repetitiva).

## L268-273 (em `self.discard`, junto a `function Game:drawForTurn()`)

> Draw de inicio de turno (F1 gameplay-overhaul):
> Fixo: compra CARDS_PER_TURN (5, StS-style) — a mão foi descartada no
> fim do turno anterior, então todo turno recomeça com mão fresca
> (+ cartas retain que sobreviveram).
> O antigo "draw de emergência +3 com mão vazia" morreu: ele PREMIAVA
> esvaziar a mão, o oposto do que o jogo precisa.

## L281-283 (em `Game:drawForTurn`, junto a `self._jokerThornFiredThisTurn = {}`)

> P2.3 (Jul/2026, rebalance v2): thorn de JOKER dispara 1x/turno por
> joker — nova janela a cada turno do jogador (ver EffectSystem
> processTriggerEffect on_defend_damage).

## L287-289 (em `self._jokerThornFiredThisTurn`, junto a `local baseDraw = (Config.Game.CARDS_PER_TURN or 5)`)

> + grimório de compra extra comprado na loja (serviço `card_draw_upgrade`):
> permanente pelo resto da run, e por isso soma na BASE, não no bônus de
> seal (que é consumido a cada turno).

## L292-293 (em `self._jokerThornFiredThisTurn`, junto a `local sealBonus = self._sealDrawBonus or 0`)

> Blue Seal acumula compras extras quando cartas com seal são jogadas.
> Consumido aqui (uma vez por turno) e zerado.

## L302-303 (em `self._jokerThornFiredThisTurn`, junto a `for i = 1, total do`)

> Stagger entre cartas pra criar cascata Balatro-style (~80ms entre cada).
> drawCard agenda o materialize via EventManager.after com esse delay.

## L309-311 (em `self._jokerThornFiredThisTurn`, junto a `function Game:applyJokerEffects(card, baseValue, turnContext)`)

> Aplica efeitos dos jokers ativos a uma carta.
> turnContext (opcional) carrega info agregada do turno (tagCounts, activeCombos,
> allSelectedCards). ComboSystem (Fase 3) usa isso para amplificar antes dos jokers.

## L316 (em `Game:applyJokerEffects`, junto a `function Game:setDeck(deckId)`)

> Novos métodos para gerenciamento de decks

## L349 (em `Game:hasCardInDeck`, junto a `function Game:startNewRun(classId, opts)`)

> ===== SISTEMA SLAY THE SPIRE =====

## L351-352 (em `Game:hasCardInDeck`, junto a `function Game:startNewRun(classId, opts)`)

> Inicia uma nova corrida com uma classe
> opts.seal = Selo do Grimório escolhido na seleção de classe (0..10).

## L357 (em `Game:startNewRun`, junto a `UnlockSystem.ensure()`)

> Meta-progressão: migra perfil antigo ANTES de qualquer contador mudar.

## L374-375 (em `Game:startNewRun`, junto a `function Game:addCardToRun(cardId, meta)`)

> (Game:completeBattle removido no rebalance v2 — chamava
> RunManager:completeBattle, caminho morto extinto no P3.1; zero callers.)

## L377-378 (em `Game:startNewRun`, junto a `function Game:addCardToRun(cardId, meta)`)

> Adiciona uma carta ao deck da corrida
> meta opcional: { edition, seal } pra cartas que vêm de packs com modifiers.

## L385-388 (em `Game:addCardToRun`, junto a `local discovered = UnlockSystem.markDiscovered(cardId)`)

> Inédita AQUI = chegou sem passar por vitrine (evento, transformação):
> ninguém mostrou o selo "NOVA", então o anúncio vira o toast + chime.
> Oferta de recompensa/loja/pacote já descobriu antes e devolve false.
> ANTES do onCardSeen: ele grava cardsSeen, que também conta como vista.

## L394-395 (em `Game:addCardToRun`, junto a `local cardData = self.deckManager.cardDatabase:getCard(cardId)`)

> Bifurca jokers: nunca entram no deck. Vão direto para jokerSlots
> + currentRun.jokers (padrão Balatro G.jokers).

## L407-408 (em `Game:addCardToRun`, junto a `if discovered then`)

> Carta comum que entrou no deck não vira aviso (o jogador acabou de
> escolhê-la); só a INÉDITA anuncia.

## L426-428 (em `Game:addCardToRun`, junto a `function Game:canAcceptJoker()`)

> True se o jogo aceita um joker novo agora. Pós-modelo coleção+bancada
> (Jul/2026) a coleção é ILIMITADA — excedentes entram na bancada em vez de
> sumir. Só exige estar em run. Mantido por compat (CardRewardScreen/autoplay).

## L433-437 (em `Game:canAcceptJoker`, junto a `function Game:syncJokerFlags()`)

> Adiciona um joker direto aos slots passivos (sem passar pelo deck/hand).
> Cumpre o invariante "joker é jogado uma vez e fica no slot pelo resto da run".
> meta opcional: { edition, seal } vinda de Buffoon packs.
> Sincroniza flags de jokers CONTÍNUOS que vivem no Player (ex: Bastião
> retain_armor — Player:onTurnStart não enxerga jokerSlots).

## L460-463 (em `Game:addJokerToRun`, junto a `local _, activated = self.runManager:addJokerToRun(cardId, meta)`)

> COLEÇÃO + BANCADA: o joker SEMPRE entra na coleção da run. Ativa se houver
> slot livre (até maxJokerSlots); senão fica na bancada — NUNCA se perde.
> (Mata o bug histórico "comprei o 4º joker e ele sumiu".) A troca de
> ativos acontece no Gerenciador de Coringas.

## L477-480 (em `Game:addJokerToRun`, junto a `function Game:rebuildJokerSlots()`)

> Reconstrói jokerSlots a partir dos jokers ATIVOS da run. Fonte única —
> usado no load (startGame), ao adquirir e ao trocar ativos no gerenciador.
> Efeitos contínuos/trigger são lidos ao vivo de jokerSlots, então trocar
> ativos basta reconstruir + sincronizar flags contínuas (retain_armor etc.).

## L492-493 (em `self.jokerSlots`, junto a `function Game:setJokerActive(ownedIndex, active)`)

> Ativa/desativa um joker possuído (índice na coleção da run), respeitando o
> teto de slots. Rebuilda os slots e persiste. Retorna (ok, motivo).

## L501-505 (em `Game:setJokerActive`, junto a `local run = self.runManager.currentRun`)

> Fora da luta, checkpoint (sincroniza ouro/HP): o saveRun cru
> gravava o deck/vitrine ATUAIS com o ouro do checkpoint anterior —
> comprar na loja, trocar coringa e fechar a janela devolvia o ouro
> com a compra no bolso. Na luta segue cru: o save do INÍCIO dela
> (vida cheia do começo) é o que vale.

## L526-528 (em `Game:synchronizeRunDeck`, junto a `self.deck = self.runManager:buildPlayableDeck()`)

> Reconstrói o deck jogável a partir do deck da corrida. Em plena
> batalha a mão atual fica como está: as cartas novas aparecem quando
> a mão for recarregada ou nos próximos turnos.

## L590-595 (em `Game:selectCard`, junto a `local seq = self.combatAnimationSystem`)

> MÃO TRAVADA ENQUANTO AS CARTAS RESOLVEM. Com o ritmo por beats a
> resolução dura segundos, e nessa janela dava pra mexer na seleção: a
> `selectedCards` é a MESMA tabela que o CombatSequence percorre.
> Selecionar derrubava o jogo ("attempt to index local 'g'" — carta sem
> geometria); desselecionar era pior porque não quebrava nada: devolvia a
> mana de uma carta que já estava sendo jogada.

## L621 (em `Game:selectCard`, junto a `if card.juice_up then card:juice_up(0.15, 0.05) end`)

> Juice kick: feedback instantâneo de clique.

## L623-624 (em `Game:selectCard`, junto a `if _G.jiggleScreen then _G.jiggleScreen(0.25) end`)

> Jiggle micro Balatro-style (engine/ui.lua:990): cada seleção
> empurra leve energia no acumulador, dando sensação de peso à ação.

## L632-644 (em `Game:selectCard`)

> ===== PASSIVAS DE CLASSE (identidade de gameplay — Jul/2026) =====
> Warrior "Ímpeto":  3+ ataques no mesmo turno → +1 Força (na batalha) (era 2+ até Out/2026).
> Mage "Conduíte":   começa toda batalha com orbe de Raio (4) e Foco 0/1/2 (cresce a cada 2 atos).
> Rogue "Toxinas":   o 1º ataque de cada turno aplica 1/2/3 de Veneno (2t, cresce a cada 2 atos);
> 2+ ataques no mesmo turno → +2 nesse Veneno (na batalha).
> CRESCER NA LUTA (Out/2026, balanceamento de classe): so o Impeto crescia
> DENTRO da batalha, e a bateria mostrou o resultado — guerreiro 43%, mago
> 13% (lutas de 12-18 turnos no A5-A6), ladino 17% (morre no chefe do A5).
> Impeto e Toxinas tem a mesma forma (regra de turno que soma na batalha).
> O Conduite TAMBEM crescia (+1 Foco por turno com 2+ cartas de orbe) ate os
> combos simples + ENEMY_POWER: com o inimigo mais fraco o mago foi a 73-90%
> e o crescimento saiu (mago 47%, bateria 30 runs).
> Toda ativação gera toast — nada acontece invisível (lei do projeto).

## L646-650 (em `Game:selectCard`, junto a `function Game:classPassiveTier()`)

> Degrau das passivas que CRESCEM com a run (Out/2026): 1 nos atos 1-2,
> 2 nos atos 3-4, 3 nos atos 5-6 (endless fica no ultimo degrau+1).
> Bateria do piloto v6: guerreiro 47% (Impeto rende Forca a cada batalha),
> ladino 23-27% e mago 6-13% — Conduite e Toxinas eram FIXAS a run inteira
> e as duas classes quebravam nos atos 4-6, quando o inimigo ja escalou.

## L660 (em `Game:applyClassBattleStartPassive`, junto a `self._jokerThornFiredThisTurn = {}`)

> P2.3: janela nova de thorn-de-joker no comeco de cada batalha.

## L665-669 (em `self._jokerThornFiredThisTurn`, junto a `if self.player.addBuff then`)

> Auditoria Jul/2026 (bateria 2 do autoplay): mago morria no boss do
> A1 — orbe de potencia FIXA nao escala com nada enquanto guerreiro
> (Forca) e ladino (Veneno) compoem. Conduíte agora tambem concede
> 1 de Foco: toda evocacao da batalha sai +1, e cartas de Foco
> empilham em cima (eixo de scaling da classe, StS Defect).

## L671-679 (em `self._jokerThornFiredThisTurn`, junto a `local f0 = self:classPassiveTier() + Game.MAGE_FOCUS_OFFSET`)

> Re-baseline Jul/2026 (bateria 10x3 pos-v5.17): mago 0/10 com
> warrior 5/10 — mesmo com o bot comprando defesa, o mago nao
> converte A2-F8/A3. Foco inicial 1→2: cada pulso/evocacao sai
> +2 desde o turno 1 (a alavanca e a identidade da classe).
> Out/2026: Foco inicial cresce com a run, ver classPassiveTier.
> 2/3/4 -> 0/1/2 depois que o f67ebe4 consertou a passiva (ela so
> valia na 1a luta da run): com ela em toda luta e o Conduite
> crescendo, o mago foi a 63% (30 runs); 1/2/3 deu 77%; 0/1/2 deu
> 53% (meta 40-55%). O Foco agora vem do JOGO (Conduite, cartas).

## L687-689 (em `self._jokerThornFiredThisTurn`, junto a `Game.TOXIN_GROWTH = 2`)

> Quanto o Veneno das Toxinas sobe a cada turno com 2+ ataques. +1 (bateria
> 15 runs): ladino 17% -> 20%, ainda morrendo no chefe do A4/A5 com lutas de
> 8-9 turnos — a curva de veneno cresce devagar demais contra 600 de vida.

## L692-697 (em `self._jokerThornFiredThisTurn`, junto a `Game.MAGE_FOCUS_OFFSET = -1`)

> Deslocamento das passivas que crescem com a run sobre o degrau de
> classPassiveTier (1/2/3). Foco inicial do mago = degrau + MAGE_FOCUS_OFFSET
> (-1 -> 0/1/2, ver applyClassBattleStartPassive); Veneno das Toxinas =
> degrau + ROGUE_POISON_OFFSET (+ o que cresceu na luta). Sao os knobs do
> sweep (BALANCE_MAGE_FOCUS / BALANCE_ROGUE_POISON em tools/balance_sim.lua);
> o piloto (tools/balance_ai.lua) espelha a mesma conta.

## L701-704 (em `self._jokerThornFiredThisTurn`, junto a `Game.IMPETUS_ATTACKS = 3`)

> Quantos ataques no turno o Impeto pede. 2 -> 3 (Out/2026): com o inimigo
> suavizado (d0e41d4) e o DoT ignorando armadura, a bateria combinada de 30
> runs deu guerreiro 67% — acima da meta 40-55%. A Forca por golpe e a
> curva mais forte do jogo; pedir 3 ataques a desacelera sem mexer no resto.

## L736-737 (em `Game:playSelectedCards`, junto a `if self.combatAnimationSystem and self.combatAnimationSystem.isBlocking`)

> Guard de reentrância (autoplay A5): startCombat com sequência ativa
> chamava onComplete SEM processar as cartas — jogada engolida.

## L747-749 (em `Game:playSelectedCards`, junto a `local snapshot = {}`)

> Snapshot das cartas selecionadas (selectedCards e limpo em onCombatAnimationComplete).
> turnContext e construido UMA VEZ antes da animacao iniciar. Fase 3 (ComboSystem)
> vai enriquecer com activeCombos; por ora ja carrega tagCounts para debug.

## L772-774 (em `activeCombos`, junto a `local EM = _G.EventManager`)

> Remove as cartas da mão IMEDIATAMENTE quando a animação começa.
> Juice kick escalonado via EventManager: cartas estouram de 60ms em 60ms
> conforme voam pro centro (sensação de "combo sendo lançado").

## L794-796 (em `func`, junto a `self.combatAnimationSystem:startCombat(`)

> (O antigo `card._expectedProcs` saiu daqui: o pacing nao e mais
> ESTIMADO. Com a fila de beats a proxima carta espera a anterior
> terminar de verdade — previsao errada nao existe mais.)

## L806-808 (em `func`, junto a `return self:processCardInCombat(card, turnContext, { beats = beatSink })`)

> Callback para processar cada carta (com contexto do turno).
> `beatSink` vem do CombatSequence: os efeitos secundarios da
> carta sao COLETADOS e tocados um a um depois do impacto.

## L814-819 (em `func`)

> ===== Editions (Fase 3.2) / Seals (Fase 3.3) =====
> As tabelas de valor (Foil +5, Holo x1.2, Polychrome x1.5, selo Red x2)
> moram em DamagePreview (fonte unica da conta da carta). A edition Negative
> (+1 vaga de coringa por carta de cor invertida) SAIU em Out/2026 a pedido
> do dono: ninguem via a mecanica, so a carta "bugada". Copias em saves
> antigos viram carta comum em RunManager:buildPlayableDeck.

## L821-824 (em `func`, junto a `function Game:getShopServiceCount(id)`)

> Quantas vezes um SERVIÇO da loja foi comprado nesta run (bancada extra de
> coringa, grimório de compra extra). Fonte única: o ledger do RunManager,
> que viaja no save. Fora de run mode não existe loja persistente → 0.
> Ver src/systems/ShopServices.lua.

## L832-833 (em `Game:getShopServiceCount`, junto a `function Game:recomputeMaxJokerSlots()`)

> Teto de coringas ATIVOS = base do Config + bancadas COMPRADAS na loja
> (serviço `joker_slot`). Chamar após startGame e após comprar bancada.

## L837-838 (em `Game:recomputeMaxJokerSlots`, junto a `if self.isRunMode and self.runManager and self.runManager.currentRun then`)

> Espelha no run pra o teto de ATIVOS (RunManager:getMaxJokerSlots) seguir
> as bancadas compradas — senão a bancada usaria só o base fixo.

## L845-849 (em `Game:recomputeMaxJokerSlots`, junto a `function Game:processCardInCombat(card, turnContext, opts)`)

> Resolucao de UMA carta. `opts.beats` (array) liga o modo SEQUENCIADO: o
> dano/bloqueio continuam no instante do impacto, mas os efeitos SECUNDARIOS
> (veneno, cura, orbe, espinhos, gatilhos de joker) sao COLETADOS e devolvidos
> em `result.beats` pro CombatSequence tocar um de cada vez. Chamada sem opts
> (testes, autoplay, smoke_upgrades) mantem tudo sincrono como sempre foi.

## L864-869 (em `result`, junto a `local function computeCardValue()`)

> Pipeline unificado attack/defense: effects → stat → combo → jokers →
> edition → seal → Fraco/Fragil. A CONTA mora em DamagePreview.cardValue
> (fonte unica, Out/2026): a previa que o jogador ve antes de jogar e esta
> mesma funcao — aqui so entram os efeitos colaterais (Eco gasto, toast e
> tick dos coringas, banner do combo). Forca por golpe e scaling em dobro
> (auditoria Jul/2026) tambem moram la — nao reintroduzir soma aqui.

## L906-907 (em `applySealSideEffects`, junto a `local function processAdditionalEffects()`)

> Efeitos secundários da carta (apply_debuff, heal, etc.) — excluem tipos que
> já foram consumidos em applyCardEffects acima.

## L921-923 (em `processAdditionalEffects`, junto a `if self.enemy.health <= 0 then`)

> Guard: inimigo ja morto nao recebe mais dano (evita "batendo no cadaver"
> quando o player encadeia multiplas cartas de ataque e a primeira ja mata).
> Retorna vazio pra CombatSequence nao spawnar damage number nem shake.

## L926-928 (em `processAdditionalEffects`, junto a `if card.exhaust and card.id then`)

> Exhaust TAMBEM precisa do bookkeeping aqui: sem isso a carta sai
> da mao e nao chega em pilha nenhuma (anomalia "cartas sumiram"
> do autoplay v3) — e escapa da remocao permanente da run.

## L945-947 (em `processAdditionalEffects`, junto a `if self.selectedClass == "rogue" and not self._toxinAppliedThisTurn`)

> Passiva rogue "Toxinas": 1º ataque do turno aplica 1 de Veneno.
> Debuff no inimigo = mudanca de ESTADO: instante proprio, depois do
> dano (pedido do dono — "esperar ele receber o buff ou debuff").

## L952-953 (em `processAdditionalEffects`, junto a `local stacks = math.max(1, self:classPassiveTier() + Game.ROGUE_POISON_OFFSET`)

> Out/2026: Veneno cresce com a run (1 → 2 → 3) e na luta
> (+2 a cada turno com 2+ ataques, ver applyClassTurnPassives).

## L967-971 (em `processAdditionalEffects`, junto a `self:settleEnemyDamage(sink)`)

> Morreu ou cruzou os 30% com ESTE golpe? Os dois sao o PRIMEIRO passo
> depois do dano — antes do veneno, da cura, do que mais a carta faca.
> A deteccao da morte nao mora mais AQUI (era um `wasAlive` local, e
> por isso so este caminho encenava a morte): mora no Enemy, marcada em
> toda queda de vida, e chega aqui como `_pendingDeath`.

## L974-975 (em `processAdditionalEffects`, junto a `self.effectSystem:applyTriggerEffects(self, "attack", {`)

> Triggers on-attack (ex: lifesteal de jokers, on_attack_debuff em cartas)
> procSink: triggers de joker também viram PROCS (tick no slot).

## L988-991 (em `processAdditionalEffects`, junto a `local armorBefore = self.player.armor`)

> Auditoria Jul/2026: o cap de Bloqueio (30) truncava EM SILENCIO —
> o jogador via "+20" e "+17" na mesma leva e nunca sabia que 7
> evaporaram. Agora o desperdicio e anunciado (decisao informada:
> "nao vale jogar o 2o escudo agora").

## L1011-1012 (em `processAdditionalEffects`, junto a `self.effectSystem:applyTriggerEffects(self, "defend", {`)

> Triggers on-defend (ex: reflexo de dano em jokers e em defense cards
> como Barreira de Fogo via context.sourceCard).

## L1022-1025 (em `processAdditionalEffects`, junto a `Debug.warn("[Game] Joker chegou via hand (leak arquitetural): " .. tostring(card.id))`)

> Joker chegou via hand: leak arquitetural. Pós-Fase joker-split,
> jokers devem ser adquiridos via Game:addJokerToRun direto, nunca
> entrar no deck/hand. Aceita defensivamente pra não travar a run,
> mas alerta no log pra detectar regressão.

## L1027-1028 (em `processAdditionalEffects`, junto a `if self.isRunMode and card.id then`)

> Roteia pelo caminho canônico (coleção + bancada) em vez de empurrar
> a instância direto — mantém o invariante e nunca perde o joker.

## L1035-1038 (em `processAdditionalEffects`, junto a `if sink and card.effects then`)

> Cartas de efeito executam seu efeito e são descartadas.
> Com sink ativo percorremos os efeitos AQUI (um passo cada) em vez de
> chamar `card.passive`, que dispara os N efeitos no mesmo instante —
> era o caso da Consumir do mago (evoca tudo + ganha Foco de uma vez).

## L1053-1054 (em `processAdditionalEffects`, junto a `if card.exhaust and card.id then`)

> Exhaust: pula o descarte (Slay-style) E agenda remocao permanente
> da run ao final da batalha. Tratamos aqui antes do push pro discard.

## L1060-1061 (em `processAdditionalEffects`, junto a `if card.type ~= "joker" and not card.exhaust then`)

> Descarte: cartas jogadas vao pra pilha de discard, exceto jokers (ficam
> em jokerSlots) e exhaust (somem da batalha e sao removidas da run).

## L1070-1073 (em `Game:onCombatAnimationComplete`, junto a `local ctx = self._currentTurnContext`)

> Aplica efeitos de combo do tipo "once" (apply_debuff, heal, evoke_on_combo)
> apos todas as cartas terem sido processadas. BEAT PROPRIO (Set/2026): o
> premio do combo chegava no mesmo frame do dissolve da ultima carta e
> passava batido — agora tem o instante dele, depois de tudo.

## L1085-1088 (em `self.selectedCards`, junto a `end`)

> TURNO MULTI-JOGADA (playtest Jul/2026): jogar cartas NÃO encerra o
> turno — mana restaurada/cartas compradas por efeitos ficam usáveis
> AGORA (cartas de mana/draw eram letra morta no modelo de 1 jogada).
> O turno só passa no botão ENCERRAR TURNO (Game:endTurn).

## L1091-1092 (em `self.selectedCards`, junto a `function Game:endTurn()`)

> Encerra o turno do jogador: descarta a mão (exceto retain) e passa a
> vez pro inimigo. Chamado pelo botão "Encerrar Turno".

## L1097-1098 (em `Game:endTurn`, junto a `self._endTurnQueued = true`)

> Clique durante a animação: ENFILEIRA (GameplayScene processa ao
> fim da jogada) — engolir o clique era "encerro e nada acontece".

## L1108-1112 (em `Game:endTurn`, junto a `if self.effectSystem and self.effectSystem.orbPassiveTick then`)

> Pulso passivo dos orbes (Defect-style) antes do inimigo agir — se o
> pulso matar, enemyTurn tem guard de inimigo morto e isPhaseCleared
> transiciona no proximo frame.
> UM ORBE POR VEZ: o sink vira uma fila de beats (cada orbe pulsa no
> instante dele). Sem EventManager (headless) o push executa na hora.

## L1121-1122 (em `pulses`, junto a `self._enemyActing = false`)

> Turno inimigo NOVO: limpa flag de "agindo" (v3) — se ficou stale de uma
> batalha abandonada, sem isso o inimigo nunca mais agiria.

## L1140-1154 (em `kept`, junto a `function Game:_announceEnrageIfPending(sink)`)

> ENFURECIDO: o instante em que o inimigo cruza os 30% de vida.
>
> Enemy:takeDamage detecta a VIRADA e levanta `_pendingEnrage` (ver o
> comentario la). Aqui esse estado vira ACONTECIMENTO: um beat bloqueante com
> rugido, aura, numero e toast — porque a conta de dano do jogador acabou de
> mudar e ele precisa saber no momento exato.
>
> `sink` presente (resolucao de carta) = vira um passo da carta, logo depois do
> dano que causou a virada. Ausente = o beat entra sozinho; e se estivermos
> DENTRO de um beat (pulso de orbe, reflexo de espinhos, checkpoint do turno),
> o anuncio roda ali mesmo e ESTENDE aquele beat pro tempo de STATUS — assim o
> caso comum (ninguem enfureceu) nao paga ar morto e o caso raro ganha o
> instante dele.
>
> Retorna true se anunciou.

## L1186-1187 (em `body`, junto a `CombatBeats.mark("enemy.enraged")`)

> Ja estamos dentro de um beat: este E o instante (a fila segura mais).
> `mark` deixa o acontecimento visivel no trace mesmo sem beat proprio.

## L1196-1237 (em `body`, junto a `function Game:announceDeathIfPending(sink)`)

> ============================================================================
> A MORTE DO INIMIGO — TAMBEM UM ACONTECIMENTO (Set/2026)
> ============================================================================
> Queixa do dono jogando: "em alguns cenarios o mob nao esta tendo a animacao
> de morrer, cair no chao etc. Acho que e quando se buffa".
>
> A hipotese "quando se buffa" estava PERTO: o que os cenarios sem morte tem
> em comum nao e o buff, e a FONTE DO GOLPE FINAL. `_onEnemyDeath` (animacao,
> rugido, shake, pontuacao da batalha) so era chamado do caminho da carta de
> ATAQUE. Matar com magia, com pulso ou evocacao de orbe, com veneno ou com
> espinhos levava a vida a zero sem que ninguem encenasse nada — e as fontes
> que o dono associa a "se buffar" (Foco + orbes do mago, espinhos armados por
> uma carta de defesa) sao justamente essas.
>
> A correcao espelha o ENFURECIDO: `Enemy` marca a VIRADA vivo->morto
> (`_pendingDeath`, no unico lugar por onde a vida cai) e aqui isso vira um
> BEAT que segura a fila pelo tempo de o corpo cair. Fonte nenhuma fica muda,
> porque a deteccao deixou de morar no caminho e passou a morar na entidade.
>
> `sink` presente (resolucao de carta) = a morte vira um passo da carta, logo
> depois do dano que a causou. Dentro de um beat (pulso de orbe, reflexo de
> espinhos, veneno) = este E o instante, e a fila segura mais. Fora de tudo =
> beat proprio.
>
> Retorna true se a morte foi encenada nesta chamada.
> AGENDAR NAO E EXECUTAR — a distincao que travou o jogo (Set/2026)
>
> Primeira versao guardava so `_deathHandled`, que so vira true DENTRO do beat,
> quando ele roda. Entre AGENDAR e RODAR passam-se dezenas de frames (a cadeia
> da carta continua: procs, orbes, dissolve). E o checkpoint da GameplayScene
> pergunta "morto e nao encenado?" A CADA FRAME — via um `announceDeathIfPending`
> por frame. Resultado: cada frame dessa janela empurrava OUTRO beat de morte
> de 1,1s pra fila. Medido em tools/test_death_midchain: 11 beats `enemy.death`
> numa jogada de 2 cartas = 12s de fila morta; com a fila travada, `isBlocking()`
> nunca cai, os botoes ficam cinzas e a tela de espolios/vitoria NUNCA entra
> ("matei o boss e o jogo parou", dono).
>
> Por isso existem DUAS flags, e elas nao sao a mesma coisa:
> `_deathStaged`  — a morte ja foi AGENDADA (existe um beat pra ela).
> `_deathHandled` — a morte ja ACONTECEU (o `_onEnemyDeath` rodou).
> Quem decide "preciso agendar?" tem que olhar a PRIMEIRA. Guardar intencao
> com o flag do resultado e a forma geral deste defeito.

## L1242-1245 (em `Game:announceDeathIfPending`, junto a `if not (e._pendingDeath or not e:isAlive()) then return false end`)

> REDE: inimigo morto e ainda nao agendado conta como pendente mesmo sem a
> marcacao. A marcacao cobre toda fonte de dano de HOJE; a rede cobre a
> fonte de AMANHA (quem mexer na vida por fora do Enemy). Nenhuma morte
> pode chegar a tela de espolios sem ter acontecido antes.

## L1252-1253 (em `body`, junto a `if self.enemy ~= enemyRef then`)

> Passo atrasado de uma batalha que ja trocou: no-op. Solta o
> agendamento pra que a batalha NOVA possa agendar a morte dela.

## L1264-1266 (em `body`, junto a `CombatBeats.mark("enemy.death")`)

> Ja estamos dentro de um beat (o orbe que pulsou, o veneno que ticou,
> o espinho que refletiu): a morte acontece NO golpe que a causou e a
> fila segura ate o corpo assentar.

## L1275-1276 (em `body`, junto a `function Game:_intentAppliesDot()`)

> O intent em execucao poe veneno/queimadura no jogador? (o beat do DoT do
> jogador e empurrado ANTES do golpe acontecer — precisa saber se tera ar).

## L1285-1288 (em `Game:_intentAppliesDot`, junto a `function Game:_announcePhaseIfPending(sink)`)

> FASE NOVA do chefe (Rainha do Eclipse abaixo de 50%): mesmo contrato do
> ENFURECIDO — o Enemy marca `_pendingPhase` no funil de dano, aqui vira
> acontecimento (beat STATUS com nome da fase, rugido e shake). O intent ja
> anunciado NAO muda; o kit novo vale do proximo intent em diante.

## L1328-1330 (em `body`, junto a `function Game:settleEnemyDamage(sink)`)

> PONTE UNICA DO POS-DANO: tudo que um dano ao inimigo pode ter causado e
> encenado aqui, em ordem — primeiro a MORTE (se matou, nada mais importa),
> depois o ENFURECIDO. Chamada depois de cada dano, de qualquer fonte.

## L1338-1344 (em `Game:settleEnemyDamage`, junto a `function Game:announceEnrageIfPending(sink)`)

> ALIAS de compatibilidade: `settleEnemyDamage` e o nome honesto, mas
> `announceEnrageIfPending` e o nome que o EffectSystem conhece (o helper
> `checkEnrage` chama isto depois de CADA takeDamage dele — foi justamente
> essa varredura ja existente que deu cobertura de graca as 6 fontes de dano
> de la). PENDENCIA ASSUMIDA: quando der pra mexer no EffectSystem, trocar
> `checkEnrage` pra chamar `settleEnemyDamage` e apagar este alias — o nome
> de um hook universal nao pode prometer so metade do que ele faz.

## L1349-1353 (em `Game:announceEnrageIfPending`, junto a `function Game:isDeathSettled()`)

> A morte ja "aconteceu na tela"? Enquanto for false, nenhuma tela de desfecho
> (espolios, vitoria) pode entrar. E a regra que o dono pediu por nome: "a tela
> de vitoria ta aparecendo rapido demais, so aparece quando a gente tem a
> confirmacao que ele morreu". Mora aqui, e nao inline na cena, pra ser
> alcancavel por teste (doutrina de defeitos 1).

## L1358-1359 (em `Game:isDeathSettled`, junto a `function Game:isReadyForEndScreen()`)

> Pode trocar pra tela de desfecho? Combate parado (inclui a fila de beats) E
> morte assentada.

## L1366-1384 (em `Game:isReadyForEndScreen`, junto a `function Game:enemyTurn()`)

> ============================================================================
> TURNO DO INIMIGO — UMA CADEIA DE ACONTECIMENTOS (Set/2026)
> ============================================================================
> Pedido do dono: "quando o inimigo se buffa, ou sofre algum debuff precisamos
> deixar isso ser algo bloqueando do turno seguir". O turno do inimigo deixou
> de ser um bloco sincrono com dois respiros no fim e virou uma FILA de beats
> (src/systems/CombatBeats.lua), cada um ocupando seu instante e segurando o
> proximo:
>
> armadura expira > furia > TELEGRAFIA > acao (defende/buffa/golpeia)
> > espinhos refletem > veneno tica > proximo intent
> > upkeep do jogador > compra > gatilhos de inicio de turno (um a um)
> > a vez volta pro jogador
>
> Os beats sao empurrados AQUI, em ordem; nada e empurrado de fora da fila
> durante a execucao (o apex da investida so LEVANTA UMA FLAG — ver `struck`
> abaixo), senao a ordem quebraria. Token `_enemyTurnSeq` + `enemyRef`
> invalidam passos atrasados se a batalha mudou no meio (morte, andar novo,
> restart).

## L1386-1387 (em `Game:enemyTurn`, junto a `if not self.enemy:isAlive() then`)

> Bug fix: inimigo morto NAO ataca. Antes nao havia check, e enemyTurn
> rodava no mesmo frame que isPhaseCleared detectava morte -> dano fantasma.

## L1389-1390 (em `Game:enemyTurn`, junto a `self.turn = "player"`)

> Devolve turn pro jogador formalmente, mas isPhaseCleared vai cuidar
> de transicionar pra cardReward no proximo frame.

## L1395-1398 (em `Game:enemyTurn`, junto a `if self._enemyActing then return end`)

> Re-entrancia (v3): com os respiros do turno, `turn` fica "enemy" por
> ~2s — caller que chama enemyTurn() por frame (gate de cena/teste)
> re-executaria o intent. O turno inimigo e UM ato: segunda chamada e
> no-op ate o beat final devolver a vez.

## L1405-1406 (em `Game:enemyTurn`, junto a `local function beat(fn)`)

> Envelope de TODO beat deste turno: se a batalha trocou, o passo atrasado
> vira no-op em vez de mexer num inimigo que nao existe mais.

## L1414-1415 (em `beat`, junto a `local intent = self.enemy.nextIntent or "attack"`)

> F1: executa o intent TELEGRAFADO no turno anterior (o jogador viu o
> icone/numero no EnemyHud e pode se preparar). Depois rola o proximo.

## L1427-1431 (em `float`, junto a `CombatBeats.push("enemy.enrage_check", beat(function()`)

> ===== BEAT: checkpoint do ENFURECIDO =====
> Rede de seguranca: se alguma fonte fora da resolucao de carta cruzou os
> 30% (combo, pulso de orbe, reflexo de espinhos), o anuncio sai AQUI,
> antes do inimigo agir — nunca fica mudo. Custa MICRO quando nao ha nada
> a anunciar; quando ha, `extendCurrent` compra o tempo de STATUS.

## L1436-1438 (em `float`, junto a `if (self.enemy.armor or 0) > 0 then`)

> ===== BEAT: armadura do inimigo EXPIRA =====
> Simetria com o jogador: defend protege contra UM turno de ataques, nao
> vira muro. Autoplay A1: elite com 4 HP ficou imortal re-encapando armor.

## L1445-1447 (em `float`, junto a `self.battleTurn = (self.battleTurn or 0) + 1`)

> ===== BEAT: Furia anti-stall =====
> Turno 8+ o inimigo ganha +2 de dano por turno, ATE +10 total (teto;
> autoplay A4: sem teto virava sentenca). E mudanca de ESTADO: beat longo.

## L1449-1450 (em `float`, junto a `if self.isRunMode and self.runManager and self.runManager.currentRun then`)

> Turnos da RUN inteira (resumo da tela final). Vive na run pra viajar
> no save — o battleTurn zera a cada batalha.

## L1469-1471 (em `float`, junto a `CombatBeats.push("enemy.telegraph", beat(function()`)

> ===== BEAT: TELEGRAFIA ("o anuncio virou acao") =====
> O intent PISCA e o NOME do golpe sobe do inimigo — IntentFlash +
> ShowMoveName do StS. Passo proprio: o jogador LE o que vem antes de vir.

## L1476-1477 (em `float`, junto a `local cur = self.enemy:getIntent()`)

> Nome do golpe do KIT (enemy_kit.moves.<id>); golpe legado cai no
> nome generico do kind.

## L1486-1493 (em `float`, junto a `local it = self.enemy:getIntent()`)

> ===== BEATS: A ACAO =====
> O golpe CONGELADO no anuncio (Enemy:getIntent, kit em src/data/enemies)
> vira uma sequencia de acontecimentos, cada um no seu beat, na mesma
> ordem em que o tooltip do intent os descreve:
> bloqueio > golpe(s) > espinhos > debuff(s) no jogador > forca > cura
> > invocacao > carga
> A execucao le os CAMPOS do intent (nao o kind): um golpe pode bloquear,
> bater e debuffar no mesmo turno.

## L1518-1524 (em `playerFloat`, junto a `local function applyHit(damage, pierce)`)

> O inimigo INVESTE fisicamente e o dano e aplicado NO IMPACTO da
> investida (apex), nao num corte seco. O beat nao e por TEMPO: ele
> espera o apex acontecer (pushUntil), senao o resto do turno rodava
> por cima de um golpe ainda no ar — foi o "bug do escudo" do
> playtest Jul/2026. MULTI-GOLPE = uma investida por golpe, cada uma
> no seu beat (o Bloqueio absorve golpe a golpe e o jogador VE onde
> o escudo acabou).

## L1526 (em `applyHit`, junto a `local atkPitch = math.max(0.7, math.min(1.05, 1.1 - damage * 0.012))`)

> Pitch escalado pela magnitude (Balatro sound_manager).

## L1531-1533 (em `applyHit`, junto a `local effective = hpBefore - self.player.health`)

> Detector do piloto (Jul/2026): registrar o dano BRUTO fazia golpe
> 100% bloqueado matar o bonus flawless do score e das conquistas.
> Conta so o que FUROU o escudo.

## L1544-1545 (em `applyHit`, junto a `local okFT, FloatingText = pcall(require, "src.ui.FloatingText")`)

> Feedback no painel do jogador: "-N" real que entrou, ou
> BLOQUEADO! em aco quando o escudo segurou tudo.

## L1585-1590 (em `applyHit`, junto a `if EffectSystem.thornStacks(self) > 0 then`)

> ===== BEAT: ESPINHOS =====
> Contrato Set/2026: a carta ARMA o buff "thorn"; o REFLEXO acontece
> aqui, quando o inimigo ataca — causa e efeito em instantes separados.
> O beat so e empurrado se ha espinhos armados AGORA (a carta ja foi
> jogada no turno do jogador); o corpo confere se o golpe saiu mesmo.
> Multi-golpe reflete UMA vez por turno (o teto P2.3 continua por turno).

## L1601-1603 (em `applyHit`, junto a `for _, d in ipairs(it.debuffs or {}) do`)

> ===== BEATS: DEBUFF NO JOGADOR (um por status) =====
> Estado do jogador mudando = STATUS (0,55s): o jogador precisa ver que
> esta Fraco/Fragil ANTES de comprar a mao que isso afeta.

## L1625-1626 (em `applyHit`, junto a `Sfx.playWithVariation("enemyBuffRoar", 1.0, 0.06)`)

> Game feel v1: buff tem RUGIDO proprio (antes reusava enemyAttack
> grave — soava como golpe, confundia) + aura vermelha subindo.

## L1662-1664 (em `applyHit`, junto a `CombatBeats.push("enemy.charge", beat(function()`)

> CARGA: o turno inteiro e o aviso. O golpe carregado ja esta forcado
> como proximo intent (Enemy:rollIntent) e aparece no HUD no fim deste
> turno — o jogador tem a mao inteira pra se preparar.

## L1677-1679 (em `applyHit`, junto a `function Game:_pushEnemyTurnTail(beat)`)

> Rabo do turno do inimigo: veneno, proximo intent, upkeep do jogador, compra,
> gatilhos de inicio de turno e a devolucao da vez. Cada um num beat.
> Separado de enemyTurn so por tamanho — faz parte da MESMA cadeia.

## L1681-1684 (em `Game:_pushEnemyTurnTail`, junto a `local hasDot = false`)

> So abre o respiro do DoT quando ha DoT VISIVEL pra ticar — sem ele,
> onTurnEnd ainda precisa rodar (decrementa durations), mas sem ar.
> Set/2026: a QUEIMADURA conta aqui tambem. Checar so `poison` fazia o
> fogo do mago ticar dentro de um MICRO de 0,10s, sem tempo de ler.

## L1713-1717 (em `Game:_pushEnemyTurnTail`, junto a `if burnDmg and burnDmg > 0 then`)

> QUEIMADURA (Set/2026): segundo DoT, assinatura PROPRIA — o veneno
> chia verde, o fogo estala laranja. Quando os dois ticam no mesmo
> turno (mago com carta de ladino) o beat ganha ar extra em vez de
> despejar dois numeros no mesmo piscar: e o passo CONDICIONAL de
> CombatBeats, o mesmo do `enemy.enrage_check`.

## L1724-1727 (em `Game:_pushEnemyTurnTail`, junto a `self:announceDeathIfPending(nil)`)

> Veneno mata igual: se este tick derrubou a criatura, ela cai AGORA —
> neste beat — e nao tres passos adiante, com a barra zerada e o
> monstro em pe enquanto o turno continua rodando. (`onTurnEnd` mexe na
> vida na aritmetica crua, por isso a morte nao vem por `takeDamage`.)

## L1731-1733 (em `Game:_pushEnemyTurnTail`, junto a `if self.enemy:hasStatus("regen") then`)

> REGENERACAO do inimigo (Colosso Putrido): cura propria no fim do turno
> dele — instante proprio, a luta longa e a vantagem dele e o jogador
> precisa VER a vida voltar.

## L1753-1755 (em `Game:_pushEnemyTurnTail`, junto a `CombatBeats.push("player.debuff_decay", beat(function()`)

> Debuffs do JOGADOR decaem no fim do turno do inimigo (o que ele acabou
> de aplicar pula este decremento — Player:decayDebuffs). Sempre
> empurrado: o golpe deste turno pode ter acabado de aplicar um.

## L1760-1762 (em `Game:_pushEnemyTurnTail`, junto a `CombatBeats.push("enemy.next_intent", beat(function()`)

> Telegrafa a PROXIMA acao (EnemyHud mostra durante o turno do jogador).
> Beat proprio: o icone do proximo golpe aparecendo e informacao, e
> aparecer junto com o veneno ticando era parte do borrao.

## L1764-1765 (em `Game:_pushEnemyTurnTail`, junto a `if not self.enemy:isAlive() then return end`)

> Cadaver nao telegrafa o proximo golpe (o HUD chegava a piscar o
> intent de um inimigo que acabou de cair pro veneno/espinhos).

## L1772-1774 (em `Game:_pushEnemyTurnTail`, junto a `if not self.enemy:isAlive() or not self.player:isAlive() then return end`)

> Morreu alguem? O rabo do turno para aqui. O gate de gameOver/
> isPhaseCleared espera a fila drenar (isBlocking), entao continuar
> comprando carta pro cadaver so poluiria a tela antes da transicao.

## L1776-1777 (em `Game:_pushEnemyTurnTail`, junto a `if self.player.onTurnStart then self.player:onTurnStart() end`)

> Decrementa buffs do jogador (durations per-turno) e zera o Bloqueio.
> E aqui que os ESPINHOS armados no turno passado expiram.

## L1781-1783 (em `Game:_pushEnemyTurnTail`, junto a `if self.player.retainArmor and (self.player.armor or 0) > 0 then`)

> BASTIAO tica quando o escudo e MANTIDO (retain_armor age dentro de
> Player:onTurnStart — sem isto o joker ficava mudo no momento exato
> em que trabalha; auditoria de procs Jul/2026).

## L1797-1799 (em `Game:_pushEnemyTurnTail`, junto a `local playerDot = self.player.getDebuffStacks`)

> VENENO/QUEIMADURA NO JOGADOR (golpes do kit): perda de vida que ignora
> o Bloqueio, no comeco do turno dele, ANTES da compra. Beat proprio — e
> dano, e o jogador precisa saber de onde veio. Sem DoT, custa MICRO.

## L1827-1829 (em `Game:_pushEnemyTurnTail`, junto a `do`)

> Gatilhos de inicio de turno (regen, Forma Demoniaca, compra extra, motor
> de orbes): UM DE CADA VEZ. Antes os 3-4 caiam no mesmo frame e viravam
> uma chuva de numeros sem dono.

## L1846-1849 (em `steps`, junto a `self:announceDeathIfPending(nil)`)

> Rede final do turno: se o inimigo morreu durante o rabo e nada
> encenou (fonte nova, ordem inesperada), a morte acontece AQUI — e com
> beat, nao num piscar: `extendCurrent` estica este MICRO pro tempo de
> a criatura cair. Idempotente via `_deathHandled`.

## L1854-1858 (em `steps`, junto a `function Game:usePotion()`)

> Centraliza efeitos colaterais de morte do inimigo (anim + sfx + pausa).
> Chamado tanto por processCardInCombat (kill via ataque) quanto por enemyTurn
> (kill via poison DoT). Idempotente: se ja rodou nesta morte, nao duplica.
> wip/sustain: bebe uma poção (cura POTION_HEAL_PCT da vida máxima) no turno
> do jogador. Devolve true se bebeu. Dado puro: nada de UI por enquanto.

## L1879-1881 (em `Game:_onEnemyDeath`, junto a `if _G.jiggleScreen then _G.jiggleScreen(1.5) end`)

> Jiggle Balatro-style empilha energia (decay 5/s) — som mais "vivo" que
> random pulse do triggerShake legacy. Compõe naturalmente com o shake
> intensity-based pra impacto cumulativo no boss death (Fase 6.4).

## L1884-1887 (em `Game:_onEnemyDeath`, junto a `self._deathPauseTimer = Game.DEATH_HOLD`)

> Mesmo numero do beat da morte (Game.DEATH_HOLD): o relogio da cena e o
> hold da fila sao a MESMA duracao, uma fonte so. O beat segura o combate;
> o relogio segura a troca de tela (espolios E vitoria) — as duas metades
> da mesma regra, "a criatura cai antes de acabar".

## L1893 (em `Game:_onEnemyDeath`, junto a `local ProfileStats = require("engine.ProfileStats")`)

> Recorde histórico: toast ÚNICO quando a run cruza o bestScore.

## L1911-1913 (em `Game:_onEnemyDeath`, junto a `if run and Config.Game.POTIONS and run.currentNode and run.currentNode.type == "elite" then`)

> wip/sustain (Config.Game.POTIONS, medido e NAO adotado): elite
> vencida deixa uma POÇÃO (run.potions, até POTION_SLOTS); usar =
> Game:usePotion no turno do jogador. Sem UI — só o piloto a bebe.

## L1923-1925 (em `Game:_onEnemyDeath`, junto a `local EM = _G.EventManager`)

> Aftershock coreografado via EventManager: 2 tremores menores pós-morte
> (sensação de corpo caindo). Exemplo canônico de sequência temporal
> sem state machine dedicada.

## L1948-1950 (em `Game:isPhaseCleared`, junto a `function Game:_buildRoundEvalSources()`)

> Constrói lista de sources de ouro pra RoundEvalScreen (Fase 9 — cash out
> estilo Balatro `evaluate_round`). Cada source tem label + dollars + color.
> Chamado por main.lua após `_deathPauseTimer` expirar, antes de showCardRewards.

## L1956-1963 (em `sources`, junto a `local act = 1`)

> 1) Vitória: recompensa base por derrotar inimigo.
> Os rótulos são exibidos na RoundEvalScreen — vão pelo i18n (antes eram
> PT cravado e apareciam em português dentro da tela traduzida).
>
> Set/2026: o valor ESCALA POR ATO (Config.Economy.victoryGold) — era $5
> fixo, e com a campanha em 6 atos a renda por batalha ficava idêntica no
> ato 6 e no ato 1 enquanto todos os preços da loja escalavam. O raciocínio
> e os números medidos estão em Config.Economy.

## L1985-1987 (em `color`, junto a `do`)

> 2b) Bônus de RISCO do nó (Out/2026): elite e chefe do ato pagam uma
> linha a mais (Config.Economy.nodeBonus) — antes pagavam igual a luta
> comum e o mapa prometia um risco que a bolsa não cobria.

## L2002-2003 (em `color`, junto a `if self.economySystem then`)

> 3) Juros Balatro ($1 a cada $5, cap $5) — FONTE ÚNICA no
> EconomySystem:calculateInterest (a TopBar mostra o mesmo número).

## L2015-2016 (em `color`, junto a `return sources`)

> 4) Vitórias consecutivas (futuro: reads from EconomySystem.consecutiveWins).
> Por ora pulamos.

## L2022 (em `Game:resetHandAndDeck`, junto a `CombatBeats.clear()`)

> mesma razao do startGame: batalha nova, fila limpa

## L2024-2040 (em `Game:resetHandAndDeck`, junto a `self.turn = "player"`)

> BATALHA NOVA COMECA NA VEZ DO JOGADOR. Sempre. (Set/2026)
>
> Faltava, e o dono levou o golpe: "teve um turno de batalha que o inimigo
> ja chegou me dando dano enquanto andava, antes mesmo de chegar na tela
> pra eu jogar minha carta".
>
> Como vazava: `endTurn` poe `turn = "enemy"` e SO ENTAO enfileira o pulso
> dos orbes. Quando o pulso (ou veneno, ou espinhos) MATA o inimigo — que
> e exatamente como o mago fecha batalha — o portao da cena exige
> `enemy:isAlive()` pra chamar `enemyTurn()`. O inimigo ja esta morto,
> entao `enemyTurn` nunca roda, e quem devolvia a vez era justamente o
> beat final dele. `turn` ficava "enemy" pela recompensa, pelo descanso e
> pelo mapa inteiros; no andar seguinte o portao via inimigo VIVO + vez do
> inimigo e mandava o bicho novo golpear antes da primeira carta.
>
> Por isso era intermitente: so acontece quando a morte vem do fim do
> turno, nunca quando vem das cartas jogadas.

## L2065-2068 (em `self.discard`, junto a `function Game:syncArmorCap()`)

> Cap de Bloqueio POR ATO (auditoria Jul/2026): base 30 no A1, +10/ato
> (A2=40, A3+=50). A bateria de autoplay mostrou o cap fixo de 30 comendo
> 20-24 turnos de scaling defensivo no A3 (hits inimigos ja passavam de 30).
> Fonte unica: chamado em startGame e nextPhase (quando o ato pode virar).

## L2079-2086 (em `Game:syncArmorCap`, junto a `function Game:syncInterestCap()`)

> Espelha no EconomySystem o TETO DE JUROS comprado na loja (relíquia
> "Cofre"). A fonte da verdade é o ledger de serviços da run — que viaja no
> save —, e este é o mesmo padrão do syncArmorCap logo acima: a entidade
> guarda um número simples e o Game o reescreve nos chokepoints de batalha.
>
> Chamado junto de syncArmorCap (startGame + nextPhase) e logo após a compra.
> Os dois primeiros são a rede: mesmo que um caminho novo de compra esqueça
> de sincronizar, o desvio morre no andar seguinte em vez de durar a run.

## L2097-2101 (em `Game:nextPhase`, junto a `self._exhaustedThisBattle = {}`)

> Exaurir (balance v2): a carta some da BATALHA e volta na próxima
> (StS-style). A remoção permanente da run punia demais — potions e
> cartas de uso único viravam lixo de deck (auditoria v2 §3).
> O objetivo anti-stall (não reciclar cura no reshuffle) continua
> atendido: exauridas não voltam pro discard DENTRO da batalha.

## L2107-2111 (em `self._exhaustedThisBattle`, junto a `self.turn = "player"`)

> Batalha nova SEMPRE começa no turno do jogador. Se o golpe final veio
> do pulso de orbe do fim de turno (ou de um "Encerrar turno" enfileirado
> durante a jogada que matou), `turn` ficava "enemy" — e só startGame o
> zerava. Resultado: a PRÓXIMA batalha abria com o inimigo agindo
> primeiro (revisão de lançamento, Out/2026; trava em test_lifecycle).

## L2117-2118 (em `self._exhaustedThisBattle`, junto a `self.scoreSystem:startBattle()`)

> F3: score antigo (BASE_SCORE_PER_PHASE) morreu — a batalha já foi
> pontuada em _onEnemyDeath via ScoreSystem (TINTA×SELO).

## L2120-2122 (em `self._exhaustedThisBattle`)

> (A passiva de classe roda DEPOIS do resetHandAndDeck, mais abaixo:
> aqui ela era apagada pelo resetTransientStats — o mago ganhava o toast
> do Conduíte e abria sem orbe nem Foco em toda luta depois da 1ª.)

## L2124-2128 (em `self._exhaustedThisBattle`)

> F2 gameplay-overhaul: FOLHA ÚNICA de pagamento. O RoundEvalScreen
> (cash-out Balatro: vitória + bônus HP + juros) é O pagamento da
> batalha. O earnBattleGold daqui era um SEGUNDO salário (~50/batalha
> na fase 5, com "streak" falso via currentPhase) que deixava o jogador
> rico demais pra loja significar escolha.

## L2130-2134 (em `self._exhaustedThisBattle`, junto a `if self.isRunMode and self.runManager:hasActiveRun() then`)

> RNG do INÍCIO da batalha (Out/2026): o Continuar no meio de uma luta
> refaz a luta do começo — e tem que ser a MESMA luta (mesma mão, mesmo
> primeiro golpe do inimigo). O save deste andar sai no FIM do nextPhase,
> com o embaralho e o sorteio do inimigo já consumidos; sem este retrato,
> sair e voltar re-embaralhava a mão inicial (save-scum da abertura).

## L2142-2143 (em `self._exhaustedThisBattle`, junto a `self.player:restoreMana()`)

> Mana CHEIA ao entrar na batalha (autoplay A3: quem gastava tudo no
> último turno começava a próxima batalha com 0 de mana).

## L2150-2152 (em `self._exhaustedThisBattle`, junto a `if self.isRunMode and self.runManager:hasActiveRun() then`)

> Stats do inimigo baseadas no ato + node atual (Fase 5 via ActSystem).
> Em run mode: usa runManager.currentRun (actNumber, floorInAct, currentNode).
> Em classic mode (sem run): fallback para curva linear antiga.

## L2161-2163 (em `self._exhaustedThisBattle`, junto a `local EnemyRoster = require("src.systems.EnemyRoster")`)

> QUEM luta (Out/2026): o inimigo foi sorteado quando o nó nasceu
> (EnemyRoster, stream "enemy") e mora em currentNode.enemyId — o
> kit dele (src/data/enemies.lua) traz golpes, vida e dano próprios.

## L2166-2171 (em `self._exhaustedThisBattle`, junto a `run.battleEnemyRng = require("src.systems.Rng").get():getStreamState("enemy")`)

> Stream "enemy" no instante do spawn (que rola o 1º golpe). O
> battleRng não basta: entre ele e o spawn o caminho do Continuar
> consome o stream de outro jeito (o inimigo provisório do startGame
> rola intent; aqui o resolveNode pode sortear) — e a luta retomada
> abria com outro golpe conforme o que rodou antes (test_resume_state
> falhava só dentro da suíte).

## L2176-2179 (em `self._exhaustedThisBattle`, junto a `self.battleTurn = 0`)

> (P0.0 Jul/2026: scoreSystem:startBattle + applyClassBattleStartPassive
> DUPLICADOS aqui foram removidos — a passiva rodava 2x por batalha em
> run mode: mago abria com 2 orbes + o dobro de Foco. A aplicacao
> canonica e a incondicional no topo do nextPhase.)

## L2181 (em `self._exhaustedThisBattle`, junto a `self.enemy.isBoss = (nodeType == "boss" or nodeType == "mini_boss")`)

> isBoss nunca era setado (só lido) — bosses agora rendem maiores

## L2190-2191 (em `self._exhaustedThisBattle`, junto a `if self.isRunMode and self.runManager:hasActiveRun() then`)

> Cura intra-ato (modo classic) OU cura inter-ato (run mode, quando floorInAct=1
> e actNumber > 1: significa que acabou de cruzar pro novo ato).

## L2195-2196 (em `self._exhaustedThisBattle`, junto a `local pct = run.endlessMode and (Config.Endless.healPercent or 0)`)

> Endless: a cura do CICLO é a do Config.Endless (antes caía na
> do ato 6 e curava 40% a cada 8 andares). Selo/maldição reduzem.

## L2218-2221 (em `self._exhaustedThisBattle`, junto a `if self.isRunMode and self.runManager:hasActiveRun() then`)

> CHECKPOINT (F1 do UI Overhaul): persiste a run a cada andar novo —
> fecha o gap "save/load existe mas sem botão Continuar".
> Estágio "battle": este save (vida do INÍCIO da luta) é o ponto de
> retomada; "Salvar e sair" no meio da luta não o sobrescreve (main.lua).

## L2229-2231 (em `self._exhaustedThisBattle`, junto a `function Game:syncRunPlayerState()`)

> ============================================================================
> Continuar (F1 do UI Overhaul): save em checkpoint + resume da run salva
> ============================================================================

## L2233 (em `self._exhaustedThisBattle`, junto a `function Game:syncRunPlayerState()`)

> Sincroniza HP/ouro do jogador pra dentro da run (antes de persistir).

## L2241-2244 (em `Game:syncRunPlayerState`, junto a `run.playerState.baseMaxMana = self.player.baseMaxMana`)

> Mana máxima PERMANENTE da run (eventos dão +1 em baseMaxMana).
> Sem persistir, sair/entrar resetava o ganho (bug do dono,
> Set/2026). O bônus de BATALHA (Cristal de Mana) fica de fora
> por design — só o base viaja.

## L2247-2248 (em `Game:syncRunPlayerState`, junto a `if self.scoreSystem then`)

> Pontuação da run (mesma classe de bug: acumulava e ZERAVA no
> Continuar — o recorde do perfil sobrevivia, a run não).

## L2251-2252 (em `Game:syncRunPlayerState`, junto a `run.playerState.scoreRecordBroken = self.scoreSystem.recordBroken or nil`)

> "RECORDE!" dourado pelo resto da run e o recibo da última batalha
> (o cash out retomado mostrava a pontuação vazia).

## L2267-2269 (em `Game:checkpointRun`, junto a `if (self.player and not self.player:isAlive())`)

> Run que ACABOU não se salva. Morto (ou já vencido) e "Salvar e sair"
> gravava currentHealth 0 por cima do save que a morte tinha apagado — e o
> resumeRun, com math.max(1, ...), RESSUSCITAVA o jogador com 1 de vida.

## L2276-2277 (em `Game:checkpointRun`, junto a `require("engine.ProfileStats").flush()`)

> Contadores do perfil (cartas jogadas, vistas/descobertas) só iam pro
> disco no fim de batalha/conquista: "Salvar e sair" os perdia.

## L2281-2282 (em `Game:checkpointRun`, junto a `function Game:resumeRun()`)

> Retoma uma run carregada (chamar DEPOIS de runManager:loadRun()):
> remonta o jogo no andar salvo com deck/jokers/HP/ouro/inimigo corretos.

## L2289-2293 (em `Game:resumeRun`, junto a `local Rng = require("src.systems.Rng")`)

> RNG: o setup abaixo (embaralho do startGame, sorteio do primeiro golpe
> do inimigo) CONSOME os streams misc/enemy. Retomando DENTRO da luta, o
> RNG volta ao início dela (battleRng, gravado no nextPhase) e a luta sai
> idêntica. Em qualquer outro estágio o inimigo é descartado e o RNG volta
> ao estado salvo — sair e voltar na loja não pode mudar a próxima luta.

## L2304-2305 (em `Game:resumeRun`, junto a `self:startGame()`)

> startGame monta o deck da run (initializeDeck usa run.currentDeck) e
> os jokers (_syncJokersFromRun) — mas reseta player/economia/inimigo.

## L2318-2320 (em `Game:resumeRun`, junto a `if ps and ps.baseMaxMana then`)

> Mana máxima PERMANENTE (eventos +1): sem restaurar, o Continuar
> voltava pro base da classe (bug do dono, Set/2026). Saves antigos
> sem o campo caem no default do Player (compat).

## L2326-2327 (em `Game:resumeRun`, junto a `if ps and ps.runScore and self.scoreSystem then`)

> Pontuação da run continua de onde parou (startGame zera o
> ScoreSystem — restaurar por cima).

## L2331-2334 (em `Game:resumeRun`, junto a `self.score = (self.scoreSystem and self.scoreSystem.runScore) or 0`)

> BUG do dono (Out/2026, "voltei e meus PONTOS zeraram"): a TopBar, a
> tela final e o recorde do perfil leem `game.score`, que o startGame
> zera e só o fim da PRÓXIMA batalha reescrevia. Morrer antes disso
> gravava 0 como pontuação da run.

## L2351-2352 (em `Game:resumeRun`, junto a `local EnemyRoster = require("src.systems.EnemyRoster")`)

> O MESMO inimigo do nó salvo (currentNode.enemyId) — o Continuar não
> re-sorteia (EnemyRoster).

## L2362-2364 (em `Game:resumeRun`, junto a `self.enemy.isBoss = (nodeType == "boss" or nodeType == "mini_boss")`)

> (startBattle + passiva de classe já rodaram no startGame, com a classe
> e o ato da run carregada. Rodar de novo aqui dava ao mago DOIS orbes e
> Foco em dobro em toda luta retomada.)

## L2369-2370 (em `Game:resumeRun`, junto a `if run.currentNode then run.currentNode.enemyId = nodeEnemyId end`)

> O inimigo provisório não pode deixar rastro no nó (resolveNode
> carimbava um enemyId numa LOJA/descanso retomados).

## L2394-2397 (em `Game:checkGameOver`, junto a `self:_recordEndlessEnd()`)

> Morte no ENDLESS: a vitória já foi contada ao matar o
> chefe final. Aqui só entra o XP dos andares extras e o
> recorde — contar uma derrota faria a mesma run valer
> vitória E derrota no perfil (runs = wins + losses).

## L2411-2414 (em `Game:checkGameOver`, junto a `function Game:abandonRun()`)

> Abandono confirmado no pause: conta como fim de run (StS: abandonar = morrer).
> Rende o XP de maestria do que a run andou e registra a derrota no perfil —
> sem isso, abandonar uma run longa jogava fora todo o progresso de classe.
> Mesmo guard do checkGameOver: nunca registra duas vezes.

## L2434-2437 (em `Game:abandonRun`, junto a `function Game:_recordEndlessEnd()`)

> Fim de uma run que JÁ VENCEU a campanha e seguiu no endless (morte ou
> abandono). A vitória foi registrada uma vez em checkVictory; aqui só o XP
> dos andares extras (computeRunXP: endless sem vitória = só o excedente) e
> o recorde de pontuação.

## L2444-2449 (em `Game:_recordEndlessEnd`, junto a `function Game:enterEndless()`)

> "Continuar no Endless" da tela de vitória (StS/Balatro): a run segue viva
> depois do chefe final. SÓ vale depois de a vitória estar registrada
> (defect_doctrine 14: endlessMode desliga checkVictory — ligá-lo antes da
> vitória contar deixaria o jogo invencível). Não avança andar nem abre mapa:
> quem chama (main.lua) segue pro cash out → recompensa → encruzilhada, e é o
> advanceFloorInAct que leva a run pro primeiro andar do endless.

## L2465-2466 (em `Game:enterEndless`, junto a `local CLOCK_IDLE = { menu = true, classSelection = true, gameOver = true,`)

> Relógio da run (resumo da tela final). Só conta com a run em jogo: menu,
> seleção de classe e as telas finais não são tempo de jogo.

## L2492-2495 (em `Game:checkVictory`, junto a `if self.isRunMode and self.runManager:hasActiveRun() then`)

> Em run mode: vitoria so acontece ao matar boss do ato final (nao endless).
> O endless so liga DEPOIS daqui, pela escolha do jogador na tela de
> vitoria (Game:enterEndless); checkVictory so retorna true na primeira
> vez que o player bate o boss do ultimo ato.

## L2509-2510 (em `Game:checkVictory`, junto a `run.campaignWon = true`)

> Marca NA RUN (viaja no save): se ela seguir pro endless,
> morte/abandono lá não contam outra vitória nem uma derrota.

## L2517-2521 (em `Game:checkVictory`, junto a `if self.runManager.deleteSave then self.runManager:deleteSave() end`)

> Vitória ENCERRA a run em disco (a derrota já fazia isso no
> checkGameOver). Sem isto o menu seguia oferecendo
> "Continuar" e devolvia o jogador ao chefe final — e cada
> replay contava outra vitória no perfil. "Continuar no
> Endless" volta a salvar (Game:enterEndless + encruzilhada).

## L2538-2539 (em `Game:checkVictory`, junto a `function Game:playCardSelectSound()`)

> Toca som de seleção de carta. Wrapper thin via Sfx.play (AudioSystem é no-op
> se áudio não disponível).

## L2541-2542 (em `Game:playCardSelectSound`, junto a `Sfx.playWithVariation("cardSelect", 1.0, 0.12)`)

> Pitch random: usuário clica em várias cartas em sequência ao montar play,
> sem variação soa staccato robótico.

