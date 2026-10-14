local Palette     = require("src.ui.Palette")
local PixelCanvas = require("src.ui.PixelCanvas")

local PixelBackground = {}

local cache = {}

local function keyOf(name, w, h)
    return name .. "_" .. w .. "x" .. h
end

local function seedRand(x, y, salt)
    local n = x * 374761393 + y * 668265263 + (salt or 0) * 1103515245
    n = (n % 2147483647)
    return (n / 2147483647)
end

function PixelBackground.casinoTable(w, h)
    local k = keyOf("casino", w, h)
    if cache[k] then return cache[k] end

    local canvas = PixelCanvas.new(w, h)
    PixelCanvas.beginDraw(canvas, true)

    PixelCanvas.rect(0, 0, w, h, { 0.05, 0.18, 0.10, 1 })
    for yy = 0, h - 1, 2 do
        for xx = 0, w - 1, 2 do
            if seedRand(xx, yy, 7) < 0.08 then
                love.graphics.setColor(0.08, 0.24, 0.13, 1)
                love.graphics.rectangle("fill", xx, yy, 1, 1)
            end
        end
    end
    for step = 0, 40 do
        local alpha = (step / 40) * 0.4
        love.graphics.setColor(0, 0, 0, alpha * 0.04)
        love.graphics.rectangle("line", step, step, w - step * 2, h - step * 2)
    end

    PixelCanvas.endDraw()
    cache[k] = canvas
    return canvas
end

function PixelBackground.voidStars(w, h)
    local k = keyOf("voidStars", w, h)
    if cache[k] then return cache[k] end

    local canvas = PixelCanvas.new(w, h)
    PixelCanvas.beginDraw(canvas, true)

    PixelCanvas.rect(0, 0, w, h, Palette.VOID)

    for i = 1, 180 do
        local x = math.floor(seedRand(i, 1, 11) * w)
        local y = math.floor(seedRand(i, 2, 13) * h)
        PixelCanvas.pixel(x, y, Palette.CYAN_PALE)
    end
    for i = 1, 30 do
        local x = math.floor(seedRand(i, 3, 17) * w)
        local y = math.floor(seedRand(i, 4, 19) * h)
        PixelCanvas.pixel(x, y, Palette.YELLOW)
        PixelCanvas.pixel(x + 1, y, Palette.ORANGE)
        PixelCanvas.pixel(x, y + 1, Palette.ORANGE)
    end
    for i = 1, 5 do
        local cx = math.floor(seedRand(i, 5, 23) * w)
        local cy = math.floor(seedRand(i, 6, 29) * h)
        for r = 0, 20 do
            for a = 0, 6.28, 0.3 do
                local px = math.floor(cx + math.cos(a) * r)
                local py = math.floor(cy + math.sin(a) * r * 0.6)
                if px >= 0 and px < w and py >= 0 and py < h then
                    if seedRand(px, py, 31) < 0.05 * (1 - r / 20) then
                        PixelCanvas.pixel(px, py, Palette.PURPLE_DEEP)
                    end
                end
            end
        end
    end

    PixelCanvas.endDraw()
    cache[k] = canvas
    return canvas
end

function PixelBackground.dungeon(w, h)
    local k = keyOf("dungeon", w, h)
    if cache[k] then return cache[k] end

    local canvas = PixelCanvas.new(w, h)
    PixelCanvas.beginDraw(canvas, true)

    PixelCanvas.rect(0, 0, w, h, Palette.BG_DEEPEST)

    local tile = 16
    for row = 0, math.floor(h / tile) do
        for col = 0, math.floor(w / tile) do
            local tx = col * tile
            local ty = row * tile
            if row % 2 == 1 then tx = tx - tile / 2 end

            local variant = math.floor(seedRand(col, row, 41) * 3)
            local baseColor = Palette.BG_DEEP
            if variant == 1 then baseColor = Palette.BG_MID end
            if variant == 2 then baseColor = Palette.OUTLINE_SOFT end

            PixelCanvas.rect(tx, ty, tile - 1, tile - 1, baseColor)
            PixelCanvas.rect(tx + 1, ty + 1, tile - 3, 1, Palette.lighten(baseColor, 0.2))
            PixelCanvas.rect(tx + 1, ty + tile - 3, tile - 3, 1, Palette.darken(baseColor, 0.6))
        end
    end

    PixelCanvas.endDraw()
    cache[k] = canvas
    return canvas
end

function PixelBackground.parchment(w, h)
    local k = keyOf("parchment", w, h)
    if cache[k] then return cache[k] end

    local canvas = PixelCanvas.new(w, h)
    PixelCanvas.beginDraw(canvas, true)

    PixelCanvas.rect(0, 0, w, h, { 0.85, 0.72, 0.48, 1 })
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local n = seedRand(x, y, 43)
            if n < 0.03 then
                love.graphics.setColor(0.5, 0.35, 0.15, 1)
                love.graphics.rectangle("fill", x, y, 1, 1)
            elseif n < 0.06 then
                love.graphics.setColor(0.7, 0.55, 0.3, 1)
                love.graphics.rectangle("fill", x, y, 1, 1)
            end
        end
    end

    PixelCanvas.endDraw()
    cache[k] = canvas
    return canvas
end

function PixelBackground.clearCache()
    cache = {}
end

return PixelBackground
