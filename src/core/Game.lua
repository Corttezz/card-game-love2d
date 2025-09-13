local AttackCard = require("src.cards.types.AttackCard")
local DefenseCard = require("src.cards.types.DefenseCard")
local JokerCard = require("src.cards.types.JokerCard")
local Player = require("src.entities.Player")
local Enemy = require("src.entities.Enemy")
local MessageSystem = require("src.systems.MessageSystem")
local DeckManager = require("src.systems.DeckManager")
local EffectSystem = require("src.systems.EffectSystem")
local RunManager = require("src.systems.RunManager")
local CombatAnimationSystem = require("src.systems.CombatAnimationSystem")
local EconomySystem = require("src.systems.EconomySystem")
local Config = require("src.core.Config")

local Game = {}
Game.__index = Game

-- Cache de áudio para melhor performance
local deckStartSoundCache = nil
local cardSelectSoundCache = nil

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
    
    -- Novos sistemas
    instance.deckManager = DeckManager:new()
    instance.effectSystem = EffectSystem:new()
    instance.runManager = RunManager:new()
    instance.combatAnimationSystem = CombatAnimationSystem:new()
    
    -- Sistema de economia e loja
    instance.economySystem = EconomySystem:new()
    
    -- Sistema de classes (Slay the Spire style)
    instance.selectedClass = nil
    instance.isRunMode = false
    
    return instance
end

function Game:initializeDeck()
    -- Usa o sistema de áudio global se disponível
    if _G.audioSystem and _G.audioSystem:isAudioAvailable() then
        _G.audioSystem:playSound("deckStart")
    else
        -- Fallback para sistema antigo
        if not deckStartSoundCache then
            deckStartSoundCache = love.audio.newSource("audio/deckStart.mp3", "static")
            deckStartSoundCache:setVolume(Config.Audio.DECK_START_VOLUME)
        end
        deckStartSoundCache:play()
    end
    
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
    self.gameState = "playing"
    self.currentPhase = 1
    self.score = 0
    self.player = Player:new()
    self.enemy = Enemy:new(Config.Game.ENEMY_BASE_HEALTH, Config.Game.ENEMY_BASE_DAMAGE)
    self.turn = "player"
    self.hand = {}
    self.selectedCards = {}
    self.jokerSlots = {}
    -- Removido: self.damageMultiplier = 1 (não é mais necessário)
    
    -- Reseta economia para nova run
    self.economySystem:resetForNewRun()
    self.economySystem.currentGold = 10 -- Ouro inicial
    
    -- Inicializa o deck com as cartas
    self:initializeDeck()
    
    -- Puxa cartas iniciais para a mão
    for i = 1, Config.Game.INITIAL_HAND_SIZE do
        self:drawCard()
    end
    
    self:addMessage("Jogo iniciado! Boa sorte!", "success")
    self:addMessage("Ouro inicial: " .. self.economySystem.currentGold, "info")
end

function Game:drawCard()
    if #self.deck > 0 then
        local card = table.remove(self.deck, 1) -- Remove a primeira carta do deck
        table.insert(self.hand, card)
    end
end

function Game:playCard(card)
    if card.type == "attack" then
        local damage = card.attack -- Dano base da carta
        
        -- Aplica efeitos dos jokers ativos
        damage = self:applyJokerEffects(card, damage)
        
        self.enemy:takeDamage(damage)
        self.score = self.score + damage
    elseif card.type == "defense" then
        local defense = card.defense -- Defesa base da carta
        
        -- Aplica efeitos dos jokers ativos
        defense = self:applyJokerEffects(card, defense)
        
        self.player:addArmor(defense)
    elseif card.type == "joker" then
        -- Jokers vão para slots passivos (mão de cima)
        if #self.jokerSlots < self.maxJokerSlots then
            table.insert(self.jokerSlots, card)
            
            card.passive(self) -- Executa efeito especial
            self:addMessage("Joker ativado: " .. card.name, "success")
            
            -- Remove o joker da mão atual
            for i, handCard in ipairs(self.hand) do
                if handCard == card then
                    table.remove(self.hand, i)
                    break
                end
            end
        else
            self:addMessage("Sem slots disponíveis para jokers!", "error")
        end
    elseif card.type == "effect" then
        -- Cartas de efeito executam seu efeito e são descartadas
        card.passive(self) -- Executa efeito especial
        self:addMessage("Efeito ativado: " .. card.name, "success")
        
        -- Remove a carta de efeito da mão atual
        for i, handCard in ipairs(self.hand) do
            if handCard == card then
                table.remove(self.hand, i)
                break
            end
        end
    end
end

-- Aplica efeitos dos jokers ativos a uma carta
function Game:applyJokerEffects(card, baseValue)
    -- Novo sistema: usa EffectSystem para aplicar efeitos
    return self.effectSystem:applyJokerEffects(self, card, baseValue)
