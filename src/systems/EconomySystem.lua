-- src/systems/EconomySystem.lua
-- Sistema de economia inspirado no TFT e Balatro

local EconomySystem = {}
EconomySystem.__index = EconomySystem

function EconomySystem:new()
    local instance = setmetatable({}, EconomySystem)
    
    -- Estado da economia
    instance.currentGold = 0
    instance.totalGoldEarned = 0
    instance.goldSpent = 0
    
    -- Configurações de ganho de ouro
    instance.baseGoldPerBattle = 10
    instance.goldPerPhase = 5
    instance.bonusGoldThreshold = 3 -- Fases sem perder vida = bonus
    
    -- Sistema de juros (como TFT)
    instance.interestRate = 0.1 -- 10% de juros
    instance.maxInterestGold = 50 -- Máximo de ouro para juros
    
    -- Histórico de gastos
    instance.purchaseHistory = {}
    
    return instance
end

-- Ganha ouro após vencer uma batalha
function EconomySystem:earnBattleGold(phase, healthLost, consecutiveWins)
    local goldEarned = self.baseGoldPerBattle + (phase * self.goldPerPhase)
    
    -- Bonus por não perder vida
    if healthLost == 0 then
        goldEarned = goldEarned + 5
    end
    
    -- Bonus por vitórias consecutivas
    if consecutiveWins >= self.bonusGoldThreshold then
        goldEarned = goldEarned + (consecutiveWins * 2)
    end
    
    -- Aplica juros (como TFT)
    local interestGold = math.min(self.currentGold * self.interestRate, self.maxInterestGold)
    goldEarned = goldEarned + interestGold
    
    self.currentGold = self.currentGold + goldEarned
    self.totalGoldEarned = self.totalGoldEarned + goldEarned
    
    return goldEarned
end

-- Gasta ouro
function EconomySystem:spendGold(amount, itemType, itemId)
    if self.currentGold >= amount then
        self.currentGold = self.currentGold - amount
        self.goldSpent = self.goldSpent + amount
        
        -- Registra a compra
        table.insert(self.purchaseHistory, {
            itemType = itemType,
            itemId = itemId,
            cost = amount,
            timestamp = love.timer.getTime()
        })
        
        return true
    end
    return false
end

-- Verifica se pode comprar algo
function EconomySystem:canAfford(amount)
    return self.currentGold >= amount
end

-- Retorna estatísticas da economia
function EconomySystem:getStats()
    return {
        currentGold = self.currentGold,
        totalEarned = self.totalGoldEarned,
        totalSpent = self.goldSpent,
        netWorth = self.totalGoldEarned - self.goldSpent,
        purchaseCount = #self.purchaseHistory
    }
end

-- Reseta economia para nova run
function EconomySystem:resetForNewRun()
    self.currentGold = 0
    self.totalGoldEarned = 0
    self.goldSpent = 0
    self.purchaseHistory = {}
end

-- Calcula juros para próxima batalha
function EconomySystem:calculateInterest()
    return math.min(self.currentGold * self.interestRate, self.maxInterestGold)
end

return EconomySystem
