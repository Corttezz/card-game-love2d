-- src/ui/BootFX.lua
-- Vórtice procedural da ENTRADA (v3, Jul/2026). Feedback do dono: o loop puro
-- do PixelLab "piscava/quebrava" (cada frame é redesenhado pela IA → shimmer)
-- e o fundo não refletia as cartas indo pro centro. Solução: base PIXEL ART
-- ESTÁTICA (sem flicker) + este vórtice em CÓDIGO — buraco abrindo na pedra,
-- rachaduras, eletricidade e brasas SUGADAS pro centro. Tudo suave e dirigido
-- por `intensity` 0..1, sincronizado à convergência das cartas.
--
-- API:
--   BootFX.reset()
--   BootFX.update(dt, intensity)          -- 0..1 (quanto o buraco está aberto)
--   BootFX.draw(cx, cy, baseRadius, intensity)
--
-- RNG: cosmético → love.math.random global (regra do projeto).

local Palette = require("src.ui.Palette")

local BootFX = {}

local GOLD_L = { 0.98, 0.82, 0.36 }
local GOLD   = { 0.80, 0.60, 0.18 }
local BLOODY = { 0.70, 0.16, 0.12 }
local SPARK  = { 0.72, 0.92, 1.00 }   -- azul-elétrico

local NUM_CRACKS   = 9
local CRACK_SEGS   = 7
local NUM_ARMS     = 3
local ARM_TURNS    = 1.6
local MAX_PARTS    = 64

local state = {
    rot = 0,
    cracks = nil,      -- {angle, segs={{da,dr}...}}
    bolts = {},        -- {points={x,y,...}, life, maxlife}
    boltTimer = 0,
    parts = {},        -- brasas sugadas {angle, r, spin, size, life, maxlife, col}
    partTimer = 0,
}

function BootFX.reset()
    state.rot = 0
    state.bolts = {}
    state.parts = {}
    state.boltTimer = 0
    state.partTimer = 0
    -- rachaduras: jitter FIXO por reset (não muda por frame → não pisca)
    local cracks = {}
    for i = 1, NUM_CRACKS do
        local segs = {}
        for s = 1, CRACK_SEGS do
            segs[s] = {
                da = (love.math.random() - 0.5) * 0.5,   -- desvio angular
                dr = 0.7 + love.math.random() * 0.6,      -- passo radial relativo
            }
        end
        cracks[i] = {
            angle = (i - 1) * (math.pi * 2 / NUM_CRACKS)
                + (love.math.random() - 0.5) * 0.3,
            segs = segs,
        }
    end
    state.cracks = cracks
end

-- ============== Update ==============

