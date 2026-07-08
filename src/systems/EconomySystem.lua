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
    
    -- Juros Balatro: $1 a cada $5 guardados, teto $5 (em $25).
    -- FONTE ÚNICA — TopBar (preview) e RoundEval (pagamento) usam
    -- calculateInterest(); antes cada um tinha fórmula própria (10% float
    -- vs floor/5) e o número prometido nunca batia com o pago.
    instance.interestPer = 5   -- $1 por cada N de ouro
    instance.interestCap = 5   -- máximo de juros por batalha
    
    -- Histórico de gastos
    instance.purchaseHistory = {}
    
    return instance
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

-- Ganho avulso (eventos, seal Gold, jokers que dão ouro). Não é battle gold —
-- não compõe stats de "ganho por batalha".
function EconomySystem:earnGold(amount, source)
    amount = amount or 0
    if amount <= 0 then return 0 end
    self.currentGold = self.currentGold + amount
    self.totalGoldEarned = self.totalGoldEarned + amount
    return amount
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

-- Juros da próxima batalha (Balatro: $1 a cada $5, cap $5). Inteiro sempre.
function EconomySystem:calculateInterest()
    return math.min(math.floor((self.currentGold or 0) / self.interestPer),
        self.interestCap)
end

return EconomySystem
