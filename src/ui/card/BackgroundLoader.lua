-- src/ui/card/BackgroundLoader.lua
-- Carrega PNGs de fundo (patterns) gerados via PixelLab.
-- Preferência: PNG em assets/sprites/backgrounds/patterns/<name>.png
-- Fallback: nil (o compositor então desenha o pattern procedural legado).
--
-- Uso:
--   local img = BackgroundLoader.get("stone")  -- love.Image ou nil
--   if img then love.graphics.draw(img, x, y) end

local BackgroundLoader = {}

local cache = {}
local missCache = {}

local function tryLoad(name)
    local path = "assets/sprites/backgrounds/patterns/" .. name .. ".png"
    if not love.filesystem.getInfo(path) then return nil end
    local ok, img = pcall(love.graphics.newImage, path)
    if not ok or not img then return nil end
    img:setFilter("nearest", "nearest")
    img:setWrap("repeat", "repeat")
    return img
end

function BackgroundLoader.get(name)
    if not name then return nil end
    if cache[name] then return cache[name] end
    if missCache[name] then return nil end
    local img = tryLoad(name)
    if img then
        cache[name] = img
    else
        missCache[name] = true
    end
    return img
end

function BackgroundLoader.clearCache()
    cache = {}
    missCache = {}
end

return BackgroundLoader
