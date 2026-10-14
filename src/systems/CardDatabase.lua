local Debug = require("src.core.Debug")

local CardDatabase = {}
CardDatabase.__index = CardDatabase

local cardData = nil
local deckData = nil

local CARD_MODULES = {
    "src.data.cards.basic",
    "src.data.cards.warrior",
    "src.data.cards.mage",
    "src.data.cards.rogue",
}

function CardDatabase:new()
    local instance = setmetatable({}, CardDatabase)
    self:loadData()
    return instance
end

function CardDatabase:loadData()
    if cardData then return end

    local merged = {}
    for _, modPath in ipairs(CARD_MODULES) do
        local ok, cards = pcall(require, modPath)
        if ok and type(cards) == "table" then
            for id, card in pairs(cards) do
                merged[id] = card
            end
        else
            Debug.err("[CardDatabase] erro ao carregar modulo: " .. modPath)
        end
    end

    cardData = { cards = merged }

    local okDecks, decks = pcall(require, "src.data.decks")
    deckData = { decks = (okDecks and type(decks) == "table") and decks or {} }
end

function CardDatabase:getCard(cardId)
    self:loadData()
    return cardData and cardData.cards and cardData.cards[cardId]
end

function CardDatabase:getAllCards()
    self:loadData()
    return cardData and cardData.cards or {}
end

function CardDatabase:getTotalCardCount()
    local n = 0
    for _ in pairs(self:getAllCards()) do n = n + 1 end
    return n
end

function CardDatabase:getDeck(deckId)
    self:loadData()
    return deckData and deckData.decks and deckData.decks[deckId]
end

function CardDatabase:getAllDecks()
    self:loadData()
    return deckData and deckData.decks or {}
end

function CardDatabase:getCardsByType(cardType)
    local filtered = {}
    for id, card in pairs(self:getAllCards()) do
        if card.type == cardType then filtered[id] = card end
    end
    return filtered
end

function CardDatabase:getCardsByRarity(rarity)
    local filtered = {}
    for id, card in pairs(self:getAllCards()) do
        if card.rarity == rarity then filtered[id] = card end
    end
    return filtered
end

function CardDatabase:buildDeckCards(deckId)
    local deck = self:getDeck(deckId)
    if not deck then error("Deck nao encontrado: " .. tostring(deckId)) end

    local cards = {}
    for _, cardEntry in ipairs(deck.cards) do
        local cardDataEntry = self:getCard(cardEntry.id)
        if cardDataEntry then
            for _ = 1, (cardEntry.quantity or 1) do
                table.insert(cards, self:createCardInstance(cardDataEntry))
            end
        else
            Debug.warn("[CardDatabase] carta nao encontrada no deck " .. deckId .. ": " .. cardEntry.id)
        end
    end
    return cards
end

function CardDatabase:createCardInstance(cd)
    local AttackCard = require("src.cards.types.AttackCard")
    local DefenseCard = require("src.cards.types.DefenseCard")
    local JokerCard = require("src.cards.types.JokerCard")
    local EffectCard = require("src.cards.types.EffectCard")
    local CardFrame = require("src.ui.CardFrame")
    local Config = require("src.core.Config")

    local instance
    if cd.type == "attack" then
        instance = AttackCard:new(cd.name, cd.cost, cd.attack, cd.subtype, cd.image)
    elseif cd.type == "defense" then
        instance = DefenseCard:new(cd.name, cd.cost, cd.defense, cd.subtype, cd.image)
    elseif cd.type == "joker" then
        instance = JokerCard:new(cd.name, cd.cost, self:createEffectFunction(cd.effects), cd.subtype, cd.image)
    elseif cd.type == "effect" then
        instance = EffectCard:new(cd.name, cd.cost, self:createEffectFunction(cd.effects), cd.subtype, cd.image)
    else
        error("Tipo de carta desconhecido: " .. tostring(cd.type))
    end

    instance.id = cd.id
    instance.description = cd.description
    instance.rarity = cd.rarity
    if cd.effects then
        local copy = {}
        for i, eff in ipairs(cd.effects) do
            if type(eff) == "table" then
                local e = {}
                for k, v in pairs(eff) do e[k] = v end
                copy[i] = e
            else
                copy[i] = eff
            end
        end
        instance.effects = copy
        if cd.type == "effect" or cd.type == "joker" then
            instance.passive = self:createEffectFunction(instance.effects)
        end
    end
    instance.class = cd.class
    local TagSystem = require("src.systems.TagSystem")
    instance.tags = TagSystem.getCardTags(cd)
    instance.innate = cd.innate
    instance.retain = cd.retain
    instance.exhaust = cd.exhaust or nil
    for _, eff in ipairs(cd.effects or {}) do
        if eff.type == "exhaust" then
            instance.exhaust = true
            break
        end
    end

    local ok, proceduralImg = pcall(CardFrame.render, instance)
    if ok and proceduralImg then
        instance.image = proceduralImg
        instance.width = proceduralImg:getWidth() * (Config.Cards.BASE_SCALE or 2)
        instance.height = proceduralImg:getHeight() * (Config.Cards.BASE_SCALE or 2)
    else
        love.graphics.setCanvas()
        Debug.warn("[CardDatabase] CardFrame.render falhou para " .. tostring(cd.id) .. ": " .. tostring(proceduralImg))
    end

    local CardArt = require("src.ui.CardArt")
    local okArt, art = pcall(CardArt.resolve, instance)
    if okArt and art then
        instance.visualEffect = art.effect
    end

    return instance
end

function CardDatabase:createEffectFunction(effects)
    local I18n = require("src.i18n.I18n")
    return function(game)
        for _, effect in ipairs(effects or {}) do
            local processed = game.effectSystem and game.effectSystem:processEffectCard(game, effect)
            if not processed then
                local text = I18n.effectDesc(effect)
                if text and text ~= "" then
                    game:addMessage(text, "info")
                end
            end
        end
    end
end

function CardDatabase:validateDeck(deckId)
    local deck = self:getDeck(deckId)
    if not deck then return false, "Deck nao encontrado" end

    local total = 0
    for _, cardEntry in ipairs(deck.cards) do
        if not self:getCard(cardEntry.id) then
            return false, "Carta invalida: " .. cardEntry.id
        end
        total = total + (cardEntry.quantity or 1)
    end
    if total < 5 then return false, "Deck muito pequeno (minimo 5 cartas)" end
    return true, "Deck valido"
end

return CardDatabase
