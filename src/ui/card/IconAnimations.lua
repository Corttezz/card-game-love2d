local Palette = require("src.ui.Palette")

local IconAnimations = {}

local CATEGORY = {
    sword_short = "weapon_shine",
    sword_great = "weapon_shine",
    axe         = "weapon_shine",
    dagger      = "blood_drip",
    claw        = "blood_drip",
    fang        = "blood_drip",
    crystal     = "sparkle",
    orb         = "sparkle",
    rune        = "sparkle",
    gem         = "sparkle",
    star        = "sparkle",
    coin        = "sparkle",
    barrier     = "sparkle",
    fireball    = "flicker",
    flame       = "flicker",
    bolt        = "soft_pulse",
    snowflake   = "shimmer",
    water_drop  = "shimmer",
    heart       = "soft_pulse",
    skull       = "soft_pulse",
    skull_crowned = "soft_pulse",
    moon        = "soft_pulse",
    eye         = "soft_pulse",
    potion_red  = "bubble",
    potion_blue = "bubble",
    shield_round = "weapon_shine",
    shield_kite  = "weapon_shine",
    joker_abyss   = "deity_eyes",
    joker_shield  = "soft_pulse",
    joker_vampire = "deity_eyes",
    joker_jester  = "soft_pulse",
}

function IconAnimations.categoryFor(iconName)
    return CATEGORY[iconName or ""]
end

local Effects = {}

function Effects.weapon_shine(x, y, w, h, t)
    local cycle = (t * 0.15) % 6
    if cycle > 1.2 then return end
    local progress = cycle / 1.2
    local width = math.min(w, h)
    local offset = -width * 0.5 + progress * (w + width)
    love.graphics.setBlendMode("add", "alphamultiply")
    local count = math.floor(width * 0.6)
    for i = 0, count do
        local px = math.floor(x + offset - i)
        local py = math.floor(y + i)
        if px >= x and px < x + w and py >= y and py < y + h then
            local peak = 1 - math.abs(progress - 0.5) * 2
            love.graphics.setColor(1, 1, 0.9, peak * 0.22)
            love.graphics.rectangle("fill", px, py, 1, 1)
        end
    end
    love.graphics.setBlendMode("alpha")
end

function Effects.blood_drip(x, y, w, h, t)
    local cycle = (t * 0.2) % 5
    if cycle > 1.6 then return end
    local progress = cycle / 1.6
    local dx = x + w / 2
    local dy = y + h * 0.58 + progress * h * 0.3
    local alpha = (1 - progress) * 0.55
    love.graphics.setColor(Palette.BLOOD[1], Palette.BLOOD[2], Palette.BLOOD[3], alpha)
    love.graphics.rectangle("fill", math.floor(dx - 0.5), math.floor(dy), 1, 2)
end

function Effects.sparkle(x, y, w, h, t)
    local points = { { 0.28, 0.30 }, { 0.68, 0.60 } }
    for i, p in ipairs(points) do
        local phase = t * 1.3 + i * 2.1
        local alpha = math.max(0, math.sin(phase)) * 0.35
        if alpha > 0.1 then
            local px = math.floor(x + p[1] * w)
            local py = math.floor(y + p[2] * h)
            love.graphics.setColor(1, 1, 1, alpha)
            love.graphics.rectangle("fill", px, py, 1, 1)
        end
    end
end

function Effects.flicker(x, y, w, h, t)
    local cycle = (t * 0.6) % 3
    local progress = cycle / 3
    local px = x + w * (0.45 + math.sin(t * 0.5) * 0.08)
    local py = y + h * 0.7 - progress * h * 0.4
    local alpha = (1 - progress) * 0.3
    love.graphics.setColor(Palette.RUST[1], Palette.RUST[2], Palette.RUST[3], alpha)
    love.graphics.rectangle("fill", math.floor(px), math.floor(py), 1, 1)
end

function Effects.soft_pulse(x, y, w, h, t)
    local amp = 0.1 + math.sin(t * 1.5) * 0.08
    if amp < 0.04 then return end
    love.graphics.setBlendMode("add", "alphamultiply")
    love.graphics.setColor(Palette.AGED_GOLD_LIGHT[1], Palette.AGED_GOLD_LIGHT[2], Palette.AGED_GOLD_LIGHT[3], amp)
    love.graphics.rectangle("fill", x + w * 0.4, y + h * 0.4, w * 0.2, h * 0.2)
    love.graphics.setBlendMode("alpha")
end

function Effects.shimmer(x, y, w, h, t)
    local phase = t * 2.5
    local alpha = math.max(0, math.sin(phase)) * 0.25
    if alpha > 0.08 then
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.rectangle("fill", x + w * 0.5, y + h * 0.45, 1, 1)
    end
end

function Effects.deity_eyes(x, y, w, h, t)
    local points = { { 0.32, 0.42 }, { 0.68, 0.42 } }
    for i, p in ipairs(points) do
        local phase = t * 1.8 + i * 0.3
        local alpha = (0.15 + math.max(0, math.sin(phase)) * 0.25)
        love.graphics.setBlendMode("add", "alphamultiply")
        love.graphics.setColor(Palette.AGED_GOLD_LIGHT[1], Palette.AGED_GOLD_LIGHT[2], Palette.AGED_GOLD_LIGHT[3], alpha)
        local px = math.floor(x + p[1] * w)
        local py = math.floor(y + p[2] * h)
        love.graphics.rectangle("fill", px, py, 2, 2)
        love.graphics.setBlendMode("alpha")
    end
end

function Effects.bubble(x, y, w, h, t)
    local cycle = (t * 0.5) % 4
    if cycle > 1.5 then return end
    local progress = cycle / 1.5
    local px = x + w * 0.5
    local py = y + h * 0.6 - progress * h * 0.15
    love.graphics.setColor(1, 1, 1, (1 - progress) * 0.35)
    love.graphics.rectangle("fill", math.floor(px), math.floor(py), 1, 1)
end

function IconAnimations.draw(iconName, x, y, w, h, t)
    local cat = IconAnimations.categoryFor(iconName)
    if not cat then return end
    local fn = Effects[cat]
    if not fn then return end
    fn(x, y, w, h, t or love.timer.getTime())
end

return IconAnimations
