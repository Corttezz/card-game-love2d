local Palette     = require("src.ui.Palette")
local PixelCanvas = require("src.ui.PixelCanvas")
local PixelFont   = require("src.ui.PixelFont")

local CardCostBadge = {}

CardCostBadge.SIZE = 13

local HW = { 1, 2, 3, 4, 5, 6, 6, 6, 5, 4, 3, 2, 1 }

function CardCostBadge.draw(cost)
    local ox, oy = 1, 2 + 3
    local size = CardCostBadge.SIZE
    local cx = ox + 6

    for i, hw in ipairs(HW) do
        PixelCanvas.hline(cx - hw + 1, oy + i, hw * 2 + 1, { 0, 0, 0, 0.35 })
    end

    for i, hw in ipairs(HW) do
        PixelCanvas.hline(cx - hw, oy + i - 1, hw * 2 + 1, Palette.INK)
    end

    for i = 2, 12 do
        local hw = HW[i] - 1
        PixelCanvas.hline(cx - hw, oy + i - 1, hw * 2 + 1, Palette.MANA)
    end

    for i = 2, 6 do
        local hw = HW[i] - 1
        if hw > 0 then
            PixelCanvas.hline(cx - hw, oy + i - 1, hw, Palette.MANA_LIGHT)
        end
    end
    for i = 8, 12 do
        local hw = HW[i] - 1
        if hw > 0 then
            PixelCanvas.hline(cx + 1, oy + i - 1, hw, Palette.MANA_DEEP)
        end
    end

    PixelCanvas.pixel(cx - 2, oy + 2, Palette.MANA_GLINT)
    PixelCanvas.pixel(cx - 3, oy + 3, Palette.MANA_GLINT)

    PixelCanvas.pixel(cx,     oy - 1,    Palette.AGED_GOLD_LIGHT)
    PixelCanvas.pixel(cx,     oy + 13,   Palette.AGED_GOLD_DARK)
    PixelCanvas.pixel(cx - 7, oy + 6,    Palette.AGED_GOLD)
    PixelCanvas.pixel(cx + 7, oy + 6,    Palette.AGED_GOLD)

    local font = PixelFont.get(8)
    love.graphics.setFont(font)
    local s = tostring(cost or 0)
    local tw = font:getWidth(s)
    local tx = ox + math.floor((size - tw) / 2)
    local ty = oy + 1
    love.graphics.setColor(Palette.INK)
    love.graphics.print(s, tx - 1, ty)
    love.graphics.print(s, tx + 1, ty)
    love.graphics.print(s, tx, ty - 1)
    love.graphics.print(s, tx, ty + 1)
    love.graphics.setColor(Palette.PARCHMENT_LIGHT)
    love.graphics.print(s, tx, ty)
end

return CardCostBadge
