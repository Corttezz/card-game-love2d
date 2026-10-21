local Debug = require("src.core.Debug")

local GrassField = {}
local QuadMesh = require("engine.QuadMesh")

GrassField.PRESETS = {
    fields    = { density = 1.00, heightK = 1.00, windAmp = 0.72,
                  gustAmp = 1.50, gustSpeed = 1.50, dir = 1,
                  broad = 0.10, flower = 0.10 },
    highlands = { density = 0.80, heightK = 0.90, windAmp = 1.00,
                  gustAmp = 1.85, gustSpeed = 2.05, dir = -1,
                  broad = 0.08, flower = 0.06 },
    abyss     = { density = 0.55, heightK = 0.80, windAmp = 0.44,
                  gustAmp = 0.82, gustSpeed = 1.05, dir = 1,
                  broad = 0.05, flower = 0.08 },
    frost     = { density = 0.30, heightK = 0.60, windAmp = 0.86, carpet = 0.40, dry = 0,
                  gustAmp = 1.60, gustSpeed = 1.85, dir = -1,
                  broad = 0.06, flower = 0.05 },
    marsh     = { density = 1.15, heightK = 1.30, windAmp = 0.64,
                  gustAmp = 1.15, gustSpeed = 1.15, dir = 1,
                  broad = 0.30, flower = 0.09 },
    dusk      = { density = 0.90, heightK = 1.05, windAmp = 0.80,
                  gustAmp = 1.35, gustSpeed = 1.30, dir = -1,
                  broad = 0.12, flower = 0.12 },
}
local DEFAULT_PRESET = GrassField.PRESETS.fields

local CELL_W, CELL_H = 8, 16
local N_THIN, N_BROAD = 6, 2
local FLOWER_CELL = N_THIN + N_BROAD
local N_CLUMP = 6
local CLUMP_W = 16
local N_FILLQ = 3
local atlasImg, quads, clumpQuads, fillQuads

local function bakeAtlas()
    if atlasImg then return end
    local n = N_THIN + N_BROAD + 1
    local atlasW = CELL_W * n + CLUMP_W * (N_CLUMP + N_FILLQ)
    local id = love.image.newImageData(atlasW, CELL_H)
    local function put(cell, x, y, lum)
        if x >= 0 and x < CELL_W and y >= 0 and y < CELL_H then
            id:setPixel(cell * CELL_W + x, y, lum, lum, lum, 1)
        end
    end
    for v = 0, N_THIN - 1 do
        local rng = love.math.newRandomGenerator(1000 + v * 37)
        local len = 9 + rng:random(0, 5)
        local curve = (rng:random() * 2 - 1) * 3.4
        for i = 0, len - 1 do
            local fy = i / (len - 1)
            local y = (CELL_H - 1) - i
            local x = math.floor(3.5 + curve * fy * fy + 0.5)
            local lum = 0.45 + 0.15 * math.min(1, fy * 3)
            if fy > 0.78 then lum = 1.0 end
            put(v, x, y, lum)
            if fy < 0.45 then put(v, x + 1, y, lum) end
        end
    end
    for b = 0, N_BROAD - 1 do
        local v = N_THIN + b
        local rng = love.math.newRandomGenerator(2000 + b * 53)
        local len = 12 + rng:random(0, 3)
        local curve = (b == 0 and 1 or -1) * (2.2 + rng:random() * 1.4)
        for i = 0, len - 1 do
            local fy = i / (len - 1)
            local y = (CELL_H - 1) - i
            local x = math.floor(3 + curve * fy * fy + 0.5)
            local wdt = fy < 0.35 and 3 or (fy < 0.7 and 2 or 1)
            local lum = 0.42 + 0.16 * math.min(1, fy * 2.5)
            if fy > 0.82 then lum = 1.0 end
            for dx = 0, wdt - 1 do put(v, x + dx, y, lum) end
        end
    end
    do
        local v = FLOWER_CELL
        for i = 0, 8 do put(v, 3, (CELL_H - 1) - i, 0.55) end
        for dy = -1, 1 do
            for dx = -1, 1 do
                local lum = (dx == 0 and dy == 0) and 1.0 or 0.82
                put(v, 3 + dx, (CELL_H - 10) + dy, lum)
            end
        end
    end
    local clumpX0 = CELL_W * n
    for cv = 0, N_CLUMP - 1 do
        local rng = love.math.newRandomGenerator(3000 + cv * 71)
        local xo = clumpX0 + cv * CLUMP_W
        for x = 0, CLUMP_W - 1 do
            for y = CELL_H - 2, CELL_H - 1 do
                if rng:random() < 0.88 then
                    local lum = 0.34 + rng:random() * 0.14
                    id:setPixel(xo + x, y, lum, lum, lum, 1)
                end
            end
        end
        for _ = 1, 8 + rng:random(0, 2) do
            local bx = rng:random(1, CLUMP_W - 2)
            local len = 6 + rng:random(0, 8)
            local curve = (rng:random() * 2 - 1) * 3.0
            local bright = 0.72 + rng:random() * 0.38
            for i = 0, len - 1 do
                local fy = i / math.max(1, len - 1)
                local y = (CELL_H - 1) - i
                local x = math.floor(bx + curve * fy * fy + 0.5)
                if x >= 0 and x < CLUMP_W and y >= 0 then
                    local lum = (0.44 + 0.16 * math.min(1, fy * 2.5)) * bright
                    if fy > 0.8 then lum = 0.95 * bright end
                    id:setPixel(xo + x, y, math.min(1, lum), math.min(1, lum),
                        math.min(1, lum), 1)
                end
            end
        end
    end
    local fillX0 = clumpX0 + CLUMP_W * N_CLUMP
    for fv = 0, N_FILLQ - 1 do
        local rng = love.math.newRandomGenerator(4000 + fv * 89)
        local xo = fillX0 + fv * CLUMP_W
        for _ = 1, 24 + rng:random(0, 6) do
            local bx = rng:random(0, CLUMP_W - 1)
            local len = 3 + rng:random(0, 6)
            local lean = (rng:random() * 2 - 1) * 1.6
            local bright = 0.62 + rng:random() * 0.38
            for i = 0, len - 1 do
                local fy = i / math.max(1, len - 1)
                local x = math.floor(bx + lean * fy * fy + 0.5)
                local y = (CELL_H - 1) - i
                if x >= 0 and x < CLUMP_W then
                    local lum = (0.52 + 0.30 * fy) * bright
                    id:setPixel(xo + x, y, math.min(1, lum), math.min(1, lum), math.min(1, lum), 1)
                end
            end
        end
    end
    atlasImg = love.graphics.newImage(id)
    atlasImg:setFilter("nearest", "nearest")
    quads = {}
    for i = 0, n - 1 do
        quads[i] = { (i * CELL_W) / atlasW, 0, (i * CELL_W + CELL_W) / atlasW, 1 }
    end
    fillQuads = {}
    for i = 0, N_FILLQ - 1 do
        local x0 = clumpX0 + (N_CLUMP + i) * CLUMP_W
        fillQuads[i] = { x0 / atlasW, 0, (x0 + CLUMP_W) / atlasW, 1 }
    end
    clumpQuads = {}
    for i = 0, N_CLUMP - 1 do
        local x0 = clumpX0 + i * CLUMP_W
        clumpQuads[i] = { x0 / atlasW, 0, (x0 + CLUMP_W) / atlasW, 1 }
    end
