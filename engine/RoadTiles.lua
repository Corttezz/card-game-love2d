local V = {}

local TW, TH = 192, 640
local CU, HALF = 96, 56
V.TW, V.TH, V.CU, V.HALF = TW, TH, CU, HALF
V.VK = 1.35

local floor, abs, min, max, sin, cos, sqrt = math.floor, math.abs, math.min, math.max, math.sin, math.cos,
    math.sqrt
local TAU = math.pi * 2

local function h2(i, j, s)
    local v = sin(i * 127.1 + j * 311.7 + s * 74.7) * 43758.5453
    return v - floor(v)
end

local function vnoise(x, y, nx, ny, s)
    local gx, gy = x / TW * nx, y / TH * ny
    local i, j = floor(gx), floor(gy)
    local fx, fy = gx - i, gy - j
    local ux = fx * fx * (3 - 2 * fx)
    local uy = fy * fy * (3 - 2 * fy)
    local i1, j1 = (i + 1) % nx, (j + 1) % ny
    i, j = i % nx, j % ny
    local a, b = h2(i, j, s), h2(i1, j, s)
    local c, d = h2(i, j1, s), h2(i1, j1, s)
    return a + (b - a) * ux + (c - a) * uy + (a - b - c + d) * ux * uy
end

local function fbm(x, y, s, nx, ny)
    nx, ny = nx or 6, ny or 20
    return vnoise(x, y, nx, ny, s) * 0.55 + vnoise(x, y, nx * 2, ny * 2, s + 7) * 0.30
        + vnoise(x, y, nx * 4, ny * 4, s + 13) * 0.15
end

local function voronoi(x, y, nx, ny, s, jit)
    jit = jit or 0.8
    local gx, gy = x / TW * nx, y / TH * ny
    local ci, cj = floor(gx), floor(gy)
    local d1, d2, id = 1e9, 1e9, 0
    for dj = -1, 1 do
        for di = -1, 1 do
            local i, j = ci + di, cj + dj
            local wi, wj = i % nx, j % ny
            local px = i + 0.5 + (h2(wi, wj, s) - 0.5) * jit
            local py = j + 0.5 + (h2(wi, wj, s + 3) - 0.5) * jit
            local dx, dy = px - gx, py - gy
            local d = sqrt(dx * dx + dy * dy)
            if d < d1 then
                d2 = d1; d1 = d; id = wi * 131 + wj
            elseif d < d2 then d2 = d end
        end
    end
    return d2 - d1, id
end

local BAYER = { 0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5 }
local function bayer(x, y) return (BAYER[(y % 4) * 4 + (x % 4) + 1] + 0.5) / 16 end

