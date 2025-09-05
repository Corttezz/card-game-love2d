-- src/systems/CardRegistry.lua
-- Sistema centralizado para gestão de cartas e classes
-- Elimina duplicação entre ClassSystem e CardDatabase

local CardRegistry = {}
CardRegistry.__index = CardRegistry

local CardDatabase = require("src.systems.CardDatabase")

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

-- Retorna deck inicial para uma classe
function CardRegistry:getStarterDeckForClass(classId)
    local starterDecks = {
        warrior = {
            "warrior_strike", "warrior_defend", "warrior_bash", "warrior_iron_wave",
            "warrior_heavy_blade", "attack_001", "defense_001", "attack_002"
        },
        mage = {
            "mage_zap", "mage_dualcast", "mage_ball_lightning", "defense_001",
            "attack_001", "attack_002", "joker_001", "warrior_defend"
        },
        rogue = {
            "rogue_strike", "rogue_defend", "rogue_survivor", "rogue_neutralize",
            "rogue_backstab", "attack_001", "defense_001", "attack_002"
        }
    }
    
    return starterDecks[classId] or {}
end

-- Gera recompensas de cartas para uma classe
function CardRegistry:generateCardRewards(classId, numCards)
    local rewards = {}
    local cardPool = self:getClassCardPool(classId)
    
    for i = 1, numCards or 3 do
        -- Distribuição de raridade (similar ao Slay the Spire)
        local rarity = self:rollRarity()
        local availableCards = cardPool[rarity]
        
        if availableCards and #availableCards > 0 then
            local randomCard = availableCards[love.math.random(#availableCards)]
            table.insert(rewards, {
                cardId = randomCard,
                rarity = rarity
            })
        end
    end
    
    return rewards
end

-- Sistema de raridade (probabilidades do Slay the Spire + legendary)
function CardRegistry:rollRarity()
    local roll = love.math.random()
    
    if roll <= 0.37 then
        return "common"
    elseif roll <= 0.37 + 0.37 then
        return "uncommon" 
    elseif roll <= 0.37 + 0.37 + 0.25 then
        return "rare"
    else
        return "legendary"  -- 1% chance (0.01)
    end
end

-- Verifica se uma carta pertence a uma classe
function CardRegistry:isClassCard(cardId, classId)
    local cardData = self.cardDatabase:getCard(cardId)
    if not cardData then return false end
    
    return cardData.class == classId or 
           cardData.rarity == "basic" or 
           not cardData.class
end

-- Informações das classes (mantém compatibilidade)
function CardRegistry:getClassInfo(classId)
    local classes = {
        warrior = {
            id = "warrior",
            name = "Guerreiro",
            description = "Especialista em combate corpo a corpo e resistência",
            color = {0.8, 0.2, 0.2, 1.0}, -- RGBA com alpha
            avatar = "assets/classes/warrior.png",
            traits = {
                strength_focus = true,
                armor_synergy = true,
                exhaust_mechanic = true
            }
        },
        mage = {
            id = "mage",
            name = "Mago",
            description = "Mestre das artes arcanas e manipulação elemental", 
            color = {0.2, 0.2, 0.8, 1.0}, -- RGBA com alpha
            avatar = "assets/classes/mage.png",
            traits = {
                orb_mechanic = true,
                focus_scaling = true,
                card_draw = true
            }
        },
        rogue = {
            id = "rogue",
            name = "Ladino",
            description = "Assassino ágil especializado em venenos e precisão",
            color = {0.2, 0.8, 0.2, 1.0}, -- RGBA com alpha
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
