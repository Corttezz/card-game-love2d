local Debug = require("src.core.Debug")

local AURAS = require("src.data.boss_auras")

local BossAura = {}

local warned = {}
local state = {}
local glowImg = nil
local musicGlow = { t = 0, k = 0 }
BossAura.MUSIC_PULSE_DUR = 0.7
local edgeCache = {}

local function reducedMotion()
    return (_G.gameSettings and _G.gameSettings.reducedMotion) or false
end

function BossAura.has(id)
    return AURAS[id] ~= nil
end

function BossAura.get(id)
    local a = AURAS[id]
    if not a and id and not warned[id] then
        warned[id] = true
        Debug.warn("[BossAura] AVISO: chefe sem aura declarada: " .. tostring(id)
            .. " (src/data/boss_auras.lua)")
    end
    return a
end

local function getGlow()
    if glowImg then return glowImg end
    local n = 16
    local data = love.image.newImageData(n, n)
    local steps = { 0.55, 0.32, 0.16, 0.06 }
    for y = 0, n - 1 do
        for x = 0, n - 1 do
            local dx, dy = (x + 0.5 - n / 2) / (n / 2), (y + 0.5 - n / 2) / (n / 2)
            local d = math.sqrt(dx * dx + dy * dy)
            local a = 0
            if d < 0.30 then a = steps[1]
            elseif d < 0.55 then a = steps[2]
            elseif d < 0.80 then a = steps[3]
            elseif d < 1.00 then a = steps[4] end
            data:setPixel(x, y, 1, 1, 1, a)
        end
    end
    glowImg = love.graphics.newImage(data)
    glowImg:setFilter("nearest", "nearest")
    return glowImg
end

local function rnd(range)
    if type(range) ~= "table" then return range or 0 end
    return range[1] + love.math.random() * (range[2] - range[1])
end

local function getState(id)
    local s = state[id]
    if not s then
        s = { t = 0, back = {}, front = {}, acc = {}, timers = {}, fade = 1 }
        state[id] = s
    end
    return s
end

local function edges(id)
    if edgeCache[id] ~= nil then return edgeCache[id] end
    local path = "assets/sprites/characters/enemies/" .. id
        .. "/animations/idle/south/0.png"
    local e = false
    if love.filesystem.getInfo(path) then
        local ok, data = pcall(love.image.newImageData, path)
        if ok and data then
            e = { left = {}, right = {}, w = data:getWidth(), h = data:getHeight() }
            for y = 0, e.h - 1 do
                for x = 0, e.w - 1 do
                    local _, _, _, a = data:getPixel(x, y)
                    if a > 0.5 then e.left[y] = x; break end
                end
                for x = e.w - 1, 0, -1 do
                    local _, _, _, a = data:getPixel(x, y)
                    if a > 0.5 then e.right[y] = x; break end
                end
            end
        end
    end
    if not e then
        Debug.warn("[BossAura] AVISO: sem quadro 0 do idle pra borda de " .. id)
    end
    edgeCache[id] = e
    return e
end

function BossAura.musicPulse(k)
    musicGlow.t = BossAura.MUSIC_PULSE_DUR
    musicGlow.k = math.max(0, math.min(1, k or 0.5))
end

function BossAura.musicLevel()
    if musicGlow.t <= 0 then return 0 end
    local p = 1 - musicGlow.t / BossAura.MUSIC_PULSE_DUR
    local env = (p < 0.15) and (p / 0.15) or (1 - (p - 0.15) / 0.85)
    return musicGlow.k * 0.8 * math.max(0, env)
end

function BossAura.reset()
    musicGlow.t = 0
    state = {}
end

local function pickTarget(w, f, iw, ih)
    local a = love.math.random() * 6.283
    local d = 0.35 + 0.65 * math.sqrt(love.math.random())
    f.tx = (w.cu + math.cos(a) * w.ru * d) * iw
    f.ty = (w.cv + math.sin(a) * w.rv * d) * ih
    f.retarget = 0.25 + love.math.random() * 0.9
    if love.math.random() < 0.5 then f.front = not f.front end
end

function BossAura._updateSwarm(w, s, dt)
    local iw, ih = s.iw or 0, s.ih or 0
    if iw == 0 then return end
    if not s.flies then
        s.flies = {}
        for i = 1, w.n do
            local f = { vx = 0, vy = 0, front = (i % 2 == 0),
                        maxV = w.speed[1] + love.math.random() * (w.speed[2] - w.speed[1]),
                        ph = love.math.random() * 6.283 }
            pickTarget(w, f, iw, ih)
            f.x, f.y = f.tx, f.ty
            pickTarget(w, f, iw, ih)
            s.flies[i] = f
        end
    end
    for _, f in ipairs(s.flies) do
        f.retarget = f.retarget - dt
        if f.retarget <= 0 then pickTarget(w, f, iw, ih) end
        local dx, dy = f.tx - f.x, f.ty - f.y
        local d = math.sqrt(dx * dx + dy * dy) + 1e-6
        local acc = f.maxV * 6
        f.vx = f.vx + dx / d * acc * dt
        f.vy = f.vy + dy / d * acc * dt
        local j = math.sin(s.t * 23 + f.ph) * f.maxV * 0.8
        f.vx = f.vx - dy / d * j * dt * 4
        f.vy = f.vy + dx / d * j * dt * 4
        local v = math.sqrt(f.vx * f.vx + f.vy * f.vy)
        if v > f.maxV then f.vx, f.vy = f.vx / v * f.maxV, f.vy / v * f.maxV end
        f.x = f.x + f.vx * dt
        f.y = f.y + f.vy * dt
    end
