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
    RUST, SOOT = 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19
V.MAT = { DIRT = DIRT, STONE = STONE, LEAF = LEAF, LEAF2 = LEAF2, LEAF3 = LEAF3, LEAF4 = LEAF4, EMBER = EMBER,
    WOOD = WOOD, WATER = WATER, SNOW = SNOW }

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
    P[MUD] = ramp(mul(edge, 0.8), mix(edge, roadB, 0.7), mul(roadA, 1.05), 5)
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
    P[ASH] = ramp(mul(edge, 0.85), mix(roadB, { 0.3, 0.28, 0.28 }, 0.55), mix(roadA, { 0.62, 0.6, 0.58 }, 0.62), 7)
    P[SOOT] = ramp(mul(edge, 0.5), mul(edge, 0.9), mix(edge, roadB, 0.5), 3)
    P[RUST] = { { 0.24, 0.12, 0.07 }, { 0.42, 0.22, 0.1 }, { 0.55, 0.32, 0.14 } }
    P[STRAW] = { { 0.42, 0.33, 0.14 }, { 0.62, 0.52, 0.26 }, { 0.8, 0.7, 0.4 } }
    P[LEAF] = { { 0.36, 0.13, 0.06 }, { 0.6, 0.24, 0.08 }, { 0.82, 0.4, 0.12 }, { 0.95, 0.58, 0.2 } }
    P[LEAF2] = { { 0.3, 0.07, 0.06 }, { 0.5, 0.12, 0.08 }, { 0.68, 0.2, 0.1 }, { 0.82, 0.32, 0.14 } }
    P[LEAF3] = { { 0.4, 0.26, 0.08 }, { 0.62, 0.44, 0.12 }, { 0.8, 0.62, 0.2 }, { 0.92, 0.78, 0.34 } }
    P[LEAF4] = { { 0.2, 0.12, 0.07 }, { 0.33, 0.21, 0.11 }, { 0.46, 0.31, 0.16 }, { 0.58, 0.42, 0.22 } }
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
    return 0.7 + (1 - d) * 0.3, val, c
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
    val = val - rk * 0.3
    local lip = 0
    if side ~= 0 then
        local outer = du * side
        if outer > 0.75 and outer < 1.35 then lip = (1 - abs(outer - 1.05) / 0.3) end
    end
    if lip > 0 then val = val + lip * 0.12; h = h + lip * 0.08 end
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

PAINT.fields = function(x, y, u, s)
    local mat, h, val, sho, rk, worn = trail(x, y, u, s, { rutW = 0.09 })
    local au = abs(u)
    local patch = fbm(x, y, s + 111, 3, 10)
    val = val + (patch - 0.5) * 0.18
    local big, bv = stone(x, y, 16, 0.22 * (1 - rk) * (0.35 + sho + (1 - worn) * 0.6), 1.6, 3.0, s + 71,
        function(uu) return abs(uu) < 1.05 end)
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
        local hy = y - cy * 19
        local off = h2(cy, 1, s + 81) > 0.5 and 0.24 or -0.24
        local hx = floor(x + 0.5 - CU - off * HALF + 2)
        if h2(cy, 2, s + 81) > 0.4 and hy < 4 and hx >= 0 and hx < 4 then
            local rim = (hy == 0) or hx == 0 or hx == 3
            if rim and not (hy == 3 and (hx == 1 or hx == 2)) then val = val - 0.15; h = h - 0.05 end
            if hy == 3 and (hx == 1 or hx == 2) then val = val + 0.06 end
        end
    end
    local st = au > 0.45 and au < 1.0 and leafAt(x, y, 9, function() return 0.08 + sho * 0.3 end, s + 85, 1.8, 2.8,
        0.18, 0.26, strawPick)
    if st then return STRAW, h + 0.1, 0.35 + val * 0.4 end
    local gr = gravel(x, y, s, 1.6 - worn * 0.6)
    if gr then return STONE, h + 0.06, gr end
    local cr2 = vnoise(x, y, 40, 140, s + 113)
    if cr2 > 0.72 then val = val - (cr2 - 0.72) * 0.6 end
    return mat, h, val
end

PAINT.highlands = function(x, y, u, s)
    local mat, h, val, sho, rk, worn = trail(x, y, u, s, { rutW = 0.08 })
    local big, bv = stone(x, y, 24, 0.26, 2.8, 4.6, s + 67, function(uu) return abs(uu) < 0.95 end)
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