end

-- Novos métodos para gerenciamento de decks
function Game:setDeck(deckId)
    self.currentDeckId = deckId
    self:addMessage("Deck alterado para: " .. (self.deckManager:getDeckInfo(deckId).name or deckId), "info")
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
    self:addMessage("Nova corrida iniciada como " .. runData.className .. "!", "success")
    
    return runData
end

-- Completa uma batalha e gera recompensas
function Game:completeBattle()
    if not self.isRunMode then return nil end
    
    local rewards = self.runManager:completeBattle()
    self:addMessage("Batalha vencida! Andar " .. rewards.floor, "success")
    
    return rewards
end

-- Adiciona uma carta ao deck da corrida
function Game:addCardToRun(cardId)
    if not self.isRunMode then 
        self:addMessage("Erro: Não está em modo de corrida!", "error")
        return false 
    end
    
    
    local success = self.runManager:addCardToDeck(cardId)
    
    if success then
        local cardData = self.deckManager.cardDatabase:getCard(cardId)
        local cardName = cardData and cardData.name or cardId
        self:addMessage("Carta adicionada: " .. cardName, "success")
        
        -- Mostra estatísticas do deck atualizado
        local deckStats = self.runManager:getCurrentRunStats()
        if deckStats then
            self:addMessage("Deck: " .. deckStats.deckSize .. " cartas", "info")
        end
        
        -- CRÍTICO: Reconstrói completamente o deck jogável
        self:synchronizeRunDeck()
        
        -- Embaralha para distribuir a nova carta
        self:shuffleDeck()
        
        return true
    else
        self:addMessage("Erro ao adicionar carta ao deck!", "error")
        return false
    end
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
        self:addMessage("Carta removida: " .. cardName, "info")
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
    return self.runManager.classSystem:getAllClasses()
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
    -- Seleciona ou desseleciona a carta
    if self:isCardSelected(card) then
        -- Desseleciona a carta
        for i, selected in ipairs(self.selectedCards) do
            if selected == card then
                table.remove(self.selectedCards, i)
                self.player.mana = self.player.mana + card.cost -- Devolve mana
                break
            end
        end
    else
        -- Seleciona a carta se tiver mana suficiente
        if self.player:spendMana(card.cost) then
            table.insert(self.selectedCards, card)
            
            -- Toca som de seleção
            self:playCardSelectSound()
        else
            self:addMessage("Mana insuficiente!", "error")
        end
    end
end

function Game:playSelectedCards()
    if #self.selectedCards == 0 then
        self:addMessage("Selecione cartas para jogar!", "warning")
        return
    end
    
    -- Remove as cartas da mão IMEDIATAMENTE quando a animação começa
    for _, card in ipairs(self.selectedCards) do
        for i, handCard in ipairs(self.hand) do
            if handCard == card then
                table.remove(self.hand, i)
                break
            end
        end
    end
    
    -- Inicia animação de combate
    self.combatAnimationSystem:startCombat(
        self.selectedCards,
        function()
            -- Callback quando animação termina
            self:onCombatAnimationComplete()
        end,
        function(card)
            -- Callback para processar cada carta
            return self:processCardInCombat(card)
        end
    )
end

function Game:processCardInCombat(card)
    local result = {}
    
    if card.type == "attack" then
        local damage = card.attack -- Dano base da carta
        
        -- Aplica efeitos dos jokers ativos
        damage = self:applyJokerEffects(card, damage)
        
        self.enemy:takeDamage(damage)
        self.score = self.score + damage
        
        result.damage = damage
        self:addMessage("Dano: " .. damage, "success")
        
    elseif card.type == "defense" then
        local defense = card.defense -- Defesa base da carta
        
        -- Aplica efeitos dos jokers ativos
        defense = self:applyJokerEffects(card, defense)
        
        self.player:addArmor(defense)
        
        result.defense = defense
        self:addMessage("Bloqueio: +" .. defense, "info")
        
    elseif card.type == "joker" then
        -- Jokers vão para slots passivos (mão de cima)
        if #self.jokerSlots < self.maxJokerSlots then
            table.insert(self.jokerSlots, card)
            
            card.passive(self) -- Executa efeito especial
            self:addMessage("Joker ativado: " .. card.name, "success")
            
            result.joker = true
        else
            self:addMessage("Todos os slots de joker estão ocupados!", "warning")
        end
        
    elseif card.type == "effect" then
        -- Cartas de efeito executam seu efeito e são descartadas
        card.passive(self) -- Executa efeito especial
        self:addMessage("Efeito ativado: " .. card.name, "success")
        
        result.effect = true
    end
    
    return result
