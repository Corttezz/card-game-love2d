local Debug = require("src.core.Debug")
local Data = require("src.data.menu_brand")

local MenuBrand = {}
MenuBrand.__index = MenuBrand

MenuBrand.T = {
    RAY0 = 1.24, RAYSTEP = 0.125, CHARGE = 2.26, FLASH = 2.62,
    MOVE = 2.86, MOVE_END = 3.46, WORD0 = 3.02, WORDSTEP = 0.075,
    SWEEP0 = 4.15, BUTTONS = 3.95, BUTTON_STEP = 0.08, BUTTON_DUR = 0.30,
    BG_FADE = 0.8, ELECTRIC = 2.55, END = 6.5,
}
MenuBrand.SWEEP_SPEED = 600 / 0.9
MenuBrand.IDLE_SWEEP = { 8, 12 }
MenuBrand.IDLE_TWINKLE = { 1.4, 3.2 }

local T = MenuBrand.T
local BOUNCE = { -14, -10, -6, -2, 1, 3, 2, 1, 0, -1, 0 }
local HOLD_TWINKLES = { { 4.7, 1 }, { 5.25, 4 }, { 5.7, 7 }, { 6.1, 3 } }
local SPARK = { { 255, 250, 232 }, { 255, 222, 140 }, { 232, 160, 64 } }
local EMBER = { { 255, 246, 214 }, { 252, 208, 110 }, { 230, 134, 48 }, { 150, 52, 26 }, { 84, 26, 22 } }
local DUST = { 96, 70, 92 }
local BAYER = { { 0, 8, 2, 10 }, { 12, 4, 14, 6 }, { 3, 11, 1, 9 }, { 15, 7, 13, 5 } }
local SPARK_SIZES = { 1, 2, 3, 3, 2, 1, 1 }
local TREMBLE = { { 1, 0 }, { 0, 1 }, { -1, 0 }, { 0, -1 } }
local N_EMBERS, N_BURST, N_CONVERGE = 16, 46, 28
local N_MOTES, N_RAY_SPARKS = 96, 6
local GOLD_D, GOLD_M, GOLD_L = { 122, 74, 26 }, { 172, 118, 42 }, { 212, 160, 68 }
MenuBrand.FX = {
    moteFrom = 0.15, moteRim = 58, moteWarpAt = 0.3, moteWarp = 1.6,
    runeFrom = 0.2, runeTo = 1.6, rayLife = 0.4, streak = 0.10,
    trembleFrom = 0.25,
}

local res = nil

local function newNearest(path)
    local img = love.graphics.newImage(path)
    img:setFilter("nearest", "nearest")
    return img
end

local function paletteImage()
    local rows = { Data.palUnlit, Data.palLit, Data.palWarm, Data.palHot }
    local d = love.image.newImageData(7, 4)
    for r = 1, 4 do
        for i = 1, 7 do
            local c = rows[r][i]
            d:setPixel(i - 1, r - 1, c[1] / 255, c[2] / 255, c[3] / 255, 1)
        end
    end
    local img = love.graphics.newImage(d)
    d:release()
    img:setFilter("nearest", "nearest")
    return img
end

local function bayerImage()
    local d = love.image.newImageData(4, 4)
    for y = 1, 4 do
        for x = 1, 4 do
            local v = (BAYER[y][x] + 0.5) / 16
            d:setPixel(x - 1, y - 1, v, v, v, 1)
        end
    end
    local img = love.graphics.newImage(d)
    d:release()
    img:setFilter("nearest", "nearest")
    img:setWrap("repeat", "repeat")
    return img
end

local function loadShader(path)
    local ok, s = pcall(love.graphics.newShader, path)
    if ok then return s end
    Debug.warn("[MenuBrand] shader nao compilou, efeito desligado: " .. path .. " (" .. tostring(s) .. ")")
    return nil
end