end

BossAura.FLOCK = { enter = 0.95, leave = 0.8, stagger = 0.24, big = 2 }

local crowFrames = {}

local HIT_FEATHER = { kind = "feather", px = 2, sway = 6,
                      color = { 0.16, 0.12, 0.26 }, color2 = { 0.62, 0.54, 0.95 } }

local function flockSpec(spec)
    local o = spec and spec.orbit
    if o and o.countBy then return o end
    return nil
end

local function hash01(i, k)
    return (math.sin(i * k) * 43758.5453) % 1
end

function BossAura.playerTarget()
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    return math.max(100, W * 0.12), H - math.max(110, H * 0.17)
end

function BossAura.setCount(id, n)
    local spec = AURAS[id]
    if not flockSpec(spec) then return end
    getState(id).want = math.max(0, math.floor(n or 0))
end

function BossAura.setCountFrom(id, enemy)
    local o = flockSpec(AURAS[id])
    if not o or not enemy or not enemy.getStatusStacks then return end
    getState(id).want = math.max(0, math.floor(enemy:getStatusStacks(o.countBy) or 0))
end

function BossAura.flockCount(id)
    local s = state[id]
    if not s or not s.flock then return 0 end
    local n = 0
    for _, c in ipairs(s.flock) do
        if c.phase ~= "leave" then n = n + 1 end
    end
    return n
end

function BossAura.flockPhases(id)
    local out = {}
    local s = state[id]
    for _, c in ipairs((s and s.flock) or {}) do
        out[c.phase] = (out[c.phase] or 0) + 1
    end
    return out
end

