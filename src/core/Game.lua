local Player = require("src.entities.Player")
local Enemy = require("src.entities.Enemy")
local MessageSystem = require("src.systems.MessageSystem")
local DeckManager = require("src.systems.DeckManager")
local EffectSystem = require("src.systems.EffectSystem")
local RunManager = require("src.systems.RunManager")
local CombatSequence = require("src.systems.CombatSequence")
local CombatBeats = require("src.systems.CombatBeats")
local EconomySystem = require("src.systems.EconomySystem")
local ShopSystem = require("src.systems.ShopSystem")
local TagSystem = require("src.systems.TagSystem")
local ComboSystem = require("src.systems.ComboSystem")
local DamagePreview = require("src.systems.DamagePreview")
local ScoreSystem = require("src.systems.ScoreSystem")
local AchievementSystem = require("src.systems.AchievementSystem")
local UnlockSystem = require("src.systems.UnlockSystem")
local ActSystem = require("src.systems.ActSystem")
local Config = require("src.core.Config")
local Sfx = require("src.systems.Sfx")
local Debug = require("src.core.Debug")

-- Helper de mensagem traduzida (mesmo contrato do msg() do EffectSystem):
-- os toasts do feed sao TEXTO DE JOGADOR e precisam sair no idioma da sessao.
-- Antes eram literais PT no meio de um HUD traduzido.
local I18nMod = require("src.i18n.I18n")
local function msg(key, vars, fallback)
    return I18nMod.t("messages." .. key, vars, fallback)
end

local Game = {}
Game.__index = Game

-- Quanto tempo a MORTE do inimigo segura o combate: o clipe de death rodando
-- (DEATH_FPS x ~7 frames ~= 0.7s) mais o respiro que separa "ele morreu" de
-- "acabou". Serve ao beat da morte E ao relogio da cena — uma duracao so.
-- PENDENCIA ASSUMIDA: valor de ritmo deveria morar em `CombatBeats.HOLD`
-- (tabela de tempos UNICA do combate) como `DEATH`. Vai como numero cru
-- enquanto nao entra la; `CombatBeats.hold` aceita numero e aplica
-- `CombatBeats.speed` igual, entao o knob global continua valendo.
Game.DEATH_HOLD = 1.1

function Game:new()
    local instance = setmetatable({}, Game)
    instance.deck = {} -- Todas as cartas disponíveis no jogo
    instance.hand = {} -- Cartas na mão
    instance.selectedCards = {} -- Cartas selecionadas
    instance.player = Player:new() -- Jogador
    instance.enemy = Enemy:new(Config.Game.ENEMY_BASE_HEALTH, Config.Game.ENEMY_BASE_DAMAGE) -- Inimigo
    instance.turn = "player"
    instance.gameState = "menu" -- menu, playing, gameOver, victory
    instance.currentPhase = 1
    instance.jokerSlots = {} -- Slots para jokers passivos
    instance.maxJokerSlots = Config.Game.MAX_JOKER_SLOTS -- Máximo de slots de joker
    instance.score = 0
    instance.messageSystem = MessageSystem:new()
    -- IDs de cartas com `exhaust=true` jogadas nesta batalha. Removidas do
    -- deck da run quando a batalha termina (nextPhase).
    instance._exhaustedThisBattle = {}
    -- Pilha de descarte. Cartas jogadas (exceto joker/exhaust) entram aqui
    -- e sao reembaralhadas no deck quando drawCard encontra deck vazio.
    instance.discard = {}
    -- Atraso após morte do inimigo até abrir cardReward. Dá tempo da death
    -- anim (~0.7s) tocar visivelmente. Setado em processCardInCombat quando
    -- enemy.health <= 0; main.lua updateGame só chama showCardRewards quando
    -- esse timer expira.
    instance._deathPauseTimer = 0
    -- Flag idempotencia pra _onEnemyDeath: evita disparar anim/sfx duplicado
    -- se tanto processCardInCombat quanto enemyTurn detectam morte no mesmo tick.
    -- Resetado em startGame/nextPhase pra proxima batalha disparar normalmente.
    instance._deathHandled = false
    -- Par do anterior: AGENDADA (existe beat) x ACONTECEU (o beat rodou).
    -- Ver Game:announceDeathIfPending — confundir os dois travou o jogo.
    instance._deathStaged = false

    -- Novos sistemas
    instance.deckManager = DeckManager:new()
    instance.effectSystem = EffectSystem:new()
    instance.runManager = RunManager:new()
    -- Nome do campo mantido pra compat com main.lua/GameUI. A classe é nova
    -- (CombatSequence via EventManager; antiga CombatAnimationSystem deletada).
    instance.combatAnimationSystem = CombatSequence:new()
    
    -- Sistema de economia e loja. ShopSystem é singleton-na-run: criado uma
    -- vez aqui e injetado em CardRewardScreen. Evita re-init de pools por
    -- raridade a cada open/refresh.
    instance.economySystem = EconomySystem:new()
    instance.shopSystem = ShopSystem:new()

    -- Pontuação TINTA×SELO (F3 gameplay-overhaul). game.score espelha
    -- scoreSystem.runScore pra compat com EndScreens/telas antigas.
    instance.scoreSystem = ScoreSystem:new()

    -- Sistema de classes (Slay the Spire style)
    instance.selectedClass = nil
    instance.isRunMode = false

    return instance
end

function Game:initializeDeck()
    Sfx.play("deckStart")
    
    if self.isRunMode and self.runManager:hasActiveRun() then
        -- Modo Slay the Spire: usa deck dinâmico da corrida
        self.deck = self.runManager:buildPlayableDeck()
    else
        -- Modo clássico: usa deck estático
        self.deckManager:setCurrentDeck("starter")
        self.deck = self.deckManager:buildCurrentDeckCards()
    end
    
    -- Embaralha o deck
    self:shuffleDeck()
end

function Game:shuffleDeck()
    -- Stream "misc" do Rng da run (Out/2026): com love.math.random a mesma
    -- seed não reproduzia o combate — a mão de cada turno saía diferente.
    local rng = require("src.systems.Rng").get()
    for i = #self.deck, 2, -1 do
        local j = rng:random("misc", i)
        self.deck[i], self.deck[j] = self.deck[j], self.deck[i]
    end
end

function Game:startGame()
    -- Batalha nova: nenhum acontecimento da anterior pode vazar pra ca
    -- (beats da morte, veneno, upkeep). A fila de beats e a espinha do
    -- combate — limpa-la e parte de zerar o combate.
    CombatBeats.clear()
    self._enemyActing = false
    self.gameState = "playing"
    self.currentPhase = 1
    self.score = 0
    self.player = Player:new()
    self.enemy = Enemy:new(Config.Game.ENEMY_BASE_HEALTH, Config.Game.ENEMY_BASE_DAMAGE)
    -- Sprite do inimigo inicial (ato 1, floor 1, battle comum).
    local EnemyRendererModule = require("src.ui.EnemyRenderer")
    self.enemy.spriteId = EnemyRendererModule.resolveSpriteId(1, "battle")
    self.turn = "player"
    self.hand = {}
    self.selectedCards = {}
    self.jokerSlots = {}
    self.discard = {}
    self._exhaustedThisBattle = {}
    self._deathHandled = false
    self._deathStaged = false
    self._deathPauseTimer = 0
    self._saveDeleted = false
    self._victoryRecorded = false
    self.battleTurn = 0
    self.scoreSystem:reset()
    self.scoreSystem:startBattle()
    self:applyClassBattleStartPassive()

    self.economySystem:resetForNewRun()
    -- Selo "Bolsa Leve" começa sem ouro (RunModifiers.startingGold).
    self.economySystem.currentGold = require("src.systems.RunModifiers").startingGold(
        self.isRunMode and self.runManager and self.runManager.currentRun, 10)

    self:syncArmorCap()
    self:syncInterestCap()
    self:initializeDeck()
    -- Cartas com edition "negative" no deck adicionam slots de joker (Fase 3.2).
    self:recomputeMaxJokerSlots()

    -- Restaura jokers da run (em saves antigos vinham de currentDeck → migrados
    -- pelo RunManager:_migrateJokersFromDeck). Em runs novas, jokers={} vazio.
    self:_syncJokersFromRun()
    self:syncJokerFlags()

    -- Reordena o deck para que cartas com flag `innate` fiquem no topo e sejam
    -- compradas primeiro na mao inicial. Em Slay, innate = sempre comeca na mao.
    self:promoteInnateCardsToTop()

    -- Stagger no draw inicial pra entrada ficar elegante em vez de pop-in.
    -- A mão inicial acompanha o grimório de compra extra (serviço da loja):
    -- INITIAL_HAND_SIZE e CARDS_PER_TURN são o mesmo número por design
    -- (F1: "mão inicial = draw por turno"), e separá-los faria do primeiro
    -- turno o único turno sem o benefício comprado.
    for i = 1, Config.Game.INITIAL_HAND_SIZE + self:getShopServiceCount("card_draw_upgrade") do
        self:drawCard((i - 1) * 0.08)
    end
end

-- Move cartas com `innate=true` para o topo do deck (ordem preservada entre elas).
-- Chamado apos shuffleDeck para garantir que innate sejam as primeiras compradas.
function Game:promoteInnateCardsToTop()
    local innates = {}
    local rest = {}
    for _, c in ipairs(self.deck) do
        if c.innate then
            table.insert(innates, c)
        else
            table.insert(rest, c)
        end
    end
    self.deck = {}
    for _, c in ipairs(innates) do table.insert(self.deck, c) end
    for _, c in ipairs(rest) do table.insert(self.deck, c) end
end

-- Coordenadas visuais da pilha de deck (canto inferior direito).
-- Cartas novas começam aqui visualmente antes de voar pro slot na mão.
function Game:getDeckOrigin()
    if not love.graphics then return 0, 0 end  -- guard pra testes sem love
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    return w * 0.92, h * 0.82
end

-- staggerDelay: segundos antes de iniciar a materialização visual. Usado por
-- callers que sacam múltiplas cartas pra criar cascata (Balatro-style).
-- nil ou 0 = materializa imediato.
function Game:drawCard(staggerDelay)
    -- Se o deck esvaziou mas ha discard, reembaralha (Slay-style). Sem isso,
    -- starter de 2 cartas trava o jogador no turno 2.
    if #self.deck == 0 and #self.discard > 0 then
        for _, c in ipairs(self.discard) do
            table.insert(self.deck, c)
        end
        self.discard = {}
        self:shuffleDeck()
        -- Innate sempre fica no topo: shuffleDeck embaralhou junto, então re-promover.
        self:promoteInnateCardsToTop()
        Sfx.play("deckStart") -- reusa SFX de embaralhamento inicial
    end
    if #self.deck > 0 then
        local card = table.remove(self.deck, 1)
        -- Reset estado visual residual. cancelDissolveAnim zera dissolve E mata
        -- os eventos pendentes (ease de 0→1) — sem isso, a carta recém-sacada
        -- vê o ease continuar e some visualmente. Ver Card:cancelDissolveAnim.
        if card.cancelDissolveAnim then
            card:cancelDissolveAnim()
        else
            card.dissolve = 0
            card._removed = false
        end
        card._flip = 0
        card.isHovered = false

        -- ===== Animação de draw (Balatro-style) =====
        -- Carta começa invisível na posição do deck (canto inf. direito),
        -- depois materializa com partículas e voa pro slot. setTargetPos do
        -- GameplayScene (chamado todo frame) ease renderX→slot.
        local EM = _G.EventManager
        if EM and card.setRenderPos then
            local dx, dy = self:getDeckOrigin()
            card:setRenderPos(dx, dy)  -- snap visual + target no deck
            card.dissolve = 1            -- invisível
            local delay = staggerDelay or 0
            EM.after(delay, function()
                if card.start_materialize then
                    card:start_materialize(nil, true, 0.35)
                else
                    card.dissolve = 0
                end
                local Sfx = require("src.systems.Sfx")
                -- Pitch variado por carta drawn pra evitar fadiga (sequência de
                -- 4-5 draws no início de cada turno seria muito repetitiva).
                pcall(Sfx.playWithVariation, "cardDraw", 1.0, 0.15)
            end)
        end

        table.insert(self.hand, card)
    end
end

-- Draw de inicio de turno (F1 gameplay-overhaul):
--   - Fixo: compra CARDS_PER_TURN (5, StS-style) — a mão foi descartada no
--     fim do turno anterior, então todo turno recomeça com mão fresca
--     (+ cartas retain que sobreviveram).
--   - O antigo "draw de emergência +3 com mão vazia" morreu: ele PREMIAVA
--     esvaziar a mão, o oposto do que o jogo precisa.
function Game:drawForTurn()
    -- Passiva rogue: nova janela de Toxinas a cada turno.
    self._toxinAppliedThisTurn = false
    -- multi-jogada: contadores por turno zerados
    self._attacksThisTurn = 0
    self._impetusFiredThisTurn = false
    self._toxinGrowFiredThisTurn = false
    -- P2.3 (Jul/2026, rebalance v2): thorn de JOKER dispara 1x/turno por
    -- joker — nova janela a cada turno do jogador (ver EffectSystem
    -- processTriggerEffect on_defend_damage).
    self._jokerThornFiredThisTurn = {}
    -- Eco (Forma de Eco): uma carta de ataque dobrada por turno.
    self._echoFiredThisTurn = false
    -- + grimório de compra extra comprado na loja (serviço `card_draw_upgrade`):
    -- permanente pelo resto da run, e por isso soma na BASE, não no bônus de
    -- seal (que é consumido a cada turno).
    local baseDraw = (Config.Game.CARDS_PER_TURN or 5)
        + self:getShopServiceCount("card_draw_upgrade")
    -- Blue Seal acumula compras extras quando cartas com seal são jogadas.
    -- Consumido aqui (uma vez por turno) e zerado.
    local sealBonus = self._sealDrawBonus or 0
    self._sealDrawBonus = 0
    local total = baseDraw + sealBonus

    if sealBonus > 0 then
        self:addMessage(msg("blue_seal", { value = sealBonus }), "info")
    end

    -- Stagger entre cartas pra criar cascata Balatro-style (~80ms entre cada).
    -- drawCard agenda o materialize via EventManager.after com esse delay.
    for i = 1, total do
        self:drawCard((i - 1) * 0.08)
    end
end

-- Aplica efeitos dos jokers ativos a uma carta.
-- turnContext (opcional) carrega info agregada do turno (tagCounts, activeCombos,
-- allSelectedCards). ComboSystem (Fase 3) usa isso para amplificar antes dos jokers.
function Game:applyJokerEffects(card, baseValue, turnContext)
    return self.effectSystem:applyJokerEffects(self, card, baseValue, turnContext)
end

-- Novos métodos para gerenciamento de decks
function Game:setDeck(deckId)
    self.currentDeckId = deckId
end

function Game:getCurrentDeckInfo()
    return self.deckManager:getDeckInfo(self.currentDeckId)
end

function Game:getAvailableDecks()
    return self.deckManager:getAvailableDecks()
end

function Game:getDeckStats()
    return self.deckManager:getDeckStats(self.currentDeckId)
end

-- Verifica se uma carta específica está no deck (útil para debug)
function Game:hasCardInDeck(cardId)
    if self.isRunMode and self.runManager:hasActiveRun() then
        local runDeck = self.runManager:getCurrentDeck()
        for _, id in ipairs(runDeck) do
            if id == cardId then return true end
        end
        return false
    else
        for _, card in ipairs(self.deck) do
            if card.id == cardId then return true end
        end
        return false
    end
