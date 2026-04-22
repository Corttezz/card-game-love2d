-- tools/preview_card_live.lua
-- Renderiza cartas em cenários que exercitam: sombra direcional, perspective warp,
-- wobble, holo composition.
-- Saída: ~/.local/share/love/card-game/preview_card_live.png

local M = {}

function M.run()
    require("src.ui.PixelCanvas").enableNearest()
    local I18n = require("src.i18n.I18n")
    I18n.init()

    local CardDatabase = require("src.systems.CardDatabase")
    local db = CardDatabase:new()
    local CardFrame = require("src.ui.CardFrame")

    local cd = db:getCard("warrior_strike")
    if not cd then print("warrior_strike não encontrada"); return end
    local inst = db:createCardInstance(cd)
    inst.image = CardFrame.render(cd)

    local w, h = 1200, 800
    local canvas = love.graphics.newCanvas(w, h)
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0.55, 0.42, 0.30, 1)

    -- Fundo claro pra ver sombra
    love.graphics.setColor(0.40, 0.30, 0.20, 1)
    love.graphics.rectangle("fill", 0, h * 0.55, w, h * 0.45)

    -- Marker de "luz"
    love.graphics.setColor(1, 0.9, 0.4, 0.9)
    love.graphics.circle("fill", w / 2, 40, 6)
    love.graphics.setColor(1, 1, 1, 1)

    -- ===== LINHA 1: sombra direcional em 5 posições X =====
    local cardY1 = h * 0.60
    inst.isDragging = false
    inst.isHovered = false
    inst.liftOffset = 0
    inst.hoverStrength = 0
    inst.tiltX = 0
    inst.tiltY = 0
    local xs = { 80, 300, 540, 780, 1020 }
    for _, cx in ipairs(xs) do
        inst:draw(cx, cardY1, false, false)
    end

    -- ===== LINHA 2: warp simulando mouse em 5 cantos diferentes =====
    -- top-left, top-right, center, bottom-left, bottom-right
    local cardY2 = h * 0.18
    inst.isHovered = true
    inst.hoverStrength = 1
    inst.liftOffset = 15

    local tiltConfigs = {
        { -0.15, -0.15, label = "TL" }, -- mouse top-left
        { 0.15,  -0.15, label = "TR" }, -- mouse top-right
        { 0.0,   0.0,   label = "C"  }, -- mouse centro (neutro)
        { -0.15, 0.15,  label = "BL" }, -- mouse bottom-left
        { 0.15,  0.15,  label = "BR" }, -- mouse bottom-right
    }
    for i, cfg in ipairs(tiltConfigs) do
        inst.tiltX = cfg[1]
        inst.tiltY = cfg[2]
        inst:draw(xs[i], cardY2, false, false)
        -- Label abaixo
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(cfg.label, xs[i] + 50, cardY2 + 210)
    end

    love.graphics.setCanvas()
    local img = canvas:newImageData()
    img:encode("png", "preview_card_live.png")
    print("[preview] salvou", love.filesystem.getSaveDirectory() .. "/preview_card_live.png")
end

return M
