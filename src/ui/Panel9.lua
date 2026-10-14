local Palette = require("src.ui.Palette")

local Panel9 = {}

local SPECS = {
    panel_main  = { margin = 26, scale = 2 },
    panel_inner = { margin = 22, scale = 2 },
    panel_gold  = { margin = 26, scale = 2 },
}

local cache = {}

local function trimBBox(data)
    local w, h = data:getWidth(), data:getHeight()
    local minX, minY, maxX, maxY = w, h, 0, 0
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local _, _, _, a = data:getPixel(x, y)
            if a > 0.02 then
                if x < minX then minX = x end
                if y < minY then minY = y end
                if x > maxX then maxX = x end
                if y > maxY then maxY = y end
            end
        end
    end
    if maxX <= minX then return nil end
    return minX, minY, maxX - minX + 1, maxY - minY + 1
end

local function load(name)
    if cache[name] ~= nil then return cache[name] end
    local spec = SPECS[name]
    local path = "assets/sprites/ui/" .. name .. ".png"
    if not spec or not love.filesystem.getInfo(path) then
        cache[name] = false
        return false
    end
    local ok, data = pcall(love.image.newImageData, path)
    if not ok then cache[name] = false return false end
    local bx, by, bw, bh = trimBBox(data)
    if not bx then cache[name] = false return false end
    local trimmed = love.image.newImageData(bw, bh)
    trimmed:paste(data, 0, 0, bx, by, bw, bh)
    local img = love.graphics.newImage(trimmed)
    img:setFilter("nearest", "nearest")

    local m = math.min(spec.margin, math.floor(math.min(bw, bh) / 3))
    local q = love.graphics.newQuad
    local entry = {
        img = img, m = m, w = bw, h = bh, scale = spec.scale or 2,
        quads = {
            tl = q(0,      0,      m,          m,          bw, bh),
            t  = q(m,      0,      bw - 2 * m, m,          bw, bh),
            tr = q(bw - m, 0,      m,          m,          bw, bh),
            l  = q(0,      m,      m,          bh - 2 * m, bw, bh),
            c  = q(m,      m,      bw - 2 * m, bh - 2 * m, bw, bh),
            r  = q(bw - m, m,      m,          bh - 2 * m, bw, bh),
            bl = q(0,      bh - m, m,          m,          bw, bh),
            b  = q(m,      bh - m, bw - 2 * m, m,          bw, bh),
            br = q(bw - m, bh - m, m,          m,          bw, bh),
        },
    }
    cache[name] = entry
    return entry
end

local function drawFallback(x, y, w, h, fill)
    local f = fill or { 0.09, 0.07, 0.055, 0.96 }
    love.graphics.setColor(f)
    love.graphics.rectangle("fill", x, y, w, h)
    love.graphics.setLineWidth(2)
    Palette.set(Palette.AGED_GOLD)
    love.graphics.rectangle("line", x + 1, y + 1, w - 2, h - 2)
    Palette.set(Palette.AGED_GOLD_DARK)
    love.graphics.rectangle("line", x + 4, y + 4, w - 8, h - 8)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

function Panel9.draw(name, x, y, w, h, opts)
    opts = opts or {}
    x, y = math.floor(x), math.floor(y)
    w, h = math.floor(w), math.floor(h)

    local p = load(name)
    if not p then
        drawFallback(x, y, w, h, opts.fill)
        return
    end

    local s = opts.scale or p.scale
    local m = p.m * s
    if w < 2 * m + 4 or h < 2 * m + 4 then
        drawFallback(x, y, w, h, opts.fill)
        return
    end

    if opts.fill then
        love.graphics.setColor(opts.fill)
        love.graphics.rectangle("fill", x + 2, y + 2, w - 4, h - 4)
    end

    local img, q = p.img, p.quads
    local ew = p.w - 2 * p.m
    local eh = p.h - 2 * p.m
    local innerW, innerH = w - 2 * m, h - 2 * m

    love.graphics.setColor(opts.tint or { 1, 1, 1, 1 })
    love.graphics.draw(img, q.tl, x, y, 0, s, s)
    love.graphics.draw(img, q.tr, x + w - m, y, 0, s, s)
    love.graphics.draw(img, q.bl, x, y + h - m, 0, s, s)
    love.graphics.draw(img, q.br, x + w - m, y + h - m, 0, s, s)
    love.graphics.draw(img, q.t, x + m, y, 0, innerW / ew, s)
    love.graphics.draw(img, q.b, x + m, y + h - m, 0, innerW / ew, s)
    love.graphics.draw(img, q.l, x, y + m, 0, s, innerH / eh)
    love.graphics.draw(img, q.r, x + w - m, y + m, 0, s, innerH / eh)
    love.graphics.draw(img, q.c, x + m, y + m, 0, innerW / ew, innerH / eh)
    love.graphics.setColor(1, 1, 1, 1)
end

function Panel9.has(name)
    return load(name) ~= false
end

function Panel9.clearCache()
    cache = {}
end

return Panel9
