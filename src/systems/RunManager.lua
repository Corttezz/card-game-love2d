-- src/systems/RunManager.lua
-- Gerencia a "corrida" atual (run) como no Slay the Spire

local RunManager = {}
RunManager.__index = RunManager

local ClassSystem = require("src.systems.ClassSystem")
local CardDatabase = require("src.systems.CardDatabase")

function RunManager:new()
    local instance = setmetatable({}, RunManager)
    instance.classSystem = ClassSystem:new()
    instance.cardDatabase = CardDatabase:new()
    
    -- Estado da corrida atual
    instance.currentRun = nil
    instance.isRunActive = false
    
    return instance
end

-- Inicia uma nova corrida com a classe selecionada
function RunManager:startNewRun(classId)
    local selectedClass = self.classSystem:selectClass(classId)
    
    self.currentRun = {
        classId = classId,
        className = selectedClass.name,
        
        -- Deck dinâmico que cresce durante o jogo
        currentDeck = {},
        
        -- Progresso
        currentFloor = 1,
        battlesWon = 0,
        cardsAdded = 0,
        
        -- Estatísticas
        totalDamageDealt = 0,
        totalDamageTaken = 0,
        cardsPlayed = 0,
        
        -- Histórico de cartas adicionadas
        cardHistory = {},
        
        -- Estado do jogador (pode ser expandido)
        playerState = {
            maxHealth = 100,
            currentHealth = 100,
            gold = 99
        }
    }
    
    -- Inicializa o deck com as cartas starter da classe
    self:initializeStarterDeck(classId)
    
    self.isRunActive = true
    return self.currentRun
end

-- Inicializa deck com cartas starter da classe
function RunManager:initializeStarterDeck(classId)
    local starterCards = self.classSystem:getStarterDeck(classId)
    
    for _, cardId in ipairs(starterCards) do
        table.insert(self.currentRun.currentDeck, cardId)
    end
end

-- Retorna o deck atual da corrida
function RunManager:getCurrentDeck()
    if not self.currentRun then return {} end
    return self.currentRun.currentDeck
end

-- Adiciona uma carta ao deck (recompensa pós-batalha)
function RunManager:addCardToDeck(cardId)
    if not self.currentRun then 
        return false 
    end
    
    table.insert(self.currentRun.currentDeck, cardId)
    self.currentRun.cardsAdded = self.currentRun.cardsAdded + 1
    
    -- Registra no histórico
    table.insert(self.currentRun.cardHistory, {
        cardId = cardId,
        floor = self.currentRun.currentFloor,
        timestamp = love.timer.getTime()
    })
    
    return true
end

-- Remove uma carta do deck (mecânica de upgrade/remoção)
function RunManager:removeCardFromDeck(cardId)
    if not self.currentRun then return false end
    
    for i, deckCardId in ipairs(self.currentRun.currentDeck) do
        if deckCardId == cardId then
            table.remove(self.currentRun.currentDeck, i)
            return true
        end
    end
    
    return false
end

-- Completa uma batalha e gera recompensas
function RunManager:completeBattle()
    if not self.currentRun then return nil end
    
    self.currentRun.battlesWon = self.currentRun.battlesWon + 1
    self.currentRun.currentFloor = self.currentRun.currentFloor + 1
    
    -- Gera 3 cartas de recompensa (padrão Slay the Spire)
    local cardRewards = self.classSystem:generateCardRewards(3)
    
    return {
        cardRewards = cardRewards,
        gold = love.math.random(10, 25),
        floor = self.currentRun.currentFloor,
        canSkipReward = true -- Opção de pular recompensa
    }
end

-- Converte deck para instâncias de cartas jogáveis
function RunManager:buildPlayableDeck()
    if not self.currentRun then return {} end
    
    local playableCards = {}
    
    for _, cardId in ipairs(self.currentRun.currentDeck) do
        local cardData = self.cardDatabase:getCard(cardId)
        if cardData then
            local cardInstance = self.cardDatabase:createCardInstance(cardData)
            table.insert(playableCards, cardInstance)
        else
            print("AVISO: Carta não encontrada no banco de dados: " .. cardId)
        end
    end
    
    return playableCards
end

-- Estatísticas da corrida atual
function RunManager:getCurrentRunStats()
    if not self.currentRun then return nil end
    
    return {
        class = self.currentRun.className,
        floor = self.currentRun.currentFloor,
        battlesWon = self.currentRun.battlesWon,
        deckSize = #self.currentRun.currentDeck,
        cardsAdded = self.currentRun.cardsAdded,
        averageCardsPerFloor = self.currentRun.cardsAdded / math.max(1, self.currentRun.currentFloor - 1),
        
        -- Análise do deck
        deckComposition = self:analyzeDeckComposition()
    }
end

-- Analisa composição do deck atual
function RunManager:analyzeDeckComposition()
    if not self.currentRun then return {} end
    
    local composition = {
        attack = 0,
        defense = 0,
        joker = 0,
        totalCards = #self.currentRun.currentDeck,
        rarityDistribution = {
            common = 0,
            uncommon = 0,
            rare = 0
        }
    }
    
    for _, cardId in ipairs(self.currentRun.currentDeck) do
        local cardData = self.cardDatabase:getCard(cardId)
        if cardData then
            -- Conta tipos
            if cardData.type == "attack" then
                composition.attack = composition.attack + 1
            elseif cardData.type == "defense" then
                composition.defense = composition.defense + 1
            elseif cardData.type == "joker" then
                composition.joker = composition.joker + 1
            end
            
            -- Conta raridades
            local rarity = cardData.rarity or "common"
            composition.rarityDistribution[rarity] = (composition.rarityDistribution[rarity] or 0) + 1
        end
    end
    
    return composition
end

-- Salva estado da corrida (para implementar save/load)
function RunManager:saveRun()
    if not self.currentRun then return nil end
    
    -- Por enquanto retorna os dados, futuramente salvaria em arquivo
    return {
        version = "1.0",
        runData = self.currentRun,
        timestamp = love.timer.getTime()
    }
end

-- Carrega estado de uma corrida
function RunManager:loadRun(saveData)
    if not saveData or not saveData.runData then return false end
    
    self.currentRun = saveData.runData
    self.isRunActive = true
    
    -- Reseleciona a classe
    self.classSystem:selectClass(self.currentRun.classId)
    
    return true
end

-- Termina a corrida atual
function RunManager:endRun(victory)
    if not self.currentRun then return nil end
    
    local finalStats = self:getCurrentRunStats()
    finalStats.victory = victory
    finalStats.finalScore = self:calculateFinalScore(victory)
    
    self.currentRun = nil
    self.isRunActive = false
    
    return finalStats
end

-- Calcula pontuação final
function RunManager:calculateFinalScore(victory)
    if not self.currentRun then return 0 end
    
    local baseScore = self.currentRun.battlesWon * 100
    local floorBonus = self.currentRun.currentFloor * 50
    local victoryBonus = victory and 1000 or 0
    
    return baseScore + floorBonus + victoryBonus
end

-- Verifica se há uma corrida ativa
function RunManager:hasActiveRun()
    return self.isRunActive and self.currentRun ~= nil
end

-- Retorna informações da classe atual
function RunManager:getCurrentClassInfo()
    if not self.currentRun then return nil end
    return self.classSystem:getCurrentClass()
end

return RunManager

