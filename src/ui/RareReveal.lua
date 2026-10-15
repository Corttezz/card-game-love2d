local Palette = require("src.ui.Palette")

local RareReveal = {}

RareReveal.CHARGE = 0.75
RareReveal.SIGNATURE_AT = 0.55
RareReveal.FLASH = 0.35
RareReveal.SPARKS = 40
RareReveal.SETTLE = 1.6

local GOLD = Palette.AGED_GOLD
local GOLD_LIGHT = Palette.AGED_GOLD_LIGHT
local GOLD_HOT = Palette.TOAST_GOLD
local CREAM = Palette.PARCHMENT_LIGHT

local function rnd(st, a, b)
    st.seed = (st.seed * 1103515245 + 12345) % 2147483648
    local u = st.seed / 2147483648
    return a + (b - a) * u
end

function RareReveal.new(opts)
    opts = opts or {}
    return {
        t = -(opts.delay or 0),
        reduced = opts.reduced and true or false,
        seed = opts.seed or 7919,
        burstDone = false,
        sigDone = false,
        motes = {},
        sparks = {},
        dust = {},
        moteAcc = 0,
        dustAcc = 0,
    }
end

function RareReveal.hidden(st)
    if not st or st.reduced then return false end
    return st.t < RareReveal.CHARGE
end

function RareReveal.started(st)
    return st ~= nil and st.t >= 0
end

function RareReveal.sinceBurst(st)
    if not st then return math.huge end
    if st.reduced then return st.t end
    return st.t - RareReveal.CHARGE
end

function RareReveal.settled(st)
    return st ~= nil and RareReveal.sinceBurst(st) >= RareReveal.SETTLE
end

local function spawnBurst(st, w, h)
    for i = 1, RareReveal.SPARKS do
        local ang = (i / RareReveal.SPARKS) * math.pi * 2 + rnd(st, -0.2, 0.2)
        local sp = rnd(st, 110, 270)
        st.sparks[#st.sparks + 1] = {
            x = math.cos(ang) * w * 0.25, y = math.sin(ang) * h * 0.25,
            vx = math.cos(ang) * sp, vy = math.sin(ang) * sp - 60,
            life = rnd(st, 0.55, 1.1), age = 0,
            size = (i % 3 == 0) and 3 or 2,
            hot = (i % 4 == 0),
        }
    end
end

function RareReveal.update(st, dt, w, h, hooks)
    if not st then return end
    hooks = hooks or {}
    local before = st.t
    st.t = st.t + dt
    w, h = w or 120, h or 180

    if st.reduced then
        if before < 0 and st.t >= 0 and not st.burstDone then
            st.burstDone = true
            if hooks.onBurst then hooks.onBurst(true) end
        end
        if st.t >= RareReveal.SIGNATURE_AT and not st.sigDone and st.burstDone then
            st.sigDone = true
            if hooks.onSignature then hooks.onSignature() end
        end
        return
    end

    if before < 0 and st.t >= 0 and hooks.onCharge then hooks.onCharge() end

    if st.t >= 0 and st.t < RareReveal.CHARGE then
        st.moteAcc = st.moteAcc + dt
        while st.moteAcc >= 0.012 do
            st.moteAcc = st.moteAcc - 0.012
            local ang = rnd(st, 0, math.pi * 2)
            local r = rnd(st, 0.7, 1.1) * math.max(w, h) * 0.75
            st.motes[#st.motes + 1] = { ang = ang, r0 = r, age = 0, life = rnd(st, 0.28, 0.42),
                size = rnd(st, 0, 1) < 0.3 and 3 or 2 }
        end
    end

    for i = #st.motes, 1, -1 do
        local m = st.motes[i]
        m.age = m.age + dt
        if m.age >= m.life then table.remove(st.motes, i) end
    end

    if st.t >= RareReveal.CHARGE and not st.burstDone then
        st.burstDone = true
        st.motes = {}
        spawnBurst(st, w, h)
        if hooks.onBurst then hooks.onBurst(false) end
    end

    if st.burstDone and not st.sigDone and RareReveal.sinceBurst(st) >= RareReveal.SIGNATURE_AT then
        st.sigDone = true
        if hooks.onSignature then hooks.onSignature() end
    end

    for i = #st.sparks, 1, -1 do
        local s = st.sparks[i]
        s.age = s.age + dt
        s.vy = s.vy + 380 * dt
        s.vx = s.vx * (1 - 1.2 * dt)
        s.x = s.x + s.vx * dt
        s.y = s.y + s.vy * dt
        if s.age >= s.life then table.remove(st.sparks, i) end
    end

    if st.burstDone then
        st.dustAcc = st.dustAcc + dt
        while st.dustAcc >= 0.22 do
            st.dustAcc = st.dustAcc - 0.22
            st.dust[#st.dust + 1] = { x = rnd(st, -0.45, 0.45) * w, y = h * rnd(st, 0.25, 0.5),
                vy = -rnd(st, 18, 34), age = 0, life = rnd(st, 1.4, 2.2), phase = rnd(st, 0, 6.28) }
        end
    end
    for i = #st.dust, 1, -1 do
        local d = st.dust[i]
        d.age = d.age + dt
        d.y = d.y + d.vy * dt
        if d.age >= d.life then table.remove(st.dust, i) end
    end
end


RareReveal.PIX = 3

local function setc(c, a)
    love.graphics.setColor(c[1], c[2], c[3], a)
end

local canvasCache = { canvas = nil, size = 0 }

