local V = {}

local TW, TH = 192, 640
local CU, HALF = 96, 56
V.TW, V.TH, V.CU, V.HALF = TW, TH, CU, HALF
V.VK = 1.75

local floor, abs, min, max, sin, sqrt = math.floor, math.abs, math.min, math.max, math.sin, math.sqrt
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
    local d1, d2, id, cxx, cyy = 1e9, 1e9, 0, 0, 0
    for dj = -1, 1 do
        for di = -1, 1 do
            local i, j = ci + di, cj + dj
            local wi, wj = i % nx, j % ny
            local px = i + 0.5 + (h2(wi, wj, s) - 0.5) * jit
            local py = j + 0.5 + (h2(wi, wj, s + 3) - 0.5) * jit
            local dx, dy = px - gx, py - gy
            local d = sqrt(dx * dx + dy * dy)
            if d < d1 then
                d2 = d1; d1 = d; id = wi * 131 + wj; cxx, cyy = dx, dy
            elseif d < d2 then d2 = d end
        end
    end
    return d2 - d1, id, cxx, cyy
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

local DIRT, STONE, GAP, GRASS, MOSS, WOOD, WATER, SNOW, EMBER, ASH, LEAF, ICE, MUD, STRAW = 1, 2, 3, 4, 5, 6,
    7, 8, 9, 10, 11, 12, 13, 14

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
    P[DIRT] = ramp(mul(edge, 0.9), roadB, mul(roadA, 1.22), 6)
    P[MUD] = ramp(mul(edge, 0.85), mix(edge, roadB, 0.75), mul(roadA, 1.1), 5)
    P[STONE] = ramp(mix(mul(rockD, 0.7), edge, 0.35), mix(rock, roadA, 0.3), mix(mul(rock, 1.45), mul(roadA, 1.4), 0.25), 6)
    P[GAP] = { mul(edge, 0.55), mul(edge, 0.8), edge }
    P[GRASS] = ramp(mul(gB, 0.7), gA, mul(gA, 1.35), 4)
    P[MOSS] = ramp(mul(gB, 0.75), mix(gA, { 0.42, 0.46, 0.18 }, 0.35), mix(mul(gA, 1.3), { 0.6, 0.62, 0.25 }, 0.3), 4)
    P[WOOD] = ramp(mul(trunk, 0.55), mul(trunk, 1.25), mix(mul(trunk, 1.9), { 0.6, 0.5, 0.36 }, 0.3), 5)
    P[WATER] = ramp(mix(skyT, edge, 0.5), mix(sky, skyT, 0.45), mul(sky, 1.25), 4)
    P[SNOW] = ramp(mix(gB, { 0.36, 0.42, 0.56 }, 0.5), gA, { 0.93, 0.95, 1.0 }, 5)
    P[ICE] = ramp(mix(sky, { 0.3, 0.38, 0.5 }, 0.5), mix(sky, { 0.75, 0.85, 0.95 }, 0.5), { 0.9, 0.96, 1.0 }, 4)
    P[EMBER] = { { 0.32, 0.08, 0.04 }, { 0.72, 0.22, 0.06 }, { 1.0, 0.48, 0.14 }, { 1.0, 0.78, 0.36 } }
    P[ASH] = ramp(mul(edge, 0.8), mix(roadB, { 0.3, 0.29, 0.3 }, 0.6), mix(roadA, { 0.6, 0.58, 0.56 }, 0.6), 5)
    if bid == "fields" then
        P[LEAF] = { { 0.42, 0.33, 0.14 }, { 0.62, 0.5, 0.22 }, { 0.8, 0.68, 0.34 } }
    elseif bid == "marsh" then
        P[LEAF] = { { 0.22, 0.24, 0.1 }, { 0.36, 0.38, 0.16 }, { 0.5, 0.5, 0.22 } }
    elseif bid == "highlands" then
        P[LEAF] = { { 0.38, 0.22, 0.12 }, { 0.56, 0.34, 0.16 }, { 0.72, 0.5, 0.22 } }
    else
        P[LEAF] = { { 0.46, 0.16, 0.1 }, { 0.7, 0.32, 0.14 }, { 0.86, 0.54, 0.2 } }
    end
    P[STRAW] = { { 0.48, 0.38, 0.16 }, { 0.7, 0.58, 0.28 }, { 0.86, 0.76, 0.42 } }
    return P
