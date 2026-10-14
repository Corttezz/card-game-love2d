local Palette     = require("src.ui.Palette")
local PixelCanvas = require("src.ui.PixelCanvas")
local FontManager = require("src.ui.FontManager")
local TextFit     = require("src.ui.TextFit")

local ShopEngraving = {}

local function withA(c, a)
    return { c[1], c[2], c[3], (c[4] or 1) * (a or 1) }
end

local function seedOf(s)
    local h = 0
    for i = 1, #tostring(s or "") do
        h = (h + tostring(s):byte(i) * i * 31) % 9973
    end
    return h
end
ShopEngraving.seedOf = seedOf

function ShopEngraving.sealRadius(objW, cost)
    local r = math.max(8, math.min(14, math.floor((objW or 0) * 0.13)))
    local digits = cost and #tostring(math.max(0, math.floor(cost))) or 3
    r = r + math.min(4, digits * 2)
    return r
end

function ShopEngraving.sealAnchor(rect, cost)
    local r = ShopEngraving.sealRadius(rect.w, cost)
    return math.floor(rect.x + rect.w - r), math.floor(rect.y + r), r
end

function ShopEngraving.sealRect(rect, cost)
    local cx, cy, r = ShopEngraving.sealAnchor(rect, cost)
    return { x = cx - r, y = cy - r, w = r * 2 + 1, h = r * 2 + 1 }
end

function ShopEngraving.priceSeal(cx, cy, r, cost, opts)
    opts = opts or {}
    local alpha  = opts.alpha or 1
    local afford = opts.afford ~= false
    if alpha <= 0.01 or r < 4 then return end
    cx, cy, r = math.floor(cx), math.floor(cy), math.floor(r)

    local body = afford and Palette.AGED_GOLD or Palette.BLOOD
    local rim  = afford and Palette.INK       or Palette.BLOOD_DARK

    local glow = opts.glow or 0
    if glow > 0.01 then
        PixelCanvas.disc(cx, cy, r + 2,
            withA(Palette.lighten(body, 0.45), alpha * 0.30 * glow))
    end

    PixelCanvas.disc(cx + 2, cy + 2, r, withA(Palette.INK, alpha * 0.55))
    PixelCanvas.disc(cx, cy, r, withA(rim, alpha))
    PixelCanvas.discShaded(cx, cy, r - 2,
        withA(Palette.lighten(body, 0.28), alpha),
        withA(Palette.darken(body, 0.50), alpha))

    local milled = withA(Palette.lighten(body, 0.55), alpha * 0.8)
    for i = 0, 7 do
        local a = i * math.pi / 4 + math.pi / 8
        PixelCanvas.pixel(cx + math.floor(math.cos(a) * (r - 1) + 0.5),
                          cy + math.floor(math.sin(a) * (r - 1) + 0.5), milled)
    end
    local txt = "$" .. tostring(cost or 0)
    local size = (r >= 12) and 11 or 9
    local font = FontManager.getFont(size)
    if size > 9 and font:getWidth(txt) > r * 2 - 6 then
        size = 9
        font = FontManager.getFont(size)
    end
    local fitted = txt
    love.graphics.setFont(font)
    local tx = cx - math.floor(font:getWidth(fitted) / 2)
    local ty = cy - math.floor(font:getHeight() / 2)
    local hi = afford and Palette.lighten(body, 0.75) or Palette.lighten(body, 0.55)
    love.graphics.setColor(hi[1], hi[2], hi[3], alpha * 0.8)
    love.graphics.print(fitted, tx + 1, ty + 1)
    local ink = afford and Palette.INK or Palette.PARCHMENT_LIGHT
    love.graphics.setColor(ink[1], ink[2], ink[3], alpha)
    love.graphics.print(fitted, tx, ty)
    love.graphics.setColor(1, 1, 1, 1)
end

function ShopEngraving.stampPrice(rect, cost, opts)
    if (cost or 0) <= 0 then return end
    local cx, cy, r = ShopEngraving.sealAnchor(rect, cost)
    ShopEngraving.priceSeal(cx, cy, r, cost, opts)
end

