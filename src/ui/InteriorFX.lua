local Debug = require("src.core.Debug")

local SceneBackground = require("src.ui.SceneBackground")
local HallAnim        = require("src.ui.HallAnim")

local InteriorFX = {}

local HALLS = {
    [1] = {
        flames = {
            { 72, 112, 10, 13 }, { 102, 122, 10, 13 }, { 158, 128, 8, 11 },
            { 234, 128, 8, 11 }, { 289, 122, 10, 13 }, { 319, 112, 10, 13 },
        },
        pulses = { { 182, 78, 36, 100, 0.9, 0.16 } },
        ember = { 1.00, 0.62, 0.22 },
        ambient = { style = "dust", rate = 7, color = { 1.00, 0.80, 0.50 },
                    region = { 150, 60, 100, 130 } },
        fog = { y = 172, h = 40, color = { 0.30, 0.20, 0.14 }, alpha = 0.45 },
        vignette = 0.75,
    },
    [2] = {
        flames = {
            { 14, 122, 44, 20 }, { 88, 148, 30, 18 },
            { 284, 148, 30, 18 }, { 342, 122, 44, 20 },
        },
        pulses = { { 172, 8, 56, 125, 0.5, 0.10 } },
        ember = { 1.00, 0.86, 0.55 },
        ambient = { style = "dust", rate = 9, color = { 0.82, 0.72, 1.00 },
                    region = { 120, 30, 160, 170 } },
        fog = { y = 196, h = 36, color = { 0.28, 0.20, 0.40 }, alpha = 0.50 },
        vignette = 0.80,
    },
    [3] = {
        flames = {
            { 25, 123, 26, 36 }, { 95, 147, 18, 21 },
            { 288, 147, 18, 21 }, { 348, 123, 26, 36 },
        },
        pulses = { { 186, 100, 28, 84, 1.4, 0.22 },
                   { 128, 140, 30, 44, 1.1, 0.12 }, { 242, 140, 30, 44, 1.25, 0.12 } },
        ember = { 1.00, 0.42, 0.14 },
        ambient = { style = "ash", rate = 26, color = { 0.55, 0.50, 0.48 },
                    region = { 0, -10, 400, 20 } },
        fog = { y = 178, h = 40, color = { 0.45, 0.10, 0.04 }, alpha = 0.40 },
        vignette = 0.85,
        anim = {
            flameFrames = true,
            flows = { { 186, 100, 28, 76 }, { 128, 140, 30, 36 }, { 242, 140, 30, 36 } },
            shimmer = { { 0, 190, 72, 50 }, { 328, 190, 72, 50 },
                        { 116, 164, 46, 22 }, { 238, 164, 46, 22 } },
        },
        smoke = { { 38, 121 }, { 104, 145 }, { 297, 145 }, { 361, 121 } },
        bubbles = { { 122, 176, 36, 10 }, { 243, 176, 36, 10 }, { 172, 173, 58, 3 } },
    },
    [4] = {
        flames = { { 136, 155, 14, 22 }, { 251, 155, 14, 22 } },
        pulses = {},
        ember = { 0.62, 0.85, 1.00 },
        ambient = { style = "snow", rate = 22, color = { 0.85, 0.93, 1.00 },
                    region = { 0, -10, 400, 20 } },
        fog = { y = 182, h = 44, color = { 0.55, 0.72, 0.95 }, alpha = 0.42 },
        vignette = 0.70,
    },
    [5] = {
        flames = { { 106, 152, 22, 28 }, { 272, 150, 24, 32 } },
        pulses = {
                   { 160, 54, 88, 120, 1.2, 0.55, th = 0.14, beat = true } },
        flameGlow = 0.28,
        anim = {
            flameFrames = true,
            flamePalette = { { 44, 112, 32 }, { 76, 168, 50 }, { 132, 214, 78 },
                             { 198, 236, 122 }, { 232, 244, 164 } },
        },
        ember = { 0.55, 0.85, 0.42 }, emberRate = 0.6,
        ambient = { style = "spores", rate = 3.5, color = { 0.72, 0.82, 0.55 },
                    region = { 20, 60, 360, 190 } },
        fireflies = { n = 6, region = { 120, 110, 160, 100 }, color = { 0.86, 0.98, 0.50 } },
        fog = { y = 190, h = 46, color = { 0.20, 0.36, 0.12 }, alpha = 0.55, speed = 0.35 },
        vignette = 0.80,
        rootMouths = { { 160, 2 }, { 240, 2 }, { 100, 62 }, { 300, 62 },
                       { 200, 0 }, { 92, 124 }, { 308, 124 } },
    },
    [6] = {
        flames = {},
        pulses = { { 170, 60, 62, 130, 0.35, 0.08 } },
        ember = nil,
        ambient = { style = "motes", rate = 10, color = { 1.00, 0.97, 0.90 },
                    region = { 172, 40, 58, 150 } },
        fog = { y = 186, h = 40, color = { 0.62, 0.60, 0.66 }, alpha = 0.38 },
        vignette = 0.65,
    },
}
InteriorFX.HALLS = HALLS

