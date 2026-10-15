local Debug = require("src.core.Debug")

local SPECS = require("src.data.boss_tokens")

local BossTokens = {}

local floor, max, min = math.floor, math.max, math.min
local state = {}
local images = {}

BossTokens.TIMES = { enter = 0.55, leave = 0.45, stagger = 0.18 }

local function reducedMotion()
    return (_G.gameSettings and _G.gameSettings.reducedMotion) or false
end

function BossTokens.has(id)
    return id ~= nil and SPECS[id] ~= nil
end

function BossTokens.spec(id)
    return SPECS[id]
end

function BossTokens.image(path)
    if images[path] ~= nil then return images[path] or nil end
    if not love.filesystem.getInfo(path) then
        Debug.warn("[BossTokens] AVISO: sprite ausente " .. tostring(path))
        images[path] = false
        return nil
    end
    local img = love.graphics.newImage(path)
    img:setFilter("nearest", "nearest")
    images[path] = img
    return img
end

local function getState(id)
    local s = state[id]
    if not s then
        s = { t = 0, tokens = {}, parts = {}, bolts = {}, serial = 0, rot = 0,
              consumed = 0 }
        state[id] = s
    end
    return s
end

function BossTokens.reset()
    state = {}
end

function BossTokens.tokenScale(artScale, full)
    if full then return max(1, floor((artScale or 1) + 0.5)) end
    return max(1, floor((artScale or 1) * 0.5 + 0.5))
end

local function hash01(i, k)
    return (math.sin(i * k) * 43758.5453) % 1
end

function BossTokens.playSound(snd, pitchJitter)
    if not snd then return end
    local a = _G.audioSystem
    if not (a and a.sources) then return end
    if not a.sources[snd.code] and a.loadSound and love.filesystem.getInfo(snd.path) then
        a:loadSound(snd.code, snd.path, { volume = snd.volume })
    end
    if a.sources[snd.code] then
        a:play(snd.code, { volume = snd.volume,
            pitch = (snd.pitch or 1) + (love.math.random() * 2 - 1) * (pitchJitter or 0.05) })
    end
end

function BossTokens.setWant(id, n)
    if not SPECS[id] then return end
    getState(id).want = max(0, floor(n or 0))
end

function BossTokens.sync(id, enemy)
    local spec = SPECS[id]
    if not spec or not enemy or not enemy.getStatusStacks then return end
    getState(id).want = max(0, floor(enemy:getStatusStacks(spec.status) or 0))
end