end

function V.rutU(y, sd)
    local k = y / TH
    return sd * (0.40 + 0.045 * sin(k * TAU * 3 + (sd > 0 and 1.3 or 4.1)) + 0.02 * sin(k * TAU * 7 + sd))
end

local function rutK(u, y, w)
    w = w or 0.085
    local best = 0
    for sd = -1, 1, 2 do
        local d = abs(u - V.rutU(y, sd)) / w
        if d < 1 then best = max(best, 1 - d * d) end
    end
    return best
end

local PEB_LX = 1

local function pebble(x, y, cell, dens, rmin, rmax, s, accept)
    local ci, cj = floor(x / cell), floor(y / cell)
    local ncx, ncy = TW / cell, floor(TH / cell)
    local best, hh, sh = nil, 0, 0
    for dj = -1, 1 do
        for di = -1, 1 do
            local i, j = ci + di, cj + dj
            local wi, wj = i % ncx, j % ncy
            if h2(wi, wj, s) < dens then
                local px = (i + 0.2 + h2(wi, wj, s + 1) * 0.6) * cell
                local py = (j + 0.2 + h2(wi, wj, s + 2) * 0.6) * cell
                local u = ((px % TW) - CU) / HALF
                if not accept or accept(u, py % TH) then
                    local r = rmin + h2(wi, wj, s + 3) * (rmax - rmin)
                    local dx, dy = (x - px) / r, (y - py) / (r * 1.25)
                    local d = dx * dx + dy * dy + (h2(x, y, s + 8) - 0.5) * 0.35
                    if d < 1 and (not best or d < best) then
                        best = d
                        hh = 1 - d * 0.5
                        sh = h2(wi, wj, s + 4) + (dx * PEB_LX + dy) * 0.28
                    end
                end
            end
        end
    end
    return best and hh, sh
end

local function blob(x, y, cell, dens, r, s, accept)
    local ci, cj = floor(x / cell), floor(y / cell)
    local ncx, ncy = TW / cell, floor(TH / cell)
    for dj = -1, 1 do
        for di = -1, 1 do
            local i, j = ci + di, cj + dj
            local wi, wj = i % ncx, j % ncy
            if h2(wi, wj, s) < dens then
                local px = (i + h2(wi, wj, s + 1)) * cell
                local py = (j + h2(wi, wj, s + 2)) * cell
                local u = ((px % TW) - CU) / HALF
                if not accept or accept(u, py % TH) then
                    local rr = r * (0.6 + h2(wi, wj, s + 3) * 0.8)
                    local dx, dy = (x - px) / rr, (y - py) / (rr * 1.3)
                    if dx * dx + dy * dy + (h2(x, y, s + 9) - 0.5) * 0.5 < 1 then
                        return h2(wi, wj, s + 5)
                    end
                end
            end
        end
    end
    return nil
end

local function trail(x, y, u, s, o)
    local au = abs(u)
    local n = fbm(x, y, s, 6, 26)
    local fine = h2(x, y, s + 21)
    local worn = 1 - sstep(0.12, 0.6, au)
    local sho = sstep(0.62, 1.05, au)
    local rk = rutK(u, y, o.rutW)
    local rutGap = vnoise(x, y, 2, 14, s + 33)
    if rutGap < 0.28 then rk = rk * rutGap / 0.28 end
    local val = 0.56 + (n - 0.5) * (0.30 - worn * 0.16) + worn * 0.14 - sho * 0.16 + (fine - 0.5) * 0.07
    local h = 0.3 + n * 0.12 - rk * 0.55 * (o.rutDepth or 1)
    val = val - rk * 0.36
    local mat = o.base or DIRT
    if o.wetRuts and rk > 0.55 and rutGap > 0.45 then mat = o.wetRuts; h = 0.0 end
    return mat, h, val, sho, rk, worn
end

