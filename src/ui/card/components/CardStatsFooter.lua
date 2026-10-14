local Palette          = require("src.ui.Palette")
local PixelCanvas      = require("src.ui.PixelCanvas")
local PixelFont        = require("src.ui.PixelFont")
local I18n             = require("src.i18n.I18n")
local BackgroundLoader = require("src.ui.card.BackgroundLoader")

local CardStatsFooter = {}

CardStatsFooter.HEIGHT = 20

local TYPE_PATTERNS = {
    attack  = "blood",
    defense = "metal",
    effect  = "arcane",
    joker   = "void",
}

local LABEL_KEYS = {
    attack  = "card_type.attack",
    defense = "card_type.defense",
    joker   = "card_type.passive",
    effect  = "card_type.action",
}

local function labelFor(cardType)
    local key = LABEL_KEYS[cardType]
    if not key then return I18n.t("card_type.unknown") end
    return I18n.t(key)
end

local GLYPH_NAMES = {
    attack  = "stat_sword",
    defense = "stat_shield",
    joker   = "stat_star",
    effect  = "stat_hourglass",
}

local glyphCache = {}
local glyphMissCache = {}

local function tryLoadGlyph(name)
    if glyphCache[name] then return glyphCache[name] end
    if glyphMissCache[name] then return nil end
    local path = "assets/sprites/ui/" .. name .. ".png"
    if not love.filesystem.getInfo(path) then
        glyphMissCache[name] = true
        return nil
    end
    local ok, img = pcall(love.graphics.newImage, path)
    if not ok or not img then
        glyphMissCache[name] = true
        return nil
    end
    img:setFilter("nearest", "nearest")
    glyphCache[name] = img
    return img
end

local ProceduralGlyphs = {
    stat_sword     = { {0,0,0,1,0},{0,0,1,1,0},{0,1,1,0,0},{1,1,0,0,0},{1,0,0,0,0} },
    stat_shield    = { {1,1,1,1,1},{1,1,0,1,1},{1,0,0,0,1},{0,1,0,1,0},{0,0,1,0,0} },
    stat_hourglass = { {1,1,1,1,1},{0,1,0,1,0},{0,0,1,0,0},{0,1,0,1,0},{1,1,1,1,1} },
    stat_star      = { {0,0,1,0,0},{1,1,1,1,1},{0,1,1,1,0},{0,1,0,1,0},{1,0,0,0,1} },
}

local function drawProceduralGlyph(name, x, y, color)
    local g = ProceduralGlyphs[name] or ProceduralGlyphs.stat_star
    for row = 1, #g do
        for col = 1, #g[row] do
            if g[row][col] == 1 then
                PixelCanvas.pixel(x + col - 1, y + row - 1, color)
            end
        end
    end
end

local WEDGE_SPANS = { 5, 3, 2, 1, 1 }
local function drawCornerWedge(x, y, dx, dy)
    for row = 0, 4 do
        for col = 0, WEDGE_SPANS[row + 1] - 1 do
            local c = Palette.AGED_GOLD
            if row + col >= WEDGE_SPANS[1] - 1 then
                c = Palette.AGED_GOLD_DARK
            end
            PixelCanvas.pixel(x + dx * col, y + dy * row, c)
        end
    end
    PixelCanvas.pixel(x, y, Palette.AGED_GOLD_LIGHT)
end

local MEDAL_HW = { 2, 3, 4, 5, 5, 5, 6, 5, 5, 5, 4, 3, 2 }

