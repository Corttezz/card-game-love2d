local Palette     = require("src.ui.Palette")
local PixelCanvas = require("src.ui.PixelCanvas")
local PixelFont   = require("src.ui.PixelFont")
local I18n        = require("src.i18n.I18n")

local CardHeader = {}

local _bannerCache  = {}
local _bannerMisses = {}
function CardHeader._getBannerBg(rarity)
    rarity = rarity or "common"
    if _bannerCache[rarity] then return _bannerCache[rarity] end
    if _bannerMisses[rarity] then return nil end
    local path = "assets/sprites/ui/banner_" .. rarity .. ".png"
    if not love.filesystem.getInfo(path) then
        _bannerMisses[rarity] = true
        return nil
    end
    local ok, img = pcall(love.graphics.newImage, path)
    if not ok or not img then
        _bannerMisses[rarity] = true
        return nil
    end
    img:setFilter("nearest", "nearest")
    local iw, ih = img:getWidth(), img:getHeight()
    local cropH = math.max(1, ih - 4)
    local quad = love.graphics.newQuad(0, 0, iw, cropH, iw, ih)
    local entry = { image = img, quad = quad, srcW = iw, srcH = cropH }
    _bannerCache[rarity] = entry
    return entry
end

CardHeader.HEIGHT_SINGLE = 18
CardHeader.HEIGHT_WRAP   = 24
CardHeader.HEIGHT = CardHeader.HEIGHT_SINGLE

local function fitsSingleLine(name, maxW)
    for _, size in ipairs({ 14, 12, 10 }) do
        if PixelFont.get(size):getWidth(name) <= maxW then return true end
    end
    return false
end

function CardHeader.computeHeight(cardOrName, w)
    local maxW = (w - 30) - 16
    local name
    if type(cardOrName) == "table" then
        name = I18n.cardName(cardOrName)
    else
        name = cardOrName or "?"
    end
    if fitsSingleLine(name, maxW) then
        return CardHeader.HEIGHT_SINGLE
    end
    return CardHeader.HEIGHT_WRAP
end

local function styleFor(rarity)
    rarity = rarity or "common"
    if rarity == "uncommon" then
        return {
            outer    = Palette.AGED_GOLD,
            innerHi  = Palette.AGED_GOLD_LIGHT,
            innerLo  = Palette.MOSS,
            accent   = Palette.MOSS,
            accentHi = Palette.GREEN_BRIGHT,
            gem      = Palette.MOSS,
            edgeKind = "leaf",
            topKind  = "dots_uncommon",
        }
    elseif rarity == "rare" then
        return {
            outer    = Palette.AGED_GOLD,
            innerHi  = Palette.AGED_GOLD_LIGHT,
            innerLo  = Palette.BLOOD_DARK,
            accent   = Palette.BLOOD,
            accentHi = Palette.PARCHMENT_LIGHT,
            gem      = Palette.BLOOD,
            edgeKind = "ruby",
            topKind  = "crown_rare",
        }
    elseif rarity == "legendary" then
        return {
            outer    = Palette.AGED_GOLD_LIGHT,
            innerHi  = Palette.PARCHMENT_LIGHT,
            innerLo  = Palette.AGED_GOLD_DARK,
            accent   = Palette.AGED_GOLD,
            accentHi = Palette.PARCHMENT_LIGHT,
            gem      = Palette.AGED_GOLD_LIGHT,
            edgeKind = "medallion",
            topKind  = "sparkles",
        }
    else
        return {
            outer    = Palette.AGED_GOLD,
            innerHi  = Palette.AGED_GOLD_DARK,
            innerLo  = Palette.AGED_GOLD_DARK,
            accent   = Palette.AGED_GOLD,
            accentHi = Palette.AGED_GOLD_LIGHT,
            gem      = Palette.AGED_GOLD,
            edgeKind = "diamond",
            topKind  = "dots_simple",
        }
    end
end