local WEDGE = { 4, 2, 1 }
local function drawCornerWedge(x, y, dx, dy)
    for row = 0, #WEDGE - 1 do
        for col = 0, WEDGE[row + 1] - 1 do
            local c = (row + col >= WEDGE[1] - 1) and Palette.AGED_GOLD_DARK
                                                   or Palette.AGED_GOLD
            PixelCanvas.pixel(x + dx * col, y + dy * row, c)
        end
    end
    PixelCanvas.pixel(x, y, Palette.AGED_GOLD_LIGHT)
end

local function drawStripeEnd(x, cy, accent, dir)
    PixelCanvas.pixel(x, cy - 2, Palette.AGED_GOLD_LIGHT)
    PixelCanvas.pixel(x - dir, cy - 1, Palette.AGED_GOLD)
    PixelCanvas.pixel(x, cy - 1, Palette.lighten(accent, 0.35))
    PixelCanvas.pixel(x + dir, cy - 1, Palette.AGED_GOLD)
    PixelCanvas.pixel(x - dir * 2, cy, Palette.AGED_GOLD_DARK)
    PixelCanvas.pixel(x - dir, cy, accent)
    PixelCanvas.pixel(x, cy, Palette.PARCHMENT_LIGHT)
    PixelCanvas.pixel(x + dir, cy, accent)
    PixelCanvas.pixel(x + dir * 2, cy, Palette.AGED_GOLD_DARK)
    PixelCanvas.pixel(x - dir, cy + 1, Palette.AGED_GOLD_DARK)
    PixelCanvas.pixel(x, cy + 1, Palette.darken(accent, 0.45))
    PixelCanvas.pixel(x + dir, cy + 1, Palette.AGED_GOLD_DARK)
    PixelCanvas.pixel(x, cy + 2, Palette.AGED_GOLD_DARK)
end

local RUST_TINT = { 0.55, 0.29, 0.12, 0.40 }

local function drawWear(w, h, seed)
    for y = 0, h - 1 do
        for x = 0, w - 2 do
            local edge = math.min(x, w - 1 - x, y, h - 1 - y)
            local r = (x * 7919 + y * 6271 + seed * 131) % 211
            local thresh = (edge <= 1) and 9 or ((edge <= 3) and 3 or 1)
            if r < thresh then
                PixelCanvas.pixel(x, y, { 0, 0, 0, 0.28 })
                PixelCanvas.pixel(x + 1, y, { 0, 0, 0, 0.16 })
            elseif r > 205 and edge == 0 then
                PixelCanvas.pixel(x, y, RUST_TINT)
            end
        end
    end
end