local function shoulderGrass(x, y, sho, s, dens)
    if sho <= 0 then return nil end
    local b = blob(x, y, 6, dens * sho * 0.45, 1.8, s + 51)
    if b then return 0.25 + b * 0.4 end
    if h2(x, y, s + 57) < sho * 0.04 then return 0.45 end
    return nil
end

local PAINT = {}

PAINT.fields = {
    A = function(x, y, u, s)
        local mat, h, val, sho, rk = trail(x, y, u, s, { rutW = 0.09 })
        local g = shoulderGrass(x, y, sho, s, 0.5)
        if g then return GRASS, 0.45, g end
        local ph, sh = pebble(x, y, 8, 0.22 * (1 - rk * 0.8), 0.8, 1.7, s + 71)
        if ph then return STONE, 0.55 + ph * 0.6, 0.35 + sh * 0.35 end
        if h2(x, y, s + 81) < 0.025 then return DIRT, h, val - 0.22 end
        return mat, h, val
    end,
    B = function(x, y, u, s)
        local au = abs(u)
        local n = fbm(x, y, s, 5, 18)
        local crown = 1 - au * au
        local val = 0.44 + (n - 0.5) * 0.16 + crown * 0.12 + (h2(x, y, s + 3) - 0.5) * 0.05
        local h = 0.3 + crown * 0.1
        if au > 0.78 and au < 0.9 then val = val - 0.14 * sstep(0.78, 0.84, au) end
        local tr = (y % 9 == 0) and vnoise(x, y, 3, 50, s + 5) > 0.62
        if tr and au < 0.7 then val = val - 0.06 end
        local ph, sh = pebble(x, y, 11, 0.16, 1.0, 1.8, s + 73)
        if ph then return STONE, 0.42 + ph * 0.4, 0.34 + sh * 0.3 end
        local fl, fsh = pebble(x, y, 23, 0.22, 3.0, 4.6, s + 79, function(uu) return abs(uu) < 0.6 end)
        if fl then return STONE, 0.36 + fl * 0.15, 0.32 + fsh * 0.22 end
        return DIRT, h, val
    end,
    C = function(x, y, u, s)
        local mat, h, val, sho, rk = trail(x, y, u, s, { rutW = 0.1, rutDepth = 1.2, wetRuts = MUD })
        if mat == MUD then return MUD, 0.0, 0.5 + (h2(x, y, s) - 0.5) * 0.1 end
        local g = shoulderGrass(x, y, sho, s, 0.55)
        if g then return GRASS, 0.45, g end
        local ph, sh = pebble(x, y, 9, 0.2 * (1 - rk), 0.8, 1.7, s + 71)
        if ph then return STONE, 0.55 + ph * 0.6, 0.35 + sh * 0.35 end
        local st = blob(x, y, 9, 0.18, 1.6, s + 91, function(uu) return abs(uu) < 0.8 end)
        if st and h2(x, y, s + 93) > 0.35 then return STRAW, h + 0.05, 0.3 + st * 0.6 end
        return mat, h, val
    end,
}

