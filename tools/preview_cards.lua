local M = {}

function M.run()
    local PixelCanvas  = require("src.ui.PixelCanvas")
    PixelCanvas.enableNearest()

    local CRTShader = require("src.ui.CRTShader")
    pcall(CRTShader.load)

    local CardDatabase = require("src.systems.CardDatabase")
    local db = CardDatabase:new()

    local CardFrame = require("src.ui.CardFrame")

    local jobs = {
        { "warrior_bastion",         nil },
        { "warrior_war_cry",         nil },
        { "warrior_twin_strike",     nil },
        { "warrior_iron_discipline", nil },
        { "warrior_colossus_blow",   nil },
        { "warrior_standard_bearer", nil },
        { "mage_overcharge",         nil },
        { "mage_arcane_focus",       nil },
        { "mage_mind_spike",         nil },
        { "mage_twin_bolts",         nil },
        { "mage_arcane_torrent",     nil },
        { "rogue_venom_coating",     nil },
        { "rogue_twin_fangs",        nil },
        { "rogue_expose_weakness",   nil },
        { "rogue_shadow_dance",      nil },
        { "rogue_executioner",       nil },
        { "attack_cleave",           nil },
        { "defense_bulwark",         nil },
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
        { "warrior_flame_barrier", nil },
        { "warrior_inflame",       nil },
        { "warrior_berserk",       nil },
        { "rogue_backstab",        nil },
        { "mage_blizzard",         nil },
        { "joker_001",             nil },
        { "joker_004",             nil },
        { "rogue_doppelganger",    nil },
        { "effect_healing_potion", nil },
        { "warrior_strike",        "uncommon" },
        { "warrior_strike",        "rare" },
        { "warrior_strike",        "legendary" },
    }

    local saved = {}
    for _, job in ipairs(jobs) do
        local id, override = job[1], job[2]
        local cd = db:getCard(id)
        if cd then
            local cloned = {}
            for k, v in pairs(cd) do cloned[k] = v end
            if override then
                cloned.rarity = override
                cloned.id = id .. "_AS_" .. override
            end
            local ok, inst = pcall(function() return db:createCardInstance(cloned) end)
            if ok and inst then
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