function MenuBrand.load()
    if res ~= nil then return res or nil end
    if not (love.graphics and love.graphics.newImage) then res = false; return nil end
    local ok, r = pcall(function()
        return {
            word = newNearest("assets/branding/wordmark.png"),
            wordGold = newNearest("assets/branding/wordmark_gold.png"),
            seal = newNearest("assets/branding/seal.png"),
            sealData = newNearest("assets/branding/seal_data.png"),
        }
    end)
    if not ok then
        Debug.warn("[MenuBrand] arte do logotipo nao carregou, menu usa o titulo de texto: " .. tostring(r))
        res = false
        return nil
    end
    r.pal = paletteImage()
    r.bayer = bayerImage()
    r.sealShader = loadShader("shaders/brand_seal.glsl")
    r.wordShader = loadShader("shaders/brand_word.glsl")
    r.fxShader = loadShader("shaders/brand_fx.glsl")
    if r.sealShader then
        r.sealShader:send("pal", r.pal)
        r.sealShader:send("trevScale", Data.seal.trevScale)
        r.sealShader:send("texSize", { Data.seal.w, Data.seal.h })
        r.sealShader:send("tRay0", T.RAY0)
        r.sealShader:send("tRayStep", T.RAYSTEP)
        r.sealShader:send("tCharge", T.CHARGE)
        r.sealShader:send("tFlash", T.FLASH)
    end
    if r.wordShader then
        r.wordShader:send("goldMask", r.wordGold)
        r.wordShader:send("texSize", { Data.word.w, Data.word.h })
    end
    if r.fxShader then r.fxShader:send("bayer", r.bayer) end
    r.quads = {}
    for i = 1, #Data.cuts - 1 do
        local a, b = Data.cuts[i], Data.cuts[i + 1]
        r.quads[i] = love.graphics.newQuad(a, 0, b - a, Data.word.h, Data.word.w, Data.word.h)
    end
    res = r
    return r
end

function MenuBrand._resetForTests() res = nil end

local stingPlayed = false

function MenuBrand.stingPending()
    if stingPlayed then return false end
    if _G.gameSettings and _G.gameSettings.reducedMotion then return false end
    return MenuBrand.canSting()
end

function MenuBrand.markStingPlayed() stingPlayed = true end
function MenuBrand.resetSting() stingPlayed = false end

function MenuBrand.available() return MenuBrand.load() ~= nil end

function MenuBrand.canSting()
    local r = MenuBrand.load()
    return r ~= nil and r.sealShader ~= nil and r.wordShader ~= nil and r.fxShader ~= nil
end

MenuBrand.COLUMN = { bottom = 0.975, spacingRatio = 0.092, spacingMax = 80, heightRatio = 0.08, heightMax = 60 }
MenuBrand.ZONE = { top = 0.025, clear = 0.02, wordMaxW = 0.42, sealDrop = 2 }

function MenuBrand.buttonColumn(vh)
    local C = MenuBrand.COLUMN
    local spacing = math.min(C.spacingMax, vh * C.spacingRatio)
    local h = math.min(C.heightMax, vh * C.heightRatio)
    return vh * C.bottom - 4 * spacing - h, spacing, h
end

function MenuBrand.layout(vw, vh, k)
    k = k or 1
    local Z = MenuBrand.ZONE
    local W, H = vw * k, vh * k
    local y0, spacing = MenuBrand.buttonColumn(vh)
    local topV = vh * Z.top
    local region = (y0 - spacing - vh * Z.clear - topV) * k
    local sw, sh, ww, wh, gap = Data.seal.w, Data.seal.h, Data.word.w, Data.word.h, Data.gap
    local P = math.max(1, math.floor(W * Z.wordMaxW / ww))
    local Ps
    while true do
        for s = P, math.max(1, P - Z.sealDrop), -1 do
            if (sh + gap) * s + wh * P <= region then Ps = s; break end
        end
        if Ps or P == 1 then break end
        P = P - 1
    end
    Ps = Ps or 1
    local total = (sh + gap) * Ps + wh * P
    local top = math.floor(topV * k + math.max(0, region - total) / 2 + 0.5)
    local ox = math.floor((W - ww * P) / 2 + 0.5)
    return {
        P = P, Ps = Ps, ox = ox, oy = top + (sh + gap) * Ps, W = W, H = H, k = k,
        top = top, total = total,
        sealPX = math.floor(ox + (ww * P - sw * Ps) / 2 + 0.5), sealPY = top,
        wordX = 0, wordY = 0,
    }
