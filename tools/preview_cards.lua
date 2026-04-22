-- tools/preview_cards.lua
-- Renderiza algumas cartas e salva PNGs pra inspeção. Usar: love . preview_cards
--
-- Inclui pelo menos uma carta de cada raridade (common/uncommon/rare/legendary)
-- pra validar o styling ornamentado do CardHeader.

local M = {}

function M.run()
    local PixelCanvas  = require("src.ui.PixelCanvas")
    PixelCanvas.enableNearest()

    local CRTShader = require("src.ui.CRTShader")
    pcall(CRTShader.load)

    local CardDatabase = require("src.systems.CardDatabase")
    local db = CardDatabase:new()

    local CardFrame = require("src.ui.CardFrame")

    -- Cada entry: {id, rarityOverride?} — rarityOverride permite testar a mesma
    -- carta em raridades diferentes (já que não existem attack/defense legendary).
    local jobs = {
        -- COMMON real
        { "warrior_strike",        nil },
        { "warrior_defend",        nil },
        { "warrior_iron_wave",     nil },
        { "warrior_kite_guard",    nil },
        { "warrior_heavy_blade",   nil },
        { "warrior_demon_form",    nil },
        { "warrior_juggernaut",    nil },
        { "mage_dualcast",         nil },
        { "mage_doom_and_gloom",   nil },
        { "warrior_brutality",     nil },
        { "rogue_bouncing_flask",  nil },
        { "mage_zap",              nil },
        -- UNCOMMON real
        { "warrior_flame_barrier", nil },
        { "warrior_inflame",       nil },
        -- RARE real
        { "warrior_berserk",       nil },
        { "rogue_backstab",        nil },
        { "mage_blizzard",         nil },
        -- LEGENDARY jokers (real)
        { "joker_001",             nil },
        { "joker_004",             nil },
        -- WRAP test
        { "rogue_doppelganger",    nil },
        -- EFFECT
        { "effect_healing_potion", nil },
        -- OVERRIDES — mesma carta em raridades fake pra testar header standard
        { "warrior_strike",        "uncommon" },
        { "warrior_strike",        "rare" },
        { "warrior_strike",        "legendary" },
    }

    local saved = {}
    for _, job in ipairs(jobs) do
        local id, override = job[1], job[2]
        local cd = db:getCard(id)
        if cd then
            -- Clona dados pra aplicar override sem mutar cache global
            local cloned = {}
            for k, v in pairs(cd) do cloned[k] = v end
            if override then
                cloned.rarity = override
                cloned.id = id .. "_AS_" .. override   -- evita cache hit
            end
            local ok, inst = pcall(function() return db:createCardInstance(cloned) end)
            if ok and inst then
                -- Bypass cache do CardFrame quando há override (ID modificado já evita,
                -- mas garantimos chamando invalidate antes).
                if override then CardFrame.invalidate(cloned) end
                inst.image = CardFrame.render(cloned)
                local okData, data = pcall(function() return inst.image:newImageData() end)
                if okData and data then
                    local rarity = cloned.rarity or "common"
                    local suffix = override and ("_OVR_" .. id) or ""
                    local fname = "preview_" .. rarity .. "_" .. id .. suffix .. ".png"
                    data:encode("png", fname)
                    saved[#saved + 1] = fname
                    print("[preview] saved " .. fname)
                end
            else
                print("[preview] WARN: failed to create instance for " .. id)
            end
        else
            print("[preview] WARN: card not found: " .. id)
        end
    end
    print("[preview] saveDir: " .. love.filesystem.getSaveDirectory())
end

return M