PAINT.highlands = {
    A = function(x, y, u, s)
        local mat, h, val, sho, rk = trail(x, y, u, s, { rutW = 0.08 })
        local g = shoulderGrass(x, y, sho, s, 0.42)
        if g then return GRASS, 0.45, g end
        local dens = 0.3 * (1 - rk * 0.85)
        local ph, sh = pebble(x, y, 5, dens, 0.7, 1.4, s + 61)
        if ph then return STONE, 0.5 + ph * 0.4, 0.3 + sh * 0.4 end
        if h2(x, y, s + 63) < 0.08 * (1 - rk) then val = val + 0.14 end
        local big, bsh = pebble(x, y, 17, 0.3, 2.4, 3.8, s + 67)
        if big then return STONE, 0.6 + big * 0.8, 0.36 + bsh * 0.25 end
        return mat, h, val - 0.04
    end,
    B = function(x, y, u, s, wet)
        local dj, id, cx, cy = voronoi(x, y, 9, 26, s + 11, 0.85)
        local small, sid, scx, scy = voronoi(x, y, 18, 52, s + 19, 0.8)
        local useSmall = h2(id % 97, floor(id / 97), s + 5) < 0.35
        if useSmall then dj, id, cx, cy = small, sid + 7919, scx, scy end
        local tone = h2(id % 89, floor(id / 89), s + 7)
        local missing = tone < 0.07
        local gapW = useSmall and 0.1 or 0.07
        if dj < gapW or missing then
            local j = (h2(x, y, s + 31) > 0.5 and vnoise(x, y, 8, 30, s + 37) > 0.45)
            if wet and vnoise(x, y, 6, 22, s + 39) > 0.6 then return WATER, 0.0, 0.4 + h2(x, y, s) * 0.2 end
            if j and not missing then return MOSS, 0.1, 0.3 + h2(x, y, s + 41) * 0.4 end
            if missing then return DIRT, 0.1, 0.42 + (h2(x, y, s + 33) - 0.5) * 0.2 end
            return GAP, 0.0, 0.4
        end
        local val = 0.32 + tone * 0.32 + (fbm(x, y, s + 43, 12, 40) - 0.5) * 0.18
        local ldot = (cx * -1 + cy * -1)
        if dj < gapW + 0.09 then val = val + ldot * 0.55 end
        if h2(x, y, s + 47) < 0.03 then val = val - 0.25 end
        if wet then
            val = val - 0.08
            if dj < gapW + 0.05 and ldot > 0.15 and h2(x, y, s + 49) > 0.4 then return WATER, 0.5, 0.9 end
        end
        return STONE, 0.6 + tone * 0.15, val
    end,
    C = function(x, y, u, s)
        local m, h, v = PAINT.highlands.B(x, y, u, s, true)
        if m ~= WATER and m ~= GAP then
            local lf = blob(x, y, 9, 0.2, 1.3, s + 95)
            if lf then return LEAF, h + 0.05, 0.2 + lf * 0.7 end
        end
        return m, h, v
    end,
}

PAINT.abyss = {
    A = function(x, y, u, s)
        local mat, h, val, sho, rk = trail(x, y, u, s, { rutW = 0.1, base = ASH })
        local drift = vnoise(x, y, 5, 30, s + 3)
        val = val + (drift - 0.5) * 0.3
        local dj = voronoi(x, y, 12, 38, s + 23, 0.95)
        if dj < 0.035 then
            if vnoise(x, y, 4, 20, s + 29) > 0.62 then return EMBER, 0.0, 0.35 + h2(x, y, s) * 0.5 end
            return GAP, 0.0, 0.3
        end
        local ph, sh = pebble(x, y, 8, 0.3, 1.0, 2.2, s + 71)
        if ph then return STONE, 0.55 + ph * 0.5, 0.25 + sh * 0.3 end
        if h2(x, y, s + 83) < 0.008 then return EMBER, 0.2, 0.9 end
        return ASH, h, val
    end,
    B = function(x, y, u, s)
        local yr = floor(y / TH * 22)
        local xs = x + ((yr % 2) * 0.5) * (TW / 8)
        local dj, id, cx, cy = voronoi(xs % TW, y, 8, 22, s + 11, 0.62)
        local tone = h2(id % 83, floor(id / 83), s + 7)
        local glow = h2(id % 71, floor(id / 71), s + 9) > 0.62
        if dj < 0.085 then
            local gn = vnoise(x, y, 6, 24, s + 13)
            if glow and gn > 0.42 then
                return EMBER, 0.0, 0.15 + (1 - dj / 0.085) * 0.45 + (gn - 0.42) * 0.6
            end
            return GAP, 0.0, 0.25
        end
        local val = 0.26 + tone * 0.22 + (fbm(x, y, s + 43, 10, 34) - 0.5) * 0.14
        local ldot = (cx * -1 + cy * -1)
        if dj < 0.17 then val = val + ldot * 0.5 end
        local cr = voronoi(x, y, 30, 90, s + 17, 1.0)
        if cr < 0.03 and tone > 0.45 then val = val - 0.2 end
        if h2(x, y, s + 47) < 0.02 then val = val + 0.2 end
        return STONE, 0.6, val
    end,
    C = function(x, y, u, s)
        local m, h, v = PAINT.abyss.B(x, y, u, s)
        if m == STONE then
            local a = vnoise(x, y, 7, 40, s + 101)
            if a > 0.62 then return ASH, h + 0.02, 0.45 + (a - 0.62) * 1.2 + (h2(x, y, s) - 0.5) * 0.1 end
        end
        return m, h, v
    end,
}