local function sstep(e0, e1, x)
    local t = min(1, max(0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)
end

local function mul(c, k) return { min(1, c[1] * k), min(1, c[2] * k), min(1, c[3] * k) } end
local function mix(a, b, k)
    return { a[1] + (b[1] - a[1]) * k, a[2] + (b[2] - a[2]) * k, a[3] + (b[3] - a[3]) * k }
end
local function ramp(dark, base, light, n)
    local r = {}
    n = n or 5
    for i = 1, n do
        local k = (i - 1) / (n - 1)
        if k < 0.5 then r[i] = mix(dark, base, k * 2) else r[i] = mix(base, light, (k - 0.5) * 2) end
    end
    return r
end

local DIRT, STONE, GAP, GRASS, MOSS, WOOD, WATER, SNOW, EMBER, ASH, LEAF, ICE, MUD, STRAW, LEAF2, LEAF3, LEAF4,
    RUST, SOOT, LEAF5, LEAF6, PEAT, HEAT, SCORIA = 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19,
    20, 21, 22, 23, 24
V.MAT = { DIRT = DIRT, STONE = STONE, LEAF = LEAF, LEAF2 = LEAF2, LEAF3 = LEAF3, LEAF4 = LEAF4, EMBER = EMBER,
    WOOD = WOOD, WATER = WATER, SNOW = SNOW, MUD = MUD, PEAT = PEAT, ASH = ASH, SOOT = SOOT, HEAT = HEAT,
    SCORIA = SCORIA }

local function palettes(bid, p)
    local roadA = p.roadA or { 0.45, 0.33, 0.2 }
    local roadB = p.roadB or mul(roadA, 0.86)
    local edge = p.roadEdge or mul(roadA, 0.45)
    local rock = p.rock or { 0.38, 0.35, 0.3 }
    local rockD = p.rockDark or mul(rock, 0.62)
    local gA = p.grassA or { 0.2, 0.3, 0.15 }
    local gB = p.grassB or mul(gA, 0.8)
    local trunk = p.trunk or { 0.3, 0.2, 0.12 }
    local sky = p.skyHorizon or { 0.5, 0.5, 0.55 }
    local skyT = p.skyTop or mul(sky, 0.4)
    local P = {}
    P[DIRT] = ramp(mul(edge, 0.9), roadB, mul(roadA, 1.22), 7)
    P[MUD] = ramp(mul(edge, 0.85), mix(edge, roadB, 0.78), mix(mul(roadA, 1.5), { 0.56, 0.52, 0.38 }, 0.25), 7)
    P[PEAT] = ramp(mul(edge, 0.6), mix(edge, trunk, 0.55), mix(mix(roadB, trunk, 0.5), gB, 0.25), 5)
    P[STONE] = ramp(mix(mul(rockD, 0.55), edge, 0.4), mix(rock, roadA, 0.25), mix(mul(rock, 1.55), mul(roadA, 1.45), 0.2), 7)
    P[GAP] = { mul(edge, 0.5), mul(edge, 0.75), edge }
    P[GRASS] = ramp(mul(gB, 0.65), gA, mix(mul(gA, 1.45), { 0.7, 0.66, 0.36 }, 0.15), 5)
    P[MOSS] = ramp(mul(gB, 0.6), mix(gA, { 0.36, 0.42, 0.16 }, 0.45), mix(mul(gA, 1.3), { 0.56, 0.6, 0.24 }, 0.4), 5)
    P[WOOD] = ramp(mul(trunk, 0.5), mix(mul(trunk, 1.6), { 0.4, 0.35, 0.26 }, 0.4),
        mix(mul(trunk, 2.4), { 0.66, 0.6, 0.48 }, 0.5), 7)
    P[WATER] = ramp(mix(skyT, edge, 0.5), mix(sky, skyT, 0.35), mix(sky, { 0.85, 0.88, 0.8 }, 0.35), 5)
    P[SNOW] = ramp(mix(gB, { 0.3, 0.36, 0.5 }, 0.55), mix(mul(gB, 0.93), { 0.5, 0.56, 0.7 }, 0.2), mix(gA, { 0.86, 0.9, 1.0 }, 0.5), 7)
    P[ICE] = ramp(mix(sky, { 0.3, 0.38, 0.5 }, 0.5), mix(sky, { 0.75, 0.85, 0.95 }, 0.5), { 0.9, 0.96, 1.0 }, 4)
    P[EMBER] = { { 0.22, 0.05, 0.03 }, { 0.46, 0.1, 0.04 }, { 0.78, 0.26, 0.06 }, { 1.0, 0.5, 0.14 },
        { 1.0, 0.76, 0.34 } }
    P[ASH] = ramp(mul(edge, 0.75), mix(roadB, rock, 0.45), mix(mul(roadA, 1.85), { 0.7, 0.58, 0.5 }, 0.35), 9)
    P[SOOT] = ramp(mul(edge, 0.45), mix(rockD, roadB, 0.5), mix(mul(rock, 2.0), { 0.6, 0.5, 0.46 }, 0.35), 7)
    P[SCORIA] = ramp({ 0.1, 0.04, 0.04 }, { 0.36, 0.16, 0.1 }, { 0.7, 0.4, 0.26 }, 7)
    P[HEAT] = ramp(mix(roadB, { 0.32, 0.12, 0.06 }, 0.45), { 0.56, 0.22, 0.08 }, { 0.9, 0.46, 0.16 }, 5)
    P[RUST] = { { 0.24, 0.12, 0.07 }, { 0.42, 0.22, 0.1 }, { 0.55, 0.32, 0.14 } }
    P[STRAW] = { { 0.42, 0.33, 0.14 }, { 0.62, 0.52, 0.26 }, { 0.8, 0.7, 0.4 } }
    P[LEAF] = { { 0.36, 0.13, 0.06 }, { 0.6, 0.24, 0.08 }, { 0.82, 0.4, 0.12 }, { 0.95, 0.58, 0.2 } }
    P[LEAF2] = { { 0.3, 0.07, 0.06 }, { 0.5, 0.12, 0.08 }, { 0.68, 0.2, 0.1 }, { 0.82, 0.32, 0.14 } }
    P[LEAF3] = { { 0.4, 0.26, 0.08 }, { 0.62, 0.44, 0.12 }, { 0.8, 0.62, 0.2 }, { 0.92, 0.78, 0.34 } }
    P[LEAF4] = { { 0.2, 0.12, 0.07 }, { 0.33, 0.21, 0.11 }, { 0.46, 0.31, 0.16 }, { 0.58, 0.42, 0.22 } }
    P[LEAF5] = { { 0.42, 0.3, 0.06 }, { 0.68, 0.5, 0.1 }, { 0.88, 0.7, 0.18 }, { 0.98, 0.86, 0.36 } }
    P[LEAF6] = { { 0.22, 0.06, 0.07 }, { 0.38, 0.1, 0.1 }, { 0.52, 0.16, 0.12 }, { 0.64, 0.26, 0.16 } }
    return P
end

function V.rutU(y, sd)
    local k = y / TH
    return sd * (0.40 + 0.045 * sin(k * TAU * 3 + (sd > 0 and 1.3 or 4.1)) + 0.02 * sin(k * TAU * 7 + sd))
end

local function rutK(u, y, w)
    w = w or 0.085
    local best, side, du = 0, 0, 1
    for sd = -1, 1, 2 do
        local d = (u - V.rutU(y, sd)) / w
        local ad = abs(d)
        if ad < 1 and 1 - ad * ad > best then best, side, du = 1 - ad * ad, sd, d end
    end
    return best, side, du
end

local LX = 1
local memo, dmemo = {}, {}

local function grid(cell, n)
    local k = max(1, floor(n / cell + 0.5))
    return k, n / k
end

local function stoneAt(wi, wj, s, cx, cy, rmin, rmax)
    local key = (wi * 4099 + wj) * 977 + s
    local c = memo[key]
    if c then return c end
    local K = 5 + floor(h2(wi, wj, s + 5) * 3)
    local rot = h2(wi, wj, s + 6) * TAU
    local r = rmin + h2(wi, wj, s + 3) * (rmax - rmin)
    local el = 0.75 + h2(wi, wj, s + 7) * 0.6
    c = { px = (h2(wi, wj, s + 1) * 0.6 + 0.2) * cx, py = (h2(wi, wj, s + 2) * 0.6 + 0.2) * cy, r = r, K = K,
        co = {}, si = {}, rr = {}, lit = {}, tone = h2(wi, wj, s + 4), el = el }
    for k = 1, K do
        local a = rot + (k - 1) / K * TAU + (h2(wi + k, wj, s + 9) - 0.5) * (TAU / K) * 0.6
        c.co[k], c.si[k] = cos(a), sin(a)
        c.rr[k] = 0.78 + h2(wi, wj + k, s + 11) * 0.34
        c.lit[k] = c.co[k] * LX * 0.75 - c.si[k] * 0.65
    end
    memo[key] = c
    return c
end

local function stone(x, y, cell, dens, rmin, rmax, s, accept)
    local ncx, cx = grid(cell, TW)
    local ncy, cy = grid(cell * 1.15, TH)
    local ci, cj = floor(x / cx), floor(y / cy)
    local bestD, bestC, bestF = nil, nil, 1
    for dj = -1, 1 do
        for di = -1, 1 do
            local i, j = ci + di, cj + dj
            local wi, wj = i % ncx, j % ncy
            if h2(wi, wj, s) < dens then
                local c = stoneAt(wi, wj, s, cx, cy, rmin, rmax)
                local px, py = i * cx + c.px, j * cy + c.py
                if not accept or accept(((px % TW) - CU) / HALF, py % TH) then
                    local dx, dy = (x + 0.5 - px) / c.el, (y + 0.5 - py) / 1.15
                    local dmax, fk = -1e9, 1
                    for k = 1, c.K do
                        local dd = (dx * c.co[k] + dy * c.si[k]) / (c.r * c.rr[k])
                        if dd > dmax then dmax, fk = dd, k end
                    end
                    if dmax < 1 and (not bestD or dmax < bestD) then bestD, bestC, bestF = dmax, c, fk end
                end
            end
        end
    end
    if not bestD then return nil end
    local c = bestC
    local d = max(0, bestD)
    local lit = c.lit[bestF]
    local tv = (c.tone - 0.5) * 0.14
    local val
    if d < 0.55 then val = 0.66 + tv
    elseif lit > 0.25 then val = 0.74 + tv
    elseif lit > -0.2 then val = 0.5 + tv
    else val = 0.3 + tv end
    if d > 0.8 and lit < 0.1 then val = 0.14 + tv * 0.5 end
    return 0.7 + (1 - d) * 0.3, val, c, d, c.si[bestF]
end

local function leafAt(x, y, cell, dens, s, len0, len1, wk0, wk1, pick)
    local ncx, cx = grid(cell, TW)
    local ncy, cy = grid(cell, TH)
    local ci, cj = floor(x / cx), floor(y / cy)
    local best, bv, bm, bl = nil, 0, LEAF, nil
    for dj = -1, 1 do
        for di = -1, 1 do
            local i, j = ci + di, cj + dj
            local wi, wj = i % ncx, j % ncy
            local dkey = ((wi * 1031 + wj) * 7 + cell) * 131 + s
            local dk = dmemo[dkey]
            if not dk then
                dk = dens(((i + 0.5) * cx % TW - CU) / HALF, (j + 0.5) * cy % TH)
                dmemo[dkey] = dk
            end
            if h2(wi, wj, s) < dk then
                local px = (i + 0.15 + h2(wi, wj, s + 1) * 0.7) * cx
                local py = (j + 0.15 + h2(wi, wj, s + 2) * 0.7) * cy
                local a = h2(wi, wj, s + 3) * TAU
                local ca, sa = cos(a), sin(a)
                local L = len0 + h2(wi, wj, s + 4) * (len1 - len0)
                local W = L * ((wk0 or 0.45) + h2(wi, wj, s + 5) * ((wk1 or 0.62) - (wk0 or 0.45)))
                local dx, dy = x + 0.5 - px, (y + 0.5 - py) * 1.2
                local al = (dx * ca + dy * sa) / L
                local ac = (-dx * sa + dy * ca)
                if al > -1 and al < 1 then
                    local prof = (1 - al * al) * (al < 0 and 1 or (1 - al * 0.35))
                    local lim = W * prof
                    if abs(ac) < lim then
                        local layer = h2(wi, wj, s + 6)
                        if not best or layer > best then
                            best = layer
                            local hk = h2(wi, wj, s + 7)
                            if pick then bm = pick(hk) else
                                bm = hk < 0.34 and LEAF or hk < 0.58 and LEAF2 or hk < 0.8 and LEAF3 or LEAF4
                            end
                            local litSide = (-sa * LX - ca * 0.6)
                            local v = 0.52 + (h2(wi, wj, s + 8) - 0.5) * 0.24
                            local side = ac / max(0.5, lim)
                            v = v + side * litSide * 0.3
                            if lim > 1.3 and abs(ac) < 0.45 and al > -0.8 and al < 0.75 then v = v - 0.14 end
                            if abs(ac) > lim - 0.7 and side * litSide < 0 then v = v - 0.16 end
                            if al < -0.9 then v = 0.15 end
                            bv = v
                            bl = layer
                        end
                    end
                end
            end
        end
    end
    if not best then return nil end
    return bm, bv, bl
end

local LEAFMATS = { LEAF, LEAF2, LEAF3, LEAF4, LEAF5, LEAF6, LEAF, LEAF2 }

local function fallenLeaf(x, y, cell, dens, s, len0, len1)
    local ncx, cx = grid(cell, TW)
    local ncy, cy = grid(cell, TH)
    local ci, cj = floor(x / cx), floor(y / cy)
    local best, bm, bv
    for dj = -1, 1 do
        for di = -1, 1 do
            local i, j = ci + di, cj + dj
            local wi, wj = i % ncx, j % ncy
            local dkey = ((wi * 1031 + wj) * 7 + floor(cell * 10)) * 131 + s
            local dk = dmemo[dkey]
            if not dk then
                dk = dens(((i + 0.5) * cx % TW - CU) / HALF, (j + 0.5) * cy % TH)
                dmemo[dkey] = dk
            end
            local layer = h2(wi, wj, s + 6)
            if h2(wi, wj, s) < dk and (not best or layer > best) then
                local px = (i + 0.1 + h2(wi, wj, s + 1) * 0.8) * cx
                local py = (j + 0.1 + h2(wi, wj, s + 2) * 0.8) * cy
                local a = h2(wi, wj, s + 3) * TAU
                local ca, sa = cos(a), sin(a)
                local L = len0 + h2(wi, wj, s + 4) * (len1 - len0)
                local W = L * (0.4 + h2(wi, wj, s + 5) * 0.2)
                local curl = h2(wi, wj, s + 9) < 0.28
                local dx, dy = x - px, (y - py) * 1.2
                local al = (dx * ca + dy * sa) / L
                local ac = (-dx * sa + dy * ca)
                local hit, v = false, 0
                local litSide = (-sa * LX - ca * 0.6)
                if al <= -0.92 and al > -1.4 and abs(ac + (al + 0.92) * 0.25) < 0.2 then
                    hit, v = true, 0.12
                elseif al > -1 and al < 1 then
                    local prof = (al < 0) and sqrt(1 - al * al) or (1 - al * al) * (1 - al * 0.25)
                    local limA, limB = W * prof, W * prof
                    if curl then limA = limA * 0.45 end
                    if ac < limA and ac > -limB then
                        hit = true
                        local side = ac / max(0.4, ac > 0 and limA or limB)
                        v = 0.55 + (h2(wi, wj, s + 8) - 0.5) * 0.24 + side * litSide * 0.26
                        if L > 1.6 and abs(ac) < 0.32 and al > -0.85 and al < 0.8 then v = v - 0.14 end
                        if curl and ac > limA - 0.6 then v = v + 0.2 end
                        if curl and ac > 0 and ac < limA - 0.6 then v = v - 0.18 end
                        if (ac > 0 and ac > limA - 0.45 or ac < 0 and ac < -limB + 0.45) and side * litSide < 0 then
                            v = v - 0.16
                        end
                    end
                end
                if hit then
                    best = layer
                    bm = LEAFMATS[1 + floor(h2(wi, wj, s + 7) * #LEAFMATS)]
                    bv = v
                end
            end
        end
    end
    if not best then return nil end
    return bm, bv, best
end

local function trail(x, y, u, s, o)
    local au = abs(u)
    local n = fbm(x, y, s, 6, 26)
    local fine = h2(x, y, s + 21)
    local worn = 1 - sstep(0.12, 0.6, au)
    local sho = sstep(0.62, 1.05, au)
    local rk, side, du = rutK(u, y, o.rutW)
    local rutGap = vnoise(x, y, 2, 14, s + 33)
    if rutGap < 0.28 then rk = rk * rutGap / 0.28 end
    local val = 0.56 + (n - 0.5) * (0.30 - worn * 0.16) + worn * 0.12 - sho * 0.16 + (fine - 0.5) * 0.06
    local h = 0.3 + n * 0.1 - rk * 0.5 * (o.rutDepth or 1)
    val = val - rk * 0.3 * (o.rutDepth or 1)
    local lip = 0
    if side ~= 0 then
        local outer = du * side
        if outer > 0.75 and outer < 1.35 then lip = (1 - abs(outer - 1.05) / 0.3) end
    end
    if lip > 0 then val = val + lip * (o.lip or 0.12); h = h + lip * 0.08 end
    return o.base or DIRT, h, val, sho, rk, worn
end

local function gravel(x, y, s, k)
    local cl = vnoise(x, y, 10, 34, s + 93)
    if cl < 0.5 then return nil end
    k = k * (cl - 0.5) * 2
    local g = h2(x, y, s + 91)
    if g < 0.03 * k then return 0.7 end
    if g > 1 - 0.025 * k then return 0.22 end
    return nil
end

local function strawPick() return STRAW end

local PAINT = {}

local OPT = { f = { rutW = 0.09 }, h = { rutW = 0.08 }, a = { rutW = 0.075, rutDepth = 0.75, lip = 0.26, base = ASH }, d = { rutW = 0.09 } }
local CUR = { sho = 0, s = 0 }
local function acceptF(uu) return abs(uu) < 1.05 end
local function acceptH(uu) return abs(uu) < 0.95 end
local function strawDens() return 0.08 + CUR.sho * 0.3 end
local function duskDens(uu, yy)
    local rr = rutK(uu, yy, 0.13)
    local a = abs(uu)
    local clump = vnoise(uu * HALF + CU, yy, 4, 14, CUR.s + 66)
    local edge = sstep(0.5, 0.92, a)
    local worn = 1 - sstep(0.12, 0.6, a)
    return 0.32 + edge * 0.7 + rr * 0.15 + (clump - 0.45) * 0.9 - (1 - edge) * worn * 0.05
end
local function duskDens2(uu, yy) return (duskDens(uu, yy) - 0.25) * 1.5 end

PAINT.fields = function(x, y, u, s)
    local mat, h, val, sho, rk, worn = trail(x, y, u, s, OPT.f)
    local au = abs(u)
    local big, bv = stone(x, y, 16, 0.22 * (1 - rk) * (0.35 + sho + (1 - worn) * 0.6), 1.6, 3.0, s + 71,
        acceptF)
    if big then return STONE, big, bv end
    local sm, sv = stone(x, y, 7, 0.2 * (1 - rk * 0.9), 0.9, 1.5, s + 75)
    if sm then return STONE, sm - 0.15, sv end
    local cl, cv = stone(x, y, 7, 0.14 * (0.4 + sho), 0.9, 1.6, s + 79)
    if cl then return DIRT, cl - 0.2, cv * 0.7 + 0.2 end
    if rk > 0.45 then
        local cr = voronoi(x, y, 34, 90, s + 77, 1.0)
        if cr < 0.045 and vnoise(x, y, 5, 30, s + 78) > 0.5 then val = val - 0.18 end
    end
    if worn > 0.5 and au > 0.16 and au < 0.32 then
        local cy = floor(y / 19)
        local off = h2(cy, 1, s + 81) > 0.5 and 0.24 or -0.24
        if h2(cy, 2, s + 81) > 0.4 then
            local dx = x + 0.5 - (CU + off * HALF)
            local dy = (y - cy * 19 - 2.2) * 1.15
            local r = sqrt(dx * dx + dy * dy)
            if r < 2.0 and r > 1.05 and dy < 0.9 then
                val = val - (dy < -0.3 and 0.16 or 0.1); h = h - 0.05
            elseif r <= 1.05 and dy > -0.4 then
                val = val + 0.04
            end
        end
    end
    CUR.sho = sho
    local st = au > 0.45 and au < 1.0 and leafAt(x, y, 9, strawDens, s + 85, 1.8, 2.8,
        0.18, 0.26, strawPick)
    if st then return STRAW, h + 0.1, 0.35 + val * 0.4 end
    local gr = gravel(x, y, s, 1.6 - worn * 0.6)
    if gr then return STONE, h + 0.06, gr end
    local cr2 = vnoise(x, y, 40, 140, s + 113)
    if cr2 > 0.72 then val = val - (cr2 - 0.72) * 0.6 end
    return mat, h, val
end

PAINT.highlands = function(x, y, u, s)
    local mat, h, val, sho, rk, worn = trail(x, y, u, s, OPT.h)
    local big, bv = stone(x, y, 24, 0.26, 2.8, 4.6, s + 67, acceptH)
    if big then
        if bv > 0.6 and h2(x, y, s + 69) < 0.07 then return MOSS, big, 0.55 end
        return STONE, big, bv
    end
    local dens = 0.3 * (1 - rk * 0.85) + sho * 0.25 + (1 - worn) * 0.12
    local sh, sv = stone(x, y, 10, dens, 1.3, 2.4, s + 61)
    if sh then return STONE, sh - 0.05, sv - 0.04 end
    local ph, pv = stone(x, y, 6, dens * 0.6, 0.7, 1.2, s + 63)
    if ph then return STONE, ph - 0.2, pv end
    local gr = gravel(x, y, s, 1.6 - worn * 0.6)
    if gr then return STONE, h + 0.05, gr end
    if sho > 0.3 and h2(x, y, s + 65) < 0.03 * sho then return MOSS, h, 0.4 end
    return mat, h, val - 0.03
end

local function crackNet(x, y, nx, ny, s)
    local gx, gy = x / TW * nx, y / TH * ny
    local ci, cj = floor(gx), floor(gy)
    local d1, d2, a1, a2 = 1e9, 1e9, 0, 0
    for dj = -1, 1 do
        for di = -1, 1 do
            local i, j = ci + di, cj + dj
            local wi, wj = i % nx, j % ny
            local px = i + 0.5 + (h2(wi, wj, s) - 0.5) * 0.95
            local py = j + 0.5 + (h2(wi, wj, s + 3) - 0.5) * 0.95
            local dx, dy = px - gx, py - gy
            local d = sqrt(dx * dx + dy * dy)
            local id = wi * 131 + wj
            if d < d1 then
                d2, a2 = d1, a1; d1, a1 = d, id
            elseif d < d2 then d2, a2 = d, id end
        end
    end
    local lo, hi = min(a1, a2), max(a1, a2)
    return d2 - d1, h2(lo, hi, s + 5)
end

local function scoriaOr(c, s, a, b)
    return h2(floor(c.px * 7.3), floor(c.py * 3.1), s) < 0.42 and a or b
end

local function rim(v, d, si, k)
    k = k or 1
    if d > 0.5 then
        if si > 0.25 then return v + 0.42 * k end
        if si < -0.25 then return v - 0.42 * k end
    end
    return v
end

PAINT.abyss = function(x, y, u, s)
    local mat, h, val, sho, rk, worn = trail(x, y, u, s, OPT.a)
    local jx = x + (vnoise(x, y, 24, 80, s + 21) - 0.5) * 2.2
    local jy = y + (vnoise(x, y, 24, 80, s + 22) - 0.5) * 2.2
    local cd, ce = crackNet(jx, jy, 9, 30, s + 23)
    local open = vnoise(x, y, 3, 12, s + 25)
    local hot = vnoise(x, y, 4, 22, s + 29)
    local wid = 0.014 + h2(floor(ce * 977), 1, s) * 0.016
    local crack = ce < 0.22 + open * 0.35 and open > 0.32
    local lava = crack and hot > 0.47 and ce < 0.38
    if lava then wid = wid * 1.35 end
    if crack and cd < wid then
        local depth = 1 - cd / wid
        if lava then return EMBER, 0.0, 0.32 + depth * 0.5 + (hot - 0.42) * 0.9 end
        return GAP, 0.05, 0.2 + (1 - depth) * 0.45
    end
    local plate, pv, _, pd, psi = stone(x, y, 25, 0.55 * (sho + 0.35) * (1 - worn * 0.7), 4.0, 7.0, s + 61, acceptF)
    if plate then
        local pcr = abs(vnoise(jx, jy, 11, 36, s + 63) - 0.5)
        if pcr < 0.016 then return GAP, 0.4, 0.18 end
        local rope = sin(jx * 0.7 + jy * 1.3 + vnoise(x, y, 5, 16, s + 31) * 6)
        local pt = (h2(floor(x), floor(y), s + 65) - 0.5) * 0.14 + (rope > 0.65 and 0.12 or rope < -0.8 and -0.1 or 0)
        local v = 0.42 + pt + (pv - 0.5) * 0.3
        if pd > 0.86 then v = psi > 0 and v + 0.32 or v - 0.3 end
        return SOOT, 0.58, v
    end
    local big, bv, bc, bd, bsi = stone(x, y, 15, 0.3 * (1 - rk) * (0.45 + sho + (1 - worn) * 0.5), 1.7, 3.0,
        s + 71, acceptF)
    if big then
        if bv > 0.55 and bc.tone < 0.06 then return EMBER, big, 0.18 + (bv - 0.55) * 1.4 end
        return scoriaOr(bc, s + 72, SCORIA, SOOT), big, rim(bv * 0.9 + 0.04, bd, bsi)
    end
    local cdn = (1 - rk * 0.85) * (0.35 + sho * 0.8 + (1 - worn) * 0.45)
    local md, mv, mc, mdd, msi = stone(x, y, 8.5, 0.36 * cdn, 1.4, 2.4, s + 75)
    if md then return scoriaOr(mc, s + 76, SCORIA, SOOT), md - 0.1, rim(mv, mdd, msi) end
    local sm, sv, sc, sdd, ssi = stone(x, y, 4.5, 0.55 * cdn, 0.6, 1.1, s + 79)
    if sm then return scoriaOr(sc, s + 80, SCORIA, SOOT), sm - 0.25, rim(sv * 0.85, sdd, ssi, 0.8) end
    local heat = lava and cd < wid * 6 and (1 - cd / (wid * 6)) or 0
    local tp, tv, _, td, tsi = stone(x, y, 3, 0.5 * (1 - rk * 0.7), 0.45, 0.75, s + 83)
    if tp and heat < 0.35 then
        return ASH, tp - 0.45, rim(tv * 0.5 + 0.25 + (fbm(x, y, s + 13, 8, 34) - 0.5) * 0.2, td, tsi, 0.6)
    end
    local ash = fbm(x, y, s + 15, 3, 9)
    local gr = (h2(floor(x), floor(y), s + 49) - 0.5) * 0.16 + (h2(floor(x / 2), floor(y / 2), s + 51) - 0.5) * 0.14
    val = val + (fbm(x, y, s + 13, 8, 34) - 0.5) * 0.24 - worn * 0.06 + sstep(0.5, 0.72, ash) * 0.22 + gr
    if heat > 0 then
        return HEAT, h, 0.08 + heat * heat * 0.75 + (hot - 0.42) * 0.35 + gr * 0.5
    end
    if crack and cd < wid * 1.8 then val = val - 0.1 end
    if worn < 0.5 and h2(floor(x / 2), floor(y / 2), s + 47) < 0.0008 then return EMBER, h + 0.05, 0.3 end
    return ASH, h, val
end

local function bootPrint(x, y, s)
    for w = 0, 2 do
        local wu = (h2(w, 1, s + 41) - 0.5) * 0.9
        local stepL = 15 + floor(h2(w, 2, s + 41) * 5)
        local ph = floor(h2(w, 3, s + 41) * stepL)
        local yy = (y + ph) % stepL
        local idx = floor((y + ph) / stepL)
        if h2(idx, w, s + 43) > 0.2 then
            local side = (idx % 2 == 0) and -1 or 1
            local cxp = CU + (wu + side * 0.07) * HALF + (h2(idx, w, s + 44) - 0.5)
            local dx = (x + 0.5 - cxp) / 1.3
            local dy = (yy - 3) / 2.8
            local r = dx * dx + dy * dy
            if r < 1 then
                if dy < -0.4 then return -0.16 end
                if dy > 0.6 then return 0.06 end
                return -0.1
            end
        end
    end
    return nil
end

PAINT.frost = function(x, y, u, s)
    local au = abs(u)
    local n = fbm(x, y, s, 6, 24)
    local worn = 1 - sstep(0.15, 0.7, au)
    local rk = rutK(u, y, 0.1)
    local val = 0.5 - worn * 0.28 + (n - 0.5) * 0.14 - rk * 0.2 + sstep(0.68, 0.98, au) * 0.34
    local h = 0.4 - rk * 0.25
    if rk > 0.6 and h2(x, y, s + 49) < 0.05 then val = val + 0.3 end
    local bp = au < 0.75 and bootPrint(x, y, s)
    if bp then return SNOW, 0.3, val + bp end
    local rip = sin((y / TH) * TAU * 52 + vnoise(x, y, 6, 20, s + 45) * 8 + x * 0.06)
    if au > 0.5 and rip > 0.8 then val = val + 0.1 * sstep(0.5, 0.85, au) end
    if au > 0.5 and rip < -0.9 then val = val - 0.05 * sstep(0.5, 0.85, au) end
    if h2(x, y, s + 47) < 0.006 * (1.4 - worn) then val = 1.0 end
    return SNOW, h, val
end

OPT.m = { rutW = 0.11, rutDepth = 0.6, base = MUD }
local function marshRoot(x, y, u, s)
    local cell = 15
    local rc = floor(y / cell)
    for dc = -1, 0 do
        local c = rc + dc
        if h2(c, 71, s) < 0.55 then
            local sd = h2(c, 72, s) < 0.5 and -1 or 1
            local y0 = c * cell + h2(c, 73, s) * 6
            local len = 9 + h2(c, 74, s) * 12
            local ly = y - y0
            if ly >= 0 and ly < len and u * sd > 0.3 then
                local k = ly / len
                local ur = sd * (1.15 - k * (0.34 + h2(c, 75, s) * 0.26)) + sin(ly * 0.5 + c) * 0.03
                local th = (2.3 - k * 1.3) / HALF
                local d = (u - ur) * sd
                if abs(d) < th then
                    local lit = (d * LX * sd > 0) and 0.22 or 0
                    return WOOD, 0.75 - k * 0.2, 0.26 + lit + (k < 0.2 and 0.08 or 0)
                end
                if abs(d) < th + 1.3 / HALF then return PEAT, 0.12, 0.18 end
            end
        end
    end
    return nil
end

local function marshReed(x, y, e, s)
    if e < 0.8 then return nil end
    if vnoise(x, y, 9, 46, s + 66) < 0.5 then return nil end
    local rcx = floor(x)
    local ph = h2(rcx, 5, s + 56) * 6
    local band = floor((y + ph) / 6)
    if h2(rcx, band, s + 57) > sstep(0.8, 1.08, e) * 0.55 then return nil end
    local hgt = 3 + floor(h2(rcx, band, s + 59) * 4)
    local ly = y + ph - band * 6
    if ly >= hgt then return nil end
    local top = 1 - ly / hgt
    return GRASS, 0.8 + top * 0.3, 0.22 + top * 0.66 + (h2(rcx, 3, s + 58) - 0.5) * 0.14
end

local function puddle(x, y, rk, e, s)
    return fbm(x, y, s + 80, 8, 30) * 0.72 + vnoise(x, y, 18, 64, s + 82) * 0.28 + rk * 0.2
        - sstep(0.55, 0.95, e) * 0.22
end

local PW = 0.63
local function woodPick() return WOOD end
local function twigDens(uu) return abs(uu) > 0.2 and 0.1 or 0.03 end
PAINT.marsh = function(x, y, u, s)
    local mat, h, val, sho, rk, worn = trail(x, y, u, s, OPT.m)
    local au = abs(u)
    local e = au + (vnoise(x, y, 3, 24, s + 70) - 0.5) * 0.24
    local rm, rh, rv = marshRoot(x, y, u, s)
    if rm then return rm, rh, rv end
    local gm, gh, gv = marshReed(x, y, e, s)
    if gm then return gm, gh, gv end
    local pw = puddle(x, y, rk, e, s)
    if pw > PW then
        local d = pw - PW
        if d < 0.012 then return PEAT, 0.14, 0.16 end
        local far = puddle(x, y + 3, rk, e, s)
        local near = puddle(x, y - 1.5, rk, e, s)
        local v = 0.26 + min(0.26, d * 3)
        if far < PW + 0.015 then v = 0.08 end
        if near < PW + 0.008 then v = v + 0.34 end
        local band = sin(y * 0.55 + vnoise(x, y, 4, 30, s + 24) * 4)
        if band > 0.82 then v = v + 0.12 end
        if band > 0.97 and vnoise(x, y, 20, 60, s + 25) > 0.55 then v = v + 0.22 end
        return WATER, 0.0, v
    end
    local wet = sstep(PW - 0.09, PW, pw)
    local peat = sstep(0.6, 1.0, e)
    local dry = fbm(x, y, s + 90, 9, 34)
    local macro = fbm(x, y, s + 88, 3, 9)
    val = val + 0.08 + (dry - 0.5) * 0.3 + (macro - 0.5) * 0.36 - wet * 0.24 - peat * 0.12
    if wet > 0.35 and h2(floor(x / 2), floor(y), s + 63) > 0.9 then return WATER, h, 0.62 end
    local bp = au < 0.62 and bootPrint(x, y, s + 5)
    if bp then
        if pw > PW - 0.16 and bp < -0.05 then return WATER, 0.05, 0.3 end
        val = val + bp * 1.4; h = h - 0.08
    end
    if peat > 0.25 then
        local fib = vnoise(x, y, 48, 70, s + 92)
        local pv = 0.42 + (fib - 0.5) * 0.4 + (dry - 0.5) * 0.2 - wet * 0.15
        if h2(x, y, s + 95) < 0.06 * peat then return MOSS, h + 0.06, 0.32 + h2(x, y, s + 96) * 0.36 end
        if peat > 0.55 or h2(floor(x), floor(y / 2), s + 94) < peat then return PEAT, h - 0.02, pv end
    end
    local tw = leafAt(x, y, 11, twigDens, s + 99, 1.8, 3.2, 0.1, 0.16, woodPick)
    if tw then return WOOD, h + 0.12, 0.2 + val * 0.35 end
    if au > 0.35 and au < 0.85 and vnoise(x, y, 10, 40, s + 101) > 0.72 and h2(floor(x), floor(y / 2), s + 102) < 0.3 then
        return GRASS, h + 0.2, 0.25 + h2(floor(x), floor(y), s + 103) * 0.4
    end
    local sm, sv = stone(x, y, 12, 0.05 * (0.3 + sho), 0.9, 1.5, s + 97)
    if sm then return MUD, sm - 0.1, sv * 0.5 + 0.3 end
    if worn > 0.5 and h2(floor(x), floor(y), s + 98) < 0.025 then val = val + 0.12 end
    return mat, h, val
end

PAINT.dusk = function(x, y, u, s)
    local mat, h, val, sho, rk, worn = trail(x, y, u, s, OPT.d)
    CUR.s = s
    local dens = duskDens
    local m2, lv, ly = fallenLeaf(x, y, 6, dens, s + 61, 2.1, 3.1)
    local m3, lv3, ly3 = fallenLeaf(x, y, 3.5, duskDens2, s + 91, 1.4, 2.0)
    if m2 then
        local wornLeaf = worn > 0.8 and rk < 0.25 and h2(floor(x), floor(y / 3), s + 63) < 0.5
        return wornLeaf and LEAF4 or m2, h + 0.3 + ly * 0.25, lv * (wornLeaf and 0.75 or 1)
    end
    if m3 then return m3, h + 0.18 + ly3 * 0.1, lv3 * 0.85 end
    if dens(u, y) > 0.6 then val = val - 0.06 end
    local sh, sv = stone(x, y, 15, 0.1, 1.2, 2.2, s + 71)
    if sh then return STONE, sh, sv end
    local gr = gravel(x, y, s, 0.7)
    if gr then return STONE, h + 0.05, gr end
    return mat, h, val
end

V.LIGHT_X = { fields = 1, highlands = 1, abyss = 1, frost = 1, marsh = 1, dusk = -1 }

function V.paint(bid, x, y, seed)
    return PAINT[bid](x, y, (x + 0.5 - CU) / HALF, seed)
end

V.S = 2
V.BUF = {}
V.MEMO = {}
V.GRAIN = { [DIRT] = 0.2, [MUD] = 0.14, [ASH] = 0.18, [SOOT] = 0.12, [SNOW] = 0.08, [STONE] = 0.12,
    [WOOD] = 0.08, [GRASS] = 0.14, [LEAF] = 0.1, [LEAF2] = 0.1, [LEAF3] = 0.1, [LEAF4] = 0.1, [LEAF5] = 0.1,
    [LEAF6] = 0.1, [STRAW] = 0.1, [PEAT] = 0.16, [SCORIA] = 0.14, [HEAT] = 0.06 }

local ffi = require("ffi")

local function boxBlur(src, dst, W, H, rx, ry, tmp)
    for y = 0, H - 1 do
        local row = y * W
        local acc = 0
        for dx = -rx, rx do acc = acc + src[row + dx % W] end
        for x = 0, W - 1 do
            tmp[row + x] = acc
            acc = acc + src[row + (x + rx + 1) % W] - src[row + (x - rx) % W]
        end
    end
    local n = (2 * rx + 1) * (2 * ry + 1)
    for x = 0, W - 1 do
        local acc = 0
        for dy = -ry, ry do acc = acc + tmp[(dy % H) * W + x] end
        for y = 0, H - 1 do
            dst[y * W + x] = acc / n
            acc = acc + tmp[((y + ry + 1) % H) * W + x] - tmp[((y - ry) % H) * W + x]
        end
    end
end

function V.bake(bid, pal, yieldEvery)
    local paint = PAINT[bid]
    if not paint then return nil end
    local P = palettes(bid, pal)
    local seed = 0
    for i = 1, #bid do seed = seed + bid:byte(i) end
    local lx = V.LIGHT_X[bid] or 1
    LX = lx
    local GR = V.GRAIN
    local S = V.S
    local W, H = TW * S, TH * S
    local N = W * H
    local d = love.image.newImageData(W * 2, H)
    local owner = V.BUF.owner
    local shared = not (owner and owner ~= true and coroutine.status(owner) ~= "dead")
    local F = shared and V.BUF or {}
    if F.n ~= N then
        F.n = N
        F.M = ffi.new("uint8_t[?]", N)
        F.Hh, F.Vv = ffi.new("float[?]", N), ffi.new("float[?]", N)
        F.R, F.G, F.B = ffi.new("float[?]", N), ffi.new("float[?]", N), ffi.new("float[?]", N)
        F.tmp = ffi.new("float[?]", N)
        F.bR, F.bG, F.bB = ffi.new("float[?]", N), ffi.new("float[?]", N), ffi.new("float[?]", N)
    end
    if shared then V.BUF.owner = coroutine.running() or true end
    local M, Hh, Vv, R, G, B = F.M, F.Hh, F.Vv, F.R, F.G, F.B
    V.MEMO[bid] = V.MEMO[bid] or { {}, {} }
    local function pass(ox)
        memo, dmemo = V.MEMO[bid][1], V.MEMO[bid][2]
        for Y = 0, H - 1 do
            if yieldEvery and Y % yieldEvery == yieldEvery - 1 then coroutine.yield() end
            local y = Y / S
            for X = 0, W - 1 do
                local x = X / S
                local u = (x + 0.5 / S - CU) / HALF
                local m, h, v = paint(x, y, u, seed)
                local i = Y * W + X
                M[i], Hh[i], Vv[i] = m, h, v
            end
        end
        for Y = 0, H - 1 do
            if yieldEvery and Y % yieldEvery == yieldEvery - 1 then coroutine.yield() end
            local yu = ((Y + S) % H) * W
            local yd = ((Y - S) % H) * W
            local y2 = ((Y + 2 * S) % H) * W
            local y1 = ((Y + 1) % H) * W
            local y0 = Y * W
            for X = 0, W - 1 do
                local i = y0 + X
                local m = M[i]
                local v = Vv[i]
                local h = Hh[i]
                if m ~= EMBER then
                    local hToLight = Hh[yu + (X + lx * S) % W]
                    local hAway = Hh[yd + (X - lx * S) % W]
                    local h2l = Hh[y2 + (X + 2 * lx * S) % W]
                    if hToLight - h > 0.25 then v = v - 0.3 - (hToLight - h) * 0.2
                    elseif h2l - h > 0.35 then v = v - 0.16 end
                    if Hh[yu + X] - h > 0.3 then v = v - 0.1 end
                    if h - Hh[y1 + (X + lx) % W] > 0.25 then v = v + 0.16 end
                    if h - hAway > 0.25 then v = v - 0.08 end
                end
                local gk = GR[m]
                if gk then
                    v = v + ((h2(X, Y, 331) - 0.5) * 0.6 + (h2(floor(X / 2), floor(Y / 2), 337) - 0.5) * 0.4) * gk
                end
                local pr = P[m] or P[DIRT]
                local n = #pr
                local lv = max(0, min(1, v)) * (n - 1) + 1
                local li = floor(lv)
                if lv - li > 0.5 + (h2(X, Y, 977) - 0.5) * 0.22 + (bayer(X, Y) - 0.5) * 0.12 then li = li + 1 end
                li = max(1, min(n, li))
                local c = pr[li]
                R[i], G[i], B[i] = c[1], c[2], c[3]
                d:setPixel(ox + X, Y, c[1], c[2], c[3], 1)
            end
        end
    end
    local by = 7 * S
    local tmp = F.tmp
    local bR, bG, bB = F.bR, F.bG, F.bB
    local function blurTo(ox, k)
        boxBlur(R, bR, W, H, 3 * S, by, tmp)
        if yieldEvery then coroutine.yield() end
        boxBlur(G, bG, W, H, 3 * S, by, tmp)
        if yieldEvery then coroutine.yield() end
        boxBlur(B, bB, W, H, 3 * S, by, tmp)
        for Y = 0, H - 1 do
            if yieldEvery and Y % (yieldEvery * 4) == 0 then coroutine.yield() end
            for X = 0, W - 1 do
                local i = Y * W + X
                local r, g, b = bR[i], bG[i], bB[i]
                d:setPixel(ox + X, Y, r + (R[i] - r) * k, g + (G[i] - g) * k, b + (B[i] - b) * k, 1)
            end
        end
    end
    pass(0)
    blurTo(W, 0.22)
    if shared then V.BUF.owner = nil end
    local img = love.graphics.newImage(d)
    img:setFilter("nearest", "nearest")
    img:setWrap("repeat", "repeat")
    return img
end

V.STYLE = {}

function V.style(bid)
    local st = V.STYLE[bid]
    if st then return st end
    local S = V.S
    st = { half = HALF * S, cu = CU * S, far = TW * S, vk = V.VK * S, tm0 = 0.98, tmK = 0.03, farT0 = 0.1,
        farT1 = 0.42, farDv = 1.0 * S, S = S }
    V.STYLE[bid] = st
    return st
end

return V
