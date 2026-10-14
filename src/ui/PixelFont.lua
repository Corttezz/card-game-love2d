local PixelFont = {}

local cache = {}

function PixelFont.get(size)
    size = math.floor(size or 10)
    if not cache[size] then
        local f = love.graphics.newFont(size)
        f:setFilter("nearest", "nearest")
        cache[size] = f
    end
    return cache[size]
end

function PixelFont.tiny()     return PixelFont.get(8)  end
function PixelFont.small()    return PixelFont.get(10) end
function PixelFont.body()     return PixelFont.get(12) end
function PixelFont.header()   return PixelFont.get(14) end
function PixelFont.title()    return PixelFont.get(20) end
function PixelFont.heading()  return PixelFont.get(28) end

function PixelFont.drawShadowed(text, x, y, size, color, shadowColor)
    local font = PixelFont.get(size)
    love.graphics.setFont(font)
    local sr, sg, sb, sa = love.graphics.getColor()

    if shadowColor then
        love.graphics.setColor(shadowColor[1], shadowColor[2], shadowColor[3], shadowColor[4] or 1)
    else
        love.graphics.setColor(0, 0, 0, 0.7)
    end
    love.graphics.print(text, math.floor(x + 1), math.floor(y + 1))

    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    love.graphics.print(text, math.floor(x), math.floor(y))

    love.graphics.setColor(sr, sg, sb, sa)
end

function PixelFont.clearCache()
    cache = {}
end

return PixelFont
