local Palette = require("src.ui.Palette")
local IconFramesLoader  = require("src.ui.IconFramesLoader")
local IconAnimations = require("src.ui.card.IconAnimations")

local CardAnimationLayer = {}

local enabled = true
function CardAnimationLayer.setEnabled(v) enabled = v end
function CardAnimationLayer.isEnabled() return enabled end

local CANVAS_W, CANVAS_H = 96, 144

local function drawPulsingBorder(x, y, w, h, color, alpha, thickness)
    thickness = thickness or 2
    love.graphics.setColor(color[1], color[2], color[3], alpha)
    for i = 0, thickness - 1 do
        love.graphics.rectangle("line", x - i, y - i, w + i * 2, h + i * 2)
    end
end

local function legendaryHalo(x, y, sx, sy, t)
    local alpha = 0.25 + math.sin(t * 2.0) * 0.15
    local w = CANVAS_W * sx
    local h = CANVAS_H * sy
    drawPulsingBorder(x, y, w, h, Palette.AGED_GOLD_LIGHT, alpha, 2)
    drawPulsingBorder(x - 2, y - 2, w + 4, h + 4, Palette.AGED_GOLD, alpha * 0.4, 1)
end

local function embers(x, y, sx, sy, t)
    local aX = x + 4 * sx
    local aY = y + 17 * sy
    local aW = 88 * sx
    local aH = 107 * sy
    for i = 0, 4 do
        local seed = i * 2.7
        local px = aX + ((math.sin(t * 0.5 + seed) + 1) / 2) * aW
        local cycle = (t * 20 + i * 30) % 80
        local py = aY + aH - cycle * (aH / 80)
        local alpha = 1 - cycle / 80
        local col = (i % 2 == 0) and Palette.BLOOD or Palette.RUST
        love.graphics.setColor(col[1], col[2], col[3], alpha * 0.9)
        love.graphics.rectangle("fill", px, py, math.max(2, 2 * sx), math.max(2, 2 * sy))
        love.graphics.setColor(Palette.AGED_GOLD_LIGHT[1], Palette.AGED_GOLD_LIGHT[2], Palette.AGED_GOLD_LIGHT[3], alpha * 0.5)
        love.graphics.rectangle("fill", px, py - 1, math.max(1, sx), math.max(1, sy))
    end
end

local function bloodDrip(x, y, sx, sy, t)
    local aX = x + 8 * sx
    local aY = y + 17 * sy
    local aH = 107 * sy
    local cycle = (t * 30) % 180
    if cycle > aH then return end
    local dropY = aY + cycle
    local alpha = 1 - cycle / aH
    love.graphics.setColor(Palette.BLOOD[1], Palette.BLOOD[2], Palette.BLOOD[3], alpha)
    love.graphics.rectangle("fill", aX, dropY, 2 * sx, 3 * sy)
end

local function poisonBubbles(x, y, sx, sy, t)
    local aX = x + 4 * sx
    local aY = y + 17 * sy
    local aW = 88 * sx
    local aH = 107 * sy
    for i = 0, 4 do
        local seed = i * 3.1
        local px = aX + ((math.sin(t * 0.4 + seed) + 1) / 2) * aW
        local cycle = (t * 15 + i * 35) % 90
        local py = aY + aH - cycle * (aH / 90)
        local alpha = 1 - cycle / 90
        local col = (i % 2 == 0) and Palette.MOSS or Palette.GREEN_BRIGHT
        love.graphics.setColor(col[1], col[2], col[3], alpha * 0.8)
        local size = math.max(2, 2 * sx)
        love.graphics.rectangle("fill", px, py, size, size)
        if i % 2 == 0 then
            love.graphics.setColor(Palette.PARCHMENT_LIGHT[1], Palette.PARCHMENT_LIGHT[2], Palette.PARCHMENT_LIGHT[3], alpha * 0.4)
            love.graphics.rectangle("fill", px, py - 1, math.max(1, sx), math.max(1, sy))
        end
    end
end

local function arcaneGlyphs(x, y, sx, sy, t)
    local aX = x + 4 * sx
    local aY = y + 17 * sy
    local aW = 88 * sx
    local aH = 107 * sy
    local positions = {
        { 0.25, 0.30 }, { 0.68, 0.35 },
        { 0.30, 0.68 }, { 0.70, 0.70 },
    }
    for i, p in ipairs(positions) do
        local phase = t * 1.1 + i * 1.5
        local driftX = math.sin(phase) * 6 * sx
        local driftY = math.cos(phase * 0.8) * 4 * sy
        local alpha = 0.25 + math.max(0, math.sin(phase * 0.9)) * 0.35
        local px = aX + p[1] * aW + driftX
        local py = aY + p[2] * aH + driftY
        love.graphics.setBlendMode("add", "alphamultiply")
        love.graphics.setColor(Palette.AGED_GOLD_LIGHT[1], Palette.AGED_GOLD_LIGHT[2], Palette.AGED_GOLD_LIGHT[3], alpha)
        local s = math.max(1, sx)
        love.graphics.rectangle("fill", px, py - s, s, s)
        love.graphics.rectangle("fill", px - s, py, s, s)
        love.graphics.rectangle("fill", px, py, s, s)
        love.graphics.rectangle("fill", px + s, py, s, s)
        love.graphics.rectangle("fill", px, py + s, s, s)
        love.graphics.setBlendMode("alpha")
    end