end

-- ===== SISTEMA SLAY THE SPIRE =====

-- Inicia uma nova corrida com uma classe
-- opts.seal = Selo do Grimório escolhido na seleção de classe (0..10).
function Game:startNewRun(classId, opts)
    self.isRunMode = true
    self.selectedClass = classId
    
    -- Meta-progressão: migra perfil antigo ANTES de qualquer contador mudar.
    UnlockSystem.ensure()
    self.unlockResult = nil

    local runData = self.runManager:startNewRun(classId, opts)
    -- nome da classe no idioma atual (runData.className é o literal do dado)

    -- Perfil persistente (menu mostra vitórias/melhor progresso).
    require("engine.ProfileStats").recordRunStart(classId)
    -- Deck inicial conta como "visto" (Coleção) + zera pendentes da run.
    UnlockSystem.onRunStarted(classId, runData.currentDeck)
    -- Conquistas: deck inicial conta como "descoberto" (Bibliotecario).
    AchievementSystem.onRunStarted(self, classId)

    return runData
end

-- (Game:completeBattle removido no rebalance v2 — chamava
-- RunManager:completeBattle, caminho morto extinto no P3.1; zero callers.)

-- Adiciona uma carta ao deck da corrida
-- meta opcional: { edition, seal } pra cartas que vêm de packs com modifiers.
function Game:addCardToRun(cardId, meta)
    if not self.isRunMode then
        self:addMessage(msg("not_in_run"), "error")
        return false
    end

    -- Inédita AQUI = chegou sem passar por vitrine (evento, transformação):
    -- ninguém mostrou o selo "NOVA", então o anúncio vira o toast + chime.
    -- Oferta de recompensa/loja/pacote já descobriu antes e devolve false.
    -- ANTES do onCardSeen: ele grava cardsSeen, que também conta como vista.
    local discovered = UnlockSystem.markDiscovered(cardId)
    if discovered then require("src.ui.DiscoveryMark").chime() end
    -- F4: registro de descoberta (Bibliotecário).
    AchievementSystem.onCardSeen(self, cardId)

    -- Bifurca jokers: nunca entram no deck. Vão direto para jokerSlots
    -- + currentRun.jokers (padrão Balatro G.jokers).
    local cardData = self.deckManager.cardDatabase:getCard(cardId)
    if cardData and cardData.type == "joker" then
        if discovered then
            self:addMessage(msg("card_discovered", { name = I18nMod.cardName(cardData or cardId) }), "success")
        end
        return self:addJokerToRun(cardId, meta)
    end

    local success = self.runManager:addCardToDeck(cardId, meta)
    
    if success then
        -- Carta comum que entrou no deck não vira aviso (o jogador acabou de
        -- escolhê-la); só a INÉDITA anuncia.
        if discovered then
            self:addMessage(msg("card_discovered", { name = I18nMod.cardName(cardData or cardId) }), "success")
        end
        
        -- CRÍTICO: Reconstrói completamente o deck jogável
        self:synchronizeRunDeck()
        
        -- Embaralha para distribuir a nova carta
        self:shuffleDeck()
        
        return true
    else
        self:addMessage(msg("card_add_failed"), "error")
        return false
    end
end

-- True se o jogo aceita um joker novo agora. Pós-modelo coleção+bancada
-- (Jul/2026) a coleção é ILIMITADA — excedentes entram na bancada em vez de
-- sumir. Só exige estar em run. Mantido por compat (CardRewardScreen/autoplay).
function Game:canAcceptJoker()
    return self.isRunMode == true
end

-- Adiciona um joker direto aos slots passivos (sem passar pelo deck/hand).
-- Cumpre o invariante "joker é jogado uma vez e fica no slot pelo resto da run".
-- meta opcional: { edition, seal } vinda de Buffoon packs.
-- Sincroniza flags de jokers CONTÍNUOS que vivem no Player (ex: Bastião
-- retain_armor — Player:onTurnStart não enxerga jokerSlots).
function Game:syncJokerFlags()
    local retain = false
    for _, j in ipairs(self.jokerSlots or {}) do
        for _, e in ipairs(j.effects or {}) do
            if e.type == "retain_armor" then retain = true end
        end
    end
    self.player.retainArmor = retain
end

function Game:addJokerToRun(cardId, meta)
    if not self.isRunMode then
        self:addMessage(msg("not_in_run"), "error")
        return false
    end

    local cardData = self.deckManager.cardDatabase:getCard(cardId)
    if not cardData or cardData.type ~= "joker" then
        Debug.warn("[Game:addJokerToRun] cardId não é joker: " .. tostring(cardId))
        return false
    end

    -- COLEÇÃO + BANCADA: o joker SEMPRE entra na coleção da run. Ativa se houver
    -- slot livre (até maxJokerSlots); senão fica na bancada — NUNCA se perde.
    -- (Mata o bug histórico "comprei o 4º joker e ele sumiu".) A troca de
    -- ativos acontece no Gerenciador de Coringas.
    local _, activated = self.runManager:addJokerToRun(cardId, meta)
    self:rebuildJokerSlots()

    if activated then
        Sfx.play("jokerActivate")
    else
        self:addMessage(msg("joker_benched",
            { name = I18nMod.cardName(cardData) }), "info")
        Sfx.play("cardSelect")
    end
    return true
end

-- Reconstrói jokerSlots a partir dos jokers ATIVOS da run. Fonte única —
-- usado no load (startGame), ao adquirir e ao trocar ativos no gerenciador.
-- Efeitos contínuos/trigger são lidos ao vivo de jokerSlots, então trocar
-- ativos basta reconstruir + sincronizar flags contínuas (retain_armor etc.).
function Game:rebuildJokerSlots()
    self.jokerSlots = {}
    if self.isRunMode and self.runManager:hasActiveRun() then
        local instances = self.runManager:buildJokerInstances()
        for _, inst in ipairs(instances) do
            table.insert(self.jokerSlots, inst)
        end
    end
    self:syncJokerFlags()
end

-- Ativa/desativa um joker possuído (índice na coleção da run), respeitando o
-- teto de slots. Rebuilda os slots e persiste. Retorna (ok, motivo).
function Game:setJokerActive(ownedIndex, active)
    if not (self.isRunMode and self.runManager:hasActiveRun()) then
        return false, "no_run"
    end
    local ok, reason = self.runManager:setJokerActive(ownedIndex, active)
    if ok then
        self:rebuildJokerSlots()
        -- Fora da luta, checkpoint (sincroniza ouro/HP): o saveRun cru
        -- gravava o deck/vitrine ATUAIS com o ouro do checkpoint anterior —
        -- comprar na loja, trocar coringa e fechar a janela devolvia o ouro
        -- com a compra no bolso. Na luta segue cru: o save do INÍCIO dela
        -- (vida cheia do começo) é o que vale.
        local run = self.runManager.currentRun
        if run and run.stage ~= "battle" and self.checkpointRun then
            self:checkpointRun()
        elseif self.runManager.saveRun then
            self.runManager:saveRun()
        end
    end
    return ok, reason
end