end

local ffi = require("ffi")
pcall(ffi.cdef, [[
typedef struct {
    float x, y, u, v;
    uint8_t r, g, b, a;
    float ax, ay, kind;
    float w1, w2, w3, w4;
} gf_vertex_t;
]])
local GF_FORMAT = {
    { "VertexPosition", "float", 2 },
    { "VertexTexCoord", "float", 2 },
    { "VertexColor", "byte", 4 },
    { "GrassArm", "float", 3 },
    { "GrassWind", "float", 4 },
}
local K_CLUMP, K_CREST, K_BLADE, K_BROAD, K_FLOWER = 0, 1, 2, 3, 4
GrassField.CELL_H = CELL_H
local tufts, tuftN = {}, 0
local clears, clearN = {}, 0
function GrassField.beginFrame() tuftN = 0; clearN = 0 end
function GrassField.requireClearing(relLo, relHi, x, halfW, rim)
    if relLo ~= relLo or x ~= x or not halfW or halfW < 2 or relHi <= relLo then return end
    clearN = clearN + 1
    local c = clears[clearN]
    if not c then c = {}; clears[clearN] = c end
    c.relLo, c.relHi, c.x, c.halfW, c.rim = relLo, relHi, x, halfW, rim or 0.22
end
function GrassField._clearings() return clears, clearN end
function GrassField.requireTufts(rel, x, w, n, scale)
    if rel ~= rel or x ~= x then return end
    tuftN = tuftN + 1
    local q = tufts[tuftN]
    if not q then q = {}; tufts[tuftN] = q end
    q.rel, q.x, q.w = rel, x, math.max(2, w or 2)
    q.n, q.s, q.done = math.max(1, math.floor(n or 3)), math.max(0.02, scale or 1), false
end
function GrassField._tuftRequests() return tufts, tuftN end
local function clearHash(a, b)
    local n = math.sin(a * 12.9898 + b * 78.233) * 43758.5453
    return n - math.floor(n)
end
local function cleared(px, rel)
    for i = 1, clearN do
        local c = clears[i]
        if rel > c.relLo and rel < c.relHi then
            local u = (rel - c.relLo) / (c.relHi - c.relLo)
            local e = 1 - (1 - u) * (1 - u)
            local hw = c.halfW * math.sqrt(math.max(0, e))
            local rag = 1 - c.rim * clearHash(math.floor(px / 3), math.floor(rel * 24))
            if math.abs(px - c.x) < hw * rag then return true end
        end
    end
    return false
end
GrassField._cleared = cleared
local function tuftSig(relFrom, relTo)
    local sig = 0
    for i = 1, clearN do
        local c = clears[i]
        if c.relLo < relTo and c.relHi > relFrom then
            sig = sig + math.floor(c.x) * 5 + math.floor(c.halfW) * 11 + math.floor(c.relLo * 100) * 17
        end
    end
    for i = 1, tuftN do
        local q = tufts[i]
        if q.rel > relFrom and q.rel <= relTo then
            sig = sig + math.floor(q.x) * 7 + math.floor(q.w) + q.n * 13 + math.floor(q.s * 100) * 3
        end
    end
    return sig
end

