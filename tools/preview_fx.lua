-- tools/preview_fx.lua
-- Renderiza uma carta representante de CADA decoração/efeito pra análise visual.
-- Usar: love . preview_fx  (salva no saveDir do LÖVE)

local M = {}

function M.run()
    local PixelCanvas = require("src.ui.PixelCanvas")
    PixelCanvas.enableNearest()
    local I18n = require("src.i18n.I18n"); pcall(I18n.init)

    local CardDatabase = require("src.systems.CardDatabase")
    local db = CardDatabase:new()
    local CardFrame = require("src.ui.CardFrame")

    -- id -> tag do efeito demonstrado (pro nome do arquivo)
    local jobs = {
        { "warrior_twin_strike",   "sparks" },
        { "warrior_heavy_blade",   "dust" },
        { "warrior_ghostly_armor", "smoke" },
        { "warrior_colossus_blow", "flash_raio" },
        { "rogue_executioner",     "blood_drips" },
        { "warrior_immolate",      "embers" },
        { "mage_blizzard",         "frost" },
        { "mage_dualcast",         "runes" },
        { "rogue_venom_coating",   "poison_bubbles" },
        { "rogue_shadow_dance",    "shadow_wisps" },
        { "joker_002",             "abyss_tendrils" },
        { "mage_mind_spike",       "void_stars" },
        -- "filtro vermelho": fundo fire/blood + accent quente
        { "warrior_inflame",       "redfilter_fire" },
        { "warrior_brutality",     "redfilter_blood" },
    }

    for _, job in ipairs(jobs) do
        local id, tag = job[1], job[2]
        local cd = db:getCard(id)
        if cd then
            local ok, inst = pcall(function() return db:createCardInstance(cd) end)
            if ok and inst then
                inst.image = CardFrame.render(cd)
                local okD, data = pcall(function() return inst.image:newImageData() end)
                if okD and data then
                    local fname = "fx_" .. tag .. "__" .. id .. ".png"
                    data:encode("png", fname)
                    print("[fx] saved " .. fname)
                end
            else
                print("[fx] WARN instance fail " .. id)
            end
        else
            print("[fx] WARN not found " .. id)
        end
    end
    print("[fx] saveDir: " .. love.filesystem.getSaveDirectory())
end

return M
