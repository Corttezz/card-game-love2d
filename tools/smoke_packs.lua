-- tools/smoke_packs.lua
-- Valida BoosterPackSystem + persistência de edition/seal por cópia.
-- love . smoke_packs

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

    -- Standard pack: 3 cartas, deve gerar instances.
    local pack = { kind = "Standard", size = 3, choose = 1, classId = "warrior" }
    local instances = BoosterPackSystem.generateContents(pack)
    check("Standard pack gera 3 instances", #instances == 3)

    for i, c in ipairs(instances) do
        check("instance " .. i .. " tem image", c and c.image ~= nil)
        check("instance " .. i .. " tem id", c and c.id ~= nil)
    end

    -- Buffoon pack: jokers.
    local buffoon = BoosterPackSystem.generateContents({ kind = "Buffoon", size = 2 })
    check("Buffoon pack gera 2 instances", #buffoon == 2)
    -- Cartas devem ser do tipo joker.
    local allJokers = true
    for _, c in ipairs(buffoon) do
        if c.type ~= "joker" then allJokers = false; break end
    end
    check("Buffoon só gera jokers", allJokers)

    -- Edition + seal probabilísticos (Standard só).
    -- Roda muitos packs e conta — deve haver alguma carta com edition.
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

    -- expandPackRecord: helper.
    local pkr = BoosterPackSystem.expandPackRecord({
        id = "pack_standard", kind = "Standard", size = 3, choose = 1
    }, "warrior")
    check("expandPackRecord retorna pack com instances", pkr.instances ~= nil and #pkr.instances == 3)
    check("expandPackRecord preserva choose", pkr.choose == 1)

    print()
    print("---- Persistência de edition/seal por cópia (Fase 5.4) ----")

    local rm = RunManager:new()
    rm:startNewRun("warrior")

    -- Adiciona uma carta normal (sem meta).
    rm:addCardToDeck("warrior_strike")
    -- Adiciona MESMA carta com edition foil + seal Red.
    rm:addCardToDeck("warrior_strike", { edition = "foil", seal = "Red" })

    -- buildPlayableDeck deve ter 2 cópias: uma normal, uma com edition+seal.
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

    print()
    print("  TOTAL: " .. pass .. " pass / " .. fail .. " fail")
    return fail == 0
end

return M
