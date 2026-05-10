-- src/systems/BoosterPackSystem.lua
-- Gera o conteúdo de um booster pack baseado no kind. Aplica edition/seal
-- probabilisticamente em Standard packs (Balatro feel: foil/holo/poly/negative
-- + Red/Blue/Gold/Purple seals).
--
-- Uso:
--   local pack = { kind = "Standard", size = 3, classId = "warrior" }
--   local contents = BoosterPackSystem.generateContents(pack)
--   -- contents = { cardInstance, cardInstance, cardInstance }

local BoosterPackSystem = {}

local CardDatabase = require("src.systems.CardDatabase")

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

-- Retorna nome de edition (foil/holo/...) ou nil se nada rolou.
local function pollEdition()
    local r = love.math.random()
    local cumulative = 0
    for _, e in ipairs(EDITION_RATES) do
        cumulative = cumulative + e.rate
        if r < cumulative then return e.name end
    end
    return nil
end

local function pollSeal()
    if love.math.random() >= SEAL_RATE then return nil end
    return SEAL_TYPES[love.math.random(#SEAL_TYPES)]
end

-- Filtra cardData.cards: retorna IDs de cartas válidas pra um pack tipo `kind`.
-- Standard: cartas attack/defense/effect da classe (ou todas se classId=nil).
-- Buffoon:  jokers de qualquer classe.
local function poolForKind(kind, classId)
    local cd = CardDatabase:new()
    local all = cd:getAllCards()
    local pool = {}

    if kind == "Standard" then
        for id, c in pairs(all) do
            local typeOk = c.type == "attack" or c.type == "defense" or c.type == "effect"
            local classOk = (classId == nil) or (c.class == nil) or (c.class == classId)
            if typeOk and classOk then table.insert(pool, id) end
        end
    elseif kind == "Buffoon" then
        for id, c in pairs(all) do
            if c.type == "joker" then table.insert(pool, id) end
        end
    elseif kind == "Arcana" or kind == "Celestial" or kind == "Spectral" then
        -- Pendente (Fase 5.2): tarots/planets/spectrals como tipos novos.
        -- Por ora cai no pool genérico pra não quebrar.
        for id, c in pairs(all) do table.insert(pool, id) end
    end

    return pool, cd
end

-- pack: { kind, size, classId, choose }
-- Retorna { instances, choose }.
function BoosterPackSystem.generateContents(pack)
    local kind = pack.kind or "Standard"
    local size = pack.size or 3
    local classId = pack.classId

    local pool, cd = poolForKind(kind, classId)
    local instances = {}

    if #pool == 0 then return instances end

    for i = 1, size do
        local cardId = pool[love.math.random(#pool)]
        local cardData = cd:getCard(cardId)
        if cardData then
            local instance = cd:createCardInstance(cardData)
            instance.shopOffer = nil  -- contraste com cards na shop

            -- Standard packs aplicam edition + seal.
            if kind == "Standard" then
                local edition = pollEdition()
                if edition then instance.edition = edition end
                local seal = pollSeal()
                if seal then instance.seal = seal end
            end

            table.insert(instances, instance)
        end
    end

    return instances
end

-- Helper: dado um pack record (vindo de pendingPacks), retorna metadata pronta
-- pra PackOpenScreen consumir.
function BoosterPackSystem.expandPackRecord(packRecord, classId)
    local pack = {
        id = packRecord.id,
        kind = packRecord.kind or "Standard",
        size = packRecord.size or 3,
        choose = packRecord.choose or 1,
        classId = classId,
    }
    pack.instances = BoosterPackSystem.generateContents(pack)
    return pack
end

return BoosterPackSystem
