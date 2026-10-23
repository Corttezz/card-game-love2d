local LightEngine = require("engine.LightEngine")
local SceneGrade = require("engine.SceneGrade")
local SV = require("engine.RoadSurfaceVariants")

local RoadDecals = {}

local atlas, Q, QW, QH = nil, nil, nil, nil
local floor, sin, abs, min, max = math.floor, math.sin, math.abs, math.min, math.max

local function hash01(n)
    local v = sin(n * 12.9898) * 43758.5453
    return v - floor(v)
end

local function build()
    local W, H = 128, 16
    local d = love.image.newImageData(W, H)
    local quads = {}
    local cx = 0
    local function stamp(name, w, h, fn)
        for y = 0, h - 1 do
            for x = 0, w - 1 do
                local v, a = fn(x, y, w, h)
                if v then d:setPixel(cx + x, y, v, v, v, a or 1) end
            end
        end
        quads[name] = { cx, 0, w, h }
        cx = cx + w + 1
    end
    stamp("rim", 13, 6, function(x, y, w, h)
        local nx, ny = (x + 0.5 - w / 2) / (w / 2), (y + 0.5 - h / 2) / (h / 2)
        local r = nx * nx + ny * ny
        if r < 1 then return 1, 1 end
    end)
    stamp("fill", 11, 4, function(x, y, w, h)
        local nx, ny = (x + 0.5 - w / 2) / (w / 2), (y + 0.5 - h / 2) / (h / 2)
        local r = nx * nx + ny * ny
        if r < 1 then
            if y == 0 then return 1, 1 end
            if y == 1 and x > 2 and x < 7 then return 0.95, 1 end
            return 0.62 + (h - y) * 0.06, 1
        end
    end)
    stamp("ring", 7, 3, function(x, y, w, h)
        local nx, ny = (x + 0.5 - w / 2) / (w / 2), (y + 0.5 - h / 2) / (h / 2)
        local r = nx * nx + ny * ny
        if r < 1.1 and r > 0.45 then return 1, 1 end
    end)
    stamp("prints", 4, 12, function(x, y)
        local left = (y % 6) < 3
        local px = left and 0 or 2
        if (x == px or x == px + 1) and (y % 3) ~= 2 then return 1, 1 end
    end)
    stamp("leaf", 3, 2, function(x, y)
        if not (x == 2 and y == 1) then return (x == 0 and 0.75 or 1), 1 end
    end)
    stamp("leaf2", 2, 2, function(x, y)
        if not (x == 1 and y == 0) then return (y == 0 and 1 or 0.8), 1 end
    end)
    stamp("wisp", 16, 2, function(x, y, w)
        local k = 1 - abs(x + 0.5 - w / 2) / (w / 2)
        if (y == 0 and x > 3 and x < 14) or (y == 1 and x < 11) then return 1, k end
    end)
    stamp("spark", 3, 3, function(x, y)
        if x == 1 or y == 1 then return 1, (x == 1 and y == 1) and 1 or 0.6 end
    end)
    stamp("reed", 5, 7, function(x, y)
        local cols = { [0] = 3, [1] = 1, [2] = 0, [3] = 2, [4] = 4 }
        if y >= cols[x] then return (y < 3) and 1 or 0.75, 1 end
    end)
    atlas = love.graphics.newImage(d)
    atlas:setFilter("nearest", "nearest")
    Q, QW, QH = {}, {}, {}
    for k, r in pairs(quads) do
        Q[k] = love.graphics.newQuad(r[1], r[2], r[3], r[4], W, H)
        QW[k], QH[k] = r[3], r[4]
    end
end

local function mulc(c, k, out)
    out[1], out[2], out[3] = c[1] * k, c[2] * k, c[3] * k
    return out
end

local CAT = {
    fields = { C = { "puddle_rut", "prints", "leaf_blow", "straw" } },
    highlands = { C = { "puddle", "leaf_blow" } },
    abyss = { B = { "embers" }, C = { "embers", "ash_blow" } },
    frost = { C = { "snow_blow", "sparkle", "prints" } },
    marsh = { C = { "puddle_big", "reeds", "leaf_float" } },
    dusk = { C = { "puddle", "leaf_blow", "leaf_blow2" } },
}

local LEAVES = {
    fields = { { 0.62, 0.5, 0.22 }, { 0.5, 0.42, 0.16 }, { 0.7, 0.36, 0.14 } },
    highlands = { { 0.56, 0.34, 0.16 }, { 0.72, 0.5, 0.22 }, { 0.4, 0.28, 0.14 } },
    marsh = { { 0.36, 0.38, 0.16 }, { 0.5, 0.5, 0.22 }, { 0.3, 0.3, 0.12 } },
    dusk = { { 0.78, 0.36, 0.16 }, { 0.86, 0.56, 0.2 }, { 0.62, 0.22, 0.12 } },
}
local EMBER = { 1.0, 0.45, 0.15 }
local REFLECT = {
    fields = { 0.62, 0.6, 0.74 }, highlands = { 0.46, 0.38, 0.66 }, abyss = { 0.66, 0.32, 0.2 },
    frost = { 0.72, 0.8, 0.9 }, marsh = { 0.46, 0.5, 0.36 }, dusk = { 0.88, 0.62, 0.4 },
}