local function alive(s)
    local out = {}
    for _, c in ipairs(s.tokens) do
        if c.phase ~= "leave" and c.phase ~= "gone" and not c.consume then out[#out + 1] = c end
    end
    return out
end

function BossTokens.count(id)
    local s = state[id]
    if not s then return 0 end
    return #alive(s)
end

function BossTokens.phases(id)
    local out = {}
    local s = state[id]
    for _, c in ipairs((s and s.tokens) or {}) do
        out[c.phase] = (out[c.phase] or 0) + 1
    end
    return out
end

local glowImg = nil
function BossTokens.glowImage()
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

local function addShards(s, ax, ay, colors, n, spread)
    for k = 1, n do
        if #s.parts >= 120 then break end
        local a = love.math.random() * 6.283
        local sp = (spread or 24) * (0.4 + love.math.random() * 0.8)
        local life = 0.45 + love.math.random() * 0.4
        s.parts[#s.parts + 1] = {
            x = ax, y = ay, vx = math.cos(a) * sp, vy = math.sin(a) * sp - 10,
            life = life, max = life, c = colors[(k % #colors) + 1],
            g = 60, big = (k % 3 == 0),
        }
    end
end

local function impact(s, colors)
    s.flash = { x = s.tgtX or 0, y = s.tgtY or 0, c = colors[1], life = 0.35, max = 0.35 }
    addShards(s, s.tgtX or 0, s.tgtY or 0, colors, 22, 50)
end

local function reconcile(spec, s, dt, still)
    local T = BossTokens.TIMES
    local want = min(spec.max or 10, s.want or 0)
    local instant = still or not s.init
    s.init = true
    local list = alive(s)
    local added = 0
    while #list + s.consumed < want do
        s.serial = s.serial + 1
        local c = { seed = s.serial, h1 = hash01(s.serial, 12.9898),
                    h2 = hash01(s.serial, 78.233),
                    img = ((s.serial - 1) % #(spec.sprites or { 1 })) + 1,
                    phase = instant and "idle" or "enter",
                    t = -T.stagger * added }
        added = added + 1
        s.tokens[#s.tokens + 1] = c
        list[#list + 1] = c
    end
    while #list + s.consumed > want do
        if s.consumed > 0 then
            s.consumed = s.consumed - 1
        else
            local idx = nil
            for i, c in ipairs(list) do
                if c.phase == "strike" then idx = i break end
            end
            if idx then
                list[idx].consume = true
            else
                idx = #list
                list[idx].phase, list[idx].t = still and "gone" or "leave", 0
            end
            table.remove(list, idx)
        end
    end
    local n = #list
    for j, c in ipairs(list) do
        local goal = (j - 1) / max(1, n) * 6.283
        if not c.off then
            c.off = goal
        else
            local d = (goal - c.off + math.pi) % 6.283 - math.pi
            c.off = c.off + d * min(1, dt * 2.4)
        end
    end
end

local function orbitPos(spec, s, c, still)
    local ang = (c.off or 0) + (s.rot or 0)
    local rk = 0.88 + 0.24 * c.h1
    local sn = math.sin(ang)
    local u = spec.cu + spec.ru * rk * math.cos(ang)
    local v = spec.cv + spec.rv * rk * sn
    if not still then v = v + (spec.bob or 0.02) * math.sin(s.t * (1.1 + c.h2) + c.seed * 2.1) end
    return u * (s.iw or 0), v * (s.ih or 0), sn
end

function BossTokens._pose(spec, s, c, still)
    local T = BossTokens.TIMES
    local ox, oy, sn = orbitPos(spec, s, c, still)
    if c.phase == "idle" then return ox, oy, sn > 0, 1, 1 end
    if c.phase == "enter" then
        if c.t < 0 then return nil end
        local k = min(1, c.t / T.enter)
        local e = 1 - (1 - k) * (1 - k)
        local sp = spec.spawn or { spec.cu, spec.cv }
        local sx, sy = sp[1] * (s.iw or 0), sp[2] * (s.ih or 0)
        return sx + (ox - sx) * e, sy + (oy - sy) * e - math.sin(k * math.pi) * 6,
            true, min(1, k * 3), 1 + (1 - k) * 0.6
    end
    if c.phase == "strike" then
        local tx, ty = s.tgtX or ox, s.tgtY or oy
        local k = max(0, min(1, c.t / c.apex))
        local kk = k ^ 1.5
        c.sx = c.sx or ox
        c.sy = c.sy or oy
        return c.sx + (tx - c.sx) * kk, c.sy + (ty - c.sy) * kk - math.sin(k * math.pi) * 18,
            true, 1, (k > 0.35) and 1.3 or 1
    end
    return ox, oy, sn > 0, 1, 1
end

local function advanceTokens(id, spec, s, dt, still)
    local T = BossTokens.TIMES
    for i = #s.tokens, 1, -1 do
        local c = s.tokens[i]
        c.t = c.t + dt
        if c.phase == "enter" and c.t >= T.enter then
            c.phase, c.t = "idle", 0
        elseif c.phase == "leave" then
            if not c.burst then
                c.burst = true
                local x, y = BossTokens._pose(spec, s, { phase = "idle", off = c.off,
                    h1 = c.h1, h2 = c.h2, seed = c.seed }, still)
                addShards(s, x, y, spec.shard or { { 1, 1, 1 } }, 12, 30)
            end
            if c.t >= T.leave then c.phase = "gone" end
        elseif c.phase == "strike" and c.t >= c.apex then
            local st = spec.strikes and spec.strikes[c.kind] or {}
            impact(s, st.burst or spec.shard or { { 1, 1, 1 } })
            BossTokens.playSound(spec.sounds and spec.sounds.hit)
            if c.consume then
                c.phase = "gone"
            else
                c.phase = "gone"
                s.consumed = s.consumed + 1
            end
        end
        if c.phase == "gone" then table.remove(s.tokens, i) end
    end
end

local function chainEnds(spec, s, ch)
    local iw, ih = s.iw or 0, s.ih or 0
    local function pt(p)
        local y = (p[2] == "ground") and (s.groundArt or ih) or p[2] * ih
        return p[1] * iw, y
    end
    local ax, ay = pt(ch.from)
    local bx, by = pt(ch.to)
    return ax, ay, bx, by
end

function BossTokens._syncChains(spec, s, dt, still)
    s.chains = s.chains or {}
    local want = min(#spec.chains, s.want or 0)
    local instant = still or not s.init
    s.init = true
    for i = 1, #spec.chains do
        local c = s.chains[i]
        if not c then
            c = { broken = i > want, t = 9 }
            s.chains[i] = c
        end
        c.t = c.t + dt
        if i <= want and c.broken then
            c.broken, c.t = false, instant and 9 or 0
        elseif i > want and not c.broken then
            c.broken, c.t = true, instant and 9 or 0
            if not instant and s.iw then
                local ax, ay, bx, by = chainEnds(spec, s, spec.chains[i])
                addShards(s, (ax + bx) / 2, (ay + by) / 2 + (spec.chains[i].sag or 0),
                    spec.shard or { { 1, 1, 1 } }, 18, 38)
            end
        end
    end
end

function BossTokens.chainState(id)
    local s = state[id]
    local out = { intact = 0, breaking = 0 }
    for _, c in ipairs((s and s.chains) or {}) do
        if not c.broken then
            out.intact = out.intact + 1
        elseif c.t < 0.9 then
            out.breaking = out.breaking + 1
        end
    end
    return out
end

local function advanceBolts(spec, s, dt)
    for i = #s.bolts, 1, -1 do
        local b = s.bolts[i]
        b.t = b.t + dt
        if not b.hit and b.t >= b.apex then
            b.hit = true
            local st = spec.strikes and spec.strikes[b.kind] or {}
            impact(s, st.burst or { { 1, 1, 1 } })
            BossTokens.playSound(st.sound)
        end
        if b.t >= b.apex + (b.back or 0.3) then table.remove(s.bolts, i) end
    end
end

function BossTokens.update(dt, id, dying)
    local spec = id and SPECS[id]
    if not spec then return end
    local s = getState(id)
    local still = reducedMotion()
    s.t = s.t + dt
    if not still then s.rot = s.rot + dt * (spec.speed or 0.5) end
    s.fade = dying and max(0, (s.fade or 1) - dt / 0.6) or min(1, (s.fade or 1) + dt / 0.4)
    if spec.layout == "orbit" then
        reconcile(spec, s, dt, still)
        advanceTokens(id, spec, s, dt, still)
    elseif spec.layout == "chains" then
        BossTokens._syncChains(spec, s, dt, still)
    end
    advanceBolts(spec, s, dt)
    if s.flash then s.flash.life = s.flash.life - dt end
    for i = #s.parts, 1, -1 do
        local p = s.parts[i]
        p.life = p.life - dt
        if p.life <= 0 then
            table.remove(s.parts, i)
        elseif not still then
            p.vy = p.vy + (p.g or 0) * dt
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
        end
    end
end

function BossTokens.strike(id, kind, apex, back)
    if reducedMotion() then return false end
    local spec = SPECS[id]
    local st = spec and spec.strikes and spec.strikes[kind]
    if not st then return false end
    local s = state[id]
    if not s or not s.iw then return false end
    if st.kind == "token" then
        local pool = {}
        for _, c in ipairs(s.tokens) do
            if c.phase == "idle" then pool[#pool + 1] = c end
        end
        if #pool == 0 then return false end
        local c = pool[#pool]
        local x, y = BossTokens._pose(spec, s, c, false)
        c.phase, c.t, c.apex, c.kind, c.sx, c.sy = "strike", 0, apex or 0.34, kind, x, y
        return true
    end
    s.bolts[#s.bolts + 1] = { kind = kind, t = 0, apex = apex or 0.34, back = back or 0.3 }
    return true
end

local function artToScreen(r, ax, ay)
    return floor(r.x + ax * r.scale), floor(r.y + ay * r.scale)
end

local function drawParts(r, s, front)
    local P = max(1, floor(r.scale + 0.5))
    if s.flash and s.flash.life > 0 then
        local f = s.flash
        local k = f.life / f.max
        local img = require("src.ui.BossTokens").glowImage()
        local x, y = artToScreen(r, f.x, f.y)
        local rad = (1 - k) * 40 * r.scale + 10
        love.graphics.setBlendMode("add")
        love.graphics.setColor(f.c[1], f.c[2], f.c[3], 0.8 * k * (s.fade or 1))
        love.graphics.draw(img, x - rad, y - rad, 0, rad * 2 / img:getWidth(), rad * 2 / img:getHeight())
        love.graphics.setBlendMode("alpha")
    end
    for _, p in ipairs(s.parts) do
        local k = p.life / p.max
        local x, y = artToScreen(r, p.x, p.y)
        love.graphics.setColor(p.c[1], p.c[2], p.c[3], min(1, k * 2.2) * (s.fade or 1))
        local n = p.big and 2 or 1
        love.graphics.rectangle("fill", x, y, P * n, P * n)
    end
end

local function drawOrbit(r, spec, s, front)
    local still = reducedMotion()
    local S = BossTokens.tokenScale(r.scale, spec.full)
    for _, c in ipairs(s.tokens) do
        local ax, ay, isFront, al, grow = BossTokens._pose(spec, s, c, still)
        if ax and isFront == front then
            local img = BossTokens.image(spec.sprites[c.img] or spec.sprites[1])
            if img then
                local x, y = artToScreen(r, ax, ay)
                local k = S
                if grow and grow > 1.25 and not still then k = S + 1 end
                local a = (al or 1) * (s.fade or 1)
                local ox, oy = floor(img:getWidth() / 2), floor(img:getHeight() / 2)
                if c.phase == "strike" then
                    for g = 2, 1, -1 do
                        local ghost = { phase = "strike", t = c.t - g * 0.035, apex = c.apex,
                                        sx = c.sx, sy = c.sy, off = c.off, h1 = c.h1, h2 = c.h2,
                                        seed = c.seed }
                        local gx, gy = BossTokens._pose(spec, s, ghost, still)
                        local sx2, sy2 = artToScreen(r, gx, gy)
                        love.graphics.setBlendMode("add")
                        local gc = spec.glow or { 1, 1, 1 }
                        love.graphics.setColor(gc[1], gc[2], gc[3], a * (0.45 / g))
                        love.graphics.draw(img, sx2, sy2, 0, k, k, ox, oy)
                        love.graphics.setBlendMode("alpha")
                    end
                end
                if spec.glow then
                    love.graphics.setBlendMode("add")
                    local pulse = still and 0.5 or (0.35 + 0.25 * math.sin(s.t * 2.6 + c.seed))
                    love.graphics.setColor(spec.glow[1], spec.glow[2], spec.glow[3], pulse * a * 0.5)
                    love.graphics.draw(img, x, y, 0, k, k, ox, oy - 1)
                    love.graphics.setBlendMode("alpha")
                end
                if isFront then
                    love.graphics.setColor(1, 1, 1, a)
                else
                    love.graphics.setColor(0.72, 0.74, 0.84, a * 0.9)
                end
                love.graphics.draw(img, x, y, 0, k, k, ox, oy)
            end
        end
    end
end

local function boltPose(s, st, b)
    local fx, fy = st.from[1] * (s.iw or 0), st.from[2] * (s.ih or 0)
    local tx, ty = s.tgtX or fx, s.tgtY or fy
    local k = max(0, min(1, b.t / b.apex))
    local kk = k ^ 1.3
    local x = fx + (tx - fx) * kk
    local y = fy + (ty - fy) * kk - math.sin(k * math.pi) * (st.arc or 24)
    return x, y, k
end

local function drawBolts(r, spec, s)
    for _, b in ipairs(s.bolts) do
        local st = spec.strikes and spec.strikes[b.kind]
        if st and st.kind == "bolt" and not b.hit and b.t >= 0 then
            local img = BossTokens.image(st.sprite)
            if img then
                local S = BossTokens.tokenScale(r.scale, st.full)
                local x, y = boltPose(s, st, b)
                local px, py = boltPose(s, st, { t = b.t - 1 / 30, apex = b.apex })
                local ang = math.atan2(y - py, x - px)
                ang = floor(ang / 0.2618 + 0.5) * 0.2618
                local ox, oy = floor(img:getWidth() / 2), floor(img:getHeight() / 2)
                local tc = st.trail or { 1, 1, 1 }
                love.graphics.setBlendMode("add")
                for g = 3, 1, -1 do
                    local gx, gy = boltPose(s, st, { t = b.t - g * 0.03, apex = b.apex })
                    local sx2, sy2 = artToScreen(r, gx, gy)
                    love.graphics.setColor(tc[1], tc[2], tc[3], 0.35 / g * (s.fade or 1))
                    love.graphics.draw(img, sx2, sy2, ang, S, S, ox, oy)
                end
                love.graphics.setBlendMode("alpha")
                local sx, sy = artToScreen(r, x, y)
                love.graphics.setColor(1, 1, 1, s.fade or 1)
                love.graphics.draw(img, sx, sy, ang, S, S, ox, oy)
            end
        end
    end
end

local function linkCurve(r, ax, ay, mx, my, bx, by)
    local pts = {}
    local N = 28
    for i = 0, N do
        local u = i / N
        local x = (1 - u) * (1 - u) * ax + 2 * u * (1 - u) * mx + u * u * bx
        local y = (1 - u) * (1 - u) * ay + 2 * u * (1 - u) * my + u * u * by
        pts[#pts + 1] = { r.x + x * r.scale, r.y + y * r.scale }
    end
    return pts
end

local function drawLinks(img, pts, S, rows)
    local period = (rows[2] - rows[1]) * S
    local ox = floor(img:getWidth() / 2)
    local acc = 0
    for i = 2, #pts do
        local p0, p1 = pts[i - 1], pts[i]
        local dx, dy = p1[1] - p0[1], p1[2] - p0[2]
        local len = math.sqrt(dx * dx + dy * dy)
        local ang = math.atan2(dy, dx) - math.pi / 2
        local d = 0
        while acc + (len - d) >= period do
            d = d + (period - acc)
            acc = 0
            local k = d / max(len, 1e-6)
            love.graphics.draw(img, floor(p0[1] + dx * k), floor(p0[2] + dy * k), ang, S, S,
                ox, rows[1])
        end
        acc = acc + (len - d)
    end
end

local function drawChain(r, spec, s, ch, c)
    local img = BossTokens.image(spec.link)
    if not img then return end
    local ax, ay, bx, by = chainEnds(spec, s, ch)
    local still = reducedMotion()
    local sway = still and 0 or math.sin(s.t * 1.3 + ax * 0.1) * 1.5
    local mx, my = (ax + bx) / 2 + sway, (ay + by) / 2 + (ch.sag or 0)
    local S = BossTokens.tokenScale(r.scale, spec.full)
    local rows = spec.linkRows or { 0, img:getHeight() }
    local alpha = s.fade or 1
    if not c.broken then
        love.graphics.setColor(0.86, 0.80, 0.78, alpha)
        drawLinks(img, linkCurve(r, ax, ay, mx, my, bx, by), S, rows)
        return
    end
    if c.t >= 0.9 or still then return end
    local k = c.t / 0.9
    alpha = alpha * (1 - k * k)
    local drop = 0.5 * 220 * c.t * c.t
    local floorY = s.groundArt or (s.ih or 0)
    local m1x, m1y = mx, min(floorY, my + drop)
    local m2x, m2y = (mx + bx) / 2, min(floorY, (my + by) / 2 + drop * 1.4)
    love.graphics.setColor(1.00, 0.62, 0.30, alpha)
    drawLinks(img, linkCurve(r, ax, ay, (ax + m1x) / 2, max(ay, m1y) + 2, m1x, m1y), S, rows)
    drawLinks(img, linkCurve(r, bx, by, bx, (by + m2y) / 2 + 4, m2x, m2y), S, rows)
end

local function drawChains(r, spec, s)
    if not s.chains then return end
    for i, ch in ipairs(spec.chains) do
        if s.chains[i] then drawChain(r, spec, s, ch, s.chains[i]) end
    end
end

local function prepare(r, s)
    s.iw, s.ih = r.iw, r.ih
    local sx, sy = require("src.ui.BossAura").playerTarget()
    local lx, ly = love.graphics.inverseTransformPoint(sx, sy)
    s.tgtX, s.tgtY = (lx - r.x) / r.scale, (ly - r.y) / r.scale
    s.groundArt = (r.groundY - r.y) / r.scale
end

function BossTokens.drawBack(id, r)
    local spec = id and SPECS[id]
    if not spec then return end
    local s = getState(id)
    prepare(r, s)
    if (s.fade or 1) <= 0 then return end
    love.graphics.push("all")
    if spec.layout == "orbit" then drawOrbit(r, spec, s, false) end
    if spec.layout == "chains" then drawChains(r, spec, s) end
    love.graphics.pop()
end

function BossTokens.drawFront(id, r)
    local spec = id and SPECS[id]
    if not spec then return end
    local s = getState(id)
    if (s.fade or 1) <= 0 then return end
    love.graphics.push("all")
    if spec.layout == "orbit" then drawOrbit(r, spec, s, true) end
    drawBolts(r, spec, s)
    drawParts(r, s, true)
    love.graphics.pop()
end

local screen = { level = 0, flash = 0 }

function BossTokens.screenLevel()
    return screen.level
end

function BossTokens.drawScreen(game)
    local e = game and game.enemy
    local spec = e and e.spriteId and SPECS[e.spriteId]
    local p = game and game.player
    local dt = love.timer.getDelta()
    local m = require("src.systems.BossMechanics").frostSpec(game)
    local want = 0
    if spec and spec.layout == "screen" and m and p then
        want = (p.frost or 0) / m.threshold
    end
    if reducedMotion() then
        screen.level = want
    else
        screen.level = screen.level + (want - screen.level) * min(1, dt * 3)
    end
    screen.flash = max(0, screen.flash - dt)
    if screen.level < 0.02 and screen.flash <= 0 then return end
    local img = spec and BossTokens.image(spec.corner)
    if not img then return end
    local W, H = love.graphics.getDimensions()
    local S = max(3, floor(H / 200))
    local l = min(1.2, screen.level)
    local k = max(1, floor(S * min(1, 0.45 + 0.55 * l) + 0.5))
    local a = min(1, 0.30 + 0.8 * l)
    local w, h = img:getWidth() * k, img:getHeight() * k
    love.graphics.push("all")
    love.graphics.setColor(1, 1, 1, a)
    love.graphics.draw(img, 0, H - h, 0, k, k)
    love.graphics.draw(img, W, H - h, 0, -k, k)
    if l >= 0.74 then
        local k2 = max(1, k - 1)
        love.graphics.setColor(1, 1, 1, a * min(1, (l - 0.74) * 4))
        love.graphics.draw(img, 0, H * 0.42, 0, k2, -k2)
        love.graphics.draw(img, W, H * 0.42, 0, -k2, -k2)
    end
    if screen.flash > 0 then
        love.graphics.setBlendMode("add")
        love.graphics.setColor(0.7, 0.9, 1.0, screen.flash * 1.2)
        love.graphics.draw(img, 0, H - h, 0, k, k)
        love.graphics.draw(img, W, H - h, 0, -k, k)
        love.graphics.setBlendMode("alpha")
    end
    love.graphics.pop()
end

function BossTokens.drawFrozenCard(card, x, y)
    local spec = SPECS.winter_monarch
    local img = BossTokens.image(spec.iceBlock)
    if not img then return end
    local a = 0.62
    if not card.frozen then
        local now = love.timer.getTime()
        local k = (now - (card._thawAt or now)) / 0.45
        if k >= 1 then
            card._thawAt = nil
            return
        end
        a = a * (1 - k)
    end
    local sx = card.image and card.image:getWidth() / img:getWidth() or 1
    local sy = card.image and card.image:getHeight() / img:getHeight() or 1
    love.graphics.setColor(1, 1, 1, a)
    love.graphics.draw(img, x, y, 0, sx, sy)
    love.graphics.setColor(1, 1, 1, 1)
end

local function playerFloat(text, opts)
    local okFT, FloatingText = pcall(require, "src.ui.FloatingText")
    if okFT and love.graphics then
        FloatingText.spawn(text, 120, love.graphics.getHeight() - 150, opts)
    end
end

local function enemyFloat(text, opts)
    local okER, ER = pcall(require, "src.ui.EnemyRenderer")
    local okFT, FloatingText = pcall(require, "src.ui.FloatingText")
    if okER and okFT and ER.getLastPos then
        local ex, ey = ER.getLastPos()
        if ex and ey then FloatingText.spawn(text, ex, ey - 30, opts) end
    end
end

function BossTokens.react(game, res)
    local e = game and game.enemy
    local id = e and e.spriteId
    local spec = id and SPECS[id]
    local I18n = require("src.i18n.I18n")
    if res.kind == "rune_gain" then
        if spec then BossTokens.playSound(spec.sounds.gain) end
        enemyFloat(I18n.t("enemy_kit.msg.rune_gain", { value = res.total }, "+1"),
            { kind = "movename", hold = 0.45, lift = 22 })
    elseif res.kind == "frost_gain" then
        if spec then BossTokens.playSound(spec.sounds.gain) end
        playerFloat(I18n.t("enemy_kit.msg.frost_gain", { value = res.n, total = res.total,
            max = res.threshold }, "+" .. res.n), { kind = "movename", hold = 0.5, lift = 22 })
    elseif res.kind == "freeze" then
        screen.flash = 0.6
        local snd = SPECS.winter_monarch.sounds.freeze
        BossTokens.playSound(snd)
        if _G.triggerShake then _G.triggerShake(4, 0.18) end
        for _, c in ipairs(res.cards or {}) do
            if c.juice_up then c:juice_up(0.25, 0.1) end
        end
        if res.n > 0 then
            playerFloat(I18n.t("enemy_kit.msg.freeze", { value = res.n }, "*"),
                { kind = "movename", hold = 0.7, lift = 26 })
        end
    elseif res.kind == "frost_melt" then
        BossTokens.playSound(SPECS.winter_monarch.sounds.melt, 0.08)
        playerFloat(I18n.t("enemy_kit.msg.frost_melt", { value = res.n }, "-" .. res.n),
            { kind = "movename", hold = 0.35, lift = 18 })
    elseif res.kind == "chain_break" then
        if spec then BossTokens.playSound(spec.sounds.lose) end
        if _G.triggerShake then _G.triggerShake(7, 0.22) end
        local okER, ER = pcall(require, "src.ui.EnemyRenderer")
        if okER and ER.triggerHurt then ER.triggerHurt() end
        enemyFloat(I18n.t("enemy_kit.msg.chain_break", { value = res.strength }, "+" .. res.strength),
            { kind = "movename", hold = 0.6, lift = 26 })
        if res.halved then
            local okFT, FloatingText = pcall(require, "src.ui.FloatingText")
            if okER and okFT and ER.getLastPos then
                local ex, ey = ER.getLastPos()
                if ex and ey then
                    FloatingText.spawn(I18n.t("enemy_kit.msg.staggered", nil, "1/2"), ex, ey - 64,
                        { kind = "movename", hold = 0.6, lift = 18 })
                end
            end
        end
    elseif res.kind == "rune_break" then
        if spec then BossTokens.playSound(spec.sounds.lose) end
        if _G.triggerShake then _G.triggerShake(4, 0.16) end
        enemyFloat(I18n.t("enemy_kit.msg.rune_break", { value = res.n }, "-" .. res.n),
            { kind = "movename", hold = 0.55, lift = 26 })
    end
end

function BossTokens._debug(id)
    return state[id]
end

return BossTokens
