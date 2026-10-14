local EconomySystem = {}
EconomySystem.__index = EconomySystem

function EconomySystem:new()
    local instance = setmetatable({}, EconomySystem)

    instance.currentGold = 0
    instance.totalGoldEarned = 0
    instance.goldSpent = 0

    instance.interestPer = 5
    instance.baseInterestCap = 5
    instance.bonusInterestCap = 0
    instance.interestCap = 5

    instance.purchaseHistory = {}

    return instance
end

function EconomySystem:spendGold(amount, itemType, itemId)
    if self.currentGold >= amount then
        self.currentGold = self.currentGold - amount
        self.goldSpent = self.goldSpent + amount

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

function EconomySystem:refundPurchase(amount, itemType, itemId)
    amount = amount or 0
    if amount <= 0 then return 0 end
    self.currentGold = self.currentGold + amount
    self.goldSpent = math.max(0, self.goldSpent - amount)

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

function EconomySystem:canAfford(amount)
    return self.currentGold >= amount
end

function EconomySystem:earnGold(amount, source)
    amount = amount or 0
    if amount <= 0 then return 0 end
    self.currentGold = self.currentGold + amount
    self.totalGoldEarned = self.totalGoldEarned + amount
    return amount
end

function EconomySystem:getStats()
    return {
        currentGold = self.currentGold,
        totalEarned = self.totalGoldEarned,
        totalSpent = self.goldSpent,
        netWorth = self.totalGoldEarned - self.goldSpent,
        purchaseCount = #self.purchaseHistory
    }
end

function EconomySystem:resetForNewRun()
    self.currentGold = 0
    self.totalGoldEarned = 0
    self.goldSpent = 0
    self.purchaseHistory = {}
    self:setBonusInterestCap(0)
end

function EconomySystem:setBonusInterestCap(bonus)
    local Config = require("src.core.Config")
    bonus = math.max(0, math.floor(bonus or 0))
    local teto = (Config.Offers and Config.Offers.INTEREST_CAP_MAX) or 25
    local base = self.baseInterestCap or 5
    self.bonusInterestCap = math.max(0, math.min(bonus, teto - base))
    self.interestCap = base + self.bonusInterestCap
    return self.interestCap
end

function EconomySystem:getInterestCap()
    return self.interestCap or (self.baseInterestCap or 5)
end

function EconomySystem:calculateInterest()
    return math.min(math.floor((self.currentGold or 0) / self.interestPer),
        self:getInterestCap())
end

return EconomySystem