local function drawSealMedallion(cx, cy, typeColor)
    for i, hw in ipairs(MEDAL_HW) do
        PixelCanvas.hline(cx - hw, cy - 7 + i, hw * 2 + 1, Palette.INK)
    end
    for i, hw in ipairs(MEDAL_HW) do
        local r = hw - 1
        if r >= 0 then
            PixelCanvas.hline(cx - r, cy - 7 + i, r * 2 + 1, Palette.AGED_GOLD)
        end
    end
    for i, hw in ipairs(MEDAL_HW) do
        local r = hw - 2
        if r >= 0 then
            PixelCanvas.hline(cx - r, cy - 7 + i, r * 2 + 1, typeColor)
        end
    end
    for i, hw in ipairs(MEDAL_HW) do
        local r = hw - 2
        local y = cy - 7 + i
        if r >= 1 then
            if y < cy then
                PixelCanvas.hline(cx - r, y, r, Palette.lighten(typeColor, 0.30))
            elseif y > cy then
                PixelCanvas.hline(cx + 1, y, r, Palette.darken(typeColor, 0.45))
            end
        end
    end
    PixelCanvas.pixel(cx - 3, cy - 5, Palette.AGED_GOLD_LIGHT)
    PixelCanvas.pixel(cx - 4, cy - 4, Palette.AGED_GOLD_LIGHT)
    PixelCanvas.pixel(cx + 3, cy + 5, Palette.AGED_GOLD_DARK)
    PixelCanvas.pixel(cx + 4, cy + 4, Palette.AGED_GOLD_DARK)
    PixelCanvas.pixel(cx - 2, cy - 2, Palette.PARCHMENT_LIGHT)
end

local function drawStripeEnd(dX, cy, typeColor)
    PixelCanvas.pixel(dX,     cy - 2, Palette.AGED_GOLD_LIGHT)
    PixelCanvas.pixel(dX - 1, cy - 1, Palette.AGED_GOLD)
    PixelCanvas.pixel(dX,     cy - 1, Palette.lighten(typeColor, 0.35))
    PixelCanvas.pixel(dX + 1, cy - 1, Palette.AGED_GOLD)
    PixelCanvas.pixel(dX - 2, cy,     Palette.AGED_GOLD_DARK)
    PixelCanvas.pixel(dX - 1, cy,     typeColor)
    PixelCanvas.pixel(dX,     cy,     Palette.PARCHMENT_LIGHT)
    PixelCanvas.pixel(dX + 1, cy,     typeColor)
    PixelCanvas.pixel(dX + 2, cy,     Palette.AGED_GOLD_DARK)
    PixelCanvas.pixel(dX - 1, cy + 1, Palette.AGED_GOLD_DARK)
    PixelCanvas.pixel(dX,     cy + 1, Palette.darken(typeColor, 0.45))
    PixelCanvas.pixel(dX + 1, cy + 1, Palette.AGED_GOLD_DARK)
    PixelCanvas.pixel(dX,     cy + 2, Palette.AGED_GOLD_DARK)
end

local function chainBlades(x1, x2, cy)
    PixelCanvas.hline(x1, cy, x2 - x1 + 1, Palette.BLOOD_DARK)
    for x = x1 + 1, x2 - 2, 4 do
        PixelCanvas.pixel(x,     cy - 1, Palette.BLOOD)
        PixelCanvas.pixel(x + 1, cy,     Palette.lighten(Palette.BLOOD, 0.35))
        PixelCanvas.pixel(x,     cy + 1, Palette.BLOOD_DARK)
    end
end

local function chainRivets(x1, x2, cy)
    for x = x1 + 2, x2 - 2, 5 do
        PixelCanvas.pixel(x,     cy - 1, Palette.STEEL_LIGHT)
        PixelCanvas.pixel(x - 1, cy,     Palette.STEEL)
        PixelCanvas.pixel(x,     cy,     Palette.lighten(Palette.STEEL, 0.45))
        PixelCanvas.pixel(x + 1, cy,     Palette.darken(Palette.STEEL, 0.35))
        PixelCanvas.pixel(x,     cy + 1, Palette.darken(Palette.STEEL, 0.55))
    end
end

local function chainVine(x1, x2, cy)
    PixelCanvas.hline(x1, cy, x2 - x1 + 1, Palette.PARCHMENT_DARK)
    local n = 0
    for x = x1 + 2, x2 - 2, 5 do
        n = n + 1
        PixelCanvas.pixel(x,     cy - 1, Palette.MOSS)
        PixelCanvas.pixel(x - 1, cy,     Palette.MOSS)
        PixelCanvas.pixel(x + 1, cy,     Palette.MOSS)
        PixelCanvas.pixel(x,     cy + 1, Palette.darken(Palette.MOSS, 0.4))
        PixelCanvas.pixel(x, cy,
            n % 2 == 0 and Palette.GREEN_BRIGHT or Palette.AGED_GOLD_LIGHT)
    end
