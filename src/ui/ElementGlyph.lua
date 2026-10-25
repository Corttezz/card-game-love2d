local Palette = require("src.ui.Palette")
local I18n    = require("src.i18n.I18n")

local ElementGlyph = {}

ElementGlyph.SIZE = 7

local GLYPH = {
    physical = {
        "......o",
        ".....o.",
        "....o..",
        ".i.o...",
        "..o....",
        ".i.i...",
        "i......",
    },
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
    physical  = { glyph = Palette.STEEL_LIGHT,     core = Palette.AGED_GOLD },
    fire      = { glyph = Palette.ORANGE,          core = Palette.YELLOW },
    ice       = { glyph = Palette.CYAN_PALE,       core = Palette.CYAN },
    lightning = { glyph = Palette.YELLOW,          core = Palette.PARCHMENT_LIGHT },
    dark      = { glyph = Palette.ARCANE_LIGHT,    core = Palette.ARCANE },
    arcane    = { glyph = Palette.ARCANE_LIGHT,    core = Palette.PINK },
    poison    = { glyph = Palette.GREEN_BRIGHT,    core = Palette.TOAST_GOOD },
    holy      = { glyph = Palette.AGED_GOLD_LIGHT, core = Palette.PARCHMENT_LIGHT },
}

function ElementGlyph.has(dtype)
    return dtype ~= nil and GLYPH[dtype] ~= nil
end

function ElementGlyph.colors(dtype)
    return COLORS[dtype]
end

local function stamp(rows, x, y, s, colO, colI, alpha)
    for r, row in ipairs(rows) do
        for c = 1, #row do
            local ch = row:sub(c, c)
            local col = (ch == "o" and colO) or (ch == "i" and colI) or nil
            if col then
                love.graphics.setColor(col[1], col[2], col[3], alpha)
                love.graphics.rectangle("fill", x + (c - 1) * s, y + (r - 1) * s, s, s)
            end
        end
    end
end

function ElementGlyph.draw(dtype, x, y, scale, alpha)
    local rows, col = GLYPH[dtype], COLORS[dtype]
    if not rows or not col then return false end
    local s = math.max(1, math.floor(scale or 1))
    alpha = alpha or 1
    x, y = math.floor(x), math.floor(y)
    stamp(rows, x + s, y + s, s, Palette.INK, Palette.INK, 0.85 * alpha)
    stamp(rows, x, y, s, col.glyph, col.core, alpha)
    love.graphics.setColor(1, 1, 1, 1)
    return true
end

function ElementGlyph.line(card)
    local Resistances = require("src.systems.Resistances")
    local ty, dmg = Resistances.elementOfCard(card)
    if not ty then return nil end
    local typeName = I18n.t("resist.type." .. ty, nil, ty)
    local key = dmg and "card_info.damage_type" or "card_info.element"
    local col = COLORS[ty]
    return {
        text = I18n.t(key, { type = typeName }, typeName),
        type = ty,
        damage = dmg,
        color = col and col.glyph or Palette.PARCHMENT_LIGHT,
    }
end

function ElementGlyph.scaleFor(font)
    return math.max(1, math.floor(font:getHeight() * 0.8 / ElementGlyph.SIZE + 0.5))
end

function ElementGlyph.lineWidth(line, font)
    if not line then return 0 end
    local s = ElementGlyph.scaleFor(font)
    return ElementGlyph.SIZE * s + s + 5 + font:getWidth(line.text)
end

function ElementGlyph.drawLine(line, x, y, font, alpha, maxW, opts)
    if not line then return 0 end
    alpha = alpha or 1
    opts = opts or {}
    local s = ElementGlyph.scaleFor(font)
    local gh = ElementGlyph.SIZE * s
    local fh = font:getHeight()
    local h = math.max(gh, fh)
    if opts.center and maxW then
        x = x + math.max(0, math.floor((maxW - ElementGlyph.lineWidth(line, font)) / 2))
        maxW = nil
    end
    ElementGlyph.draw(line.type, x, y + math.floor((h - gh) / 2), s, alpha)
    local tx = x + gh + s + 5
    love.graphics.setFont(font)
    local c = opts.textColor or line.color
    local ty = y + math.floor((h - fh) / 2)
    local function out(px, py)
        if maxW then
            love.graphics.printf(line.text, px, py, maxW - (tx - x))
        else
            love.graphics.print(line.text, px, py)
        end
    end
    if not opts.textColor then
        love.graphics.setColor(Palette.INK[1], Palette.INK[2], Palette.INK[3], 0.8 * alpha)
        out(tx + 1, ty + 1)
    end
    love.graphics.setColor(c[1], c[2], c[3], alpha)
    out(tx, ty)
    love.graphics.setColor(1, 1, 1, 1)
    return h, x
end

return ElementGlyph
