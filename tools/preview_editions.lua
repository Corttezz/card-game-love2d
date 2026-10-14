local M = {}

local LABELS = {
    { key = nil,          name = "LIMPA" },
    { key = "foil",       name = "FOIL" },
    { key = "polychrome", name = "POLYCHROME" },
}

function M.run(cardId)
    local PixelCanvas = require("src.ui.PixelCanvas")
    PixelCanvas.enableNearest()
    local I18n = require("src.i18n.I18n"); pcall(I18n.init)

    pcall(function() require("src.ui.CardMesh").load() end)
    require("src.ui.HoloShader").load()
    require("src.ui.FoilShader").load()
    require("src.ui.PolychromeShader").load()

    local FontManager = require("src.ui.FontManager")
    local CardDatabase = require("src.systems.CardDatabase")
    local db = CardDatabase:new()

    cardId = cardId or "warrior_defend"
    local base = db:getCard(cardId)
    if not base then
        print("[editions] carta nao encontrada: " .. tostring(cardId))
        love.event.quit()
        return
    end

    local shots = {}
    for _, L in ipairs(LABELS) do
        local cd = {}
        for k, v in pairs(base) do cd[k] = v end
        cd.id = cardId .. "_ed_" .. (L.key or "clean")
        local inst = db:createCardInstance(cd)
        inst.edition = L.key
        shots[#shots + 1] = { inst = inst, name = L.name }
    end

    _G.gameSettings = _G.gameSettings or {}
    local prevRM = _G.gameSettings.reducedMotion
    for _, rm in ipairs({ false, true }) do
    _G.gameSettings.reducedMotion = rm

    local sw, sh = love.graphics.getDimensions()
    local canvas = love.graphics.newCanvas(sw, sh)
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0.20, 0.16, 0.12, 1)

    local img = shots[1].inst.image
    local scale = 2.4
    local cw, ch = img:getWidth() * scale, img:getHeight() * scale
    local gap = (sw - cw * #shots) / (#shots + 1)
    local cy = math.floor(sh * 0.5 - ch * 0.5)

    local font = FontManager.getFont(12)
    love.graphics.setFont(font)
    for i, sdef in ipairs(shots) do
        local cx = math.floor(gap * i + cw * (i - 1))
        local card = sdef.inst
        love.graphics.setColor(1, 1, 1, 1)
        if card.edition == "foil" then
            require("src.ui.FoilShader").draw(card.image, cx, cy, 0.7, 0, scale, scale)
        elseif card.edition == "polychrome" then
            require("src.ui.PolychromeShader").draw(card.image, cx, cy, 0.7, 0, scale, scale)
        else
            love.graphics.draw(card.image, cx, cy, 0, scale, scale)
        end
        love.graphics.setColor(0.85, 0.80, 0.70, 0.95)
        love.graphics.print(sdef.name,
            math.floor(cx + cw * 0.5 - font:getWidth(sdef.name) * 0.5), cy + ch + 14)
    end
    love.graphics.setCanvas()
    local suffix = (_G.gameSettings and _G.gameSettings.reducedMotion) and "_reducedmotion" or ""
    canvas:newImageData():encode("png", "editions_comparativo" .. suffix .. ".png")
    print("[editions] editions_comparativo" .. suffix .. ".png")

    for _, sdef in ipairs(shots) do
        local one = love.graphics.newCanvas(img:getWidth(), img:getHeight())
        love.graphics.setCanvas(one)
        love.graphics.clear(0, 0, 0, 0)
        love.graphics.setColor(1, 1, 1, 1)
        local card = sdef.inst
        if card.edition == "foil" then
            require("src.ui.FoilShader").draw(card.image, 0, 0, 0.7)
        elseif card.edition == "polychrome" then
            require("src.ui.PolychromeShader").draw(card.image, 0, 0, 0.7)
        else
            love.graphics.draw(card.image, 0, 0)
        end
        love.graphics.setCanvas()
        local nm = "editions_1to1_" .. sdef.name:lower() .. suffix .. ".png"
        one:newImageData():encode("png", nm)
        print("[editions] " .. nm)
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(canvas, 0, 0)
    end
    _G.gameSettings.reducedMotion = prevRM
    love.graphics.present()
    love.event.quit()
end

return M
