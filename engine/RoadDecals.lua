local SceneGrade = require("engine.SceneGrade")
local RoadTiles = require("engine.RoadTiles")

local RoadDecals = {}

local atlas, Q, QW, QH = nil, nil, nil, nil
local floor, sin, abs, min, max = math.floor, math.sin, math.abs, math.min, math.max

local function hash01(n)
    local v = sin(n * 12.9898) * 43758.5453
    return v - floor(v)
end

local STAMPS = {
    leafA = { ".22..", "13331", ".113." },
    leafB = { ".23.", "1332", ".11." },
    leafC = { "..2.", ".331", "13..", },
}
local SHADE = { ["1"] = 0.55, ["2"] = 1.0, ["3"] = 0.8 }

local function build()
    local W, H = 32, 4
    local d = love.image.newImageData(W, H)
    Q, QW, QH = {}, {}, {}
    local cx = 0
    for _, name in ipairs({ "leafA", "leafB", "leafC" }) do
        local rows = STAMPS[name]
        local w, h = #rows[1], #rows
        for y = 1, h do
            for x = 1, w do
                local c = rows[y]:sub(x, x)
                local v = SHADE[c]
                if v then d:setPixel(cx + x - 1, y - 1, v, v, v, 1) end
            end
        end
        Q[name] = { cx, w, h }
        cx = cx + w + 1
    end
    atlas = love.graphics.newImage(d)
    atlas:setFilter("nearest", "nearest")
    for k, r in pairs(Q) do
        Q[k] = love.graphics.newQuad(r[1], 0, r[2], r[3], W, H)
        QW[k], QH[k] = r[2], r[3]
    end
end

RoadDecals.CAT = {
    dusk = { { cada = 1.7, move = 0.07 } },
}

RoadDecals.LEAVES = {
    { 0.82, 0.4, 0.12 }, { 0.68, 0.2, 0.1 }, { 0.8, 0.62, 0.2 }, { 0.46, 0.31, 0.16 },
}

local GR, NAMES = {}, { "leafA", "leafB", "leafC" }

function RoadDecals.has(bid)
    return RoadDecals.CAT[bid] ~= nil
end

function RoadDecals.draw(ctx)
    local list = RoadDecals.CAT[ctx.bid]
    if not list then return end
    if not atlas then build() end
    local g = ctx.geom
    local camZ = ctx.camZ
    local time = ctx.time or 0
    local gr = SceneGrade.color("road", 1, GR)
    local lg = love.graphics
    for fi, f in ipairs(list) do
        local salt = fi * 7919
        local s0 = floor(camZ / f.cada)
        local s1 = floor((camZ + ctx.relCrest) / f.cada)
        for slot = s0, s1 do
            local h1 = hash01(slot * 12.9898 + salt)
            local wz = (slot + 0.15 + h1 * 0.7) * f.cada
            local rel = wz - camZ
            local fz = 0
            if (ctx.forkK or 0) > 0 then
                fz = ctx.forkK * min(1, max(0, (rel - (ctx.forkRel - 1.6)) / 1.2))
            end
            local t = fz < 0.99 and g.tOf(rel) or nil
            if t and t >= 0.3 and t <= 1 then
                local h2 = hash01(slot * 78.233 + salt)
                local h3 = hash01(slot * 37.719 + salt)
                local cxr = ctx.roadCenter(wz, t)
                local half = ctx.roadHalf(t) / 0.82 * (ctx.roadVis or 0.88)
                local sc = max(1, half / RoadTiles.HALF)
                local aDist = min(1, (t - 0.3) * 4) * (1 - fz) * min(1, (1 - t) * 14)
                local sp = f.move * (0.5 + h3)
                local cyc = (h2 * 2.6 + time * sp) % 2.6
                local ux = cyc - 1.3
                local edgeA = 1 - max(0, (abs(ux) - 0.85) / 0.4)
                local rest = sin(time * 0.9 + h1 * 11)
                if edgeA > 0 then
                    local px = cxr + ux * half
                    local hs = sin(time * 2.4 + h1 * 9)
                    local hop = rest > 0.2 and hs * hs * sc * 1.5 * min(1, (rest - 0.2) * 4) or 0
                    local py = g.latY(px - g.cx, t) - hop
                    local lc = RoadDecals.LEAVES[1 + floor(h3 * 4) % 4]
                    local q = NAMES[1 + floor(h1 * 3) % 3]
                    local fl = (sin(time * 1.7 + h1 * 7) > 0) and 1 or -1
                    lg.setColor(0.05, 0.03, 0.02, 0.35 * aDist * edgeA * (hop > 0 and 1 or 0.6))
                    lg.draw(atlas, Q[q], floor(px + sc), floor(g.latY(px - g.cx, t) + sc * 0.5), 0, sc * fl, sc,
                        QW[q] / 2, QH[q] / 2)
                    lg.setColor(lc[1] * gr[1], lc[2] * gr[2], lc[3] * gr[3], aDist * edgeA)
                    lg.draw(atlas, Q[q], floor(px), floor(py), 0, sc * fl, sc, QW[q] / 2, QH[q] / 2)
                    if ctx.seq then ctx.seq("leaf", fi, slot, px, py, sc * 4, sc * 3, aDist * edgeA) end
                end
            end
        end
    end
    lg.setColor(1, 1, 1, 1)
end

return RoadDecals
