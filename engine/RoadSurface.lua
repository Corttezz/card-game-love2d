local Debug = require("src.core.Debug")
local RoadTiles = require("engine.RoadTiles")

local RoadSurface = {}

local cache = {}

function RoadSurface.style(bid)
    return RoadTiles.style(bid)
end

function RoadSurface.get(bid, pal, yieldEvery)
    local hit = cache[bid]
    if hit ~= nil then return hit or nil end
    local ok, img = pcall(RoadTiles.bake, bid, pal or {}, yieldEvery)
    if not ok or not img then
        Debug.warn(("[RoadSurface] bake do bioma '%s' falhou: %s"):format(tostring(bid), tostring(img)))
        cache[bid] = false
        return nil
    end
    if not cache[bid] then cache[bid] = img end
    return cache[bid]
end

function RoadSurface.has(bid) return cache[bid] ~= nil end

function RoadSurface.clear() cache = {} end

return RoadSurface
