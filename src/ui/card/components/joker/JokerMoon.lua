local Palette     = require("src.ui.Palette")
local PixelCanvas = require("src.ui.PixelCanvas")

local JokerMoon = {}

JokerMoon.SIZE = 13

local MOON = {
    { 4, 7 },
    { 3, 8 },
    { 2, 6 },
    { 1, 5 },
    { 1, 4 },
    { 0, 4 },
    { 0, 4 },
    { 0, 4 },
    { 1, 4 },
    { 1, 5 },
    { 2, 6 },
    { 3, 8 },
    { 4, 7 },
}

local function stamp(ox, oy, color, dx, dy)
    for i, sp in ipairs(MOON) do
        PixelCanvas.hline(ox + sp[1] + dx, oy + i - 1 + dy,
            sp[2] - sp[1] + 1, color)
    end
end

function JokerMoon.draw()
    local ox, oy = 1, 1 + 3

    stamp(ox, oy, Palette.INK, 1, 0)
    stamp(ox, oy, Palette.INK, -1, 0)
    stamp(ox, oy, Palette.INK, 0, 1)
    stamp(ox, oy, Palette.INK, 0, -1)

    stamp(ox, oy, Palette.TAROT_GOLD, 0, 0)

    for i, sp in ipairs(MOON) do
        PixelCanvas.pixel(ox + sp[2], oy + i - 1, Palette.TAROT_GOLD_DARK)
    end

    for i = 2, 6 do
        PixelCanvas.pixel(ox + MOON[i][1], oy + i - 1, Palette.AGED_GOLD_LIGHT)
    end

    local sx, sy = ox + 9, oy + 6
    PixelCanvas.pixel(sx,     sy - 1, Palette.AGED_GOLD_LIGHT)
    PixelCanvas.pixel(sx - 1, sy,     Palette.AGED_GOLD_LIGHT)
    PixelCanvas.pixel(sx,     sy,     Palette.TAROT_CREAM)
    PixelCanvas.pixel(sx + 1, sy,     Palette.AGED_GOLD_LIGHT)
    PixelCanvas.pixel(sx,     sy + 1, Palette.AGED_GOLD_LIGHT)

    PixelCanvas.pixel(sx + 2, sy - 3, Palette.TAROT_GOLD)
end

return JokerMoon
