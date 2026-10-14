local Debug = require("src.core.Debug")

local Config = require("src.core.Config")
local Rng = require("src.systems.Rng")

local ScribeDice = {}

local function cfg()
    local c = Config.Economy and Config.Economy.DICE
    if not c then
        Debug.warn("[ScribeDice] Config.Economy.DICE ausente — mini-jogo desligado")
    end
    return c
end

ScribeDice.BET_IDS = { "low", "seven", "high" }

local RANGES = {
    low   = { 2, 6 },
    seven = { 7, 7 },
    high  = { 8, 12 },
}

function ScribeDice.wins(betId, sum)
    local r = RANGES[betId]
    return r ~= nil and sum >= r[1] and sum <= r[2]
end

function ScribeDice.chance(betId)
    local n = 0
    for a = 1, 6 do
        for b = 1, 6 do
            if ScribeDice.wins(betId, a + b) then n = n + 1 end
        end
    end
    return n / 36
end

function ScribeDice.payoutMult(betId)
    local c = cfg()
    local m = c and c.PAYOUT and c.PAYOUT[betId]
    if not m then
        Debug.warn("[ScribeDice] aposta sem pagamento no Config: " .. tostring(betId))
        return 0
    end
    return m
end

function ScribeDice.expectedValue(betId)
    return ScribeDice.chance(betId) * ScribeDice.payoutMult(betId)
end

function ScribeDice.payout(betId, stake)
    return math.floor(stake * ScribeDice.payoutMult(betId))
end

function ScribeDice.stakes(act)
    local c = cfg()
    if not c then return {} end
    act = math.max(1, math.floor(tonumber(act) or 1))
    local k = 1 + (c.STAKE_PER_ACT or 0) * (act - 1)
    local out = {}
    for i, base in ipairs(c.STAKES or {}) do
        local v = base * k
        out[i] = math.max(2, 2 * math.floor(v / 2 + 0.5))
    end
    return out
end

function ScribeDice.nodeKey(run)
    return ("dice|%d|%d|%d"):format(run.actNumber or 1, run.floorInAct or 1,
        #(run.mapHistory or {}))
end

function ScribeDice.state(run)
    if not run then return nil end
    local st = run.scribeDice
    if st and st.key ~= ScribeDice.nodeKey(run) then
        run.scribeDice = nil
        return nil
    end
    return st
end

function ScribeDice.isUsed(run)
    local st = ScribeDice.state(run)
    return st ~= nil and st.used == true
end

function ScribeDice.canRoll(run, economy, betId, stake)
    if not cfg() then return false, "disabled" end
    if not run then return false, "no_run" end
    if ScribeDice.isUsed(run) then return false, "used" end
    if not RANGES[betId] then return false, "bad_bet" end
    local valid = false
    for _, s in ipairs(ScribeDice.stakes(run.actNumber)) do
        if s == stake then valid = true end
    end
    if not valid then return false, "bad_stake" end
    if not economy or not economy:canAfford(stake) then return false, "poor" end
    return true
end

function ScribeDice.roll(run, economy, betId, stake)
    local ok, why = ScribeDice.canRoll(run, economy, betId, stake)
    if not ok then return nil, why end

    economy:spendGold(stake, "minigame", "scribe_dice")
    local rng = Rng.get()
    local a = rng:random("shop", 6)
    local b = rng:random("shop", 6)
    local sum = a + b
    local won = ScribeDice.wins(betId, sum)
    local payout = won and ScribeDice.payout(betId, stake) or 0
    if payout > 0 then economy:earnGold(payout, "scribe_dice") end

    local st = {
        key = ScribeDice.nodeKey(run), used = true,
        bet = betId, stake = stake, dice = { a, b }, sum = sum,
        won = won, payout = payout,
    }
    run.scribeDice = st
    return st
end

return ScribeDice