local function drawDiamondSimple(cx, cy, st)
    PixelCanvas.pixel(cx,     cy - 1, st.accentHi)
    PixelCanvas.pixel(cx - 1, cy,     st.accent)
    PixelCanvas.pixel(cx,     cy,     st.accentHi)
    PixelCanvas.pixel(cx + 1, cy,     st.accent)
    PixelCanvas.pixel(cx,     cy + 1, Palette.AGED_GOLD_DARK)
    PixelCanvas.pixel(cx - 2, cy - 1, Palette.AGED_GOLD_DARK)
    PixelCanvas.pixel(cx + 2, cy - 1, Palette.AGED_GOLD_DARK)
    PixelCanvas.pixel(cx - 2, cy + 1, Palette.AGED_GOLD_DARK)
    PixelCanvas.pixel(cx + 2, cy + 1, Palette.AGED_GOLD_DARK)
end

local function drawLeaf(cx, cy, st)
    PixelCanvas.pixel(cx,     cy - 2, st.accentHi)
    PixelCanvas.pixel(cx - 1, cy - 1, st.accent)
    PixelCanvas.pixel(cx + 1, cy - 1, st.accent)
    PixelCanvas.pixel(cx,     cy - 1, st.accentHi)
    PixelCanvas.pixel(cx - 1, cy,     st.accent)
    PixelCanvas.pixel(cx,     cy,     Palette.AGED_GOLD_LIGHT)
    PixelCanvas.pixel(cx + 1, cy,     st.accent)
    PixelCanvas.pixel(cx,     cy + 1, Palette.AGED_GOLD_DARK)
    PixelCanvas.pixel(cx,     cy + 2, Palette.AGED_GOLD_DARK)
end

local function drawRuby(cx, cy, st)
    PixelCanvas.pixel(cx,     cy - 2, Palette.AGED_GOLD_LIGHT)
    PixelCanvas.pixel(cx - 1, cy - 1, st.accent)
    PixelCanvas.pixel(cx,     cy - 1, st.accentHi)
    PixelCanvas.pixel(cx + 1, cy - 1, st.accent)
    PixelCanvas.pixel(cx - 1, cy,     Palette.BLOOD_DARK)
    PixelCanvas.pixel(cx,     cy,     st.accent)
    PixelCanvas.pixel(cx + 1, cy,     Palette.BLOOD_DARK)
    PixelCanvas.pixel(cx - 1, cy + 1, st.accent)
    PixelCanvas.pixel(cx,     cy + 1, Palette.BLOOD_DARK)
    PixelCanvas.pixel(cx + 1, cy + 1, st.accent)
    PixelCanvas.pixel(cx,     cy + 2, Palette.INK)
end

local function drawMedallion(cx, cy, st)
    for col = -2, 2 do PixelCanvas.pixel(cx + col, cy - 2, st.accent) end
    for col = -2, 2 do PixelCanvas.pixel(cx + col, cy + 2, Palette.AGED_GOLD_DARK) end
    PixelCanvas.pixel(cx - 2, cy - 1, st.accent)
    PixelCanvas.pixel(cx + 2, cy - 1, st.accent)
    PixelCanvas.pixel(cx - 2, cy,     Palette.AGED_GOLD_DARK)
    PixelCanvas.pixel(cx + 2, cy,     Palette.AGED_GOLD_DARK)
    PixelCanvas.pixel(cx - 2, cy + 1, Palette.AGED_GOLD_DARK)
    PixelCanvas.pixel(cx + 2, cy + 1, Palette.AGED_GOLD_DARK)
    PixelCanvas.pixel(cx - 1, cy - 1, st.accentHi)
    PixelCanvas.pixel(cx,     cy - 1, st.gem)
    PixelCanvas.pixel(cx - 1, cy,     st.accent)
    PixelCanvas.pixel(cx,     cy,     st.accentHi)
    PixelCanvas.pixel(cx + 1, cy,     st.accent)
    PixelCanvas.pixel(cx,     cy + 1, Palette.AGED_GOLD_DARK)
end

local function drawEndCap(kind, cx, cy, st)
    if     kind == "leaf"      then drawLeaf(cx, cy, st)
    elseif kind == "ruby"      then drawRuby(cx, cy, st)
    elseif kind == "medallion" then drawMedallion(cx, cy, st)
    else                            drawDiamondSimple(cx, cy, st)
    end
end

local function drawTopDotsSimple(bx, by, bw, st)
    for i = 0, 2 do
        local px = bx + 12 + i * math.floor((bw - 24) / 3)
        PixelCanvas.pixel(px, by, st.accentHi)
    end
end

