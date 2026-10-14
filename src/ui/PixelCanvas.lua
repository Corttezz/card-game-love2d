local Palette = require("src.ui.Palette")

local PixelCanvas = {}

function PixelCanvas.enableNearest()
    love.graphics.setDefaultFilter("nearest", "nearest", 0)
end

function PixelCanvas.new(w, h)
    local c = love.graphics.newCanvas(w, h)
    c:setFilter("nearest", "nearest")
    return c
end

function PixelCanvas.beginDraw(canvas, clear)
    love.graphics.push("all")
    love.graphics.origin()
    love.graphics.setScissor()
    love.graphics.setCanvas(canvas)
    if clear ~= false then
        love.graphics.clear(0, 0, 0, 0)
    end
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 1)
end

function PixelCanvas.endDraw()
    love.graphics.pop()
end

function PixelCanvas.pixel(x, y, color)
    Palette.set(color)
    love.graphics.rectangle("fill", math.floor(x), math.floor(y), 1, 1)
end

function PixelCanvas.fill(color)
    Palette.set(color)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getCanvas():getWidth(), love.graphics.getCanvas():getHeight())
end

function PixelCanvas.rect(x, y, w, h, color)
    Palette.set(color)
    love.graphics.rectangle("fill", math.floor(x), math.floor(y), math.floor(w), math.floor(h))
end

function PixelCanvas.rectOutline(x, y, w, h, color)
    Palette.set(color)
    x, y, w, h = math.floor(x), math.floor(y), math.floor(w), math.floor(h)
    love.graphics.rectangle("fill", x, y, w, 1)
    love.graphics.rectangle("fill", x, y + h - 1, w, 1)
    love.graphics.rectangle("fill", x, y, 1, h)
    love.graphics.rectangle("fill", x + w - 1, y, 1, h)
end

function PixelCanvas.rectFramed(x, y, w, h, fill, outline)
    PixelCanvas.rect(x + 1, y + 1, w - 2, h - 2, fill)
    PixelCanvas.rectOutline(x, y, w, h, outline)
end

function PixelCanvas.rectRounded(x, y, w, h, radius, color)
    Palette.set(color)
    x, y, w, h = math.floor(x), math.floor(y), math.floor(w), math.floor(h)
    radius = math.max(0, math.min(math.floor(radius or 0), math.floor(math.min(w, h) / 2)))
    if radius <= 0 then
        love.graphics.rectangle("fill", x, y, w, h)
        return
    end
    love.graphics.rectangle("fill", x, y + radius, w, h - 2 * radius)
    love.graphics.rectangle("fill", x + radius, y, w - 2 * radius, h)
end

function PixelCanvas.rectRoundedOutline(x, y, w, h, radius, color)
    Palette.set(color)
    x, y, w, h = math.floor(x), math.floor(y), math.floor(w), math.floor(h)
    radius = math.max(0, math.min(math.floor(radius or 0), math.floor(math.min(w, h) / 2)))
    if radius <= 0 then
        PixelCanvas.rectOutline(x, y, w, h, color)
        return
    end
    love.graphics.rectangle("fill", x + radius, y, w - 2 * radius, 1)
    love.graphics.rectangle("fill", x + radius, y + h - 1, w - 2 * radius, 1)
    love.graphics.rectangle("fill", x, y + radius, 1, h - 2 * radius)
    love.graphics.rectangle("fill", x + w - 1, y + radius, 1, h - 2 * radius)
    for i = 1, radius - 1 do
        love.graphics.rectangle("fill", x + radius - i, y + i,             1, 1)
        love.graphics.rectangle("fill", x + w - radius + i - 1, y + i,     1, 1)
        love.graphics.rectangle("fill", x + radius - i, y + h - i - 1,     1, 1)
        love.graphics.rectangle("fill", x + w - radius + i - 1, y + h - i - 1, 1, 1)
    end
end

function PixelCanvas.hline(x, y, len, color)
    PixelCanvas.rect(x, y, len, 1, color)
end