local function spawnBolt(maxR)
    -- raio jagged do aro até o centro (ou cruzando)
    local a = love.math.random() * math.pi * 2
    local r0 = maxR * (0.85 + love.math.random() * 0.5)
    local x0, y0 = math.cos(a) * r0, math.sin(a) * r0
    local pts = {}
    local steps = 6 + love.math.random(0, 3)
    for k = 0, steps do
        local t = k / steps
        -- interpola do aro (x0,y0) até o centro (0,0), com jitter perpendicular
        local bx, by = x0 * (1 - t), y0 * (1 - t)
        local perpA = a + math.pi / 2
        local jit = (love.math.random() - 0.5) * maxR * 0.32 * (1 - t)
        pts[#pts + 1] = bx + math.cos(perpA) * jit
        pts[#pts + 1] = by + math.sin(perpA) * jit
    end
    state.bolts[#state.bolts + 1] = { points = pts, life = 0.14, maxlife = 0.14 }
end

local function spawnPart(maxR)
    if #state.parts >= MAX_PARTS then return end
    local warm = love.math.random() < 0.6
    state.parts[#state.parts + 1] = {
        angle = love.math.random() * math.pi * 2,
        r     = maxR * (1.4 + love.math.random() * 0.8),
        spin  = (1.4 + love.math.random() * 1.8),   -- rad/s de órbita ao cair
        size  = 1 + love.math.random() * 2,
        life  = 0, maxlife = 0.5 + love.math.random() * 0.4,
        col   = warm and GOLD_L or BLOODY,
    }
end

function BootFX.update(dt, intensity)
    if not state.cracks then BootFX.reset() end
    intensity = math.max(0, math.min(1, intensity or 0))
    state.rot = state.rot + dt * (0.6 + 1.8 * intensity)   -- gira mais rápido ao abrir

    -- eletricidade: cadência sobe com a intensidade
    state.boltTimer = state.boltTimer - dt
    local boltEvery = 0.13 - 0.09 * intensity
    if intensity > 0.12 and state.boltTimer <= 0 then
        state.boltTimer = boltEvery
        local n = 1 + math.floor(intensity * 3)
        for _ = 1, n do spawnBolt(BootFX._maxR or 120) end
    end
    for i = #state.bolts, 1, -1 do
        local b = state.bolts[i]
        b.life = b.life - dt
        if b.life <= 0 then table.remove(state.bolts, i) end
    end

    -- brasas sugadas pro centro (espiral pra dentro)
    state.partTimer = state.partTimer - dt
    local partEvery = 0.05 - 0.035 * intensity
    if intensity > 0.1 and state.partTimer <= 0 then
        state.partTimer = partEvery
        spawnPart(BootFX._maxR or 120)
    end
    for i = #state.parts, 1, -1 do
        local p = state.parts[i]
        p.life = p.life + dt
        local t = p.life / p.maxlife
        p.r = p.r * (1 - dt * 2.4)          -- cai pro centro (exponencial)
        p.angle = p.angle + dt * p.spin * (1 + t)  -- acelera a órbita ao cair
        if t >= 1 or p.r < 2 then table.remove(state.parts, i) end
    end
end

-- ============== Draw ==============

local function setCol(c, a) love.graphics.setColor(c[1], c[2], c[3], a) end

function BootFX.draw(cx, cy, baseRadius, intensity)
    intensity = math.max(0, math.min(1, intensity or 0))
    if intensity <= 0.001 then return end
    BootFX._maxR = baseRadius

    local maxR = baseRadius * (0.35 + 0.65 * intensity)  -- buraco cresce
    local prevBlend = love.graphics.getBlendMode()

    love.graphics.push("all")
    love.graphics.translate(cx, cy)

    -- 1) RACHADURAS na pedra (radiais, comprimento ∝ intensidade). Núcleo
    --    quente + glow. Desenhadas em alpha (sobre a pedra).
    local crackLen = baseRadius * (0.4 + 1.7 * intensity)
    for _, cr in ipairs(state.cracks) do
        local a = cr.angle
        local px, py = 0, 0
        local pts = { 0, 0 }
        local rr = maxR * 0.6
        for _, seg in ipairs(cr.segs) do
            a = a + seg.da * 0.4
            rr = rr + seg.dr * (crackLen / CRACK_SEGS)
            px = math.cos(a) * rr
            py = math.sin(a) * rr
            pts[#pts + 1] = px
            pts[#pts + 1] = py
        end
        love.graphics.setLineWidth(3)
        setCol({ 0, 0, 0 }, 0.55 * intensity)      -- sombra da fenda
        love.graphics.line(pts)
        love.graphics.setLineWidth(1.5)
        setCol(GOLD_L, 0.85 * intensity)            -- brilho quente na fenda
        love.graphics.line(pts)
    end

    -- daqui pra baixo: additivo (glow/energia)
    love.graphics.setBlendMode("add")

    -- 2) GLOW radial no centro (bloom dourado pulsante)
    local pulse = 0.85 + 0.15 * math.sin(love.timer.getTime() * 8)
    for k = 5, 1, -1 do
        local rr = maxR * (0.6 + k * 0.42)
        setCol(GOLD, (0.05 + 0.04 * intensity) * pulse)
        love.graphics.circle("fill", 0, 0, rr, 40)
    end

    -- 3) VÓRTICE: braços espirais girando pra dentro (sensação de sucção)
    love.graphics.setLineWidth(2)
    for arm = 1, NUM_ARMS do
        local phase = state.rot + arm * (math.pi * 2 / NUM_ARMS)
        local pts = {}
        local steps = 26
        for s = 0, steps do
            local k = s / steps
            local r = maxR * (1.05 - k)           -- do aro pro centro
            local ang = phase + k * ARM_TURNS * math.pi * 2
            pts[#pts + 1] = math.cos(ang) * r
            pts[#pts + 1] = math.sin(ang) * r
        end
        setCol(arm % 2 == 0 and BLOODY or GOLD_L, 0.5 * intensity + 0.2)
        love.graphics.line(pts)
    end

    -- 4) BURACO escuro no miolo (o "vazio" que suga) — em alpha por cima do glow
    love.graphics.setBlendMode("alpha")
    local holeR = maxR * 0.5 * intensity
    if holeR > 1 then
        setCol({ 0.02, 0.01, 0.03 }, 0.92 * intensity)
        love.graphics.circle("fill", 0, 0, holeR, 36)
        -- aro incandescente do buraco
        love.graphics.setLineWidth(2 + 2 * intensity)
        setCol(GOLD_L, 0.9 * intensity)
        love.graphics.circle("line", 0, 0, holeR, 36)
    end

    -- 5) BRASAS sugadas (espiral pra dentro) — additivo
    love.graphics.setBlendMode("add")
    for _, p in ipairs(state.parts) do
        local x = math.cos(p.angle) * p.r
        local y = math.sin(p.angle) * p.r
        local a = 1 - (p.life / p.maxlife)
        setCol(p.col, 0.8 * a)
        love.graphics.circle("fill", x, y, p.size, 6)
    end

    -- 6) ELETRICIDADE (raios jagged brilhantes) por cima de tudo
    love.graphics.setLineWidth(2)
    for _, b in ipairs(state.bolts) do
        local a = b.life / b.maxlife
        setCol(GOLD_L, 0.35 * a)           -- glow dourado largo
        love.graphics.setLineWidth(4)
        love.graphics.line(b.points)
        setCol(SPARK, 0.95 * a)            -- núcleo azul-elétrico fino
        love.graphics.setLineWidth(1.5)
        love.graphics.line(b.points)
    end

    love.graphics.setBlendMode(prevBlend)
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
end

return BootFX
