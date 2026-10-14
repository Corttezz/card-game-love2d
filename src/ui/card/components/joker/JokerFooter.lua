local Palette          = require("src.ui.Palette")
local PixelCanvas      = require("src.ui.PixelCanvas")
local BackgroundLoader = require("src.ui.card.BackgroundLoader")

local JokerFooter = {}

JokerFooter.HEIGHT = 16

local function drawSunSymbol(cx, cy)
    local c, hi = Palette.TAROT_GOLD, Palette.AGED_GOLD_LIGHT
    PixelCanvas.pixel(cx, cy - 2, c)
    PixelCanvas.pixel(cx - 1, cy - 1, c)
    PixelCanvas.pixel(cx + 1, cy - 1, c)
    PixelCanvas.pixel(cx - 2, cy, c)
    PixelCanvas.pixel(cx - 1, cy, hi)
    PixelCanvas.pixel(cx,     cy, hi)
    PixelCanvas.pixel(cx + 1, cy, c)
    PixelCanvas.pixel(cx + 2, cy, Palette.TAROT_GOLD_DARK)
    PixelCanvas.pixel(cx - 1, cy + 1, c)
    PixelCanvas.pixel(cx + 1, cy + 1, Palette.TAROT_GOLD_DARK)
    PixelCanvas.pixel(cx, cy + 2, Palette.TAROT_GOLD_DARK)
end

local function drawStarSymbol(cx, cy)
    local c, hi = Palette.TAROT_GOLD, Palette.AGED_GOLD_LIGHT
    PixelCanvas.pixel(cx, cy - 2, hi)
    PixelCanvas.pixel(cx - 2, cy - 1, c)
    PixelCanvas.pixel(cx - 1, cy - 1, hi)
    PixelCanvas.pixel(cx,     cy - 1, hi)
    PixelCanvas.pixel(cx + 1, cy - 1, c)
    PixelCanvas.pixel(cx + 2, cy - 1, Palette.TAROT_GOLD_DARK)
    PixelCanvas.pixel(cx - 1, cy, c)
    PixelCanvas.pixel(cx,     cy, Palette.PARCHMENT_LIGHT)
    PixelCanvas.pixel(cx + 1, cy, c)
    PixelCanvas.pixel(cx - 2, cy + 1, Palette.TAROT_GOLD_DARK)
    PixelCanvas.pixel(cx + 2, cy + 1, Palette.TAROT_GOLD_DARK)
    PixelCanvas.pixel(cx - 1, cy + 2, Palette.TAROT_GOLD_DARK)
    PixelCanvas.pixel(cx + 1, cy + 2, Palette.TAROT_GOLD_DARK)
end

local function drawMoonSymbol(cx, cy)
    local c, hi = Palette.TAROT_GOLD, Palette.AGED_GOLD_LIGHT
    PixelCanvas.pixel(cx, cy - 2, hi)
    PixelCanvas.pixel(cx - 1, cy - 1, hi)
    PixelCanvas.pixel(cx,     cy - 1, c)
    PixelCanvas.pixel(cx - 2, cy, hi)
    PixelCanvas.pixel(cx - 1, cy, c)
    PixelCanvas.pixel(cx - 2, cy + 1, c)
    PixelCanvas.pixel(cx - 1, cy + 1, c)
    PixelCanvas.pixel(cx,     cy + 1, Palette.TAROT_GOLD_DARK)
    PixelCanvas.pixel(cx, cy + 2, Palette.TAROT_GOLD_DARK)
end

local function drawSymbolShadow(cx, cy)
    PixelCanvas.rect(cx - 1, cy - 1, 4, 4, { 0, 0, 0, 0.35 })
end