function PixelCanvas.vline(x, y, len, color)
    PixelCanvas.rect(x, y, 1, len, color)
end

local function discHalfWidth(r, dy)
    local v = r * r - dy * dy
    if v < 0 then return -1 end
    return math.floor(math.sqrt(v) + 0.5)
end

function PixelCanvas.disc(cx, cy, r, color)
    Palette.set(color)
    cx, cy, r = math.floor(cx), math.floor(cy), math.floor(r)
    for dy = -r, r do
        local hw = discHalfWidth(r, dy)
        if hw >= 0 then
            love.graphics.rectangle("fill", cx - hw, cy + dy, hw * 2 + 1, 1)
        end
    end
end

function PixelCanvas.discOutline(cx, cy, r, color)
    Palette.set(color)
    cx, cy, r = math.floor(cx), math.floor(cy), math.floor(r)
    for dy = -r, r do
        local hw = discHalfWidth(r, dy)
        if hw >= 0 then
            local inner = discHalfWidth(r - 1, dy)
            if inner < 0 or dy == -r or dy == r then
                love.graphics.rectangle("fill", cx - hw, cy + dy, hw * 2 + 1, 1)
            else
                love.graphics.rectangle("fill", cx - hw, cy + dy, hw - inner, 1)
                love.graphics.rectangle("fill", cx + inner + 1, cy + dy, hw - inner, 1)
            end
        end
    end
end

function PixelCanvas.discShaded(cx, cy, r, top, bottom)
    cx, cy, r = math.floor(cx), math.floor(cy), math.floor(r)
    if r < 0 then return end
    for dy = -r, r do
        local hw = discHalfWidth(r, dy)
        if hw >= 0 then
            local t = (r > 0) and ((dy + r) / (2 * r)) or 0
            Palette.set(Palette.lerp(top, bottom, t))
            love.graphics.rectangle("fill", cx - hw, cy + dy, hw * 2 + 1, 1)
        end
    end
end

function PixelCanvas.drawBitmap(matrix, ox, oy, palette)
    palette = palette or Palette.INDEXED
    ox = math.floor(ox or 0)
    oy = math.floor(oy or 0)

    for row = 1, #matrix do
        local line = matrix[row]
        for col = 1, #line do
            local idx = line[col]
            if idx and idx ~= 0 then
                local color = palette[idx]
                if color then
                    Palette.set(color)
                    love.graphics.rectangle("fill", ox + col - 1, oy + row - 1, 1, 1)
                end
            end
        end
    end
end

function PixelCanvas.drawBitmapScaled(matrix, ox, oy, scale, palette)
    palette = palette or Palette.INDEXED
    ox = math.floor(ox or 0)
    oy = math.floor(oy or 0)
    scale = math.max(1, math.floor(scale or 1))

    for row = 1, #matrix do
        local line = matrix[row]
        for col = 1, #line do
            local idx = line[col]
            if idx and idx ~= 0 then
                local color = palette[idx]
                if color then
                    Palette.set(color)
                    love.graphics.rectangle("fill",
                        ox + (col - 1) * scale,
                        oy + (row - 1) * scale,
                        scale, scale)
                end
            end
        end
    end
end

function PixelCanvas.checker(x, y, w, h, colorA, colorB)
    for row = 0, h - 1 do
        for col = 0, w - 1 do
            local c = ((col + row) % 2 == 0) and colorA or colorB
            Palette.set(c)
            love.graphics.rectangle("fill", x + col, y + row, 1, 1)
        end
    end
end

function PixelCanvas.dither50(x, y, w, h, color)
    Palette.set(color)
    for row = 0, h - 1 do
        for col = 0, w - 1 do
            if (col + row) % 2 == 0 then
                love.graphics.rectangle("fill", x + col, y + row, 1, 1)
            end
        end
    end
end

function PixelCanvas.dither25(x, y, w, h, color)
    Palette.set(color)
    for row = 0, h - 1, 2 do
        for col = 0, w - 1, 2 do
            love.graphics.rectangle("fill", x + col, y + row, 1, 1)
        end
    end
end

return PixelCanvas
