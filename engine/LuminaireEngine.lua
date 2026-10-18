local LightEngine = require("engine.LightEngine")
local Debug = require("src.core.Debug")

local LuminaireEngine = {}

LuminaireEngine.POOL_MIN_T = 0.50
LuminaireEngine.DAY_GATE = { 0.45, 0.85 }

local frameTod = 1
function LuminaireEngine.setTimeOfDay(tod)
    frameTod = math.max(0, math.min(1, tod or 1))
end
function LuminaireEngine.dayK(tod)
    local g = LuminaireEngine.DAY_GATE
    local k = ((tod or frameTod) - g[1]) / (g[2] - g[1])
    k = math.max(0, math.min(1, k))
    return k * k * (3 - 2 * k)
end

local FIRE_AMBER  = { 1.00, 0.62, 0.25 }

local CATALOG = {
    fields = {
        lantern = { size = 5.6, face = 1, roadside = true,
            lane = { 0.0, 0.08 }, anchor = { 0.78, 0.46 },
            weight = 1.1,
            light = { color = FIRE_AMBER, radiusK = 1.50, coreK = 0.40,
                      intensity = 1.00, flicker = "fire",
                      pool = { radiusK = 1.20, intensity = 1.10, sy = 0.35 } } },
        shrine = { size = 1.6, lane = { 0.30, 0.75 }, anchor = { 0.50, 0.42 },
            weight = 0.5,
            light = { color = { 1.00, 0.75, 0.40 }, radiusK = 0.90,
                      coreK = 0.30, intensity = 0.65, flicker = "pulse" } },
    },

    highlands = {
        brazier = { size = 4.90, roadside = true, lane = { 0.32, 0.42 }, anchor = { 0.50, 0.08 },
            weight = 0.9,
            light = { color = { 0.55, 0.70, 1.00 }, radiusK = 0.95,
                      coreK = 0.50, intensity = 0.85, flicker = "fire",
                      pool = { radiusK = 0.90, intensity = 0.85, sy = 0.35 } },
            embers = { color = { 0.65, 0.80, 1.00 }, count = 2 } },
        runestone = { size = 1.5, lane = { 0.05, 0.35 }, anchor = { 0.50, 0.45 },
            weight = 0.7,
            light = { color = { 0.45, 0.62, 1.00 }, radiusK = 1.10,
                      coreK = 0.35, intensity = 0.70, flicker = "wisp" } },
    },

    abyss = {
        brazier = { size = 5.00, roadside = true, lane = { 0.10, 0.20 }, anchor = { 0.50, 0.10 },
            weight = 1.0,
            light = { color = { 1.00, 0.45, 0.12 }, radiusK = 1.15,
                      coreK = 0.60, intensity = 0.95, flicker = "fire",
                      pool = { radiusK = 1.10, intensity = 1.10, sy = 0.35 } },
            embers = { color = { 1.00, 0.55, 0.18 }, count = 4 } },
        torch = { size = 5.30, roadside = true, lane = { 0.0, 0.10 }, anchor = { 0.50, 0.08 },
            weight = 0.8,
            light = { color = { 1.00, 0.55, 0.20 }, radiusK = 0.85,
                      coreK = 0.45, intensity = 0.85, flicker = "fire",
                      pool = { radiusK = 0.95, intensity = 1.10, sy = 0.35 } },
            embers = { color = { 1.00, 0.60, 0.22 }, count = 2 } },
        fissure = { size = 0.50, lane = { 0.05, 0.50 }, anchor = { 0.50, 0.60 },
            weight = 0.6,
            light = { color = { 1.00, 0.35, 0.10 }, radiusK = 1.00,
                      coreK = 0.30, intensity = 0.75, flicker = "wisp" } },
    },

    frost = {
        brazier = { size = 2.70, roadside = true, lane = { 0.01, 0.12 }, anchor = { 0.50, 0.20 },
            weight = 0.8,
            light = { color = { 1.00, 0.58, 0.22 }, radiusK = 1.60,
                      coreK = 0.50, intensity = 0.90, flicker = "fire",
                      pool = { radiusK = 1.40, intensity = 0.70, emit = 2.2, color = { 1.00, 0.50, 0.16 }, sy = 0.35 } },
            embers = { color = { 1.0, 0.68, 0.30 }, count = 3 } },
        crystal = { size = 1.1, lane = { 0.03, 0.40 }, anchor = { 0.50, 0.35 },
            weight = 0.8,
            light = { color = { 0.62, 0.85, 1.00 }, radiusK = 1.10,
                      coreK = 0.35, intensity = 0.70, flicker = "shimmer" } },
        lantern = { size = 5.6, face = 1, roadside = true,
            lane = { 0.0, 0.08 }, anchor = { 0.80, 0.40 },
            weight = 0.9,
            light = { color = { 1.00, 0.68, 0.32 }, radiusK = 1.50,
                      coreK = 0.40, intensity = 0.95, flicker = "fire",
                      pool = { radiusK = 1.25, intensity = 0.45, emit = 4.5, color = { 1.00, 0.46, 0.12 }, sy = 0.35 } } },
    },

    marsh = {
        lantern = { size = 5.6, face = 1, roadside = true,
            lane = { 0.15, 0.30 }, anchor = { 0.78, 0.46 },
            weight = 0.9,
            light = { color = { 0.55, 0.95, 0.45 }, radiusK = 1.60,
                      coreK = 0.45, intensity = 1.00, flicker = "wisp",
                      pool = { radiusK = 0.80, intensity = 0.80, sy = 0.35 } } },
        mushroom = { size = 0.8, lane = { 0.0, 0.60 }, anchor = { 0.50, 0.40 },
            weight = 1.0,
            light = { color = { 0.45, 0.90, 0.60 }, radiusK = 0.80,
                      coreK = 0.30, intensity = 0.60, flicker = "pulse" } },
        totem = { size = 3.4, roadside = true, lane = { 0.02, 0.20 }, anchor = { 0.50, 0.18 },
            weight = 0.6,
            light = { color = { 0.62, 0.88, 0.50 }, radiusK = 1.20,
                      coreK = 0.40, intensity = 0.75, flicker = "wisp" } },
    },

    dusk = {
        lantern = { size = 6.1, face = 1, roadside = true,
            lane = { 0.0, 0.08 }, anchor = { 0.78, 0.46 },
            weight = 1.1,
            light = { color = { 1.00, 0.72, 0.30 }, radiusK = 1.40,
                      coreK = 0.40, intensity = 0.85, flicker = "fire",
                      pool = { radiusK = 1.10, intensity = 0.95, sy = 0.35 } } },
        shrine = { size = 1.6, lane = { 0.30, 0.75 }, anchor = { 0.50, 0.42 },
            weight = 0.5,
            light = { color = { 1.00, 0.78, 0.45 }, radiusK = 0.95,
                      coreK = 0.30, intensity = 0.70, flicker = "pulse" } },
    },
}

