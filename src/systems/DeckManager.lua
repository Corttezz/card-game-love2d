-- src/systems/DeckManager.lua
-- Sistema de gerenciamento de decks

local DeckManager = {}
DeckManager.__index = DeckManager

local CardDatabase = require("src.systems.CardDatabase")

function DeckManager:new()
    local instance = setmetatable({}, DeckManager)
    instance.cardDatabase = CardDatabase:new()
    instance.currentDeck = nil
    instance.availableDecks = {}
    instance:loadAvailableDecks()
    return instance
end

-- Carrega todos os decks disponíveis
function DeckManager:loadAvailableDecks()
    self.availableDecks = self.cardDatabase:getAllDecks()
end

-- Define o deck atual
function DeckManager:setCurrentDeck(deckId)
    local isValid, message = self.cardDatabase:validateDeck(deckId)
    if not isValid then
        error("Deck inválido: " .. message)
    end
    
    self.currentDeck = deckId
    return true
end

-- Retorna o deck atual
function DeckManager:getCurrentDeck()
    return self.currentDeck
end

-- Cria uma lista de cartas do deck atual
function DeckManager:buildCurrentDeckCards()
    if not self.currentDeck then
        error("Nenhum deck selecionado!")
    end
    
    return self.cardDatabase:buildDeckCards(self.currentDeck)
end

-- Retorna informações sobre um deck
function DeckManager:getDeckInfo(deckId)
    return self.cardDatabase:getDeck(deckId)
end

-- Retorna lista de todos os decks disponíveis
function DeckManager:getAvailableDecks()
    return self.availableDecks
end

-- Retorna estatísticas de um deck
function DeckManager:getDeckStats(deckId)
    local deck = self.cardDatabase:getDeck(deckId)
    if not deck then return nil end
    
    local stats = {
        totalCards = 0,
        attackCards = 0,
        defenseCards = 0,
        jokerCards = 0,
        averageCost = 0,
        rarityDistribution = {
            common = 0,
            rare = 0,
            epic = 0,
            legendary = 0
        }
    }
    
    local totalCost = 0
    
    for _, cardEntry in ipairs(deck.cards) do
        local cardData = self.cardDatabase:getCard(cardEntry.id)
        if cardData then
            local quantity = cardEntry.quantity or 1
            stats.totalCards = stats.totalCards + quantity
            
            -- Conta tipos
            if cardData.type == "attack" then
                stats.attackCards = stats.attackCards + quantity
            elseif cardData.type == "defense" then
                stats.defenseCards = stats.defenseCards + quantity
            elseif cardData.type == "joker" then
                stats.jokerCards = stats.jokerCards + quantity
            end
            
            -- Calcula custo médio
            totalCost = totalCost + (cardData.cost * quantity)
            
            -- Conta raridades
            local rarity = cardData.rarity or "common"
            stats.rarityDistribution[rarity] = (stats.rarityDistribution[rarity] or 0) + quantity
        end
    end
    
    stats.averageCost = stats.totalCards > 0 and (totalCost / stats.totalCards) or 0
    
    return stats
end

return DeckManager
