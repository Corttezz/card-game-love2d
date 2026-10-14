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

function DeckManager:loadAvailableDecks()
    self.availableDecks = self.cardDatabase:getAllDecks()
end

function DeckManager:setCurrentDeck(deckId)
    local isValid, message = self.cardDatabase:validateDeck(deckId)
    if not isValid then
        error("Deck inválido: " .. message)
    end

    self.currentDeck = deckId
    return true
end

function DeckManager:getCurrentDeck()
    return self.currentDeck
end

function DeckManager:buildCurrentDeckCards()
    if not self.currentDeck then
        error("Nenhum deck selecionado!")
    end

    return self.cardDatabase:buildDeckCards(self.currentDeck)
end

function DeckManager:getDeckInfo(deckId)
    return self.cardDatabase:getDeck(deckId)
end

function DeckManager:getAvailableDecks()
    return self.availableDecks
end

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

            if cardData.type == "attack" then
                stats.attackCards = stats.attackCards + quantity
            elseif cardData.type == "defense" then
                stats.defenseCards = stats.defenseCards + quantity
            elseif cardData.type == "joker" then
                stats.jokerCards = stats.jokerCards + quantity
            end

            totalCost = totalCost + (cardData.cost * quantity)

            local rarity = cardData.rarity or "common"
            stats.rarityDistribution[rarity] = (stats.rarityDistribution[rarity] or 0) + quantity
        end
    end

    stats.averageCost = stats.totalCards > 0 and (totalCost / stats.totalCards) or 0

    return stats
end

return DeckManager