local MAX_PARTICLES = 220
local particles = {}
local spawnAcc = 0
local emberAcc = 0
local time = 0
local gust = nil
local pulseBoost = nil
InteriorFX.fogHook = nil
local veilCur = 0
local eclipseLvl, eclipseDawn = 0, 0

local fogImg, vignetteImg
local hallImgs = {}
local hallAnims = {}
local quads = {}
local avisou = {}

local function hash(x, y)
    local n = math.sin(x * 127.1 + y * 311.7) * 43758.5453
    return n - math.floor(n)
end

local function vnoise(x, y)
    local xi, yi = math.floor(x), math.floor(y)
    local fx, fy = x - xi, y - yi
    fx = fx * fx * (3 - 2 * fx)
    fy = fy * fy * (3 - 2 * fy)
    local a = hash(xi, yi)
    local b = hash(xi + 1, yi)
    local c = hash(xi, yi + 1)
    local d = hash(xi + 1, yi + 1)
    return a + (b - a) * fx + (c - a) * fy + (a - b - c + d) * fx * fy
end

local FOG_W, FOG_H = 200, 24

local function buildFog()
    local data = love.image.newImageData(FOG_W, FOG_H)
    for y = 0, FOG_H - 1 do
        local v = y / (FOG_H - 1)
        local band = math.sin(v * math.pi)
        for x = 0, FOG_W - 1 do
            local ang = x / FOG_W * 2 * math.pi
            local n = vnoise(math.cos(ang) * 4 + 10, math.sin(ang) * 4 + y * 0.35) * 0.65
                + vnoise(math.cos(ang) * 9 + 30, math.sin(ang) * 9 + y * 0.7) * 0.35
            local dens = band * (n * 1.5 - 0.35)
            local lvl = math.max(0, math.min(3, math.floor(dens * 4)))
            data:setPixel(x, y, 1, 1, 1, lvl / 3)
        end
    end
    fogImg = love.graphics.newImage(data)
    fogImg:setFilter("nearest", "nearest")
    fogImg:setWrap("repeat", "clamp")
end

local function buildVignette()
    local w, h = 400, 256
    local data = love.image.newImageData(w, h)
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local dx = (x - w / 2) / (w / 2)
            local dy = (y - h * 0.46) / (h / 2)
            local r = math.sqrt(dx * dx * 0.9 + dy * dy * 1.1)
            local d = math.max(0, math.min(1, (r - 0.55) / 0.6))
            d = d * d
            data:setPixel(x, y, 1, 1, 1, math.floor(d * 8 + 0.5) / 8)
        end
    end
    vignetteImg = love.graphics.newImage(data)
    vignetteImg:setFilter("nearest", "nearest")
end

local FLAME_LUMA, PULSE_LUMA = 0.50, 0.32

local function stampEmissive(src, dst, r, th)
    local iw, ih = src:getWidth(), src:getHeight()
    for y = math.max(0, r[2]), math.min(ih - 1, r[2] + r[4] - 1) do
        for x = math.max(0, r[1]), math.min(iw - 1, r[1] + r[3] - 1) do
            local cr, cg, cb = src:getPixel(x, y)
            local l = 0.3 * cr + 0.59 * cg + 0.11 * cb
            if l > th then
                local _, _, _, pa = dst:getPixel(x, y)
                local a = math.min(1, (l - th) / (1 - th) * 1.6)
                if a > pa then dst:setPixel(x, y, cr, cg, cb, a) end
            end
        end
    end
