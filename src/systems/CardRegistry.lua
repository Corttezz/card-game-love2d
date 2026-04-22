-- src/systems/CardRegistry.lua
-- Sistema centralizado para gestão de cartas e classes.
-- Consolida consultas por classe/raridade, starter decks e rolagem de raridade.

local CardRegistry = {}
CardRegistry.__index = CardRegistry

local CardDatabase = require("src.systems.CardDatabase")
local I18n = require("src.i18n.I18n")

function CardRegistry:new()
    local instance = setmetatable({}, CardRegistry)
    instance.cardDatabase = CardDatabase:new()
    return instance
end

-- Retorna cartas filtradas por classe e raridade
function CardRegistry:getCardsByClassAndRarity(classId, rarity)
    local allCards = self.cardDatabase:getAllCards()
    local filtered = {}
    
    for id, card in pairs(allCards) do
        -- Verifica se pertence à classe (ou é básica)
        local belongsToClass = (card.class == classId) or 
                              (not card.class) or -- Cartas sem classe são consideradas básicas
                              (card.rarity == "basic")
        
        if belongsToClass and (not rarity or card.rarity == rarity) then
            table.insert(filtered, id)
        end
    end
    
    return filtered
end

-- Retorna pool de cartas para uma classe específica
function CardRegistry:getClassCardPool(classId)
    return {
        common = self:getCardsByClassAndRarity(classId, "common"),
        uncommon = self:getCardsByClassAndRarity(classId, "uncommon"),
        rare = self:getCardsByClassAndRarity(classId, "rare"),
        legendary = self:getCardsByClassAndRarity(classId, "legendary"),
        basic = self:getCardsByClassAndRarity(classId, "basic")
    }
end

-- Retorna deck inicial para uma classe.
-- Fase 5: deck minimo de 2 cartas (1 attack + 1 defense da classe). O resto e
-- construido via recompensas/loja/eventos. Cada batalha puxa as 2 cartas direto
-- na mao inicial (INITIAL_HAND_SIZE=4 garante folga mesmo com deck curto).
function CardRegistry:getStarterDeckForClass(classId)
    local starterDecks = {
        warrior = { "warrior_strike", "warrior_defend" },
        mage    = { "mage_zap",       "defense_001" },
        rogue   = { "rogue_strike",   "rogue_defend" },
    }
    return starterDecks[classId] or { "attack_001", "defense_001" }
end

-- Gera recompensas de cartas para uma classe.
-- opts.rarityWeights: pesos customizados (Fase 5 passa do ActSystem).
-- opts.minRarity: "uncommon"/"rare" para forcar piso (elites/bosses).
function CardRegistry:generateCardRewards(classId, numCards, opts)
    opts = opts or {}
    local rewards = {}
    local cardPool = self:getClassCardPool(classId)

    local minRarity = opts.minRarity
    local minOrder = { common = 1, uncommon = 2, rare = 3, legendary = 4 }

    for _ = 1, numCards or 3 do
        local rarity = self:rollRarity(opts.rarityWeights)
        -- Aplica piso minimo (se especificado)
        if minRarity and (minOrder[rarity] or 0) < (minOrder[minRarity] or 0) then
            rarity = minRarity
        end
        local availableCards = cardPool[rarity]
        if availableCards and #availableCards > 0 then
            local randomCard = availableCards[love.math.random(#availableCards)]
            table.insert(rewards, {
                cardId = randomCard,
                rarity = rarity,
            })
        end
    end

    return rewards
end

-- Sistema de raridade com pesos customizaveis (Fase 5 via ActSystem).
-- weights: { common=N, uncommon=N, rare=N, legendary=N } (qualquer escala, sao normalizados)
-- Se omitido, usa defaults proximo do Slay (37/37/25/1).
function CardRegistry:rollRarity(weights)
    weights = weights or { common = 37, uncommon = 37, rare = 25, legendary = 1 }
    local total = 0
    for _, w in pairs(weights) do total = total + w end
    if total <= 0 then return "common" end

    local roll = love.math.random() * total
    local acc = 0
    for _, rarity in ipairs({ "common", "uncommon", "rare", "legendary" }) do
        acc = acc + (weights[rarity] or 0)
        if roll <= acc then return rarity end
    end
    return "common"
end

-- Verifica se uma carta pertence a uma classe
function CardRegistry:isClassCard(cardId, classId)
    local cardData = self.cardDatabase:getCard(cardId)
    if not cardData then return false end
    
    return cardData.class == classId or 
           cardData.rarity == "basic" or 
           not cardData.class
end

-- Informações das classes (nome/descricao traduzidos via I18n).
function CardRegistry:getClassInfo(classId)
    local classes = {
        warrior = {
            id = "warrior",
            name = I18n.t("classes.warrior.name"),
            description = I18n.t("classes.warrior.desc"),
            color = {0.8, 0.2, 0.2, 1.0},
            avatar = "assets/classes/warrior.png",
            traits = {
                strength_focus = true,
                armor_synergy = true,
                exhaust_mechanic = true
            }
        },
        mage = {
            id = "mage",
            name = I18n.t("classes.mage.name"),
            description = I18n.t("classes.mage.desc"),
            color = {0.2, 0.2, 0.8, 1.0},
            avatar = "assets/classes/mage.png",
            traits = {
                orb_mechanic = true,
                focus_scaling = true,
                card_draw = true
            }
        },
        rogue = {
            id = "rogue",
            name = I18n.t("classes.rogue.name"),
            description = I18n.t("classes.rogue.desc"),
            color = {0.2, 0.8, 0.2, 1.0},
            avatar = "assets/classes/rogue.png",
            traits = {
                poison_synergy = true,
                dexterity_focus = true,
                discard_mechanics = true
            }
        }
    }

    return classes[classId]
end

-- Retorna todas as classes
function CardRegistry:getAllClasses()
    return {
        warrior = self:getClassInfo("warrior"),
        mage = self:getClassInfo("mage"),
        rogue = self:getClassInfo("rogue")
    }
end

-- Delegate methods para manter compatibilidade com CardDatabase
function CardRegistry:getCard(cardId)
    return self.cardDatabase:getCard(cardId)
end

function CardRegistry:getAllCards()
    return self.cardDatabase:getAllCards()
end

function CardRegistry:getCardsByType(cardType)
    return self.cardDatabase:getCardsByType(cardType)
end

function CardRegistry:getCardsByRarity(rarity)
    return self.cardDatabase:getCardsByRarity(rarity)
end

function CardRegistry:createCardInstance(cardData)
    return self.cardDatabase:createCardInstance(cardData)
end

return CardRegistry