local function drawTopDotsUncommon(bx, by, bw, st)
    for i = 0, 4 do
        local px = bx + 10 + i * math.floor((bw - 20) / 4)
        if i % 2 == 0 then
            PixelCanvas.pixel(px, by, st.accent)
            PixelCanvas.pixel(px, by - 1, st.accentHi)
        else
            PixelCanvas.pixel(px, by, Palette.AGED_GOLD_LIGHT)
        end
    end
end

local function drawTopCrownRare(bx, by, bw, st)
    local positions = { 12, math.floor(bw / 2), bw - 13 }
    for _, dx in ipairs(positions) do
        local px = bx + dx
        PixelCanvas.pixel(px,     by - 2, Palette.AGED_GOLD_LIGHT)
        PixelCanvas.pixel(px - 1, by - 1, st.accent)
        PixelCanvas.pixel(px,     by - 1, Palette.PARCHMENT_LIGHT)
        PixelCanvas.pixel(px + 1, by - 1, st.accent)
        PixelCanvas.pixel(px,     by,     Palette.BLOOD_DARK)
    end
    PixelCanvas.pixel(bx + math.floor(bw * 0.30), by, Palette.AGED_GOLD_LIGHT)
    PixelCanvas.pixel(bx + math.floor(bw * 0.70), by, Palette.AGED_GOLD_LIGHT)
end

local function drawTopSparklesLegendary(bx, by, bw, st)
    local positions = {
        { bx + 12,                       0 },
        { bx + math.floor(bw * 0.30),   -1 },
        { bx + math.floor(bw / 2),       0 },
        { bx + math.floor(bw * 0.70),   -1 },
        { bx + bw - 13,                  0 },
    }
    for i, p in ipairs(positions) do
        local px, dy = p[1], p[2]
        local cy = by + dy
        if i % 2 == 1 then
            PixelCanvas.pixel(px,     cy - 1, st.accentHi)
            PixelCanvas.pixel(px - 1, cy,     st.gem)
            PixelCanvas.pixel(px,     cy,     st.accentHi)
            PixelCanvas.pixel(px + 1, cy,     st.gem)
            PixelCanvas.pixel(px,     cy + 1, st.gem)
        else
            PixelCanvas.pixel(px,     cy,     st.accentHi)
            PixelCanvas.pixel(px,     cy - 1, st.accent)
        end
    end
end

local function drawTopTrim(kind, bx, by, bw, st)
    if     kind == "dots_uncommon" then drawTopDotsUncommon(bx, by, bw, st)
    elseif kind == "crown_rare"    then drawTopCrownRare(bx, by, bw, st)
    elseif kind == "sparkles"      then drawTopSparklesLegendary(bx, by, bw, st)
    else                                drawTopDotsSimple(bx, by, bw, st)
    end
end

local function drawBottomTrim(rarity, bx, by, bw, bh, st)
    if rarity == "legendary" then
        PixelCanvas.pixel(bx + 4,        by + bh,     st.accent)
        PixelCanvas.pixel(bx + 4,        by + bh + 1, Palette.AGED_GOLD_DARK)
        PixelCanvas.pixel(bx + bw - 5,   by + bh,     st.accent)
        PixelCanvas.pixel(bx + bw - 5,   by + bh + 1, Palette.AGED_GOLD_DARK)
        PixelCanvas.pixel(bx + math.floor(bw / 2), by + bh,     Palette.AGED_GOLD_LIGHT)
        PixelCanvas.pixel(bx + math.floor(bw / 2), by + bh + 1, Palette.AGED_GOLD_DARK)
    elseif rarity == "rare" then
        PixelCanvas.hline(bx + 6, by + bh, bw - 12, Palette.BLOOD_DARK)
    elseif rarity == "uncommon" then
        for i = bx + 8, bx + bw - 8, 4 do
            PixelCanvas.pixel(i, by + bh, st.accent)
        end
    end
end

