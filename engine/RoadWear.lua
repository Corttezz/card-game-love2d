local LightEngine = require("engine.LightEngine")

local RoadWear = {}

local stamps = nil

local function put(d, x, y, v, a)
    local w, h = d:getWidth(), d:getHeight()
    if x >= 0 and x < w and y >= 0 and y < h then
        d:setPixel(x, y, v, v, v, a or 1)
    end
end

local function hash01(n)
    local v = math.sin(n * 12.9898) * 43758.5453
    return v - math.floor(v)
end

local function makeStamps()
    local S = {}

    do
        local w, h = 26, 10
        local d = love.image.newImageData(w, h)
        for y = 0, h - 1 do
            for x = 0, w - 1 do
                local nx = (x - w / 2) / (w / 2)
                local ny = (y - h / 2) / (h / 2)
                local r = nx * nx + ny * ny
                local n = hash01(x * 7 + y * 13)
                if r < 0.55 or (r < 1.0 and n > r) then
                    put(d, x, y, 0.5 + n * 0.12, 1)
                end
            end
        end
        S.patch = love.graphics.newImage(d)
    end

    do
        local d = love.image.newImageData(7, 5)
        local rows = { "0111100", "1222210", "1222221", "0122210", "0011100" }
        local V = { [0] = nil, [1] = 0.42, [2] = 0.66 }
        for y = 1, 5 do
            for x = 1, 7 do
                local c = tonumber(rows[y]:sub(x, x))
                if V[c] then put(d, x - 1, y - 1, y <= 2 and math.min(1, V[c] * 1.3) or V[c], 1) end
            end
        end
        S.stone = love.graphics.newImage(d)
    end

    do
        local d = love.image.newImageData(12, 5)
        local pts = { { 1, 2, 3, 2 }, { 6, 0, 2, 2 }, { 9, 2, 3, 3 } }
        for _, p in ipairs(pts) do
            for y = p[2], math.min(4, p[2] + p[4] - 1) do
                for x = p[1], math.min(11, p[1] + p[3] - 1) do
                    put(d, x, y, y == p[2] and 0.72 or 0.5, 1)
                end
            end
        end
        S.stones = love.graphics.newImage(d)
    end

    do
        local d = love.image.newImageData(10, 7)
        for y = 0, 6 do
            for x = 0, 9 do
                local edge = x == 0 or y == 0 or x == 9 or y == 6
                local chip = hash01(x * 31 + y * 17) > 0.92
                if not chip then
                    if edge then put(d, x, y, 0.30, 1)
                    else put(d, x, y, y <= 1 and 0.74 or 0.58, 1) end
                end
            end
        end
        S.cobble = love.graphics.newImage(d)
    end

    do
        local d = love.image.newImageData(20, 6)
        local y = 2
        for x = 0, 19 do
            put(d, x, y, 0.9, 1)
            if hash01(x * 7) > 0.62 then y = math.max(0, math.min(5, y + (hash01(x * 3) > 0.5 and 1 or -1))) end
            if hash01(x * 11) > 0.8 then put(d, x, y + 1, 0.6, 1) end
        end
        S.crack = love.graphics.newImage(d)
    end

    do
        local w, h = 20, 8
        local d = love.image.newImageData(w, h)
        for y = 0, h - 1 do
            for x = 0, w - 1 do
                local nx = (x - w / 2) / (w / 2)
                local ny = (y - h / 2) / (h / 2)
                local r = nx * nx + ny * ny
                if r < 1.0 then
                    if r > 0.62 then put(d, x, y, 0.22, 1)
                    else put(d, x, y, 0.85, 1) end
                end
            end
        end
        S.puddle = love.graphics.newImage(d)
    end

    do
        local d = love.image.newImageData(14, 8)
        for k = 1, 14 do
            local x = math.floor(hash01(k * 13) * 13)
            local y = math.floor(hash01(k * 29) * 7)
            put(d, x, y, 0.55 + hash01(k * 7) * 0.35, 1)
            if hash01(k * 5) > 0.6 then put(d, x + 1, y, 0.5, 1) end
        end
        S.leaves = love.graphics.newImage(d)
    end

    do
        local w, h = 24, 9
        local d = love.image.newImageData(w, h)
        for y = 0, h - 1 do
            for x = 0, w - 1 do
                local nx = (x - w / 2) / (w / 2)
                local ny = (y - h / 2) / (h / 2)
                local r = nx * nx + ny * ny
                local n = hash01(x * 3 + y * 19)
                if r < 0.5 or (r < 1.0 and n > r * 0.9) then
                    put(d, x, y, 0.88 + n * 0.12, 1)
                end
            end
        end
        S.snow = love.graphics.newImage(d)
    end

    do
        local d = love.image.newImageData(16, 6)
        for k = 0, 3 do
            local x = k * 4
            local y = (k % 2 == 0) and 1 or 3
            put(d, x, y, 0.35, 1); put(d, x + 1, y, 0.35, 1)
        end
        S.prints = love.graphics.newImage(d)
    end

    do
        local d = love.image.newImageData(10, 4)
        for k = 0, 2 do
            local x0 = k * 3
            put(d, x0, 2, 0.8, 1); put(d, x0 + 1, 1, 0.85, 1)
            put(d, x0 + 2, 1, 0.8, 1)
        end
        S.straw = love.graphics.newImage(d)
    end

    do
        local d = love.image.newImageData(22, 5)
        local y = 2
        for x = 0, 21 do
            put(d, x, y, 0.3, 1)
            put(d, x, y + 1, 0.22, 1)
            if hash01(x * 17) > 0.7 then y = math.max(0, math.min(3, y + (hash01(x * 9) > 0.5 and 1 or -1))) end
            if x == 11 then put(d, x, y - 1, 0.38, 1) end
        end
        S.root = love.graphics.newImage(d)
    end

    do
        local d = love.image.newImageData(8, 3)
        for x = 1, 6 do put(d, x, 1, 0.85, 1) end
        put(d, 0, 0, 0.8, 1); put(d, 0, 2, 0.8, 1)
        put(d, 7, 0, 0.8, 1); put(d, 7, 2, 0.8, 1)
        S.bone = love.graphics.newImage(d)
    end

    for _, img in pairs(S) do img:setFilter("nearest", "nearest") end
    return S
