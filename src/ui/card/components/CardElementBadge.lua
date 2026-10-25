local Palette     = require("src.ui.Palette")
local PixelCanvas = require("src.ui.PixelCanvas")

local CardElementBadge = {}

CardElementBadge.SIZE = 11
CardElementBadge.MARGIN_X = 2
CardElementBadge.MARGIN_Y = 2

local GLYPH = {
    fire = {
        "...o...",
        "..oo...",
        "..ooo..",
        ".ooioo.",
        ".oiiio.",
        ".oiiio.",
        "..ooo..",
    },
    ice = {
        "...o...",
        ".o.o.o.",
        "..ooo..",
        "oooiooo",
        "..ooo..",
        ".o.o.o.",
        "...o...",
    },
    lightning = {
        "...ooo.",
        "..ooo..",
        ".ooo...",
        ".ooiio.",
        "...oo..",
        "..oo...",
        ".o.....",
    },
    dark = {
        "..ooo..",
        ".ooo...",
        "ooi....",
        "ooi....",
        "ooi....",
        ".ooo...",
        "..ooo..",
    },
    arcane = {
        "...o...",
        "..o.o..",
        ".o.i.o.",
        "o.iii.o",
        ".o.i.o.",
        "..o.o..",
        "...o...",
    },
    poison = {
        "...o...",
        "...o...",
        "..ooo..",
        ".ooooo.",
        ".oiooo.",
        ".ooooo.",
        "..ooo..",
    },
    holy = {
        "...o...",
        "..oio..",
        "ooiiioo",
        "..oio..",
        "...o...",
        "...o...",
        "...o...",
    },
}

local COLORS = {
    fire      = { fill = Palette.BLOOD_DARK,   glyph = Palette.ORANGE,          core = Palette.YELLOW },
    ice       = { fill = Palette.BLUE_DEEP,    glyph = Palette.CYAN_PALE,       core = Palette.CYAN },
    lightning = { fill = Palette.BG_MID,       glyph = Palette.YELLOW,          core = Palette.PARCHMENT_LIGHT },
    dark      = { fill = Palette.VOID,         glyph = Palette.ARCANE_LIGHT,    core = Palette.ARCANE },
    arcane    = { fill = Palette.PURPLE_DEEP,  glyph = Palette.ARCANE_LIGHT,    core = Palette.PINK },
    poison    = { fill = Palette.INK,          glyph = Palette.GREEN_BRIGHT,    core = Palette.TOAST_GOOD },
    holy      = { fill = Palette.AGED_GOLD_DARK, glyph = Palette.PARCHMENT_LIGHT, core = Palette.AGED_GOLD_LIGHT },
}

function CardElementBadge.has(dtype)
    return dtype ~= nil and GLYPH[dtype] ~= nil
end

function CardElementBadge.colors(dtype)
    return COLORS[dtype]
end

function CardElementBadge.rect(w, h, footerH)
    local s = CardElementBadge.SIZE
    local x = w - 5 - CardElementBadge.MARGIN_X - s
    local y = h - footerH - CardElementBadge.MARGIN_Y - s
    return x, y, s, s
end

local function disc(ox, oy, size, fill, outline)
    PixelCanvas.rect(ox, oy + 1, size, size - 2, fill)
    PixelCanvas.rect(ox + 1, oy, size - 2, size, fill)
    PixelCanvas.hline(ox + 2, oy, size - 4, outline)
    PixelCanvas.hline(ox + 2, oy + size - 1, size - 4, outline)
    PixelCanvas.vline(ox, oy + 2, size - 4, outline)
    PixelCanvas.vline(ox + size - 1, oy + 2, size - 4, outline)
    PixelCanvas.pixel(ox + 1, oy + 1, outline)
    PixelCanvas.pixel(ox + size - 2, oy + 1, outline)
    PixelCanvas.pixel(ox + 1, oy + size - 2, outline)
    PixelCanvas.pixel(ox + size - 2, oy + size - 2, outline)
end

function CardElementBadge.drawAt(ox, oy, dtype)
    local rows = GLYPH[dtype]
    local col = COLORS[dtype]
    if not rows or not col then return false end
    local size = CardElementBadge.SIZE

    for i = 1, size - 2 do
        PixelCanvas.hline(ox + 1, oy + i + 1, size - 1, { 0, 0, 0, 0.30 })
    end
    disc(ox, oy, size, col.fill, Palette.INK)
    PixelCanvas.pixel(ox + 2, oy + 1, Palette.AGED_GOLD_LIGHT)
    PixelCanvas.pixel(ox + 1, oy + 2, Palette.AGED_GOLD)
    PixelCanvas.pixel(ox + size - 3, oy + size - 2, Palette.AGED_GOLD_DARK)
    PixelCanvas.pixel(ox + size - 2, oy + size - 3, Palette.AGED_GOLD_DARK)

    local gx, gy = ox + 2, oy + 2
    for r, row in ipairs(rows) do
        for c = 1, #row do
            local ch = row:sub(c, c)
            if ch == "o" then
                PixelCanvas.pixel(gx + c - 1, gy + r - 1, col.glyph)
            elseif ch == "i" then
                PixelCanvas.pixel(gx + c - 1, gy + r - 1, col.core)
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
    return true
end

function CardElementBadge.draw(w, h, footerH, dtype)
    if not GLYPH[dtype] then return false end
    local ox, oy = CardElementBadge.rect(w, h, footerH)
    return CardElementBadge.drawAt(ox, oy, dtype)
end

return CardElementBadge