local function renderStrip(w, h, text, accent, seed)
    local canvas = PixelCanvas.new(w, h)
    PixelCanvas.beginDraw(canvas)

    local top = Palette.lerp(Palette.INK, Palette.PARCHMENT_DARK, 0.22)
    for row = 0, h - 1 do
        PixelCanvas.hline(0, row, w, Palette.lerp(top, Palette.INK, row / math.max(1, h - 1)))
    end

    for y = 1, h - 2 do
        for x = 1, w - 2 do
            local g = (x * 3557 + y * 2953 + seed * 41) % 17
            if g == 0 then
                PixelCanvas.pixel(x, y, { 1, 1, 1, 0.05 })
            elseif g == 1 then
                PixelCanvas.pixel(x, y, { 0, 0, 0, 0.11 })
            end
        end
    end

    local cy = math.floor(h / 2)

    PixelCanvas.hline(1, cy - 1, w - 2, Palette.lighten(accent, 0.25))
    PixelCanvas.hline(1, cy,     w - 2, accent)
    PixelCanvas.hline(1, cy + 1, w - 2, Palette.darken(accent, 0.55))

    local bronze = Palette.lerp(Palette.AGED_GOLD_DARK, Palette.INK, 0.45)
    PixelCanvas.hline(0, 0, w, Palette.AGED_GOLD_LIGHT)
    PixelCanvas.vline(0, 0, h, Palette.AGED_GOLD)
    PixelCanvas.hline(0, h - 1, w, Palette.AGED_GOLD_DARK)
    PixelCanvas.vline(w - 1, 0, h, Palette.AGED_GOLD_DARK)
    PixelCanvas.hline(1, h - 2, w - 2, bronze)
    PixelCanvas.vline(w - 2, 1, h - 2, bronze)

    drawCornerWedge(1, 1,         1,  1)
    drawCornerWedge(w - 2, 1,    -1,  1)
    drawCornerWedge(1, h - 2,     1, -1)
    drawCornerWedge(w - 2, h - 2, -1, -1)

    drawWear(w, h, seed)

    local font, fitted = TextFit.fit(text, math.max(8, math.min(11, h - 5)), w - 26)
    love.graphics.setFont(font)
    local tw = font:getWidth(fitted)
    local tx = math.floor((w - tw) / 2)
    local ty = math.floor((h - font:getHeight()) / 2)

    local pad = 4
    if tx - pad - 3 >= 3 then
        PixelCanvas.rect(tx - pad, cy - 1, tw + pad * 2, 3,
            Palette.lerp(top, Palette.INK, 0.5))
        drawStripeEnd(tx - pad - 3, cy, accent, -1)
        drawStripeEnd(tx + tw + pad + 3, cy, accent, 1)
    end

    FontManager.drawWithOutline(fitted, tx, ty,
        { Palette.PARCHMENT_LIGHT[1], Palette.PARCHMENT_LIGHT[2],
          Palette.PARCHMENT_LIGHT[3], 1 }, 1)

    PixelCanvas.endDraw()
    return canvas
end

local function renderValuePlate(w, h, label, value, accent, seed)
    local canvas = PixelCanvas.new(w, h)
    PixelCanvas.beginDraw(canvas)

    local top = Palette.lerp(Palette.INK, Palette.PARCHMENT_DARK, 0.22)
    for row = 0, h - 1 do
        PixelCanvas.hline(0, row, w, Palette.lerp(top, Palette.INK, row / math.max(1, h - 1)))
    end
    for y = 1, h - 2 do
        for x = 1, w - 2 do
            local g = (x * 3557 + y * 2953 + seed * 41) % 17
            if g == 0 then
                PixelCanvas.pixel(x, y, { 1, 1, 1, 0.05 })
            elseif g == 1 then
                PixelCanvas.pixel(x, y, { 0, 0, 0, 0.11 })
            end
        end
    end

    local bronze = Palette.lerp(Palette.AGED_GOLD_DARK, Palette.INK, 0.45)
    PixelCanvas.hline(0, 0, w, Palette.AGED_GOLD_LIGHT)
    PixelCanvas.vline(0, 0, h, Palette.AGED_GOLD)
    PixelCanvas.hline(0, h - 1, w, Palette.AGED_GOLD_DARK)
    PixelCanvas.vline(w - 1, 0, h, Palette.AGED_GOLD_DARK)
    PixelCanvas.hline(1, h - 2, w - 2, bronze)
    PixelCanvas.vline(w - 2, 1, h - 2, bronze)
    drawCornerWedge(1, 1,         1,  1)
    drawCornerWedge(w - 2, 1,    -1,  1)
    drawCornerWedge(1, h - 2,     1, -1)
    drawCornerWedge(w - 2, h - 2, -1, -1)

    local function engrave(text, font, x, y, color)
        love.graphics.setFont(font)
        love.graphics.setColor(0, 0, 0, 0.85)
        love.graphics.print(text, x + 1, y + 1)
        love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
        love.graphics.print(text, x, y)
    end

    local fl = FontManager.getFont(8)
    engrave(label, fl, math.floor((w - fl:getWidth(label)) / 2), 4,
        { Palette.PARCHMENT[1], Palette.PARCHMENT[2], Palette.PARCHMENT[3], 0.95 })
    local ruleY = 5 + fl:getHeight()
    PixelCanvas.hline(6, ruleY, w - 12, Palette.lighten(accent, 0.25))
    PixelCanvas.hline(6, ruleY + 1, w - 12, Palette.darken(accent, 0.55))

    local fv = FontManager.getFont(14)
    local vc = Palette.lighten(accent, 0.62)
    engrave(value, fv, math.floor((w - fv:getWidth(value)) / 2),
        ruleY + 3 + math.floor((h - ruleY - 3 - fv:getHeight()) / 2), vc)

    drawWear(w, h, seed + 7)
    PixelCanvas.endDraw()
    return canvas