end

local function mul(c, k) return { c[1] * k, c[2] * k, c[3] * k } end

RoadWear.CATALOG = {
    fields = {
        { stamp = "patch",  cada = 3.2, alpha = 0.50, uMax = 0.75, scaleK = 1.1,
          tint = function(cx2) return mul(cx2.tint("roadA"), 0.72) end },
        { stamp = "stone",  cada = 4.5, alpha = 1.0, uMax = 0.8,
          tint = function(cx2) return mul(cx2.tint("roadEdge"), 1.25) end },
        { stamp = "straw",  cada = 5.0, alpha = 1.0, uMax = 0.7,
          tint = function(cx2) return { 0.82, 0.70, 0.38 } end },
        { stamp = "prints", cada = 6.5, alpha = 0.55, uMax = 0.45,
          tint = function(cx2) return mul(cx2.tint("roadA"), 0.6) end },
        { stamp = "stones", cada = 7.0, alpha = 0.95, uMax = 0.85,
          tint = function(cx2) return mul(cx2.tint("roadEdge"), 1.1) end },
    },
    highlands = {
        { stamp = "leaves", cada = 4.5, alpha = 0.7, uMax = 0.7,
          tint = function(cx2) return mul(cx2.tint("grassA"), 1.15) end },
        { stamp = "stone",  cada = 5.0, alpha = 1.0, uMax = 0.85,
          tint = function(cx2) return mul(cx2.tint("roadEdge"), 1.3) end },
        { stamp = "patch",  cada = 5.5, alpha = 0.40, uMax = 0.7,
          tint = function(cx2) return mul(cx2.tint("roadEdge"), 1.1) end },
    },
    abyss = {
        { stamp = "crack",  cada = 3.0, alpha = 0.95, uMax = 0.7, scaleK = 1.2,
          ember = true,
          tint = function(cx2) return { 1.0, 0.42, 0.12 } end },
        { stamp = "patch",  cada = 3.5, alpha = 0.6, uMax = 0.8, scaleK = 1.2,
          tint = function(cx2) return mul(cx2.tint("roadA"), 0.45) end },
        { stamp = "bone",   cada = 6.0, alpha = 0.9, uMax = 0.75,
          tint = function(cx2) return { 0.78, 0.72, 0.60 } end },
        { stamp = "stone",  cada = 5.5, alpha = 1.0, uMax = 0.85,
          tint = function(cx2) return mul(cx2.tint("roadEdge"), 1.2) end },
    },
    frost = {
        { stamp = "snow",   cada = 2.6, alpha = 0.85, uMax = 0.9, scaleK = 1.25,
          tint = function(cx2) return { 0.88, 0.92, 1.0 } end },
        { stamp = "patch",  cada = 4.0, alpha = 0.5, uMax = 0.7,
          tint = function(cx2) return { 0.62, 0.75, 0.95 } end },
        { stamp = "prints", cada = 4.5, alpha = 0.7, uMax = 0.5,
          tint = function(cx2) return mul(cx2.tint("roadA"), 0.55) end },
        { stamp = "stone",  cada = 6.5, alpha = 1.0, uMax = 0.8,
          tint = function(cx2) return mul(cx2.tint("roadEdge"), 1.15) end },
    },
    marsh = {
        { stamp = "puddle", cada = 2.8, alpha = 0.9, uMax = 0.7, scaleK = 1.25,
          tint = function(cx2) return mul(cx2.tint("fog"), 1.35) end },
        { stamp = "patch",  cada = 3.2, alpha = 0.6, uMax = 0.85, scaleK = 1.15,
          tint = function(cx2) return mul(cx2.tint("roadA"), 0.55) end },
        { stamp = "root",   cada = 5.0, alpha = 0.9, uMax = 0.9, scaleK = 1.2,
          tint = function(cx2) return mul(cx2.tint("roadEdge"), 0.9) end },
        { stamp = "leaves", cada = 6.0, alpha = 0.7, uMax = 0.7,
          tint = function(cx2) return mul(cx2.tint("grassA"), 0.9) end },
    },
    dusk = {
        { stamp = "leaves", cada = 2.4, alpha = 0.9, uMax = 0.85, scaleK = 1.2,
          tint = function(cx2) return { 0.78, 0.38, 0.25 } end },
        { stamp = "leaves", cada = 3.6, alpha = 0.8, uMax = 0.75,
          tint = function(cx2) return { 0.72, 0.52, 0.22 } end },
        { stamp = "root",   cada = 5.5, alpha = 0.85, uMax = 0.85, scaleK = 1.1,
          tint = function(cx2) return mul(cx2.tint("roadEdge"), 0.85) end },
        { stamp = "stone",  cada = 6.0, alpha = 1.0, uMax = 0.8,
          tint = function(cx2) return mul(cx2.tint("roadEdge"), 1.2) end },
    },
}