GrassField.SHADER_VERTEX = [[
uniform float uT;      // relógio do mundo (ctx.time)
uniform vec4 uP;       // gustSpeed, gustAmp, windAmp, dir (preset do bioma)
uniform vec4 uPoke;    // nx, wz, t0, ativo — rajada pontual (pokeAt)
attribute vec3 GrassArm;
attribute vec4 GrassWind;

// windAt da CPU (ver comentário da função Lua windAt — mesma fórmula)
float windAt(float nx, float wz, float t, float pers) {
    float ph = nx * 5.2 + wz * 0.14;
    float phA = nx * 7.5 + wz * 0.23;
    float phB = nx * 3.2 - wz * 0.31 + 1.7;
    float f1 = max(sin(phA * 0.85 - t * uP.x), 0.0);
    float f2 = max(sin(phB * 0.41 - t * uP.x * 0.737 + 2.4), 0.0);
    float gust = f1 * f1 * 0.70 + f2 * f2 * 0.50;
    float tb = t * (1.0 + pers * 0.45) + pers * 7.9;
    float breeze = sin(tb * 1.35 + ph * 3.1) * 0.30
                 + sin(tb * 0.53 + ph * 1.7) * 0.20;
    float curl = sin(ph * 9.3 + t * 2.6) * sin(ph * 3.7 - t * 1.9) * 0.12;
    float jitter = sin(tb * 6.1 + ph * 12.7) * 0.10 * (0.35 + gust);
    float wander = 0.72 + 0.28 * sin(t * 0.083 + ph * 0.11);
    return (breeze + gust * uP.y + curl + jitter) * uP.z * uP.w * wander;
}

// pokeLean da CPU (rajada local amortecida)
float pokeLean(float nx, float wz) {
    if (uPoke.w < 0.5) return 0.0;
    float e = uT - uPoke.z;
    if (e < 0.0 || e >= 0.9) return 0.0;
    float dxr = nx - uPoke.x;
    float dx = dxr * 7.0;
    float dz = (wz - uPoke.y) * 0.6;
    float d2 = dx * dx + dz * dz;
    if (d2 >= 4.0) return 0.0;
    float swell = min(1.0, e * 10.0) * exp(-e * 4.0);
    float side = dxr >= 0.0 ? 1.0 : -1.0;
    return exp(-d2 * 1.3) * swell * side * 1.9;
}

vec4 position(mat4 transform_projection, vec4 vertex_position) {
    float kind = GrassArm.z;
    float kx;
    float squash = 0.0;
    if (kind < 0.5) {
        // moita do tapete: 2 senos com frequência/fase PRÓPRIAS (v7.4.12)
        float hk = GrassWind.x;
        float dz = GrassWind.y;
        kx = (sin(uT * (0.85 + hk * 1.35) + hk * 37.0) * 0.72
            + sin(uT * (1.9 + hk * 2.2) + dz * 53.0) * 0.28) * GrassWind.z;
    } else if (kind < 1.5) {
        // franja da crista
        float hk = GrassWind.x;
        kx = (sin(uT * (0.85 + hk * 1.35) + hk * 41.0) * 0.7
            + sin(uT * (2.0 + hk * 1.7) + hk * 91.0) * 0.3) * GrassWind.z;
    } else {
        float nx = GrassWind.x;
        float wz = GrassWind.y;
        float hb = GrassWind.z;
        float h3 = GrassWind.w;
        float pk = pokeLean(nx, wz);
        float lean;
        if (kind < 3.5) {
            float flex = 0.55 + hb * 0.75;
            float fe = sin(uT * 0.37 + h3 * 41.0);
            float flick = fe > 0.92
                ? ((fe - 0.92) / 0.08) * sin(uT * 11.0 + h3 * 9.0) * 0.45
                : 0.0;
            if (kind < 2.5) {
                lean = windAt(nx, wz, uT, hb) * flex;
            } else {
                // junco largo: INÉRCIA (relógio lento, balanço fundo)
                lean = windAt(nx, wz, uT * 0.62, hb * 0.4) * flex * 1.30;
            }
            lean = lean + (flick + pk) * flex;
            squash = abs(lean) * 0.16;
        } else {
            lean = (windAt(nx, wz, uT + 0.3, 0.0) + pk) * 0.8;   // flor
        }
        kx = lean * 0.55;
    }
    vertex_position.x += kx * GrassArm.x;
    vertex_position.y -= squash * GrassArm.y;
    return transform_projection * vertex_position;
}
]]
GrassField.SHADER_PIXEL = [[
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    return Texel(tex, uv) * color;
}
]]

local qm
local shader
local frameId_
local cache = { valid = false, slices = {} }
local frameMode, sliceIdx, cacheable = "build", 0, false
GrassField.stats = { replays = 0, builds = 0, sprites = 0, tufts = 0 }
function GrassField.resetStats()
    local st = GrassField.stats
    st.replays, st.builds, st.sprites, st.tufts = 0, 0, 0, 0
end
local cDark = { 0, 0, 0 }
local rowCache = {}
local lastCamZ
local lastTime
local camMovingFrame = false
local GF_DEBUG = require("src.core.Release").isDev() and os.getenv("GF_DEBUG")

local function windAt(nx, wz, t, P, pers)
    local ph = nx * 5.2 + wz * 0.14
    local phA = nx * 7.5 + wz * 0.23
    local phB = nx * 3.2 - wz * 0.31 + 1.7
    local f1 = math.sin(phA * 0.85 - t * P.gustSpeed)
    local f2 = math.sin(phB * 0.41 - t * P.gustSpeed * 0.737 + 2.4)
    local f1p, f2p = math.max(f1, 0), math.max(f2, 0)
    local gust = (f1p * f1p) * 0.70
               + (f2p * f2p) * 0.50
    pers = pers or 0
    local tb = t * (1 + pers * 0.45) + pers * 7.9
    local breeze = math.sin(tb * 1.35 + ph * 3.1) * 0.30
                 + math.sin(tb * 0.53 + ph * 1.7) * 0.20
    local curl = math.sin(ph * 9.3 + t * 2.6)
               * math.sin(ph * 3.7 - t * 1.9) * 0.12
    local jitter = math.sin(tb * 6.1 + ph * 12.7) * 0.10 * (0.35 + gust)
    local wander = 0.72 + 0.28 * math.sin(t * 0.083 + ph * 0.11)
    return (breeze + gust * P.gustAmp + curl + jitter)
           * P.windAmp * P.dir * wander
end
GrassField.windAt = windAt

GrassField._poke = nil
function GrassField.pokeAt(nx, wz, t)
    GrassField._poke = { nx = nx, wz = wz, t0 = t }
end

local sortRow
local function byRowKey(a, b) return sortRow[a].key < sortRow[b].key end

local function hash(a, b)
    local v = math.sin(a * 127.1 + b * 311.7) * 43758.5453
    return v - math.floor(v)
end

local function edgeNoise(z, side)
    local u = z * 1.9 + side * 17.3
    local i = math.floor(u)
    local f = u - i
    f = f * f * (3 - 2 * f)
    local a, b = hash(i, 61), hash(i + 1, 61)
    return a + (b - a) * f
end

local function roadDist(px, centers, armW, clear, offL, offR, roadC)
    if centers then
        local d = 1e9
        for a = 1, #centers do
            local dx = px - centers[a]
            local dd = math.abs(dx) - (clear + (dx < 0 and offL or offR)) * (armW and armW[a] or 1)
            if dd < d then d = dd end
        end
        return d
    end
    local dx = px - roadC
    return math.abs(dx) - clear - (dx < 0 and offL or offR)
end

local function gapWidth(px, centers, armW, clear, offL, offR)
    if not centers then return 1e9 end
    local dl, dr = 1e9, 1e9
    for a = 1, #centers do
        local wa = armW and armW[a] or 1
        local dx = px - centers[a]
        if dx > 0 then
            local d = dx - (clear + offR) * wa
            if d < dl then dl = d end
        else
            local d = -dx - (clear + offL) * wa
            if d < dr then dr = d end
        end
    end
    return dl + dr
end

local function clumpColor(e, P, cDark, cMid, cLight)
    local c = (e.tone == 3) and cDark or ((e.tone == 2) and cMid or cLight)
    local dk = e.dk * (P.dry or 1)
    return QuadMesh.c8(math.min(1, c[1] * (1 + dk * 0.30))),
        QuadMesh.c8(c[2] * (1 - dk * 0.06)),
        QuadMesh.c8(c[3] * (1 - dk * 0.35))
