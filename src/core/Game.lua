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
local ScoreSystem = require("src.systems.ScoreSystem")
local AchievementSystem = require("src.systems.AchievementSystem")
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
    for i = #self.deck, 2, -1 do
        local j = love.math.random(i)
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
    self.economySystem.currentGold = 10

    self:syncArmorCap()
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
    for i = 1, Config.Game.INITIAL_HAND_SIZE do
        self:drawCard((i - 1) * 0.08)
    end

    self:addMessage(msg("game_start"), "success")
    self:addMessage(msg("starting_gold", { value = self.economySystem.currentGold }), "info")
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
        self:addMessage(msg("reshuffled"), "info")
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
    -- P2.3 (Jul/2026, rebalance v2): thorn de JOKER dispara 1x/turno por
    -- joker — nova janela a cada turno do jogador (ver EffectSystem
    -- processTriggerEffect on_defend_damage).
    self._jokerThornFiredThisTurn = {}
    local baseDraw = Config.Game.CARDS_PER_TURN or 5
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
    self:addMessage(msg("deck_changed",
        { name = self.deckManager:getDeckInfo(deckId).name or deckId }), "info")
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
function Game:startNewRun(classId)
    self.isRunMode = true
    self.selectedClass = classId
    
    local runData = self.runManager:startNewRun(classId)
    self:addMessage(msg("run_started", { name = runData.className }), "success")

    -- Perfil persistente (menu mostra vitórias/melhor progresso).
    require("engine.ProfileStats").recordRunStart(classId)

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

    -- F4: registro de descoberta (Bibliotecário).
    AchievementSystem.onCardSeen(self, cardId)

    -- Bifurca jokers: nunca entram no deck. Vão direto para jokerSlots
    -- + currentRun.jokers (padrão Balatro G.jokers).
    local cardData = self.deckManager.cardDatabase:getCard(cardId)
    if cardData and cardData.type == "joker" then
        return self:addJokerToRun(cardId, meta)
    end

    local success = self.runManager:addCardToDeck(cardId, meta)
    
    if success then
        local cardData = self.deckManager.cardDatabase:getCard(cardId)
        local cardName = cardData and cardData.name or cardId
        self:addMessage(msg("card_added", { name = cardName }), "success")
        
        -- Mostra estatísticas do deck atualizado
        local deckStats = self.runManager:getCurrentRunStats()
        if deckStats then
            self:addMessage(msg("deck_size", { value = deckStats.deckSize }), "info")
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
        self:addMessage(msg("joker_activated", { name = cardData.name or cardId }), "success")
        Sfx.play("jokerActivate")
    else
        self:addMessage(msg("joker_benched",
            { name = cardData.name or cardId }), "info")
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
        if self.runManager.saveRun then self.runManager:saveRun() end
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
    
    local success = self.runManager:removeCardFromDeck(cardId)
    if success then
        local cardData = self.deckManager.cardDatabase:getCard(cardId)
        local cardName = cardData and cardData.name or cardId
        self:addMessage(msg("card_removed", { name = cardName }), "info")
    end
    
    return success
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
-- Warrior "Ímpeto":  2+ ataques no mesmo turno → +1 Força (na batalha).
-- Mage "Conduíte":   começa toda batalha com orbe de Raio (2) canalizado.
-- Rogue "Toxinas":   o 1º ataque de cada turno aplica 1 de Veneno (2t).
-- Toda ativação gera toast — nada acontece invisível (lei do projeto).

function Game:applyClassBattleStartPassive()
    self._toxinAppliedThisTurn = false
    -- P2.3: janela nova de thorn-de-joker no comeco de cada batalha.
    self._jokerThornFiredThisTurn = {}
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
            self.player:addBuff("focus", 99, 2)
        end
        self:addMessage(msg("passive_conduit"), "info")
        if love.timer then self._passiveFlashT = love.timer.getTime() end
    end
end