-- Restaura jokerSlots a partir da run (load). Delega pro rebuild (fonte única).
function Game:_syncJokersFromRun()
    if not self.isRunMode or not self.runManager:hasActiveRun() then return end
    self:rebuildJokerSlots()
    Debug.log("[Game] jokerSlots restaurados da run: " .. #self.jokerSlots)
end

-- Sincroniza o deck jogável com o deck da corrida
function Game:synchronizeRunDeck()
    if self.isRunMode and self.runManager:hasActiveRun() then
        -- Reconstrói o deck jogável a partir do deck da corrida
        self.deck = self.runManager:buildPlayableDeck()

        -- Força a atualização do estado do jogo
        if self.gameState == "playing" then
            -- Se estamos jogando, mantém a mão atual mas adiciona as novas possibilidades
            -- As cartas novas aparecerão quando a mão for recarregada ou em próximos turnos
        end
    end
end

-- Remove uma carta do deck da corrida
function Game:removeCardFromRun(cardId)
    if not self.isRunMode then return false end
    
    return self.runManager:removeCardFromDeck(cardId)
end

-- Retorna estatísticas da corrida atual
function Game:getCurrentRunStats()
    return self.runManager:getCurrentRunStats()
end

-- Termina a corrida atual
function Game:endCurrentRun(victory)
    if not self.isRunMode then return nil end

    local finalStats = self.runManager:endRun(victory)
    self.isRunMode = false
    self.selectedClass = nil

    -- Limpa save em disco (run encerrada).
    if self.runManager.deleteSave then self.runManager:deleteSave() end

    return finalStats
end

-- Verifica se está em modo corrida
function Game:isInRunMode()
    return self.isRunMode and self.runManager:hasActiveRun()
end

-- Retorna informações da classe atual
function Game:getCurrentClassInfo()
    return self.runManager:getCurrentClassInfo()
end

-- Retorna todas as classes disponíveis
function Game:getAvailableClasses()
    return self.runManager.cardRegistry:getAllClasses()
end

function Game:isCardSelected(card)
    -- Verifica se a carta já está na lista de selecionadas
    for _, selected in ipairs(self.selectedCards) do
        if selected == card then
            return true
        end
    end
    return false
end

function Game:canPlayCard(card)
    -- Verifica se a carta pode ser jogada (tem mana suficiente)
    return self.player.mana >= card.cost
end

function Game:selectCard(card)
    -- MÃO TRAVADA ENQUANTO AS CARTAS RESOLVEM. Com o ritmo por beats a
    -- resolução dura segundos, e nessa janela dava pra mexer na seleção: a
    -- `selectedCards` é a MESMA tabela que o CombatSequence percorre.
    -- Selecionar derrubava o jogo ("attempt to index local 'g'" — carta sem
    -- geometria); desselecionar era pior porque não quebrava nada: devolvia a
    -- mana de uma carta que já estava sendo jogada.
    local seq = self.combatAnimationSystem
    if seq and (seq.active or (seq.isBlocking and seq:isBlocking())) then
        return false
    end

    -- Seleciona ou desseleciona a carta
    if self:isCardSelected(card) then
        -- Desseleciona a carta
        for i, selected in ipairs(self.selectedCards) do
            if selected == card then
                table.remove(self.selectedCards, i)
                self.player.mana = self.player.mana + card.cost -- Devolve mana
                -- F12.3: faltava som no deselect. Pitch baixo pra diferenciar de select.
                Sfx.playWithVariation("cardSelect", 0.85, 0.10)
                break
            end
        end
    else
        -- Seleciona a carta se tiver mana suficiente
        if self.player:spendMana(card.cost) then
            table.insert(self.selectedCards, card)

            -- Toca som de seleção
            self:playCardSelectSound()

            -- Juice kick: feedback instantâneo de clique.
            if card.juice_up then card:juice_up(0.15, 0.05) end
            -- Jiggle micro Balatro-style (engine/ui.lua:990): cada seleção
            -- empurra leve energia no acumulador, dando sensação de peso à ação.
            if _G.jiggleScreen then _G.jiggleScreen(0.25) end
        else
            self:addMessage(msg("no_mana"), "error")
        end
    end
end

-- ===== PASSIVAS DE CLASSE (identidade de gameplay — Jul/2026) =====
-- Warrior "Ímpeto":  3+ ataques no mesmo turno → +1 Força (na batalha) (era 2+ até Out/2026).
-- Mage "Conduíte":   começa toda batalha com orbe de Raio (4) e Foco 0/1/2 (cresce a cada 2 atos).
-- Rogue "Toxinas":   o 1º ataque de cada turno aplica 1/2/3 de Veneno (2t, cresce a cada 2 atos);
--                    2+ ataques no mesmo turno → +2 nesse Veneno (na batalha).
-- CRESCER NA LUTA (Out/2026, balanceamento de classe): so o Impeto crescia
-- DENTRO da batalha, e a bateria mostrou o resultado — guerreiro 43%, mago
-- 13% (lutas de 12-18 turnos no A5-A6), ladino 17% (morre no chefe do A5).
-- Impeto e Toxinas tem a mesma forma (regra de turno que soma na batalha).
-- O Conduite TAMBEM crescia (+1 Foco por turno com 2+ cartas de orbe) ate os
-- combos simples + ENEMY_POWER: com o inimigo mais fraco o mago foi a 73-90%
-- e o crescimento saiu (mago 47%, bateria 30 runs).
-- Toda ativação gera toast — nada acontece invisível (lei do projeto).

-- Degrau das passivas que CRESCEM com a run (Out/2026): 1 nos atos 1-2,
-- 2 nos atos 3-4, 3 nos atos 5-6 (endless fica no ultimo degrau+1).
-- Bateria do piloto v6: guerreiro 47% (Impeto rende Forca a cada batalha),
-- ladino 23-27% e mago 6-13% — Conduite e Toxinas eram FIXAS a run inteira
-- e as duas classes quebravam nos atos 4-6, quando o inimigo ja escalou.
function Game:classPassiveTier()
    local run = self.runManager and self.runManager.currentRun
    local act = (run and run.actNumber) or 1
    return 1 + math.floor((math.max(1, act) - 1) / 2)
end

function Game:applyClassBattleStartPassive()
    self._toxinAppliedThisTurn = false
    self._toxinBonus = 0   -- Toxinas que cresceu nesta batalha
    -- P2.3: janela nova de thorn-de-joker no comeco de cada batalha.
    self._jokerThornFiredThisTurn = {}
    self._echoFiredThisTurn = false
    if self.selectedClass == "mage" and self.player and self.player.addOrb then
        self.player:addOrb({ type = "lightning", value = 4 })
        -- Auditoria Jul/2026 (bateria 2 do autoplay): mago morria no boss do
        -- A1 — orbe de potencia FIXA nao escala com nada enquanto guerreiro
        -- (Forca) e ladino (Veneno) compoem. Conduíte agora tambem concede
        -- 1 de Foco: toda evocacao da batalha sai +1, e cartas de Foco
        -- empilham em cima (eixo de scaling da classe, StS Defect).
        if self.player.addBuff then
            -- Re-baseline Jul/2026 (bateria 10x3 pos-v5.17): mago 0/10 com
            -- warrior 5/10 — mesmo com o bot comprando defesa, o mago nao
            -- converte A2-F8/A3. Foco inicial 1→2: cada pulso/evocacao sai
            -- +2 desde o turno 1 (a alavanca e a identidade da classe).
            -- Out/2026: Foco inicial cresce com a run, ver classPassiveTier.
            -- 2/3/4 -> 0/1/2 depois que o f67ebe4 consertou a passiva (ela so
            -- valia na 1a luta da run): com ela em toda luta e o Conduite
            -- crescendo, o mago foi a 63% (30 runs); 1/2/3 deu 77%; 0/1/2 deu
            -- 53% (meta 40-55%). O Foco agora vem do JOGO (Conduite, cartas).
            local f0 = self:classPassiveTier() + Game.MAGE_FOCUS_OFFSET
            if f0 > 0 then self.player:addBuff("focus", 99, f0) end
        end
        if love.timer then self._passiveFlashT = love.timer.getTime() end
    end
end

-- Quanto o Veneno das Toxinas sobe a cada turno com 2+ ataques. +1 (bateria
-- 15 runs): ladino 17% -> 20%, ainda morrendo no chefe do A4/A5 com lutas de
-- 8-9 turnos — a curva de veneno cresce devagar demais contra 600 de vida.
Game.TOXIN_GROWTH = 2

-- Deslocamento das passivas que crescem com a run sobre o degrau de
-- classPassiveTier (1/2/3). Foco inicial do mago = degrau + MAGE_FOCUS_OFFSET
-- (-1 -> 0/1/2, ver applyClassBattleStartPassive); Veneno das Toxinas =
-- degrau + ROGUE_POISON_OFFSET (+ o que cresceu na luta). Sao os knobs do
-- sweep (BALANCE_MAGE_FOCUS / BALANCE_ROGUE_POISON em tools/balance_sim.lua);
-- o piloto (tools/balance_ai.lua) espelha a mesma conta.
Game.MAGE_FOCUS_OFFSET = -1
Game.ROGUE_POISON_OFFSET = 0

-- Quantos ataques no turno o Impeto pede. 2 -> 3 (Out/2026): com o inimigo
-- suavizado (d0e41d4) e o DoT ignorando armadura, a bateria combinada de 30
-- runs deu guerreiro 67% — acima da meta 40-55%. A Forca por golpe e a
-- curva mais forte do jogo; pedir 3 ataques a desacelera sem mexer no resto.
Game.IMPETUS_ATTACKS = 3

function Game:applyClassTurnPassives(turnContext)
    local cls = self.selectedClass
    if cls ~= "warrior" and cls ~= "rogue" then return end
    -- multi-jogada: soma ataques de TODAS as jogadas do turno
    local attacks = self._attacksThisTurn or 0
    for _, c in ipairs(turnContext.allSelectedCards or {}) do
        if (c.attack or 0) > 0 then attacks = attacks + 1 end
    end
    self._attacksThisTurn = attacks
    if cls == "rogue" then
        if attacks >= 2 and not self._toxinGrowFiredThisTurn then
            self._toxinGrowFiredThisTurn = true
            self._toxinBonus = (self._toxinBonus or 0) + Game.TOXIN_GROWTH
            self:addMessage(msg("passive_toxins_grow",
                { n = self:classPassiveTier() + self._toxinBonus }), "success")
            if love.timer then self._passiveFlashT = love.timer.getTime() end
            Sfx.play("comboTrigger", { pitch = 1.3, volume = 0.6 })
        end
        return
    end
    if attacks >= Game.IMPETUS_ATTACKS and not self._impetusFiredThisTurn then
        self._impetusFiredThisTurn = true
        self.player:gainStrength(1)
        if love.timer then self._passiveFlashT = love.timer.getTime() end
        Sfx.play("comboTrigger", { pitch = 1.3, volume = 0.6 })
    end
end

function Game:playSelectedCards()
    -- Guard de reentrância (autoplay A5): startCombat com sequência ativa
    -- chamava onComplete SEM processar as cartas — jogada engolida.
    if self.combatAnimationSystem and self.combatAnimationSystem.isBlocking
        and self.combatAnimationSystem:isBlocking() then
        return
    end
    if #self.selectedCards == 0 then
        self:addMessage(msg("select_cards"), "info")
        return
    end

    -- Snapshot das cartas selecionadas (selectedCards e limpo em onCombatAnimationComplete).
    -- turnContext e construido UMA VEZ antes da animacao iniciar. Fase 3 (ComboSystem)
    -- vai enriquecer com activeCombos; por ora ja carrega tagCounts para debug.
    local snapshot = {}
    for _, c in ipairs(self.selectedCards) do table.insert(snapshot, c) end

    local turnContext = {
        allSelectedCards = snapshot,
        tagCounts = TagSystem.countAllTags(snapshot),
        cardsProcessed = {},
        turnNumber = self.turnCount or 0,
        activeCombos = {},
        game = self,   -- coringas de combo (ComboSystem.boostFor)
    }
    -- Detecta combos e anuncia no feed de mensagens uma vez por turno.
    ComboSystem.detect(turnContext)
    -- F3: estilo pontua — combos distintos da batalha + máximo num turno.
    self.scoreSystem:recordTurnCombos(turnContext.activeCombos)
    -- F4: contador de cartas jogadas + Tinta Viva (4 combos num turno).
    AchievementSystem.onCardsPlayed(self, turnContext)
    -- Passiva de classe por turno (Ímpeto do guerreiro).
    self:applyClassTurnPassives(turnContext)
    ComboSystem.announce(self, turnContext)
    self._currentTurnContext = turnContext

    -- Remove as cartas da mão IMEDIATAMENTE quando a animação começa.
    -- Juice kick escalonado via EventManager: cartas estouram de 60ms em 60ms
    -- conforme voam pro centro (sensação de "combo sendo lançado").
    local EM = _G.EventManager
    local Ev = _G.Event
    for idx, card in ipairs(self.selectedCards) do
        for i, handCard in ipairs(self.hand) do
            if handCard == card then
                table.remove(self.hand, i)
                break
            end
        end
        if EM and Ev and card.juice_up then
            EM.add(Ev:new({
                trigger = "after",
                delay = (idx - 1) * 0.06,
                blocking = false, -- paralelo: cada carta juice no seu tempo
                func = function() card:juice_up(0.35, 0.12); return true end,
            }))
        end
    end

    -- (O antigo `card._expectedProcs` saiu daqui: o pacing nao e mais
    -- ESTIMADO. Com a fila de beats a proxima carta espera a anterior
    -- terminar de verdade — previsao errada nao existe mais.)

    -- Inicia animação de combate
    self.combatAnimationSystem:startCombat(
        self.selectedCards,
        function()
            -- Callback quando animação termina
            self:onCombatAnimationComplete()
        end,
        function(card, beatSink)
            -- Callback para processar cada carta (com contexto do turno).
            -- `beatSink` vem do CombatSequence: os efeitos secundarios da
            -- carta sao COLETADOS e tocados um a um depois do impacto.
            return self:processCardInCombat(card, turnContext, { beats = beatSink })
        end
    )
end

-- ===== Editions (Fase 3.2) / Seals (Fase 3.3) =====
-- As tabelas de valor (Foil +5, Holo x1.2, Polychrome x1.5, selo Red x2)
-- moram em DamagePreview (fonte unica da conta da carta). Negative nao mexe
-- no valor: o efeito e +1 slot de joker (recomputeMaxJokerSlots).

-- Conta cartas Negative no deck atual e ajusta maxJokerSlots = base + N.
-- Chamar após startGame, addCardToRun, e qualquer mudança de deck.
-- Quantas vezes um SERVIÇO da loja foi comprado nesta run (bancada extra de
-- coringa, grimório de compra extra). Fonte única: o ledger do RunManager,
-- que viaja no save. Fora de run mode não existe loja persistente → 0.
-- Ver src/systems/ShopServices.lua.
function Game:getShopServiceCount(id)
    if self.isRunMode and self.runManager and self.runManager.getServiceCount then
        return self.runManager:getServiceCount(id)
    end
    return 0
end

function Game:recomputeMaxJokerSlots()
    -- Base do Config + bancadas COMPRADAS na loja (serviço `joker_slot`).
    local base = (Config.Game.MAX_JOKER_SLOTS or 3)
        + self:getShopServiceCount("joker_slot")
    local negCount = 0
    for _, card in ipairs(self.deck or {}) do
        if card and card.edition == "negative" then
            negCount = negCount + 1
        end
    end
    -- Inclui também cartas na mão (em jogo elas existem como instâncias).
    for _, card in ipairs(self.hand or {}) do
        if card and card.edition == "negative" then
            negCount = negCount + 1
        end
    end
    self.maxJokerSlots = base + negCount
    -- Espelha no run pra o teto de ATIVOS (RunManager:getMaxJokerSlots) seguir
    -- os bônus de slot (Negative) — senão a bancada usaria só o base fixo.
    if self.isRunMode and self.runManager and self.runManager.currentRun then
        self.runManager.currentRun.maxJokerSlots = self.maxJokerSlots
        self:rebuildJokerSlots()
    end
end

-- Resolucao de UMA carta. `opts.beats` (array) liga o modo SEQUENCIADO: o
-- dano/bloqueio continuam no instante do impacto, mas os efeitos SECUNDARIOS
-- (veneno, cura, orbe, espinhos, gatilhos de joker) sao COLETADOS e devolvidos
-- em `result.beats` pro CombatSequence tocar um de cada vez. Chamada sem opts
-- (testes, autoplay, smoke_upgrades) mantem tudo sincrono como sempre foi.
function Game:processCardInCombat(card, turnContext, opts)
    local sink = opts and opts.beats or nil
    local prevSink = self._beatSink
    self._beatSink = sink
    local result = self:_resolveCardInCombat(card, turnContext, sink)
    self._beatSink = prevSink
    return result
end

function Game:_resolveCardInCombat(card, turnContext, sink)
    local result = {}
    result.beats = sink
    turnContext = turnContext or self._currentTurnContext

    -- Pipeline unificado attack/defense: effects → stat → combo → jokers →
    -- edition → seal → Fraco/Fragil. A CONTA mora em DamagePreview.cardValue
    -- (fonte unica, Out/2026): a previa que o jogador ve antes de jogar e esta
    -- mesma funcao — aqui so entram os efeitos colaterais (Eco gasto, toast e
    -- tick dos coringas, banner do combo). Forca por golpe e scaling em dobro
    -- (auditoria Jul/2026) tambem moram la — nao reintroduzir soma aqui.
    local function computeCardValue()
        local v, steps, entries, echoUsed = DamagePreview.cardValue(self, card,
            turnContext, DamagePreview.liveState(self))
        if echoUsed then self._echoFiredThisTurn = true end
        for _, s in ipairs(steps) do
            if s.kind == "combo" then ComboSystem.raiseBanner(turnContext) break end
        end
        local procs = {}
        for _, e in ipairs(entries) do
            self.effectSystem:notifyJokerProc(self, e.joker, e.label, e.kind, procs)
        end
        result.jokerProcs = procs
        return v
    end

    -- Side-effects de seal (não envolvem valor da carta): ouro, orbs, draw extra.
    local function applySealSideEffects()
        if not card.seal then return end
        CombatBeats.step(sink, "seal." .. tostring(card.seal), function()
        if card.seal == "Gold" then
            if self.economySystem and self.economySystem.earnGold then
                self.economySystem:earnGold(3, "seal_gold")
                self:addMessage(msg("gold_seal", { value = 3 }), "gold")
            end
        elseif card.seal == "Purple" then
            if self.player and self.player.addOrb then
                self.player:addOrb({ type = "lightning", value = 1 })
                self:addMessage(msg("purple_seal"), "arcane")
            end
        elseif card.seal == "Blue" then
            -- Marca pra puxar 1 carta extra no próximo drawForTurn.
            self._sealDrawBonus = (self._sealDrawBonus or 0) + 1
        end
        end, "SIDE_EFFECT")
    end

    -- Efeitos secundários da carta (apply_debuff, heal, etc.) — excluem tipos que
    -- já foram consumidos em applyCardEffects acima.
    local function processAdditionalEffects()
        if not card.effects then return end
        for _, effect in ipairs(card.effects) do
            local t = effect.type
            if t ~= "strength_scaling" and t ~= "dexterity_scaling"
                and t ~= "multi_hit" and t ~= "damage_bonus_self" then
                -- ...Stepped: com sink ativo cada efeito ocupa um instante.
                self.effectSystem:processEffectCardStepped(self, effect, false)
            end
        end
    end

    if card.type == "attack" then
        -- Guard: inimigo ja morto nao recebe mais dano (evita "batendo no cadaver"
        -- quando o player encadeia multiplas cartas de ataque e a primeira ja mata).
        -- Retorna vazio pra CombatAnimationSystem nao spawnar damage number nem shake.
        if self.enemy.health <= 0 then
            if turnContext then table.insert(turnContext.cardsProcessed, card) end
            -- Exhaust TAMBEM precisa do bookkeeping aqui: sem isso a carta sai
            -- da mao e nao chega em pilha nenhuma (anomalia "cartas sumiram"
            -- do autoplay v3) — e escapa da remocao permanente da run.
            if card.exhaust and card.id then
                table.insert(self._exhaustedThisBattle, card.id)
                Sfx.play("cardExhaust")
            end
            if card.type ~= "joker" and not card.exhaust then
                table.insert(self.discard, card)
            end
            return result
        end

        -- (FRACO, debuff do inimigo: -25% por ultimo, dentro de cardValue.)
        local damage = computeCardValue()

        self.enemy:takeDamage(damage)
        AchievementSystem.onCardDamage(self, card, damage)   -- Golpe de Tinta

        -- Passiva rogue "Toxinas": 1º ataque do turno aplica 1 de Veneno.
        -- Debuff no inimigo = mudanca de ESTADO: instante proprio, depois do
        -- dano (pedido do dono — "esperar ele receber o buff ou debuff").
        if self.selectedClass == "rogue" and not self._toxinAppliedThisTurn
            and self.enemy:isAlive() then
            self._toxinAppliedThisTurn = true
            CombatBeats.step(sink, "passive.toxins", function()
                -- Out/2026: Veneno cresce com a run (1 → 2 → 3) e na luta
                -- (+2 a cada turno com 2+ ataques, ver applyClassTurnPassives).
                local stacks = math.max(1, self:classPassiveTier() + Game.ROGUE_POISON_OFFSET
                    + (self._toxinBonus or 0))
                self.enemy:addStatusEffect({ name = "poison", stacks = stacks, duration = 2 })
                local okCF, CF = pcall(require, "src.systems.CardFeel")
                if okCF then CF.burstAtEnemy("poison", 0.8) end
                if love.timer then self._passiveFlashT = love.timer.getTime() end
            end, "STATUS")
        end

        -- Floating damage number ancorado na carta (Fase 6.1).
        local FloatingText = require("src.ui.FloatingText")
        FloatingText.atCard(card, "-" .. tostring(damage), { kind = "damage" })

        -- Morreu ou cruzou os 30% com ESTE golpe? Os dois sao o PRIMEIRO passo
        -- depois do dano — antes do veneno, da cura, do que mais a carta faca.
        -- A deteccao da morte nao mora mais AQUI (era um `wasAlive` local, e
        -- por isso so este caminho encenava a morte): mora no Enemy, marcada em
        -- toda queda de vida, e chega aqui como `_pendingDeath`.
        self:settleEnemyDamage(sink)

        -- Triggers on-attack (ex: lifesteal de jokers, on_attack_debuff em cartas)
        -- procSink: triggers de joker também viram PROCS (tick no slot).
        self.effectSystem:applyTriggerEffects(self, "attack", {
            target = self.enemy, turnContext = turnContext, sourceCard = card,
            procSink = result.jokerProcs, beatSink = sink,
        })
        processAdditionalEffects()
        applySealSideEffects()

        result.damage = damage
    elseif card.type == "defense" then
        -- (FRAGIL, debuff do inimigo: -25% por ultimo, dentro de cardValue.)
        local defense = computeCardValue()

        -- Auditoria Jul/2026: o cap de Bloqueio (30) truncava EM SILENCIO —
        -- o jogador via "+20" e "+17" na mesma leva e nunca sabia que 7
        -- evaporaram. Agora o desperdicio e anunciado (decisao informada:
        -- "nao vale jogar o 2o escudo agora").
        local armorBefore = self.player.armor
        self.player:addArmor(defense)
        local wasted = (armorBefore + defense) - self.player.armor
        if wasted > 0 then
            local I18n = require("src.i18n.I18n")
            self:addMessage(I18n.t("messages.armor_capped",
                { max = self.player.maxArmor, wasted = wasted },
                "Bloqueio no maximo (" .. self.player.maxArmor .. ")! "
                    .. wasted .. " desperdicado"), "warning")
        end
        -- F4: Muralha do Escriba (cap de armor atingido).
        if self.player.armor >= self.player.maxArmor then
            AchievementSystem.onArmorCapped(self)
        end

        -- Floating armor number (Fase 6.1).
        local FloatingText = require("src.ui.FloatingText")
        FloatingText.atCard(card, "+" .. tostring(defense), { kind = "armor" })

        -- Triggers on-defend (ex: reflexo de dano em jokers e em defense cards
        -- como Barreira de Fogo via context.sourceCard).
        self.effectSystem:applyTriggerEffects(self, "defend", {
            target = self.enemy, turnContext = turnContext, sourceCard = card,
            procSink = result.jokerProcs, beatSink = sink,
        })
        processAdditionalEffects()
        applySealSideEffects()

        result.defense = defense
    elseif card.type == "joker" then
        -- Joker chegou via hand: leak arquitetural. Pós-Fase joker-split,
        -- jokers devem ser adquiridos via Game:addJokerToRun direto, nunca
        -- entrar no deck/hand. Aceita defensivamente pra não travar a run,
        -- mas alerta no log pra detectar regressão.
        Debug.warn("[Game] Joker chegou via hand (leak arquitetural): " .. tostring(card.id))
        -- Roteia pelo caminho canônico (coleção + bancada) em vez de empurrar
        -- a instância direto — mantém o invariante e nunca perde o joker.
        if self.isRunMode and card.id then
            self:addJokerToRun(card.id, { edition = card.edition, seal = card.seal })
        end
        result.joker = true
        
    elseif card.type == "effect" then
        -- Cartas de efeito executam seu efeito e são descartadas.
        -- Com sink ativo percorremos os efeitos AQUI (um passo cada) em vez de
        -- chamar `card.passive`, que dispara os N efeitos no mesmo instante —
        -- era o caso da Consumir do mago (evoca tudo + ganha Foco de uma vez).
        if sink and card.effects then
            for _, effect in ipairs(card.effects) do
                self.effectSystem:processEffectCardStepped(self, effect, true)
            end
        else
            card.passive(self) -- Executa efeito especial
        end
        result.effect = true
    end

    if turnContext then
        table.insert(turnContext.cardsProcessed, card)
    end

    -- Exhaust: pula o descarte (Slay-style) E agenda remocao permanente
    -- da run ao final da batalha. Tratamos aqui antes do push pro discard.
    if card.exhaust and card.id then
        table.insert(self._exhaustedThisBattle, card.id)
        Sfx.play("cardExhaust")
    end

    -- Descarte: cartas jogadas vao pra pilha de discard, exceto jokers (ficam
    -- em jokerSlots) e exhaust (somem da batalha e sao removidas da run).
    if card.type ~= "joker" and not card.exhaust then
        table.insert(self.discard, card)
    end

    return result
end

function Game:onCombatAnimationComplete()
    -- Aplica efeitos de combo do tipo "once" (apply_debuff, heal, evoke_on_combo)
    -- apos todas as cartas terem sido processadas. BEAT PROPRIO (Set/2026): o
    -- premio do combo chegava no mesmo frame do dissolve da ultima carta e
    -- passava batido — agora tem o instante dele, depois de tudo.
    local ctx = self._currentTurnContext
    if ctx then
        CombatBeats.push("combo.once_effects", function()
            ComboSystem.applyOnceEffects(self, ctx)
        end, "SIDE_EFFECT")
    end
    self._currentTurnContext = nil

    -- Cartas já foram removidas da mão em playSelectedCards()
    self.selectedCards = {}

    -- TURNO MULTI-JOGADA (playtest Jul/2026): jogar cartas NÃO encerra o
    -- turno — mana restaurada/cartas compradas por efeitos ficam usáveis
    -- AGORA (cartas de mana/draw eram letra morta no modelo de 1 jogada).
    -- O turno só passa no botão ENCERRAR TURNO (Game:endTurn).
end

-- Encerra o turno do jogador: descarta a mão (exceto retain) e passa a
-- vez pro inimigo. Chamado pelo botão "Encerrar Turno".
function Game:endTurn()
    if self.turn ~= "player" then return end
    if self.combatAnimationSystem and self.combatAnimationSystem.isBlocking
        and self.combatAnimationSystem:isBlocking() then
        -- Clique durante a animação: ENFILEIRA (GameplayScene processa ao
        -- fim da jogada) — engolir o clique era "encerro e nada acontece".
        self._endTurnQueued = true
        return
    end
    self._endTurnQueued = false
    -- devolve mana de cartas selecionadas e não jogadas
    for i = #self.selectedCards, 1, -1 do
        self:selectCard(self.selectedCards[i])
    end
    self:discardHandEndOfTurn()
    -- Pulso passivo dos orbes (Defect-style) antes do inimigo agir — se o
    -- pulso matar, enemyTurn tem guard de inimigo morto e isPhaseCleared
    -- transiciona no proximo frame.
    -- UM ORBE POR VEZ: o sink vira uma fila de beats (cada orbe pulsa no
    -- instante dele). Sem EventManager (headless) o push executa na hora.
    if self.effectSystem and self.effectSystem.orbPassiveTick then
        local pulses = {}
        self.effectSystem:orbPassiveTick(self, pulses)
        if #pulses > 0 then
            CombatBeats.push("turn.orb_pulse_start", nil, "MICRO")
            CombatBeats.pushAll(pulses)
        end
    end
    -- Turno inimigo NOVO: limpa flag de "agindo" (v3) — se ficou stale de uma
    -- batalha abandonada, sem isso o inimigo nunca mais agiria.
    self._enemyActing = false
    self.turn = "enemy"
end

-- Move a mão pro descarte no fim do turno do jogador (cartas `retain` ficam).
function Game:discardHandEndOfTurn()
    local kept = {}
    for _, card in ipairs(self.hand) do
        if card.retain then
            table.insert(kept, card)
        else
            table.insert(self.discard, card)
        end
    end
    self.hand = kept
end

-- ENFURECIDO: o instante em que o inimigo cruza os 30% de vida.
--
-- Enemy:takeDamage detecta a VIRADA e levanta `_pendingEnrage` (ver o
-- comentario la). Aqui esse estado vira ACONTECIMENTO: um beat bloqueante com
-- rugido, aura, numero e toast — porque a conta de dano do jogador acabou de
-- mudar e ele precisa saber no momento exato.
--
-- `sink` presente (resolucao de carta) = vira um passo da carta, logo depois do
-- dano que causou a virada. Ausente = o beat entra sozinho; e se estivermos
-- DENTRO de um beat (pulso de orbe, reflexo de espinhos, checkpoint do turno),
-- o anuncio roda ali mesmo e ESTENDE aquele beat pro tempo de STATUS — assim o
-- caso comum (ninguem enfureceu) nao paga ar morto e o caso raro ganha o
-- instante dele.
--
-- Retorna true se anunciou.
function Game:_announceEnrageIfPending(sink)
    local e = self.enemy
    if not e or not e._pendingEnrage then return false end
    e._pendingEnrage = false
    -- Morreu no mesmo golpe que o enfureceria: a morte e o acontecimento.
    if not e:isAlive() then return false end

    local enemyRef = e
    local body = function()
        if self.enemy ~= enemyRef then return end
        local I18n = require("src.i18n.I18n")
        Sfx.playWithVariation("enemyBuffRoar", 0.88, 0.05)
        if enemyRef.juice_up then enemyRef:juice_up(0.45, 0.12) end
        local okER, ER = pcall(require, "src.ui.EnemyRenderer")
        if okER and ER.triggerBuff then ER.triggerBuff() end
        local okCF, CardFeel = pcall(require, "src.systems.CardFeel")
        if okCF then CardFeel.burstAtEnemy("buff", 1.2) end
        if _G.triggerShake then _G.triggerShake(7, 0.2) end
        local okFT, FloatingText = pcall(require, "src.ui.FloatingText")
        if okFT and okER and ER.getLastPos then
            local ex, ey = ER.getLastPos()
            if ex and ey then
                FloatingText.spawn(I18n.t("status.enraged.name", nil, "Enfurecido"),
                    ex, ey - 30, { kind = "movename", hold = 0.5, lift = 24 })
            end
        end
    end

    if sink then
        sink[#sink + 1] = { label = "enemy.enraged", fn = body, hold = "STATUS" }
    elseif CombatBeats.extendCurrent("STATUS") then
        -- Ja estamos dentro de um beat: este E o instante (a fila segura mais).
        -- `mark` deixa o acontecimento visivel no trace mesmo sem beat proprio.
        CombatBeats.mark("enemy.enraged")
        body()
    else
        CombatBeats.push("enemy.enraged", body, "STATUS")
    end
    return true
end

-- ============================================================================
-- A MORTE DO INIMIGO — TAMBEM UM ACONTECIMENTO (Set/2026)
-- ============================================================================
-- Queixa do dono jogando: "em alguns cenarios o mob nao esta tendo a animacao
-- de morrer, cair no chao etc. Acho que e quando se buffa".
--
-- A hipotese "quando se buffa" estava PERTO: o que os cenarios sem morte tem
-- em comum nao e o buff, e a FONTE DO GOLPE FINAL. `_onEnemyDeath` (animacao,
-- rugido, shake, pontuacao da batalha) so era chamado do caminho da carta de
-- ATAQUE. Matar com magia, com pulso ou evocacao de orbe, com veneno ou com
-- espinhos levava a vida a zero sem que ninguem encenasse nada — e as fontes
-- que o dono associa a "se buffar" (Foco + orbes do mago, espinhos armados por
-- uma carta de defesa) sao justamente essas.
--
-- A correcao espelha o ENFURECIDO: `Enemy` marca a VIRADA vivo->morto
-- (`_pendingDeath`, no unico lugar por onde a vida cai) e aqui isso vira um
-- BEAT que segura a fila pelo tempo de o corpo cair. Fonte nenhuma fica muda,
-- porque a deteccao deixou de morar no caminho e passou a morar na entidade.
--
-- `sink` presente (resolucao de carta) = a morte vira um passo da carta, logo
-- depois do dano que a causou. Dentro de um beat (pulso de orbe, reflexo de
-- espinhos, veneno) = este E o instante, e a fila segura mais. Fora de tudo =
-- beat proprio.
--
-- Retorna true se a morte foi encenada nesta chamada.
-- AGENDAR NAO E EXECUTAR — a distincao que travou o jogo (Set/2026)
--
-- Primeira versao guardava so `_deathHandled`, que so vira true DENTRO do beat,
-- quando ele roda. Entre AGENDAR e RODAR passam-se dezenas de frames (a cadeia
-- da carta continua: procs, orbes, dissolve). E o checkpoint da GameplayScene
-- pergunta "morto e nao encenado?" A CADA FRAME — via um `announceDeathIfPending`
-- por frame. Resultado: cada frame dessa janela empurrava OUTRO beat de morte
-- de 1,1s pra fila. Medido em tools/test_death_midchain: 11 beats `enemy.death`
-- numa jogada de 2 cartas = 12s de fila morta; com a fila travada, `isBlocking()`
-- nunca cai, os botoes ficam cinzas e a tela de espolios/vitoria NUNCA entra
-- ("matei o boss e o jogo parou", dono).
--
-- Por isso existem DUAS flags, e elas nao sao a mesma coisa:
--   `_deathStaged`  — a morte ja foi AGENDADA (existe um beat pra ela).
--   `_deathHandled` — a morte ja ACONTECEU (o `_onEnemyDeath` rodou).
-- Quem decide "preciso agendar?" tem que olhar a PRIMEIRA. Guardar intencao
-- com o flag do resultado e a forma geral deste defeito.
function Game:announceDeathIfPending(sink)
    local e = self.enemy
    if not e then return false end
    if self._deathStaged or self._deathHandled then return false end
    -- REDE: inimigo morto e ainda nao agendado conta como pendente mesmo sem a
    -- marcacao. A marcacao cobre toda fonte de dano de HOJE; a rede cobre a
    -- fonte de AMANHA (quem mexer na vida por fora do Enemy). Nenhuma morte
    -- pode chegar a tela de espolios sem ter acontecido antes.
    if not (e._pendingDeath or not e:isAlive()) then return false end
    e._pendingDeath = false
    self._deathStaged = true

    local enemyRef = e
    local body = function()
        -- Passo atrasado de uma batalha que ja trocou: no-op. Solta o
        -- agendamento pra que a batalha NOVA possa agendar a morte dela.
        if self.enemy ~= enemyRef then
            self._deathStaged = false
            return
        end
        self:_onEnemyDeath()
    end

    if sink then
        sink[#sink + 1] = { label = "enemy.death", fn = body, hold = Game.DEATH_HOLD }
    elseif CombatBeats.extendCurrent(Game.DEATH_HOLD) then
        -- Ja estamos dentro de um beat (o orbe que pulsou, o veneno que ticou,
        -- o espinho que refletiu): a morte acontece NO golpe que a causou e a
        -- fila segura ate o corpo assentar.
        CombatBeats.mark("enemy.death")
        body()
    else
        CombatBeats.push("enemy.death", body, Game.DEATH_HOLD)
    end
    return true
end

-- O intent em execucao poe veneno/queimadura no jogador? (o beat do DoT do
-- jogador e empurrado ANTES do golpe acontecer — precisa saber se tera ar).
function Game:_intentAppliesDot()
    local it = self.enemy and self.enemy.getIntent and self.enemy:getIntent()
    for _, d in ipairs((it and it.debuffs) or {}) do
        if d.name == "poison" or d.name == "burn" then return true end
    end
    return false
end

-- FASE NOVA do chefe (Rainha do Eclipse abaixo de 50%): mesmo contrato do
-- ENFURECIDO — o Enemy marca `_pendingPhase` no funil de dano, aqui vira
-- acontecimento (beat STATUS com nome da fase, rugido e shake). O intent ja
-- anunciado NAO muda; o kit novo vale do proximo intent em diante.
function Game:_announcePhaseIfPending(sink)
    local e = self.enemy
    if not e or not e._pendingPhase then return false end
    local ph = e._pendingPhase
    e._pendingPhase = nil
    if not e:isAlive() then return false end
    local enemyRef = e
    local body = function()
        if self.enemy ~= enemyRef then return end
        local I18n = require("src.i18n.I18n")
        local key = "enemy_kit.phases." .. tostring(ph.id)
        local name = I18n.t(key .. ".name", nil, tostring(ph.id))
        self:addMessage(I18n.t(key .. ".msg", nil, name), "warning")
        Sfx.playWithVariation("enemyBuffRoar", 0.75, 0.04)
        if enemyRef.juice_up then enemyRef:juice_up(0.6, 0.15) end
        local okER, ER = pcall(require, "src.ui.EnemyRenderer")
        if okER and ER.triggerBuff then ER.triggerBuff() end
        local okCF, CardFeel = pcall(require, "src.systems.CardFeel")
        if okCF then CardFeel.burstAtEnemy("dark", 1.4) end
        if _G.triggerShake then _G.triggerShake(10, 0.35) end
        local okFT, FloatingText = pcall(require, "src.ui.FloatingText")
        if okFT and okER and ER.getLastPos then
            local ex, ey = ER.getLastPos()
            if ex and ey then
                FloatingText.spawn(name, ex, ey - 30, { kind = "movename", hold = 0.7, lift = 26 })
            end
        end
    end
    if sink then
        sink[#sink + 1] = { label = "enemy.phase", fn = body, hold = "STATUS" }
    elseif CombatBeats.extendCurrent("STATUS") then
        CombatBeats.mark("enemy.phase")
        body()
    else
        CombatBeats.push("enemy.phase", body, "STATUS")
    end
    return true
end

-- PONTE UNICA DO POS-DANO: tudo que um dano ao inimigo pode ter causado e
-- encenado aqui, em ordem — primeiro a MORTE (se matou, nada mais importa),
-- depois o ENFURECIDO. Chamada depois de cada dano, de qualquer fonte.
function Game:settleEnemyDamage(sink)
    local died = self:announceDeathIfPending(sink)
    local raged = self:_announceEnrageIfPending(sink)
    local phased = self:_announcePhaseIfPending(sink)
    return died or raged or phased
end

-- ALIAS de compatibilidade: `settleEnemyDamage` e o nome honesto, mas
-- `announceEnrageIfPending` e o nome que o EffectSystem conhece (o helper
-- `checkEnrage` chama isto depois de CADA takeDamage dele — foi justamente
-- essa varredura ja existente que deu cobertura de graca as 6 fontes de dano
-- de la). PENDENCIA ASSUMIDA: quando der pra mexer no EffectSystem, trocar
-- `checkEnrage` pra chamar `settleEnemyDamage` e apagar este alias — o nome
-- de um hook universal nao pode prometer so metade do que ele faz.
function Game:announceEnrageIfPending(sink)
    return self:settleEnemyDamage(sink)
end

-- A morte ja "aconteceu na tela"? Enquanto for false, nenhuma tela de desfecho
-- (espolios, vitoria) pode entrar. E a regra que o dono pediu por nome: "a tela
-- de vitoria ta aparecendo rapido demais, so aparece quando a gente tem a
-- confirmacao que ele morreu". Mora aqui, e nao inline na cena, pra ser
-- alcancavel por teste (doutrina de defeitos 1).
function Game:isDeathSettled()
    return not self._deathPauseTimer or self._deathPauseTimer <= 0
end

-- Pode trocar pra tela de desfecho? Combate parado (inclui a fila de beats) E
-- morte assentada.
function Game:isReadyForEndScreen()
    local cs = self.combatAnimationSystem
    if cs and cs.isBlocking and cs:isBlocking() then return false end
    return self:isDeathSettled()
end

-- ============================================================================
-- TURNO DO INIMIGO — UMA CADEIA DE ACONTECIMENTOS (Set/2026)
-- ============================================================================
-- Pedido do dono: "quando o inimigo se buffa, ou sofre algum debuff precisamos
-- deixar isso ser algo bloqueando do turno seguir". O turno do inimigo deixou
-- de ser um bloco sincrono com dois respiros no fim e virou uma FILA de beats
-- (src/systems/CombatBeats.lua), cada um ocupando seu instante e segurando o
-- proximo:
--
--   armadura expira > furia > TELEGRAFIA > acao (defende/buffa/golpeia)
--     > espinhos refletem > veneno tica > proximo intent
--     > upkeep do jogador > compra > gatilhos de inicio de turno (um a um)
--     > a vez volta pro jogador
--
-- Os beats sao empurrados AQUI, em ordem; nada e empurrado de fora da fila
-- durante a execucao (o apex da investida so LEVANTA UMA FLAG — ver `struck`
-- abaixo), senao a ordem quebraria. Token `_enemyTurnSeq` + `enemyRef`
-- invalidam passos atrasados se a batalha mudou no meio (morte, andar novo,
-- restart).
function Game:enemyTurn()
    -- Bug fix: inimigo morto NAO ataca. Antes nao havia check, e enemyTurn
    -- rodava no mesmo frame que isPhaseCleared detectava morte -> dano fantasma.
    if not self.enemy:isAlive() then
        -- Devolve turn pro jogador formalmente, mas isPhaseCleared vai cuidar
        -- de transicionar pra cardReward no proximo frame.
        self.turn = "player"
        return
    end

    -- Re-entrancia (v3): com os respiros do turno, `turn` fica "enemy" por
    -- ~2s — caller que chama enemyTurn() por frame (gate de cena/teste)
    -- re-executaria o intent. O turno inimigo e UM ato: segunda chamada e
    -- no-op ate o beat final devolver a vez.
    if self._enemyActing then return end
    self._enemyActing = true

    self._enemyTurnSeq = (self._enemyTurnSeq or 0) + 1
    local seq = self._enemyTurnSeq
    local enemyRef = self.enemy
    -- Envelope de TODO beat deste turno: se a batalha trocou, o passo atrasado
    -- vira no-op em vez de mexer num inimigo que nao existe mais.
    local function beat(fn)
        return function()
            if self._enemyTurnSeq ~= seq or self.enemy ~= enemyRef then return end
            fn()
        end
    end

    -- F1: executa o intent TELEGRAFADO no turno anterior (o jogador viu o
    -- icone/numero no EnemyHud e pode se preparar). Depois rola o proximo.
    local intent = self.enemy.nextIntent or "attack"

    local okER, ER = pcall(require, "src.ui.EnemyRenderer")
    if not okER then ER = nil end
    local function float(text, opts)
        local okFT, FloatingText = pcall(require, "src.ui.FloatingText")
        local ex, ey
        if ER and ER.getLastPos then ex, ey = ER.getLastPos() end
        if okFT and ex and ey then FloatingText.spawn(text, ex, ey, opts) end
    end

    -- ===== BEAT: checkpoint do ENFURECIDO =====
    -- Rede de seguranca: se alguma fonte fora da resolucao de carta cruzou os
    -- 30% (combo, pulso de orbe, reflexo de espinhos), o anuncio sai AQUI,
    -- antes do inimigo agir — nunca fica mudo. Custa MICRO quando nao ha nada
    -- a anunciar; quando ha, `extendCurrent` compra o tempo de STATUS.
    CombatBeats.push("enemy.enrage_check", beat(function()
        self:announceEnrageIfPending(nil)
    end), "MICRO")

    -- ===== BEAT: armadura do inimigo EXPIRA =====
    -- Simetria com o jogador: defend protege contra UM turno de ataques, nao
    -- vira muro. Autoplay A1: elite com 4 HP ficou imortal re-encapando armor.
    if (self.enemy.armor or 0) > 0 then
        CombatBeats.push("enemy.armor_expire", beat(function()
            self.enemy.armor = 0
        end), "MICRO")
    end

    -- ===== BEAT: Furia anti-stall =====
    -- Turno 8+ o inimigo ganha +2 de dano por turno, ATE +10 total (teto;
    -- autoplay A4: sem teto virava sentenca). E mudanca de ESTADO: beat longo.
    self.battleTurn = (self.battleTurn or 0) + 1
    -- Turnos da RUN inteira (resumo da tela final). Vive na run pra viajar
    -- no save — o battleTurn zera a cada batalha.
    if self.isRunMode and self.runManager and self.runManager.currentRun then
        local r = self.runManager.currentRun
        r.turnsTotal = (r.turnsTotal or 0) + 1
    end
    if self.battleTurn >= 8 and self.battleTurn < 13 then
        CombatBeats.push("enemy.fury", beat(function()
            self.enemy.baseDamage = self.enemy.baseDamage + 2
            self.enemy.damage = self.enemy.damage + 2
            self.enemy:addStatusEffect({ name = "fury", stacks = 2, duration = 99 })
            self:addMessage(msg("enemy_fury", { value = 2 }), "warning")
            Sfx.playWithVariation("enemyBuffRoar", 1.05, 0.06)
            if self.enemy.juice_up then self.enemy:juice_up(0.35, 0.1) end
            local okCF, CardFeel = pcall(require, "src.systems.CardFeel")
            if okCF then CardFeel.burstAtEnemy("buff", 1.0) end
            float("+2", { kind = "damage", fontSize = 18 })
        end), "STATUS")
    end

    -- ===== BEAT: TELEGRAFIA ("o anuncio virou acao") =====
    -- O intent PISCA e o NOME do golpe sobe do inimigo — IntentFlash +
    -- ShowMoveName do StS. Passo proprio: o jogador LE o que vem antes de vir.
    CombatBeats.push("enemy.telegraph", beat(function()
        local okEH, EnemyHud = pcall(require, "src.ui.EnemyHud")
        if okEH and EnemyHud.flashIntent then EnemyHud.flashIntent() end
        local I18n = require("src.i18n.I18n")
        -- Nome do golpe do KIT (enemy_kit.moves.<id>); golpe legado cai no
        -- nome generico do kind.
        local cur = self.enemy:getIntent()
        local moveName = I18n.t("enemy_kit.moves." .. tostring(cur.id) .. ".name", nil,
            I18n.t("enemy_moves." .. intent, nil, ""))
        if moveName ~= "" then
            float(moveName, { kind = "movename", hold = 0.55, lift = 26 })
        end
    end), "TELEGRAPH")

    -- ===== BEATS: A ACAO =====
    -- O golpe CONGELADO no anuncio (Enemy:getIntent, kit em src/data/enemies)
    -- vira uma sequencia de acontecimentos, cada um no seu beat, na mesma
    -- ordem em que o tooltip do intent os descreve:
    --   bloqueio > golpe(s) > espinhos > debuff(s) no jogador > forca > cura
    --     > invocacao > carga
    -- A execucao le os CAMPOS do intent (nao o kind): um golpe pode bloquear,
    -- bater e debuffar no mesmo turno.
    local it = self.enemy:getIntent()
    local I18n = require("src.i18n.I18n")
    local struck = false   -- algum golpe chegou a acontecer? (governa os espinhos)
    local function playerFloat(text, opts)
        local okFT, FloatingText = pcall(require, "src.ui.FloatingText")
        if okFT and love.graphics then
            FloatingText.spawn(text, 120, love.graphics.getHeight() - 150, opts)
        end
    end

    if (it.armor or 0) > 0 then
        CombatBeats.push("enemy.defend", beat(function()
            local armorGain = it.armor
            self.enemy:addArmor(armorGain)
            Sfx.play("armorSound")
            if ER and ER.triggerDefend then ER.triggerDefend() end
            -- Game feel v1: o escudo MATERIALIZA no corpo dele (burst azul-aco).
            local okCF, CardFeel = pcall(require, "src.systems.CardFeel")
            if okCF then CardFeel.burstAtEnemy("armor", 0.9) end
            float("+" .. armorGain, { kind = "armor", fontSize = 20 })
        end), "ENEMY_ACT")
    end

    if (it.hits or 0) > 0 and (it.perHit or 0) > 0 then
        -- O inimigo INVESTE fisicamente e o dano e aplicado NO IMPACTO da
        -- investida (apex), nao num corte seco. O beat nao e por TEMPO: ele
        -- espera o apex acontecer (pushUntil), senao o resto do turno rodava
        -- por cima de um golpe ainda no ar — foi o "bug do escudo" do
        -- playtest Jul/2026. MULTI-GOLPE = uma investida por golpe, cada uma
        -- no seu beat (o Bloqueio absorve golpe a golpe e o jogador VE onde
        -- o escudo acabou).
        local function applyHit(damage, pierce)
            -- Pitch escalado pela magnitude (Balatro sound_manager).
            local atkPitch = math.max(0.7, math.min(1.05, 1.1 - damage * 0.012))
            Sfx.playWithVariation("enemyAttack", atkPitch, 0.08)
            local hpBefore = self.player.health
            self.player:takeDamage(damage, pierce)
            -- Detector do piloto (Jul/2026): registrar o dano BRUTO fazia golpe
            -- 100% bloqueado matar o bonus flawless do score e das conquistas.
            -- Conta so o que FUROU o escudo.
            local effective = hpBefore - self.player.health
            self.scoreSystem:recordDamageTaken(effective)
            if pierce then
                self:addMessage(I18n.t("enemy_kit.msg.pierce", { value = damage },
                    "Golpe atravessa o Bloqueio: {value}!"), "warning")
            end
            if _G.triggerShake then
                local intensity = math.min(14, 4 + damage * 0.25)
                _G.triggerShake(intensity, 0.22)
            end
            -- Feedback no painel do jogador: "-N" real que entrou, ou
            -- BLOQUEADO! em aco quando o escudo segurou tudo.
            local okFT, FloatingText = pcall(require, "src.ui.FloatingText")
            if okFT and love.graphics then
                if effective > 0 then
                    FloatingText.spawn("-" .. effective, 120,
                        love.graphics.getHeight() - 120,
                        { kind = "damage", fontSize = 22 })
                else
                    FloatingText.spawn("BLOQUEADO!", 120,
                        love.graphics.getHeight() - 120,
                        { kind = "armor", fontSize = 18 })
                end
            end
        end

        local hits = it.hits
        local animKind = (it.kind == "strong") and "strong" or "attack"
        for h = 1, hits do
            local landed = false
            CombatBeats.pushUntil("enemy.attack", beat(function()
                if not self.player:isAlive() then landed = true return end
                local damage = self.enemy:intentHitDamage(self.player)
                if damage <= 0 then
                    landed = true
                    return
                end
                struck = true
                if ER and ER.triggerAttack then
                    ER.triggerAttack(animKind, function()
                        applyHit(damage, it.pierce)
                        landed = true
                    end)
                else
                    applyHit(damage, it.pierce)
                    landed = true
                end
            end), function() return landed end, 2.5,
                (h == hits) and "HIT_SETTLE" or "JOKER_PROC")
        end

        -- ===== BEAT: ESPINHOS =====
        -- Contrato Set/2026: a carta ARMA o buff "thorn"; o REFLEXO acontece
        -- aqui, quando o inimigo ataca — causa e efeito em instantes separados.
        -- O beat so e empurrado se ha espinhos armados AGORA (a carta ja foi
        -- jogada no turno do jogador); o corpo confere se o golpe saiu mesmo.
        -- Multi-golpe reflete UMA vez por turno (o teto P2.3 continua por turno).
        if EffectSystem.thornStacks(self) > 0 then
            CombatBeats.push("player.thorn_reflect", beat(function()
                if not struck then return end
                self.effectSystem:fireThornReflect(self)
                -- O reflexo pode ter cruzado os 30%: o anuncio e aqui mesmo.
                self:announceEnrageIfPending(nil)
            end), "REFLECT")
        end
    end

    -- ===== BEATS: DEBUFF NO JOGADOR (um por status) =====
    -- Estado do jogador mudando = STATUS (0,55s): o jogador precisa ver que
    -- esta Fraco/Fragil ANTES de comprar a mao que isso afeta.
    for _, d in ipairs(it.debuffs or {}) do
        CombatBeats.push("enemy.debuff." .. d.name, beat(function()
            if not self.player:isAlive() then return end
            self.player:addDebuff(d.name, d.duration, d.stacks)
            local statusName = I18n.t("status." .. d.name .. ".name", nil,
                I18n.t("enemy_kit.status." .. d.name .. ".name", nil, d.name))
            Sfx.playWithVariation("enemyBuffRoar", 0.8, 0.05)
            if _G.triggerShake then _G.triggerShake(3, 0.12) end
            local okCF, CardFeel = pcall(require, "src.systems.CardFeel")
            if okCF then
                local theme = ({ weak = "weak", frail = "weak", vulnerable = "vulnerable",
                    poison = "poison", burn = "fire" })[d.name] or "weak"
                CardFeel.burstAtPlayer(theme, 0.9)
            end
            playerFloat(statusName, { kind = "movename", hold = 0.5, lift = 22 })
        end), "STATUS")
    end

    if (it.strength or 0) > 0 then
        CombatBeats.push("enemy.buff", beat(function()
            self.enemy:gainStrength(it.strength)
            -- Game feel v1: buff tem RUGIDO proprio (antes reusava enemyAttack
            -- grave — soava como golpe, confundia) + aura vermelha subindo.
            Sfx.playWithVariation("enemyBuffRoar", 1.0, 0.06)
            if self.enemy.juice_up then self.enemy:juice_up(0.4, 0.1) end
            if ER and ER.triggerBuff then ER.triggerBuff() end
            local okCF, CardFeel = pcall(require, "src.systems.CardFeel")
            if okCF then CardFeel.burstAtEnemy("buff", 1.1) end
            float(I18n.t("enemy_kit.msg.strength_float", { value = it.strength },
                "+" .. it.strength), { kind = "damage", fontSize = 18 })
        end), "STATUS")
    end

    if (it.heal or 0) > 0 then
        CombatBeats.push("enemy.heal", beat(function()
            local healed = self.enemy:healSelf(it.heal)
            if healed <= 0 then return end
            Sfx.playWithVariation("enemyBuffRoar", 1.15, 0.05)
            local okCF, CardFeel = pcall(require, "src.systems.CardFeel")
            if okCF then CardFeel.burstAtEnemy("heal", 1.0) end
            float("+" .. healed, { color = { 0.45, 0.9, 0.5, 1 }, fontSize = 20 })
        end), "STATUS")
    end

    if (it.summon or 0) > 0 then
        CombatBeats.push("enemy.summon", beat(function()
            self.enemy:addStatusEffect({ name = "swarm", stacks = it.summon, duration = 999 })
            Sfx.playWithVariation("enemyBuffRoar", 1.2, 0.08)
            self:addMessage(I18n.t("enemy_kit.msg.summoned", { value = it.summon },
                "A revoada cresce: +{value}"), "warning")
            if ER and ER.triggerBuff then ER.triggerBuff() end
            local okCF, CardFeel = pcall(require, "src.systems.CardFeel")
            if okCF then CardFeel.burstAtEnemy("dark", 1.1) end
            float("+" .. it.summon, { kind = "damage", fontSize = 18 })
        end), "STATUS")
    end

    if it.charge then
        -- CARGA: o turno inteiro e o aviso. O golpe carregado ja esta forcado
        -- como proximo intent (Enemy:rollIntent) e aparece no HUD no fim deste
        -- turno — o jogador tem a mao inteira pra se preparar.
        CombatBeats.push("enemy.charge", beat(function()
            Sfx.playWithVariation("enemyBuffRoar", 0.7, 0.04)
            if self.enemy.juice_up then self.enemy:juice_up(0.5, 0.12) end
            if ER and ER.triggerBuff then ER.triggerBuff() end
            if _G.triggerShake then _G.triggerShake(5, 0.3) end
        end), "STATUS")
    end

    -- ===== BEATS: fim do turno do inimigo + comeco do turno do jogador =====
    self:_pushEnemyTurnTail(beat)
end

-- Rabo do turno do inimigo: veneno, proximo intent, upkeep do jogador, compra,
-- gatilhos de inicio de turno e a devolucao da vez. Cada um num beat.
-- Separado de enemyTurn so por tamanho — faz parte da MESMA cadeia.
function Game:_pushEnemyTurnTail(beat)
    -- So abre o respiro do DoT quando ha DoT VISIVEL pra ticar — sem ele,
    -- onTurnEnd ainda precisa rodar (decrementa durations), mas sem ar.
    -- Set/2026: a QUEIMADURA conta aqui tambem. Checar so `poison` fazia o
    -- fogo do mago ticar dentro de um MICRO de 0,10s, sem tempo de ler.
    local hasDot = false
    for _, st in ipairs(self.enemy.statusEffects or {}) do
        if (st.name == "poison" or st.name == "burn") and (st.stacks or 0) > 0 then
            hasDot = true
            break
        end
    end

    CombatBeats.push("enemy.dot", beat(function()
        local poisonDmg, burnDmg = self.enemy:onTurnEnd()
        if poisonDmg and poisonDmg > 0 then
            -- Pitch random pra poison "chiar" diferente cada tick.
            Sfx.playWithVariation("poisonTick", 1.0, 0.2)
            local okER, ER = pcall(require, "src.ui.EnemyRenderer")
            if okER and ER.triggerPoison then
                ER.triggerPoison()
                local okFT, FloatingText = pcall(require, "src.ui.FloatingText")
                local ex, ey
                if ER.getLastPos then ex, ey = ER.getLastPos() end
                if okFT and ex and ey then
                    FloatingText.spawn("-" .. poisonDmg, ex, ey,
                        { color = { 0.45, 0.9, 0.35, 1 }, fontSize = 18 })
                end
            end
            -- Game feel v1: bolhas verdes borbulham do corpo (o DoT e fisico).
            local okCF, CardFeel = pcall(require, "src.systems.CardFeel")
            if okCF then CardFeel.burstAtEnemy("poison", 0.8) end
        end
        -- QUEIMADURA (Set/2026): segundo DoT, assinatura PROPRIA — o veneno
        -- chia verde, o fogo estala laranja. Quando os dois ticam no mesmo
        -- turno (mago com carta de ladino) o beat ganha ar extra em vez de
        -- despejar dois numeros no mesmo piscar: e o passo CONDICIONAL de
        -- CombatBeats, o mesmo do `enemy.enrage_check`.
        if burnDmg and burnDmg > 0 then
            self.effectSystem.announceBurnTick(self, burnDmg)
            if poisonDmg and poisonDmg > 0 then
                CombatBeats.extendCurrent("DOT")
            end
        end
        -- Veneno mata igual: se este tick derrubou a criatura, ela cai AGORA —
        -- neste beat — e nao tres passos adiante, com a barra zerada e o
        -- monstro em pe enquanto o turno continua rodando. (`onTurnEnd` mexe na
        -- vida na aritmetica crua, por isso a morte nao vem por `takeDamage`.)
        self:announceDeathIfPending(nil)
    end), hasDot and "DOT" or "MICRO")

    -- REGENERACAO do inimigo (Colosso Putrido): cura propria no fim do turno
    -- dele — instante proprio, a luta longa e a vantagem dele e o jogador
    -- precisa VER a vida voltar.
    if self.enemy:hasStatus("regen") then
        CombatBeats.push("enemy.regen", beat(function()
            local healed = self.enemy:tickRegen()
            if healed and healed > 0 then
                local I18n = require("src.i18n.I18n")
                local okCF, CardFeel = pcall(require, "src.systems.CardFeel")
                if okCF then CardFeel.burstAtEnemy("heal", 0.8) end
                local okER, ER = pcall(require, "src.ui.EnemyRenderer")
                local okFT, FloatingText = pcall(require, "src.ui.FloatingText")
                if okER and okFT and ER.getLastPos then
                    local ex, ey = ER.getLastPos()
                    if ex and ey then
                        FloatingText.spawn("+" .. healed, ex, ey,
                            { color = { 0.45, 0.9, 0.5, 1 }, fontSize = 18 })
                    end
                end
            end
        end), "DOT")
    end

    -- Debuffs do JOGADOR decaem no fim do turno do inimigo (o que ele acabou
    -- de aplicar pula este decremento — Player:decayDebuffs). Sempre
    -- empurrado: o golpe deste turno pode ter acabado de aplicar um.
    CombatBeats.push("player.debuff_decay", beat(function()
        if self.player.decayDebuffs then self.player:decayDebuffs() end
    end), "MICRO")

    -- Telegrafa a PROXIMA acao (EnemyHud mostra durante o turno do jogador).
    -- Beat proprio: o icone do proximo golpe aparecendo e informacao, e
    -- aparecer junto com o veneno ticando era parte do borrao.
    CombatBeats.push("enemy.next_intent", beat(function()
        -- Cadaver nao telegrafa o proximo golpe (o HUD chegava a piscar o
        -- intent de um inimigo que acabou de cair pro veneno/espinhos).
        if not self.enemy:isAlive() then return end
        self.enemy:rollIntent(self.player)
    end), "DECAY")

    -- ===== Upkeep do jogador =====
    CombatBeats.push("player.upkeep", beat(function()
        -- Morreu alguem? O rabo do turno para aqui. O gate de gameOver/
        -- isPhaseCleared espera a fila drenar (isBlocking), entao continuar
        -- comprando carta pro cadaver so poluiria a tela antes da transicao.
        if not self.enemy:isAlive() or not self.player:isAlive() then return end
        -- Decrementa buffs do jogador (durations per-turno) e zera o Bloqueio.
        -- E aqui que os ESPINHOS armados no turno passado expiram.
        if self.player.onTurnStart then self.player:onTurnStart() end
        self.player:restoreMana()

        -- BASTIAO tica quando o escudo e MANTIDO (retain_armor age dentro de
        -- Player:onTurnStart — sem isto o joker ficava mudo no momento exato
        -- em que trabalha; auditoria de procs Jul/2026).
        if self.player.retainArmor and (self.player.armor or 0) > 0 then
            for _, joker in ipairs(self.jokerSlots or {}) do
                for _, e in ipairs(joker.effects or {}) do
                    if e.type == "retain_armor" then
                        self.effectSystem:notifyJokerProc(self, joker,
                            "Escudo mantido", "armor")
                        break
                    end
                end
            end
        end
    end), "HANDOFF")

    -- VENENO/QUEIMADURA NO JOGADOR (golpes do kit): perda de vida que ignora
    -- o Bloqueio, no comeco do turno dele, ANTES da compra. Beat proprio — e
    -- dano, e o jogador precisa saber de onde veio. Sem DoT, custa MICRO.
    local playerDot = self.player.getDebuffStacks
        and (self.player:getDebuffStacks("poison") + self.player:getDebuffStacks("burn") > 0
            or self:_intentAppliesDot())
    CombatBeats.push("player.dot", beat(function()
        if not self.enemy:isAlive() or not self.player:isAlive() then return end
        if not self.player.tickDebuffDots then return end
        local poison, burn = self.player:tickDebuffDots()
        local total = (poison or 0) + (burn or 0)
        if total <= 0 then return end
        self.scoreSystem:recordDamageTaken(total)
        local I18n = require("src.i18n.I18n")
        Sfx.playWithVariation("poisonTick", 0.85, 0.15)
        local okCF, CardFeel = pcall(require, "src.systems.CardFeel")
        if okCF then
            CardFeel.burstAtPlayer(((burn or 0) > (poison or 0)) and "fire" or "poison", 0.8)
        end
        local okFT, FloatingText = pcall(require, "src.ui.FloatingText")
        if okFT and love.graphics then
            FloatingText.spawn("-" .. total, 120, love.graphics.getHeight() - 120,
                { color = { 0.45, 0.9, 0.35, 1 }, fontSize = 20 })
        end
    end), playerDot and "DOT" or "MICRO")

    CombatBeats.push("player.draw", beat(function()
        if not self.enemy:isAlive() or not self.player:isAlive() then return end
        self:drawForTurn()
    end), "HANDOFF")

    -- Gatilhos de inicio de turno (regen, Forma Demoniaca, compra extra, motor
    -- de orbes): UM DE CADA VEZ. Antes os 3-4 caiam no mesmo frame e viravam
    -- uma chuva de numeros sem dono.
    do
        local steps = {}
        self.effectSystem:applyTriggerEffects(self, "turn_start", { beatSink = steps })
        for _, st in ipairs(steps) do
            local fn = st.fn
            CombatBeats.push(st.label, beat(function()
                if not self.enemy:isAlive() or not self.player:isAlive() then return end
                fn()
            end), st.hold)
        end
    end

    -- ===== BEAT final: a vez volta pro jogador =====
    CombatBeats.push("turn.player_ready", beat(function()
        self._enemyActing = false
        self.turn = "player"
        -- Rede final do turno: se o inimigo morreu durante o rabo e nada
        -- encenou (fonte nova, ordem inesperada), a morte acontece AQUI — e com
        -- beat, nao num piscar: `extendCurrent` estica este MICRO pro tempo de
        -- a criatura cair. Idempotente via `_deathHandled`.
        self:announceDeathIfPending(nil)
    end), "MICRO")
end

-- Centraliza efeitos colaterais de morte do inimigo (anim + sfx + pausa).
-- Chamado tanto por processCardInCombat (kill via ataque) quanto por enemyTurn
-- (kill via poison DoT). Idempotente: se ja rodou nesta morte, nao duplica.
function Game:_onEnemyDeath()
    if self._deathHandled then return end
    self._deathHandled = true

    local okER, EnemyRenderer = pcall(require, "src.ui.EnemyRenderer")
    if okER and EnemyRenderer.triggerDeath then
        EnemyRenderer.triggerDeath(self.enemy.spriteId)
    end
    if _G.triggerShake then _G.triggerShake(18, 0.4) end
    -- Jiggle Balatro-style empilha energia (decay 5/s) — som mais "vivo" que
    -- random pulse do triggerShake legacy. Compõe naturalmente com o shake
    -- intensity-based pra impacto cumulativo no boss death (Fase 6.4).
    if _G.jiggleScreen then _G.jiggleScreen(1.5) end
    Sfx.play("enemyDeath")
    -- Mesmo numero do beat da morte (Game.DEATH_HOLD): o relogio da cena e o
    -- hold da fila sao a MESMA duracao, uma fonte so. O beat segura o combate;
    -- o relogio segura a troca de tela (espolios E vitoria) — as duas metades
    -- da mesma regra, "a criatura cai antes de acabar".
    self._deathPauseTimer = Game.DEATH_HOLD

    -- F3: fecha a pontuação da batalha (TINTA×SELO); game.score espelha a run.
    self.scoreSystem:finishBattle(self)
    self.score = self.scoreSystem.runScore
    -- Recorde histórico: toast ÚNICO quando a run cruza o bestScore.
    local ProfileStats = require("engine.ProfileStats")
    local best = ProfileStats.get().bestScore or 0
    if best > 0 and self.score > best and not self.scoreSystem.recordBroken then
        self.scoreSystem.recordBroken = true
        self:addMessage(msg("new_record"), "gold")
        Sfx.play("comboTrigger")
    end

    -- F4: conquistas de batalha (turno 1, 1 HP, boss flawless, score, endless).
    AchievementSystem.onBattleWon(self)

    -- Meta-progressão: chefe de ato vencido libera classe/marco NA HORA.
    do
        local run = self.isRunMode and self.runManager and self.runManager.currentRun
        if run and run.currentNode and run.currentNode.type == "boss" then
            UnlockSystem.onBossDefeated(run.actNumber, self)
        end
    end

    -- Aftershock coreografado via EventManager: 2 tremores menores pós-morte
    -- (sensação de corpo caindo). Exemplo canônico de sequência temporal
    -- sem state machine dedicada.
    local EM = _G.EventManager
    if EM and _G.triggerShake then
        EM.after(0.22, function() _G.triggerShake(8, 0.18) end)
        EM.after(0.42, function() _G.triggerShake(4, 0.12) end)
    end

    -- Juice celebratório nos jokers ativos (quando tiverem card:juice_up).
    if EM and self.jokerSlots then
        for i, joker in ipairs(self.jokerSlots) do
            if joker and joker.juice_up then
                EM.after((i - 1) * 0.08, function()
                    joker:juice_up(0.25, 0.08)
                end)
            end
        end
    end
end

function Game:isPhaseCleared()
    return self.enemy.health <= 0
end

-- Constrói lista de sources de ouro pra RoundEvalScreen (Fase 9 — cash out
-- estilo Balatro `evaluate_round`). Cada source tem label + dollars + color.
-- Chamado por main.lua após `_deathPauseTimer` expirar, antes de showCardRewards.
function Game:_buildRoundEvalSources()
    -- require local (padrão do arquivo — Game.lua não tem I18n no topo)
    local I18n = require("src.i18n.I18n")
    local sources = {}

    -- 1) Vitória: recompensa base por derrotar inimigo.
    -- Os rótulos são exibidos na RoundEvalScreen — vão pelo i18n (antes eram
    -- PT cravado e apareciam em português dentro da tela traduzida).
    --
    -- Set/2026: o valor ESCALA POR ATO (Config.Economy.victoryGold) — era $5
    -- fixo, e com a campanha em 6 atos a renda por batalha ficava idêntica no
    -- ato 6 e no ato 1 enquanto todos os preços da loja escalavam. O raciocínio
    -- e os números medidos estão em Config.Economy.
    local act = 1
    if self.isRunMode and self.runManager and self.runManager:hasActiveRun() then
        act = self.runManager.currentRun.actNumber or 1
    end
    table.insert(sources, {
        label = I18n.t("round_eval.src_victory", nil, "Vitoria"),
        dollars = math.max(1, Config.Economy.victoryGold(act) + require(
            "src.systems.RunModifiers").victoryGoldDelta(
            self.isRunMode and self.runManager and self.runManager.currentRun)),
        color = {1, 0.85, 0.30, 1},
    })

    -- 2) HP cheio: bônus se não perdeu nenhum HP na batalha.
    if self.player and self.player.health == self.player.maxHealth then
        table.insert(sources, {
            label = I18n.t("round_eval.src_full_hp", nil, "HP cheio"),
            dollars = Config.Economy.FULL_HP_BONUS,
            color = {0.4, 0.95, 0.5, 1},
        })
    end

    -- 2b) Bônus de RISCO do nó (Out/2026): elite e chefe do ato pagam uma
    -- linha a mais (Config.Economy.nodeBonus) — antes pagavam igual a luta
    -- comum e o mapa prometia um risco que a bolsa não cobria.
    do
        local run = self.isRunMode and self.runManager and self.runManager.currentRun
        local nt = run and run.currentNode and run.currentNode.type
        local bonus = Config.Economy.nodeBonus(nt, act)
        if bonus > 0 then
            table.insert(sources, {
                label = I18n.t(nt == "boss" and "round_eval.src_boss" or "round_eval.src_elite",
                    nil, nt == "boss" and "Chefe" or "Elite"),
                dollars = bonus,
                color = {0.95, 0.55, 0.30, 1},
            })
        end
    end

    -- 3) Juros Balatro ($1 a cada $5, cap $5) — FONTE ÚNICA no
    -- EconomySystem:calculateInterest (a TopBar mostra o mesmo número).
    if self.economySystem then
        local interest = self.economySystem:calculateInterest()
        if interest > 0 then
            table.insert(sources, {
                label = I18n.t("round_eval.src_interest", nil, "Juros (1$ a cada 5$)"),
                dollars = interest,
                color = {0.95, 0.85, 0.30, 1},
            })
        end
    end

    -- 4) Vitórias consecutivas (futuro: reads from EconomySystem.consecutiveWins).
    -- Por ora pulamos.

    return sources