RoadWear.DENSITY = 1.6

function RoadWear.draw(ctx)
    local vid = require("engine.RoadVariants").id
    if vid ~= "atual" then
        return require("engine.RoadDecals").draw(ctx, vid)
    end
    stamps = stamps or makeStamps()
    local cat = RoadWear.CATALOG[ctx.bid]
    if not cat then return end
    local g = ctx.geom
    local camZ = ctx.camZ

    for fi, f in ipairs(cat) do
        local img = stamps[f.stamp]
        if img then
            local iw, ih = img:getWidth(), img:getHeight()
            local tintC = f.tint(ctx)
            local salt = fi * 7919
            local cada = f.cada / RoadWear.DENSITY
            local s0 = math.floor(camZ / cada)
            local s1 = math.floor((camZ + ctx.relCrest) / cada)
            for slot = s0, s1 do
                local h1 = hash01(slot * 12.9898 + salt)
                local wz = (slot + 0.15 + h1 * 0.7) * cada
                local rel = wz - camZ
                local skip = ctx.forkActive and rel > (ctx.forkRel - 1)
                local t = (not skip) and g.tOf(rel) or nil
                if t and t >= 0.10 and t <= 1 then
                    local h2 = hash01(slot * 78.233 + salt)
                    local h3 = hash01(slot * 37.719 + salt)
                    local cxr = ctx.roadCenter(wz, t)
                    local half = ctx.roadHalf(t)
                    local u = (h2 * 2 - 1) * (f.uMax or 0.7)
                    local px = cxr + u * half
                    local py = g.latY(px - g.cx, t)
                    local sc = (0.70 + 2.6 * t) * (f.scaleK or 1)
                    local sy2 = sc * 0.55
                    local flip = h3 > 0.5 and -1 or 1
                    local aDist = math.min(1, (t - 0.06) * 4)
                    love.graphics.setColor(tintC[1], tintC[2], tintC[3],
                        (f.alpha or 0.8) * aDist)
                    love.graphics.draw(img, math.floor(px), math.floor(py),
                        0, sc * flip, sy2, iw / 2, ih / 2)
                    if f.ember and LightEngine.submitMicro then
                        LightEngine.submitMicro(px, py, 9 * sc * 0.4,
                            { 1.0, 0.45, 0.15 },
                            0.30 + 0.12 * math.sin(ctx.time * 1.7 + slot),
                            rel)
                    end
                end
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return RoadWear