end

local function chainDots(x1, x2, cy)
    for x = x1 + 1, x2 - 1, 4 do
        PixelCanvas.pixel(x, cy, Palette.AGED_GOLD)
        PixelCanvas.pixel(x + 1, cy, Palette.AGED_GOLD_DARK)
    end
end

local CHAINS = {
    attack  = chainBlades,
    defense = chainRivets,
    effect  = chainVine,
}

local function seedFrom(id)
    local s = 0
    for i = 1, #(id or "") do
        s = (s + id:byte(i) * i * 31) % 9973
    end
    return s
end

local RUST_TINT = { 0.55, 0.29, 0.12, 0.40 }

local function drawWear(bx, by, bw, bh, seed)
    for y = by, by + bh - 1 do
        for x = bx, bx + bw - 2 do
            local edgeDist = math.min(x - bx, (bx + bw - 1) - x,
                                      y - by, (by + bh - 1) - y)
            local r = (x * 7919 + y * 6271 + seed * 131) % 211
            local thresh
            if edgeDist <= 1 then thresh = 9
            elseif edgeDist <= 3 then thresh = 3
            else thresh = 1 end
            if r < thresh then
                PixelCanvas.pixel(x,     y, { 0, 0, 0, 0.28 })
                PixelCanvas.pixel(x + 1, y, { 0, 0, 0, 0.16 })
            elseif r > 205 and edgeDist == 0 then
                PixelCanvas.pixel(x, y, RUST_TINT)
            end
        end
    end
end