end

function Game:resetHandAndDeck()
    CombatBeats.clear()   -- mesma razao do startGame: batalha nova, fila limpa
    self._enemyActing = false
    -- BATALHA NOVA COMECA NA VEZ DO JOGADOR. Sempre. (Set/2026)
    --
    -- Faltava, e o dono levou o golpe: "teve um turno de batalha que o inimigo
    -- ja chegou me dando dano enquanto andava, antes mesmo de chegar na tela
    -- pra eu jogar minha carta".
    --
    -- Como vazava: `endTurn` poe `turn = "enemy"` e SO ENTAO enfileira o pulso
    -- dos orbes. Quando o pulso (ou veneno, ou espinhos) MATA o inimigo — que
    -- e exatamente como o mago fecha batalha — o portao da cena exige
    -- `enemy:isAlive()` pra chamar `enemyTurn()`. O inimigo ja esta morto,
    -- entao `enemyTurn` nunca roda, e quem devolvia a vez era justamente o
    -- beat final dele. `turn` ficava "enemy" pela recompensa, pelo descanso e
    -- pelo mapa inteiros; no andar seguinte o portao via inimigo VIVO + vez do
    -- inimigo e mandava o bicho novo golpear antes da primeira carta.
    --
    -- Por isso era intermitente: so acontece quando a morte vem do fim do
    -- turno, nunca quando vem das cartas jogadas.
    self.turn = "player"
    self.hand = {}
    self.selectedCards = {}
    self.discard = {} -- limpa descarte entre batalhas

    -- Transient stats sao per-battle: zera strength/dexterity/orbs/buffs/armor.
    if self.player.resetTransientStats then
        self.player:resetTransientStats()
    end

    if self.isRunMode and self.runManager:hasActiveRun() then
        self:synchronizeRunDeck()
    end

    self:shuffleDeck()
    self:promoteInnateCardsToTop()

    for i = 1, Config.Game.INITIAL_HAND_SIZE + self:getShopServiceCount("card_draw_upgrade") do
        if #self.deck > 0 then
            self:drawCard((i - 1) * 0.08)  -- stagger pra cascata visual
        end
    end
