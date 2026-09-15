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
    -- Teto BASE (o que toda corrida começa tendo). O teto EFETIVO é
    -- `baseInterestCap + bonusInterestCap`, e o bônus é comprado na loja
    -- (relíquia "Cofre" — ver setBonusInterestCap abaixo).
    instance.baseInterestCap = 5
    instance.bonusInterestCap = 0
    instance.interestCap = 5   -- máximo de juros por batalha (base + bonus)
    
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

-- Estorna uma compra que NÃO se concretizou (o jogador pagou pelo serviço da
-- loja e fechou o picker de carta sem escolher nada).
--
-- Não é `earnGold`: estorno não é RENDA. Somar em totalGoldEarned inflaria o
-- "ganho da run" que a tela de fim de corrida mostra e mentiria nas
-- estatísticas. Aqui a compra é DESFEITA: o ouro volta, o gasto desce e a
-- linha some do histórico.
function EconomySystem:refundPurchase(amount, itemType, itemId)
    amount = amount or 0
    if amount <= 0 then return 0 end
    self.currentGold = self.currentGold + amount
    self.goldSpent = math.max(0, self.goldSpent - amount)

    -- Remove a ÚLTIMA compra igual do histórico (a que está sendo desfeita).
    for i = #self.purchaseHistory, 1, -1 do
        local h = self.purchaseHistory[i]
        if h.cost == amount and (itemId == nil or h.itemId == itemId)
            and (itemType == nil or h.itemType == itemType) then
            table.remove(self.purchaseHistory, i)
            break
        end
    end

    return amount
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

-- ===== TETO DE JUROS COMPRÁVEL (Set/2026) =====
--
-- O teto efetivo é `base + bonus`, e o bônus é DERIVADO do ledger de serviços
-- da run (quantas vezes a relíquia "Cofre" foi comprada). Este objeto guarda
-- só o espelho: a fonte da verdade é `currentRun.services.interest_cap`, que
-- viaja no save. Game:syncInterestCap faz o espelhamento, do mesmo jeito que
-- syncArmorCap espelha o cap de armadura por ato.
--
-- O espelho existe porque `calculateInterest` é chamado TODO FRAME pela
-- TopBar: perguntar ao RunManager ali acoplaria economia a progressão por
-- causa de um número que muda uma vez por compra.
function EconomySystem:setBonusInterestCap(bonus)
    local Config = require("src.core.Config")
    bonus = math.max(0, math.floor(bonus or 0))
    local teto = (Config.Offers and Config.Offers.INTEREST_CAP_MAX) or 25
    local base = self.baseInterestCap or 5
    -- O guarda-corpo limita o TOTAL, não o bônus: um dia a base pode mudar.
    self.bonusInterestCap = math.max(0, math.min(bonus, teto - base))
    self.interestCap = base + self.bonusInterestCap
    return self.interestCap
end

function EconomySystem:getInterestCap()
    return self.interestCap or (self.baseInterestCap or 5)
end

-- Juros da próxima batalha (Balatro: $1 a cada $5, teto comprável). Inteiro.
function EconomySystem:calculateInterest()
    return math.min(math.floor((self.currentGold or 0) / self.interestPer),
        self:getInterestCap())
end

return EconomySystem