end

local function easeOut(u)
    u = math.min(1, math.max(0, u))
    return 1 - (1 - u) ^ 3
end

function MenuBrand.new()
    local self = setmetatable({}, MenuBrand)
    self.mode = "static"
    self.clock = 0
    self.sweeps = {}
    self.twinkles = {}
    local rng = love.math.newRandomGenerator(7)
    self.rng = rng
    self.burst = {}
    for i = 1, N_BURST do
        local a = rng:random() * 2 * math.pi
        local s = 70 + rng:random() * 160
        self.burst[i] = { vx = math.cos(a) * s, vy = math.sin(a) * s * 0.9,
            life = 0.6 + rng:random() * 1.1, big = rng:random() < 0.3 }
    end
    self.converge = {}
    for i = 1, N_CONVERGE do
        self.converge[i] = { a = rng:random() * 2 * math.pi, r0 = 110 + rng:random() * 80,
            t0 = T.CHARGE - 0.1 + rng:random() * 0.2 }
    end
    self.motes = {}
    for i = 1, N_MOTES do
        self.motes[i] = {
            a0 = rng:random() * 2 * math.pi, spin = rng:random() < 0.5 and -1 or 1,
            ts = MenuBrand.FX.moteFrom + rng:random() * 1.6, period = 0.8 + rng:random() * 0.6,
            r0 = 150 + rng:random() * 100, big = rng:random() < 0.35,
        }
    end
    self.raySparks = {}
    for i = 1, 8 * N_RAY_SPARKS do
        self.raySparks[i] = { da = (rng:random() - 0.5) * 1.6, v = 40 + rng:random() * 70,
            life = 0.18 + rng:random() * 0.2 }
    end
    self.embers = {}
    for i = 1, N_EMBERS do
        self.embers[i] = {
            x0 = -50 + rng:random() * (Data.word.w + 100),
            yn = rng:random(),
            vy = -22 + rng:random() * 13, ph = rng:random() * 6.28, amp = 2 + rng:random() * 5,
            t0 = rng:random() * 2.6, life = 1.8 + rng:random() * 1.6, fl = 4 + rng:random() * 5,
        }
    end
    self.emberT0 = math.huge
    return self
end

function MenuBrand:isPlaying() return self.mode == "sting" end

function MenuBrand:stingTime()
    if self.mode == "sting" then return self.clock end
    return math.huge
end

local function rand(rng, lo, hi) return lo + rng:random() * (hi - lo) end

function MenuBrand:_toIdle()
    self.mode = "idle"
    self.sweeps = {}
    self.twinkles = {}
    self.nextSweep = self.clock + rand(self.rng, MenuBrand.IDLE_SWEEP[1], MenuBrand.IDLE_SWEEP[2])
    self.nextTwinkle = self.clock + rand(self.rng, MenuBrand.IDLE_TWINKLE[1], MenuBrand.IDLE_TWINKLE[2])
    if self.emberT0 == math.huge then self.emberT0 = self.clock end
end