end

-- Cap de Bloqueio POR ATO (auditoria Jul/2026): base 30 no A1, +10/ato
-- (A2=40, A3+=50). A bateria de autoplay mostrou o cap fixo de 30 comendo
-- 20-24 turnos de scaling defensivo no A3 (hits inimigos ja passavam de 30).
-- Fonte unica: chamado em startGame e nextPhase (quando o ato pode virar).
function Game:syncArmorCap()
    local act = 1
    if self.isRunMode and self.runManager:hasActiveRun() then
        act = self.runManager.currentRun.actNumber or 1
    end
    local base = Config.Game.PLAYER_MAX_ARMOR or 30
    local per = Config.Game.PLAYER_MAX_ARMOR_PER_ACT or 0
    self.player.maxArmor = base + per * math.max(0, act - 1)
end

-- Espelha no EconomySystem o TETO DE JUROS comprado na loja (relíquia
-- "Cofre"). A fonte da verdade é o ledger de serviços da run — que viaja no
-- save —, e este é o mesmo padrão do syncArmorCap logo acima: a entidade
-- guarda um número simples e o Game o reescreve nos chokepoints de batalha.
--
-- Chamado junto de syncArmorCap (startGame + nextPhase) e logo após a compra.
-- Os dois primeiros são a rede: mesmo que um caminho novo de compra esqueça
-- de sincronizar, o desvio morre no andar seguinte em vez de durar a run.
function Game:syncInterestCap()
    if not self.economySystem or not self.economySystem.setBonusInterestCap then
        return
    end
    local porCompra = (Config.Offers and Config.Offers.INTEREST_CAP_PER_BUY) or 2
    self.economySystem:setBonusInterestCap(
        self:getShopServiceCount("interest_cap") * porCompra)
