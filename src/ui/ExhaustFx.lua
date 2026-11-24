local ExhaustFx = {}

ExhaustFx.DURATION = 1.55
ExhaustFx.HOLD = 1.15
ExhaustFx.DIM = 0.58
ExhaustFx.LIFT = 22
ExhaustFx.DISSOLVE_FAC = 1.6
ExhaustFx.FLAKES = 90

local active = {}

local ASH = {
    { 0.86, 0.83, 0.78 },
    { 0.62, 0.59, 0.55 },
    { 0.38, 0.36, 0.34 },
    { 0.95, 0.52, 0.20 },
}

local function clamp01(v) return math.max(0, math.min(1, v)) end
local function smooth(v) v = clamp01(v); return v * v * (3 - 2 * v) end

function ExhaustFx.isExhausting(card)
    if not card then return false end
    if card.exhaust then return true end
    for _, e in ipairs(card.effects or {}) do
        if e.type == "exhaust" then return true end
    end
    return false
end

local function reduced()
    return _G.gameSettings and _G.gameSettings.reducedMotion and true or false
end

local function frontTime(v)
    local p = clamp01((0.80 - 0.55 * v) / 1.3)
    local x = 0.5 - math.sin(math.asin(1 - 2 * p) / 3)
    return 0.7 * ExhaustFx.DISSOLVE_FAC * x
end

function ExhaustFx.start(card, x, y, w, h)
    local fx = { card = card, t = 0, x = x, y = y, w = w, h = h, flakes = {} }
    if card then card.cardFx = { mode = "ash", progress = 0, seed = love.math.random() * 50 } end
    local n = reduced() and math.floor(ExhaustFx.FLAKES / 3) or ExhaustFx.FLAKES
    for i = 1, n do
        local fy = love.math.random()
        local shade = ASH[(i % 9 == 0) and 4 or love.math.random(1, 3)]
        fx.flakes[i] = {
            u = love.math.random(), v = fy,
            born = frontTime(fy) + love.math.random() * 0.12,
            life = 0.55 + love.math.random() * 0.55,
            vx = (love.math.random() - 0.35) * 46,
            vy = -(28 + love.math.random() * 58),
            size = love.math.random(1, 3),
            c = shade,
        }
    end
    active[#active + 1] = fx
    return fx
end

function ExhaustFx.update(dt)
    for i = #active, 1, -1 do
        local fx = active[i]
        fx.t = fx.t + dt
        local card = fx.card
        if card and card.cardFx and card.cardFx.mode == "ash" then
            card.cardFx.progress = card.dissolve or 0
        end
        if fx.t >= ExhaustFx.DURATION then
            if card and card.cardFx and card.cardFx.mode == "ash" then card.cardFx = nil end
            table.remove(active, i)
        end
    end
end

function ExhaustFx.isActive() return #active > 0 end

function ExhaustFx.isFocused(card)
    for _, fx in ipairs(active) do
        if fx.card == card then return true end
    end
    return false
end

function ExhaustFx.dimAlpha()
    local a = 0
    for _, fx in ipairs(active) do
        local t = fx.t
        local inA = smooth(t / 0.18)
        local outA = 1 - smooth((t - (ExhaustFx.DURATION - 0.45)) / 0.45)
        a = math.max(a, ExhaustFx.DIM * inA * outA)
    end
    return a
end

function ExhaustFx.drawDim()
    local a = ExhaustFx.dimAlpha()
    if a <= 0.001 then return end
    local w, h = love.graphics.getDimensions()
    love.graphics.setColor(0.02, 0.015, 0.02, a)
    love.graphics.rectangle("fill", 0, 0, w, h)
    for _, fx in ipairs(active) do
        local cx, cy = fx.x + fx.w / 2, fx.y + fx.h / 2 - ExhaustFx.LIFT * smooth(fx.t / 0.9)
        local r = math.max(fx.w, fx.h) * 0.85
        for k = 1, 6 do
            love.graphics.setColor(0.55, 0.32, 0.18, a * 0.05)
            love.graphics.circle("fill", cx, cy, r * (0.55 + k * 0.08))
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function ExhaustFx.cardTarget(fx)
    return fx.x, fx.y - ExhaustFx.LIFT
end

function ExhaustFx.drawOver()
    if #active == 0 then return end
    for _, fx in ipairs(active) do
        local lift = ExhaustFx.LIFT * smooth(fx.t / 0.9)
        for _, f in ipairs(fx.flakes) do
            local age = fx.t - f.born
            if age > 0 and age < f.life then
                local k = age / f.life
                local px = fx.x + f.u * fx.w + f.vx * age + math.sin((age + f.u) * 7) * 4
                local py = fx.y + f.v * fx.h - lift + f.vy * age
                local alpha = (1 - k) * (k < 0.12 and k / 0.12 or 1)
                love.graphics.setColor(f.c[1], f.c[2], f.c[3], alpha)
                local s = f.size * (1 - k * 0.5)
                love.graphics.rectangle("fill", math.floor(px), math.floor(py), s * 2, s * 2)
            end
        end
        local la = smooth((fx.t - 0.15) / 0.25) * (1 - smooth((fx.t - 1.05) / 0.4))
        if la > 0.01 then
            local I18n = require("src.i18n.I18n")
            local FontManager = require("src.ui.FontManager")
            local text = I18n.t("keyword.exhaust.name", nil, "Exaurir")
            local font = FontManager.getFont(22)
            love.graphics.setFont(font)
            local tw = font:getWidth(text)
            local tx = math.floor(fx.x + fx.w / 2 - tw / 2)
            local ty = math.floor(fx.y - lift - font:getHeight() - 10 - fx.t * 10)
            love.graphics.setColor(0.08, 0.05, 0.04, la * 0.9)
            for ox = -2, 2, 2 do
                for oy = -2, 2, 2 do
                    if ox ~= 0 or oy ~= 0 then love.graphics.print(text, tx + ox, ty + oy) end
                end
            end
            love.graphics.setColor(0.90, 0.86, 0.80, la)
            love.graphics.print(text, tx, ty)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function ExhaustFx.clear()
    for _, fx in ipairs(active) do
        if fx.card and fx.card.cardFx and fx.card.cardFx.mode == "ash" then fx.card.cardFx = nil end
    end
    active = {}
end

return ExhaustFx
