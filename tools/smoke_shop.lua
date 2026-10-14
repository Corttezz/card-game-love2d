local ShopSystem = require("src.systems.ShopSystem")

local M = {}

function M.run()
    local pass, fail = 0, 0
    local function check(name, cond)
        if cond then pass = pass + 1; print("  [ok] " .. name)
        else fail = fail + 1; print("  [FAIL] " .. name) end
    end

    print("---- ShopSystem (Fase 4) ----")

    local shop = ShopSystem:new()

    check("default mode é shop", shop.mode == "shop")
    check("getModeConfig retorna config válido", shop:getModeConfig() ~= nil)

    shop:setMode("rewards")
    local cfg = shop:getModeConfig()
    check("rewards: 3 cartas", cfg.cards == 3)
    check("rewards: sem upgrades", cfg.upgrades == 0)
    check("rewards: sem boosters", cfg.boosters == 0)
    check("rewards: canReroll false", cfg.canReroll == false)

    shop:generateOffers()
    local offers = shop:getCurrentOffers()
    check("rewards gera ~3 ofertas", #offers >= 1 and #offers <= 3)
    local typeCounts = { card = 0, upgrade = 0, booster_pack = 0 }
    for _, o in ipairs(offers) do typeCounts[o.type] = (typeCounts[o.type] or 0) + 1 end
    check("rewards: nenhum upgrade", typeCounts.upgrade == 0)
    check("rewards: nenhum booster", typeCounts.booster_pack == 0)

    shop:setMode("shop")
    cfg = shop:getModeConfig()
    check("shop: 4 cartas", cfg.cards == 4)
    check("shop: 3 vagas de reliquia", cfg.upgrades == 3)
    check("shop: 1 booster", cfg.boosters == 1)
    check("shop: canReroll true", cfg.canReroll == true)
    check("shop: skipBonus 3", cfg.skipBonus == 3)

    shop:generateOffers()
    offers = shop:getCurrentOffers()
    typeCounts = { card = 0, upgrade = 0, booster_pack = 0 }
    for _, o in ipairs(offers) do typeCounts[o.type] = (typeCounts[o.type] or 0) + 1 end
    check("shop gera mistura de tipos", typeCounts.card > 0 and typeCounts.booster_pack > 0)
    check("shop tem ~8 ofertas", #offers >= 5 and #offers <= 8)
    check("sem run, nenhuma vaga vira servico",
        typeCounts.upgrade > 0 and (function()
            for _, o in ipairs(offers) do if o.isService then return false end end
            return true
        end)())

    local pack
    for _, o in ipairs(offers) do
        if o.type == "booster_pack" then pack = o; break end
    end
    check("booster offer tem id", pack and pack.id ~= nil)
    check("booster offer tem kind", pack and pack.kind ~= nil)
    check("booster offer tem size", pack and pack.size ~= nil)
    check("booster offer tem choose", pack and pack.choose ~= nil)
    check("booster offer tem cost > 0", pack and pack.cost > 0)

    shop = ShopSystem:new()
    shop:setMode("shop")
    check("reroll inicial = 4", shop:getRefreshCost() == 4)
    shop:refreshOffers()
    check("após 1 reroll, custo > 4", shop:getRefreshCost() > 4)
    shop:refreshOffers()
    local after2 = shop:getRefreshCost()
    shop:refreshOffers()
    local after3 = shop:getRefreshCost()
    check("reroll cresce monotonicamente", after3 > after2)
    check("3 rerolls produz 10 (4 + 2*3)", after3 == 10)

    shop:setMode("shop")
    check("setMode reseta refresh count", shop:getRefreshCost() == 4)

    local types = ShopSystem.getBoosterTypes()
    check("getBoosterTypes retorna lista", types ~= nil and #types > 0)
    check("tem 5 tipos de pack", #types == 5)

    print()
    print("  TOTAL: " .. pass .. " pass / " .. fail .. " fail")
    return fail == 0
end

return M
