local Debug = require("src.core.Debug")

local BoosterPackSystem = {}

local CardDatabase = require("src.systems.CardDatabase")
local Rng = require("src.systems.Rng")

local EDITION_RATES = {
    { name = "polychrome", rate = 0.075 },
    { name = "holo",       rate = 0.05 },
    { name = "foil",       rate = 0.10 },
}

local SEAL_RATE = 0.20
local SEAL_TYPES = { "Red", "Blue", "Gold", "Purple" }

local BUFFOON_RARITY_WEIGHT = { common = 1.0, uncommon = 1.0, rare = 0.6, legendary = 0.15 }

local function pollEdition()
    local r = Rng.get():random("shop")
    local cumulative = 0
    for _, e in ipairs(EDITION_RATES) do
        cumulative = cumulative + e.rate
        if r < cumulative then return e.name end
    end
    return nil
end

local function pollSeal()
    local rng = Rng.get()
    if rng:random("shop") >= SEAL_RATE then return nil end
    return SEAL_TYPES[rng:random("shop", #SEAL_TYPES)]
end

local function sortedIds(all)
    local UnlockSystem = require("src.systems.UnlockSystem")
    local ids = {}
    for id in pairs(all) do
        if UnlockSystem.isCardUnlocked(id) then table.insert(ids, id) end
    end
    table.sort(ids)
    return ids
end

local function classOk(c, classId)
    if c.class == "boss" then return false end
    return classId == nil or c.class == nil or c.class == "basic" or c.class == classId
end

function BoosterPackSystem.generateContents(pack)
    local kind = pack.kind or "Standard"
    local size = pack.size or 3
    local classId = pack.classId

    local cd = CardDatabase:new()
    local all = cd:getAllCards()
    local allIds = sortedIds(all)
    local rng = Rng.get()
    local instances = {}

    local function addInstance(cardId, withModifiers)
        local cardData = cardId and cd:getCard(cardId)
        if not cardData then return end
        local instance = cd:createCardInstance(cardData)
        if require("src.systems.UnlockSystem").markDiscovered(cardId) then
            instance.isNewDiscovery = true
        end
        instance.shopOffer = nil
        if withModifiers then
            local edition = pollEdition()
            if edition then instance.edition = edition end
            local seal = pollSeal()
            if seal then instance.seal = seal end
        end
        table.insert(instances, instance)
    end

    if kind == "Buffoon" then
        local owned = pack.ownedJokerIds or {}
        local pickedInPack = {}
        for _ = 1, size do
            local entries = {}
            for _, id in ipairs(allIds) do
                local c = all[id]
                if c.type == "joker" and classOk(c, classId)
                    and not owned[id] and not pickedInPack[id] then
                    table.insert(entries, { item = id, weight = BUFFOON_RARITY_WEIGHT[c.rarity] or 1.0 })
                end
            end
            if #entries == 0 then break end
            local cardId = rng:weighted("shop", entries)
            pickedInPack[cardId] = true
            addInstance(cardId, false)
        end
        return instances
    end

    local pool = {}
    for _, id in ipairs(allIds) do
        local c = all[id]
        local typeOk = c.type == "attack" or c.type == "defense" or c.type == "effect"
        if typeOk and classOk(c, classId) then table.insert(pool, id) end
    end
    if #pool == 0 then return instances end

    local rarityWeights = (kind ~= "Standard") and pack.rarityWeights or nil
    local weightedEntries = nil
    if rarityWeights then
        weightedEntries = {}
        for _, id in ipairs(pool) do
            local c = all[id]
            local w = rarityWeights[c.rarity] or 0
            if kind == "Spectral" and (c.rarity == "common" or c.rarity == "basic") then
                w = 0
            end
            table.insert(weightedEntries, { item = id, weight = w })
        end
        if kind == "Spectral" then
            local soma = 0
            for _, e in ipairs(weightedEntries) do soma = soma + (e.weight or 0) end
            if soma <= 0 then
                Debug.warn("[BoosterPack] Espectral sem incomum+ na pool — caindo nos pesos normais")
                weightedEntries = {}
                for _, id in ipairs(pool) do
                    local c = all[id]
                    table.insert(weightedEntries, { item = id, weight = rarityWeights[c.rarity] or 0 })
                end
            end
        end
    end

    for _ = 1, size do
        local cardId
        if weightedEntries then
            cardId = rng:weighted("shop", weightedEntries)
        else
            cardId = pool[rng:random("shop", #pool)]
        end
        addInstance(cardId, kind == "Standard")
    end

    return instances
end

function BoosterPackSystem.expandPackRecord(packRecord, classId, opts)
    opts = opts or {}
    local pack = {
        id = packRecord.id,
        kind = packRecord.kind or "Standard",
        size = packRecord.size or 3,
        choose = packRecord.choose or 1,
        classId = classId,
    }

    local run = opts.runManager and opts.runManager.currentRun
    if run and run.jokers then
        local owned = {}
        for _, entry in ipairs(run.jokers) do
            local id = type(entry) == "table" and entry.id or entry
            if id then owned[id] = true end
        end
        pack.ownedJokerIds = owned
    end

    if opts.actNumber then
        local ActSystem = require("src.systems.ActSystem")
        pack.rarityWeights = ActSystem.getRarityWeights(opts.actNumber)
    end

    pack.instances = BoosterPackSystem.generateContents(pack)
    return pack
end

return BoosterPackSystem