end

function Game:nextPhase()
    -- Exaurir (balance v2): a carta some da BATALHA e volta na próxima
    -- (StS-style). A remoção permanente da run punia demais — potions e
    -- cartas de uso único viravam lixo de deck (auditoria v2 §3).
    -- O objetivo anti-stall (não reciclar cura no reshuffle) continua
    -- atendido: exauridas não voltam pro discard DENTRO da batalha.
    self._exhaustedThisBattle = {}
    self._deathHandled = false
    self._deathStaged = false
    self._deathPauseTimer = 0
    self._saveDeleted = false
    -- Batalha nova SEMPRE começa no turno do jogador. Se o golpe final veio
    -- do pulso de orbe do fim de turno (ou de um "Encerrar turno" enfileirado
    -- durante a jogada que matou), `turn` ficava "enemy" — e só startGame o
    -- zerava. Resultado: a PRÓXIMA batalha abria com o inimigo agindo
    -- primeiro (revisão de lançamento, Out/2026; trava em test_lifecycle).
    self.turn = "player"
    self._endTurnQueued = false
    self._enemyActing = false

    self.currentPhase = self.currentPhase + 1
    -- F3: score antigo (BASE_SCORE_PER_PHASE) morreu — a batalha já foi
    -- pontuada em _onEnemyDeath via ScoreSystem (TINTA×SELO).
    self.scoreSystem:startBattle()
    -- (A passiva de classe roda DEPOIS do resetHandAndDeck, mais abaixo:
    -- aqui ela era apagada pelo resetTransientStats — o mago ganhava o toast
    -- do Conduíte e abria sem orbe nem Foco em toda luta depois da 1ª.)

    -- F2 gameplay-overhaul: FOLHA ÚNICA de pagamento. O RoundEvalScreen
    -- (cash-out Balatro: vitória + bônus HP + juros) é O pagamento da
    -- batalha. O earnBattleGold daqui era um SEGUNDO salário (~50/batalha
    -- na fase 5, com "streak" falso via currentPhase) que deixava o jogador
    -- rico demais pra loja significar escolha.

    -- RNG do INÍCIO da batalha (Out/2026): o Continuar no meio de uma luta
    -- refaz a luta do começo — e tem que ser a MESMA luta (mesma mão, mesmo
    -- primeiro golpe do inimigo). O save deste andar sai no FIM do nextPhase,
    -- com o embaralho e o sorteio do inimigo já consumidos; sem este retrato,
    -- sair e voltar re-embaralhava a mão inicial (save-scum da abertura).
    if self.isRunMode and self.runManager:hasActiveRun() then
        local st = require("src.systems.Rng").get():getState()
        st.meta = nil -- pity etc. seguem do estado vivo (não volta no tempo)
        self.runManager.currentRun.battleRng = st
    end

    self.player:resetMaxMana()
    -- Mana CHEIA ao entrar na batalha (autoplay A3: quem gastava tudo no
    -- último turno começava a próxima batalha com 0 de mana).
    self.player:restoreMana()
    self:syncArmorCap()
    self:syncInterestCap()
    self:resetHandAndDeck()
    self:applyClassBattleStartPassive()

    -- Stats do inimigo baseadas no ato + node atual (Fase 5 via ActSystem).
    -- Em run mode: usa runManager.currentRun (actNumber, floorInAct, currentNode).
    -- Em classic mode (sem run): fallback para curva linear antiga.
    if self.isRunMode and self.runManager:hasActiveRun() then
        local run = self.runManager.currentRun
        local nodeType = (run.currentNode and run.currentNode.type) or "battle"
        local stats = ActSystem.getEnemyStats(run.actNumber, run.floorInAct, nodeType,
            run.endlessMode and run.floorsInEndless or nil)
        -- Selo do Grimório / maldições do endless multiplicam POR CIMA.
        local RunModifiers = require("src.systems.RunModifiers")
        stats = RunModifiers.enemyStats(run, stats, nodeType)
        -- QUEM luta (Out/2026): o inimigo foi sorteado quando o nó nasceu
        -- (EnemyRoster, stream "enemy") e mora em currentNode.enemyId — o
        -- kit dele (src/data/enemies.lua) traz golpes, vida e dano próprios.
        local EnemyRoster = require("src.systems.EnemyRoster")
        local enemyId = EnemyRoster.resolveNode(run, run.currentNode, nodeType)
        -- Stream "enemy" no instante do spawn (que rola o 1º golpe). O
        -- battleRng não basta: entre ele e o spawn o caminho do Continuar
        -- consome o stream de outro jeito (o inimigo provisório do startGame
        -- rola intent; aqui o resolveNode pode sortear) — e a luta retomada
        -- abria com outro golpe conforme o que rodou antes (test_resume_state
        -- falhava só dentro da suíte).
        run.battleEnemyRng = require("src.systems.Rng").get():getStreamState("enemy")
        self.enemy = EnemyRoster.spawn(Enemy, enemyId, stats, run.actNumber)
        RunModifiers.decorateEnemy(run, self.enemy)
        EnemyRoster.remember(run, enemyId)
        -- (P0.0 Jul/2026: scoreSystem:startBattle + applyClassBattleStartPassive
        -- DUPLICADOS aqui foram removidos — a passiva rodava 2x por batalha em
        -- run mode: mago abria com 2 orbes + o dobro de Foco. A aplicacao
        -- canonica e a incondicional no topo do nextPhase.)
        self.battleTurn = 0
        -- isBoss nunca era setado (só lido) — bosses agora rendem maiores
        self.enemy.isBoss = (nodeType == "boss" or nodeType == "mini_boss")
    else
        local newHealth = Config.Game.ENEMY_BASE_HEALTH + (self.currentPhase - 1) * Config.Game.ENEMY_HEALTH_SCALING
        local newDamage = Config.Game.ENEMY_BASE_DAMAGE + (self.currentPhase - 1) * Config.Game.ENEMY_DAMAGE_SCALING
        self.enemy = Enemy:new(newHealth, newDamage)
        self.battleTurn = 0
    end

    -- Cura intra-ato (modo classic) OU cura inter-ato (run mode, quando floorInAct=1
    -- e actNumber > 1: significa que acabou de cruzar pro novo ato).
    if self.isRunMode and self.runManager:hasActiveRun() then
        local run = self.runManager.currentRun
        if run.floorInAct == 1 and run.actNumber > 1 then
            -- Endless: a cura do CICLO é a do Config.Endless (antes caía na
            -- do ato 6 e curava 40% a cada 8 andares). Selo/maldição reduzem.
            local pct = run.endlessMode and (Config.Endless.healPercent or 0)
                or ActSystem.getInterActHealPercent(run.actNumber - 1)
            pct = (pct or 0) * require("src.systems.RunModifiers").healMul(run, "act")
            if pct and pct > 0 then
                local before = self.player.health
                self.player:heal(math.floor(self.player.maxHealth * pct))
                -- vida cheia: nada curado, nada a dizer
                local heal = self.player.health - before
                if heal > 0 then
                    self:addMessage(msg("act_transition_heal", { value = heal }), "success")
                end
            end
            Sfx.play("actComplete")
        end
    else
        if self.currentPhase % Config.Game.HEALTH_RESTORE_INTERVAL == 0 then
            self.player.health = math.min(self.player.health + Config.Game.PLAYER_HEALTH_RESTORE, self.player.maxHealth)
            self:addMessage(msg("health_restored", { value = Config.Game.PLAYER_HEALTH_RESTORE }), "success")
        end
    end

    -- CHECKPOINT (F1 do UI Overhaul): persiste a run a cada andar novo —
    -- fecha o gap "save/load existe mas sem botão Continuar".
    -- Estágio "battle": este save (vida do INÍCIO da luta) é o ponto de
    -- retomada; "Salvar e sair" no meio da luta não o sobrescreve (main.lua).
    if self.isRunMode and self.runManager:hasActiveRun() then
        self.runManager.currentRun.stage = "battle"
        self.runManager.currentRun.stageEventId = nil
    end
    self:checkpointRun()
