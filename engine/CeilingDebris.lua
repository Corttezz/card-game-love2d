local CeilingDebris = {}

CeilingDebris.MAX = 120
CeilingDebris.LAND_FADE = 0.45

local pool = {}
for i = 1, CeilingDebris.MAX do
    pool[i] = { on = false, x = 0, y = 0, vx = 0, vy = 0, floorY = 0, life = 0,
                land = -1, phase = 0, size = 1, ci = 1, style = nil, swayK = 0 }
end
local live = 0
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

function CeilingDebris.spawn(style, count, area, cluster)
    if not style or not area then return 0 end
    local made = 0
    local cx = nil
    if cluster then cx = area.x0 + rnd() * (area.x1 - area.x0) end
    for _ = 1, count or 1 do
        local p = slot()
        if not p then break end
        p.on = true
        p.style = style
        if cx then
            p.x = cx + (rnd() - 0.5) * (cluster * 2)
        else
            p.x = area.x0 + rnd() * (area.x1 - area.x0)
        end
        p.y = area.y0 + rnd() * (area.y1 - area.y0)
        p.vx = range(style.vx, 0)
        p.vy = range(style.vy, 20)
        p.floorY = area.floor0 + rnd() * (area.floor1 - area.floor0)
        p.life = 0
        p.land = -1
        p.phase = rnd() * 6.283
        p.size = math.floor(range(style.size, 1) + 0.5)
        p.ci = rnd(1, #style.colors)
        p.swayK = range(style.sway, 0)
        live = live + 1
        made = made + 1
    end
    return made
end

local function kill(p)
    if p.on then
        p.on = false
        p.style = nil
        live = live - 1
    end
end

function CeilingDebris.update(dt)
    time = time + dt
    if live == 0 then return end
    for i = 1, CeilingDebris.MAX do
        local p = pool[i]
        if p.on then
            p.life = p.life + dt
            if p.land >= 0 then
                p.land = p.land + dt
                if p.land >= CeilingDebris.LAND_FADE then kill(p) end
            else
                local st = p.style
                p.vy = math.min(st.vmax or 200, p.vy + (st.gravity or 0) * dt)
                local sway = p.swayK ~= 0 and math.sin(time * (st.swayHz or 2) + p.phase) * p.swayK or 0
                p.x = p.x + (p.vx + sway) * dt
                p.y = p.y + p.vy * dt
                if p.y >= p.floorY then
                    p.y = p.floorY
                    p.land = 0
                end
                if p.life > (st.life or 8) or p.x < -12 or p.x > 412 then kill(p) end
            end
        end
    end
end

local function cell(ox, oy, s, x, y, w, h)
    love.graphics.rectangle("fill", math.floor(ox + x * s), math.floor(oy + y * s),
        math.ceil(s * (w or 1)), math.ceil(s * (h or 1)))
end

function CeilingDebris.draw(tr)
    if live == 0 or not tr then return end
    local s, ox, oy = tr.scale, tr.ox, tr.oy
    for i = 1, CeilingDebris.MAX do
        local p = pool[i]
        if p.on then
            local st = p.style
            local c = st.colors[p.ci]
            local a = st.alpha or 0.9
            if p.life < 0.12 then a = a * p.life / 0.12 end
            if p.land >= 0 then a = a * (1 - p.land / CeilingDebris.LAND_FADE) end
            local px, py = math.floor(p.x), math.floor(p.y)
            local shape = st.shape
            if shape == "feather" then
                local dir = math.sin(time * (st.swayHz or 2) + p.phase) >= 0 and 1 or -1
                love.graphics.setColor(c[1], c[2], c[3], a)
                cell(ox, oy, s, px, py, 2, 1)
                love.graphics.setColor(c[1], c[2], c[3], a * 0.55)
                cell(ox, oy, s, dir > 0 and px + 2 or px - 1, py + 1, 1, 1)
            elseif shape == "shard" then
                local glint = 0.75 + 0.25 * math.sin(time * 9 + p.phase)
                love.graphics.setColor(c[1], c[2], c[3], a * glint)
                cell(ox, oy, s, px, py, 1, p.size + 1)
            elseif shape == "ember" then
                local fl = 0.7 + 0.3 * math.sin(time * 13 + p.phase)
                love.graphics.setColor(c[1], c[2] * fl, c[3], a * fl)
                cell(ox, oy, s, px, py, 1, 1)
            else
                love.graphics.setColor(c[1], c[2], c[3], a)
                cell(ox, oy, s, px, py, p.size, p.size)
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
end

function CeilingDebris.count()
    return live
end

return CeilingDebris