local function syncFlock(o, s, dt, still)
    s.flock = s.flock or {}
    local fl = s.flock
    local F = BossAura.FLOCK
    local want = math.min(o.max or 10, s.want or 0)
    local instant = still or not s.flockInit
    s.flockInit = true
    local alive = {}
    for _, c in ipairs(fl) do
        if c.phase ~= "leave" then alive[#alive + 1] = c end
    end
    local added = 0
    while #alive < want do
        s.serial = (s.serial or 0) + 1
        local c = { seed = s.serial, h1 = hash01(s.serial, 12.9898),
                    h2 = hash01(s.serial, 78.233),
                    side = (s.serial % 2 == 0) and -1 or 1,
                    phase = instant and "orbit" or "enter",
                    t = -F.stagger * added, off = nil }
        added = added + 1
        fl[#fl + 1] = c
        alive[#alive + 1] = c
    end
    while #alive > want do
        local c = table.remove(alive)
        if still then
            c.phase, c.t = "gone", 0
        else
            c.phase, c.t = "leave", 0
        end
    end
    local n = #alive
    for j, c in ipairs(alive) do
        local goal = (j - 1) / math.max(1, n) * 6.283
        if not c.off then
            c.off = goal
        else
            local d = (goal - c.off + math.pi) % 6.283 - math.pi
            c.off = c.off + d * math.min(1, dt * 2.2)
        end
    end
    if not still then s.rot = (s.rot or 0) + dt * o.speed end
    for i = #fl, 1, -1 do
        local c = fl[i]
        c.t = c.t + dt
        if c.phase == "enter" and c.t >= F.enter then
            c.phase, c.t = "orbit", 0
        elseif c.phase == "dive" then
            if not c.hit and c.t >= c.apex then
                c.hit = true
                local tx, ty = s.tgtX, s.tgtY
                if tx and #s.front < 90 then
                    for k = 1, 9 do
                        local a = -math.pi * (0.1 + 0.8 * love.math.random())
                        local sp = 14 + love.math.random() * 22
                        local life = 0.7 + love.math.random() * 0.5
                        s.front[#s.front + 1] = {
                            em = HIT_FEATHER, u = tx / s.iw, v = ty / s.ih,
                            ax = (k - 5) * 1.2, ay = 0,
                            vx = math.cos(a) * sp, vy = math.sin(a) * sp * 0.6 + 6,
                            life = life, max = life, ph = love.math.random() * 6.283,
                            sf = 1.5 + love.math.random() * 1.5, st = 0,
                        }
                    end
                end
            end
            if c.t >= c.apex + c.back then c.phase, c.t, c.hit = "orbit", 0, nil end
        elseif (c.phase == "leave" and c.t >= F.leave) or c.phase == "gone" then
            table.remove(fl, i)
        end
    end
end

function BossAura.dive(id, apex, back)
    if reducedMotion() then return false end
    local s = state[id]
    if not s or not s.flock then return false end
    local pool = {}
    for _, c in ipairs(s.flock) do
        if c.phase == "orbit" then pool[#pool + 1] = c end
    end
    if #pool == 0 then return false end
    s.diveIdx = ((s.diveIdx or 0) % #pool) + 1
    local c = pool[s.diveIdx]
    c.phase, c.t, c.apex, c.back, c.hit = "dive", 0, apex or 0.34, back or 0.42, nil
    return true
end

function BossAura.hitFeathers(id)
    local spec = AURAS[id]
    local s = state[id]
    if not spec or not spec.hitFeathers or not s or not s.tgtX or reducedMotion() then
        return
    end
    for k = 1, spec.hitFeathers do
        if #s.front >= 90 then break end
        local a = -math.pi * love.math.random()
        local sp = 10 + love.math.random() * 18
        local life = 0.6 + love.math.random() * 0.5
        s.front[#s.front + 1] = {
            em = HIT_FEATHER, u = s.tgtX / s.iw, v = s.tgtY / s.ih,
            ax = (k - spec.hitFeathers / 2) * 1.5, ay = 0,
            vx = math.cos(a) * sp, vy = math.sin(a) * sp * 0.6 + 6,
            life = life, max = life, ph = love.math.random() * 6.283,
            sf = 1.5 + love.math.random() * 1.5, st = 0,
        }
    end
end

function BossAura.update(dt, id, dying)
    if not id then return end
    local spec = AURAS[id]
    if not spec then return end
    local s = getState(id)
    s.t = s.t + dt
    if musicGlow.t > 0 then musicGlow.t = math.max(0, musicGlow.t - dt) end
    local flock = flockSpec(spec)
    if flock then syncFlock(flock, s, dt, reducedMotion()) end
    if dying then
        s.fade = math.max(0, s.fade - dt / 0.6)
    else
        s.fade = math.min(1, s.fade + dt / 0.4)
    end

    local still = reducedMotion()
    if not still and not dying and spec.emit then
        for i, em in ipairs(spec.emit) do
            local n = 0
            local spot = nil
            if em.kind == "ooze" then
                s.spots = s.spots or {}
                s.spots[i] = s.spots[i] or {}
                for si, sp in ipairs(em.spots) do
                    local tm = (s.spots[i][si] or rnd(em.interval)) - dt
                    if tm <= 0 and not spot then
                        spot = sp
                        n = 1
                        tm = rnd(em.interval)
                    end
                    s.spots[i][si] = tm
                end
            elseif em.every then
                s.timers[i] = (s.timers[i] or (em.every * 0.5)) - dt
                if s.timers[i] <= 0 then
                    s.timers[i] = em.every * (0.65 + 0.7 * love.math.random())
                    n = em.burst or 1
                end
            else
                s.acc[i] = (s.acc[i] or (-math.log(1 - love.math.random()) / (em.rate or 1))) - dt
                while s.acc[i] <= 0 and n < 6 do
                    n = n + 1
                    s.acc[i] = s.acc[i] - math.log(1 - love.math.random()) / (em.rate or 1)
                end
            end
            for _ = 1, n do
                local u, v
                if spot then
                    u, v = spot[1], spot[2]
                elseif em.points then
                    local p = em.points[love.math.random(#em.points)]
                    u, v = p[1], p[2]
                else
                    local ar = em.area
                    u = ar[1] + love.math.random() * (ar[3] - ar[1])
                    v = ar[2] + love.math.random() * (ar[4] - ar[2])
                end
                local life = rnd(em.life or { 1, 2 })
                local list = em.back and s.back or s.front
                if #list < 90 then
                    list[#list + 1] = {
                        em = em, u = u, v = v, ax = 0, ay = 0,
                        vx = rnd(em.vx), vy = rnd(em.vy),
                        life = life, max = life,
                        ph = love.math.random() * 6.283,
                        big = love.math.random() < (em.big or 0),
                        sf = 1.2 + love.math.random() * 1.8,
                        state = (em.kind == "ooze") and "form" or nil,
                        st = 0, formDur = rnd(em.form or { 0.8, 1.6 }),
                    }
                end
            end
        end
    end

    if spec.swarm and not still then
        BossAura._updateSwarm(spec.swarm, s, dt)
    end

    for _, list in ipairs({ s.back, s.front }) do
        for i = #list, 1, -1 do
            local p = list[i]
            p.life = p.life - dt
            if p.life <= 0 then
                table.remove(list, i)
            elseif not still then
                local em = p.em
                if em.kind == "ooze" then
                    p.st = p.st + dt
                    if p.state == "form" then
                        if p.st >= p.formDur then
                            p.state, p.st, p.vy = "fall", 0, 4
                            p.ay = 2
                        end
                    elseif p.state == "fall" then
                        p.vy = p.vy + (em.gravity or 90) * dt
                        p.ay = p.ay + p.vy * dt
                        local g = s.groundArt
                        if g and p.v * (s.ih or 0) + p.ay >= g - 1 then
                            p.state, p.st = "splash", 0
                            p.ay = g - 1 - p.v * s.ih
                            p.life = 0.55
                            p.max = 0.55
                            p.sx = 7 + love.math.random() * 7
                            p.sy = -(9 + love.math.random() * 6)
                        end
                    end
                else
                    p.ax = p.ax + p.vx * dt
                    p.ay = p.ay + p.vy * dt
                    if em.kind == "breath" or em.kind == "smoke" then
                        p.vx = p.vx * (1 - 0.9 * dt)
                    end
                end
            end
        end
    end
end

local floor = math.floor

local KX, KY, K = 0, 0, 1
local function setK(ax, ay, k)
    KX, KY, K = ax, ay, k or 1
end

local function artRect(r, ax, ay, nw, nh)
    if K ~= 1 then
        ax = KX + (ax - KX) * K
        ay = KY + (ay - KY) * K
        nw = (nw or 1) * K
        nh = (nh or 1) * K
    end
    local P = r.scale
    local x = r.x + floor(ax + 0.5) * P
    local y = r.y + floor(ay + 0.5) * P
    love.graphics.rectangle("fill", floor(x), floor(y),
        math.ceil(P * (nw or 1)), math.ceil(P * (nh or 1)))
end

local function drawGlows(r, spec, s, fade)
    if not spec.glows then return end
    local img = getGlow()
    local t = s.t
    local still = reducedMotion()
    love.graphics.setBlendMode("add")
    for i, g in ipairs(spec.glows) do
        local k = 1
        if g.beat then
            local ph = (t % g.beat) / g.beat
            local b1 = math.max(0, 1 - math.abs(ph - 0.10) / 0.08)
            local b2 = math.max(0, 1 - math.abs(ph - 0.30) / 0.08)
            k = 0.55 + 0.6 * math.max(b1, b2 * 0.75)
        elseif g.pulse and not still then
            k = 0.78 + 0.22 * math.sin(t * g.pulse + i)
        end
        local a = (g.a or 0.4) * k * fade * (1 + BossAura.musicLevel())
        local rad = (g.r or 4) * r.scale * (0.92 + 0.08 * k)
        local x = r.x + g.u * r.w
        local y = r.y + g.v * r.h
        local sc = (rad * 2) / img:getWidth()
        love.graphics.setColor(g.color[1], g.color[2], g.color[3], a)
        love.graphics.draw(img, floor(x - rad), floor(y - rad), 0, sc, sc)
    end
    love.graphics.setBlendMode("alpha")
end

local function parseShape(rows)
    local pts = {}
    local h, w = #rows, #rows[1]
    for y, row in ipairs(rows) do
        for x = 1, #row do
            local ch = row:sub(x, x)
            if ch ~= "." then
                pts[#pts + 1] = { x - 1 - floor(w / 2), y - 1 - floor(h / 2), ch == "o" }
            end
        end
    end
    return pts
end
local CROW = {
    parseShape({
        "#.......#",
        "##.....##",
        ".##.#.##.",
        "..##o##..",
        "....#....",
    }),
    parseShape({
        ".........",
        "....#....",
        "###.o.###",
        "..##o##..",
        "....#....",
    }),
    parseShape({
        ".........",
        "....#....",
        "..##o##..",
        ".##.#.##.",
        "##.....##",
    }),
}
local CROW_SEQ = { 1, 2, 3, 2 }

local RUNES = {
    { { 0, -1 }, { 0, 0 }, { 0, 1 }, { -1, -1 }, { 1, 1 } },
    { { -1, -1 }, { 1, -1 }, { 0, 0 }, { -1, 1 }, { 1, 1 } },
    { { -1, -1 }, { 0, -1 }, { 1, -1 }, { 0, 0 }, { 0, 1 } },
    { { -1, 0 }, { 0, -1 }, { 1, 0 }, { 0, 1 }, { 0, 0 } },
}

local function orbitOne(r, o, s, front)
    local still = reducedMotion()
    local t = still and 0 or s.t
    local fade = s.fade
    for i = 1, o.n do
        local h1, h2, h3 = 0.5, 0.5, 0
        if not o.regular then
            h1 = (math.sin(i * 12.9898) * 43758.5453) % 1
            h2 = (math.sin(i * 78.233) * 12345.678) % 1
            h3 = (math.sin(i * 39.425) * 24634.634) % 1
        end
        local base = (i - 1) / o.n * 6.283 + h3 * 1.4
        local ang = base + t * o.speed * (0.7 + 0.6 * h2)
        local sn = math.sin(ang)
        local isFront = sn > 0
        if isFront == front then
            local cu, cv = o.cu, o.cv
            local ru, rv = o.ru, o.rv
            local u, v
            if o.kind == "fly" then
                u = cu + ru * math.cos(ang) * (0.6 + 0.4 * math.sin(t * 1.7 + i))
                v = cv + rv * math.sin(ang * 1.6 + i)
                if not still then
                    u = u + (love.math.random() - 0.5) * 0.012
                    v = v + (love.math.random() - 0.5) * 0.012
                end
            elseif o.kind == "flake" then
                local rise = ((t * (o.rise or 0.05) * (0.7 + 0.6 * h2) + h1 + i * 0.137) % 1)
                v = cv + 0.40 - rise * 0.85 + rv * sn
                u = cu + ru * math.cos(ang) * (0.75 + 0.25 * rise)
            else
                local rk = 0.8 + 0.4 * h1
                u = cu + ru * rk * math.cos(ang)
                v = cv + rv * rk * sn
                if not o.regular then
                    v = v + 0.025 * math.sin(t * (0.6 + h2) + i * 2.1)
                end
            end
            local ax, ay = u * r.iw, v * r.ih
            local near = isFront and 1 or 0.6
            setK(ax, ay, o.px or 1)
            if o.kind == "crow" then
                local fr = CROW[CROW_SEQ[(floor(t * 7 + i * 1.7) % 4) + 1]]
                local c = o.color
                local hi = o.color2
                local al = fade * (isFront and 1 or 0.75)
                for _, d in ipairs(fr) do
                    local cc = d[3] and hi or c
                    love.graphics.setColor(cc[1], cc[2], cc[3], al)
                    artRect(r, ax + d[1], ay + d[2], 1, 1)
                end
            elseif o.kind == "rune" then
                local g = RUNES[(i - 1) % #RUNES + 1]
                local c = isFront and o.color or o.color2
                love.graphics.setBlendMode("add")
                local pulse = still and 1 or (0.7 + 0.3 * math.sin(s.t * 2.4 + i * 1.3))
                love.graphics.setColor(c[1], c[2], c[3], fade * near * 0.9 * pulse)
                for _, d in ipairs(g) do artRect(r, ax + d[1], ay + d[2], 1, 1) end
                love.graphics.setBlendMode("alpha")
            elseif o.kind == "mote" then
                local c = isFront and o.color or o.color2
                love.graphics.setBlendMode("add")
                love.graphics.setColor(c[1], c[2], c[3], 0.9 * fade * near)
                artRect(r, ax, ay, 1, 1)
                love.graphics.setColor(c[1], c[2], c[3], 0.35 * fade * near)
                artRect(r, ax - math.cos(ang) * 1.5, ay - sn * 0.8, 1, 1)
                love.graphics.setBlendMode("alpha")
            elseif o.kind == "flake" then
                local c = isFront and o.color or o.color2
                love.graphics.setColor(c[1], c[2], c[3], fade * (isFront and 0.95 or 0.55))
                if isFront and i % 3 == 0 then
                    artRect(r, ax, ay, 1, 1)
                    love.graphics.setColor(c[1], c[2], c[3], fade * 0.55)
                    artRect(r, ax - 1, ay, 1, 1); artRect(r, ax + 1, ay, 1, 1)
                    artRect(r, ax, ay - 1, 1, 1); artRect(r, ax, ay + 1, 1, 1)
                else
                    artRect(r, ax, ay, 1, 1)
                end
            elseif o.kind == "fly" then
                local c = isFront and o.color or o.color2
                love.graphics.setColor(c[1], c[2], c[3], fade * (isFront and 1 or 0.7))
                artRect(r, ax, ay, 1, 1)
                local wing = (floor(s.t * 30 + i) % 2 == 0) and -1 or 1
                love.graphics.setColor(0.82, 0.88, 0.74, 0.75 * fade)
                artRect(r, ax + wing * 0.5, ay - 1, 1, 1)
            end
        end
    end
end

local function drawSwarm(r, spec, s, front)
    local w = spec.swarm
    if not w or not s.flies then return end
    for i, f in ipairs(s.flies) do
        if f.front == front then
            setK(f.x, f.y, w.px or 1)
            local c = front and w.color or w.color2
            love.graphics.setColor(c[1], c[2], c[3], s.fade * (front and 1 or 0.7))
            artRect(r, f.x, f.y, 1, 1)
            if floor(s.t * 28 + f.ph * 3) % 2 == 0 then
                love.graphics.setColor(w.wing[1], w.wing[2], w.wing[3], 0.55 * s.fade)
                artRect(r, f.x, f.y - 1, 1, 1)
            end
        end
    end
    setK(0, 0, 1)
end

local function crowOrbitPos(o, s, c, still)
    local ang = (c.off or 0) + (s.rot or 0)
    local rk = 0.8 + 0.4 * c.h1
    local sn = math.sin(ang)
    local u = o.cu + o.ru * rk * math.cos(ang)
    local v = o.cv + o.rv * rk * sn
    if not still then v = v + 0.025 * math.sin(s.t * (0.6 + c.h2) + c.seed * 2.1) end
    return u * (s.iw or 0), v * (s.ih or 0), sn
end

function BossAura._crowPose(o, s, c, still)
    local F = BossAura.FLOCK
    local ox, oy, sn = crowOrbitPos(o, s, c, still)
    if c.phase == "orbit" then return ox, oy, 1, sn > 0, 1 end
    local iw, ih = s.iw or 0, s.ih or 0
    if c.phase == "enter" then
        if c.t < 0 then return nil end
        local k = math.min(1, c.t / F.enter)
        local e = 1 - (1 - k) * (1 - k)
        local sx, sy = (0.5 + c.side * 1.15) * iw, -0.35 * ih
        local mx, my = (0.5 + c.side * 0.35) * iw, 0.95 * ih
        local a1x, a1y = sx + (mx - sx) * e, sy + (my - sy) * e
        local a2x, a2y = mx + (ox - mx) * e, my + (oy - my) * e
        return a1x + (a2x - a1x) * e, a1y + (a2y - a1y) * e,
            (e < 0.55) and F.big or 1, true, math.min(1, k * 4)
    elseif c.phase == "leave" then
        local k = math.min(1, c.t / F.leave)
        local e = k * k
        local ex, ey = (0.5 - c.side * 1.2) * iw, -0.4 * ih
        return ox + (ex - ox) * e, oy + (ey - oy) * e, 1, sn > 0, 1 - e * 0.6
    elseif c.phase == "dive" then
        local tx, ty = s.tgtX or ox, s.tgtY or oy
        if c.t < c.apex then
            local k = c.t / c.apex
            local kk = k * k
            local lift = math.sin(k * math.pi) * 0.10 * ih
            return ox + (tx - ox) * kk, oy + (ty - oy) * kk - lift,
                (kk > 0.30) and F.big or 1, true, 1, "glide"
        end
        local k = math.min(1, (c.t - c.apex) / c.back)
        local e = 1 - (1 - k) * (1 - k)
        return tx + (ox - tx) * e, ty + (oy - ty) * e - math.sin(k * math.pi) * 0.18 * ih,
            (e < 0.6) and F.big or 1, true, 1
    end
    return nil
end

function BossAura.crowFrames(dir)
    if crowFrames[dir] ~= nil then return crowFrames[dir] or nil end
    local list = {}
    for i = 0, 31 do
        local p = dir .. "/frame_" .. i .. ".png"
        if not love.filesystem.getInfo(p) then break end
        local img = love.graphics.newImage(p)
        img:setFilter("nearest", "nearest")
        list[#list + 1] = img
    end
    if #list == 0 then
        Debug.warn("[BossAura] AVISO: corvo sem quadros em " .. tostring(dir))
        crowFrames[dir] = false
        return nil
    end
    crowFrames[dir] = list
    return list
end

function BossAura.crowScale(artScale)
    return math.max(1, floor((artScale or 1) * 0.5 + 0.5))
end

function BossAura.crowSpriteDir(id)
    local a = AURAS[id]
    local o = a and a.orbit
    return (o and o.kind == "crow" and o.sprite) or nil
end

function BossAura.crowFrameIndex(frames, t, h1, phase)
    local n = #frames
    local fps = (phase == "orbit") and 10 or 15
    return (floor(t * fps + (h1 or 0) * n) % n) + 1
end

function BossAura.drawCrowSprite(frames, fi, x, y, face, rot, S, alpha, isFront)
    local img = frames[fi]
    if not img then return end
    if isFront then
        love.graphics.setColor(1, 1, 1, alpha)
    else
        love.graphics.setColor(0.70, 0.68, 0.80, alpha * 0.9)
    end
    love.graphics.draw(img, floor(x), floor(y), rot or 0, (face or 1) * S, S,
        floor(img:getWidth() / 2), floor(img:getHeight() / 2))
end

local function wrapPi(a)
    return (a + math.pi) % 6.283185 - math.pi
end

local function drawFlock(r, o, s, front)
    if not s.flock then return end
    local frames = BossAura.crowFrames(o.sprite)
    if not frames then return end
    local still = reducedMotion()
    local t = still and 0 or s.t
    local n = #frames
    local base = BossAura.crowScale(r.scale)
    for _, c in ipairs(s.flock) do
        local ax, ay, big, isFront, al, mode = BossAura._crowPose(o, s, c, still)
        if ax and isFront == front then
            local x = floor(r.x + ax * r.scale)
            local y = floor(r.y + ay * r.scale)
            local face, rot = c.face or 1, 0
            if c.phase == "orbit" then
                face = isFront and -1 or 1
            elseif c.phase == "dive" and mode == "glide" then
                local tx = r.x + (s.tgtX or ax) * r.scale
                local ty = r.y + (s.tgtY or ay) * r.scale
                local dx, dy = tx - x, ty - y
                face = (dx < 0) and -1 or 1
                rot = wrapPi(math.atan2(dy, dx) - ((face < 0) and math.pi or 0))
                rot = math.max(-0.9, math.min(0.9, rot))
                rot = floor(rot / 0.2618 + 0.5) * 0.2618
            elseif c.lastX then
                local dx = x - c.lastX
                if math.abs(dx) > 0.5 then face = (dx < 0) and -1 or 1 end
            end
            c.face, c.lastX = face, x
            local fi
            if mode == "glide" then
                fi = math.min(n, 3)
            else
                fi = BossAura.crowFrameIndex(frames, t, c.h1, c.phase)
            end
            BossAura.drawCrowSprite(frames, fi, x, y, face, rot, base * (big or 1),
                s.fade * (al or 1), isFront)
        end
    end
end

local function orbitBodies(r, spec, s, front)
    drawSwarm(r, spec, s, front)
    setK(0, 0, 1)
    if spec.orbit and spec.orbit.countBy then
        drawFlock(r, spec.orbit, s, front)
    elseif spec.orbit then
        orbitOne(r, spec.orbit, s, front)
    end
    if spec.orbits then
        for _, o in ipairs(spec.orbits) do orbitOne(r, o, s, front) end
    end
end

local function drawParticles(r, list, fade)
    for _, p in ipairs(list) do
        setK(0, 0, 1)
        local em = p.em
        local k = p.life / p.max
        local ax = p.u * r.iw + p.ax
        local ay = p.v * r.ih + p.ay
        if em.sway then ax = ax + math.sin(p.ph + (p.max - p.life) * (p.sf or 2.2)) * em.sway * 0.3 end
        setK(ax, ay, em.px or 1)
        local c1, c2 = em.color, em.color2 or em.color
        local mix = 1 - k
        local cr = c1[1] + (c2[1] - c1[1]) * mix
        local cg = c1[2] + (c2[2] - c1[2]) * mix
        local cb = c1[3] + (c2[3] - c1[3]) * mix
        local a = (em.a or 1) * math.min(1, k * 2.5) * math.min(1, (1 - k) * 8 + 0.2) * fade
        local kind = em.kind
        if kind == "feather" then
            local dir = (math.sin(p.ph + (p.max - p.life) * 3) > 0) and 1 or -1
            love.graphics.setColor(cr, cg, cb, a)
            artRect(r, ax - dir, ay - 1, 1, 1)
            artRect(r, ax + dir, ay + 1, 1, 1)
            love.graphics.setColor(c2[1], c2[2], c2[3], a)
            artRect(r, ax, ay, 1, 1)
        elseif kind == "petal" then
            local f = floor(p.ph + (p.max - p.life) * 2.5) % 4
            love.graphics.setColor(cr, cg, cb, a)
            artRect(r, ax, ay, 2, 2)
            local hx = (f == 1 or f == 2) and 1 or 0
            local hy = (f >= 2) and 1 or 0
            love.graphics.setColor(c2[1], c2[2], c2[3], a)
            artRect(r, ax + hx, ay + hy, 1, 1)
        elseif kind == "wisp" or kind == "spore" or kind == "ember" or kind == "spark" then
            love.graphics.setBlendMode("add")
            if kind == "spark" and love.math.random() < 0.15 then a = a * 0.3 end
            love.graphics.setColor(cr, cg, cb, a)
            local sz = p.big and 2 or 1
            artRect(r, ax, ay, sz, sz)
            if kind == "wisp" then
                love.graphics.setColor(cr, cg, cb, a * 0.45)
                artRect(r, ax, ay + 1, 1, 1)
                love.graphics.setColor(cr, cg, cb, a * 0.2)
                artRect(r, ax, ay + 2, 1, 1)
            end
            love.graphics.setBlendMode("alpha")
        elseif kind == "smoke" or kind == "breath" then
            local n = (kind == "breath") and (1 + floor((1 - k) * 2.5)) or (2 + floor((1 - k) * 2))
            love.graphics.setColor(cr, cg, cb, a * 0.8)
            artRect(r, ax - n / 2, ay - n / 2 + 0.5, n, math.max(1, n - 1))
        elseif kind == "sparkle" then
            love.graphics.setBlendMode("add")
            local n = (k > 0.5) and 2 or 1
            love.graphics.setColor(cr, cg, cb, a)
            artRect(r, ax, ay, 1, 1)
            for d = 1, n do
                artRect(r, ax + d, ay, 1, 1); artRect(r, ax - d, ay, 1, 1)
                artRect(r, ax, ay + d, 1, 1); artRect(r, ax, ay - d, 1, 1)
            end
            love.graphics.setBlendMode("alpha")
        elseif kind == "ooze" then
            local base, hi = em.color, em.color2 or em.color
            if p.state == "form" then
                local k2 = math.min(1, p.st / p.formDur)
                local len = (k2 < 0.45) and 1 or ((k2 < 0.8) and 2 or 3)
                love.graphics.setColor(base[1], base[2], base[3], 0.95 * fade)
                artRect(r, ax, ay, 1, len)
                if len == 3 then artRect(r, ax, ay + 2, 1, 1) end
                love.graphics.setColor(hi[1], hi[2], hi[3], 0.9 * fade)
                artRect(r, ax, ay + len - 1, 1, 1)
            elseif p.state == "fall" then
                love.graphics.setColor(base[1], base[2], base[3], 0.95 * fade)
                artRect(r, ax, ay - 1, 1, (p.vy > 30) and 3 or 2)
                love.graphics.setColor(hi[1], hi[2], hi[3], 0.9 * fade)
                artRect(r, ax, ay, 1, 1)
            else
                local tt = p.st
                local kk = math.max(0, 1 - tt / 0.55)
                love.graphics.setColor(base[1], base[2], base[3], 0.9 * kk * fade)
                artRect(r, ax - 1, ay, (tt < 0.2) and 2 or 3, 1)
                local dy = p.sy * tt + 0.5 * 90 * tt * tt
                if dy < 0.5 then
                    love.graphics.setColor(hi[1], hi[2], hi[3], 0.85 * kk * fade)
                    artRect(r, ax - p.sx * tt, ay + dy, 1, 1)
                    artRect(r, ax + 1 + p.sx * tt * 0.8, ay + dy * 0.85, 1, 1)
                end
            end
        end
    end
end

local function drawFloor(r, spec, s)
    local f = spec.floor
    if not f then return end
    local still = reducedMotion()
    local t = s.t
    local rx = f.ru * r.iw
    local ry = f.rv * r.iw
    local cxArt = (r.cx - r.x) / r.scale
    local cyArt = (r.groundY - r.y) / r.scale
    local rot = still and 0 or t * f.speed
    local pulse = still and 1 or (0.75 + 0.25 * math.sin(t * 1.3))
    local a = f.a * s.fade * pulse
    love.graphics.setBlendMode("add")
    local n = 44
    for i = 0, n - 1 do
        local ang = i / n * 6.283 + rot
        local c = (i % 11 == 0) and f.color2 or f.color
        love.graphics.setColor(c[1], c[2], c[3], a * ((i % 2 == 0) and 1 or 0.45))
        artRect(r, cxArt + math.cos(ang) * rx, cyArt + math.sin(ang) * ry, 1, 1)
        if i % 11 == 0 then
            artRect(r, cxArt + math.cos(ang) * rx * 0.86, cyArt + math.sin(ang) * ry * 0.86, 1, 1)
        end
    end
    for i = 0, 27 do
        local ang = i / 28 * 6.283 - rot * 1.4
        love.graphics.setColor(f.color2[1], f.color2[2], f.color2[3], a * 0.4)
        if i % 3 ~= 0 then
            artRect(r, cxArt + math.cos(ang) * rx * 0.62, cyArt + math.sin(ang) * ry * 0.62, 1, 1)
        end
    end
    love.graphics.setBlendMode("alpha")
end

local function drawCorona(r, spec, s)
    local c = spec.corona
    if not c then return end
    local still = reducedMotion()
    local t = s.t
    local cxA, cyA = c.u * r.iw, c.v * r.ih
    local R = c.r
    local fade = s.fade
    local rot = still and 0 or t * c.speed
    local nr = c.rays or 24
    for i = 0, nr - 1 do
        if (i % 2 == 0) or c.disc ~= false then
        local ang = i / nr * 6.283 + rot
        local len = (c.rayLen or 3) * (1 + (0.5 + 0.5 * math.sin(i * 2.1 + (still and 0 or t * 1.3))))
        for d = 0, floor(len) do
            local k = d / (len + 1)
            local col = (d < 2) and c.color or c.color2
            love.graphics.setColor(col[1], col[2], col[3], (c.a or 0.55) * (1 - 0.8 * k) * fade)
            artRect(r, cxA + math.cos(ang) * (R + d), cyA + math.sin(ang) * (R + d), 1, 1)
        end
        end
    end
    if c.disc == false then return end
    for i = 0, 71 do
        local ang = i / 72 * 6.283
        love.graphics.setColor(c.color[1], c.color[2], c.color[3], 0.85 * fade)
        artRect(r, cxA + math.cos(ang) * R, cyA + math.sin(ang) * R, 1, 1)
    end
    love.graphics.setColor(c.dark[1], c.dark[2], c.dark[3], fade)
    for dy = -R + 1, R - 1 do
        local half = floor(math.sqrt(math.max(0, (R - 0.6) ^ 2 - dy * dy)) + 0.5)
        artRect(r, cxA - half, cyA + dy, half * 2, 1)
    end
end

local function drawGlint(r, spec, s)
    local g = spec.glint
    if not g or reducedMotion() then return end
    local e = edges(r.id)
    if not e then return end
    local ph = (s.t % g.period) / g.period
    if ph > 0.6 then return end
    local k = ph / 0.6
    local row0 = floor((g.v0 + (g.v1 - g.v0) * k) * e.h)
    love.graphics.setBlendMode("add")
    for d = 0, 4 do
        local row = row0 - d
        local a = (1 - d / 5) * 0.9 * s.fade * math.sin(k * math.pi)
        love.graphics.setColor(g.color[1], g.color[2], g.color[3], a)
        if e.left[row] then artRect(r, e.left[row] + 1, row, 1, 1) end
        if e.right[row] then artRect(r, e.right[row] - 1, row, 1, 1) end
    end
    love.graphics.setBlendMode("alpha")
end

function BossAura.drawBack(id, r)
    local spec = BossAura.get(id)
    if not spec then return end
    local s = getState(id)
    if s.fade <= 0 then return end
    r.id = id
    s.groundArt = (r.groundY - r.y) / r.scale
    s.ih = r.ih
    s.iw = r.iw
    if flockSpec(spec) or spec.hitFeathers then
        local sx, sy = BossAura.playerTarget()
        local lx, ly = love.graphics.inverseTransformPoint(sx, sy)
        s.tgtX, s.tgtY = (lx - r.x) / r.scale, (ly - r.y) / r.scale
    end
    love.graphics.push("all")
    drawFloor(r, spec, s)
    drawCorona(r, spec, s)
    orbitBodies(r, spec, s, false)
    drawParticles(r, s.back, s.fade)
    setK(0, 0, 1)
    love.graphics.pop()
end

function BossAura.drawFront(id, r)
    local spec = AURAS[id]
    if not spec then return end
    local s = getState(id)
    if s.fade <= 0 then return end
    r.id = id
    love.graphics.push("all")
    drawGlows(r, spec, s, s.fade)
    drawGlint(r, spec, s)
    orbitBodies(r, spec, s, true)
    drawParticles(r, s.front, s.fade)
    setK(0, 0, 1)
    love.graphics.pop()
end

function BossAura._debugCount(id)
    local s = state[id]
    if not s then return 0 end
    return #s.back + #s.front, s.fade
end

return BossAura
