-- src/ui/card/components/joker/JokerFooter.lua
-- Rodapé do joker: navy banner com 3 símbolos tarot (⊕ ⊙ ☽) em dourado,
-- ao invés do texto "PASSIVE". Alternativa visual mais mística.

local Palette     = require("src.ui.Palette")
local PixelCanvas = require("src.ui.PixelCanvas")

local JokerFooter = {}

JokerFooter.HEIGHT = 16

-- Símbolo "sol" (⊕): círculo com cruz 5×5
local function drawSunSymbol(cx, cy, color)
    PixelCanvas.pixel(cx, cy - 2, color)
    PixelCanvas.pixel(cx - 1, cy - 1, color)
    PixelCanvas.pixel(cx + 1, cy - 1, color)
    PixelCanvas.pixel(cx - 2, cy, color)
    PixelCanvas.pixel(cx - 1, cy, color)
    PixelCanvas.pixel(cx, cy, color)
    PixelCanvas.pixel(cx + 1, cy, color)
    PixelCanvas.pixel(cx + 2, cy, color)
    PixelCanvas.pixel(cx - 1, cy + 1, color)
    PixelCanvas.pixel(cx + 1, cy + 1, color)
    PixelCanvas.pixel(cx, cy + 2, color)
end

-- Símbolo "estrela" 5×5
local function drawStarSymbol(cx, cy, color)
    PixelCanvas.pixel(cx, cy - 2, color)
    PixelCanvas.pixel(cx - 2, cy - 1, color)
    PixelCanvas.pixel(cx - 1, cy - 1, color)
    PixelCanvas.pixel(cx, cy - 1, color)
    PixelCanvas.pixel(cx + 1, cy - 1, color)
    PixelCanvas.pixel(cx + 2, cy - 1, color)
    PixelCanvas.pixel(cx - 1, cy, color)
    PixelCanvas.pixel(cx, cy, color)
    PixelCanvas.pixel(cx + 1, cy, color)
    PixelCanvas.pixel(cx - 2, cy + 1, color)
    PixelCanvas.pixel(cx + 2, cy + 1, color)
    PixelCanvas.pixel(cx - 1, cy + 2, color)
    PixelCanvas.pixel(cx + 1, cy + 2, color)
end

-- Símbolo "lua crescente" 5×5
local function drawMoonSymbol(cx, cy, color)
    PixelCanvas.pixel(cx, cy - 2, color)
    PixelCanvas.pixel(cx - 1, cy - 1, color)
    PixelCanvas.pixel(cx, cy - 1, color)
    PixelCanvas.pixel(cx - 2, cy, color)
    PixelCanvas.pixel(cx - 1, cy, color)
    PixelCanvas.pixel(cx - 2, cy + 1, color)
    PixelCanvas.pixel(cx - 1, cy + 1, color)
    PixelCanvas.pixel(cx, cy + 1, color)
    PixelCanvas.pixel(cx, cy + 2, color)
end

function JokerFooter.draw(w, h)
    local fh = JokerFooter.HEIGHT
    local fy = h - fh - 1

    -- Banner navy com ouro
    PixelCanvas.rect(2, fy, w - 4, fh, Palette.TAROT_NAVY)
    PixelCanvas.rectOutline(2, fy, w - 4, fh, Palette.TAROT_GOLD)
    PixelCanvas.hline(3, fy + 1, w - 6, Palette.TAROT_NAVY_DARK)
    PixelCanvas.hline(3, fy - 1, w - 6, Palette.TAROT_GOLD_DARK) -- accent strip

    -- End-caps dourados nas pontas
    PixelCanvas.pixel(1, fy + math.floor(fh / 2), Palette.TAROT_GOLD)
    PixelCanvas.pixel(w - 2, fy + math.floor(fh / 2), Palette.TAROT_GOLD)

    -- 3 símbolos tarot ao longo do banner (esquerda → centro → direita)
    local cy = fy + math.floor(fh / 2)
    local positions = {
        math.floor(w * 0.28),
        math.floor(w * 0.50),
        math.floor(w * 0.72),
    }
    drawSunSymbol(positions[1], cy, Palette.TAROT_GOLD)
    drawStarSymbol(positions[2], cy, Palette.AGED_GOLD_LIGHT)
    drawMoonSymbol(positions[3], cy, Palette.TAROT_GOLD)
end

return JokerFooter