end

local function shadowWisps(x, y, sx, sy, t)
    local aX = x + 4 * sx
    local aY = y + 17 * sy
    local aW = 88 * sx
    local aH = 107 * sy

    for i = 0, 5 do
        local seed = i * 2.3
        local px = aX + (0.10 + i * 0.16) * aW + math.sin(t * 0.6 + seed) * 6 * sx
        local cycle = (t * 14 + i * 25) % 110
        local py = aY + aH - cycle * (aH / 110)
        local alpha = 1 - cycle / 110
        love.graphics.setColor(Palette.INK[1] * 2, Palette.INK[2] * 2, Palette.INK[3] * 2, alpha * 0.7)
        local size = math.max(2, 3 * sx)
        love.graphics.rectangle("fill", px, py, size, math.max(3, 5 * sy))
        if i % 2 == 1 then
            love.graphics.setColor(Palette.MAGENTA_DARK[1], Palette.MAGENTA_DARK[2], Palette.MAGENTA_DARK[3], alpha * 0.5)
            love.graphics.rectangle("fill", px + 1, py, math.max(1, sx), math.max(2, 3 * sy))
        end
    end

    for i = 0, 2 do
        local phase = t * 0.8 + i * 1.5
        local px = aX + ((math.sin(phase) + 1) / 2) * aW
        local py = aY + (0.25 + i * 0.25) * aH + math.cos(phase * 0.7) * 6 * sy
        local alpha = 0.4 + math.max(0, math.sin(phase * 1.3)) * 0.4
        love.graphics.setColor(Palette.PURPLE_DEEP[1], Palette.PURPLE_DEEP[2], Palette.PURPLE_DEEP[3], alpha)
        love.graphics.rectangle("fill", px, py, math.max(1, sx), math.max(1, sy))
    end
end

local function abyssEyes(x, y, sx, sy, t)
    local aX = x + 4 * sx
    local aY = y + 17 * sy
    local aW = 88 * sx
    local aH = 107 * sy

    local eyes = {
        { 0.25, 0.42 }, { 0.70, 0.38 }, { 0.50, 0.72 },
        { 0.15, 0.65 }, { 0.85, 0.60 },
    }
    for i, p in ipairs(eyes) do
        local phase = t * 1.4 + i * 1.9
        local open = math.max(0, math.sin(phase))
        if open >= 0.15 then
            local alpha = 0.55 * open
            local px = aX + p[1] * aW
            local py = aY + p[2] * aH
            love.graphics.setBlendMode("add", "alphamultiply")
            love.graphics.setColor(Palette.AGED_GOLD_LIGHT[1], Palette.AGED_GOLD_LIGHT[2], Palette.AGED_GOLD_LIGHT[3], alpha)
            local s = math.max(2, 2 * sx)
            love.graphics.rectangle("fill", px, py, s, s)
            love.graphics.setBlendMode("alpha")
            love.graphics.setColor(Palette.INK[1], Palette.INK[2], Palette.INK[3], alpha)
            love.graphics.rectangle("fill", px, py, math.max(1, sx), math.max(1, sy))
        end
    end

    local rCycle = t % 4
    if rCycle < 1.5 then
        local progress = rCycle / 1.5
        for i = 0, 1 do
            local px = aX + (0.35 + i * 0.3) * aW
            local py = aY + aH - progress * aH * 0.4
            local alpha = (1 - progress) * 0.5
            love.graphics.setColor(Palette.INK[1] * 2, Palette.INK[2] * 2, Palette.INK[3] * 2, alpha)
            local s = math.max(2, 3 * sx)
            love.graphics.rectangle("fill", px, py, s, s)
            love.graphics.setColor(Palette.MAGENTA_DARK[1], Palette.MAGENTA_DARK[2], Palette.MAGENTA_DARK[3], alpha * 0.7)
            love.graphics.rectangle("fill", px - 1, py + 1, math.max(1, sx), math.max(1, sy))
        end
    end

    for i = 0, 1 do
        local sideX = (i == 0) and (aX + 4 * sx) or (aX + aW - 4 * sx)
        local swayPhase = t * 1.0 + i * 2
        for k = 0, 6 do
            local sway = math.sin(swayPhase + k * 0.3) * 2 * sx
            local px = sideX + sway
            local py = aY + (k * aH / 6)
            local alpha = 0.25 + (k / 6) * 0.15
            love.graphics.setColor(Palette.MAGENTA_DARK[1], Palette.MAGENTA_DARK[2], Palette.MAGENTA_DARK[3], alpha)
            love.graphics.rectangle("fill", px, py, math.max(1, sx), math.max(2, 3 * sy))
        end
    end