PAINT.frost = {
    A = function(x, y, u, s)
        local au = abs(u)
        local n = fbm(x, y, s, 6, 24)
        local worn = 1 - sstep(0.15, 0.7, au)
        local rk = rutK(u, y, 0.1)
        local val = 0.47 - worn * 0.2 + (n - 0.5) * 0.2 - rk * 0.2 + sstep(0.7, 1.0, au) * 0.12
        local h = 0.4 - rk * 0.4
        local bp = (y % 14 < 4) and blob(x, y, 7, 0.4 * worn, 1.4, s + 41)
        if bp then val = val - 0.2; h = 0.1 end
        local sl = fbm(x, y, s + 45, 10, 40)
        if sl > 0.6 then val = val - (sl - 0.6) * 0.9 * worn end
        if h2(x, y, s + 47) < 0.012 * (1 - worn) then val = 1.0 end
        return SNOW, h, val
    end,
    B = function(x, y, u, s)
        local n = fbm(x, y, s, 5, 18)
        local val = 0.36 + (n - 0.5) * 0.14 + (h2(x, y, s + 1) - 0.5) * 0.03 + sstep(0.7, 1.0, abs(u)) * 0.12
        local h = 0.4
        for sd = -1, 1, 2 do
            local ru = sd * (0.17 + 0.012 * sin(y / TH * TAU * 2 + sd))
            local d = abs(u - ru) * HALF
            if d < 0.9 then val = val - 0.34; h = 0.15 elseif d < 1.8 then val = val + 0.12 end
        end
        local hoof = (y % 11 < 3) and blob(x, y, 6, 0.55, 1.2, s + 43,
            function(uu) return abs(uu) < 0.12 end)
        if hoof then val = val - 0.22; h = 0.15 end
        local boot = (y % 13 < 3) and blob(x, y, 6, 0.35, 1.0, s + 49,
            function(uu) return abs(uu) > 0.4 and abs(uu) < 0.7 end)
        if boot then val = val - 0.18; h = 0.15 end
        local st, ssh = pebble(x, y, 19, 0.3, 2.0, 3.4, s + 61)
        if st then
            if st > 0.82 then return SNOW, 0.9, 0.86 end
            return STONE, 0.6 + st * 0.6, 0.22 + ssh * 0.25
        end
        return SNOW, h, val
    end,
    C = function(x, y, u, s)
        local m, h, v = PAINT.frost.A(x, y, u, s)
        local ic = vnoise(x, y, 14, 60, s + 77) * 0.7 + vnoise(x, y, 28, 120, s + 78) * 0.3
        if ic > 0.68 and abs(u) < 0.6 then
            local k = (ic - 0.68) / 0.32
            if h2(x, y, s + 79) < 0.06 then return ICE, 0.3, 1.0 end
            return ICE, 0.3, 0.5 + k * 0.4 + ((x + y) % 7 == 0 and 0.3 or 0)
        end
        return m, h, v
    end,
}

