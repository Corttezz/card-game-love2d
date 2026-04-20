-- src/ui/card/components/joker/JokerHeader.lua
-- Banner do nome em tema tarot — navy com filete dourado duplo e nome em cream.

local Palette     = require("src.ui.Palette")
local PixelCanvas = require("src.ui.PixelCanvas")
local PixelFont   = require("src.ui.PixelFont")

local JokerHeader = {}

JokerHeader.HEIGHT = 14

function JokerHeader.draw(w, cardName)
    local h = JokerHeader.HEIGHT
    local bx, by = 13, 2
    local bw, bh = w - 26, h - 3

    -- Fundo navy
    PixelCanvas.rect(bx, by, bw, bh, Palette.TAROT_NAVY)
    -- Borda externa INK
    PixelCanvas.rectOutline(bx - 1, by - 1, bw + 2, bh + 2, Palette.INK)
    -- Filete duplo dourado
    PixelCanvas.rectOutline(bx, by, bw, bh, Palette.TAROT_GOLD)
    PixelCanvas.hline(bx + 1, by + 1, bw - 2, Palette.AGED_GOLD_LIGHT)

    -- End-caps losango dourados nas pontas
    PixelCanvas.pixel(bx - 2, by + math.floor(bh / 2), Palette.TAROT_GOLD)
    PixelCanvas.pixel(bx - 3, by + math.floor(bh / 2), Palette.TAROT_GOLD_DARK)
    PixelCanvas.pixel(bx + bw + 1, by + math.floor(bh / 2), Palette.TAROT_GOLD)
    PixelCanvas.pixel(bx + bw + 2, by + math.floor(bh / 2), Palette.TAROT_GOLD_DARK)

    -- Nome em TAROT_CREAM
    local font = PixelFont.get(8)
    love.graphics.setFont(font)
    local name = cardName or "?"
    local maxChars = math.floor(bw / 4)
    if #name > maxChars then name = name:sub(1, maxChars - 1) .. "." end
    local tw = font:getWidth(name)
    love.graphics.setColor(Palette.TAROT_CREAM)
    love.graphics.print(name, bx + math.floor((bw - tw) / 2), by + 1)
end

return JokerHeader