end

local function voidTwinkle(x, y, sx, sy, t)
    local aX = x + 4 * sx
    local aY = y + 17 * sy
    local aW = 88 * sx
    local aH = 107 * sy

    local stars = {
        { 0.15, 0.20 }, { 0.45, 0.35 }, { 0.75, 0.15 },
        { 0.30, 0.75 }, { 0.82, 0.65 },
        { 0.55, 0.55 }, { 0.20, 0.50 },
    }
    for i, s in ipairs(stars) do
        local phase = t * 3.2 + i * 1.3
        local alpha = math.max(0, math.sin(phase)) * 0.95
        if alpha > 0.15 then
            local px = aX + s[1] * aW
            local py = aY + s[2] * aH
            love.graphics.setColor(1, 1, 1, alpha)
            local sz = math.max(1, sx)
            love.graphics.rectangle("fill", px, py, sz, sz)
            if i % 3 == 0 and alpha > 0.5 then
                love.graphics.setColor(Palette.AGED_GOLD_LIGHT[1], Palette.AGED_GOLD_LIGHT[2], Palette.AGED_GOLD_LIGHT[3], alpha * 0.7)
                love.graphics.rectangle("fill", px - sz, py, sz, sz)
                love.graphics.rectangle("fill", px + sz, py, sz, sz)
                love.graphics.rectangle("fill", px, py - sz, sz, sz)
                love.graphics.rectangle("fill", px, py + sz, sz, sz)
            end
        end
    end

    local sCycle = t % 5
    if sCycle < 0.6 then
        local progress = sCycle / 0.6
        local startX = aX + aW * 0.05
        local startY = aY + aH * 0.15
        local endX   = aX + aW * 0.95
        local endY   = aY + aH * 0.55
        local px = startX + (endX - startX) * progress
        local py = startY + (endY - startY) * progress
        local alpha = math.sin(progress * math.pi) * 0.95
        love.graphics.setColor(1, 1, 1, alpha)
        local sz = math.max(2, 2 * sx)
        love.graphics.rectangle("fill", px, py, sz, sz)
        for k = 1, 3 do
            local tp = math.max(0, progress - k * 0.06)
            local tpx = startX + (endX - startX) * tp
            local tpy = startY + (endY - startY) * tp
            love.graphics.setColor(Palette.AGED_GOLD_LIGHT[1], Palette.AGED_GOLD_LIGHT[2], Palette.AGED_GOLD_LIGHT[3], alpha * (1 - k * 0.3))
            love.graphics.rectangle("fill", tpx, tpy, math.max(1, sx), math.max(1, sy))
        end
    end

    for i = 0, 3 do
        local phase = t * 0.4 + i * 1.7
        local px = aX + ((math.sin(phase) + 1) / 2) * aW
        local py = aY + ((math.cos(phase * 0.7) + 1) / 2) * aH
        local alpha = 0.25 + math.max(0, math.sin(phase * 1.5)) * 0.25
        local col = (i % 2 == 0) and Palette.PURPLE or Palette.STEEL_LIGHT
        love.graphics.setColor(col[1], col[2], col[3], alpha)
        love.graphics.rectangle("fill", px, py, math.max(1, sx), math.max(1, sy))
    end
end

function CardAnimationLayer.draw(card, art, x, y, scaleX, scaleY, t)
    if not enabled then return end
    if _G.gameSettings and _G.gameSettings.reducedMotion then return end
    scaleX = scaleX or 1
    scaleY = scaleY or 1
    t = t or love.timer.getTime()

    local r, g, b, a = love.graphics.getColor()
    love.graphics.setBlendMode("alpha")

    local rarity = card.rarity or "common"

    if rarity == "legendary" then
        legendaryHalo(x, y, scaleX, scaleY, t)
    end

    local bg = art and art.bgPattern
    if bg == "fire" or bg == "rage" then
        embers(x, y, scaleX, scaleY, t)
    elseif bg == "blood" then
        bloodDrip(x, y, scaleX, scaleY, t)
    elseif bg == "poison" then
        poisonBubbles(x, y, scaleX, scaleY, t)
    elseif bg == "arcane" then
        arcaneGlyphs(x, y, scaleX, scaleY, t)
    elseif bg == "shadow" then
        shadowWisps(x, y, scaleX, scaleY, t)
    elseif bg == "abyss" then
        abyssEyes(x, y, scaleX, scaleY, t)
    elseif bg == "void" then
        voidTwinkle(x, y, scaleX, scaleY, t)
    end

    if art and art.iconName and not IconFramesLoader.has(art.iconName) then
        local iconX = x + 16 * scaleX
        local iconY = y + 38 * scaleY
        local iconW = 64 * scaleX
        local iconH = 64 * scaleY
        IconAnimations.draw(art.iconName, iconX, iconY, iconW, iconH, t)
    end

    love.graphics.setColor(r, g, b, a)
end

return CardAnimationLayer
