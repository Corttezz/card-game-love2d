local HandFx = {}

HandFx.DISCARD = 0.62
HandFx.RETAIN = 1.05
HandFx.INNATE = 0.95
HandFx.SHUFFLE = 0.85

local active = {}

local function clamp01(v) return math.max(0, math.min(1, v)) end
local function smooth(v) v = clamp01(v); return v * v * (3 - 2 * v) end

local function reduced()
    return _G.gameSettings and _G.gameSettings.reducedMotion and true or false
end

local function cardRect(card)
    local s = card.currentScale or 1
    local w = (card.image and card.image:getWidth() or 100) * s
    local h = (card.image and card.image:getHeight() or 140) * s
    local x = (card.renderX and card.renderX ~= 0) and card.renderX or card.x or 0
    local y = (card.renderY and card.renderY ~= 0) and card.renderY or card.y or 0
    return x, y, w, h
end

local function screen()
    if not love.graphics then return 1280, 720 end
    return love.graphics.getWidth(), love.graphics.getHeight()
end

function HandFx.discard(card, tx, ty)
    if not card then return nil end
    local x, y, w, h = cardRect(card)
    local sw, sh = screen()
    local fx = { kind = "discard", card = card, t = 0, dur = HandFx.DISCARD,
        x = x, y = y, w = w, h = h, tx = tx or sw * 0.92, ty = ty or sh * 0.82,
        spin = (love.math.random() < 0.5) and -1 or 1 }
    active[#active + 1] = fx
    return fx
end

function HandFx.retain(card)
    if not card then return nil end
    local fx = { kind = "retain", card = card, t = 0, dur = HandFx.RETAIN }
    active[#active + 1] = fx
    return fx
end

function HandFx.innate(card)
    if not card then return nil end
    local fx = { kind = "innate", card = card, t = 0, dur = HandFx.INNATE }
    active[#active + 1] = fx
    return fx
end

function HandFx.reshuffle(n, x, y)
    local sw, sh = screen()
    local fx = { kind = "shuffle", t = 0, dur = HandFx.SHUFFLE,
        x = x or sw * 0.92, y = y or sh * 0.82, n = math.max(5, math.min(8, n or 6)) }
    active[#active + 1] = fx
    return fx
end

function HandFx.update(dt)
    for i = #active, 1, -1 do
        local fx = active[i]
        fx.t = fx.t + dt
        if fx.t >= fx.dur then
            table.remove(active, i)
        end
    end
end

function HandFx.isActive() return #active > 0 end

function HandFx.count(kind)
    local n = 0
    for _, fx in ipairs(active) do
        if not kind or fx.kind == kind then n = n + 1 end
    end
    return n
end

function HandFx.clear() active = {} end

local function drawCardAt(card, x, y, s, rot, a)
    if not card or not card.draw then return end
    local w = (card.image and card.image:getWidth() or 100) * (card.currentScale or 1)
    local h = (card.image and card.image:getHeight() or 140) * (card.currentScale or 1)
    love.graphics.push()
    love.graphics.translate(x + w * s / 2, y + h * s / 2)
    love.graphics.rotate(rot or 0)
    love.graphics.scale(s, s)
    love.graphics.translate(-w / 2, -h / 2)
    love.graphics.setColor(1, 1, 1, a)
    local d = card.dissolve
    card.dissolve = 1 - a
    card:draw(0, 0, false, false)
    card.dissolve = d
    love.graphics.pop()
end

local function drawDiscard(fx)
    local k = smooth(fx.t / fx.dur)
    local s = 1 - 0.6 * k
    local px = fx.x + (fx.tx - fx.w * 0.2 - fx.x) * k
    local py = fx.y + (fx.ty - fx.h * 0.2 - fx.y) * k - math.sin(k * math.pi) * 40
    local rot = fx.spin * k * 0.9
    local a = 1 - smooth((k - 0.65) / 0.35)
    for i = 3, 1, -1 do
        local kk = math.max(0, k - i * 0.06)
        local gx = fx.x + (fx.tx - fx.w * 0.2 - fx.x) * kk
        local gy = fx.y + (fx.ty - fx.h * 0.2 - fx.y) * kk - math.sin(kk * math.pi) * 40
        love.graphics.setColor(0.55, 0.20, 0.16, 0.16 * a * (4 - i) / 3)
        love.graphics.rectangle("fill", gx, gy, fx.w * (1 - 0.6 * kk), fx.h * (1 - 0.6 * kk), 6, 6)
    end
    drawCardAt(fx.card, px, py, s, rot, a)
    if fx.t < 0.22 then
        local sk = fx.t / 0.22
        love.graphics.setColor(0.95, 0.88, 0.75, 0.8 * (1 - sk))
        love.graphics.setLineWidth(3)
        local cx, cy = fx.x + fx.w / 2, fx.y + fx.h / 2
        local r = fx.w * 0.65
        love.graphics.line(cx - r, cy + r * 0.5 - sk * 10, cx + r, cy - r * 0.5 - sk * 10)
        love.graphics.setLineWidth(1)
    end
end

local function chain(x1, y1, x2, y2, links, a, gold)
    local dx, dy = (x2 - x1) / links, (y2 - y1) / links
    for i = 0, links - 1 do
        local cx, cy = x1 + dx * (i + 0.5), y1 + dy * (i + 0.5)
        local horiz = (i % 2 == 0)
        local lw, lh = horiz and 11 or 5, horiz and 5 or 11
        love.graphics.setColor(0.10, 0.07, 0.04, 0.75 * a)
        love.graphics.rectangle("line", cx - lw / 2 + 1, cy - lh / 2 + 1, lw, lh, 2, 2)
        love.graphics.setColor(gold[1], gold[2], gold[3], a)
        love.graphics.rectangle("line", cx - lw / 2, cy - lh / 2, lw, lh, 2, 2)
    end
end

local function drawRetain(fx)
    local x, y, w, h = cardRect(fx.card)
    local t = fx.t / fx.dur
    local inK = smooth(t / 0.25)
    local outK = 1 - smooth((t - 0.7) / 0.3)
    local a = inK * outK
    if a <= 0.01 then return end
    local gold = { 0.96, 0.78, 0.32 }
    local pad = 6 + (1 - inK) * 18
    love.graphics.setColor(gold[1], gold[2], gold[3], 0.22 * a)
    love.graphics.rectangle("fill", x - pad - 4, y - pad - 4, w + (pad + 4) * 2, h + (pad + 4) * 2, 10, 10)
    love.graphics.setLineWidth(2)
    chain(x - pad, y + h * 0.30, x + w + pad, y + h * 0.30 + 10, 9, a, gold)
    chain(x - pad, y + h * 0.70, x + w + pad, y + h * 0.70 - 10, 9, a, gold)
    love.graphics.setLineWidth(1)
    local lx, ly = x + w / 2, y + h * 0.5
    local bob = reduced() and 0 or math.sin(fx.t * 9) * 2 * (1 - t)
    love.graphics.setColor(0.10, 0.07, 0.04, a)
    love.graphics.rectangle("fill", lx - 11, ly - 6 + bob, 22, 17, 3, 3)
    love.graphics.setColor(gold[1], gold[2], gold[3], a)
    love.graphics.rectangle("fill", lx - 9, ly - 4 + bob, 18, 13, 2, 2)
    love.graphics.setLineWidth(3)
    love.graphics.arc("line", "open", lx, ly - 5 + bob, 7, math.pi, 2 * math.pi)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(0.25, 0.15, 0.05, a)
    love.graphics.rectangle("fill", lx - 1.5, ly + 0 + bob, 3, 6)
end

local function drawInnate(fx)
    local x, y, w, h = cardRect(fx.card)
    local t = fx.t / fx.dur
    local a = smooth(t / 0.2) * (1 - smooth((t - 0.6) / 0.4))
    if a <= 0.01 then return end
    local rise = smooth(t) * 34
    love.graphics.setColor(1.0, 0.93, 0.62, 0.30 * a)
    love.graphics.rectangle("fill", x - 4, y - 4, w + 8, h + 8, 8, 8)
    love.graphics.setColor(1.0, 0.93, 0.62, 0.9 * a)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x - 4, y - 4, w + 8, h + 8, 8, 8)
    love.graphics.setLineWidth(1)
    local cx, cy = x + w / 2, y - 22 - rise
    love.graphics.setColor(1.0, 0.93, 0.62, 0.25 * a)
    love.graphics.circle("fill", cx, cy, 26)
    love.graphics.setColor(0.10, 0.07, 0.04, a)
    love.graphics.polygon("fill", cx, cy - 19, cx + 19, cy, cx, cy + 19, cx - 19, cy)
    love.graphics.setColor(1.0, 0.93, 0.62, a)
    love.graphics.polygon("fill", cx, cy - 16, cx + 16, cy, cx, cy + 16, cx - 16, cy)
    love.graphics.setColor(0.35, 0.22, 0.05, a)
    love.graphics.polygon("fill", cx, cy - 7, cx + 7, cy, cx, cy + 7, cx - 7, cy)
end

local function drawShuffle(fx)
    local t = fx.t / fx.dur
    local a = 1 - smooth((t - 0.75) / 0.25)
    local cw, ch = 52, 74
    for i = 1, fx.n do
        local phase = (i - 1) / fx.n
        local k = smooth(clamp01((t - phase * 0.35) / 0.55))
        local ang = phase * math.pi * 2 + k * math.pi * 2
        local r = 84 * math.sin(k * math.pi)
        local cx = fx.x + math.cos(ang) * r
        local cy = fx.y + math.sin(ang) * r * 0.55
        love.graphics.push()
        love.graphics.translate(cx, cy)
        love.graphics.rotate(ang * 0.25)
        love.graphics.setColor(0.10, 0.07, 0.04, 0.85 * a)
        love.graphics.rectangle("fill", -cw / 2 - 2, -ch / 2 - 2, cw + 4, ch + 4, 4, 4)
        love.graphics.setColor(0.48, 0.16, 0.14, a)
        love.graphics.rectangle("fill", -cw / 2, -ch / 2, cw, ch, 3, 3)
        love.graphics.setColor(0.93, 0.78, 0.40, a)
        love.graphics.rectangle("line", -cw / 2 + 4, -ch / 2 + 4, cw - 8, ch - 8, 2, 2)
        love.graphics.pop()
    end
end

function HandFx.draw()
    if #active == 0 then return end
    for _, fx in ipairs(active) do
        if fx.kind == "discard" then drawDiscard(fx)
        elseif fx.kind == "retain" then drawRetain(fx)
        elseif fx.kind == "innate" then drawInnate(fx)
        elseif fx.kind == "shuffle" then drawShuffle(fx)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return HandFx
