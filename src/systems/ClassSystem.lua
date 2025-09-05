-- src/systems/ClassSystem.lua
-- Sistema de classes estilo Slay the Spire
-- DEPRECATED: Use CardRegistry para nova funcionalidade

local ClassSystem = {}
ClassSystem.__index = ClassSystem

local CardRegistry = require("src.systems.CardRegistry")

function ClassSystem:new()
    local instance = setmetatable({}, ClassSystem)
    instance.cardRegistry = CardRegistry:new()
    instance.currentClass = nil
    return instance
end

-- Mantém compatibilidade com código existente
-- A definição de classes agora está centralizada no CardRegistry

-- Seleciona uma classe para o jogador
function ClassSystem:selectClass(classId)
    local classInfo = self.cardRegistry:getClassInfo(classId)
    if not classInfo then
        error("Classe não encontrada: " .. tostring(classId))
    end
    
    self.currentClass = classId
    return classInfo
end

-- Retorna informações da classe atual
function ClassSystem:getCurrentClass()
    if not self.currentClass then return nil end
    return self.cardRegistry:getClassInfo(self.currentClass)
end

-- Retorna deck inicial da classe
function ClassSystem:getStarterDeck(classId)
    local targetClass = classId or self.currentClass
    return self.cardRegistry:getStarterDeckForClass(targetClass)
end

-- Retorna pool de cartas da classe para recompensas
function ClassSystem:getClassCardPool(classId, rarity)
    local targetClass = classId or self.currentClass
    if not targetClass then return {} end
    
    if rarity then
        return self.cardRegistry:getCardsByClassAndRarity(targetClass, rarity)
    else
        local pool = self.cardRegistry:getClassCardPool(targetClass)
        local allCards = {}
        for _, rarityCards in pairs(pool) do
            for _, cardId in ipairs(rarityCards) do
                table.insert(allCards, cardId)
            end
        end
        return allCards
    end
end

-- Gera recompensas de cartas após batalha
function ClassSystem:generateCardRewards(numCards)
    if not self.currentClass then return {} end
    return self.cardRegistry:generateCardRewards(self.currentClass, numCards)
end

-- Sistema de raridade (probabilidades do Slay the Spire)
function ClassSystem:rollRarity()
    return self.cardRegistry:rollRarity()
end

-- Verifica se uma carta pertence à classe
function ClassSystem:isClassCard(cardId, classId)
    local targetClass = classId or self.currentClass
    if not targetClass then return false end
    return self.cardRegistry:isClassCard(cardId, targetClass)
end

-- Retorna todas as classes disponíveis
function ClassSystem:getAllClasses()
    return self.cardRegistry:getAllClasses()
end

-- Retorna características da classe
function ClassSystem:getClassTraits(classId)
    local classInfo = self.cardRegistry:getClassInfo(classId or self.currentClass)
    return classInfo and classInfo.traits or {}
end

return ClassSystem
