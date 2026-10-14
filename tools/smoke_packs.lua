local BoosterPackSystem = require("src.systems.BoosterPackSystem")
local RunManager = require("src.systems.RunManager")

local M = {}

function M.run()
    local pass, fail = 0, 0
    local function check(name, cond)
        if cond then pass = pass + 1; print("  [ok] " .. name)
        else fail = fail + 1; print("  [FAIL] " .. name) end
    end

    print("---- BoosterPackSystem (Fase 5.1) ----")

    local pack = { kind = "Standard", size = 3, choose = 1, classId = "warrior" }
    local instances = BoosterPackSystem.generateContents(pack)
    check("Standard pack gera 3 instances", #instances == 3)

    for i, c in ipairs(instances) do
        check("instance " .. i .. " tem image", c and c.image ~= nil)
        check("instance " .. i .. " tem id", c and c.id ~= nil)
    end

    local buffoon = BoosterPackSystem.generateContents({ kind = "Buffoon", size = 2 })
    check("Buffoon pack gera 2 instances", #buffoon == 2)
    local allJokers = true
    for _, c in ipairs(buffoon) do
        if c.type ~= "joker" then allJokers = false; break end
    end
    check("Buffoon só gera jokers", allJokers)

    math.randomseed(42); love.math.setRandomSeed(42)
    local hasEdition = false
    local hasSeal = false
    for _ = 1, 50 do
        local p = BoosterPackSystem.generateContents({ kind = "Standard", size = 3, classId = "warrior" })
        for _, c in ipairs(p) do
            if c.edition then hasEdition = true end
            if c.seal then hasSeal = true end
        end
        if hasEdition and hasSeal then break end
    end
    check("Standard pack eventualmente gera edition em alguma carta", hasEdition)
    check("Standard pack eventualmente gera seal em alguma carta", hasSeal)

    local pkr = BoosterPackSystem.expandPackRecord({
        id = "pack_standard", kind = "Standard", size = 3, choose = 1
    }, "warrior")
    check("expandPackRecord retorna pack com instances", pkr.instances ~= nil and #pkr.instances == 3)
    check("expandPackRecord preserva choose", pkr.choose == 1)

    print()
    print("---- Persistência de edition/seal por cópia (Fase 5.4) ----")

    local rm = RunManager:new()
    rm:startNewRun("warrior")

    rm:addCardToDeck("warrior_strike")
    rm:addCardToDeck("warrior_strike", { edition = "foil", seal = "Red" })

    local deck = rm:buildPlayableDeck()
    local normal, modified = nil, nil
    for _, c in ipairs(deck) do
        if c.id == "warrior_strike" then
            if c.edition == "foil" then modified = c
            elseif not c.edition then normal = c end
        end
    end
    check("deck tem cópia normal de warrior_strike", normal ~= nil)
    check("deck tem cópia foil de warrior_strike", modified ~= nil)
    check("cópia foil tem seal Red", modified and modified.seal == "Red")
    check("cópia normal não tem seal", normal and normal.seal == nil)

    local BPS = require("src.systems.BoosterPackSystem")
    require("tools.testkit").seedRng(20260914)
    local pesosA3 = { basic = 0, common = 15, uncommon = 45, rare = 32, legendary = 8 }
    local comuns, total = 0, 0
    for _ = 1, 40 do
        local conteudo = BPS.generateContents({
            kind = "Spectral", size = 2, classId = "warrior",
            rarityWeights = pesosA3,
        })
        for _, c in ipairs(conteudo) do
            total = total + 1
            if c.rarity == "common" or c.rarity == "basic" then comuns = comuns + 1 end
        end
    end
    check("Espectral gerou cartas (" .. total .. ")", total > 0)
    check("Espectral NAO traz comum nem basic (" .. comuns .. " de " .. total .. ")", comuns == 0)

    local comunsArcana = 0
    for _ = 1, 40 do
        for _, c in ipairs(BPS.generateContents({
            kind = "Arcana", size = 3, classId = "warrior", rarityWeights = pesosA3,
        })) do
            if c.rarity == "common" then comunsArcana = comunsArcana + 1 end
        end
    end
    check("Arcano ainda traz comuns (" .. comunsArcana .. ")", comunsArcana > 0)

    print()
    print("  TOTAL: " .. pass .. " pass / " .. fail .. " fail")
    return fail == 0
end

return M