function CardHeader.draw(w, cardName, rarity)
    local h  = CardHeader.computeHeight(cardName, w)
    local st = styleFor(rarity)
    local bx, by = 15, 3
    local bw, bh = w - 30, h

    local bgEntry = CardHeader._getBannerBg(rarity)
    if bgEntry then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(bgEntry.image, bgEntry.quad, bx, by, 0,
                           bw / bgEntry.srcW, bh / bgEntry.srcH)
    else
        PixelCanvas.rect(bx + 1, by + bh, bw, 1, { 0, 0, 0, 0.55 })
        PixelCanvas.rect(bx, by, bw, bh, Palette.INK)
        PixelCanvas.rectOutline(bx, by, bw, bh, st.outer)
        PixelCanvas.rectOutline(bx + 1, by + 1, bw - 2, bh - 2, Palette.AGED_GOLD_DARK)
        PixelCanvas.hline(bx + 2, by + 2,      bw - 4, st.innerHi)
        PixelCanvas.hline(bx + 2, by + bh - 3, bw - 4, { 0, 0, 0, 0.7 })
        drawEndCap(st.edgeKind, bx + 4,        by + math.floor(bh / 2), st)
        drawEndCap(st.edgeKind, bx + bw - 5,   by + math.floor(bh / 2), st)
        drawTopTrim(st.topKind, bx, by, bw, st)
        drawBottomTrim(rarity, bx, by, bw, bh, st)
    end

    local utf8 = require("utf8")
    local name = cardName or "?"
    local maxW = bw - 16

    local function truncate(s, f)
        local out = s
        local suffix = "."
        while f:getWidth(out) > maxW and utf8.len(out) > 1 do
            local cutAt = utf8.offset(out, -1)
            if not cutAt then break end
            out = out:sub(1, cutAt - 1) .. suffix
            suffix = ""
        end
        return out
    end

    local function wordWrap(text, f)
        local words = {}
        for w in text:gmatch("%S+") do table.insert(words, w) end
        if #words == 0 then return { text } end
        local result, current = {}, ""
        for _, word in ipairs(words) do
            local try = current == "" and word or (current .. " " .. word)
            if f:getWidth(try) <= maxW then
                current = try
            else
                if current ~= "" then table.insert(result, current) end
                current = word
            end
        end
        if current ~= "" then table.insert(result, current) end
        return result
    end

    local function allFit(wrappedLines, f)
        for _, line in ipairs(wrappedLines) do
            if f:getWidth(line) > maxW then return false end
        end
        return true
    end

    local font, lines
    for _, size in ipairs({ 14, 12, 10 }) do
        local f = PixelFont.get(size)
        if f:getWidth(name) <= maxW then
            font, lines = f, { name }
            break
        end
    end

    if not font then
        for _, size in ipairs({ 10, 9, 8, 7 }) do
            local f = PixelFont.get(size)
            local wrapped = wordWrap(name, f)
            if #wrapped == 1 and f:getWidth(wrapped[1]) <= maxW then
                font, lines = f, wrapped
                break
            elseif #wrapped == 2 and allFit(wrapped, f) then
                font, lines = f, wrapped
                break
            end
        end
    end

    if not font then
        for _, size in ipairs({ 8, 7, 6 }) do
            local f = PixelFont.get(size)
            if f:getWidth(name) <= maxW then
                font, lines = f, { name }
                break
            end
        end
    end
    if not font then
        font = PixelFont.get(7)
        local wrapped = wordWrap(name, font)
        if #wrapped >= 2 then
            lines = { truncate(wrapped[1], font), truncate(wrapped[2], font) }
        else
            lines = { truncate(name, font) }
        end
    end

    love.graphics.setFont(font)
    local singleLine = #lines == 1
    local lineH = singleLine and font:getHeight() or (font:getHeight() - 2)
    local totalH = lineH * #lines
    local opticalOffset = singleLine and 0 or -2
    local startY = by + math.floor((bh - totalH) / 2) + opticalOffset

    local textHi = Palette.AGED_GOLD_LIGHT
    local textLo = Palette.AGED_GOLD_DARK

    for i, line in ipairs(lines) do
        local ty = startY + (i - 1) * lineH

        love.graphics.setColor(0, 0, 0, 1)
        for dx = -1, 1 do
            for dy = -1, 1 do
                if not (dx == 0 and dy == 0) then
                    love.graphics.printf(line, bx + dx, ty + dy, bw, "center")
                end
            end
        end
        love.graphics.setColor(textLo)
        love.graphics.printf(line, bx, ty + 1, bw, "center")
        love.graphics.setColor(textHi)
        love.graphics.printf(line, bx, ty, bw, "center")
    end
end

return CardHeader