end

function Game:onCombatAnimationComplete()
    -- Cartas já foram removidas da mão em playSelectedCards()
    -- Apenas limpa a seleção e muda para o turno do inimigo
    self.selectedCards = {}
    self.turn = "enemy"
    
    -- Removido: self.damageMultiplier = 1 (jokers agora têm efeitos eternos)
end

function Game:enemyTurn()
    -- Inimigo ataca o jogador
    local damage = self.enemy:performAttack()
    if damage > 0 then
        self.player:takeDamage(damage)
        self:addMessage("Inimigo causou " .. damage .. " de dano!", "warning")
    end

    -- Volta para o turno do jogador e restaura mana
    self.turn = "player"
    self.player:restoreMana()
    
    -- Compra uma carta no início do turno
    if #self.deck > 0 then
        self:drawCard()
    end
end

function Game:isPhaseCleared()
    return self.enemy.health <= 0
end

function Game:resetHandAndDeck()
    -- Limpa a mão atual
    self.hand = {}
    self.selectedCards = {}
    
    -- Se estiver em modo run, sincroniza o deck com o deck da corrida
    if self.isRunMode and self.runManager:hasActiveRun() then
        self:synchronizeRunDeck()
    end
    
    -- Reembaralha o deck para o próximo andar
    self:shuffleDeck()
    
    -- Compra cartas iniciais para a nova fase
    for i = 1, Config.Game.INITIAL_HAND_SIZE do
        if #self.deck > 0 then
            self:drawCard()
        end
    end
    
    self:addMessage("Mão limpa e deck reembaralhado para o próximo andar!", "info")
end

function Game:nextPhase()
    self.currentPhase = self.currentPhase + 1
    self.score = self.score + Config.Game.BASE_SCORE_PER_PHASE * self.currentPhase
    
    -- Ganha ouro por vencer a batalha
    local healthLost = self.player.maxHealth - self.player.health
    local goldEarned = self.economySystem:earnBattleGold(self.currentPhase, healthLost, self.currentPhase)
    self:addMessage("Ganhou " .. goldEarned .. " ouro!", "success")
    
    -- Reseta a mana máxima para o valor base (remove efeitos de cartas de fase anterior)
    self.player:resetMaxMana()
    
    -- Limpa a mão atual e reembaralha o deck para o próximo andar
    self:resetHandAndDeck()
    
    -- Cria o próximo inimigo com vida e dano maiores usando Config
    local newHealth = Config.Game.ENEMY_BASE_HEALTH + (self.currentPhase - 1) * Config.Game.ENEMY_HEALTH_SCALING
    local newDamage = Config.Game.ENEMY_BASE_DAMAGE + (self.currentPhase - 1) * Config.Game.ENEMY_DAMAGE_SCALING
    self.enemy = Enemy:new(newHealth, newDamage)
    
    -- Restaura vida do jogador a cada X fases usando Config
    if self.currentPhase % Config.Game.HEALTH_RESTORE_INTERVAL == 0 then
        self.player.health = math.min(self.player.health + Config.Game.PLAYER_HEALTH_RESTORE, self.player.maxHealth)
        self:addMessage("Vida restaurada! +" .. Config.Game.PLAYER_HEALTH_RESTORE .. " HP", "success")
    end
    
    self:addMessage("Fase " .. self.currentPhase .. " iniciada!", "info")
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
        return true
    end
    return false
end

function Game:checkVictory()
    -- Vitória após X fases usando Config
    if self.currentPhase > Config.Game.VICTORY_PHASES then
        self.gameState = "victory"
        return true
    end
    return false
end

-- Toca som de seleção de carta
function Game:playCardSelectSound()
    -- Usa o sistema de áudio global se disponível
    if _G.audioSystem and _G.audioSystem:isAudioAvailable() then
        _G.audioSystem:playSound("cardSelect")
    else
        -- Fallback para sistema antigo
        if not cardSelectSoundCache then
            cardSelectSoundCache = love.audio.newSource("audio/clickselect2-92097.mp3", "static")
            cardSelectSoundCache:setVolume(Config.Audio.CLICK_SELECT_VOLUME)
        end
        
        -- Garante que o som seja tocado corretamente
        if cardSelectSoundCache then
            -- Para o som anterior se estiver tocando
            cardSelectSoundCache:stop()
            -- Toca o som
            cardSelectSoundCache:play()
        end
    end
end

-- Método para alternar o menu (usado pela TopBar)
function Game:toggleMenu()
    -- Por enquanto, apenas imprime uma mensagem
    -- Pode ser expandido para mostrar um menu de configurações
    self:addMessage("Menu de configurações em desenvolvimento", "info")
    print("[Game] Menu toggled - configurações em desenvolvimento")
end

return Game
