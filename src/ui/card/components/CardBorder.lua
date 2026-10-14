local Palette     = require("src.ui.Palette")
local PixelCanvas = require("src.ui.PixelCanvas")

local CardBorder = {}

local _sprites = {}
local _spritesLoaded = false
local function loadSprites()
    if _spritesLoaded then return _sprites end
    _spritesLoaded = true
    local files = {
        corner_flourish  = "assets/sprites/ui/corner_flourish.png",
        vertical_divider = "assets/sprites/ui/vertical_divider.png",
        wear_overlay     = "assets/sprites/ui/wear_overlay.png",
        knotwork_strip   = "assets/sprites/ui/knotwork_strip.png",
        edge_medallion   = "assets/sprites/ui/edge_medallion.png",
    }
    for k, path in pairs(files) do
        if love.filesystem.getInfo(path) then
            local ok, img = pcall(love.graphics.newImage, path)
            if ok and img then
                img:setFilter("nearest", "nearest")
                _sprites[k] = img
            end
        end
    end
    return _sprites
end

local function drawRotatedSprite(img, rot, x, y, w, h)
    if not img then return end
    local iw, ih = img:getWidth(), img:getHeight()
    local sx = w / iw
    local sy = h / ih
    love.graphics.setColor(1, 1, 1, 1)
    if rot == 0 then
        love.graphics.draw(img, x, y, 0, sx, sy)
    elseif rot == 1 then
        love.graphics.draw(img, x + w, y, math.pi / 2, sy, sx)
    elseif rot == 2 then
        love.graphics.draw(img, x + w, y + h, math.pi, sx, sy)
    elseif rot == 3 then
        love.graphics.draw(img, x, y + h, -math.pi / 2, sy, sx)
    end
end

local function drawCornerScroll(ox, oy, dx, dy, variant)
    variant = variant or 1
    local patterns = {
        {
            { 0, 0, "G" }, { 1, 0, "G" }, { 2, 0, "G" },
            { 0, 1, "G" }, { 1, 1, "L" },
            { 0, 2, "G" }, { 2, 2, "d" },
            { 3, 3, "d" }, { 4, 4, "d" }, { 5, 5, "G" },
        },
        {
            { 0, 0, "G" }, { 1, 0, "L" }, { 2, 0, "G" },
            { 0, 1, "L" }, { 2, 1, "G" },
            { 0, 2, "G" }, { 1, 2, "G" }, { 3, 2, "d" },
            { 3, 3, "G" }, { 4, 4, "d" }, { 5, 5, "G" },
        },
    }
    local pattern = patterns[variant]
    local colors = {
        G = Palette.AGED_GOLD,
        L = Palette.AGED_GOLD_LIGHT,
        d = Palette.AGED_GOLD_DARK,
    }
    for _, p in ipairs(pattern) do
        PixelCanvas.pixel(ox + dx * p[1], oy + dy * p[2], colors[p[3]])
    end
end

local function drawDamage(w, h, seed)
    local crackCount = 5
    for i = 1, crackCount do
        local edge = ((seed * i * 31) % 4)
        local along, across
        if edge == 0 then
            along = 12 + (seed * i * 7) % (w - 24)
            across = 1
            PixelCanvas.pixel(along, across, Palette.INK)
            PixelCanvas.pixel(along + 1, across + 1, Palette.INK)
            PixelCanvas.pixel(along, across + 2, Palette.INK)
        elseif edge == 1 then
            along = 12 + (seed * i * 7) % (h - 24)
            across = w - 2
            PixelCanvas.pixel(across, along, Palette.INK)
            PixelCanvas.pixel(across - 1, along + 1, Palette.INK)
            PixelCanvas.pixel(across - 2, along, Palette.INK)
        elseif edge == 2 then
            along = 12 + (seed * i * 7) % (w - 24)
            across = h - 2
            PixelCanvas.pixel(along, across, Palette.INK)
            PixelCanvas.pixel(along + 1, across - 1, Palette.INK)
            PixelCanvas.pixel(along, across - 2, Palette.INK)
        else
            along = 12 + (seed * i * 7) % (h - 24)
            across = 1
            PixelCanvas.pixel(across, along, Palette.INK)
            PixelCanvas.pixel(across + 1, along + 1, Palette.INK)
            PixelCanvas.pixel(across + 2, along, Palette.INK)
        end
    end

    local chunks = 3
    for i = 1, chunks do
        local x = 5 + (seed * i * 23) % (w - 10)
        local y = 5 + (seed * i * 19) % (h - 10)
        if x < 10 or x > w - 10 or y < 10 or y > h - 10 then
            PixelCanvas.rect(x, y, 2, 2, Palette.PARCHMENT_DARK)
            PixelCanvas.pixel(x, y, Palette.INK)
        end
    end

    for i = 1, 15 do
        local x = (seed * i * 11 + 5) % (w - 4) + 2
        local y = (seed * i * 13 + 3) % (h - 4) + 2
        if x < 8 or x > w - 9 or y < 8 or y > h - 9 then
            PixelCanvas.pixel(x, y, Palette.PARCHMENT_DARK)
        end
    end

    local fx = 5 + (seed * 29) % (w - 10)
    local fy = 5 + (seed * 37) % (h - 10)
    if fx < 10 or fx > w - 12 or fy < 10 or fy > h - 12 then
        PixelCanvas.pixel(fx, fy, Palette.PARCHMENT_LIGHT)
        PixelCanvas.pixel(fx + 1, fy, Palette.PARCHMENT_LIGHT)
        PixelCanvas.pixel(fx, fy + 1, Palette.PARCHMENT_LIGHT)
    end
