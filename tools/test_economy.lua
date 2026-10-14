local TK = require("tools.testkit")
local EconomySystem = require("src.systems.EconomySystem")

local M = {}

function M.run()
    local t = TK.new("economia: EconomySystem")

    local eco = EconomySystem:new()
    t:eq("new: currentGold 0", eco.currentGold, 0)

    t:eq("earnGold(10) retorna 10", eco:earnGold(10, "test"), 10)
    t:eq("earnGold soma no cofre", eco.currentGold, 10)
    t:eq("earnGold(0) no-op retorna 0", eco:earnGold(0), 0)
    t:eq("earnGold(negativo) no-op retorna 0", eco:earnGold(-5), 0)
    t:eq("cofre inalterado apos no-ops", eco.currentGold, 10)

    t:truthy("canAfford(10) com 10", eco:canAfford(10))
    t:falsy("canAfford(11) com 10", eco:canAfford(11))
    t:truthy("canAfford(0)", eco:canAfford(0))

    t:truthy("spendGold(4) ok", eco:spendGold(4, "card", "x"))
    t:eq("cofre apos gasto", eco.currentGold, 6)
    t:falsy("spendGold(999) falha", eco:spendGold(999, "card", "y"))
    t:eq("cofre inalterado apos gasto falho", eco.currentGold, 6)

    local s = eco:getStats()
    t:eq("stats.currentGold", s.currentGold, 6)
    t:eq("stats.totalEarned", s.totalEarned, 10)
    t:eq("stats.totalSpent", s.totalSpent, 4)
    t:eq("stats.netWorth = earned - spent", s.netWorth, 6)
    t:eq("stats.purchaseCount", s.purchaseCount, 1)

    local function interestAt(gold)
        local e = EconomySystem:new()
        e.currentGold = gold
        return e:calculateInterest()
    end
    t:eq("juros com 0", interestAt(0), 0)
    t:eq("juros com 4 = 0", interestAt(4), 0)
    t:eq("juros com 5 = 1", interestAt(5), 1)
    t:eq("juros com 9 = 1", interestAt(9), 1)
    t:eq("juros com 20 = 4", interestAt(20), 4)
    t:eq("juros com 25 = 5 (cap)", interestAt(25), 5)
    t:eq("juros com 100 = 5 (cap)", interestAt(100), 5)

    eco:resetForNewRun()
    t:eq("reset zera currentGold", eco.currentGold, 0)
    t:eq("reset zera totalEarned", eco.totalGoldEarned, 0)
    t:eq("reset zera goldSpent", eco.goldSpent, 0)
    t:eq("reset limpa histórico", #eco.purchaseHistory, 0)

    local Config = require("src.core.Config")
    local ShopServices = require("src.systems.ShopServices")
    local ShopSystem = require("src.systems.ShopSystem")
    local PORTA_A1, RENDA_A1 = 26, 10
    local fakeRm = { currentRun = { currentDeck = {} }, n = 0,
        getServiceCount = function(self) return self.n end }
    local slot1 = ShopServices.cost("joker_slot", fakeRm)
    fakeRm.n = 1
    local slot2 = ShopServices.cost("joker_slot", fakeRm)
    t:truthy(("1ª bancada ($%d) cabe na porta da loja do A1 ($%d)"):format(slot1, PORTA_A1),
        slot1 <= PORTA_A1)
    t:truthy(("2ª bancada ($%d) ≤ 1ª + 2 batalhas do A1"):format(slot2), slot2 <= slot1 + 2 * RENDA_A1)
    local shop = ShopSystem:new()
    t:truthy("lendária ≤ porta do A1", shop:calculateCardCost("legendary") <= PORTA_A1)
    t:truthy("reroll inicial ≤ 2 comuns",
        shop:getRefreshCost() <= 2 * shop:calculateCardCost("common"))
    t:truthy("elite paga bônus", Config.Economy.nodeBonus("elite", 1) > 0)
    t:eq("luta comum sem bônus", Config.Economy.nodeBonus("battle", 1), 0)
    t:truthy("chefe paga ao menos o que a elite paga",
        Config.Economy.nodeBonus("boss", 3) >= Config.Economy.nodeBonus("elite", 3))

    return t:done()
end

return M
