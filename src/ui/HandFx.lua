local CardBack = require("src.ui.CardBack")

local HandFx = {}

HandFx.DISCARD = 0.62
HandFx.RETAIN = 1.25
HandFx.INNATE = 1.05
HandFx.STAMP = 0.46
HandFx.SHUFFLE = 0.85

local active = {}

local function clamp01(v) return math.max(0, math.min(1, v)) end
local function smooth(v) v = clamp01(v); return v * v * (3 - 2 * v) end

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

local ON_CARD = { retain = "seal", innate = "dawn" }

local function onCard(kind, card, dur)
    if not card then return nil end
    local fx = { kind = kind, card = card, t = 0, dur = dur }
    card.cardFx = { mode = ON_CARD[kind], progress = 0, seed = love.math.random() * 50 }
    fx.cfx = card.cardFx
    active[#active + 1] = fx
    return fx
end

function HandFx.retain(card)
    return onCard("retain", card, HandFx.RETAIN)
end

function HandFx.innate(card)
    local fx = onCard("innate", card, HandFx.INNATE)
    if fx and card.juice_up then card:juice_up(0.12, 0.03) end
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
        local before = fx.t / fx.dur
        fx.t = fx.t + dt
        local k = clamp01(fx.t / fx.dur)
        if fx.cfx then
            fx.cfx.progress = k
            if fx.kind == "retain" and before < HandFx.STAMP and k >= HandFx.STAMP and fx.card.juice_up then
                fx.card:juice_up(0.22, 0.05)
            end
        end
        if fx.t >= fx.dur then
            if fx.cfx and fx.card.cardFx == fx.cfx then fx.card.cardFx = nil end
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

function HandFx.clear()
    for _, fx in ipairs(active) do
        if fx.cfx and fx.card.cardFx == fx.cfx then fx.card.cardFx = nil end
    end
    active = {}
end

local function drawCardAt(card, x, y, s, rot, a, cfx)
    if not card or not card.draw then return end
    local w = (card.image and card.image:getWidth() or 100) * (card.currentScale or 1)
    local h = (card.image and card.image:getHeight() or 140) * (card.currentScale or 1)
    love.graphics.push()
    love.graphics.translate(x + w * s / 2, y + h * s / 2)
    love.graphics.rotate(rot or 0)
    love.graphics.scale(s, s)
    love.graphics.translate(-w / 2, -h / 2)
    love.graphics.setColor(1, 1, 1, a)
    local d, prev = card.dissolve, card.cardFx
    if cfx then
        cfx.alpha = a
        card.dissolve = 0
        card.cardFx = cfx
    else
        card.dissolve = 1 - a
    end
    card:draw(0, 0, false, false)
    card.dissolve = d
    card.cardFx = prev
    love.graphics.pop()
end

local function drawDiscard(fx)
    local k = smooth(fx.t / fx.dur)
    local s = 1 - 0.6 * k
    local px = fx.x + (fx.tx - fx.w * 0.2 - fx.x) * k
    local py = fx.y + (fx.ty - fx.h * 0.2 - fx.y) * k - math.sin(k * math.pi) * 40
    local rot = fx.spin * k * 0.9
    local a = 1 - smooth((k - 0.65) / 0.35)
    fx.wind = fx.wind or { mode = "wind", seed = love.math.random() * 50 }
    fx.wind.progress = clamp01(fx.t / fx.dur)
    fx.wind.side = (fx.tx >= fx.x) and 1 or -1
    drawCardAt(fx.card, px, py, s, rot, a, fx.wind)
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
        CardBack.draw(cx, cy, cw, ch, { alpha = a, rot = ang * 0.25 })
    end
end

function HandFx.draw()
    if #active == 0 then return end
    for _, fx in ipairs(active) do
        if fx.kind == "discard" then drawDiscard(fx)
        elseif fx.kind == "shuffle" then drawShuffle(fx)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return HandFx