end

local function hallImage(hall)
    if hallImgs[hall] ~= nil then return hallImgs[hall] or nil end
    local cfg = HALLS[hall]
    local path = "assets/sprites/scenes/castle_hall_" .. hall .. ".png"
    local ok, src = pcall(love.image.newImageData, path)
    if not ok or not src then
        Debug.warn("[InteriorFX] AVISO: não carregou " .. path .. " — sem luz nas chamas")
        hallImgs[hall] = false
        return nil
    end
    local dst = love.image.newImageData(src:getWidth(), src:getHeight())
    for _, f in ipairs(cfg.flames) do stampEmissive(src, dst, f, FLAME_LUMA) end
    for _, pz in ipairs(cfg.pulses) do stampEmissive(src, dst, pz, pz.th or PULSE_LUMA) end
    local img = love.graphics.newImage(dst)
    img:setFilter("nearest", "nearest")
    hallImgs[hall] = img
    hallAnims[hall] = HallAnim.build(src, cfg)
    quads[hall] = {}
    return img
end

local function quadFor(hall, key, r)
    local q = quads[hall][key]
    if not q then
        local img = hallImgs[hall]
        q = love.graphics.newQuad(r[1], r[2], r[3], r[4], img:getWidth(), img:getHeight())
        quads[hall][key] = q
    end
    return q
end

local hallMemo = {}
function InteriorFX.hallFor(act)
    local a = math.max(1, act or 1)
    if hallMemo[a] then return hallMemo[a] end
    local res = a
    if not love.filesystem.getInfo("assets/sprites/scenes/castle_hall_" .. a .. ".png") then
        res = math.min(3, a)
        if not avisou[a] then
            avisou[a] = true
            Debug.warn(("[cena] sem castle_hall_%d.png — caindo no salão %d"):format(a, res))
        end
    end
    hallMemo[a] = res
    return res
end

function InteriorFX.clear()
    gust = nil
    veilCur = 0
    eclipseLvl, eclipseDawn = 0, 0
    for i = #particles, 1, -1 do particles[i] = nil end
    spawnAcc = 0
    emberAcc = 0
end

local rnd = love.math.random

