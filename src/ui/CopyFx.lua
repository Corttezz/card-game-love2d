local CopyFx = {}

CopyFx.UNFOLD = 0.42
CopyFx.HOLD = 0.38
CopyFx.FLY = 0.55
CopyFx.DURATION = CopyFx.UNFOLD + CopyFx.HOLD + CopyFx.FLY

local active = {}

local function clamp01(v) return math.max(0, math.min(1, v)) end
local function smooth(v) v = clamp01(v); return v * v * (3 - 2 * v) end
local function outBack(v)
    v = clamp01(v)
    local c1 = 1.70158
    local c3 = c1 + 1
    return 1 + c3 * (v - 1) ^ 3 + c1 * (v - 1) ^ 2
end

function CopyFx.start(copy, sx, sy, w, h, tx, ty)
    if not copy then return nil end
    local sw = love.graphics and love.graphics.getWidth() or 1280
    local side = (sx + w * 1.6 > sw) and -1 or 1
    local fx = {
        card = copy, t = 0, x = sx, y = sy, w = w, h = h,
        tx = tx or sw * 0.92, ty = ty or (love.graphics and love.graphics.getHeight() * 0.82 or 600),
        side = side, sparks = {},
    }
    for i = 1, 14 do
        fx.sparks[i] = { u = love.math.random(), v = love.math.random(),
            born = CopyFx.UNFOLD * 0.6 + love.math.random() * (CopyFx.HOLD + 0.2),
            life = 0.30 + love.math.random() * 0.25 }
    end
    active[#active + 1] = fx
    return fx
end

function CopyFx.update(dt)
    for i = #active, 1, -1 do
        local fx = active[i]
        fx.t = fx.t + dt
        if fx.t >= CopyFx.DURATION then table.remove(active, i) end
    end
end

function CopyFx.isActive() return #active > 0 end

function CopyFx.remaining()
    local r = 0
    for _, fx in ipairs(active) do r = math.max(r, CopyFx.DURATION - fx.t) end
    return r
end

function CopyFx.pose(fx)
    local t = fx.t
    local hingeX = fx.side > 0 and (fx.x + fx.w) or fx.x
    if t < CopyFx.UNFOLD then
        local k = outBack(t / CopyFx.UNFOLD)
        return hingeX, fx.y, math.max(0.02, k), 1, 1
    end
    local restX = hingeX + (fx.side > 0 and 8 or -8)
    if t < CopyFx.UNFOLD + CopyFx.HOLD then
        local b = math.sin((t - CopyFx.UNFOLD) / CopyFx.HOLD * math.pi) * 6
        return restX, fx.y - b, 1, 1, 1
    end
    local k = smooth((t - CopyFx.UNFOLD - CopyFx.HOLD) / CopyFx.FLY)
    local ox = restX + (fx.side > 0 and 0 or -fx.w)
    local px = ox + (fx.tx - fx.w * 0.25 - ox) * k
    local arc = math.sin(k * math.pi) * 70
    local py = fx.y + (fx.ty - fx.h * 0.25 - fx.y) * k - arc
    local s = 1 - 0.55 * k
    local a = 1 - smooth((k - 0.7) / 0.3)
    return px, py, s, s, a, true
end

local function drawCard(card, x, y, sx, sy)
    if not card or not card.draw then return end
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.scale(sx, sy)
    card:draw(0, 0, false, false)
    love.graphics.pop()
end

function CopyFx.draw()
    if #active == 0 then return end
    for _, fx in ipairs(active) do
        local px, py, sx, sy, a, flying = CopyFx.pose(fx)
        local w, h = fx.w * sx, fx.h * sy
        local left
        if flying then
            left = px
        else
            left = fx.side > 0 and px or (px - w)
        end
        love.graphics.setColor(1, 1, 1, a)
        local prev = fx.card.cardFx
        if flying then
            fx.card.dissolve = 1 - a
            fx.card.cardFx = nil
        else
            fx.mirror = fx.mirror or { mode = "mirror", seed = love.math.random() * 50 }
            fx.mirror.progress = clamp01(fx.t / (CopyFx.UNFOLD + CopyFx.HOLD))
            fx.mirror.side = fx.side
            fx.mirror.alpha = a
            fx.card.dissolve = 0
            fx.card.cardFx = fx.mirror
        end
        drawCard(fx.card, left, py, sx, sy)
        fx.card.cardFx = prev
        for _, s in ipairs(fx.sparks) do
            local age = fx.t - s.born
            if age > 0 and age < s.life and not flying then
                local k = age / s.life
                local cx = left + s.u * w
                local cy = py + s.v * h - k * 10
                local r = 3 + 3 * math.sin(k * math.pi)
                love.graphics.setColor(0.92, 0.96, 1.0, 1 - k)
                love.graphics.rectangle("fill", cx - r, cy - 0.5, r * 2, 1)
                love.graphics.rectangle("fill", cx - 0.5, cy - r, 1, r * 2)
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function CopyFx.clear() active = {} end

return CopyFx
