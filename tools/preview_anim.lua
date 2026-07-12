-- tools/preview_anim.lua
-- Renderiza cada overlay animado do CardAnimationLayer em 3 amostras de tempo
-- (frames) lado a lado, pra avaliar o MOVIMENTO. Usar: love . preview_anim
-- Saída: anim_<label>.png no saveDir.

local M = {}

function M.run()
    local PixelCanvas = require("src.ui.PixelCanvas")
    PixelCanvas.enableNearest()
    local I18n = require("src.i18n.I18n"); pcall(I18n.init)

    local CardDatabase = require("src.systems.CardDatabase")
    local db = CardDatabase:new()
    local CardFrame = require("src.ui.CardFrame")
    local CardArt   = require("src.ui.CardArt")
    local Layer     = require("src.ui.card.CardAnimationLayer")

    -- id, override(rarity/type), label
    local jobs = {
        { "joker_002",           nil, "joker_ring+abyss" },
        { "joker_001",           nil, "legendary_joker" },
        { "warrior_immolate",    nil, "embers_fire" },
        { "warrior_brutality",   nil, "blood_drip" },
        { "mage_overcharge",     nil, "storm_flash" },
        { "mage_blizzard",       nil, "ice_shimmer" },
        { "rogue_venom_coating", nil, "poison_bubbles" },
        { "mage_dualcast",       nil, "arcane_glyphs" },
        { "rogue_shadow_dance",  nil, "shadow_wisps" },
        { "mage_mind_spike",     nil, "void_twinkle" },
    }

    local S = 3                         -- escala de render
    local ts = { 0.30, 1.30, 2.52 }     -- amostras (2.52%2.5≈0.02 pega storm flash; 0.30 pega shooting star/ripple)
    local cw, ch = 96 * S, 144 * S
    local pad = 12

    for _, job in ipairs(jobs) do
        local id, ovr, label = job[1], job[2], job[3]
        local base = db:getCard(id)
        if base then
            local cd = {}
            for k, v in pairs(base) do cd[k] = v end
            if ovr then for k, v in pairs(ovr) do cd[k] = v end; cd.id = id .. "_ovr" end
            local inst = db:createCardInstance(cd)
            local img = CardFrame.render(cd)
            local art = CardArt.resolve(cd)

            local W = #ts * cw + (#ts + 1) * pad
            local H = ch + 2 * pad
            local canvas = love.graphics.newCanvas(W, H)
            love.graphics.setCanvas(canvas)
            love.graphics.clear(0.12, 0.10, 0.09, 1)
            for fi, tv in ipairs(ts) do
                local px = pad + (fi - 1) * (cw + pad)
                local py = pad
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(img, px, py, 0, S, S)
                Layer.draw(cd, art, px, py, S, S, tv)
            end
            love.graphics.setCanvas()
            local data = canvas:newImageData()
            data:encode("png", "anim_" .. label .. ".png")
            print("[anim] saved anim_" .. label .. ".png")
        else
            print("[anim] WARN not found " .. id)
        end
    end
    print("[anim] saveDir: " .. love.filesystem.getSaveDirectory())
end

return M