function Game:applyClassTurnPassives(turnContext)
    if self.selectedClass ~= "warrior" then return end
    -- multi-jogada: soma ataques de TODAS as jogadas do turno
    local attacks = self._attacksThisTurn or 0
    for _, c in ipairs(turnContext.allSelectedCards or {}) do
        if (c.attack or 0) > 0 then attacks = attacks + 1 end
    end
    self._attacksThisTurn = attacks
    if attacks >= 2 and not self._impetusFiredThisTurn then
        self._impetusFiredThisTurn = true
        self.player:gainStrength(1)
        self:addMessage(msg("passive_momentum"), "success")
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

-- ===== Editions (Fase 3.2) =====
-- Aplica modifiers de edition no valor já calculado. Foil é flat; Holo/Polychrome
-- são multiplicativos; Negative não muda o valor (o efeito é +1 slot de joker,
-- aplicado em recomputeMaxJokerSlots).
local EDITION_FLAT = { foil = 5 }
local EDITION_MULT = { holo = 1.2, polychrome = 1.5 }

local function applyEditionToValue(value, card)
    if not card or not card.edition then return value end
    local flat = EDITION_FLAT[card.edition]
    if flat then value = value + flat end
    local mult = EDITION_MULT[card.edition]
    if mult then value = value * mult end
    return value
end

-- ===== Seals (Fase 3.3) =====
-- Red: ×2 valor (retrigger via mult). Outros são side-effect post-play.
local SEAL_VALUE_MULT = { Red = 2.0 }

local function applySealToValue(value, card)
    if not card or not card.seal then return value end
    local mult = SEAL_VALUE_MULT[card.seal]
    if mult then return value * mult end
    return value
end

