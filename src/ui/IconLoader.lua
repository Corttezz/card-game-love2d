local PixelIcons  = require("src.ui.PixelIcons")
local PixelCanvas = require("src.ui.PixelCanvas")

local IconLoader = {}

local handleCache = {}

local function tryLoadPNG(name)
    local path = "assets/sprites/icons/" .. name .. ".png"
    if not love.filesystem.getInfo(path) then return nil end
    local ok, img = pcall(love.graphics.newImage, path)
    if ok and img then
        img:setFilter("nearest", "nearest")
        return img
    end
    return nil
end

function IconLoader.get(name)
    if handleCache[name] then return handleCache[name] end

    local png = tryLoadPNG(name)
    if png then
        local h = {
            kind = "image",
            image = png,
            path = "assets/sprites/icons/" .. name .. ".png",
            size = { w = png:getWidth(), h = png:getHeight() },
            draw = function(x, y, scale)
                scale = scale or 1
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(png, math.floor(x), math.floor(y), 0, scale, scale)
            end,
        }
        handleCache[name] = h
        return h
    end

    local matrix = PixelIcons.get(name)
    local size = #matrix > 0 and { w = #matrix[1], h = #matrix } or { w = 16, h = 16 }
    local h = {
        kind = "matrix",
        matrix = matrix,
        size = size,
        draw = function(x, y, scale)
            PixelCanvas.drawBitmapScaled(matrix, x, y, scale or 1)
        end,
    }
    handleCache[name] = h
    return h
end

function IconLoader.bounds(name)
    local h = IconLoader.get(name)
    if h.bounds then return h.bounds end
    local b = { x = 0, y = 0, w = h.size.w, h = h.size.h }
    if h.kind == "image" then
        local ok, data = pcall(love.image.newImageData, h.path)
        if ok and data then
            local w, hh = data:getDimensions()
            local x0, y0, x1, y1 = w, hh, -1, -1
            for y = 0, hh - 1 do
                for x = 0, w - 1 do
                    local _, _, _, a = data:getPixel(x, y)
                    if a > 0.08 then
                        if x < x0 then x0 = x end
                        if x > x1 then x1 = x end
                        if y < y0 then y0 = y end
                        if y > y1 then y1 = y end
                    end
                end
            end
            if x1 >= x0 then b = { x = x0, y = y0, w = x1 - x0 + 1, h = y1 - y0 + 1 } end
        end
    end
    h.bounds = b
    return b
end

function IconLoader.drawScaled(name, cx, cy, s)
    local h = IconLoader.get(name)
    local b = IconLoader.bounds(name)
    h.draw(cx - (b.x + b.w / 2) * s, cy - (b.y + b.h / 2) * s, s)
    return s
end

function IconLoader.drawFit(name, cx, cy, box)
    local b = IconLoader.bounds(name)
    return IconLoader.drawScaled(name, cx, cy, box / math.max(b.w, b.h))
end

function IconLoader.clearCache()
    handleCache = {}
end

function IconLoader.computeScale(iconH, targetSize)
    if iconH <= targetSize then
        return math.max(1, math.floor(targetSize / iconH))
    else
        return targetSize / iconH
    end
end

return IconLoader
