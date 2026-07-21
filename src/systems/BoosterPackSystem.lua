-- src/systems/BoosterPackSystem.lua
-- Gera o conteúdo de um booster pack baseado no kind. Aplica edition/seal
-- probabilisticamente em Standard packs (Balatro feel: foil/holo/poly/negative
-- + Red/Blue/Gold/Purple seals).
--
-- P0.6 (rebalance Jul/2026):
--   (a) TODO roll de pack usa o stream "shop" do Rng seedado — packs são
--       decisão de RUN (love.math.random quebrava a reprodutibilidade por seed
--       e o anti-save-scum).
--   (b) Pacote Bufão: pool = jokers da classe + neutros (class 'basic'/nil),
--       pesado por raridade; dedup dentro do pack E contra jokers já
--       possuídos (P0.10 — a posse/coleção fica intocada, a vitrine é que
--       não repete).
--   (c) Arcana/Celestial/Spectral (tarôs/planetas/espectrais continuam
--       pendentes como tipos próprios): o fallback deixa de ser o pool GLOBAL
--       e vira classe do jogador + neutras, com pesos de raridade por ato.
--
-- Uso:
--   local pack = { kind = "Standard", size = 3, classId = "warrior" }
--   local contents = BoosterPackSystem.generateContents(pack)
--   -- contents = { cardInstance, cardInstance, cardInstance }

local BoosterPackSystem = {}

local CardDatabase = require("src.systems.CardDatabase")
local Rng = require("src.systems.Rng")

-- Rates "garantidas" pra Standard pack (Balatro: base × 25 multiplier
-- aplicado quando o pack força roll). Soma ~30% chance de ter edition.
local EDITION_RATES = {
    { name = "negative",   rate = 0.075 },
    { name = "polychrome", rate = 0.075 },
    { name = "holo",       rate = 0.05 },
    { name = "foil",       rate = 0.10 },
}

local SEAL_RATE = 0.20  -- 20% chance de ter qualquer seal
local SEAL_TYPES = { "Red", "Blue", "Gold", "Purple" }

-- Peso por raridade dos jokers no Pacote Bufão (P0.6b): legendaries são
-- raros de sair mesmo no pack dedicado.
local BUFFOON_RARITY_WEIGHT = { common = 1.0, uncommon = 1.0, rare = 0.6, legendary = 0.15 }

-- Retorna nome de edition (foil/holo/...) ou nil se nada rolou.
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

-- IDs ordenados: pairs() não tem ordem estável e o pool alimenta rolls
-- seedados — sem sort, a mesma seed daria packs diferentes por sessão
-- (mesma razão do sort em CardRegistry:getCardsByClassAndRarity).
local function sortedIds(all)
    local ids = {}
    for id in pairs(all) do table.insert(ids, id) end
    table.sort(ids)
    return ids
end

-- Neutra ofertável = class nil OU 'basic' (espelha o P0.1 do CardRegistry).
local function classOk(c, classId)
    return classId == nil or c.class == nil or c.class == "basic" or c.class == classId
end

-- pack: { kind, size, classId, choose, ownedJokerIds?, rarityWeights? }
--   ownedJokerIds — set { [jokerId]=true } (P0.10, só Buffoon usa)
--   rarityWeights — pesos por ato (P0.6c, Arcana/Celestial/Spectral usam)
-- Retorna lista de instances.
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
        instance.shopOffer = nil  -- contraste com cards na shop
        if withModifiers then
            local edition = pollEdition()
            if edition then instance.edition = edition end
            local seal = pollSeal()
            if seal then instance.seal = seal end
        end
        table.insert(instances, instance)
    end

    if kind == "Buffoon" then
        -- P0.6b: jokers da classe + neutros, pesados por raridade, sem repetir
        -- dentro do pack nem oferecer joker já possuído (P0.10).
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
            if #entries == 0 then break end  -- pool esgotada: pack sai menor
            local cardId = rng:weighted("shop", entries)
            pickedInPack[cardId] = true
            addInstance(cardId, false)
        end
        return instances
    end

    -- Standard / Arcana / Celestial / Spectral: attack/defense/effect da
    -- classe + neutras (P0.6c: o fallback dos packs "especiais" não vaza mais
    -- carta de outra classe).
    local pool = {}
    for _, id in ipairs(allIds) do
        local c = all[id]
        local typeOk = c.type == "attack" or c.type == "defense" or c.type == "effect"
        if typeOk and classOk(c, classId) then table.insert(pool, id) end
    end
    if #pool == 0 then return instances end

    -- P0.6c: packs não-Standard sorteiam pesado pelos pesos de raridade do ato
    -- (legendary peso 0 no A1 simplesmente não sai; rarity 'basic' fica fora).
    local rarityWeights = (kind ~= "Standard") and pack.rarityWeights or nil
    local weightedEntries = nil
    if rarityWeights then
        weightedEntries = {}
        for _, id in ipairs(pool) do
            local c = all[id]
            table.insert(weightedEntries, { item = id, weight = rarityWeights[c.rarity] or 0 })
        end
    end

    for _ = 1, size do
        local cardId
        if weightedEntries then
            cardId = rng:weighted("shop", weightedEntries)
        else
            cardId = pool[rng:random("shop", #pool)]
        end
        -- Standard packs aplicam edition + seal.
        addInstance(cardId, kind == "Standard")
    end

    return instances
end

-- Helper: dado um pack record (vindo de pendingPacks), retorna metadata pronta
-- pra PackOpenScreen consumir.
-- opts (P0.6/P0.10, opcional): { runManager=, actNumber= } — liga o dedup de
-- joker possuído (Buffoon) e os pesos de raridade por ato (packs especiais).
function BoosterPackSystem.expandPackRecord(packRecord, classId, opts)
    opts = opts or {}
    local pack = {
        id = packRecord.id,
        kind = packRecord.kind or "Standard",
        size = packRecord.size or 3,
        choose = packRecord.choose or 1,
        classId = classId,
    }

    -- P0.10: jokers já possuídos nunca reaparecem na vitrine do pack.
    local run = opts.runManager and opts.runManager.currentRun
    if run and run.jokers then
        local owned = {}
        for _, entry in ipairs(run.jokers) do
            local id = type(entry) == "table" and entry.id or entry
            if id then owned[id] = true end
        end
        pack.ownedJokerIds = owned
    end

    -- P0.6c: pesos de raridade por ato pros packs de fallback.
    if opts.actNumber then
        local ActSystem = require("src.systems.ActSystem")
        pack.rarityWeights = ActSystem.getRarityWeights(opts.actNumber)
    end

    pack.instances = BoosterPackSystem.generateContents(pack)
    return pack
end

return BoosterPackSystem
