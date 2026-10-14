local Debug = require("src.core.Debug")

local ImageCache = {}

local cache = {}
local missCache = {}
local FALLBACK_PATH = "assets/cards/attack/theRock.png"
local fallbackImage = nil

function ImageCache.get(path)
    if not path or path == "" then
        return ImageCache.getFallback()
    end

    if cache[path] then
        return cache[path]
    end
    if missCache[path] then
        return ImageCache.getFallback()
    end

    local ok, image = pcall(love.graphics.newImage, path)
    if ok then
        cache[path] = image
        return image
    end

    missCache[path] = true
    Debug.warn("[ImageCache] falha ao carregar: " .. tostring(path))
    return ImageCache.getFallback()
end

function ImageCache.tryGet(path)
    if not path or path == "" then return nil end
    if cache[path] then return cache[path] end
    if missCache[path] then return nil end
    local ok, image = pcall(love.graphics.newImage, path)
    if ok then
        cache[path] = image
        return image
    end
    missCache[path] = true
    Debug.warn("[ImageCache] falha ao carregar: " .. tostring(path))
    return nil
end

function ImageCache.getFallback()
    if not fallbackImage then
        fallbackImage = love.graphics.newImage(FALLBACK_PATH)
    end
    return fallbackImage
end

function ImageCache.preload(paths)
    for _, path in ipairs(paths or {}) do
        ImageCache.get(path)
    end
end

function ImageCache.clear()
    cache = {}
    missCache = {}
    fallbackImage = nil
end

function ImageCache.stats()
    local count = 0
    for _ in pairs(cache) do count = count + 1 end
    return { entries = count }
end

return ImageCache
