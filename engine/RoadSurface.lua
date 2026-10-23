local Debug = require("src.core.Debug")

local RoadSurface = {}

local cache = {}

local W, H = 192, 512

local function latHash(i, j, seed)
    local v = math.sin(i * 127.1 + j * 311.7 + seed * 74.7) * 43758.5453
    return v - math.floor(v)
end

local function vnoise(x, y, nx, ny, seed)
    local gx, gy = x / W * nx, y / H * ny
    local i, j = math.floor(gx), math.floor(gy)
    local fx, fy = gx - i, gy - j
    local ux = fx * fx * (3 - 2 * fx)
    local uy = fy * fy * (3 - 2 * fy)
    local i1, j1 = (i + 1) % nx, (j + 1) % ny
    i, j = i % nx, j % ny
    local a = latHash(i, j, seed)
    local b = latHash(i1, j, seed)
    local c = latHash(i, j1, seed)
    local d = latHash(i1, j1, seed)
    return a + (b - a) * ux + (c - a) * uy + (a - b - c + d) * ux * uy
end

local function fbm(x, y, seed)
    return vnoise(x, y, 8, 20, seed) * 0.62
         + vnoise(x, y, 21, 52, seed + 7) * 0.38
end

local function mulc(c, k) return { c[1] * k, c[2] * k, c[3] * k } end
local function mixc(a, b, k)
    return { a[1] + (b[1] - a[1]) * k, a[2] + (b[2] - a[2]) * k,
             a[3] + (b[3] - a[3]) * k }
end

local function voronoi(x, y, nx, ny, seed, ky)
    local gx, gy = x / W * nx, y / H * ny
    local ci, cj = math.floor(gx), math.floor(gy)
    local d1, d2, id = 1e9, 1e9, 0
    for dj = -1, 1 do
        for di = -1, 1 do
            local i, j = ci + di, cj + dj
            local wi, wj = i % nx, j % ny
            local jx = latHash(wi, wj, seed) * 0.7 + 0.15
            local jy = latHash(wi, wj, seed + 3) * 0.7 + 0.15
            local dx = (i + jx) - gx
            local dy = (j + jy) - gy
            local d = math.max(math.abs(dx) * 1.0, math.abs(dy) * (ky or 0.78))
            if d < d1 then d2 = d1; d1 = d; id = wi * 131 + wj
            elseif d < d2 then d2 = d end
        end
    end
    return (d2 - d1), id
end