end

-- ============================================================================
-- Continuar (F1 do UI Overhaul): save em checkpoint + resume da run salva
-- ============================================================================

-- Sincroniza HP/ouro do jogador pra dentro da run (antes de persistir).
function Game:syncRunPlayerState()
    local run = self.runManager and self.runManager.currentRun
    if not run then return end
    run.playerState = run.playerState or {}
    if self.player then
        run.playerState.maxHealth = self.player.maxHealth
        run.playerState.currentHealth = self.player.health
        -- Mana máxima PERMANENTE da run (eventos dão +1 em baseMaxMana).
        -- Sem persistir, sair/entrar resetava o ganho (bug do dono,
        -- Set/2026). O bônus de BATALHA (Cristal de Mana) fica de fora
        -- por design — só o base viaja.
        run.playerState.baseMaxMana = self.player.baseMaxMana
    end
    -- Pontuação da run (mesma classe de bug: acumulava e ZERAVA no
    -- Continuar — o recorde do perfil sobrevivia, a run não).
    if self.scoreSystem then
        run.playerState.runScore = self.scoreSystem.runScore or 0
        -- "RECORDE!" dourado pelo resto da run e o recibo da última batalha
        -- (o cash out retomado mostrava a pontuação vazia).
        run.playerState.scoreRecordBroken = self.scoreSystem.recordBroken or nil
        run.playerState.lastBattleScore = self.scoreSystem.lastBattle
    end
    if self.economySystem then
        run.playerState.gold = self.economySystem.currentGold
        run.playerState.goldEarned = self.economySystem.totalGoldEarned
        run.playerState.goldSpent = self.economySystem.goldSpent
    end