PAINT.marsh = {
    A = function(x, y, u, s)
        local mat, h, val, sho, rk = trail(x, y, u, s, { rutW = 0.11, rutDepth = 1.3, base = MUD, wetRuts = WATER })
        val = val + 0.1
        if mat == WATER then return WATER, 0.0, 0.35 + (h2(x, y, s) > 0.9 and 0.4 or 0) end
        local hump = vnoise(x, y, 6, 26, s + 5)
        if hump > 0.62 then return DIRT, h + 0.15, 0.3 + (hump - 0.62) * 0.9 end
        local root = abs(vnoise(x, y, 3, 30, s + 9) - 0.5) < 0.018 and vnoise(x, y, 2, 10, s + 11) > 0.55
        if root then return WOOD, 0.6, 0.35 end
        local g = shoulderGrass(x, y, sho, s, 0.6)
        if g then return GRASS, 0.45, g end
        return MUD, h, val
    end,
    B = function(x, y, u, s)
        local PL = 7
        local pi = floor(y / PL)
        local pk = pi % floor(TH / PL)
        local inPlank = (y % PL) ~= 0
        local plankHalf = 0.58 + (h2(pk, 1, s) - 0.5) * 0.12
        local skew = (h2(pk, 2, s) - 0.5) * 0.06
        local missing = h2(pk, 3, s) < 0.09
        local broken = h2(pk, 4, s) < 0.12
        local uu = u + skew * ((y % PL) / PL - 0.5)
        local sideCut = broken and ((h2(pk, 5, s) > 0.5) and uu > 0.1 or uu < -0.1)
        if not missing and not sideCut and abs(uu) < plankHalf and inPlank then
            local grain = vnoise(x, y, 40, TH / 2.5, s + 7)
            local tone = h2(pk, 6, s)
            local val = 0.32 + tone * 0.26 + (grain - 0.5) * 0.18
            local yy = y % PL
            if yy == PL - 1 then val = val + 0.18 end
            if yy == 1 then val = val - 0.12 end
            local nailU = plankHalf - 0.09
            if (yy == 3) and (abs(uu - nailU) * HALF < 0.8 or abs(uu + nailU) * HALF < 0.8) then
                return GAP, 0.9, 0.2
            end
            if abs(uu) > plankHalf - 0.05 then val = val - 0.1 end
            if h2(x, y, s + 13) < 0.02 then return MOSS, 0.9, 0.5 end
            return WOOD, 0.9, val
        end
        if abs(u) < 0.66 and not missing and not sideCut and (y % PL) == 0 then
            return GAP, 0.3, 0.2
        end
        local wet = vnoise(x, y, 5, 20, s + 17)
        if wet > 0.48 then return WATER, 0.0, 0.3 + (wet - 0.48) * 0.8 + (h2(x, y, s) > 0.93 and 0.3 or 0) end
        local au = abs(u)
        local g = shoulderGrass(x, y, sstep(0.66, 1.0, au), s, 0.6)
        if g then return GRASS, 0.45, g end
        return MUD, 0.2, 0.36 + (fbm(x, y, s + 23, 6, 26) - 0.5) * 0.3
    end,
    C = function(x, y, u, s)
        local m, h, v = PAINT.marsh.A(x, y, u, s)
        if m == MUD then
            local p = vnoise(x, y, 4, 16, s + 107)
            if p > 0.68 and abs(u) < 0.7 then return WATER, 0.0, 0.35 + (p - 0.68) * 1.4 end
            if p > 0.63 and abs(u) < 0.72 then return MUD, 0.05, 0.12 end
        end
        return m, h, v
    end,
}