function JokerFooter.draw(w, h)
    local fh = JokerFooter.HEIGHT
    local fy = h - fh - 1
    local bx, by = 2, fy
    local bw, bh = w - 4, fh
    local cy = by + math.floor(bh / 2)

    PixelCanvas.rect(bx, by + bh, bw, 1, { 0, 0, 0, 0.7 })

    local navyTop = Palette.lerp(Palette.TAROT_NAVY, Palette.TAROT_GOLD_DARK, 0.10)
    for row = 0, bh - 1 do
        local t = row / (bh - 1)
        PixelCanvas.hline(bx, by + row, bw,
            Palette.lerp(navyTop, Palette.TAROT_NAVY_DARK, t))
    end

    for y = by + 1, by + bh - 2 do
        for x = bx + 1, bx + bw - 2 do
            local g = (x * 3557 + y * 2953) % 17
            if g == 0 then
                PixelCanvas.pixel(x, y, { 1, 1, 1, 0.04 })
            elseif g == 1 then
                PixelCanvas.pixel(x, y, { 0, 0, 0, 0.10 })
            end
        end
    end

    local tex = BackgroundLoader.get("void")
    if tex then
        local quad = love.graphics.newQuad(0, 0, bw - 2, bh - 2,
            tex:getWidth(), tex:getHeight())
        love.graphics.setColor(1, 1, 1, 0.24)
        love.graphics.draw(tex, quad, bx + 1, by + 1)
        love.graphics.setColor(1, 1, 1, 1)
    end

    PixelCanvas.hline(bx + 1, by - 1, bw - 2, Palette.TAROT_GOLD_DARK)

    local bronze = Palette.lerp(Palette.TAROT_GOLD_DARK, Palette.INK, 0.45)
    PixelCanvas.hline(bx, by, bw, Palette.AGED_GOLD_LIGHT)
    PixelCanvas.vline(bx, by, bh, Palette.TAROT_GOLD)
    PixelCanvas.hline(bx, by + bh - 1, bw, Palette.TAROT_GOLD_DARK)
    PixelCanvas.vline(bx + bw - 1, by, bh, Palette.TAROT_GOLD_DARK)
    PixelCanvas.hline(bx + 1, by + 1, bw - 2, Palette.TAROT_GOLD_DARK)
    PixelCanvas.hline(bx + 1, by + bh - 2, bw - 2, bronze)

    for y = by, by + bh - 1 do
        for x = bx, bx + bw - 2 do
            local edgeDist = math.min(x - bx, (bx + bw - 1) - x,
                                      y - by, (by + bh - 1) - y)
            local r = (x * 7919 + y * 6271) % 223
            local thresh
            if edgeDist <= 1 then thresh = 8
            elseif edgeDist <= 3 then thresh = 2
            else thresh = 0 end
            if r < thresh then
                PixelCanvas.pixel(x,     y, { 0, 0, 0, 0.28 })
                PixelCanvas.pixel(x + 1, y, { 0, 0, 0, 0.16 })
            end
        end
    end

    PixelCanvas.pixel(bx - 1, cy, Palette.TAROT_GOLD)
    PixelCanvas.pixel(bx, cy - 1, Palette.TAROT_GOLD_DARK)
    PixelCanvas.pixel(bx, cy + 1, Palette.TAROT_GOLD_DARK)
    PixelCanvas.pixel(bx + bw, cy, Palette.TAROT_GOLD)
    PixelCanvas.pixel(bx + bw - 1, cy - 1, Palette.TAROT_GOLD_DARK)
    PixelCanvas.pixel(bx + bw - 1, cy + 1, Palette.TAROT_GOLD_DARK)

    local p1 = math.floor(w * 0.28)
    local p2 = math.floor(w * 0.50)
    local p3 = math.floor(w * 0.72)

    for x = p1 + 4, p3 - 4, 3 do
        PixelCanvas.pixel(x, cy, Palette.TAROT_GOLD_DARK)
    end
    PixelCanvas.pixel(math.floor((p1 + p2) / 2), cy - 3, Palette.TAROT_GOLD)
    PixelCanvas.pixel(math.floor((p2 + p3) / 2) + 1, cy + 3, Palette.TAROT_GOLD)
    PixelCanvas.pixel(math.floor((p2 + p3) / 2) - 3, cy - 4, Palette.TAROT_GOLD_DARK)

    drawSymbolShadow(p1, cy); drawSunSymbol(p1, cy)
    drawSymbolShadow(p2, cy); drawStarSymbol(p2, cy)
    drawSymbolShadow(p3, cy); drawMoonSymbol(p3, cy)
end

return JokerFooter