function CardStatsFooter.draw(w, h, card)
    local fh = CardStatsFooter.HEIGHT
    local fy = h - fh - 1
    local typeColor = Palette.forCardType(card.type) or Palette.PARCHMENT_DARK

    local bx, by = 1, fy
    local bw, bh = w - 2, fh
    local cy = by + math.floor(bh / 2)

    PixelCanvas.rect(bx, by + bh, bw, 1, { 0, 0, 0, 0.7 })

    local inkTop = Palette.lerp(Palette.INK, Palette.PARCHMENT_DARK, 0.20)
    for row = 0, bh - 1 do
        local t = row / (bh - 1)
        PixelCanvas.hline(bx, by + row, bw, Palette.lerp(inkTop, Palette.INK, t))
    end

    local grainSeed = 0
    for i = 1, #(card.id or "") do grainSeed = (grainSeed + card.id:byte(i)) % 4093 end
    for y = by + 1, by + bh - 2 do
        for x = bx + 1, bx + bw - 2 do
            local g = (x * 3557 + y * 2953 + grainSeed * 41) % 17
            if g == 0 then
                PixelCanvas.pixel(x, y, { 1, 1, 1, 0.045 })
            elseif g == 1 then
                PixelCanvas.pixel(x, y, { 0, 0, 0, 0.10 })
            end
        end
    end

    local tex = BackgroundLoader.get(TYPE_PATTERNS[card.type])
    if tex then
        local quad = love.graphics.newQuad(0, 0, bw - 2, bh - 2,
            tex:getWidth(), tex:getHeight())
        love.graphics.setColor(1, 1, 1, 0.26)
        love.graphics.draw(tex, quad, bx + 1, by + 1)
        love.graphics.setColor(1, 1, 1, 1)
    end

    local stripeY = cy - 1
    PixelCanvas.hline(bx + 1, stripeY,     bw - 2, Palette.lighten(typeColor, 0.25))
    PixelCanvas.hline(bx + 1, stripeY + 1, bw - 2, typeColor)
    PixelCanvas.hline(bx + 1, stripeY + 2, bw - 2, Palette.darken(typeColor, 0.55))

    local bronze = Palette.lerp(Palette.AGED_GOLD_DARK, Palette.INK, 0.45)
    PixelCanvas.hline(bx, by, bw, Palette.AGED_GOLD_LIGHT)
    PixelCanvas.vline(bx, by, bh, Palette.AGED_GOLD)
    PixelCanvas.hline(bx, by + bh - 1, bw, Palette.AGED_GOLD_DARK)
    PixelCanvas.vline(bx + bw - 1, by, bh, Palette.AGED_GOLD_DARK)
    PixelCanvas.hline(bx + 1, by + 1, bw - 2, Palette.AGED_GOLD)
    PixelCanvas.vline(bx + 1, by + 1, bh - 2, Palette.AGED_GOLD_DARK)
    PixelCanvas.hline(bx + 1, by + bh - 2, bw - 2, bronze)
    PixelCanvas.vline(bx + bw - 2, by + 1, bh - 2, bronze)

    drawCornerWedge(bx + 2,      by + 2,       1,  1)
    drawCornerWedge(bx + bw - 3, by + 2,      -1,  1)
    drawCornerWedge(bx + 2,      by + bh - 3,  1, -1)
    drawCornerWedge(bx + bw - 3, by + bh - 3, -1, -1)

    drawWear(bx, by, bw, bh, seedFrom(card.id))

    local medCX = bx + 8
    PixelCanvas.hline(bx + 1, cy - 1, 2, Palette.AGED_GOLD_DARK)
    PixelCanvas.hline(bx + 1, cy,     2, Palette.AGED_GOLD)
    PixelCanvas.hline(bx + 1, cy + 1, 2, Palette.AGED_GOLD_DARK)
    drawSealMedallion(medCX, cy, typeColor)
    local glyphName = GLYPH_NAMES[card.type]
    if glyphName then
        local pngGlyph = tryLoadGlyph(glyphName)
        if pngGlyph then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(pngGlyph, medCX - 3, cy - 3, 0,
                7 / pngGlyph:getWidth(), 7 / pngGlyph:getHeight())
        else
            drawProceduralGlyph(glyphName, medCX - 2, cy - 2, Palette.AGED_GOLD_LIGHT)
        end
    end

    local font = PixelFont.get(10)
    love.graphics.setFont(font)
    local label = labelFor(card.type)
    local labelX = bx + 17
    local labelY = by + math.floor((bh - font:getHeight()) / 2)
    love.graphics.setColor(0, 0, 0, 1)
    for dx = -1, 1 do
        for dy = -1, 1 do
            if not (dx == 0 and dy == 0) then
                love.graphics.print(label, labelX + dx, labelY + dy)
            end
        end
    end
    love.graphics.setColor(Palette.AGED_GOLD_LIGHT)
    love.graphics.print(label, labelX, labelY)
    local labelEnd = labelX + font:getWidth(label)

    local value
    if card.type == "attack" and (card.attack or 0) > 0 then
        value = tostring(card.attack)
    elseif card.type == "defense" and (card.defense or 0) > 0 then
        value = tostring(card.defense)
    end

    local chainRight = bx + bw - 6
    if value then
        local statFont = PixelFont.get(12)
        local valueW = statFont:getWidth(value)
        local vx = bx + bw - 6 - valueW
        local vy = by + math.floor((bh - statFont:getHeight()) / 2) - 1
        local dX = vx - 6
        drawStripeEnd(dX, cy, typeColor)
        chainRight = dX - 5

        love.graphics.setFont(statFont)
        love.graphics.setColor(0, 0, 0, 1)
        for dx = -1, 1 do
            for dy = -1, 1 do
                if not (dx == 0 and dy == 0) then
                    love.graphics.print(value, vx + dx, vy + dy)
                end
            end
        end
        if (card.upgrades or 0) > 0 then
            love.graphics.setColor(0.55, 0.92, 0.45, 1)
        else
            love.graphics.setColor(Palette.AGED_GOLD_LIGHT)
        end
        love.graphics.print(value, vx, vy)
    end

    local chainLeft = labelEnd + 5
    if chainRight - chainLeft >= 8 then
        local chain = CHAINS[card.type] or chainDots
        chain(chainLeft, chainRight, cy)
    end
end

function CardStatsFooter.clearCache()
    glyphCache = {}
    glyphMissCache = {}
end

return CardStatsFooter