end

-- Checkpoint: sincroniza e salva em disco (no-op fora do run mode).
function Game:checkpointRun()
    if not self.isRunMode then return end
    if not (self.runManager and self.runManager:hasActiveRun()) then return end
    -- Run que ACABOU não se salva. Morto (ou já vencido) e "Salvar e sair"
    -- gravava currentHealth 0 por cima do save que a morte tinha apagado — e o
    -- resumeRun, com math.max(1, ...), RESSUSCITAVA o jogador com 1 de vida.
    if (self.player and not self.player:isAlive())
        or self.gameState == "gameOver" or self.gameState == "victory" then
        return
    end
    self:syncRunPlayerState()
    self.runManager:saveRun()
    -- Contadores do perfil (cartas jogadas, vistas/descobertas) só iam pro
    -- disco no fim de batalha/conquista: "Salvar e sair" os perdia.
    require("engine.ProfileStats").flush()
end

-- Retoma uma run carregada (chamar DEPOIS de runManager:loadRun()):
-- remonta o jogo no andar salvo com deck/jokers/HP/ouro/inimigo corretos.
function Game:resumeRun()
    local run = self.runManager and self.runManager.currentRun
    if not run then return false end
    self.isRunMode = true
    self.selectedClass = run.classId

    -- RNG: o setup abaixo (embaralho do startGame, sorteio do primeiro golpe
    -- do inimigo) CONSOME os streams misc/enemy. Retomando DENTRO da luta, o
    -- RNG volta ao início dela (battleRng, gravado no nextPhase) e a luta sai
    -- idêntica. Em qualquer outro estágio o inimigo é descartado e o RNG volta
    -- ao estado salvo — sair e voltar na loja não pode mudar a próxima luta.
    local Rng = require("src.systems.Rng")
    local savedRng = Rng.get():getState()
    local inBattle = (run.stage == nil or run.stage == "battle")
        and not (run.pendingNodes and #run.pendingNodes > 0)
    if inBattle and run.battleRng then
        local r = Rng.fromState(run.battleRng)
        r.meta = savedRng.meta
        Rng.setActive(r)
    end

    -- startGame monta o deck da run (initializeDeck usa run.currentDeck) e
    -- os jokers (_syncJokersFromRun) — mas reseta player/economia/inimigo.
    self:startGame()

    -- Restaura o estado salvo por cima do reset:
    local ps = run.playerState
    if ps and ps.maxHealth then
        self.player.maxHealth = ps.maxHealth
        self.player.health = math.max(1,
            math.min(ps.currentHealth or ps.maxHealth, ps.maxHealth))
    end
    if ps and ps.gold then
        self.economySystem.currentGold = ps.gold
    end
    -- Mana máxima PERMANENTE (eventos +1): sem restaurar, o Continuar
    -- voltava pro base da classe (bug do dono, Set/2026). Saves antigos
    -- sem o campo caem no default do Player (compat).
    if ps and ps.baseMaxMana then
        self.player.baseMaxMana = ps.baseMaxMana
        self.player.maxMana = ps.baseMaxMana
        self.player.mana = self.player.maxMana
    end
    -- Pontuação da run continua de onde parou (startGame zera o
    -- ScoreSystem — restaurar por cima).
    if ps and ps.runScore and self.scoreSystem then
        self.scoreSystem.runScore = ps.runScore
    end
    -- BUG do dono (Out/2026, "voltei e meus PONTOS zeraram"): a TopBar, a
    -- tela final e o recorde do perfil leem `game.score`, que o startGame
    -- zera e só o fim da PRÓXIMA batalha reescrevia. Morrer antes disso
    -- gravava 0 como pontuação da run.
    self.score = (self.scoreSystem and self.scoreSystem.runScore) or 0
    if ps and self.scoreSystem then
        self.scoreSystem.recordBroken = ps.scoreRecordBroken and true or false
        self.scoreSystem.lastBattle = ps.lastBattleScore
    end
    if ps and self.economySystem then
        self.economySystem.totalGoldEarned = ps.goldEarned or self.economySystem.totalGoldEarned
        self.economySystem.goldSpent = ps.goldSpent or self.economySystem.goldSpent
    end

    -- Inimigo do andar salvo (mesma receita do nextPhase run-mode):
    local nodeType = (run.currentNode and run.currentNode.type) or "battle"
    local stats = ActSystem.getEnemyStats(run.actNumber, run.floorInAct, nodeType,
        run.endlessMode and run.floorsInEndless or nil)
    local RunModifiers = require("src.systems.RunModifiers")
    stats = RunModifiers.enemyStats(run, stats, nodeType)
    -- O MESMO inimigo do nó salvo (currentNode.enemyId) — o Continuar não
    -- re-sorteia (EnemyRoster).
    local EnemyRoster = require("src.systems.EnemyRoster")
    local nodeEnemyId = run.currentNode and run.currentNode.enemyId
    local enemyId = EnemyRoster.resolveNode(run, run.currentNode, nodeType)
    if inBattle and run.battleEnemyRng then
        Rng.get():setStreamState("enemy", run.battleEnemyRng)
    end
    self.enemy = EnemyRoster.spawn(Enemy, enemyId, stats, run.actNumber)
    RunModifiers.decorateEnemy(run, self.enemy)
    self.battleTurn = 0
    -- (startBattle + passiva de classe já rodaram no startGame, com a classe
    -- e o ato da run carregada. Rodar de novo aqui dava ao mago DOIS orbes e
    -- Foco em dobro em toda luta retomada.)
    self.enemy.isBoss = (nodeType == "boss" or nodeType == "mini_boss")
    if not inBattle then
        local r = Rng.fromState(savedRng)
        Rng.setActive(r)
        -- O inimigo provisório não pode deixar rastro no nó (resolveNode
        -- carimbava um enemyId numa LOJA/descanso retomados).
        if run.currentNode then run.currentNode.enemyId = nodeEnemyId end
    end
    return true
end

function Game:addMessage(text, type)
    if self.messageSystem then
        self.messageSystem:addMessage(text, type)
    end
    print(text) -- Mantém no console também
end

function Game:checkGameOver()
    if not self.player:isAlive() then
        self.gameState = "gameOver"
        -- morte encerra a run: apaga o save (Continuar não ressuscita)
        if self.isRunMode and self.runManager and not self._saveDeleted then
            self._saveDeleted = true
            self.runManager:deleteSave()
            -- Perfil: registra a derrota UMA vez (mesmo guard do save).
            local run = self.runManager.currentRun
            local PS = require("engine.ProfileStats")
            if run and run.campaignWon then
                -- Morte no ENDLESS: a vitória já foi contada ao matar o
                -- chefe final. Aqui só entra o XP dos andares extras e o
                -- recorde — contar uma derrota faria a mesma run valer
                -- vitória E derrota no perfil (runs = wins + losses).
                self:_recordEndlessEnd()
            else
                -- Meta-progressão ANTES do recordDefeat (que mexe no perfil).
                self.unlockResult = UnlockSystem.onRunEnded(self:_unlockSummary(false))
                PS.recordDefeat(run and run.actNumber, run and run.floorInAct)
                PS.updateBestScore(self.score)
            end
        end
        return true
    end
    return false
end

-- Abandono confirmado no pause: conta como fim de run (StS: abandonar = morrer).
-- Rende o XP de maestria do que a run andou e registra a derrota no perfil —
-- sem isso, abandonar uma run longa jogava fora todo o progresso de classe.
-- Mesmo guard do checkGameOver: nunca registra duas vezes.
function Game:abandonRun()
    if not self.runManager then return end
    if not self.isRunMode then self.runManager:deleteSave(); return end
    if self._saveDeleted or self._victoryRecorded then
        if self.runManager.deleteSave then self.runManager:deleteSave() end
        return
    end
    self._saveDeleted = true
    local run = self.runManager.currentRun
    if run and run.campaignWon then
        self:_recordEndlessEnd()
    elseif run then
        local PS = require("engine.ProfileStats")
        self.unlockResult = UnlockSystem.onRunEnded(self:_unlockSummary(false))
        PS.recordDefeat(run.actNumber, run.floorInAct)
    end
    self.runManager:deleteSave()
end

-- Fim de uma run que JÁ VENCEU a campanha e seguiu no endless (morte ou
-- abandono). A vitória foi registrada uma vez em checkVictory; aqui só o XP
-- dos andares extras (computeRunXP: endless sem vitória = só o excedente) e
-- o recorde de pontuação.
function Game:_recordEndlessEnd()
    local PS = require("engine.ProfileStats")
    self.unlockResult = UnlockSystem.onRunEnded(self:_unlockSummary(false))
    PS.updateBestScore(self.score)
end

-- "Continuar no Endless" da tela de vitória (StS/Balatro): a run segue viva
-- depois do chefe final. SÓ vale depois de a vitória estar registrada
-- (defect_doctrine 14: endlessMode desliga checkVictory — ligá-lo antes da
-- vitória contar deixaria o jogo invencível). Não avança andar nem abre mapa:
-- quem chama (main.lua) segue pro cash out → recompensa → encruzilhada, e é o
-- advanceFloorInAct que leva a run pro primeiro andar do endless.
function Game:enterEndless()
    if not (self.isRunMode and self.runManager and self.runManager:hasActiveRun()) then
        return false
    end
    local run = self.runManager.currentRun
    if not run.campaignWon or run.endlessMode then return false end
    run.endlessMode = true
    run.floorsInEndless = 0
    -- A run voltou a ser jogável: checkpointRun recusa gameState "victory".
    self.gameState = "playing"
    self._victoryRecorded = false
    self.unlockResult = nil
    return true
end

-- Relógio da run (resumo da tela final). Só conta com a run em jogo: menu,
-- seleção de classe e as telas finais não são tempo de jogo.
local CLOCK_IDLE = { menu = true, classSelection = true, gameOver = true,
                     victory = true }
function Game:tickRunClock(dt, state)
    if not self.isRunMode or CLOCK_IDLE[state or ""] then return end
    local run = self.runManager and self.runManager.currentRun
    if not run or self.gameState ~= "playing" then return end
    run.playSeconds = (run.playSeconds or 0) + (dt or 0)
end

-- Resumo da run pro UnlockSystem.onRunEnded (XP de maestria + marcos).
function Game:_unlockSummary(victory)
    local run = self.runManager and self.runManager.currentRun or {}
    return {
        classId = run.classId or self.selectedClass,
        victory = victory and true or false,
        actNumber = run.actNumber or 1,
        floorInAct = run.floorInAct or 1,
        endlessMode = run.endlessMode or false,
        floorsInEndless = run.floorsInEndless or 0,
        score = self.score or 0,
        seal = run.seal or 0,
    }
end

function Game:checkVictory()
    -- Em run mode: vitoria so acontece ao matar boss do ato final (nao endless).
    -- O endless so liga DEPOIS daqui, pela escolha do jogador na tela de
    -- vitoria (Game:enterEndless); checkVictory so retorna true na primeira
    -- vez que o player bate o boss do ultimo ato.
    if self.isRunMode and self.runManager:hasActiveRun() then
        local run = self.runManager.currentRun
        if run.endlessMode then return false end
        local totalActs = Config.TotalActs or 3
        local MapManager = require("src.systems.MapManager")
        if run.actNumber >= totalActs
            and run.floorInAct >= MapManager.FLOORS_PER_ACT
            and run.currentNode and run.currentNode.type == "boss"
            and self:isPhaseCleared() then
            self.gameState = "victory"
            -- Perfil: registra vitória UMA vez por run.
            if not self._victoryRecorded then
                self._victoryRecorded = true
                -- Marca NA RUN (viaja no save): se ela seguir pro endless,
                -- morte/abandono lá não contam outra vitória nem uma derrota.
                run.campaignWon = true
                local PS = require("engine.ProfileStats")
                -- Meta-progressão ANTES do recordVictory (que mexe no perfil).
                self.unlockResult = UnlockSystem.onRunEnded(self:_unlockSummary(true))
                PS.recordVictory(run.actNumber, run.floorInAct, run.classId or self.selectedClass)
                PS.updateBestScore(self.score)
                -- Vitória ENCERRA a run em disco (a derrota já fazia isso no
                -- checkGameOver). Sem isto o menu seguia oferecendo
                -- "Continuar" e devolvia o jogador ao chefe final — e cada
                -- replay contava outra vitória no perfil. "Continuar no
                -- Endless" volta a salvar (Game:enterEndless + encruzilhada).
                if self.runManager.deleteSave then self.runManager:deleteSave() end
                -- F4: conquistas de vitória (deck, classes, restrições).
                AchievementSystem.onVictory(self)
            end
            return true
        end
        return false
    end
    -- Fallback classic
    if self.currentPhase > Config.Game.VICTORY_PHASES then
        self.gameState = "victory"
        return true
    end
    return false
end

-- Toca som de seleção de carta. Wrapper thin via Sfx.play (AudioSystem é no-op
-- se áudio não disponível).
function Game:playCardSelectSound()
    -- Pitch random: usuário clica em várias cartas em sequência ao montar play,
    -- sem variação soa staccato robótico.
    Sfx.playWithVariation("cardSelect", 1.0, 0.12)
end

-- Alterna o menu de configurações. O handler real é injetado por main.lua.
function Game:toggleMenu()
    if self.onToggleSettings then
        self.onToggleSettings()
    else
        self:addMessage(msg("settings_unavailable"), "warning")
    end
end

return Game
