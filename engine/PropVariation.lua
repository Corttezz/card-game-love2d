local PropVariation = {}

local out = { tintR = 1, tintG = 1, tintB = 1, scale = 1, flip = 1,
              windPhase = 0, canopy = 0, trunk = 0 }

local function hash01(n)
    local v = math.sin(n * 127.1 + 311.7) * 43758.5453
    return v - math.floor(v)
end

function PropVariation.of(seed, kind, tbl)
    seed = seed or 0
    tbl = tbl or out
    local h1 = hash01(seed * 1.37 + 0.11)
    local h2 = hash01(seed * 2.19 + 7.3)
    local h3 = hash01(seed * 0.73 + 19.1)
    local h4 = hash01(seed * 3.31 + 2.2)
    local h5 = hash01(seed * 5.07 + 41.9)
    local h6 = hash01(seed * 1.91 + 3.7)
    local tk = tbl.tint or 0
    out.tintR = 1 + (h1 - 0.5) * 2 * tk
    out.tintG = 1 + (h2 - 0.5) * 2 * tk * 0.6
    out.tintB = 1 + (h3 - 0.5) * 2 * tk
    out.scale = 1 + (h4 - 0.5) * 2 * (tbl.scale or 0)
    out.flip = (tbl.flip and h5 < 0.5) and -1 or 1
    out.windPhase = tbl.windPhase and (h6 * 6.2832) % 6.2832 or 0
    if kind == "bush" then
        out.canopy = tbl.bushSway or 0
        out.trunk = 0
    else
        out.canopy = tbl.canopySway or 0
        out.trunk = tbl.trunkSway or 0
    end
    return out
end

function PropVariation.sway(v, time, gust, stiff, reduced)
    if reduced then return 0, 0 end
    local ph = time * 1.15 + (v.windPhase or 0)
    local rot = math.sin(ph) * (v.trunk or 0)
    local kx = math.sin(ph * 1.3 + 0.7) * (v.canopy or 0) - (gust or 0) * (stiff or 0)
    return rot, kx
end

return PropVariation