end

local function drawCorner(ox, oy, dx, dy, size, mainColor, highlightColor, gem, sparkle)
    for i = 0, size - 1 do
        PixelCanvas.pixel(ox + dx * i, oy, mainColor)
    end
    for i = 0, size - 1 do
        PixelCanvas.pixel(ox, oy + dy * i, mainColor)
    end
    PixelCanvas.pixel(ox + dx, oy + dy, Palette.INK)
    if highlightColor then
        for i = 1, size - 2 do
            PixelCanvas.pixel(ox + dx * i, oy - dy, highlightColor)
            PixelCanvas.pixel(ox - dx, oy + dy * i, highlightColor)
        end
    end
    if gem then
        PixelCanvas.pixel(ox + dx, oy, gem)
        PixelCanvas.pixel(ox, oy + dy, gem)
    end
    if sparkle then
        PixelCanvas.pixel(ox + dx * (size + 1), oy + dy * (size + 1), sparkle)
        PixelCanvas.pixel(ox + dx * (size + 2), oy + dy * (size + 2), Palette.AGED_GOLD)
    end
end

local function drawRarityCorners(w, h, rarity, seed)
    if rarity == "common" or rarity == "basic" or not rarity then return end
    local INSET = 13
    local x1, y1 = INSET, INSET
    local x2, y2 = w - 1 - INSET, INSET
    local x3, y3 = INSET, h - 1 - INSET
    local x4, y4 = w - 1 - INSET, h - 1 - INSET

    if rarity == "uncommon" then
        local s = 8
        drawCorner(x1, y1,  1,  1, s, Palette.MOSS, Palette.GREEN_BRIGHT, nil, nil)
        drawCorner(x2, y2, -1,  1, s, Palette.MOSS, Palette.GREEN_BRIGHT, nil, nil)
        drawCorner(x3, y3,  1, -1, s, Palette.MOSS, Palette.GREEN_BRIGHT, nil, nil)
        drawCorner(x4, y4, -1, -1, s, Palette.MOSS, Palette.GREEN_BRIGHT, nil, nil)

    elseif rarity == "rare" then
        local s = 10
        drawCorner(x1, y1,  1,  1, s, Palette.BLOOD, Palette.BLOOD_DARK, Palette.AGED_GOLD, nil)
        drawCorner(x2, y2, -1,  1, s, Palette.BLOOD, Palette.BLOOD_DARK, Palette.AGED_GOLD, nil)
        drawCorner(x3, y3,  1, -1, s, Palette.BLOOD, Palette.BLOOD_DARK, Palette.AGED_GOLD, nil)
        drawCorner(x4, y4, -1, -1, s, Palette.BLOOD, Palette.BLOOD_DARK, Palette.AGED_GOLD, nil)

    elseif rarity == "legendary" then
        local s = 12
        drawCorner(x1, y1,  1,  1, s, Palette.AGED_GOLD, Palette.AGED_GOLD_LIGHT, Palette.PARCHMENT_LIGHT, Palette.AGED_GOLD_LIGHT)
        drawCorner(x2, y2, -1,  1, s, Palette.AGED_GOLD, Palette.AGED_GOLD_LIGHT, Palette.PARCHMENT_LIGHT, Palette.AGED_GOLD_LIGHT)
        drawCorner(x3, y3,  1, -1, s, Palette.AGED_GOLD, Palette.AGED_GOLD_LIGHT, Palette.PARCHMENT_LIGHT, Palette.AGED_GOLD_LIGHT)
        drawCorner(x4, y4, -1, -1, s, Palette.AGED_GOLD, Palette.AGED_GOLD_LIGHT, Palette.PARCHMENT_LIGHT, Palette.AGED_GOLD_LIGHT)
    end