local function bake(bid, pal, yieldEvery)
    local roadA = pal.roadA or { 0.45, 0.33, 0.20 }
    local roadB = pal.roadB or mulc(roadA, 0.86)
    local edge  = pal.roadEdge or mulc(roadA, 0.45)
    local tones = {
        mulc(roadB, 0.90), roadB, roadA, mulc(roadA, 1.14),
    }
    local seed = 0
    for i = 1, #bid do seed = seed + bid:byte(i) end

    local d = love.image.newImageData(W, H)
    local idx = {}
    local slab = bid == "highlands"
    local cracked = bid == "abyss"

    for y = 0, H - 1 do
        if yieldEvery and y % yieldEvery == yieldEvery - 1 then
            coroutine.yield()
        end
        idx[y] = {}
        for x = 0, W - 1 do
            local n = fbm(x, y, seed)
            local ti
            if n < 0.38 then ti = 1
            elseif n < 0.52 then ti = 2
            elseif n < 0.70 then ti = 3
            else ti = 4 end
            if slab then
                local dj, id = voronoi(x, y, 14, 36, seed + 11, 1.35)
                if dj < 0.055 then ti = 0
                else
                    ti = 2 + math.floor(latHash(id % 97, math.floor(id / 97), seed) * 2.4)
                    ti = math.min(4, ti)
                    if dj < 0.11 and n > 0.74 then ti = 0 end
                end
            elseif cracked then
                local dj = voronoi(x, y, 18, 40, seed + 23)
                if dj < 0.026 then ti = 0 end
            end
            idx[y][x] = ti
        end
    end

    for y = 0, H - 1 do
        if yieldEvery and y % yieldEvery == yieldEvery - 1 then
            coroutine.yield()
        end
        for x = 0, W - 1 do
            local ti = idx[y][x]
            local c
            if ti == 0 then
                c = { edge[1], edge[2], edge[3] }
            else
                c = { tones[ti][1], tones[ti][2], tones[ti][3] }
                local up = idx[(y - 1) % H][x]
                local dn = idx[(y + 1) % H][x]
                if up < ti then c = mulc(c, 1.10) end
                if dn < ti then c = mulc(c, 0.90) end
                if slab and up == 0 then c = mulc(c, 1.13) end
                if slab and dn == 0 then c = mulc(c, 0.88) end
            end

            local u = x / W
            if not slab then
                local wob = math.sin(y / H * math.pi * 6) * 0.018
                for s = -1, 1, 2 do
                    local du = math.abs(u - (0.5 + s * 0.21 + wob * s))
                    if du < 0.028 then
                        local k = 1 - du / 0.028
                        c = mulc(c, 1 - 0.11 * k)
                    elseif du < 0.044 then
                        c = mulc(c, 1.03)
                    end
                end
                local dc = math.abs(u - 0.5)
                if dc < 0.13 then
                    c = mulc(c, 1 + 0.07 * (1 - dc / 0.13)
                        * (0.6 + 0.4 * vnoise(x, y, 4, 10, seed + 31)))
                end
            end

            if bid == "frost" then
                local r = vnoise(x, y, 12, 64, seed + 41)
                local dash = vnoise(x, y, 20, 30, seed + 47)
                if math.abs(r - 0.5) < 0.020 and dash > 0.5 then
                    c = mixc(c, { 0.72, 0.80, 0.95 }, 0.30)
                end
            elseif bid == "marsh" then
                local sh = math.sin((y / H) * math.pi * 14 + fbm(x, y, seed + 5) * 3)
                if sh > 0.75 then c = mulc(c, 1.10) end
                c = mixc(c, { 0.16, 0.18, 0.10 }, 0.10)
            elseif bid == "dusk" then
                if latHash(x, y, seed + 51) > 0.965 then
                    c = mixc(c, { 0.66, 0.36, 0.20 }, 0.8)
                end
            end

            local g1 = latHash(x, y, seed + 61)
            if g1 > 0.980 then c = mulc(c, 0.70)
            elseif g1 < 0.012 then c = mulc(c, 1.24) end

            d:setPixel(x, y, math.min(1, c[1]), math.min(1, c[2]),
                math.min(1, c[3]), 1)
        end
    end

    local img = love.graphics.newImage(d)
    img:setFilter("nearest", "nearest")
    img:setWrap("repeat", "repeat")
    return img
end

local RoadVariants = require("engine.RoadVariants")

function RoadSurface.style(bid)
    if RoadVariants.id == "atual" then return nil end
    return require("engine.RoadSurfaceVariants").style(bid, RoadVariants.id)
end

function RoadSurface.get(bid, pal, yieldEvery)
    local vid = RoadVariants.id
    local key = vid == "atual" and bid or (bid .. "|" .. vid)
    local hit = cache[key]
    if hit ~= nil then return hit or nil end
    local ok, img
    if vid == "atual" then
        ok, img = pcall(bake, bid, pal or {}, yieldEvery)
    else
        ok, img = pcall(require("engine.RoadSurfaceVariants").bake, bid, vid, pal or {}, yieldEvery)
    end
    bid = key
    if not ok or not img then
        Debug.warn(("[RoadSurface] bake do bioma '%s' falhou: %s — usando o PNG")
            :format(tostring(bid), tostring(img)))
        cache[bid] = false
        return nil
    end
    if not cache[bid] then cache[bid] = img end
    return cache[bid]
end

function RoadSurface.has(bid) return cache[bid] ~= nil end

function RoadSurface.clear() cache = {} end

return RoadSurface
