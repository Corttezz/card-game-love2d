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

-- Cria um deck personalizado (futuro)
function DeckManager:createCustomDeck(name, description, cardList)
    -- Funcionalidade para criar decks personalizados
    -- Seria implementada no futuro
    local customDeck = {
        name = name,
        description = description,
        cards = cardList,
        custom = true
    }
    
    -- Validar deck
    local totalCards = 0
    for _, cardEntry in ipairs(cardList) do
        if not self.cardDatabase:getCard(cardEntry.id) then
            return false, "Carta inválida: " .. cardEntry.id
        end
        totalCards = totalCards + (cardEntry.quantity or 1)
    end
    
    if totalCards < 5 then
        return false, "Deck muito pequeno (mínimo 5 cartas)"
    end
    
    return true, customDeck
end

-- Salva deck personalizado (futuro)
function DeckManager:saveCustomDeck(deckData)
    -- Salvaria em arquivo JSON customizado
    -- Por enquanto apenas retorna sucesso
    return true
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

-- Sugere melhorias para um deck
function DeckManager:suggestDeckImprovements(deckId)
    local stats = self:getDeckStats(deckId)
    if not stats then return {} end
    
    local suggestions = {}
    
    -- Muito focado em ataque
    if stats.attackCards > (stats.totalCards * 0.7) then
        table.insert(suggestions, "Considere adicionar mais cartas defensivas para balanceamento")
    end
    
    -- Muito defensivo
    if stats.defenseCards > (stats.totalCards * 0.7) then
        table.insert(suggestions, "Adicione mais cartas de ataque para terminar combates")
    end
    
    -- Sem jokers
    if stats.jokerCards == 0 then
        table.insert(suggestions, "Jokers oferecem efeitos passivos poderosos")
    end
    
    -- Custo muito alto
    if stats.averageCost > 3 then
        table.insert(suggestions, "Deck com custo alto - considere cartas mais baratas")
    end
    
    -- Deck muito pequeno
    if stats.totalCards < 8 then
        table.insert(suggestions, "Deck pequeno - adicione mais cartas para consistência")
    end
    
    return suggestions
end

return DeckManager