local function pixelLayer(cx, cy, half, fn)
    local P = RareReveal.PIX
    local size = math.ceil(half * 2 / P)
    if canvasCache.size ~= size or not canvasCache.canvas then
        canvasCache.canvas = love.graphics.newCanvas(size, size)
        canvasCache.canvas:setFilter("nearest", "nearest")
        canvasCache.size = size
    end
    local c = canvasCache.canvas
    love.graphics.push("all")
    love.graphics.setCanvas(c)
    love.graphics.origin()
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.translate(size / 2, size / 2)
    love.graphics.scale(1 / P, 1 / P)
    love.graphics.setBlendMode("add", "alphamultiply")
    fn()
    love.graphics.pop()
    love.graphics.push("all")
    love.graphics.setBlendMode("add", "premultiplied")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(c, math.floor(cx - size * P / 2), math.floor(cy - size * P / 2), 0, P, P)
    love.graphics.pop()
end

local function drawRays(len, alpha, rot, count)
    if alpha <= 0.003 then return end
    for i = 0, count - 1 do
        local a = rot + i * (math.pi * 2 / count)
        local major = i % 2 == 0
        local half = major and 0.06 or 0.035
        local l = major and len or len * 0.7
        setc(major and GOLD_LIGHT or GOLD, alpha * (major and 1 or 0.7))
        love.graphics.polygon("fill", 0, 0,
            math.cos(a - half) * l, math.sin(a - half) * l,
            math.cos(a + half) * l, math.sin(a + half) * l)
    end
end

local function drawGlow(w, h, alpha)
    if alpha <= 0.003 then return end
    local P = RareReveal.PIX
    for i = 4, 1, -1 do
        local g = i * P * 2
        setc(GOLD, alpha * (0.2 / i))
        love.graphics.rectangle("fill", -w / 2 - g, -h / 2 - g, w + g * 2, h + g * 2)
    end
end

local function regionHalf(w, h)
    return math.max(w, h) * 0.95 + 90
end

function RareReveal.drawBack(st, cx, cy, w, h)
    if not RareReveal.started(st) then return end
    local now = love.timer.getTime()
    local P = RareReveal.PIX
    pixelLayer(cx, cy, regionHalf(w, h), function()
        if st.reduced then
            drawGlow(w, h, 0.6)
            drawRays(h * 0.78, 0.12, 0, 12)
        elseif st.t < RareReveal.CHARGE then
            local k = st.t / RareReveal.CHARGE
            local pulse = 0.5 + 0.5 * math.sin(now * 18)
            setc(GOLD, 0.06 + 0.16 * k * k)
            love.graphics.rectangle("fill", -w / 2, -h / 2, w, h)
            local beamW = P * (1 + math.floor(3 * k))
            setc(GOLD_LIGHT, 0.12 + 0.3 * k)
            love.graphics.rectangle("fill", -beamW / 2, -h / 2 - 24, beamW, h + 48)
            setc(GOLD_LIGHT, 0.35 + 0.55 * k)
            love.graphics.setLineWidth(P)
            love.graphics.rectangle("line", -w / 2, -h / 2, w, h)
            love.graphics.setLineWidth(1)
            local r = P * (1 + 5 * k) + pulse * P
            setc(GOLD_HOT, 0.45 + 0.5 * k)
            love.graphics.rectangle("fill", -r, -r, r * 2, r * 2)
            setc(CREAM, 0.6 * k)
            love.graphics.rectangle("fill", -r / 2, -r / 2, r, r)
        else
            local a = RareReveal.sinceBurst(st)
            local settle = math.min(1, a / RareReveal.SETTLE)
            local rayA = 0.32 - 0.20 * settle + 0.03 * math.sin(now * 2.2)
            drawRays(h * (0.6 + 0.2 * math.min(1, a * 3)), rayA, now * 0.22, 12)
            drawGlow(w, h, 0.75 - 0.3 * settle + 0.08 * math.sin(now * 2.6))
        end
    end)
    love.graphics.setColor(1, 1, 1, 1)
end

function RareReveal.drawFront(st, cx, cy, w, h)
    if not RareReveal.started(st) or st.reduced then return end
    local now = love.timer.getTime()
    local P = RareReveal.PIX
    pixelLayer(cx, cy, regionHalf(w, h), function()
        for _, m in ipairs(st.motes) do
            local k = m.age / m.life
            local r = m.r0 * (1 - k * k)
            local s = m.size == 3 and P * 2 or P
            setc(m.size == 3 and GOLD_HOT or GOLD_LIGHT, 0.5 + 0.5 * k)
            love.graphics.rectangle("fill", math.cos(m.ang) * r, math.sin(m.ang) * r, s, s)
        end

        local a = RareReveal.sinceBurst(st)
        if st.burstDone and a < RareReveal.FLASH then
            local k = a / RareReveal.FLASH
            setc(GOLD_LIGHT, 0.7 * (1 - k) * (1 - k))
            love.graphics.rectangle("fill", -w / 2, -h / 2, w, h)
            local ring = (0.35 + 1.0 * k) * math.max(w, h) * 0.6
            setc(GOLD_HOT, 0.9 * (1 - k))
            love.graphics.setLineWidth(P)
            love.graphics.circle("line", 0, 0, ring, 32)
            love.graphics.setLineWidth(1)
        end

        for _, s in ipairs(st.sparks) do
            local k = s.age / s.life
            local sz = s.size == 3 and P * 2 or P
            setc(s.hot and CREAM or GOLD_HOT, 1 - k)
            love.graphics.rectangle("fill", s.x, s.y, sz, sz)
        end

        for _, d in ipairs(st.dust) do
            local k = d.age / d.life
            local alpha = (k < 0.2 and k / 0.2 or 1) * (1 - k) * 0.85
            setc(GOLD_LIGHT, alpha)
            love.graphics.rectangle("fill", d.x + math.sin(now * 2 + d.phase) * 4, d.y, P, P)
        end
    end)
    love.graphics.setColor(1, 1, 1, 1)
end

return RareReveal
