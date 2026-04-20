-- src/ui/card/components/CardCostBadge.lua
-- Desenha o badge circular de custo no canto superior esquerdo.
-- Visual: disco azul-aço bordado em preto, com número em bone white.
--
-- API: CardCostBadge.draw(cost)

local Palette     = require("src.ui.Palette")
local PixelCanvas = require("src.ui.PixelCanvas")
local PixelFont   = require("src.ui.PixelFont")

local CardCostBadge = {}

CardCostBadge.SIZE = 11

-- "Círculo" 11×11 pseudo-redondo: 4 pixels cortados em cada canto.
local function drawCircle(ox, oy, size, fill, outline)
    local r = size - 1
    -- Preenche centro
    PixelCanvas.rect(ox, oy + 1, size, size - 2, fill)
    PixelCanvas.rect(ox + 1, oy, size - 2, size, fill)
    -- Outline seguindo a silhueta
    PixelCanvas.hline(ox + 1, oy, size - 2, outline)
    PixelCanvas.hline(ox + 1, oy + size - 1, size - 2, outline)
    PixelCanvas.vline(ox, oy + 1, size - 2, outline)
    PixelCanvas.vline(ox + size - 1, oy + 1, size - 2, outline)
    -- Cantos suavizados
    PixelCanvas.pixel(ox + 1, oy + 1, outline)
    PixelCanvas.pixel(ox + size - 2, oy + 1, outline)
    PixelCanvas.pixel(ox + 1, oy + size - 2, outline)
    PixelCanvas.pixel(ox + size - 2, oy + size - 2, outline)
end

function CardCostBadge.draw(cost)
    local ox, oy = 1, 1
    local size = CardCostBadge.SIZE

    -- Disco externo
    drawCircle(ox, oy, size, Palette.STEEL, Palette.INK)
    -- Highlight interno
    drawCircle(ox + 1, oy + 1, size - 2, Palette.STEEL_LIGHT, Palette.STEEL)
    PixelCanvas.pixel(ox + 3, oy + 3, Palette.PARCHMENT_LIGHT)

    -- Número do custo centralizado
    local font = PixelFont.get(8)
    love.graphics.setFont(font)
    local s = tostring(cost or 0)
    local tw = font:getWidth(s)
    love.graphics.setColor(Palette.PARCHMENT_LIGHT)
    love.graphics.print(s, ox + math.floor((size - tw) / 2), oy + 1)
end

return CardCostBadge