PAINT.dusk = {
    A = function(x, y, u, s)
        local mat, h, val, sho, rk = trail(x, y, u, s, { rutW = 0.09 })
        local g = shoulderGrass(x, y, sho, s, 0.35)
        if g then return GRASS, 0.45, g end
        local dens = 0.25 + sho * 0.4 + (1 - rk) * 0.15
        local lf = blob(x, y, 5, dens, 1.15, s + 61)
        if lf then return LEAF, h + 0.1, 0.15 + lf * 0.8 end
        local ph, sh = pebble(x, y, 9, 0.2, 1.0, 2.0, s + 71)
        if ph then return STONE, 0.5 + ph * 0.5, 0.35 + sh * 0.3 end
        return mat, h, val
    end,
    B = function(x, y, u, s, wet)
        local RH = 10
        local row = floor(y / RH)
        local off = (row % 2) * 0.5 + h2(row, 1, s) * 0.3
        local len = 0.36 + h2(row, 2, s) * 0.12
        local cu = (u + 1.2) / len + off
        local ci = floor(cu)
        local fu = cu - ci
        local id = row * 61 + ci
        local tone = h2(id, 3, s)
        local missing = tone < 0.1
        local yy = y % RH
        local edgeU = min(fu, 1 - fu) * len * HALF
        local gapX = edgeU < 1.0
        local gapY = yy == 0
        local au = abs(u)
        if au > 0.92 then
            return GRASS, 0.4, 0.3 + h2(x, y, s + 5) * 0.4
        end
        if missing or gapX or gapY then
            local mossK = 0.35 + sstep(0.4, 0.9, au) * 0.5
            if wet and missing and vnoise(x, y, 6, 30, s + 9) > 0.3 then
                return WATER, 0.0, 0.35 + (h2(x, y, s) > 0.9 and 0.35 or 0)
            end
            if h2(x, y, s + 7) < mossK then return MOSS, 0.15, 0.25 + h2(x, y, s + 8) * 0.5 end
            return GAP, 0.0, missing and 0.8 or 0.4
        end
        local worn = 1 - sstep(0.1, 0.55, au)
        local val = 0.3 + tone * 0.3 + worn * 0.08 + (fbm(x, y, s + 13, 12, 50) - 0.5) * 0.16
        local lx = -1
        if yy == RH - 1 then val = val + 0.16 end
        if yy == 1 then val = val - 0.1 end
        if edgeU < 2.0 then val = val + ((fu > 0.5) == (lx > 0) and 0.12 or -0.1) end
        local cr = tone > 0.82 and abs(vnoise(x, y, 30, 80, s + 17) - 0.5) < 0.03
        if cr then return GAP, 0.3, 0.3 end
        if h2(x, y, s + 19) < 0.03 * (1 + au) then return MOSS, 0.6, 0.5 end
        return STONE, 0.6, val
    end,
    C = function(x, y, u, s)
        local m, h, v = PAINT.dusk.B(x, y, u, s, true)
        if m == STONE or m == GAP then
            local lf = blob(x, y, 7, 0.16, 1.2, s + 95)
            if lf then return LEAF, h + 0.05, 0.15 + lf * 0.8 end
        end
        return m, h, v
    end,
}

V.LIGHT_X = { fields = 1, highlands = 1, abyss = 1, frost = 1, marsh = 1, dusk = -1 }

function V.bake(bid, vid, pal, yieldEvery)
    local paint = PAINT[bid] and PAINT[bid][vid]
    if not paint then return nil end
    local P = palettes(bid, pal)
    local seed = 0
    for i = 1, #bid do seed = seed + bid:byte(i) end
    seed = seed + (vid == "A" and 0 or vid == "B" and 300 or 600)
    local lx = V.LIGHT_X[bid] or 1
    PEB_LX = lx
    local N = TW * TH
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
            elseif h2l - h > 0.35 then v = v - 0.18 end
                local hl = Hh[yu + x]
                if hl - h > 0.3 then v = v - 0.1 end
                if h - hToLight > 0.25 then v = v + 0.2 end
                if h - hAway > 0.25 then v = v - 0.1 end
            end
            local pr = P[m] or P[DIRT]
            local n = #pr
            local lv = max(0, min(1, v)) * (n - 1) + 1
            local li = floor(lv)
            if lv - li > 0.5 + (h2(x, y, 977) - 0.5) * 0.55 + (bayer(x, y) - 0.5) * 0.15 then li = li + 1 end
            li = max(1, min(n, li))
            local c = pr[li]
            R[i], G[i], B[i] = c[1], c[2], c[3]
            d:setPixel(x, y, c[1], c[2], c[3], 1)
        end
    end
    local BX, BY = 3, 7
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

V.STYLE = {
    base = { half = HALF, cu = CU, far = TW, vk = V.VK, tm0 = 0.98, tmK = 0.03, noRowDeco = true },
}

function V.style(bid, vid)
    local st = V.STYLE[bid .. vid]
    if st then return st end
    local b = V.STYLE.base
    st = {}
    for k, v in pairs(b) do st[k] = v end
    if bid == "fields" and vid == "B" then st.edging = true end
    if bid == "marsh" and vid == "B" then st.edgeLine = 0.35 end
    V.STYLE[bid .. vid] = st
    return st
end

return V