end

local function pixelDiamond(cx, cy, r, color)
    Palette.set(color)
    for dy = -r, r do
        local hw = r - math.abs(dy)
        love.graphics.rectangle("fill", math.floor(cx - hw), math.floor(cy + dy),
            hw * 2 + 1, 1)
    end
end

function ShopEngraving.marker(cx, cy, text, color, fontSize, dia)
    local f = FontManager.getFont(fontSize or 8)
    love.graphics.setFont(f)
    local tw = f:getWidth(text)
    local fh = f:getHeight()
    dia = dia or 3
    local dx = math.floor(tw / 2) + 12
    for _, sx in ipairs({ -1, 1 }) do
        local px = cx + sx * dx
        pixelDiamond(px, cy + 1, dia, { 0, 0, 0, 0.8 })
        pixelDiamond(px, cy, dia, color)
    end
    local tx = cx - math.floor(tw / 2)
    local ty = cy - math.floor(fh / 2)
    love.graphics.setColor(0, 0, 0, 0.85)
    for _, o in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
        love.graphics.print(text, tx + o[1], ty + o[2])
    end
    love.graphics.setColor(color[1], color[2], color[3], 1)
    love.graphics.print(text, tx, ty)
    love.graphics.setColor(1, 1, 1, 1)
end

local stripCache = {}
local stripCount = 0

local function colorKey(c)
    return ("%d.%d.%d"):format(c[1] * 255, c[2] * 255, c[3] * 255)
end

function ShopEngraving.effectStrip(x, y, w, h, text, opts)
    opts = opts or {}
    w, h = math.floor(w), math.floor(h)
    if w < 24 or h < 9 or not text or text == "" then return end
    local accent = opts.accent or Palette.AGED_GOLD
    local seed   = opts.seed or 0
    local key = ("%d|%d|%s|%s|%d"):format(w, h, text, colorKey(accent), seed)

    local canvas = stripCache[key]
    if not canvas then
        if stripCount > 96 then ShopEngraving.clearCache() end
        canvas = renderStrip(w, h, text, accent, seed)
        stripCache[key] = canvas
        stripCount = stripCount + 1
    end

    local a = opts.alpha or 1
    local d = opts.dim or 1
    love.graphics.setColor(0, 0, 0, 0.55 * a)
    love.graphics.rectangle("fill", math.floor(x), math.floor(y) + h, w, 1)
    love.graphics.setColor(d, d, d, a)
    love.graphics.draw(canvas, math.floor(x), math.floor(y))
    love.graphics.setColor(1, 1, 1, 1)
end

function ShopEngraving.valuePlate(x, y, w, h, label, value, opts)
    opts = opts or {}
    w, h = math.floor(w), math.floor(h)
    if w < 24 or h < 20 then return end
    local accent = opts.accent or Palette.AGED_GOLD
    local seed = opts.seed or 0
    local key = ("V%d|%d|%s|%s|%s|%d"):format(w, h, label, value, colorKey(accent), seed)
    local canvas = stripCache[key]
    if not canvas then
        if stripCount > 96 then ShopEngraving.clearCache() end
        canvas = renderValuePlate(w, h, label, value, accent, seed)
        stripCache[key] = canvas
        stripCount = stripCount + 1
    end
    local a, d = opts.alpha or 1, opts.dim or 1
    love.graphics.setColor(0, 0, 0, 0.55 * a)
    love.graphics.rectangle("fill", math.floor(x), math.floor(y) + h, w, 1)
    love.graphics.setColor(d, d, d, a)
    love.graphics.draw(canvas, math.floor(x), math.floor(y))
    love.graphics.setColor(1, 1, 1, 1)
end

function ShopEngraving.clearCache()
    stripCache = {}
    stripCount = 0
end

return ShopEngraving