local KIND_SET = {}
for _, kinds in pairs(CATALOG) do
    for kind in pairs(kinds) do KIND_SET[kind] = true end
end

function LuminaireEngine.catalog(bid) return CATALOG[bid] or {} end
function LuminaireEngine.def(bid, kind)
    local c = CATALOG[bid]
    return c and c[kind] or nil
end
function LuminaireEngine.isLuminaire(kind) return KIND_SET[kind] == true end

local anchorCache = {}

local ffi = require("ffi")
local F8 = {}
for b = 0, 255 do F8[b] = tonumber(ffi.cast("float", b / 255)) end

local function scanImage(path, data)
    if not data then
        local ok, d = pcall(love.image.newImageData, path)
        if not ok or not d then return nil end
        data = d
    end
    local w, h = data:getWidth(), data:getHeight()
    local minX, maxX, maxY = w, -1, -1
    local sumX, sumY, sumW = 0, 0, 0
    local peak = 0
    local px = data:getFormat() == "rgba8"
        and ffi.cast("const uint8_t*", data:getFFIPointer()) or nil
    local function rgba(x, y)
        if px then
            local o = (y * w + x) * 4
            return F8[px[o]], F8[px[o + 1]], F8[px[o + 2]], F8[px[o + 3]]
        end
        return data:getPixel(x, y)
    end
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local r, g, b, a = rgba(x, y)
            if a > 0.5 then
                if x < minX then minX = x end
                if x > maxX then maxX = x end
                if y > maxY then maxY = y end
                local lum = r * 0.3 + g * 0.55 + b * 0.15
                if lum > peak then peak = lum end
            end
        end
    end
    if maxX < 0 then return nil end
    local cut = peak * 0.88
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local r, g, b, a = rgba(x, y)
            if a > 0.5 then
                local lum = r * 0.3 + g * 0.55 + b * 0.15
                if lum >= cut then
                    sumX = sumX + x; sumY = sumY + y; sumW = sumW + 1
                end
            end
        end
    end
    local res = {
        offX = math.floor((minX + maxX) / 2 - w / 2 + 0.5),
        footPad = h - 1 - maxY,
    }
    if sumW > 0 then
        res.ax = (sumX / sumW) / w
        res.ay = (sumY / sumW) / h
    end
    return res