function MenuBrand:startSting()
    self.mode = "sting"
    self.clock = 0
    self.emberT0 = T.MOVE
    self.sweeps = { T.SWEEP0 }
    self.twinkles = {}
    for k = 0, 7 do self.twinkles[#self.twinkles + 1] = { T.RAY0 + k * T.RAYSTEP + 0.1, k + 1 } end
    for _, h in ipairs(HOLD_TWINKLES) do self.twinkles[#self.twinkles + 1] = { h[1], h[2] } end
end

function MenuBrand:startShort()
    self.clock = 0
    self.emberT0 = math.huge
    self:_toIdle()
    self.sweeps = { 0.35 }
end

function MenuBrand:finish()
    if self.mode ~= "sting" then return end
    self.clock = T.END
    self:_toIdle()
end

function MenuBrand:update(dt, reduced)
    if reduced then
        if self.mode == "sting" then self:finish() end
        return
    end
    self.clock = self.clock + dt
    if self.mode == "sting" then
        if self.clock >= T.END then self:_toIdle() end
        return
    end
    if self.mode == "static" then self:_toIdle() end
    if self.clock >= self.nextSweep then
        self.sweeps[#self.sweeps + 1] = self.clock
        self.nextSweep = self.clock + rand(self.rng, MenuBrand.IDLE_SWEEP[1], MenuBrand.IDLE_SWEEP[2])
    end
    if self.clock >= self.nextTwinkle then
        self.twinkles[#self.twinkles + 1] = { self.clock, self.rng:random(1, 8) }
        self.nextTwinkle = self.clock + rand(self.rng, MenuBrand.IDLE_TWINKLE[1], MenuBrand.IDLE_TWINKLE[2])
    end
    for i = #self.sweeps, 1, -1 do
        if self.clock - self.sweeps[i] > 2 then table.remove(self.sweeps, i) end
    end
    for i = #self.twinkles, 1, -1 do
        if self.clock - self.twinkles[i][1] > 1 then table.remove(self.twinkles, i) end
    end
end

local SWEEP_FROM = -60
local SWEEP_TO = Data.word.w + Data.word.h * 0.55 + 20

function MenuBrand:sweepP()
    for _, s0 in ipairs(self.sweeps) do
        local p = SWEEP_FROM + (self.clock - s0) * MenuBrand.SWEEP_SPEED
        if self.clock >= s0 and p <= SWEEP_TO then return p end
    end
    return nil
end

local alphaMul = 1

local function px(x, y, c)
    love.graphics.setColor(c[1] / 255, c[2] / 255, c[3] / 255, alphaMul)
    love.graphics.rectangle("fill", math.floor(x + 0.5), math.floor(y + 0.5), 1, 1)
end

local function sparkle(x, y, age)
    local f = math.floor(age * 60 / 3)
    if f < 0 or f >= #SPARK_SIZES then return end
    local s = SPARK_SIZES[f + 1]
    x, y = math.floor(x + 0.5), math.floor(y + 0.5)
    px(x, y, SPARK[1])
    for i = 1, s do
        local c = s > 1 and SPARK[math.min(3, i)] or SPARK[2]
        px(x + i, y, c); px(x - i, y, c); px(x, y + i, c); px(x, y - i, c)
    end
    if s == 3 then
        px(x + 1, y + 1, SPARK[3]); px(x - 1, y + 1, SPARK[3])
        px(x + 1, y - 1, SPARK[3]); px(x - 1, y - 1, SPARK[3])
    end
end

local function emberColor(u)
    return EMBER[math.min(#EMBER, math.floor(u * #EMBER) + 1)]
end

MenuBrand.STING_SEAL_H = 0.42

function MenuBrand.stingScale(L)
    local Ps = math.max(1, math.floor(L.H * MenuBrand.STING_SEAL_H / Data.seal.h + 0.5))
    while Ps > 1 and Data.seal.h * Ps > L.H * 0.62 do Ps = Ps - 1 end
    return math.max(Ps, L.Ps)
end

function MenuBrand:_sealGeom(L)
    local t = self.clock
    local w, h = Data.seal.w, Data.seal.h
    local sting = self.mode == "sting"
    local Ps = sting and MenuBrand.stingScale(L) or L.Ps
    local sox = math.floor((L.W - w * Ps) / 2 + 0.5)
    local soy = math.floor((L.H - h * Ps) / 2 + 0.5) - 4 * Ps
    local fx, fy = L.sealPX, L.sealPY
    local u = sting and easeOut((t - T.MOVE) / (T.MOVE_END - T.MOVE)) or 1
    local s = Ps - math.floor((Ps - L.Ps) * u + 0.5)
    local c0x, c0y = sox + w * Ps / 2, soy + h * Ps / 2
    local c1x, c1y = fx + w * L.Ps / 2, fy + h * L.Ps / 2
    local ccx, ccy = c0x + (c1x - c0x) * u, c0y + (c1y - c0y) * u
    local G = {
        x = math.floor(ccx - w * s / 2 + 0.5), y = math.floor(ccy - h * s / 2 + 0.5), s = s,
        jx = 0, jy = 0, Ps = Ps, sox = sox, soy = soy,
    }
    if u >= 1 then G.x, G.y = fx, fy end
    local t0 = T.CHARGE - MenuBrand.FX.trembleFrom
    if sting and t >= t0 and t < T.FLASH then
        local d, D = t - t0, T.FLASH - t0
        local phase = 6 * d + 54 * d * d * d / (3 * D * D)
        local k = math.floor(phase) % 4
        G.jx, G.jy = TREMBLE[k + 1][1], TREMBLE[k + 1][2]
    end
    return G
end

local function hash(x)
    local v = math.sin(x * 12.9898) * 43758.5453
    return v - math.floor(v)
end

local function moteWarp(t)
    local d = t - (T.CHARGE - MenuBrand.FX.moteWarpAt)
    if d <= 0 then return t end
    return t + MenuBrand.FX.moteWarp * d * d
end

function MenuBrand:_drawMotes(t, cx, cy)
    local F = MenuBrand.FX
    if t < F.moteFrom or t >= T.FLASH then return end
    local wt = moteWarp(t)
    for _, m in ipairs(self.motes) do
        if t >= m.ts then
            local tau = wt - moteWarp(m.ts)
            local q = tau / m.period
            local cyc = math.floor(q)
            local u = q - cyc
            local r = F.moteRim + (m.r0 - F.moteRim) * (1 - u) ^ 1.4
            local a = m.a0 + cyc * 2.4 + m.spin * u * 2.6
            local c = u > 0.8 and SPARK[2] or (u > 0.5 and EMBER[3] or EMBER[4])
            px(cx + math.cos(a) * r, cy + math.sin(a) * r, c)
            if m.big and u > 0.45 then
                local a2 = a - m.spin * 0.06
                px(cx + math.cos(a2) * (r + 2), cy + math.sin(a2) * (r + 2), EMBER[4])
            end
        end
    end
end

function MenuBrand:_drawRunes(t, cx, cy)
    local F = MenuBrand.FX
    if t < F.runeFrom or t >= F.runeTo then return end
    local env = math.min(1, (t - F.runeFrom) / 0.25, (F.runeTo - t) / 0.3)
    local tick = math.floor(t * 14)
    for a = 1, 3 do
        if hash(tick + a * 7) > 0.12 then
            local R = 62 + a * 4
            local dir = (a % 2 == 0) and -1 or 1
            local start = a * 2.1 + dir * t * (0.7 + 0.2 * a)
            local n = math.floor(0.8 * R / 2)
            for i = 0, n do
                if ((i * 7) % 16) / 16 < env then
                    local ang = start + i * 2 / R
                    local ca, sa = math.cos(ang), math.sin(ang)
                    if i % 6 == 3 then
                        px(cx + ca * (R + 2), cy + sa * (R + 2), GOLD_L)
                        px(cx + ca * (R + 1), cy + sa * (R + 1), GOLD_M)
                        px(cx + ca * (R - 1), cy + sa * (R - 1), GOLD_D)
                    elseif i % 3 ~= 2 then
                        px(cx + ca * R, cy + sa * R, (i % 6 < 2) and GOLD_M or GOLD_D)
                    end
                end
            end
        end
    end
end

function MenuBrand:_drawRayIgnition(t, cx, cy)
    local F = MenuBrand.FX
    for k = 0, 7 do
        local age = t - (T.RAY0 + k * T.RAYSTEP)
        if age >= 0 and age < F.rayLife then
            local th = -math.pi / 2 + k * math.pi / 4
            local ux, uy = math.cos(th), math.sin(th)
            local tip = Data.tips[k + 1]
            local L = math.sqrt((tip[1] - cx) ^ 2 + (tip[2] - cy) ^ 2)
            if age < F.streak + 0.06 then
                local head = 12 + (L - 12) * math.min(1, age / F.streak)
                local fade = age > F.streak and 4 or 10
                for d = head - fade, head, 2 do
                    if d >= 12 and d <= L then
                        px(cx + ux * d, cy + uy * d, (d > head - 3) and SPARK[2] or SPARK[3])
                    end
                end
            end
            for j = 1, N_RAY_SPARKS do
                local sp = self.raySparks[k * N_RAY_SPARKS + j]
                if age < sp.life then
                    local f = (1 - math.exp(-3 * age)) / 3
                    local ang = th + sp.da
                    local c = age < sp.life * 0.35 and SPARK[1] or (age < sp.life * 0.7 and SPARK[3] or EMBER[4])
                    px(tip[1] + math.cos(ang) * sp.v * f, tip[2] + math.sin(ang) * sp.v * f + 14 * age * age, c)
                end
            end
        end
    end
end

local function sendRing(sh, name, col, on, R, thick, dens, c)
    if on then
        sh:send(name, { R, thick, dens, 1 })
        sh:send(col, { c[1] / 255, c[2] / 255, c[3] / 255 })
    else
        sh:send(name, { 0, 0, 0, 0 })
    end
end

function MenuBrand:_fxPass(L, G, under, bgAmt, cx, cy)
    local r = res
    if not (r and r.fxShader) then return end
    local t = self.clock
    local sh = r.fxShader
    local g = love.graphics
    local x0, y0 = g.transformPoint(0, 0)
    local x1 = g.transformPoint(1, 0)
    local Ps = G.Ps
    sh:send("cell", math.max(1, x1 - x0))
    sh:send("gridOrigin", { x0, y0 })
    sh:send("center", { cx, cy })
    sh:send("bgCenter", { (L.W / 2 - G.sox) / Ps, (L.H * 0.44 - G.soy) / Ps })
    sh:send("screenN", { L.W / Ps, L.H / Ps })
    local tf = t - T.FLASH
    if under then
        sh:send("bgAmt", bgAmt)
        local on = t >= 0.06 and t < 0.72
        local uu = easeOut((t - 0.06) / 0.66)
        sendRing(sh, "ringA", "colA", on, 150 - 100 * uu, 1.0, 0.15 + 0.6 * uu, { 150, 104, 52 })
        sendRing(sh, "ringB", "colB", false)
        if bgAmt <= 0 and not on then return end
    else
        sh:send("bgAmt", 0)
        local on1 = tf >= 0 and tf < 0.62
        local uu = tf / 0.62
        local cols = { SPARK[1], SPARK[2], SPARK[3], EMBER[4] }
        sendRing(sh, "ringA", "colA", on1, 10 + 320 * easeOut(uu), 1.5 - 0.5 * uu, 1.05 - uu,
            cols[math.min(4, math.floor(uu * 4) + 1)])
        local on2 = on1 and tf > 0.06
        local u2 = (tf - 0.06) / 0.56
        sendRing(sh, "ringB", "colB", on2, 6 + 220 * easeOut(u2), 1.0, 0.7 - 0.7 * u2, EMBER[3])
        if not on1 then return end
    end
    g.setShader(sh)
    g.setColor(1, 1, 1, 1)
    g.rectangle("fill", -G.sox / Ps - 2, -G.soy / Ps - 2, L.W / Ps + 4, L.H / Ps + 4)
    g.setShader()
end

function MenuBrand:_drawWord(L, t, sweepP, reduced)
    local r = res
    local g = love.graphics
    local sh = r.wordShader
    local last = T.WORD0 + (#r.quads - 1) * T.WORDSTEP + #BOUNCE * 2 / 60
    if self.mode ~= "sting" or t >= last then
        if sweepP and sh and not reduced then
            g.setShader(sh)
            sh:send("origin", { L.wordX, L.wordY })
            sh:send("sweepP", sweepP)
            sh:send("whiteMix", 0)
            sh:send("boost", 0)
        end
        g.setColor(1, 1, 1, alphaMul)
        g.draw(r.word, L.wordX, L.wordY)
        g.setShader()
        return
    end
    for i, q in ipairs(r.quads) do
        local t0 = T.WORD0 + (i - 1) * T.WORDSTEP
        local f = math.floor((t - t0) * 60 / 2)
        if f >= 0 then
            local dy = BOUNCE[f + 1] or 0
            local a, b = Data.cuts[i], Data.cuts[i + 1]
            if sh then
                g.setShader(sh)
                sh:send("origin", { L.wordX, L.wordY + dy })
                sh:send("sweepP", sweepP or -10000)
                sh:send("whiteMix", f < 2 and 0.65 or 0)
                sh:send("boost", (f >= 2 and f < 4) and 1 or 0)
            end
            g.setColor(1, 1, 1, alphaMul)
            g.draw(r.word, q, L.wordX + a, L.wordY + dy)
            g.setShader()
            if f >= 4 and f < 9 then
                local base = L.wordY + Data.word.h - 2
                local k = f - 4
                local w = b - a
                for s = -1, 1, 2 do
                    for j = 0, 1 do
                        local x = L.wordX + a + math.floor(w / 2) + s * (math.floor(w / 2) + 1 + k * 2 + j * 2)
                        px(x, base - math.floor(k / 2) - j, k > 2 and EMBER[5] or DUST)
                    end
                end
            end
        end
    end
end

MenuBrand.PULSE = { dur = 0.16, alpha = 0.18 }

function MenuBrand:draw(alpha, bgAmt, reduced)
    local r = MenuBrand.load()
    if not r then return false end
    alpha = alpha or 1
    bgAmt = bgAmt or 0
    local g = love.graphics
    local k = require("src.ui.UiScale").activeK()
    local L = MenuBrand.layout(g.getWidth(), g.getHeight(), k)
    self._layout = L
    local t = self.clock
    local sting = self.mode == "sting" and not reduced
    alphaMul = alpha
    local G = self:_sealGeom(L)
    if not sting then
        G.x, G.y, G.s, G.jx, G.jy = L.sealPX, L.sealPY, L.Ps, 0, 0
    end
    self._seal = G
    local cx, cy = Data.seal.cx, Data.seal.cy

    local lastLetter = T.WORD0 + (#r.quads - 1) * T.WORDSTEP + 4 / 60
    local shake = (sting and t - lastLetter >= 0 and t - lastLetter < 3 / 60) and L.P or 0

    g.push()
    g.scale(1 / k, 1 / k)

    if sting then
        g.push()
        g.translate(G.sox, G.soy)
        g.scale(G.Ps, G.Ps)
        self:_fxPass(L, G, true, bgAmt, cx, cy)
        self:_drawMotes(t, cx, cy)
        self:_drawRunes(t, cx, cy)
        if t >= T.CHARGE and t < T.FLASH then
            for _, c in ipairs(self.converge) do
                local u = (t - c.t0) / (T.FLASH - c.t0)
                if u >= 0 and u < 1 then
                    local rr = c.r0 * (1 - u * u)
                    local ca, sa = math.cos(c.a), math.sin(c.a)
                    px(cx + ca * rr, cy + sa * rr, u > 0.6 and SPARK[2] or SPARK[3])
                    px(cx + ca * (rr + 3), cy + sa * (rr + 3), EMBER[4])
                end
            end
        end
        g.pop()
    end

    local sweepP = (not reduced) and self:sweepP() or nil
    g.push()
    g.translate(G.x, G.y + shake)
    g.scale(G.s, G.s)
    local animSeal = sting and t < T.FLASH + 0.4
    if (animSeal or sweepP) and r.sealShader then
        local sh = r.sealShader
        g.setShader(sh)
        sh:send("T", animSeal and t or 99)
        sh:send("origin", { (L.sealPX - L.ox) / L.P, (L.sealPY - L.oy) / L.P })
        sh:send("pxScale", L.Ps / L.P)
        sh:send("sweepP", sweepP or -10000)
        g.setColor(1, 1, 1, alpha)
        g.draw(r.sealData, G.jx, G.jy)
        g.setShader()
    elseif not sting or t >= T.FLASH then
        g.setColor(1, 1, 1, alpha)
        g.draw(r.seal, 0, 0)
    end
    if not reduced then
        for _, tw in ipairs(self.twinkles) do
            local tip = Data.tips[tw[2]]
            sparkle(tip[1], tip[2], t - tw[1])
        end
    end
    if sting and t < T.FLASH then self:_drawRayIgnition(t, cx, cy) end
    g.pop()

    g.push()
    g.translate(L.ox, L.oy + shake)
    g.scale(L.P, L.P)
    if not sting or t >= T.WORD0 - 0.01 then self:_drawWord(L, t, sweepP, reduced) end
    if not reduced and t >= self.emberT0 then
        local sealTop = (L.sealPY - L.oy) / L.P
        local yA = sealTop + Data.seal.h * L.Ps / L.P * 0.6
        local yB = Data.word.h + 20
        for _, e in ipairs(self.embers) do
            local te = t - self.emberT0 - e.t0
            if te >= 0 then
                te = te % (e.life + 0.4)
                if te <= e.life and math.sin(e.ph + te * e.fl) >= -0.6 then
                    local u = te / e.life
                    px(e.x0 + math.sin(e.ph + te * 1.7) * e.amp, yA + e.yn * (yB - yA) + e.vy * te, emberColor(0.25 + u * 0.75))
                end
            end
        end
    end
    g.pop()

    if sting then
        local tf = t - T.FLASH
        g.push()
        g.translate(G.sox, G.soy)
        g.scale(G.Ps, G.Ps)
        local ccx = (G.x + cx * G.s - G.sox) / G.Ps
        local ccy = (G.y + cy * G.s - G.soy) / G.Ps
        self:_fxPass(L, G, false, 0, ccx, ccy)
        if tf >= 0 then
            for _, b in ipairs(self.burst) do
                if tf <= b.life then
                    local drag = 2.2
                    local f = (1 - math.exp(-drag * tf)) / drag
                    local x = cx + b.vx * f
                    local y = cy + b.vy * f + 26 * tf * tf
                    local c = emberColor(tf / b.life)
                    px(x, y, c)
                    if b.big and tf < b.life * 0.5 then
                        px(x + 1, y, c); px(x, y + 1, c); px(x + 1, y + 1, c)
                    end
                end
            end
        end
        g.pop()
        if tf >= 0 and tf < MenuBrand.PULSE.dur then
            local a = MenuBrand.PULSE.alpha * (1 - tf / MenuBrand.PULSE.dur) ^ 2
            g.setBlendMode("add")
            g.setColor(1, 0.94, 0.82, a)
            g.rectangle("fill", 0, 0, L.W, L.H)
            g.setBlendMode("alpha")
        end
    end

    g.pop()
    g.setColor(1, 1, 1, 1)
    alphaMul = 1
    return true
end

function MenuBrand:wordRect()
    local L = self._layout
    if not L then return nil end
    return L.ox / L.k, L.oy / L.k,
        Data.word.w * L.P / L.k, Data.word.h * L.P / L.k, L.P
end

return MenuBrand
