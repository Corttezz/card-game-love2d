-- src/systems/CardDatabase.lua
-- Loader de cartas e decks. Os dados vivem em src/data/cards/*.lua e src/data/decks.lua.
-- Esta camada apenas: (1) merge dos módulos, (2) queries, (3) criação de instâncias de Card.

local CardDatabase = {}
CardDatabase.__index = CardDatabase

-- Caches (escopo do módulo — singleton natural).
local cardData = nil
local deckData = nil

-- Fontes de dados por classe/categoria. Ordem determina precedência em colisão de ID
-- (a última sobrescreve), mas os IDs são prefixados por classe, então não há colisão real.
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
            print("[CardDatabase] erro ao carregar modulo: " .. modPath)
        end
    end

    cardData = { cards = merged }

    local okDecks, decks = pcall(require, "src.data.decks")
    deckData = { decks = (okDecks and type(decks) == "table") and decks or {} }
end

-- ===== Queries =====

function CardDatabase:getCard(cardId)
    self:loadData()
    return cardData and cardData.cards and cardData.cards[cardId]
end

function CardDatabase:getAllCards()
    self:loadData()
    return cardData and cardData.cards or {}
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

-- ===== Instanciação =====

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
            print("[CardDatabase] carta nao encontrada no deck " .. deckId .. ": " .. cardEntry.id)
        end
    end
    return cards
end

-- Cria instância de carta (Attack/Defense/Joker/Effect) a partir dos dados.
-- Injeta `description`, `rarity`, `effects` na instância e **substitui a imagem**
-- pelo canvas procedural gerado via CardFrame.
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

    -- Dados auxiliares usados em runtime (tooltip, EffectSystem, CardFrame).
    instance.id = cd.id
    instance.description = cd.description
    instance.rarity = cd.rarity
    instance.effects = cd.effects
    instance.class = cd.class
    -- Normaliza tags na criacao: carrega do card-data ou deriva do tipo.
    -- TagSystem.getCardTags ja faz merge com tag implicita e remove duplicados.
    local TagSystem = require("src.systems.TagSystem")
    instance.tags = TagSystem.getCardTags(cd)
    -- Flags opcionais de cartas especiais (preenchidos no pass de rebalance da Fase 7).
    instance.innate = cd.innate
    instance.retain = cd.retain
    -- Exhaust: Game.lua checa instance.exhaust (top-level), mas os dados
    -- declaram {type="exhaust"} dentro de effects — sem esta derivação
    -- NENHUMA carta exauria (bug F0 do gameplay-overhaul-v1).
    instance.exhaust = cd.exhaust or nil
    for _, eff in ipairs(cd.effects or {}) do
        if eff.type == "exhaust" then
            instance.exhaust = true
            break
        end
    end

    -- Substitui imagem pela arte procedural pixel-perfect.
    -- Mantém o fallback original se CardFrame falhar (ex: em ambiente sem love).
    local ok, proceduralImg = pcall(CardFrame.render, instance)
    if ok and proceduralImg then
        instance.image = proceduralImg
        instance.width = proceduralImg:getWidth() * (Config.Cards.BASE_SCALE or 2)
        instance.height = proceduralImg:getHeight() * (Config.Cards.BASE_SCALE or 2)
    else
        -- CardFrame.render usa PixelCanvas.beginDraw (seta canvas) e endDraw (restaura).
        -- Se o crash for ENTRE os dois, o canvas fica preso ativo — isso bloqueia
        -- o love.graphics.present() do próximo frame ("Canvas is active"). Reset forçado:
        love.graphics.setCanvas()
        print("[CardDatabase] CardFrame.render falhou para " .. tostring(cd.id) .. ": " .. tostring(proceduralImg))
    end

    -- Marca flags visuais consumidas por Card:draw (efeito holo/glow via shader).
    local CardArt = require("src.ui.CardArt")
    local okArt, art = pcall(CardArt.resolve, instance)
    if okArt and art then
        instance.visualEffect = art.effect  -- nil | "shine" | "glow" | "holo"
    end

    return instance
end

-- Compila a função `passive(game)` executada quando a carta é jogada.
-- Delega para EffectSystem:processEffectCard. Se o efeito não for reconhecido,
-- mostra a descrição traduzida via I18n.effectDesc (fallback: effect.description).
function CardDatabase:createEffectFunction(effects)
    local I18n = require("src.i18n.I18n")
    return function(game)
        for _, effect in ipairs(effects or {}) do
            if game.effectSystem and game.effectSystem:processEffectCard(game, effect) then
                -- processado
            else
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