end

local function emit(x, y, sx, sy, ox, oy, qw, qh, q, R, G, B,
                    kind, w1, w2, w3, w4)
    local i = qm:alloc()
    local vt = qm.v
    local xl, xr = x - ox * sx, x + (qw - ox) * sx
    local dT, dB = -oy, qh - oy
    local yT, yB = y + sy * dT, y + sy * dB
    local axT, axB = sx * dT, sx * dB
    local ayT, ayB = sy * dT, sy * dB
    local u0, v0, u1, v1 = q[1], q[2], q[3], q[4]
    local p = vt[i]
    p.x, p.y, p.u, p.v = xl, yT, u0, v0
    p.r, p.g, p.b, p.a = R, G, B, 255
    p.ax, p.ay, p.kind = axT, ayT, kind
    p.w1, p.w2, p.w3, p.w4 = w1, w2, w3, w4
    p = vt[i + 1]
    p.x, p.y, p.u, p.v = xl, yB, u0, v1
    p.r, p.g, p.b, p.a = R, G, B, 255
    p.ax, p.ay, p.kind = axB, ayB, kind
    p.w1, p.w2, p.w3, p.w4 = w1, w2, w3, w4
    p = vt[i + 2]
    p.x, p.y, p.u, p.v = xr, yT, u1, v0
    p.r, p.g, p.b, p.a = R, G, B, 255
    p.ax, p.ay, p.kind = axT, ayT, kind
    p.w1, p.w2, p.w3, p.w4 = w1, w2, w3, w4
    p = vt[i + 3]
    p.x, p.y, p.u, p.v = xr, yB, u1, v1
    p.r, p.g, p.b, p.a = R, G, B, 255
    p.ax, p.ay, p.kind = axB, ayB, kind
    p.w1, p.w2, p.w3, p.w4 = w1, w2, w3, w4
end

local KEY_N = 22
local keyNow, keyPrev = {}, {}
local function fillKey(k, ctx)
    local g, c = ctx.geom, ctx.colors
    k[1], k[2], k[3], k[4] = ctx.camZ, ctx.x, ctx.w, ctx.relCrest
    k[5], k[6], k[7], k[8] = g.cx, g.crestApexY, g.bottomY, g.R
    k[9], k[10], k[11] = c.light[1], c.light[2], c.light[3]
    k[12], k[13], k[14] = c.mid[1], c.mid[2], c.mid[3]
    k[15], k[16], k[17] = c.accent[1], c.accent[2], c.accent[3]
    k[18] = ctx.biomeId
    k[19] = (ctx.castleGapHalf or 0) + math.floor(ctx.castleGapX or 0) * 4096
    k[20] = ctx.forkSig or 0
    k[21] = ctx.roadCenters and 1 or 0
    k[22] = GF_DEBUG and 1 or 0
end
local function sameKey()
    for i = 1, KEY_N do
        if keyNow[i] ~= keyPrev[i] then return false end
    end
    return true
end

local Z_CELL = 0.26
local SLOTS = 12
local EDGE_MARGIN = 0.85
local ISLAND = { cell = 0.9, chance = 0.20, tMin = 0.06, inMin = 0.04, inMax = 0.16,
    nMin = 3, nMax = 7, spread = 14, zJit = 0.12, k = 0.50 }
local FILL = { n = 4, k = 0.66, band = 2.2, edge = 0.85, narrowW = 0.22 }
local FRINGE = { cell = 0.065, slots = 8, perPx = 1.5, out = 4, outP = 14, over = 3.4,
    tuft = 0.76, tuftMin = 0.36, tuftK = 0.8 }

