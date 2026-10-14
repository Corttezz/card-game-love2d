local Palette     = require("src.ui.Palette")
local PixelCanvas = require("src.ui.PixelCanvas")

local JokerSeal = {}

JokerSeal.SIZE = 13

local function drawCircle(ox, oy, size, fill, outline)
    PixelCanvas.rect(ox, oy + 1, size, size - 2, fill)
    PixelCanvas.rect(ox + 1, oy, size - 2, size, fill)
    PixelCanvas.hline(ox + 1, oy, size - 2, outline)
    PixelCanvas.hline(ox + 1, oy + size - 1, size - 2, outline)
    PixelCanvas.vline(ox, oy + 1, size - 2, outline)
    PixelCanvas.vline(ox + size - 1, oy + 1, size - 2, outline)
    PixelCanvas.pixel(ox + 1, oy + 1, outline)
    PixelCanvas.pixel(ox + size - 2, oy + 1, outline)
    PixelCanvas.pixel(ox + 1, oy + size - 2, outline)
    PixelCanvas.pixel(ox + size - 2, oy + size - 2, outline)
end

function JokerSeal.draw(w, rarity)
    local size = JokerSeal.SIZE
    local ox = w - size - 1
    local oy = 1 + 3

    local cx, cy = ox + size / 2, oy + size / 2
    for i = 0, 5 do
        local a = i * math.pi * 2 / 6
        local px = math.floor(cx + math.cos(a) * (size / 2 + 1))
        local py = math.floor(cy + math.sin(a) * (size / 2 + 1))
        PixelCanvas.pixel(px, py, Palette.TAROT_GOLD)
    end

    drawCircle(ox, oy, size, Palette.TAROT_NAVY, Palette.INK)
    drawCircle(ox + 2, oy + 2, size - 4, Palette.TAROT_GOLD, Palette.TAROT_NAVY_DARK)
    PixelCanvas.rect(ox + 5, oy + 5, 3, 3, Palette.AGED_GOLD_LIGHT)
    PixelCanvas.pixel(ox + 6, oy + 6, Palette.PARCHMENT_LIGHT)

    local rays = {
        { 0, -4 }, { 3, -2 }, { 3, 2 }, { 0, 4 }, { -3, 2 }, { -3, -2 },
    }
    for _, r in ipairs(rays) do
        local px = math.floor(cx + r[1] * 0.7)
        local py = math.floor(cy + r[2] * 0.7)
        PixelCanvas.pixel(px, py, Palette.TAROT_GOLD_DARK)
    end
end

return JokerSeal
