local I18n = require("src.i18n.I18n")

local CounterJokers = {}

CounterJokers.EFFECTS = { counter_debuff = true, counter_frost = true, counter_sight = true }

CounterJokers.DEBUFFS = { poison = true, burn = true, weak = true, frail = true, vulnerable = true }

CounterJokers.OFFER_WEIGHT = 0.4

CounterJokers.IDLE_OFFER_WEIGHT = 0.12

CounterJokers.PILOT_SCORE = {
    poison = 14, burn = 12, weak = 14, frail = 10, vulnerable = 14,
    frost = 20, fog = 12,
}

local games = setmetatable({}, { __mode = "k" })

function CounterJokers.bind(game)
    if game then games[game] = true end
end

function CounterJokers.gameOf(enemy)
    if not enemy then return nil end
    for g in pairs(games) do
        if g.enemy == enemy then return g end
    end
    return nil
end

function CounterJokers.threatOf(effect)
    if not effect then return nil end
    if effect.type == "counter_debuff" then return effect.debuffName end
    if effect.type == "counter_frost" then return "frost" end
    if effect.type == "counter_sight" then return "fog" end
    return nil
end

function CounterJokers.threatOfCard(cd)
    if not cd or cd.type ~= "joker" then return nil end
    for _, e in ipairs(cd.effects or {}) do
        local t = CounterJokers.threatOf(e)
        if t then return t end
    end
    return nil
end

function CounterJokers.find(game, effectType, debuff)
    for _, joker in ipairs((game and game.jokerSlots) or {}) do
        for _, e in ipairs(joker.effects or {}) do
            if e.type == effectType and (debuff == nil or e.debuffName == debuff) then
                return joker, e
            end
        end
    end
    return nil
end

local function proc(game, joker, label, kind)
    if game and game.effectSystem and game.effectSystem.notifyJokerProc then
        game.effectSystem:notifyJokerProc(game, joker, label, kind or "buff")
    end
    if game then
        game._counterProcs = (game._counterProcs or 0) + 1
    end
end

local function statusName(name)
    return I18n.t("status." .. name .. ".name", nil,
        I18n.t("enemy_kit.status." .. name .. ".name", nil, name))
end

function CounterJokers.blocksDebuff(game, name)
    local joker, e = CounterJokers.find(game, "counter_debuff", name)
    if not (e and e.type == "counter_debuff") then return false end
    proc(game, joker, I18n.t("counter_jokers.proc.immune", { status = statusName(name) },
        "Imune: " .. statusName(name)), "buff")
    return true
end

function CounterJokers.frostGain(game, n)
    if (n or 0) <= 0 then return n end
    local joker, e = CounterJokers.find(game, "counter_frost")
    if not (e and e.type == "counter_frost") then return n end
    proc(game, joker, I18n.t("counter_jokers.proc.frost", { value = n }, "-" .. n), "armor")
    return 0
end

function CounterJokers.freezeCount(game, n)
    if (n or 0) <= 0 then return n end
    local joker, e = CounterJokers.find(game, "counter_frost")
    if not (e and e.type == "counter_frost") then return n end
    proc(game, joker, I18n.t("counter_jokers.proc.thaw", nil, "Degelo"), "armor")
    return 0
end

function CounterJokers.filterVisibility(enemy, level, cause)
    if level == "full" or level == nil then return level, cause end
    local game = CounterJokers.gameOf(enemy)
    if not game then return level, cause end
    local joker, e = CounterJokers.find(game, "counter_sight")
    if not (e and e.type == "counter_sight") then return level, cause end
    proc(game, joker, I18n.t("counter_jokers.proc.sight", nil, "Revelado"), "info")
    return "full", "lantern"
end

local threatCache = {}

local function kitThreats(kit, out)
    if not kit then return end
    local function scanMoves(moves)
        for _, m in ipairs(moves or {}) do
            local d = m.debuff
            if d then
                if d.name then d = { d } end
                for _, x in ipairs(d) do
                    if x.name then out[x.name] = (out[x.name] or 0) + 1 end
                end
            end
        end
    end
    scanMoves(kit.moves)
    if kit.veil then out.fog = (out.fog or 0) + 1 end
    for _, ph in ipairs(kit.phases or {}) do
        scanMoves(ph.moves)
        if ph.veil then out.fog = (out.fog or 0) + 1 end
    end
    if kit.mechanic and kit.mechanic.kind == "frost" then
        out.frost = (out.frost or 0) + 1
    end
end

function CounterJokers.actThreats(act)
    act = ((math.max(1, act or 1) - 1) % 6) + 1
    if threatCache[act] then return threatCache[act] end
    local Enemies = require("src.data.enemies")
    local roster = Enemies.ROSTER[act] or {}
    local count = {}
    for _, kind in ipairs({ "battle", "elite", "mini_boss", "boss" }) do
        for _, id in ipairs(roster[kind] or {}) do
            local found = {}
            kitThreats(Enemies.KITS[id], found)
            for k in pairs(found) do count[k] = (count[k] or 0) + 1 end
        end
    end
    local biomes = require("src.data.biomes")
    local list = biomes.list or biomes
    local b = list[act]
    local fog = require("src.data.intent_fog")
    if b and fog.biomes[b.id] then count.fog = 7 end
    threatCache[act] = count
    return count
end

function CounterJokers.isRelevant(threat, act)
    if not threat then return true end
    for _, a in ipairs({ act or 1, (act or 1) + 1 }) do
        if (CounterJokers.actThreats(a)[threat] or 0) > 0 then return true end
    end
    return false
end

function CounterJokers.offerWeight(cd, act)
    local threat = CounterJokers.threatOfCard(cd)
    if not threat then return 1 end
    return CounterJokers.isRelevant(threat, act) and CounterJokers.OFFER_WEIGHT
        or CounterJokers.IDLE_OFFER_WEIGHT
end

function CounterJokers.pilotScore(effect, act)
    local threat = CounterJokers.threatOf(effect)
    if not threat then return nil end
    local n = CounterJokers.actThreats(act)[threat] or 0
    if n <= 0 then return 0 end
    local base = CounterJokers.PILOT_SCORE[threat] or 8
    if threat == "frost" then return base end
    return base * math.min(1, n / 3)
end

return CounterJokers