end
LuminaireEngine._scanImage = scanImage

function LuminaireEngine.anchor(bid, kind, variant, path)
    local key = bid .. "|" .. kind .. "|" .. tostring(variant)
    local hit = anchorCache[key]
    if hit then return hit end
    local def = LuminaireEngine.def(bid, kind)
    local res = path and scanImage(path) or nil
    if not res then res = { offX = 0, footPad = 0 } end
    if not res.ax and def then
        res.ax, res.ay = def.anchor[1], def.anchor[2]
    end
    anchorCache[key] = res
    return res
end

local function flickerOf(L, seed)
    local time = love.timer.getTime()
    local fi, fr = 1, 1
    if L.flicker == "fire" then
        local n = love.math.noise(time * 1.4, seed) * 0.75
            + love.math.noise(time * 4.0, seed + 37.2) * 0.25
        fi = 0.86 + 0.14 * n
        fr = 0.88 + 0.18 * n
    elseif L.flicker == "wisp" then
        local n = love.math.noise(time * 0.7, seed) * 0.65
            + love.math.noise(time * 2.1, seed + 53.7) * 0.35
        fi = 0.72 + 0.28 * n
        fr = 0.84 + 0.22 * n
    elseif L.flicker == "shimmer" then
        local n = love.math.noise(time * 3.0, seed)
        fi = 0.84 + 0.16 * n
        fr = 0.92 + 0.12 * n
    elseif L.flicker == "pulse" then
        local s = 0.5 + 0.5 * math.sin(time * 1.4 + seed)
        fi = 0.80 + 0.20 * s
        fr = 0.90 + 0.14 * s
    end
    return fi, fr
end

LuminaireEngine.EMIT = { on = true, intensity = 0.22, radiusK = 0.75, levels = 3, cell = 4, upK = 2.2 }
local emit = { shader = nil, ok = nil, img = nil }

local function emitShader()
    if emit.ok == nil then
        local ok, sh = pcall(love.graphics.newShader, "shaders/light_emit.glsl")
        emit.ok = ok and sh and true or false
        emit.shader = emit.ok and sh or nil
        if not emit.ok then
            Debug.warn("[LuminaireEngine] shader light_emit falhou: " .. tostring(sh))
        end
        local d = love.image.newImageData(2, 2)
        d:mapPixel(function() return 1, 1, 1, 1 end)
        emit.img = love.graphics.newImage(d)
    end
    return emit.shader
end

