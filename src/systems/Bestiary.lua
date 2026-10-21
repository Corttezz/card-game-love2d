local ProfileStats = require("engine.ProfileStats")
local Enemies = require("src.data.enemies")

local Bestiary = {}

Bestiary.TIERS = {
    { node = "battle", tier = "common" },
    { node = "elite", tier = "elite" },
    { node = "mini_boss", tier = "miniboss" },
    { node = "boss", tier = "boss" },
}

local entriesCache = nil
local byId = nil
local runList = nil

local function biomeIdFor(act)
    local ok, biomes = pcall(require, "src.data.biomes")
    local b = ok and type(biomes) == "table" and biomes[act] or nil
    return b and b.id or nil
end

local function build()
    if entriesCache then return end
    entriesCache, byId = {}, {}
    for act = 1, #Enemies.ROSTER do
        local byNode = Enemies.ROSTER[act] or {}
        local biome = biomeIdFor(act)
        for _, t in ipairs(Bestiary.TIERS) do
            for _, id in ipairs(byNode[t.node] or {}) do
                if not byId[id] then
                    local e = { id = id, act = act, biome = biome, tier = t.tier,
                                spriteId = id, index = #entriesCache + 1 }
                    entriesCache[#entriesCache + 1] = e
                    byId[id] = e
                end
            end
        end
    end
end

local function state()
    local s = ProfileStats.get()
    local b = s.bestiary
    if type(b) ~= "table" then
        b = {}
        s.bestiary = b
    end
    b.seen = b.seen or {}
    b.defeated = b.defeated or {}
    b.killedYou = b.killedYou or {}
    b.fresh = b.fresh or {}
    return b
end

function Bestiary.entries()
    build()
    local out = {}
    for i, e in ipairs(entriesCache) do
        out[i] = { id = e.id, act = e.act, biome = e.biome, tier = e.tier,
                   spriteId = e.spriteId }
    end
    return out
end

function Bestiary.entry(id)
    build()
    local e = byId[id]
    if not e then return nil end
    return { id = e.id, act = e.act, biome = e.biome, tier = e.tier, spriteId = e.spriteId }
end

function Bestiary.has(id)
    build()
    return id ~= nil and byId[id] ~= nil
end

function Bestiary.nameKey(id)
    return "end_screen.enemy." .. tostring(id)
end

function Bestiary.kit(id)
    return Enemies.KITS[id]
end

function Bestiary.isSeen(id)
    return (state().seen[id] or 0) > 0
end

function Bestiary.isDefeated(id)
    return (state().defeated[id] or 0) > 0
end

function Bestiary.stats(id)
    local b = state()
    return { seen = b.seen[id] or 0, defeated = b.defeated[id] or 0,
             killedYou = b.killedYou[id] or 0 }
end

function Bestiary.seenCount()
    build()
    local n = 0
    for _, e in ipairs(entriesCache) do
        if Bestiary.isSeen(e.id) then n = n + 1 end
    end
    return n, #entriesCache
end

function Bestiary.markSeen(id)
    if not Bestiary.has(id) then return false end
    local b = state()
    local first = (b.seen[id] or 0) == 0
    b.seen[id] = (b.seen[id] or 0) + 1
    if first then
        b.fresh[id] = true
        if runList then runList[#runList + 1] = id end
    end
    ProfileStats.flush()
    return first
end

function Bestiary.markDefeated(id)
    if not Bestiary.has(id) then return false end
    local b = state()
    if (b.seen[id] or 0) == 0 then Bestiary.markSeen(id) end
    b.defeated[id] = (b.defeated[id] or 0) + 1
    ProfileStats.flush()
    return true
end

function Bestiary.markKilledYou(id)
    if not Bestiary.has(id) then return false end
    local b = state()
    if (b.seen[id] or 0) == 0 then Bestiary.markSeen(id) end
    b.killedYou[id] = (b.killedYou[id] or 0) + 1
    ProfileStats.flush()
    return true
end

function Bestiary.isNew(id)
    return state().fresh[id] == true
end

function Bestiary.clearNew(id)
    local b = state()
    if not b.fresh[id] then return false end
    b.fresh[id] = nil
    ProfileStats.flush()
    return true
end

function Bestiary.anyNew()
    for id in pairs(state().fresh) do
        if Bestiary.has(id) then return true end
    end
    return false
end

function Bestiary.newCount()
    local n = 0
    for id in pairs(state().fresh) do
        if Bestiary.has(id) then n = n + 1 end
    end
    return n
end

function Bestiary.resetRun(run)
    runList = {}
    if run then
        run.bestiaryNew = runList
        run.fightSerial = run.fightSerial or 0
        run.bestiaryFight = nil
    end
end

function Bestiary.attachRun(run)
    if not run then return end
    if type(run.bestiaryNew) ~= "table" then run.bestiaryNew = {} end
    runList = run.bestiaryNew
end

function Bestiary.runNewCount()
    return runList and #runList or 0
end

function Bestiary.runNewIds()
    local out = {}
    for i, id in ipairs(runList or {}) do out[i] = id end
    return out
end

function Bestiary.beginFight(run)
    if not run then return end
    run.fightSerial = (run.fightSerial or 0) + 1
    run.bestiaryFight = nil
end

local MARK = { seen = Bestiary.markSeen, defeated = Bestiary.markDefeated,
               killedYou = Bestiary.markKilledYou }

function Bestiary.onFight(run, id, kind)
    if not run or not Bestiary.has(id) or not MARK[kind] then return false end
    local serial = run.fightSerial or 0
    local rec = run.bestiaryFight
    if type(rec) ~= "table" or rec.serial ~= serial or rec.id ~= id then
        rec = { serial = serial, id = id }
        run.bestiaryFight = rec
    end
    if kind ~= "seen" and not rec.seen then
        rec.seen = true
        Bestiary.markSeen(id)
    end
    if rec[kind] then return false end
    rec[kind] = true
    MARK[kind](id)
    return true
end

function Bestiary._resetForTests()
    runList = nil
    entriesCache, byId = nil, nil
end

return Bestiary