function GrassField.draw(ctx)
    if GrassField.disabled then return end
    bakeAtlas()
    if not qm then
        qm = QuadMesh.new(16384, { ctype = "gf_vertex_t", format = GF_FORMAT })
        shader = love.graphics.newShader(GrassField.SHADER_PIXEL,
            GrassField.SHADER_VERTEX)
    end
    local P = GrassField.PRESETS[ctx.biomeId] or DEFAULT_PRESET
    local relFrom = ctx.relFrom or -1
    local relTo = ctx.relTo or (ctx.relCrest + 2)
    local sig = tuftSig(relFrom, relTo)

    local frameId = ctx.frame or ctx.time
    if frameId ~= frameId_ then
        if frameMode == "build" then
            cache.valid = cacheable
            keyPrev, keyNow = keyNow, keyPrev
        end
        frameId_ = frameId
        fillKey(keyNow, ctx)
        if cache.valid and sameKey() then
            frameMode = "replay"
        else
            frameMode = "build"
            cache.valid = false
            for i = #cache.slices, 1, -1 do cache.slices[i] = nil end
            qm:reset()
            cacheable = not GF_DEBUG
        end
        sliceIdx = 0
        shader:send("uT", ctx.time)
        shader:send("uP", { P.gustSpeed, P.gustAmp, P.windAmp, P.dir })
        local pk = GrassField._poke
        if pk then
            shader:send("uPoke", { pk.nx, pk.wz, pk.t0, 1 })
        else
            shader:send("uPoke", { 0, 0, 0, 0 })
        end
    end
    sliceIdx = sliceIdx + 1
    if frameMode == "replay" then
        local sl = cache.slices[sliceIdx]
        if sl and sl[1] == relFrom and sl[2] == relTo and sl[5] == sig then
            for i = 1, tuftN do
                local q = tufts[i]
                if q.rel > relFrom and q.rel <= relTo then q.done = true end
            end
            if sl[4] > 0 then
                local prev = love.graphics.getShader()
                love.graphics.setShader(shader)
                love.graphics.setColor(1, 1, 1, 1)
                qm:draw(sl[3], sl[4], atlasImg)
                love.graphics.setShader(prev)
            end
            GrassField._lastCount = sl[4]
            GrassField.stats.replays = GrassField.stats.replays + 1
            return
        end
        frameMode = "build"
        cache.valid = false
        cacheable = false
        qm:reset()
    end
    local sliceStart = qm.n
    local cR, cG, cB = 255, 255, 255
    local c8 = QuadMesh.c8

    local g = ctx.geom
    local t0 = ctx.time
    local camZ = ctx.camZ
    local w = ctx.w
    local cLight = ctx.colors.light
    local cMid = ctx.colors.mid
    local cAcc = ctx.colors.accent
    cDark[1], cDark[2], cDark[3] = cMid[1] * 0.68, cMid[2] * 0.68, cMid[3] * 0.68

    if ctx.time ~= lastTime then
        camMovingFrame = lastCamZ ~= nil
            and math.abs(camZ - lastCamZ) > 1e-4
        lastCamZ = camZ
        lastTime = ctx.time
        local wf = math.floor(camZ / Z_CELL)
        local wl = math.floor((camZ + ctx.relCrest) / Z_CELL)
        for kci in pairs(rowCache) do
            if kci < wf or kci > wl then rowCache[kci] = nil end
        end
    end
    local camMoving = camMovingFrame

    local first = math.floor((camZ + math.max(0, relFrom)) / Z_CELL)
    local last = math.floor(
        (camZ + math.min(ctx.relCrest - 0.05, relTo)) / Z_CELL)

    local NK = 96
    for ci = last, first, -1 do
        local z = ci * Z_CELL
        local rel = z - camZ
        local t = g.tOf(rel)
        if t and t > 0.002 and rel > relFrom and rel <= relTo then
            local persp = g.persp(t)
            local scale = (0.26 + persp * 1.75) * P.heightK
            local ch = scale * CELL_H
            if ch >= 2 then
                local t2 = g.tOf(rel - Z_CELL)
                local dy = t2 and (g.latY(0, t2) - g.latY(0, t)) or ch
                local M = 1
                while dy * M < ch * 0.22 and M < 64 do M = M * 2 end
                if GF_DEBUG then
                    Debug.log(string.format(
                        "ci=%d rel=%.2f t=%.4f dy=%.2f ch=%.2f M=%d draw=%s",
                        ci, rel, t, dy, ch, M, tostring(ci % M == 0)))
                end
                if ci % M == 0 then
                    local rc = rowCache[ci]
                    if not rc then
                        rc = { order = {},
                               born = camMoving and -1e9 or t0 }
                        for k = 0, NK - 1 do
                            local hk = hash(ci * 3 + 1, k * 11 + 2)
                            local ht = hash(ci * 19, k * 7 + 3)
                            local dq = math.floor(
                                hash(ci * 5 + 2, k * 3 + 1) * 2.999)
                            local dryK = dq * 0.15
                            local tone = (ht < 0.30) and 3
                                or ((ht < 0.62) and 2 or 1)
                            local lf = (k + (hk - 0.5) * 0.9) / NK - 0.5
                            local df = math.min(1, math.max(0,
                                (math.abs(lf) - 0.055) / 0.30))
                            local pSmall = 0.62 - 0.47 * df
                            local pTall = 0.08 + 0.57 * df
                            local hr = hash(ci * 41 + 8, k * 23 + 5)
                            local hr2 = hash(ci * 43 + 2, k * 31 + 9)
                            local hMul
                            if hr < pSmall then
                                hMul = 0.60 + hr2 * 0.18
                            elseif hr > 1 - pTall then
                                hMul = 1.30 + hr2 * 0.50
                            else
                                hMul = 0.88 + hr2 * 0.30
                            end
                            rc[k] = {
                                hk = hk,
                                lf = lf,
                                hMul = hMul,
                                tone = tone,
                                key = tone * 4 + dq,
                                dk = dryK,
                                cv = hash(ci * 7 + 3, k * 5 + 1),
                                q = clumpQuads[math.floor(hk * N_CLUMP)
                                    % N_CLUMP],
                                flip = (hash(ci, k) < 0.5) and 1 or -1,
                                dz = (hash(ci * 13 + 4, k * 17 + 6) - 0.5)
                                    * 0.9,
                            }
                            rc.order[k + 1] = k
                        end
                        sortRow = rc
                        table.sort(rc.order, byRowKey)
                        sortRow = nil
                        rowCache[ci] = rc
                    end
                    local roadC = ctx.roadCenter(z, t)
                    local half = ctx.roadHalf(t)
                    local centers, armK, armW
                    if ctx.roadCenters then
                        centers, armK, armW = ctx.roadCenters(z, t)
                    end
                    local clear = half * (centers and (armK or 1) or 1)
                    local offL = ctx.roadEdgeOff and ctx.roadEdgeOff(z, t, -1, clear) or 0
                    local offR = ctx.roadEdgeOff and ctx.roadEdgeOff(z, t, 1, clear) or 0
                    local spread = 0.92 + 0.14 * t
                    local spanW = w * 1.06 * spread
                    local spacing = spanW / NK
                    local baseW = 12 * scale
                    local sxK = math.max(1, spacing / math.max(1, baseW)
                        * 1.25)
                    local margin = CLUMP_W * 0.5 * scale * sxK * EDGE_MARGIN
                    local lastKey = -1
                    local fillBand = margin + spacing * FILL.band
                    local age = t0 - rc.born
                    for oi = 1, NK do
                        local k = rc.order[oi]
                        local e = rc[k]
                        local pxX = g.cx + e.lf * spanW
                        local dRaw = roadDist(pxX, centers, armW, clear, offL, offR, roadC)
                        local dRoad = dRaw - margin
                        local onField = math.abs(pxX - g.cx) < w * 0.53 and e.cv < (P.carpet or 1)
                        local gk = 1
                        if age < 1.4 then
                            gk = math.min(1, age / (0.6 + e.hk * 0.7))
                            gk = gk * gk * (3 - 2 * gk)
                            cacheable = false
                        end
                        if dRoad > 0 and onField and clearN > 0 and cleared(pxX, rel) then onField = false end
                        if dRoad > 0 and onField then
                            local zk = z + e.dz * Z_CELL * 3
                            local tk = g.tOf(zk - camZ) or t
                            local perspK = g.persp(tk)
                            local sK = (0.26 + perspK * 1.75) * P.heightK
                            local base = g.latY(pxX - g.cx, tk)
                            local amp = (0.14 + math.abs(e.dz) * 0.26)
                                * P.windAmp * P.dir * 0.5 * e.flip
                            if GF_DEBUG then
                                cR, cG, cB = 255, 0, 255
                                lastKey = -1
                            elseif e.key ~= lastKey then
                                lastKey = e.key
                                cR, cG, cB = clumpColor(e, P, cDark, cMid, cLight)
                            end
                            local edgeK = math.min(1,
                                dRoad / (6 + 14 * perspK))
                            emit(math.floor(pxX),
                                math.floor(base + 1),
                                sK * sxK * e.flip,
                                sK * e.hMul
                                    * (0.55 + 0.45 * edgeK) * gk,
                                CLUMP_W / 2, CELL_H, CLUMP_W, CELL_H,
                                e.q, cR, cG, cB,
                                K_CLUMP, e.hk, e.dz, amp, 0)
                        end
                        local nearEdge = dRaw > -fillBand and dRaw < fillBand
                        local narrow = centers and dRaw > -fillBand
                            and gapWidth(pxX, centers, armW, clear, offL, offR) < w * FILL.narrowW
                        if onField and (nearEdge or narrow) then
                            local fr, fg, fb = clumpColor(e, P, cDark, cMid, cLight)
                            lastKey = -1
                            local nF = FILL.n
                            for j = 0, nF - 1 do
                                local hj = hash(ci * 29 + j * 7, k * 13 + 3)
                                local hz = hash(ci * 31 + j * 5, k * 19 + 7)
                                local fx = pxX + (j + hj - nF * 0.5) * spacing / nF * 1.2
                                local zf = z + (hz - 0.5) * Z_CELL * M
                                local tf = g.tOf(zf - camZ) or t
                                local sF = (0.26 + g.persp(tf) * 1.75) * P.heightK
                                    * FILL.k * (0.75 + hj * 0.5)
                                local fh = CLUMP_W * 0.5 * sF
                                local dF = roadDist(fx, centers, armW, clear, offL, offR, roadC)
                                if dF > fh * FILL.edge and sF * CELL_H >= 1.5
                                   and not (clearN > 0 and cleared(fx, zf - camZ)) then
                                    emit(math.floor(fx), math.floor(g.latY(fx - g.cx, tf) + 1),
                                        sF * ((hz < 0.5) and 1 or -1),
                                        sF * (0.85 + hz * 0.4) * gk,
                                        CLUMP_W / 2, CELL_H, CLUMP_W, CELL_H,
                                        fillQuads[(math.floor(hj * N_FILLQ) + j) % N_FILLQ],
                                        fr, fg, fb, K_CLUMP, hj, e.dz, 0.10 * P.windAmp * P.dir, 0)
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if relTo > ctx.relCrest then
        local scaleC = (0.26 + g.persp(0.01) * 1.75) * P.heightK
        local stepC = math.max(6, 12 * scaleC * 0.7)
        local roadC = ctx.roadCenter(camZ + ctx.relCrest - 0.2, 0.01)
        local halfC = ctx.roadHalf(0.01)
        local cgap = ctx.castleGapHalf or 0
        for k = 0, math.floor(w / stepC) do
            local hk = hash(k * 13 + 7, 91)
            local px = ctx.x + k * stepC + (hk - 0.5) * stepC
            if math.abs(px - roadC) > halfC + 4
               and math.abs(px - (ctx.castleGapX or g.cx)) > cgap then
                local cy = g.crestYAt(px)
                if cy < g.bottomY - 6 then
                    local ht = hash(k * 29 + 3, 57)
                    local c = (ht < 0.45) and cDark or cMid
                    local sC = scaleC * (0.75 + hk * 0.5)
                    local flipC = (ht < 0.5) and 1 or -1
                    local q = clumpQuads[math.floor(hk * N_CLUMP) % N_CLUMP]
                    local ampC = (0.15 + hk * 0.2) * P.windAmp * P.dir
                        * 0.5 * flipC
                    emit(math.floor(px), math.floor(cy + 3),
                        sC * flipC, sC, CLUMP_W / 2, CELL_H, CLUMP_W, CELL_H,
                        q, c8(c[1]), c8(c[2]), c8(c[3]),
                        K_CREST, hk, 0, ampC, 0)
                end
            end
        end
    end

    for ci = first, last do
        local patch = 0.5 + 0.5 * math.sin(ci * 0.31)
        for slot = 0, SLOTS - 1 do
            local h1 = hash(ci, slot * 7 + 1)
            if h1 < (0.34 + 0.24 * patch) * P.density then
                local z = ci * Z_CELL + h1 * Z_CELL
                local rel = z - camZ
                local t = g.tOf(rel)
                if t and t > 0.18 and rel > relFrom and rel <= relTo then
                    local h2 = hash(ci, slot * 13 + 5)
                    local h3 = hash(ci, slot * 29 + 11)
                    local side = (slot % 2 == 0) and -1 or 1
                    local roadC = ctx.roadCenter(z, t)
                    local half = ctx.roadHalf(t)
                    local offS = ctx.roadEdgeOff and ctx.roadEdgeOff(z, t, side, half) or 0
                    local pxX = roadC + side * (half + offS + 2
                        + w * (0.004 + h2 * 0.52) * (0.45 + 0.55 * t))
                    local armBlock = false
                    if ctx.roadCenters then
                        local cs, aK, aW = ctx.roadCenters(z, t)
                        if cs then
                            local ha = half * (aK or 1) + offS + 2
                            for a = 1, #cs do
                                if math.abs(pxX - cs[a])
                                   < ha * (aW and aW[a] or 1) then
                                    armBlock = true
                                    break
                                end
                            end
                        end
                    end
                    if not armBlock
                       and math.abs(pxX - g.cx) < w * 0.52
                       and not (clearN > 0 and cleared(pxX, rel)) then
                        local base = g.latY(pxX - g.cx, t)
                        local persp = g.persp(t)
                        local nx = (pxX - ctx.x) / w
                        local nb = (t < 0.22) and (2 + math.floor(h3 * 2))
                            or (4 + math.floor(h3 * 4))
                        local ramp = math.min(1, (t - 0.18) / 0.10)
                        ramp = ramp * ramp * (3 - 2 * ramp)
                        local dfA = math.min(1, h2 * 1.8)
                        local pSmallA = 0.62 - 0.47 * dfA
                        local pTallA = 0.08 + 0.57 * dfA
                        local hrA = hash(ci * 47 + 6, slot * 37 + 13)
                        local hMulA
                        if hrA < pSmallA then
                            hMulA = 0.45 + h3 * 0.2
                        elseif hrA > 1 - pTallA then
                            hMulA = 1.30 + h3 * 0.5
                        else
                            hMulA = 0.82 + h3 * 0.34
                        end
                        local scale = (0.22 + persp * 1.85) * P.heightK
                            * ramp * hMulA
                        if scale * CELL_H >= 1.6 then
                            local dryK = hash(ci * 7, slot * 3 + 9) * 0.30
                            for bi = 0, nb - 1 do
                                local hb = hash(ci * 31 + slot, bi * 17 + 3)
                                local hv = hash(ci * 53 + bi, slot * 19 + 7)
                                local broad = hv < P.broad
                                local vquad = broad
                                    and (N_THIN + math.floor(hb * N_BROAD))
                                    or math.floor(hv * N_THIN)
                                local s = scale * (0.72 + hb * 0.55)
                                local bx = pxX + (bi - nb / 2)
                                    * (1.6 + persp * 2.2) + hb * 3
                                local ht = hash(ci * 17 + bi, slot * 23 + 2)
                                local c = (ht < 0.25) and cDark
                                    or ((ht < 0.55) and cMid or cLight)
                                emit(math.floor(bx), math.floor(base + 1),
                                    s, s, CELL_W / 2, CELL_H, CELL_W, CELL_H,
                                    quads[vquad],
                                    c8(math.min(1, c[1] * (1 + dryK * 0.30))),
                                    c8(c[2] * (1 - dryK * 0.06)),
                                    c8(c[3] * (1 - dryK * 0.35)),
                                    broad and K_BROAD or K_BLADE,
                                    nx, z, hb, h3)
                            end
                            if h3 > 1 - P.flower and t > 0.25 then
                                emit(math.floor(pxX + h2 * 4 - 2),
                                    math.floor(base + 1),
                                    scale * 0.9, scale * 0.9,
                                    CELL_W / 2, CELL_H, CELL_W, CELL_H,
                                    quads[FLOWER_CELL],
                                    c8(cAcc[1]), c8(cAcc[2]), c8(cAcc[3]),
                                    K_FLOWER, nx, z, 0, h3)
                            end
                        end
                    end
                end
            end
        end
    end

    if P.fringe ~= false then
        local FR = FRINGE
        local dirt = ctx.colors.dirt
        local fz0 = math.floor((camZ + math.max(0.05, relFrom)) / FR.cell)
        local fz1 = math.floor((camZ + math.min(ctx.relCrest - 0.05, relTo)) / FR.cell)
        local dens = FR.perPx * math.min(1, 0.45 + (P.density or 1) * 0.6)
            * (0.5 + 0.5 * (P.carpet or 1))
        for fi = fz0, fz1 do
            local ta = g.tOf(fi * FR.cell - camZ)
            local tb = g.tOf((fi + 1) * FR.cell - camZ)
            if ta and tb and tb > 0.004 then
                local dyc = math.abs(g.latY(0, ta) - g.latY(0, tb))
                local keep = dyc * dens * 2 / FR.slots
                for slot = 0, FR.slots - 1 do
                    local h1 = hash(fi * 7 + 3, slot * 13 + 1)
                    local hk = hash(fi * 11 + 5, slot * 17 + 2)
                    if hk < keep then
                        local z = (fi + h1) * FR.cell
                        local rel = z - camZ
                        local t = g.tOf(rel)
                        if t and t > 0.004 and rel > relFrom and rel <= relTo then
                            local side = (slot % 2 == 0) and -1 or 1
                            local half = ctx.roadHalf(t)
                            local persp = g.persp(t)
                            local h2 = hash(fi * 13 + 1, slot * 29 + 7)
                            local h3 = hash(fi * 19 + 9, slot * 5 + 3)
                            local nz = edgeNoise(z, side)
                            local u = h2 * h2 * (FR.out + FR.outP * persp)
                                - FR.over * (0.6 + persp) * h3 * (0.2 + 1.8 * nz * nz)
                            local centers, armK, armW
                            if ctx.roadCenters then centers, armK, armW = ctx.roadCenters(z, t) end
                            local na = centers and #centers or 1
                            local hA = half * (centers and (armK or 1) or 1)
                            local off = ctx.roadEdgeOff and ctx.roadEdgeOff(z, t, side, hA) or 0
                            for a = 1, na do
                                local wa = centers and (armW and armW[a] or 1) or 1
                                if wa > 0.04 then
                                    local ca = centers and centers[a] or ctx.roadCenter(z, t)
                                    local ra = (half * (centers and (armK or 1) or 1) + off) * wa
                                    local bx = ca + side * (ra + u * wa)
                                    local inside = false
                                    if centers then
                                        for b = 1, na do
                                            if b ~= a then
                                                local wb = armW and armW[b] or 1
                                                local db = bx - centers[b]
                                                local rb = (half * (armK or 1)
                                                    + (ctx.roadEdgeOff and ctx.roadEdgeOff(z, t,
                                                        db < 0 and -1 or 1, hA) or 0)) * wb
                                                if math.abs(db) < rb - 1 then inside = true break end
                                            end
                                        end
                                    end
                                    if not inside and math.abs(bx - g.cx) < w * 0.53
                                       and not (clearN > 0 and cleared(bx, rel)) then
                                        local base = g.latY(bx - g.cx, t)
                                        local hv = hash(fi * 23 + a, slot * 37 + 11)
                                        local reach = math.max(0, u) / (FR.out + FR.outP * persp)
                                        local s = (0.22 + persp * 1.30) * P.heightK
                                            * (0.40 + h3 * 0.45 + reach * 0.55) * math.min(1, wa * 1.5)
                                        if s * CELL_H >= 1.5 then
                                            local vquad = math.floor(hv * N_THIN)
                                            local ht = hash(fi * 31 + a, slot * 41 + 5)
                                            local c = (ht < 0.22) and cDark
                                                or ((ht < 0.70) and cMid or cLight)
                                            local r, gg, bb = c[1], c[2], c[3]
                                            if dirt and u < 1 and ht > 0.45 and ht < 0.70 then
                                                r = (r + dirt[1]) * 0.5
                                                gg = (gg + dirt[2]) * 0.5
                                                bb = (bb + dirt[3]) * 0.5
                                            end
                                            local nx = (bx - ctx.x) / w
                                            if hv > FR.tuft and u < FR.out then
                                                local sc = math.max(s, FR.tuftMin) * FR.tuftK
                                                local tc = (ht < 0.5) and cMid or cLight
                                                emit(math.floor(bx), math.floor(base + 1),
                                                    sc * 0.45 * ((hv < 0.93) and 1 or -1), sc,
                                                    CLUMP_W / 2, CELL_H, CLUMP_W, CELL_H,
                                                    clumpQuads[math.floor(h2 * N_CLUMP) % N_CLUMP],
                                                    c8(tc[1]), c8(tc[2]), c8(tc[3]), K_CLUMP, h3, 0,
                                                    0.12 * P.windAmp * P.dir, 0)
                                            else
                                                emit(math.floor(bx), math.floor(base + 1),
                                                    s * ((hv < 0.62) and -side or side), s,
                                                    CELL_W / 2, CELL_H, CELL_W, CELL_H, quads[vquad],
                                                    c8(r), c8(gg), c8(bb), K_BLADE, nx, z, h3, hv)
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if P.fringe ~= false then
        local IS = ISLAND
        local c0 = math.floor((camZ + math.max(0.05, relFrom)) / IS.cell)
        local c1 = math.floor((camZ + math.min(ctx.relCrest - 0.05, relTo)) / IS.cell)
        for ci2 = c0, c1 do
            for side = -1, 1, 2 do
                local hs = hash(ci2 * 17 + side * 5, 77)
                if hs < IS.chance * (P.carpet or 1) then
                    local z = (ci2 + 0.2 + hash(ci2 * 3 + side, 91) * 0.6) * IS.cell
                    local rel = z - camZ
                    local t = g.tOf(rel)
                    if t and t > IS.tMin and rel > relFrom and rel <= relTo then
                        local half = ctx.roadHalf(t)
                        local persp = g.persp(t)
                        local centers, armK, armW
                        if ctx.roadCenters then centers, armK, armW = ctx.roadCenters(z, t) end
                        local hA = half * (centers and (armK or 1) or 1)
                        local off = ctx.roadEdgeOff and ctx.roadEdgeOff(z, t, side, hA) or 0
                        local depth = IS.inMin + hash(ci2 * 7 + side, 13) * (IS.inMax - IS.inMin)
                        local na = centers and #centers or 1
                        for a = 1, na do
                            local wa = centers and (armW and armW[a] or 1) or 1
                            if wa > 0.5 then
                                local ca = centers and centers[a] or ctx.roadCenter(z, t)
                                local ex = ca + side * (hA + off) * wa
                                local n = IS.nMin + math.floor(hash(ci2 * 11 + a, side + 40) * (IS.nMax - IS.nMin + 1))
                                local spread = IS.spread * (0.4 + persp)
                                for b = 0, n - 1 do
                                    local hb = hash(ci2 * 23 + b, side * 3 + a)
                                    local hc = hash(ci2 * 29 + b, side * 7 + a)
                                    local bx = ex - side * (depth * hA * (1 - hb * 0.6))
                                        + (hc - 0.5) * spread
                                    local zb = z + (hb - 0.5) * IS.zJit
                                    local tb = g.tOf(zb - camZ) or t
                                    local sb = (0.26 + g.persp(tb) * 1.75) * P.heightK * IS.k * (0.7 + hc * 0.6)
                                    if sb * CELL_H >= 1.5 and not (clearN > 0 and cleared(bx, zb - camZ)) then
                                        local c = (hb < 0.3) and cDark or ((hb < 0.75) and cMid or cLight)
                                        emit(math.floor(bx), math.floor(g.latY(bx - g.cx, tb) + 1),
                                            sb * ((hc < 0.5) and 1 or -1), sb * (0.7 + hb * 0.5),
                                            CLUMP_W / 2, CELL_H, CLUMP_W, CELL_H,
                                            fillQuads[(b + ci2) % N_FILLQ],
                                            c8(c[1]), c8(c[2]), c8(c[3]), K_CLUMP, hb, 0,
                                            0.10 * P.windAmp * P.dir, 0)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    for i = 1, tuftN do
        local q = tufts[i]
        if not q.done and q.rel > relFrom and q.rel <= relTo then
            q.done = true
            local tq = g.tOf(q.rel)
            if tq and tq > 0 then
                local nx = (q.x - ctx.x) / w
                local zq = camZ + q.rel
                local qx = math.floor(q.x)
                for bi = 0, q.n - 1 do
                    local hb = hash(qx * 31 + bi, 17)
                    local hv = hash(qx * 53 + bi, 7)
                    local bx = q.x - q.w * 0.5 + (bi + 0.5) / q.n * q.w
                        + (hb - 0.5) * q.w / q.n
                    local base = g.latY(bx - g.cx, tq)
                    local s = q.s * (0.72 + hb * 0.55)
                    local vquad = (hv < P.broad)
                        and (N_THIN + math.floor(hb * N_BROAD)) or math.floor(hv * N_THIN)
                    local ht = hash(qx * 17 + bi, 23)
                    local c = (ht < 0.25) and cDark or ((ht < 0.55) and cMid or cLight)
                    emit(math.floor(bx), math.floor(base + 1),
                        s * ((hb < 0.5) and 1 or -1), s,
                        CELL_W / 2, CELL_H, CELL_W, CELL_H, quads[vquad],
                        c8(c[1]), c8(c[2]), c8(c[3]), K_BLADE, nx, zq, hb, hv)
                end
                GrassField.stats.tufts = GrassField.stats.tufts + q.n
            end
        end
    end

    local count = qm.n - sliceStart
    if count > 0 then
        qm:upload(sliceStart, qm.n)
        local prev = love.graphics.getShader()
        love.graphics.setShader(shader)
        love.graphics.setColor(1, 1, 1, 1)
        qm:draw(sliceStart, count, atlasImg)
        love.graphics.setShader(prev)
    end
    local sl = cache.slices[sliceIdx]
    if not sl then
        sl = {}
        cache.slices[sliceIdx] = sl
    end
    sl[1], sl[2], sl[3], sl[4], sl[5] = relFrom, relTo, sliceStart, count, sig
    GrassField._lastCount = count
    local st = GrassField.stats
    st.builds, st.sprites = st.builds + 1, st.sprites + count
end

function GrassField.clearCache()
    atlasImg, quads, clumpQuads, fillQuads, qm, shader = nil, nil, nil, nil, nil, nil
    frameId_, frameMode, cacheable = nil, "build", false
    cache = { valid = false, slices = {} }
    rowCache = {}
    lastCamZ = nil
    tuftN = 0
    clearN = 0
end

return GrassField