function LuminaireEngine.drawPool(bid, kind, a)
    local E = LuminaireEngine.EMIT
    local def = E.on and LuminaireEngine.def(bid, kind)
    local P = def and def.light.pool
    if not P or (a.t or 1) < LuminaireEngine.POOL_MIN_T * 0.5 then return end
    local dayK = LuminaireEngine.dayK(a.tod)
    if dayK <= 0 or not LightEngine.isEnabled() then return end
    local sh = emitShader()
    if not sh then return end
    local L = def.light
    local fi, fr = flickerOf(L, (a.seed or 0) % 1000)
    local distK = 0.42 + 0.58 * math.min(1, (a.t or 1) / 0.55)
    local r = math.min(P.radiusK * a.flameH * fr * distK, a.capR or 1e9) * dayK * E.radiusK
    local inten = E.intensity * P.intensity * (P.emit or 1) * fi * (0.6 + 0.4 * distK) * (a.alphaK or 1) * dayK
    if r < 2 or inten <= 0.01 then return end
    local pr, pg, pb, pa = love.graphics.getColor()
    local bm, am = love.graphics.getBlendMode()
    local prevSh = love.graphics.getShader()
    love.graphics.setShader(sh)
    sh:send("levels", E.levels)
    sh:send("cell", E.cell)
    sh:send("intensity", inten)
    sh:send("upK", E.upK)
    love.graphics.setBlendMode("add", "alphamultiply")
    local pc = P.color or L.color
    love.graphics.setColor(pc[1], pc[2], pc[3], 1)
    local sc = r
    love.graphics.draw(emit.img, math.floor(a.gx), math.floor(a.gy), 0, sc, sc * (P.sy or 0.35), 1, 1)
    love.graphics.setShader(prevSh)
    love.graphics.setBlendMode(bm, am)
    love.graphics.setColor(pr, pg, pb, pa)
end

function LuminaireEngine.submit(bid, kind, a)
    local def = LuminaireEngine.def(bid, kind)
    if not def then return end
    local dayK = LuminaireEngine.dayK(a.tod)
    if dayK <= 0 then return end
    local L = def.light
    local fi, fr = flickerOf(L, (a.seed or 0) % 1000)
    local base = a.flameH or a.sh
    local aK = a.alphaK or 1
    local distK = 0.42 + 0.58 * math.min(1, (a.t or 1) / 0.55)
    LightEngine.submit({
        x = a.fx, y = a.fy,
        radius = math.min(L.radiusK * base * fr * distK, (a.capR or 1e9)) * dayK,
        color = L.color, intensity = L.intensity * fi * (0.6 + 0.4 * distK) * aK * dayK,
        dither = true, ditherAmt = 0.28, levels = 8,
        seed = a.seed, z = a.rel,
    })
    local P = L.pool
    if P and a.gx and a.gy and (a.t or 1) >= LuminaireEngine.POOL_MIN_T * 0.5 then
        LightEngine.submit({
            x = a.gx, y = a.gy,
            radius = math.min(P.radiusK * base * fr * distK, (a.capR or 1e9)) * dayK,
            color = P.color or L.color, intensity = P.intensity * fi * (0.6 + 0.4 * distK) * aK * dayK,
            dither = true, ditherAmt = 0.28, levels = 8, sy = P.sy or 0.35,
            seed = a.seed, z = a.rel,
        })
    end
    LightEngine.submitMicro(a.fx, a.fy,
        math.min(L.coreK * base * 0.6 * fr * distK, (a.capR or 1e9) * 0.4) * dayK,
        L.color, 0.9 * fi * aK * dayK, a.rel)
end

local function hash01(n)
    return (math.sin(n * 127.1 + 311.7) * 43758.5453) % 1
end

function LuminaireEngine.drawEmbersSpec(em, fx, fy, sh, seed)
    if not em or sh < 14 then return end
    local time = love.timer.getTime()
    local c = em.color
    for i = 1, em.count do
        local h1 = hash01(seed * 7.13 + i * 13.7)
        local h2 = hash01(seed * 3.71 + i * 29.3)
        local cycle = 1.1 + h1 * 0.9
        local life = (time / cycle + h2) % 1
        local rise = life * sh * 0.55
        local wob = math.sin(time * 2.2 + h1 * 6.28 + life * 5.0)
            * sh * 0.05
        local aK = (1 - life) * (1 - life) * math.min(1, life * 6)
        if aK > 0.05 then
            local sz = math.max(1, math.floor(sh * 0.03 * (1 - life * 0.5)))
            love.graphics.setColor(c[1], c[2], c[3], aK)
            love.graphics.rectangle("fill",
                math.floor(fx + wob), math.floor(fy - rise), sz, sz)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function LuminaireEngine.drawEmbers(bid, kind, fx, fy, sh, seed)
    local def = LuminaireEngine.def(bid, kind)
    return LuminaireEngine.drawEmbersSpec(def and def.embers, fx, fy, sh, seed)
end

return LuminaireEngine
