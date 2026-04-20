-- tools/preview_cards.lua
-- Renderiza algumas cartas e salva PNGs pra inspeção. Usar: love . preview_cards

local M = {}

function M.run()
    local PixelCanvas  = require("src.ui.PixelCanvas")
    PixelCanvas.enableNearest()

    local CRTShader = require("src.ui.CRTShader")
    pcall(CRTShader.load)

    local CardDatabase = require("src.systems.CardDatabase")
    local db = CardDatabase:new()

    local ids = {
        "warrior_strike", "warrior_heavy_blade", "warrior_defend", "warrior_berserk",
        "mage_zap", "mage_blizzard", "rogue_backstab",
        "joker_001", "joker_004",
        "effect_healing_potion",
    }

    local saved = {}
    for _, id in ipairs(ids) do
        local cd = db:getCard(id)
        if cd then
            local ok, inst = pcall(function() return db:createCardInstance(cd) end)
            if ok and inst and inst.image then
                local okData, data = pcall(function() return inst.image:newImageData() end)
                if okData and data then
                    local fname = "preview_" .. id .. ".png"
                    data:encode("png", fname)
                    saved[#saved + 1] = fname
                    print("[preview] saved " .. fname)
                end
            end
        end
    end
    print("[preview] saveDir: " .. love.filesystem.getSaveDirectory())
end

return M