PAINT.abyss = function(x, y, u, s)
    local mat, h, val, sho, rk = trail(x, y, u, s, { rutW = 0.1, base = ASH })
    local drift = fbm(x, y, s + 3, 4, 40)
    val = val + (drift - 0.5) * 0.32
    local streak = vnoise(x, y, 3, 60, s + 5)
    if streak > 0.66 then val = val + (streak - 0.66) * 0.8 end
    local dj, id = voronoi(x, y, 22, 66, s + 23, 1.0)
    local open = vnoise(x, y, 9, 32, s + 25)
    local wid = 0.05 + vnoise(x, y, 14, 60, s + 27) * 0.07
    if dj < wid and open > 0.46 then
        local depth = 1 - dj / wid
        local hot = vnoise(x, y, 5, 22, s + 29)
        if hot > 0.62 and wid > 0.085 then
            return EMBER, 0.0, 0.1 + depth * 0.6 + (hot - 0.62) * 0.9
        end
        return SOOT, 0.05, 0.45 + (1 - depth) * 0.45
    end
    if dj < wid + 0.06 and open > 0.46 then val = val - 0.09 * (1 - (dj - wid) / 0.06) end
    local sh, sv = stone(x, y, 14, 0.2 * (1 - rk * 0.7), 1.3, 2.6, s + 71)
    if sh then
        if sv > 0.7 and h2(x, y, s + 73) < 0.08 then return EMBER, sh, 0.3 end
        return SOOT, sh, sv * 0.8 + 0.15
    end
    local tone = h2(id % 89, floor(id / 89), s + 7)
    val = val + (tone - 0.5) * 0.06
    local gr = gravel(x, y, s, 1.2)
    if gr then return SOOT, h + 0.05, gr + 0.2 end
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
    local val = 0.56 - worn * 0.22 + (n - 0.5) * 0.14 - rk * 0.2 + sstep(0.7, 1.0, au) * 0.18
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