end

function CardBorder.draw(w, h, cardType, rarity, cardId)
    local sprites = loadSprites()

    local seed = 1
    if cardId then
        for i = 1, #cardId do
            seed = (seed * 31 + cardId:byte(i)) % 997
        end
    end

    PixelCanvas.rectOutline(0, 0, w, h, Palette.INK)
    PixelCanvas.rectOutline(1, 1, w - 2, h - 2, Palette.PARCHMENT_DARK)
    PixelCanvas.rectOutline(2, 2, w - 4, h - 4, Palette.PARCHMENT)
    PixelCanvas.rectOutline(3, 3, w - 6, h - 6, Palette.PARCHMENT_DARK)
    PixelCanvas.rectOutline(4, 4, w - 8, h - 8, Palette.INK)
    PixelCanvas.rectOutline(5, 5, w - 10, h - 10, Palette.AGED_GOLD)
    PixelCanvas.rectOutline(6, 6, w - 12, h - 12, Palette.AGED_GOLD_DARK)

    if sprites.knotwork_strip then
        local strip = sprites.knotwork_strip
        local sw, sh = strip:getWidth(), strip:getHeight()
        local targetW = w - 16
        local targetH = 10
        local scaleX = targetW / sw
        local scaleY = targetH / sh
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(strip, 8, 1, 0, scaleX, scaleY)
        love.graphics.draw(strip, 8, h - 1, 0, scaleX, -scaleY)
    end

    if sprites.vertical_divider then
        local div = sprites.vertical_divider
        local dw, dh = 6, math.min(h - 32, 60)
        local sw, sh = div:getWidth(), div:getHeight()
        local scaleX = dw / sw
        local scaleY = dh / sh
        local leftY = 16 + (seed % 12)
        local rightY = 16 + ((seed * 7) % 12)
        love.graphics.draw(div, 1, leftY, 0, scaleX, scaleY)
        love.graphics.draw(div, w - 1 - dw, rightY, 0, scaleX, scaleY)
    end

    if sprites.edge_medallion then
        local med = sprites.edge_medallion
        local ms = 10
        local s = ms / med:getWidth()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(med, math.floor((w - ms) / 2), 0, 0, s, s)
        love.graphics.draw(med, math.floor((w - ms) / 2), h - ms, 0, s, s)
        love.graphics.draw(med, 0, math.floor((h - ms) / 2), 0, s, s)
        love.graphics.draw(med, w - ms, math.floor((h - ms) / 2), 0, s, s)
    end

    if sprites.corner_flourish then
        local cw, ch = 18, 18
        drawRotatedSprite(sprites.corner_flourish, 0, 0, 0, cw, ch)
        drawRotatedSprite(sprites.corner_flourish, 1, w - cw, 0, cw, ch)
        drawRotatedSprite(sprites.corner_flourish, 2, w - cw, h - ch, cw, ch)
        drawRotatedSprite(sprites.corner_flourish, 3, 0, h - ch, cw, ch)
    else
        drawCornerScroll(2, 2, 1, 1, 1)
        drawCornerScroll(w - 3, 2, -1, 1, 1)
        drawCornerScroll(2, h - 3, 1, -1, 2)
        drawCornerScroll(w - 3, h - 3, -1, -1, 2)
    end

    drawDamage(w, h, seed)

    if sprites.wear_overlay then
        love.graphics.setColor(1, 1, 1, 0.20)
        love.graphics.draw(sprites.wear_overlay, 0, 0, 0,
                           w / sprites.wear_overlay:getWidth(),
                           h / sprites.wear_overlay:getHeight())
        love.graphics.setColor(1, 1, 1, 1)
    end

    drawRarityCorners(w, h, rarity, seed)
end

return CardBorder
