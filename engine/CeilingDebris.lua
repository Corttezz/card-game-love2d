local CeilingDebris = {}

CeilingDebris.MAX = 160
CeilingDebris.LAND_FADE = 0.45
CeilingDebris.PUFF_LIFE = 0.42
CeilingDebris.TUMBLE = 0.11

local pool = {}
for i = 1, CeilingDebris.MAX do
    pool[i] = { on = false, kind = "fall", x = 0, y = 0, vx = 0, vy = 0, floorY = 0,
                life = 0, maxLife = 0, land = -1, phase = 0, size = 1, ci = 1,
                style = nil, swayK = 0, var = 0, bounces = 0, tumble = 0, alpha = 1 }
end
local live = 0
local floating = 0
local time = 0

local rnd = love.math.random

local function range(r, default)
    if type(r) ~= "table" then return r or default end
    return r[1] + rnd() * (r[2] - r[1])
end

local function slot()
    for i = 1, CeilingDebris.MAX do
        if not pool[i].on then return pool[i] end
    end
    return nil
end

local function wake(p, style, kind)
    p.on = true
    p.kind = kind
    p.style = style
    p.life = 0
    p.maxLife = style.life or 8
    p.land = -1
    p.bounces = 0
    p.tumble = rnd() * CeilingDebris.TUMBLE
    p.var = rnd(0, 3)
    p.phase = rnd() * 6.283
    p.ci = rnd(1, #style.colors)
    p.alpha = style.alpha or 0.9
    live = live + 1
end

local function sizeFor(style)
    local big = style.big
    if big and rnd() < big[1] then return math.floor(range(big[2], 4) + 0.5) end
    return math.max(1, math.floor(range(style.size, 1) + 0.5))
end

local function kill(p)
    if p.on then
        if p.kind == "float" then floating = floating - 1 end
        p.on = false
        p.style = nil
        live = live - 1
    end
end

function CeilingDebris.spawn(style, count, area, cluster)
    if not style or not area then return 0 end
    local made = 0
    local cx = nil
    if cluster then cx = area.x0 + rnd() * (area.x1 - area.x0) end
    for _ = 1, count or 1 do
        local p = slot()
        if not p then break end
        wake(p, style, "fall")
        if cx then
            p.x = cx + (rnd() - 0.5) * (cluster * 2)
        else
            p.x = area.x0 + rnd() * (area.x1 - area.x0)
        end
        p.y = area.y0 + rnd() * (area.y1 - area.y0)
        p.vx = range(style.vx, 0)
        p.vy = range(style.vy, 0)
        p.floorY = area.floor0 + rnd() * (area.floor1 - area.floor0)
        p.size = sizeFor(style)
        p.swayK = range(style.sway, 0)
        made = made + 1
    end
    return made
end

function CeilingDebris.spawnStreak(style, count, area)
    if not style or not area then return 0 end
    local made = 0
    local cx = area.x0 + rnd() * (area.x1 - area.x0)
    local y0 = area.y0 + rnd() * 6
    local vy = range(style.vy, 0)
    local phase = rnd() * 6.283
    local floorY = area.floor0 + rnd() * (area.floor1 - area.floor0)
    local gap = style.streakGap or 1.6
    for i = 1, count or 3 do
        local p = slot()
        if not p then break end
        wake(p, style, "fall")
        p.x = cx + (rnd() - 0.5) * 0.6
        p.y = y0 - (i - 1) * gap
        p.vx = 0
        p.vy = vy + (i - 1) * 0.4
        p.floorY = floorY
        p.size = 1
        p.swayK = range(style.sway, 0) * 0.5
        p.phase = phase
        made = made + 1
    end
    return made
end

function CeilingDebris.spawnFloat(style, area)
    if not style or not area then return 0 end
    local p = slot()
    if not p then return 0 end
    wake(p, style, "float")
    floating = floating + 1
    p.x = area.x0 + rnd() * (area.x1 - area.x0)
    p.y = area.y1 + rnd() * (area.floor0 - area.y1)
    p.vx = range(style.vx, 0)
    p.vy = range(style.vy, 1)
    p.floorY = area.floor0 + rnd() * (area.floor1 - area.floor0)
    p.size = 1
    p.swayK = range(style.sway, 0)
    p.maxLife = range(style.life, 6)
    return 1
end

local function puff(p, st)
    local n = st.puff or 0
    if n <= 0 then return end
    local c = st.puffColor or st.colors[p.ci]
    for _ = 1, n do
        local q = slot()
        if not q then return end
        wake(q, st, "puff")
        q.x = p.x + (rnd() - 0.5) * 1.5
        q.y = p.floorY - 0.5
        q.vx = (rnd() - 0.5) * 22
        q.vy = -(3 + rnd() * 8)
        q.floorY = p.floorY
        q.size = 1
        q.swayK = 0
        q.maxLife = CeilingDebris.PUFF_LIFE * (0.7 + rnd() * 0.6)
        q.alpha = (st.puffAlpha or 0.55)
        q.puffColor = c
    end
end

function CeilingDebris.update(dt)
    time = time + dt
    if live == 0 then return end
    for i = 1, CeilingDebris.MAX do
        local p = pool[i]
        if p.on then
            local st = p.style
            p.life = p.life + dt
            if p.kind == "puff" then
                p.vy = p.vy + 26 * dt
                p.vx = p.vx * (1 - 3 * dt)
                p.x = p.x + p.vx * dt
                p.y = math.min(p.floorY, p.y + p.vy * dt)
                if p.life >= p.maxLife then kill(p) end
            elseif p.kind == "float" then
                local sway = math.sin(time * (st.swayHz or 0.5) + p.phase) * p.swayK
                p.x = p.x + (p.vx + sway) * dt
                p.y = p.y + p.vy * dt
                if p.life >= p.maxLife or p.y >= p.floorY then kill(p) end
            elseif p.land >= 0 then
                p.land = p.land + dt
                if p.land >= (st.rest or 0) + CeilingDebris.LAND_FADE then kill(p) end
            else
                p.vy = math.min(st.vmax or 200, p.vy + (st.gravity or 0) * dt)
                local sway = p.swayK ~= 0 and math.sin(time * (st.swayHz or 2) + p.phase) * p.swayK or 0
                p.x = p.x + (p.vx + sway) * dt
                p.y = p.y + p.vy * dt
                p.tumble = p.tumble + dt
                if p.tumble >= CeilingDebris.TUMBLE then
                    p.tumble = p.tumble - CeilingDebris.TUMBLE
                    p.var = (p.var + 1) % 4
                end
                if p.y >= p.floorY then
                    p.y = p.floorY
                    local b = st.bounce or 0
                    if p.bounces == 0 then puff(p, st) end
                    if b > 0 and p.bounces < 2 and p.vy > (st.bounceMin or 30) then
                        p.bounces = p.bounces + 1
                        p.vy = -p.vy * b * (0.7 + rnd() * 0.6)
                        p.vx = p.vx * 0.5 + (rnd() - 0.5) * 8
                        p.y = p.floorY - 0.01
                    else
                        p.vy = 0
                        p.land = 0
                    end
                end
                if p.life > p.maxLife or p.x < -12 or p.x > 412 then kill(p) end
            end
        end
    end
end

local function cell(ox, oy, s, u, x, y, w, h)
    local sx = math.floor((ox + x * s) / u) * u
    local sy = math.floor((oy + y * s) / u) * u
    love.graphics.rectangle("fill", sx, sy, u * (w or 1), u * (h or 1))
end

local function chunk(ox, oy, s, u, x, y, n, var, c, a)
    if n <= 1 then
        cell(ox, oy, s, u, x, y, 1, 1)
        return
    end
    local sx = math.floor((ox + x * s) / u) * u
    local sy = math.floor((oy + y * s) / u) * u
    local cutTop = (var == 1 or var == 2)
    local cutLeft = (var == 1 or var == 3)
    local hx, hy = 0, 0
    for r = 0, n - 1 do
        local w, xo = n, 0
        if (r == 0 and cutTop) or (r == n - 1 and not cutTop) then
            w = n - 1
            if cutLeft then xo = 1 end
        end
        if r == 0 then hx = xo end
        love.graphics.rectangle("fill", sx + xo * u, sy + r * u, u * w, u)
    end
    if c then
        love.graphics.setColor(math.min(1, c[1] * 1.45 + 0.08), math.min(1, c[2] * 1.45 + 0.08),
            math.min(1, c[3] * 1.45 + 0.08), a)
        love.graphics.rectangle("fill", sx + hx * u, sy + hy * u, u, u)
    end
end

function CeilingDebris.draw(tr)
    if live == 0 or not tr then return end
    local s, ox, oy = tr.scale, tr.ox, tr.oy
    local u = math.max(1, math.floor(s / 2 + 0.5))
    for i = 1, CeilingDebris.MAX do
        local p = pool[i]
        if p.on then
            local st = p.style
            local c = st.colors[p.ci]
            local a = p.alpha
            if p.kind == "puff" then
                local t = p.life / p.maxLife
                local pc = p.puffColor or c
                love.graphics.setColor(pc[1], pc[2], pc[3], a * (1 - t) * (1 - t))
                cell(ox, oy, s, u, p.x, p.y, 1, 1)
            elseif p.kind == "float" then
                local t = p.life / p.maxLife
                local env = math.min(1, t * 6, (1 - t) * 4)
                local tw = 0.75 + 0.25 * math.sin(time * 1.3 + p.phase)
                love.graphics.setColor(c[1], c[2], c[3], a * env * tw)
                cell(ox, oy, s, u, p.x, p.y, 1, 1)
            else
                if p.life < 0.1 then a = a * p.life / 0.1 end
                if p.land >= 0 then
                    local f = p.land - (st.rest or 0)
                    if f > 0 then a = a * (1 - f / CeilingDebris.LAND_FADE) end
                end
                local shape = st.shape
                local px, py = p.x, p.y
                if shape == "feather" then
                    local sw = math.sin(time * (st.swayHz or 2) + p.phase)
                    local dir = sw >= 0 and 1 or -1
                    love.graphics.setColor(c[1], c[2], c[3], a)
                    if math.abs(sw) > 0.45 then
                        cell(ox, oy, s, u, px, py, 3, 1)
                        love.graphics.setColor(c[1] * 0.7, c[2] * 0.7, c[3] * 0.7, a)
                        cell(ox, oy, s, u, px + (dir > 0 and 2 or 0) * u / s, py + u / s, 1, 1)
                    else
                        cell(ox, oy, s, u, px, py, 2, 1)
                        cell(ox, oy, s, u, px + dir * u / s, py + u / s, 1, 1)
                    end
                elseif shape == "shard" then
                    local glint = 0.7 + 0.3 * math.sin(time * 9 + p.phase)
                    love.graphics.setColor(c[1], c[2], c[3], a * glint)
                    if p.land >= 0 or p.var % 2 == 0 then
                        cell(ox, oy, s, u, px, py, 1, p.size + 1)
                    else
                        cell(ox, oy, s, u, px, py, p.size + 1, 1)
                    end
                elseif shape == "ember" then
                    local fl = 0.7 + 0.3 * math.sin(time * 13 + p.phase)
                    love.graphics.setColor(c[1], c[2] * fl, c[3], a * fl)
                    cell(ox, oy, s, u, px, py, 1, 1)
                else
                    love.graphics.setColor(c[1], c[2], c[3], a)
                    chunk(ox, oy, s, u, px, py, p.size, p.land >= 0 and 0 or p.var, c, a)
                end
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function CeilingDebris.clear()
    for i = 1, CeilingDebris.MAX do
        pool[i].on = false
        pool[i].style = nil
    end
    live = 0
    floating = 0
end

function CeilingDebris.count()
    return live
end

function CeilingDebris.floatingCount()
    return floating
end

function CeilingDebris.unitFor(scale)
    return math.max(1, math.floor((scale or 1) / 2 + 0.5))
end

return CeilingDebris