local PLANKS
local function plankTable(s)
    if PLANKS and PLANKS.s == s then return PLANKS end
    local list, y = {}, 0
    local i = 0
    while y < TH do
        local w = 6 + floor(h2(i, 9, s) * 3)
        if TH - y < 11 then w = TH - y end
        list[#list + 1] = { y0 = y, w = w, i = i }
        y = y + w
        i = i + 1
    end
    local at = {}
    for k, p in ipairs(list) do for yy = p.y0, p.y0 + p.w - 1 do at[yy] = k end end
    PLANKS = { s = s, list = list, at = at }
    return PLANKS
end

PAINT.marsh = function(x, y, u, s)
    local PT = plankTable(s)
    local p = PT.list[PT.at[y]]
    local pk = p.i
    local yy = y - p.y0
    local PLW = p.w
    local au = abs(u)
    local endL = -(0.57 + (h2(pk, 1, s) - 0.5) * 0.1)
    local endR = 0.57 + (h2(pk, 12, s) - 0.5) * 0.1
    local shift = (h2(pk, 11, s) - 0.5) * 0.05
    endL, endR = endL + shift, endR + shift
    local missing = h2(pk, 3, s) < 0.06
    local broken = (not missing) and h2(pk, 4, s) < 0.12
    if broken then
        local bu = (h2(pk, 5, s) - 0.5) * 0.6
        local jag = (h2(pk, yy, s + 5) - 0.5) * 0.1
        if h2(pk, 6, s) > 0.5 then endR = min(endR, bu + 0.25 + jag) else endL = max(endL, bu - 0.25 + jag) end
    end
    local sag = (h2(pk, 7, s) < 0.15) and 1 or 0
    local rag = (h2(pk, yy, s + 31) - 0.5) * 2.2 / HALF
    endL, endR = endL + rag * (h2(pk, 32, s) > 0.4 and 1 or 0.3), endR - rag * (h2(pk, 33, s) > 0.4 and 1 or 0.3)
    local inPlank = yy < PLW - 1 and not missing and u > endL and u < endR
    if inPlank then
        local grain = vnoise(x, y, 5, TH * 0.9, s + 7 + pk) * 0.55 + vnoise(x, y, 24, TH * 0.5, s + 8) * 0.45
        local tone = h2(pk, 6, s + 1)
        tone = tone * tone * (3 - 2 * tone)
        local val = 0.34 + tone * 0.4 + (grain - 0.5) * 0.3 - sag * 0.12
        if yy == 0 then val = val + 0.14 end
        if yy == PLW - 2 then val = val - 0.2 end
        if yy > 0 and yy < PLW - 2 and vnoise(x, y, 3, TH * 0.9, s + 35 + yy) > 0.7
            and h2(pk, yy, s + 36) < 0.45 then val = val - 0.14 end
        local dE = min(u - endL, endR - u) * HALF
        if dE < 1.1 then val = val - 0.2 end
        local wet = vnoise(x, y, 4, 50, s + 15)
        if wet > 0.64 and yy <= 1 then val = val + 0.18 end
        if wet < 0.3 then val = val - 0.1 end
        if h2(pk, 15, s) < 0.2 and yy == floor(PLW * 0.5) and abs(u - (h2(pk, 16, s) - 0.5) * 0.6) < 0.12 then
            val = val - 0.24
        end
        local kn = h2(pk, 13, s)
        if kn < 0.3 then
            local ku = (h2(pk, 14, s) - 0.5) * 0.8
            local kx, ky = (u - ku) * HALF / 1.8, (yy - PLW * 0.45) / 1.1
            local r = kx * kx + ky * ky
            if r < 0.5 then return WOOD, 0.88, 0.1 end
            if r < 1.6 then val = val - 0.1 end
        end
        for sd = -1, 1, 2 do
            local nu = sd * 0.42 + shift
            if abs(u - nu) * HALF < 0.6 and (yy == 1 or yy == PLW - 3) then return GAP, 0.95, 0.0 end
            if abs(u - nu) * HALF < 0.6 and (yy == 2 or yy == PLW - 2) and h2(pk, 17 + sd, s) < 0.45 then
                return RUST, 0.9, 0.45
            end
        end
        local mo = vnoise(x, y, 14, 110, s + 19) * 0.75 + h2(x, y, s + 20) * 0.25
        if dE < 4 and mo > 0.72 - (4 - dE) * 0.015 then return MOSS, 0.92, 0.3 + (mo - 0.6) * 1.4 end
        return WOOD, 0.9 - sag * 0.1, val
    end
    local str = abs(au - 0.42) * HALF < 2.2
    if str and au < 0.62 then
        local val = 0.2 + vnoise(x, y, 30, 80, s + 21) * 0.14
        if yy == 0 then val = val - 0.08 end
        return WOOD, 0.55, val
    end
    local post = (pk % 6 == 2) and yy < PLW - 2 and abs(au - 0.68) * HALF < 2.4
    if post then
        local lu = (au - 0.68) * HALF * (u > 0 and 1 or -1) * LX
        local val = 0.42 + (lu > 0.6 and 0.16 or lu < -0.6 and -0.12 or 0) + (yy == 0 and 0.1 or 0)
        if (x + yy * 2) % 4 == 0 then val = val - 0.08 end
        return WOOD, 1.0, val
    end
    if au < 0.64 and not missing and yy == PLW - 1 then
        return WATER, 0.1, 0.1 + (h2(x, y, s) > 0.9 and 0.55 or 0)
    end
    local wet = vnoise(x, y, 5, 20, s + 17) + (missing and 0.25 or 0)
    if wet > 0.5 then
        local rip = (sin(y * 0.9 + vnoise(x, y, 8, 40, s + 24) * 6) > 0.92 and h2(x, y, s + 23) > 0.4) and 0.3 or 0
        local edgeW = (wet < 0.54) and -0.15 or 0
        return WATER, 0.0, 0.3 + (wet - 0.5) * 0.6 + rip + edgeW
    end
    return MUD, 0.2, 0.36 + (fbm(x, y, s + 23, 6, 26) - 0.5) * 0.3
end

PAINT.dusk = function(x, y, u, s)
    local mat, h, val, sho, rk, worn = trail(x, y, u, s, { rutW = 0.09 })
    local au = abs(u)
    local function dens(uu, yy)
        local rr = rutK(uu, yy, 0.13)
        local a = abs(uu)
        local clump = vnoise(uu * HALF + CU, yy, 5, 18, s + 66)
        return 0.27 + sstep(0.55, 0.95, a) * 0.36 + rr * 0.1 + (clump - 0.5) * 0.7
    end
    local m2, lv = leafAt(x, y, 8, dens, s + 61, 2.0, 3.0, 0.5, 0.66)
    if m2 then
        if worn > 0.75 and rk < 0.3 then return m2 == LEAF3 and LEAF4 or m2, h + 0.1, lv * 0.8 end
        return m2, h + 0.32, lv
    end
    local m3, lv3 = leafAt(x, y, 4, function(uu, yy) return (dens(uu, yy) - 0.3) * 1.6 end, s + 91, 1.3, 2.0,
        0.5, 0.7)
    if m3 then return m3, h + 0.18, lv3 * 0.82 end
    if dens(u, y) > 0.5 then val = val - 0.05 end
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

function V.bake(bid, pal, yieldEvery)
    local paint = PAINT[bid]
    if not paint then return nil end
    local P = palettes(bid, pal)
    local seed = 0
    for i = 1, #bid do seed = seed + bid:byte(i) end
    local lx = V.LIGHT_X[bid] or 1
    LX = lx
    memo, dmemo = {}, {}
    local M, Hh, Vv = {}, {}, {}
    for y = 0, TH - 1 do
        if yieldEvery and y % yieldEvery == yieldEvery - 1 then coroutine.yield() end
        for x = 0, TW - 1 do
            local u = (x + 0.5 - CU) / HALF
            local m, h, v = paint(x, y, u, seed)
            local i = y * TW + x
            M[i], Hh[i], Vv[i] = m, h, v
        end
    end
    memo, dmemo = {}, {}
    local d = love.image.newImageData(TW * 2, TH)
    local R, G, B = {}, {}, {}
    for y = 0, TH - 1 do
        if yieldEvery and y % yieldEvery == yieldEvery - 1 then coroutine.yield() end
        local yu = ((y + 1) % TH) * TW
        local yd = ((y - 1) % TH) * TW
        local y0 = y * TW
        for x = 0, TW - 1 do
            local i = y0 + x
            local m = M[i]
            local v = Vv[i]
            local h = Hh[i]
            local xl = (x + lx) % TW
            local xr = (x - lx) % TW
            local hToLight = Hh[yu + xl]
            local hAway = Hh[yd + xr]
            if m ~= EMBER then
                local h2l = Hh[((y + 2) % TH) * TW + (x + 2 * lx) % TW]
                if hToLight - h > 0.25 then v = v - 0.3 - (hToLight - h) * 0.2
                elseif h2l - h > 0.35 then v = v - 0.16 end
                local hl = Hh[yu + x]
                if hl - h > 0.3 then v = v - 0.1 end
                if h - hToLight > 0.25 then v = v + 0.16 end
                if h - hAway > 0.25 then v = v - 0.08 end
            end
            local pr = P[m] or P[DIRT]
            local n = #pr
            local lv = max(0, min(1, v)) * (n - 1) + 1
            local li = floor(lv)
            if lv - li > 0.5 + (h2(x, y, 977) - 0.5) * 0.22 + (bayer(x, y) - 0.5) * 0.12 then li = li + 1 end
            li = max(1, min(n, li))
            local c = pr[li]
            R[i], G[i], B[i] = c[1], c[2], c[3]
            d:setPixel(x, y, c[1], c[2], c[3], 1)
        end
    end
    local BX, BY = 3, (bid == "marsh") and 13 or 7
    for y = 0, TH - 1 do
        if yieldEvery and y % yieldEvery == yieldEvery - 1 then coroutine.yield() end
        for x = 0, TW - 1 do
            local r, g, b, cnt = 0, 0, 0, 0
            for dy = -BY, BY, 2 do
                local yy = ((y + dy) % TH) * TW
                for dx = -BX, BX do
                    local j = yy + (x + dx) % TW
                    r, g, b, cnt = r + R[j], g + G[j], b + B[j], cnt + 1
                end
            end
            r, g, b = r / cnt, g / cnt, b / cnt
            local i = y * TW + x
            local k = 0.22
            d:setPixel(TW + x, y, r + (R[i] - r) * k, g + (G[i] - g) * k, b + (B[i] - b) * k, 1)
        end
    end
    local img = love.graphics.newImage(d)
    img:setFilter("nearest", "nearest")
    img:setWrap("repeat", "repeat")
    return img
end

V.STYLE = {}

function V.style(bid)
    local st = V.STYLE[bid]
    if st then return st end
    st = { half = HALF, cu = CU, far = TW, vk = V.VK, tm0 = 0.98, tmK = 0.03, farT0 = 0.1, farT1 = 0.42 }
    if bid == "marsh" then st.platform, st.farT0, st.farT1 = true, 0.2, 0.4 end
    V.STYLE[bid] = st
    return st
end

return V