local FAM = {
    puddle_rut = { cada = 2.6, kind = "puddle", rut = true, size = 1.0 },
    puddle = { cada = 3.4, kind = "puddle", uMax = 0.6, size = 0.9 },
    puddle_big = { cada = 2.2, kind = "puddle", uMax = 0.65, size = 1.5 },
    prints = { cada = 1.6, kind = "prints", uMax = 0.18 },
    leaf_blow = { cada = 0.9, kind = "leaf", move = 0.10 },
    leaf_blow2 = { cada = 1.3, kind = "leaf", move = 0.06, alt = true },
    leaf_float = { cada = 2.0, kind = "leaf", move = 0.0, alt = true },
    straw = { cada = 1.4, kind = "leaf", move = 0.0, straw = true },
    embers = { cada = 1.1, kind = "ember" },
    ash_blow = { cada = 0.7, kind = "wisp", move = 0.22, ash = true },
    snow_blow = { cada = 0.55, kind = "wisp", move = 0.32 },
    sparkle = { cada = 0.35, kind = "spark" },
    reeds = { cada = 1.2, kind = "reed" },
}

local C1, C2, GR = {}, {}, {}

function RoadDecals.has(bid, vid)
    local c = CAT[bid]
    return c and c[vid] ~= nil
end

function RoadDecals.draw(ctx, vid)
    local c = CAT[ctx.bid]
    local list = c and c[vid]
    if not list then return end
    if not atlas then build() end
    local g = ctx.geom
    local camZ = ctx.camZ
    local time = ctx.time or 0
    local gr = SceneGrade.color("road", 1, GR)
    local roadEdge, roadA = ctx.tint("roadEdge"), ctx.tint("roadA")
    local sky, skyT = ctx.tint("skyHorizon"), ctx.tint("skyTop")
    local VD = 5.2 * SV.VK
    local lg = love.graphics
    for fi, name in ipairs(list) do
        local f = FAM[name]
        local salt = fi * 7919 + #name * 131
        local s0 = floor(camZ / f.cada)
        local s1 = floor((camZ + ctx.relCrest) / f.cada)
        for slot = s0, s1 do
            local h1 = hash01(slot * 12.9898 + salt)
            local wz = (slot + 0.15 + h1 * 0.7) * f.cada
            local rel = wz - camZ
            local skip = ctx.forkActive and rel > (ctx.forkRel - 1)
            local t = (not skip) and g.tOf(rel) or nil
            if t and t >= 0.12 and t <= 1 then
                local h2 = hash01(slot * 78.233 + salt)
                local h3 = hash01(slot * 37.719 + salt)
                local cxr = ctx.roadCenter(wz, t)
                local half = ctx.roadHalf(t) / 0.82 * (ctx.roadVis or 0.88)
                local sc = half / SV.HALF
                local sy = sc * 0.78
                local aDist = min(1, (t - 0.12) * 5)
                local u
                if f.rut then
                    local yy = (wz * VD) % SV.TH
                    u = SV.rutU(yy, h2 > 0.5 and 1 or -1)
                else
                    u = (h2 * 2 - 1) * (f.uMax or 0.8)
                end
                local k = f.kind
                if k == "puddle" then
                    if h3 > 0.35 then
                        local px = cxr + u * half
                        local py = g.latY(px - g.cx, t)
                        local sz = f.size * (0.8 + h3 * 0.6)
                        local rim = mulc(roadEdge, 0.8, C1)
                        lg.setColor(rim[1] * gr[1], rim[2] * gr[2], rim[3] * gr[3], 0.9 * aDist)
                        lg.draw(atlas, Q.rim, floor(px), floor(py), 0, sc * sz, sy * sz, QW.rim / 2, QH.rim / 2)
                        local gl = (gr[1] + gr[2] + gr[3]) / 3
                        local wk = 0.55 + gl * 0.45
                        local rf = REFLECT[ctx.bid] or sky
                        lg.setColor(rf[1] * wk, rf[2] * wk, rf[3] * wk, 0.95 * aDist)
                        lg.draw(atlas, Q.fill, floor(px), floor(py), 0, sc * sz, sy * sz, QW.fill / 2, QH.fill / 2)
                        local ph = (time * 0.42 + h1 * 3) % 1
                        local rs = 0.4 + ph * 0.9
                        local rf2 = REFLECT[ctx.bid] or sky
                        lg.setColor(min(1, rf2[1] * 1.35 * wk), min(1, rf2[2] * 1.35 * wk), min(1, rf2[3] * 1.35 * wk),
                            (1 - ph) * 0.6 * aDist)
                        lg.draw(atlas, Q.ring, floor(px + (h2 - 0.5) * 3 * sc), floor(py), 0, sc * sz * rs,
                            sy * sz * rs, QW.ring / 2, QH.ring / 2)
                    end
                elseif k == "prints" then
                    if h3 > 0.25 then
                        local px = cxr + u * half
                        local py = g.latY(px - g.cx, t)
                        local col = mulc(roadEdge, 0.9, C1)
                        lg.setColor(col[1] * gr[1], col[2] * gr[2], col[3] * gr[3], 0.55 * aDist)
                        lg.draw(atlas, Q.prints, floor(px), floor(py), 0, sc, sy * 0.7, QW.prints / 2, QH.prints / 2)
                    end
                elseif k == "leaf" then
                    local ux = u
                    if f.move > 0 and h3 > 0.4 then
                        local sp = f.move * (0.6 + h3 * 0.8)
                        ux = ((h2 * 2.4 + time * sp) % 2.4) - 1.2
                    end
                    local edgeA = 1 - max(0, (abs(ux) - 0.85) / 0.35)
                    if edgeA > 0 then
                        local px = cxr + ux * half
                        local py = g.latY(px - g.cx, t) - (f.move > 0 and abs(sin(time * 2.2 + h1 * 9)) * 2 * sc * 0.4 or 0)
                        local P = LEAVES[ctx.bid] or LEAVES.dusk
                        local col = f.straw and C2 or C1
                        if f.straw then col[1], col[2], col[3] = 0.78, 0.66, 0.34
                        else
                            local lc = P[1 + floor(h3 * #P) % #P]
                            col[1], col[2], col[3] = lc[1], lc[2], lc[3]
                        end
                        local q = (f.alt or h1 > 0.5) and "leaf2" or "leaf"
                        local fl = (sin(time * 3 + h1 * 7) > 0) and 1 or -1
                        lg.setColor(col[1] * gr[1], col[2] * gr[2], col[3] * gr[3], 0.95 * aDist * edgeA)
                        lg.draw(atlas, Q[q], floor(px), floor(py), 0, sc * (f.move > 0 and fl or 1), sy,
                            QW[q] / 2, QH[q] / 2)
                    end
                elseif k == "wisp" then
                    local sp = f.move * (0.7 + h3 * 0.6)
                    local ux = ((h2 * 3 + time * sp) % 3) - 1.5
                    local life = max(0, sin(((time * sp * 0.7 + h1) % 1) * math.pi))
                    local edgeA = 1 - max(0, (abs(ux) - 0.9) / 0.5)
                    if edgeA > 0 and life > 0.05 then
                        local px = cxr + ux * half
                        local py = g.latY(px - g.cx, t)
                        local col = f.ash and C1 or C2
                        if f.ash then col[1], col[2], col[3] = 0.52, 0.5, 0.5
                        else col[1], col[2], col[3] = 0.95, 0.97, 1.0 end
                        lg.setColor(col[1] * gr[1], col[2] * gr[2], col[3] * gr[3], 0.5 * life * edgeA * aDist)
                        lg.draw(atlas, Q.wisp, floor(px), floor(py), 0, sc * 1.4, sy, QW.wisp / 2, QH.wisp / 2)
                    end
                elseif k == "spark" then
                    local tw = sin(time * (1.6 + h3 * 2.2) + h1 * 40)
                    if tw > 0.82 then
                        local px = cxr + u * half * 1.1
                        local py = g.latY(px - g.cx, t)
                        lg.setColor(1, 1, 1, (tw - 0.82) / 0.18 * 0.9 * aDist)
                        lg.draw(atlas, Q.spark, floor(px), floor(py), 0, max(1, floor(sc * 0.6 + 0.5)),
                            max(1, floor(sc * 0.6 + 0.5)), 1.5, 1.5)
                    end
                elseif k == "reed" then
                    local side = h2 > 0.5 and 1 or -1
                    local ux = side * (0.78 + h3 * 0.3)
                    local px = cxr + ux * half
                    local py = g.latY(px - g.cx, t)
                    local gA = ctx.tint("grassA")
                    local sw = sin(time * 1.3 + h1 * 6) * 0.06
                    lg.setColor(gA[1] * 1.25 * gr[1], gA[2] * 1.2 * gr[2], gA[3] * 0.9 * gr[3], aDist)
                    lg.draw(atlas, Q.reed, floor(px), floor(py), sw, sc, sc, QW.reed / 2, QH.reed)
                elseif k == "ember" then
                    if h3 > 0.3 and LightEngine.submitMicro then
                        local px = cxr + u * half * 0.8
                        local py = g.latY(px - g.cx, t)
                        local pulse = 0.22 + 0.14 * sin(time * (1.2 + h3) + slot)
                        LightEngine.submitMicro(px, py, 10 * sc * 0.5, EMBER, pulse, rel)
                    end
                end
            end
        end
    end
    lg.setColor(1, 1, 1, 1)
end

return RoadDecals