-- Conta cartas Negative no deck atual e ajusta maxJokerSlots = base + N.
-- Chamar após startGame, addCardToRun, e qualquer mudança de deck.
function Game:recomputeMaxJokerSlots()
    local base = Config.Game.MAX_JOKER_SLOTS or 3
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

    -- Pipeline unificado attack/defense: effects → stat → combo → jokers → edition → seal.
    local function computeCardValue(baseValue, statBonus)
        local v = self.effectSystem:applyCardEffects(self, card, baseValue)
        v = v + (statBonus or 0)
        v = ComboSystem.applyToCardValue(card, v, turnContext)
        -- Game feel v1: applyJokerEffects também devolve os PROCS (quem
        -- contribuiu com o quê) — o CombatSequence tica os jokers em sequência.
        local procs
        v, procs = self:applyJokerEffects(card, v, turnContext)
        result.jokerProcs = procs
        v = applyEditionToValue(v, card)
        v = applySealToValue(v, card)
        return math.floor(v)
    end

    -- Auditoria Jul/2026: strength_scaling/dexterity_scaling deixaram de ser
    -- flag-only — a carta com a flag conta o stat em DOBRO (identidade real da
    -- Lamina Pesada/Medalhao Estelar; a desc "Escala com Forca" era promessa
    -- vazia: toda carta ja soma o stat 1x). O DOBRO acontece AQUI (fonte unica
    -- do statBonus) — nao reintroduzir soma no EffectSystem.
    local function scaledStat(stat, scalingType)
        local s = stat or 0
        if s == 0 or not card.effects then return s end
        for _, e in ipairs(card.effects) do
            if e.type == scalingType then return s * 2 end
        end
        return s
    end

    -- Side-effects de seal (não envolvem valor da carta): ouro, orbs, draw extra.
    local function applySealSideEffects()
        if not card.seal then return end
        CombatBeats.step(sink, "seal." .. tostring(card.seal), function()
        if card.seal == "Gold" then
            if self.economySystem and self.economySystem.earnGold then
                self.economySystem:earnGold(3, "seal_gold")
                self:addMessage(msg("gold_seal", { value = 3 }), "info")
            end
        elseif card.seal == "Purple" then
            if self.player and self.player.addOrb then
                self.player:addOrb({ type = "lightning", value = 1 })
                self:addMessage(msg("purple_seal"), "info")
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
                self:addMessage(msg("exhausted", { name = card.name or card.id }), "warning")
                Sfx.play("cardExhaust")
            end
            if card.type ~= "joker" and not card.exhaust then
                table.insert(self.discard, card)
            end
            return result
        end

        local damage = computeCardValue(card.attack,
            scaledStat(self.player.strength, "strength_scaling"))

        self.enemy:takeDamage(damage)

        -- Passiva rogue "Toxinas": 1º ataque do turno aplica 1 de Veneno.
        -- Debuff no inimigo = mudanca de ESTADO: instante proprio, depois do
        -- dano (pedido do dono — "esperar ele receber o buff ou debuff").
        if self.selectedClass == "rogue" and not self._toxinAppliedThisTurn
            and self.enemy:isAlive() then
            self._toxinAppliedThisTurn = true
            CombatBeats.step(sink, "passive.toxins", function()
                self.enemy:addStatusEffect({ name = "poison", stacks = 1, duration = 2 })
                self:addMessage(msg("passive_toxins"), "info")
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
        self:addMessage(msg("damage_dealt", { value = damage }), "success")

    elseif card.type == "defense" then
        local defense = computeCardValue(card.defense,
            scaledStat(self.player.dexterity, "dexterity_scaling"))

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
        self:addMessage(msg("block_gained", { value = defense }), "info")
        
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
        self:addMessage(msg("effect_played", { name = card.name }), "success")

        result.effect = true
    end

    if turnContext then
        table.insert(turnContext.cardsProcessed, card)
    end

    -- Exhaust: pula o descarte (Slay-style) E agenda remocao permanente
    -- da run ao final da batalha. Tratamos aqui antes do push pro discard.
    if card.exhaust and card.id then
        table.insert(self._exhaustedThisBattle, card.id)
        self:addMessage(msg("exhausted", { name = card.name or card.id }), "warning")
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
    local discarded = 0
    for _, card in ipairs(self.hand) do
        if card.retain then
            table.insert(kept, card)
        else
            table.insert(self.discard, card)
            discarded = discarded + 1
        end
    end
    self.hand = kept
    if discarded > 0 then
        self:addMessage(msg("discarded", { value = discarded }), "info")
    end
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
        self:addMessage(I18n.t("messages.enemy_enraged", { value = 50 },
            "Ferido! O inimigo passa a causar {value}% mais dano"), "warning")
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

-- PONTE UNICA DO POS-DANO: tudo que um dano ao inimigo pode ter causado e
-- encenado aqui, em ordem — primeiro a MORTE (se matou, nada mais importa),
-- depois o ENFURECIDO. Chamada depois de cada dano, de qualquer fonte.
function Game:settleEnemyDamage(sink)
    local died = self:announceDeathIfPending(sink)
    local raged = self:_announceEnrageIfPending(sink)
    return died or raged
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
        local moveName = I18n.t("enemy_moves." .. intent, nil, "")
        if moveName ~= "" then
            float(moveName, { kind = "movename", hold = 0.55, lift = 26 })
        end
    end), "TELEGRAPH")

    -- ===== BEAT: A ACAO =====
    local struck = false   -- o golpe chegou a acontecer? (governa os espinhos)

    if intent == "defend" then
        CombatBeats.push("enemy.defend", beat(function()
            local armorGain = self.enemy:getDefendAmount()
            self.enemy:addArmor(armorGain)
            Sfx.play("armorSound")
            self:addMessage(msg("enemy_defends", { value = armorGain }), "info")
            if ER and ER.triggerDefend then ER.triggerDefend() end
            -- Game feel v1: o escudo MATERIALIZA no corpo dele (burst azul-aco).
            local okCF, CardFeel = pcall(require, "src.systems.CardFeel")
            if okCF then CardFeel.burstAtEnemy("armor", 0.9) end
            float("+" .. armorGain, { kind = "armor", fontSize = 20 })
        end), "ENEMY_ACT")

    elseif intent == "buff" then
        CombatBeats.push("enemy.buff", beat(function()
            self.enemy.baseDamage = self.enemy.baseDamage + 2
            self.enemy.damage = self.enemy.damage + 2
            -- Game feel v1: buff tem RUGIDO proprio (antes reusava enemyAttack
            -- grave — soava como golpe, confundia) + aura vermelha subindo.
            Sfx.playWithVariation("enemyBuffRoar", 1.0, 0.06)
            self:addMessage(msg("enemy_enrages", { value = 2 }), "warning")
            if self.enemy.juice_up then self.enemy:juice_up(0.4, 0.1) end
            if ER and ER.triggerBuff then ER.triggerBuff() end
            local okCF, CardFeel = pcall(require, "src.systems.CardFeel")
            if okCF then CardFeel.burstAtEnemy("buff", 1.1) end
            local I18n = require("src.i18n.I18n")
            float(I18n.t("enemy_moves.buff_gain", nil, "+2"),
                { kind = "damage", fontSize = 18 })
        end), "STATUS")

    else
        -- attack | strong — o inimigo INVESTE fisicamente e o dano e aplicado
        -- NO IMPACTO da investida (apex), nao num corte seco. O beat nao e por
        -- TEMPO: ele espera o apex acontecer (pushUntil), senao o resto do
        -- turno rodava por cima de um golpe ainda no ar — foi o "bug do
        -- escudo" do playtest Jul/2026.
        local landed = false
        local function applyHit(damage)
            -- Pitch escalado pela magnitude (Balatro sound_manager).
            local atkPitch = math.max(0.7, math.min(1.05, 1.1 - damage * 0.012))
            Sfx.playWithVariation("enemyAttack", atkPitch, 0.08)
            local hpBefore = self.player.health
            self.player:takeDamage(damage)
            -- Detector do piloto (Jul/2026): registrar o dano BRUTO fazia golpe
            -- 100% bloqueado matar o bonus flawless do score e das conquistas.
            -- Conta so o que FUROU o escudo.
            local effective = hpBefore - self.player.health
            self.scoreSystem:recordDamageTaken(effective)
            self:addMessage(msg("enemy_hit", { value = damage }), "warning")
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

        CombatBeats.pushUntil("enemy.attack", beat(function()
            local damage = self.enemy:performAttack()
            if intent == "strong" and damage > 0 then
                damage = math.floor(damage * 1.6)
            end
            if damage <= 0 then
                landed = true
                return
            end
            struck = true
            if ER and ER.triggerAttack then
                ER.triggerAttack(intent, function()
                    applyHit(damage)
                    landed = true
                end)
            else
                applyHit(damage)
                landed = true
            end
        end), function() return landed end, 2.5, "HIT_SETTLE")

        -- ===== BEAT: ESPINHOS =====
        -- Contrato Set/2026: a carta ARMA o buff "thorn"; o REFLEXO acontece
        -- aqui, quando o inimigo ataca — causa e efeito em instantes separados.
        -- O beat so e empurrado se ha espinhos armados AGORA (a carta ja foi
        -- jogada no turno do jogador); o corpo confere se o golpe saiu mesmo.
        if EffectSystem.thornStacks(self) > 0 then
            CombatBeats.push("player.thorn_reflect", beat(function()
                if not struck then return end
                self.effectSystem:fireThornReflect(self)
                -- O reflexo pode ter cruzado os 30%: o anuncio e aqui mesmo.
                self:announceEnrageIfPending(nil)
            end), "REFLECT")
        end
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
            self:addMessage(msg("poison_tick", { value = poisonDmg }), "success")
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

    -- Telegrafa a PROXIMA acao (EnemyHud mostra durante o turno do jogador).
    -- Beat proprio: o icone do proximo golpe aparecendo e informacao, e
    -- aparecer junto com o veneno ticando era parte do borrao.
    CombatBeats.push("enemy.next_intent", beat(function()
        -- Cadaver nao telegrafa o proximo golpe (o HUD chegava a piscar o
        -- intent de um inimigo que acabou de cair pro veneno/espinhos).
        if not self.enemy:isAlive() then return end
        self.enemy:rollIntent()
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
        self:addMessage(msg("new_record"), "success")
        Sfx.play("comboTrigger")
    end

    -- F4: conquistas de batalha (turno 1, 1 HP, boss flawless, score, endless).
    AchievementSystem.onBattleWon(self)

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
    table.insert(sources, {
        label = I18n.t("round_eval.src_victory", nil, "Vitoria"),
        dollars = 5,
        color = {1, 0.85, 0.30, 1},
    })

    -- 2) HP cheio: bônus se não perdeu nenhum HP na batalha.
    if self.player and self.player.health == self.player.maxHealth then
        table.insert(sources, {
            label = I18n.t("round_eval.src_full_hp", nil, "HP cheio"),
            dollars = 3,
            color = {0.4, 0.95, 0.5, 1},
        })
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

    for i = 1, Config.Game.INITIAL_HAND_SIZE do
        if #self.deck > 0 then
            self:drawCard((i - 1) * 0.08)  -- stagger pra cascata visual
        end
    end

    self:addMessage(msg("hand_reset"), "info")
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

    self.currentPhase = self.currentPhase + 1
    -- F3: score antigo (BASE_SCORE_PER_PHASE) morreu — a batalha já foi
    -- pontuada em _onEnemyDeath via ScoreSystem (TINTA×SELO).
    self.scoreSystem:startBattle()
    self:applyClassBattleStartPassive()

    -- F2 gameplay-overhaul: FOLHA ÚNICA de pagamento. O RoundEvalScreen
    -- (cash-out Balatro: vitória + bônus HP + juros) é O pagamento da
    -- batalha. O earnBattleGold daqui era um SEGUNDO salário (~50/batalha
    -- na fase 5, com "streak" falso via currentPhase) que deixava o jogador
    -- rico demais pra loja significar escolha.

    self.player:resetMaxMana()
    -- Mana CHEIA ao entrar na batalha (autoplay A3: quem gastava tudo no
    -- último turno começava a próxima batalha com 0 de mana).
    self.player:restoreMana()
    self:syncArmorCap()
    self:resetHandAndDeck()

    -- Stats do inimigo baseadas no ato + node atual (Fase 5 via ActSystem).
    -- Em run mode: usa runManager.currentRun (actNumber, floorInAct, currentNode).
    -- Em classic mode (sem run): fallback para curva linear antiga.
    if self.isRunMode and self.runManager:hasActiveRun() then
        local run = self.runManager.currentRun
        local nodeType = (run.currentNode and run.currentNode.type) or "battle"
        local stats = ActSystem.getEnemyStats(run.actNumber, run.floorInAct, nodeType)
        self.enemy = Enemy:new(stats.health, stats.damage)
        -- (P0.0 Jul/2026: scoreSystem:startBattle + applyClassBattleStartPassive
        -- DUPLICADOS aqui foram removidos — a passiva rodava 2x por batalha em
        -- run mode: mago abria com 2 orbes + o dobro de Foco. A aplicacao
        -- canonica e a incondicional no topo do nextPhase.)
        self.battleTurn = 0
        -- Sprite do inimigo: roster por ato × tipo de node (v5).
        -- Endless: bioma 4+ a cada 8 andares (mesma fórmula do
        -- GameplayScene/WorldRoad — monstro casa com o cenário).
        local spriteAct = run.actNumber
        if run.endlessMode then
            spriteAct = 4 + math.floor(math.max(0, (run.currentFloor or 25) - 25) / 8)
        end
        local EnemyRenderer = require("src.ui.EnemyRenderer")
        self.enemy.spriteId = EnemyRenderer.resolveSpriteId(spriteAct, nodeType)
        -- isBoss nunca era setado (só lido) — bosses agora rendem maiores
        self.enemy.isBoss = (nodeType == "boss" or nodeType == "mini_boss")
        -- Log com nome do ato
        self:addMessage(ActSystem.getActName(run.actNumber, run.floorInAct)
            .. " — andar " .. run.floorInAct .. " (" .. nodeType .. ")", "info")
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
            local pct = ActSystem.getInterActHealPercent(run.actNumber - 1)
            if pct and pct > 0 then
                local heal = math.floor(self.player.maxHealth * pct)
                self.player:heal(heal)
                self:addMessage(msg("act_transition_heal", { value = heal }), "success")
            end
            Sfx.play("actComplete")
        end
    else
        if self.currentPhase % Config.Game.HEALTH_RESTORE_INTERVAL == 0 then
            self.player.health = math.min(self.player.health + Config.Game.PLAYER_HEALTH_RESTORE, self.player.maxHealth)
            self:addMessage(msg("health_restored", { value = Config.Game.PLAYER_HEALTH_RESTORE }), "success")
        end
    end

    self:addMessage(msg("phase_started", { value = self.currentPhase }), "info")

    -- CHECKPOINT (F1 do UI Overhaul): persiste a run a cada andar novo —
    -- fecha o gap "save/load existe mas sem botão Continuar".
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
    end
    if self.economySystem then
        run.playerState.gold = self.economySystem.currentGold
    end
end

-- Checkpoint: sincroniza e salva em disco (no-op fora do run mode).
function Game:checkpointRun()
    if not self.isRunMode then return end
    if not (self.runManager and self.runManager:hasActiveRun()) then return end
    self:syncRunPlayerState()
    self.runManager:saveRun()
end

-- Retoma uma run carregada (chamar DEPOIS de runManager:loadRun()):
-- remonta o jogo no andar salvo com deck/jokers/HP/ouro/inimigo corretos.
function Game:resumeRun()
    local run = self.runManager and self.runManager.currentRun
    if not run then return false end
    self.isRunMode = true
    self.selectedClass = run.classId

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

    -- Inimigo do andar salvo (mesma receita do nextPhase run-mode):
    local nodeType = (run.currentNode and run.currentNode.type) or "battle"
    local stats = ActSystem.getEnemyStats(run.actNumber, run.floorInAct, nodeType)
    self.enemy = Enemy:new(stats.health, stats.damage)
    self.battleTurn = 0
    self.scoreSystem:startBattle()
    self:applyClassBattleStartPassive()
    local spriteAct = run.actNumber
    if run.endlessMode then
        spriteAct = 4 + math.floor(math.max(0, (run.currentFloor or 25) - 25) / 8)
    end
    local EnemyRenderer = require("src.ui.EnemyRenderer")
    self.enemy.spriteId = EnemyRenderer.resolveSpriteId(spriteAct, nodeType)
    self.enemy.isBoss = (nodeType == "boss" or nodeType == "mini_boss")

    self:addMessage(msg("run_resumed", {
        name = ActSystem.getActName(run.actNumber, run.floorInAct),
        floor = run.floorInAct }), "success")
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
            PS.recordDefeat(run and run.actNumber, run and run.floorInAct)
            PS.updateBestScore(self.score)
        end
        return true
    end
    return false
end

function Game:checkVictory()
    -- Em run mode: vitoria so acontece ao matar boss do ato final (nao endless).
    -- A transicao pra endless e disparada em advanceFloorInAct; checkVictory so
    -- retorna true na primeira vez que o player bate o boss do ultimo ato.
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
                local PS = require("engine.ProfileStats")
                PS.recordVictory(run.actNumber, run.floorInAct, run.classId or self.selectedClass)
                PS.updateBestScore(self.score)
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