local function spawnAmbient(cfg)
    local amb = cfg.ambient
    local r = amb.region
    local p = {
        x = r[1] + rnd() * r[3], y = r[2] + rnd() * r[4],
        kind = amb.style, front = rnd() < 0.35,
        phase = rnd() * 6.28, life = 0, color = amb.color,
    }
    local st = amb.style
    if st == "dust" or st == "motes" then
        p.vx, p.vy = (rnd() - 0.5) * 3, (rnd() - 0.5) * 2.5
        p.maxLife = 4 + rnd() * 4
        p.front = false
    elseif st == "ash" then
        p.vx, p.vy = (rnd() - 0.5) * 6, 6 + rnd() * 8
        p.maxLife = 30
    elseif st == "snow" then
        p.vx, p.vy = (rnd() - 0.5) * 4, 8 + rnd() * 9
        p.maxLife = 30
    elseif st == "spores" then
        local z = rnd()
        p.z = z
        p.size = (z > 0.78) and 2 or 1
        p.front = z > 0.85
        p.speedK = 0.35 + 0.75 * z
        p.vx, p.vy = 0, -(0.6 + rnd() * 1.4) * p.speedK
        p.freq = 0.25 + rnd() * 0.5
        p.amp = (1.5 + rnd() * 2.5) * p.speedK
        p.maxLife = 9 + rnd() * 8
    end
    particles[#particles + 1] = p
end

local function spawnFirefly(cfg)
    local ff = cfg.fireflies
    local r = ff.region
    particles[#particles + 1] = {
        kind = "firefly", front = rnd() < 0.3, color = ff.color,
        cx = r[1] + rnd() * r[3], cy = r[2] + rnd() * r[4], x = 0, y = 0,
        ax = 6 + rnd() * 14, ay = 3 + rnd() * 7,
        fx = 0.10 + rnd() * 0.18, fy = 0.13 + rnd() * 0.22,
        phase = rnd() * 6.28, phase2 = rnd() * 6.28,
        period = 2.6 + rnd() * 3.2, blinkOff = rnd() * 5,
        life = 0, maxLife = 16 + rnd() * 14, vx = 0, vy = 0,
    }
end

local function spawnSmoke(cfg)
    local pt = cfg.smoke[rnd(1, #cfg.smoke)]
    particles[#particles + 1] = {
        kind = "smoke", front = false, x = pt[1] + (rnd() - 0.5) * 3, y = pt[2],
        vx = 1 + rnd() * 1.5, vy = -(5 + rnd() * 4), phase = rnd() * 6.28,
        life = 0, maxLife = 3 + rnd() * 1.5,
    }
end

local function spawnBubble(cfg)
    local b = cfg.bubbles[rnd(1, #cfg.bubbles)]
    particles[#particles + 1] = {
        kind = "bubble", front = false,
        x = b[1] + math.floor(rnd() * b[3]), y = b[2] + math.floor(rnd() * b[4]),
        vx = 0, vy = 0, life = 0, maxLife = 0.55 + rnd() * 0.35,
    }
end

local function countKind(k)
    local n = 0
    for i = 1, #particles do if particles[i].kind == k then n = n + 1 end end
    return n
end

local function spawnEmber(cfg)
    local fl = cfg.flames
    if #fl == 0 then return end
    local f = fl[rnd(1, #fl)]
    particles[#particles + 1] = {
        x = f[1] + f[3] * (0.3 + rnd() * 0.4), y = f[2] + 1,
        vx = (rnd() - 0.5) * 5, vy = -(10 + rnd() * 12),
        kind = "ember", front = false, phase = rnd() * 6.28,
        life = 0, maxLife = 0.8 + rnd() * 0.9, color = cfg.ember,
    }
end

local currentHall = nil
local step

local function enterHall(hall)
    currentHall = hall
    InteriorFX.clear()
    for _ = 1, 250 do step(0.1, hall) end
end

function InteriorFX.update(dt, hall)
    if hall ~= currentHall then enterHall(hall) end
    step(dt, hall)
end

step = function(dt, hall)
    time = time + dt
    if gust then
        gust.t = gust.t + dt
        if gust.t >= gust.dur then gust = nil end
    end
    if pulseBoost then
        pulseBoost.t = pulseBoost.t + dt
        if pulseBoost.t >= pulseBoost.dur then pulseBoost = nil end
    end
    do
        local target = 0
        if InteriorFX.fogHook then
            local ok, v = pcall(InteriorFX.fogHook)
            if ok and type(v) == "number" then target = math.max(0, math.min(1, v)) end
        end
        veilCur = veilCur + (target - veilCur) * math.min(1, dt * 4)
    end
    local cfg = HALLS[hall or 1]
    if not cfg then return end

    if #particles < MAX_PARTICLES then
        spawnAcc = spawnAcc + dt * cfg.ambient.rate
        while spawnAcc >= 1 do
            spawnAcc = spawnAcc - 1
            spawnAmbient(cfg)
        end
        if cfg.ember then
            emberAcc = emberAcc + dt * (cfg.emberRate or 3) * #cfg.flames
            while emberAcc >= 1 do
                emberAcc = emberAcc - 1
                spawnEmber(cfg)
            end
        end
        if cfg.smoke and rnd() < dt * 6 then spawnSmoke(cfg) end
        if cfg.bubbles and rnd() < dt * 5 then spawnBubble(cfg) end
        if cfg.fireflies and rnd() < dt * 0.8
            and countKind("firefly") < cfg.fireflies.n then
            spawnFirefly(cfg)
        end
    end

    for i = #particles, 1, -1 do
        local p = particles[i]
        p.life = p.life + dt
        local k = p.kind
        if k == "ember" then
            p.vy = p.vy + 9 * dt
            p.vx = p.vx * (1 - dt * 1.5)
        elseif k == "ash" or k == "snow" then
            p.vx = p.vx + math.sin(time * 1.3 + p.phase) * 4 * dt
        elseif k == "spores" then
            p.vx = math.cos(time * p.freq + p.phase) * p.amp * p.freq * 2
        elseif k == "smoke" then
            p.vx = p.vx * (1 - dt * 0.4) + math.sin(time * 0.8 + p.phase) * 0.6 * dt
            p.vy = p.vy * (1 - dt * 0.35)
        end
        if k == "firefly" then
            local t = p.life
            p.x = p.cx + math.sin(t * p.fx * 6.28 + p.phase) * p.ax
                + math.sin(t * p.fx * 14.4 + p.phase2) * p.ax * 0.3
            p.y = p.cy + math.sin(t * p.fy * 6.28 + p.phase2) * p.ay
        else
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
        end
        if p.life >= p.maxLife or p.y > 262 or p.y < -14
            or p.x < -10 or p.x > 410 then
            particles[i] = particles[#particles]
            particles[#particles] = nil
        end
    end
end

local function lifeAlpha(p)
    local t = p.life / p.maxLife
    if p.kind == "ash" or p.kind == "snow" then return 1 end
    if p.kind == "spores" or p.kind == "firefly" then
        return math.min(1, t * 4) * math.min(1, (1 - t) * 4)
    end
    return math.min(1, t * 5) * math.min(1, (1 - t) * 3)
end

local function blinkOf(p)
    local ph = ((p.life + p.blinkOff) % p.period) / p.period
    local on = 0.8 / p.period
    if ph > on then return 0.06 end
    return 0.06 + 0.94 * math.sin(ph / on * math.pi)
end

local function cell(ox, oy, s, x, y, n)
    love.graphics.rectangle("fill", math.floor(ox + x * s), math.floor(oy + y * s),
        math.ceil(s * n), math.ceil(s * n))
end

local function drawParticles(tr, front)
    local s = tr.scale
    local ox, oy = tr.ox, tr.oy
    for i = 1, #particles do
        local p = particles[i]
        if p.front == front then
            local c = p.color
            local a = lifeAlpha(p)
            local k = p.kind
            local px, py = math.floor(p.x), math.floor(p.y)
            if k == "smoke" then
                local t = p.life / p.maxLife
                local n = (t < 0.3) and 1 or ((t < 0.65) and 2 or 3)
                local al = math.floor((1 - t) * 4) / 4 * 0.38
                love.graphics.setColor(0.46, 0.39, 0.36, al)
                cell(ox, oy, s, px, py, n)
            elseif k == "bubble" then
                local t = p.life / p.maxLife
                if t < 0.6 then
                    love.graphics.setColor(1, 0.86, 0.45, 0.9)
                    cell(ox, oy, s, px, py, t < 0.3 and 1 or 2)
                else
                    love.graphics.setColor(1, 0.55, 0.15, 0.8 * (1 - t) / 0.4)
                    cell(ox, oy, s, px - 1, py, 1); cell(ox, oy, s, px + 2, py, 1)
                    cell(ox, oy, s, px, py - 1, 1); cell(ox, oy, s, px + 1, py - 1, 1)
                end
            elseif k == "firefly" then
                love.graphics.setColor(c[1], c[2], c[3], a * blinkOf(p) * 0.9)
                cell(ox, oy, s, px, py, 1)
            elseif k == "spores" then
                local tw = 0.8 + 0.2 * math.sin(time * 0.9 + p.phase)
                local al = a * tw * (0.18 + 0.42 * p.z)
                love.graphics.setColor(c[1], c[2], c[3], al)
                cell(ox, oy, s, px, py, 1)
                if p.size > 1 then
                    love.graphics.setColor(c[1], c[2], c[3], al * 0.35)
                    cell(ox, oy, s, px - 1, py, 1); cell(ox, oy, s, px + 1, py, 1)
                    cell(ox, oy, s, px, py - 1, 1); cell(ox, oy, s, px, py + 1, 1)
                end
            elseif k == "ember" then
                local t = p.life / p.maxLife
                love.graphics.setColor(c[1], math.max(0.1, c[2] - t * 0.35), c[3], a)
                cell(ox, oy, s, px, py, 1)
            else
                local tw = 0.65 + 0.35 * math.sin(time * 2.2 + p.phase)
                if k == "motes" and (eclipseLvl > 0.01 or eclipseDawn > 0.01) then
                    c = { c[1] + (0.85 - c[1]) * eclipseLvl, c[2] + (0.30 - c[2]) * eclipseLvl,
                          c[3] + (0.75 - c[3]) * eclipseLvl }
                    c = { c[1] + (1.0 - c[1]) * eclipseDawn, c[2] + (0.82 - c[2]) * eclipseDawn,
                          c[3] + (0.50 - c[3]) * eclipseDawn }
                end
                love.graphics.setColor(c[1], c[2], c[3], a * tw * (front and 0.95 or 0.7))
                cell(ox, oy, s, px, py, 1)
            end
        end
    end
end

function InteriorFX.pulseBoost(k, dur)
    pulseBoost = { k = math.max(1, k or 2), t = 0, dur = math.max(0.1, dur or 1) }
end
function InteriorFX.pulseBoostK()
    if not pulseBoost then return 1 end
    return 1 + (pulseBoost.k - 1) * math.max(0, 1 - pulseBoost.t / pulseBoost.dur)
end

function InteriorFX.gust(strength, dur)
    gust = { k = math.max(0, math.min(1, strength or 1)), t = 0, dur = math.max(0.05, dur or 0.5) }
end
function InteriorFX.gustLevel()
    if not gust then return 0 end
    local p = gust.t / gust.dur
    local env = (p < 0.15) and (p / 0.15) or (1 - (p - 0.15) / 0.85)
    return gust.k * math.max(0, env)
end

function InteriorFX.setEclipse(level, dawn)
    eclipseLvl = math.max(0, math.min(1, level or 0))
    eclipseDawn = math.max(0, math.min(1, dawn or 0))
end
function InteriorFX.eclipseState() return eclipseLvl, eclipseDawn end

local function eclipseFogColor(fc)
    if eclipseLvl <= 0.01 and eclipseDawn <= 0.01 then return fc end
    local r = fc[1] + (0.42 - fc[1]) * eclipseLvl
    local g = fc[2] + (0.16 - fc[2]) * eclipseLvl
    local b = fc[3] + (0.50 - fc[3]) * eclipseLvl
    r = r + (0.82 - r) * eclipseDawn
    g = g + (0.66 - g) * eclipseDawn
    b = b + (0.46 - b) * eclipseDawn
    return { r, g, b }
end

local function drawEclipseOnHall(hall, img, tr)
    if hall ~= 6 then return end
    local s, ox, oy = tr.scale, tr.ox, tr.oy
    if eclipseLvl > 0.01 then
        local q = math.floor(eclipseLvl * 4 + 1e-6) / 4
        if q > 0 then
            love.graphics.setColor(0.05, 0.01, 0.07, 0.80 * q)
            love.graphics.rectangle("fill", ox + 160 * s, oy - 4 * s, 80 * s, 196 * s)
            love.graphics.setColor(0.05, 0.01, 0.07, 0.60 * q)
            love.graphics.rectangle("fill", ox + 148 * s, oy + 192 * s, 104 * s, 70 * s)
        end
    end
    if eclipseDawn > 0.01 and img then
        love.graphics.setBlendMode("add")
        local a = 0.55 * eclipseDawn * (0.9 + 0.1 * math.sin(time * 0.8))
        love.graphics.setColor(1.0, 0.86, 0.62, a)
        love.graphics.draw(img, quadFor(hall, "dawnBeam", { 170, 0, 62, 196 }), ox + 170 * s, oy, 0, s, s)
        love.graphics.setColor(1.0, 0.80, 0.55, a * 0.7)
        love.graphics.draw(img, quadFor(hall, "dawnFloor", { 140, 190, 120, 66 }), ox + 140 * s, oy + 190 * s, 0, s, s)
        love.graphics.setBlendMode("alpha")
    end
end

local function flicker(i)
    local base = 0.62 + 0.22 * math.sin(time * 11 + i * 2.4)
        + 0.12 * math.sin(time * 27 + i * 7.1)
        + 0.06 * math.sin(time * 53 + i * 3.3)
    local g = InteriorFX.gustLevel()
    if g > 0 then
        base = base * (1 + g * (0.85 - 0.45 * (0.5 + 0.5 * math.sin(time * 31 + i * 2.1))))
    end
    return base
end

function InteriorFX.draw(hall)
    local cfg = HALLS[hall or 1]
    if not cfg then return end
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local tr = SceneBackground.getCoverTransform("castle_hall_" .. hall, w, h)
    if not tr then return end
    local s, ox, oy = tr.scale, tr.ox, tr.oy
    if not fogImg then buildFog() end
    if not vignetteImg then buildVignette() end

    local img = hallImage(hall)
    if img then HallAnim.draw(hallAnims[hall], tr, time) end
    if img then
        love.graphics.setBlendMode("add")
        for i, f in ipairs(cfg.flames) do
            love.graphics.setColor(1, 1, 1, (cfg.flameGlow or 0.75) * flicker(i))
            love.graphics.draw(img, quadFor(hall, "f" .. i, f), ox + f[1] * s, oy + f[2] * s, 0, s, s)
        end
        for i, pz in ipairs(cfg.pulses) do
            local a
            if pz.beat then
                local pk = InteriorFX.pulseBoostK()
                local ph = (time * pz[5] * pk) % 1
                a = pz[6] * pk * (math.exp(-((ph - 0.08) / 0.05) ^ 2)
                    + 0.6 * math.exp(-((ph - 0.30) / 0.06) ^ 2))
            else
                a = pz[6] * (0.5 + 0.5 * math.sin(time * pz[5] + i * 1.7))
            end
            love.graphics.setColor(1, 1, 1, a)
            love.graphics.draw(img, quadFor(hall, "p" .. i, pz), ox + pz[1] * s, oy + pz[2] * s, 0, s, s)
        end
        love.graphics.setBlendMode("alpha")
    end

    drawEclipseOnHall(hall, img, tr)

    local fog = cfg.fog
    local fc = eclipseFogColor(fog.color)
    local veilH = 1 + 0.8 * veilCur
    local sy = fog.h * veilH / FOG_H
    for layer = 1, 2 do
        local speed = (layer == 1 and 3 or -5) * (fog.speed or 1)
        local off = math.floor((time * speed) % FOG_W)
        local yy = oy + (fog.y - fog.h * (veilH - 1) + (layer - 1) * fog.h * 0.35) * s
        love.graphics.setColor(fc[1], fc[2], fc[3],
            math.min(1, fog.alpha * (1 + 1.5 * veilCur)) * (layer == 1 and 1 or 0.7))
        for k = -1, 2 do
            love.graphics.draw(fogImg, ox + (k * FOG_W - off) * s, yy, 0, s, s * sy)
        end
    end

    love.graphics.setColor(0.02, 0.01, 0.01, cfg.vignette)
    love.graphics.draw(vignetteImg, ox, oy, 0, s, s)

    drawParticles(tr, false)
    love.graphics.setColor(1, 1, 1, 1)
end

function InteriorFX.drawFront(hall, clipTop)
    if not HALLS[hall or 1] then return end
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local tr = SceneBackground.getCoverTransform("castle_hall_" .. hall, w, h)
    if not tr then return end
    local top = math.max(0, math.floor(clipTop or 0))
    local sx, sy, sw, sh = love.graphics.getScissor()
    love.graphics.intersectScissor(0, top, w, h - top)
    drawParticles(tr, true)
    if veilCur > 0.01 and fogImg then
        local cfg = HALLS[hall or 1]
        local fog = cfg.fog
        local fc = eclipseFogColor(fog.color)
        local s, ox, oy = tr.scale, tr.ox, tr.oy
        local reduced = _G.gameSettings and _G.gameSettings.reducedMotion
        local hh = fog.h * 2.2
        local off = reduced and 0 or math.floor((time * 4 * (fog.speed or 1)) % FOG_W)
        local yy = oy + (fog.y + fog.h - hh) * s
        love.graphics.setColor(fc[1], fc[2], fc[3], 0.35 * veilCur)
        for k = -1, 2 do
            love.graphics.draw(fogImg, ox + (k * FOG_W - off) * s, yy, 0, s, s * hh / FOG_H)
        end
    end
    if sx then love.graphics.setScissor(sx, sy, sw, sh) else love.graphics.setScissor() end
    love.graphics.setColor(1, 1, 1, 1)
end

function InteriorFX.renderedFog()
    return veilCur
end

return InteriorFX
