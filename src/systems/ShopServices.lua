local Debug = require("src.core.Debug")

local Config = require("src.core.Config")

local ShopServices = {}

ShopServices.CATALOG = {
    { id = "remove_card",    effect = "remove_card",    picker = "remove",    weight = 0,   fixture = true },
    { id = "duplicate_card", effect = "duplicate_card", picker = "duplicate", weight = 0.8 },
    { id = "joker_slot",     effect = "add_joker_slot", weight = 0,   fixture = true },
    { id = "card_draw_upgrade", effect = "increase_draw", weight = 0.8 },
    { id = "interest_cap",   effect = "raise_interest_cap", weight = 0.7,
      valueKey = "INTEREST_CAP_PER_BUY" },
}

local BY_ID = {}
for _, s in ipairs(ShopServices.CATALOG) do BY_ID[s.id] = s end

function ShopServices.get(id)
    return BY_ID[id]
end

function ShopServices.tuning(id)
    local cfg = (Config.Offers and Config.Offers.SERVICES or {})[id]
    if not cfg then
        Debug.warn("[ShopServices] servico sem tuning em Config.Offers.SERVICES: "
            .. tostring(id))
    end
    return cfg
end

function ShopServices.value(id)
    local svc = BY_ID[id]
    if not svc then return 1 end
    if svc.valueKey then
        local v = Config.Offers and Config.Offers[svc.valueKey]
        if v then return v end
        Debug.warn("[ShopServices] valueKey ausente em Config.Offers: "
            .. tostring(svc.valueKey) .. " (servico " .. tostring(id) .. ")")
    end
    return 1
end

function ShopServices.count(id, runManager)
    if not runManager or not runManager.getServiceCount then return 0 end
    return runManager:getServiceCount(id)
end

function ShopServices.cost(id, runManager)
    local cfg = ShopServices.tuning(id)
    if not cfg then return nil end
    local n = ShopServices.count(id, runManager)
    local raw = cfg.base * (cfg.mult ^ n)
    return math.min(cfg.max, math.floor(raw + 0.5))
end

function ShopServices.isAvailable(id, runManager)
    local cfg = ShopServices.tuning(id)
    if not cfg then return false end
    if not runManager or not runManager.currentRun then return false end

    local maxPerRun = cfg.maxPerRun or 0
    if maxPerRun > 0 and ShopServices.count(id, runManager) >= maxPerRun then
        return false
    end

    if cfg.minDeck then
        local deck = runManager.currentRun.currentDeck or {}
        if #deck < cfg.minDeck then return false end
    end

    return true
end

local BENCH_PRESSURE_MULT = 3.0

function ShopServices.weight(id, runManager)
    local svc = BY_ID[id]
    if not svc then return 0 end
    local w = svc.weight or 0

    if id == "joker_slot" and runManager and runManager.currentRun
        and runManager.getActiveJokerCount then
        local possuidos = #(runManager.currentRun.jokers or {})
        if possuidos > runManager:getActiveJokerCount() then
            w = w * BENCH_PRESSURE_MULT
        end
    end

    return w
end

function ShopServices.deckFingerprint(runManager)
    if not runManager or not runManager.currentRun then return 0 end
    local deck = runManager.currentRun.currentDeck or {}
    local levels = 0
    for i = 1, #deck do
        levels = levels + (runManager:getEntryLevel(deck[i]) or 0)
    end
    return #deck * 4096 + levels
end

return ShopServices
