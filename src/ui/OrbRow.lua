local Debug = require("src.core.Debug")

local Palette = require("src.ui.Palette")
local FontManager = require("src.ui.FontManager")
local StatusTooltip = require("src.ui.StatusTooltip")

local OrbRow = {}

local SIZE = 48
local SPACING = 12
local PLATE_H = 18
local GAP_GEM_PLATE = 2
local GAP_ABOVE_PILLS = 16

OrbRow.COLORS = {
    lightning = { 0.95, 0.85, 0.30 },
    ice       = { 0.45, 0.75, 0.95 },
    dark      = { 0.60, 0.40, 0.85 },
    fire      = { 0.95, 0.50, 0.20 },
    holy      = { 0.95, 0.90, 0.62 },
}
local EVOKE_CYAN = { 0.25, 0.95, 0.95 }

OrbRow.ART = {
    lightning = "assets/sprites/orbs/lightning.png",
    ice       = "assets/sprites/orbs/ice.png",
    fire      = "assets/sprites/orbs/fire.png",
    dark      = "assets/sprites/orbs/dark.png",
    holy      = "assets/sprites/orbs/holy.png",
}

local ANIM_ROOT = "assets/sprites/orbs_anim"
local PHASE_STEP = 0.37

OrbRow.ANIM_ROOT = ANIM_ROOT

local FramesLoader = require("src.ui.IconFramesLoader")
local animWarned = {}

function OrbRow.animationFor(orbType)
    if not orbType then return nil end
    local handle = FramesLoader.getFrom(ANIM_ROOT, orbType)
    if handle then return handle end
    if not animWarned[orbType]
        and love.filesystem.getInfo(ANIM_ROOT .. "/" .. tostring(orbType), "directory") then
        animWarned[orbType] = true
        Debug.warn(("[OrbRow] %s/%s existe mas nao tem frame_NNN.png legivel -- "
            .. "caindo no PNG estatico"):format(ANIM_ROOT, tostring(orbType)))
    end
    return nil
end

local ImageCache = require("src.ui.ImageCache")
local gemCache = {}
local warnedGem = {}
local function gemOf(orbType)
    if gemCache[orbType] ~= nil then return gemCache[orbType] or nil end
    local path = OrbRow.ART[orbType]
    local img = path and ImageCache.tryGet(path) or nil
    if img then
        img:setFilter("nearest", "nearest")
    elseif not warnedGem[orbType] then
        warnedGem[orbType] = true
        Debug.warn("[OrbRow] sem arte de gema pra '" .. tostring(orbType)
            .. "' — registre em OrbRow.ART (esperado 48x48 nativo)")
    end
    gemCache[orbType] = img or false
    return img
end

function OrbRow.gemImageAt(orbType, t)
    local anim = OrbRow.animationFor(orbType)
    if anim then
        local frame = anim:frameAt(t or 0)
        if frame then return frame, (t ~= nil) end
    end
    return gemOf(orbType), false
end

local UNIT_OF = {
    pulse = { lightning = "damage", fire = "damage", ice = "block",
              holy = "heal", dark = "grow" },
    evoke = { lightning = "damage", fire = "damage", ice = "block",
              holy = "heal", dark = "damage" },
}
local UNIT_COLOR = {
    damage = { 1.00, 0.45, 0.35 },
    block  = { 0.58, 0.78, 1.00 },
    heal   = { 0.50, 0.95, 0.55 },
    grow   = { 0.80, 0.62, 1.00 },
}

OrbRow.UNIT_OF = UNIT_OF

function OrbRow.readout(orb, focus, mode)
    local EffectSystem = require("src.systems.EffectSystem")
    if mode == "evoke" then
        return EffectSystem.orbEvokeValue(orb, focus), UNIT_OF.evoke[orb.type]
    end
    if orb.type == "dark" then
        return (orb.value or 1), UNIT_OF.pulse.dark
    end
    return EffectSystem.orbPulseValue(orb, focus), UNIT_OF.pulse[orb.type]
end

local function drawUnitGlyph(unit, x, y, h)
    local a = h * 0.5
    love.graphics.setLineWidth(2)
    if unit == "damage" then
        local w = a * 0.22
        love.graphics.polygon("fill",
            x, y - a,  x + w, y - w,  x + a, y,  x + w, y + w,
            x, y + a,  x - w, y + w,  x - a, y,  x - w, y - w)
    elseif unit == "block" then
        love.graphics.polygon("fill",
            x - a, y - a, x + a, y - a, x + a, y * 1 + a * 0.2,
            x, y + a, x - a, y + a * 0.2)
    elseif unit == "heal" then
        love.graphics.line(x, y - a, x, y + a)
        love.graphics.line(x - a, y, x + a, y)
    elseif unit == "grow" then
        love.graphics.polygon("fill", x, y - a, x + a, y + a * 0.15, x - a, y + a * 0.15)
        love.graphics.rectangle("fill", x - a * 0.32, y + a * 0.1, a * 0.64, a * 0.9)
    end
end

local slotPos = nil
local slotAnim = {}
local pulseFlash = {}
local animTime = 0
local previewMode = nil

local inbound = {}
local outbound = {}

local FLIGHT_IN  = 0.26
local FLIGHT_OUT = 0.45

local function reducedMotion()
    return (_G.gameSettings and _G.gameSettings.reducedMotion) or false
end

local function tutNote(ev, info)
    pcall(function() require("src.systems.Tutorial").noteEvent(ev, info) end)
end

local function gemClock(i)
    if reducedMotion() then return nil end
    return animTime + (i - 1) * PHASE_STEP
end

local function decay(tbl, dt)
    for k, v in pairs(tbl) do
        tbl[k] = v - dt
        if tbl[k] <= 0 then tbl[k] = nil end
    end
end

local function spellOrigin()
    return love.graphics.getWidth() * 0.5, love.graphics.getHeight() * 0.52
end

function OrbRow.notifyChannel(i, orb)
    tutNote("orb_channel", { slot = i, type = orb and orb.type })
    if reducedMotion() then
        slotAnim[i] = 1.0
        return
    end
    inbound[i] = {
        t = 0, dur = FLIGHT_IN,
        otype = orb and orb.type,
        color = OrbRow.COLORS[orb and orb.type] or { 0.85, 0.85, 0.85 },
    }
end

function OrbRow.notifyPulse(i, text, kind)
    tutNote("orb_pulse", { slot = i, text = text, kind = kind })
    pulseFlash[i] = 1.0
    if slotPos and slotPos[i] then
        local okFT, FloatingText = pcall(require, "src.ui.FloatingText")
        if okFT and FloatingText.spawn then
            local ftKind = (kind == "damage") and "damage"
                or (kind == "heal") and "heal" or "armor"
            FloatingText.spawn(text, slotPos[i].x, slotPos[i].y - SIZE * 0.7,
                { kind = ftKind, fontSize = 16, lift = 34 })
        end
    end
end

function OrbRow.burstAtSlot(i, theme, k)
    if not (slotPos and slotPos[i]) then return end
    local ok, CardFeel = pcall(require, "src.systems.CardFeel")
    if ok and CardFeel.burst then
        CardFeel.burst(theme, slotPos[i].x, slotPos[i].y, k or 1)
    end
end

function OrbRow.notifyEvoke(i, orb, reason)
    local I18n = require("src.i18n.I18n")
    local isOverflow = (reason == "overflow")
    tutNote(isOverflow and "orb_overflow" or "orb_evoke", { slot = i, type = orb and orb.type })
    local label = isOverflow
        and I18n.t("orb.expelled", nil, "EXPULSO")
        or I18n.t("orb.evoked", nil, "EVOCADO")
    local color = OrbRow.COLORS[orb and orb.type] or { 0.95, 0.90, 0.78 }
    if isOverflow then color = { 0.95, 0.72, 0.30 } end

    outbound[#outbound + 1] = {
        slot = i, t = 0, dur = reducedMotion() and 0.0001 or FLIGHT_OUT,
        color = color, otype = orb and orb.type,
    }
    if slotPos and slotPos[i] then
        local okFT, FloatingText = pcall(require, "src.ui.FloatingText")
        if okFT and FloatingText.spawn then
            local half = FontManager.getFont(14):getWidth(label) * 0.5
            local x = math.max(slotPos[i].x, half + 6)
            FloatingText.spawn(label, x, slotPos[i].y - SIZE * 0.8,
                { color = color, fontSize = 14, hold = 0.4, lift = 26 })
        end
    end
end

local function cellHeight()
    return SIZE + GAP_GEM_PLATE + PLATE_H
end

local function drawPlate(x, y, w, color, unit, value, font)
    love.graphics.setColor(0.07, 0.05, 0.04, 0.95)
    love.graphics.rectangle("fill", x, y, w, PLATE_H)
    love.graphics.setColor(Palette.INK[1], Palette.INK[2], Palette.INK[3], 1)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x - 1, y - 1, w + 2, PLATE_H + 2)
    love.graphics.setColor(color[1], color[2], color[3], 1)
    love.graphics.rectangle("line", x, y, w, PLATE_H)

    local txt = tostring(value)
    love.graphics.setFont(font)
    local tw = font:getWidth(txt)
    local gh = PLATE_H - 8
    local gap = 3
    local total = gh + gap + tw
    local cx = x + w / 2
    local cy = y + PLATE_H / 2
    local gx = cx - total / 2 + gh / 2
    local nx = math.floor(cx - total / 2 + gh + gap)
    local ny = math.floor(cy - font:getHeight() / 2)

    local uc = UNIT_COLOR[unit or ""] or { 1, 1, 1 }
    love.graphics.setColor(0, 0, 0, 0.9)
    drawUnitGlyph(unit, gx + 1, cy + 1, gh)
    love.graphics.setColor(uc[1], uc[2], uc[3], 1)
    drawUnitGlyph(unit, gx, cy, gh)

    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.print(txt, nx + 1, ny + 1)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(txt, nx, ny)
end

local function drawGem(orbType, x, y, alpha, flash, t)
    local img = OrbRow.gemImageAt(orbType, t)
    if not img then return false end
    love.graphics.setColor(1, 1, 1, alpha or 1)
    love.graphics.draw(img, math.floor(x), math.floor(y))
    if flash and flash > 0 then
        local prev = love.graphics.getBlendMode()
        love.graphics.setBlendMode("add")
        love.graphics.setColor(flash * 0.7, flash * 0.7, flash * 0.7, 1)
        love.graphics.draw(img, math.floor(x), math.floor(y))
        love.graphics.setBlendMode(prev)
    end
    return true
end

function OrbRow.clear()
    for k in pairs(inbound) do inbound[k] = nil end
    for k = #outbound, 1, -1 do outbound[k] = nil end
    for k in pairs(slotAnim) do slotAnim[k] = nil end
    for k in pairs(pulseFlash) do pulseFlash[k] = nil end
end

function OrbRow.update(dt, game)
    animTime = animTime + (dt or 0)
    decay(slotAnim, (dt or 0) * 3)
    decay(pulseFlash, (dt or 0) * 1.6)

    for i, fx in pairs(inbound) do
        fx.t = fx.t + (dt or 0)
        if fx.t >= fx.dur then
            inbound[i] = nil
            slotAnim[i] = 1.0
        end
    end
    for k = #outbound, 1, -1 do
        local fx = outbound[k]
        fx.t = fx.t + (dt or 0)
        if fx.t >= fx.dur then table.remove(outbound, k) end
    end

    previewMode = nil
    if game and game.hand then
        for _, c in ipairs(game.hand) do
            if c.isHovered and c.effects then
                for _, e in ipairs(c.effects) do
                    if e.type == "evoke_all_orbs" then
                        previewMode = "evoke_all"
                    elseif e.type == "evoke_orb" and previewMode ~= "evoke_all" then
                        previewMode = "evoke_one"
                    elseif (e.type == "channel_orb" or e.type == "channel_per_turn")
                        and not previewMode then
                        previewMode = "channel"
                    end
                end
            end
        end
    end
end

local function isVisible(game)
    if not game or not game.player then return false end
    local p = game.player
    if (p.orbSlots or 0) <= 0 then return false end
    return game.selectedClass == "mage" or #(p.orbs or {}) > 0
end

function OrbRow.draw(game, panelX, panelY)
    if not isVisible(game) then
        slotPos = nil
        return
    end
    local p = game.player
    local focus = (p.getBuffStacks and p:getBuffStacks("focus")) or 0
    local EffectSystem = require("src.systems.EffectSystem")

    local PlayerBuffPills = require("src.ui.PlayerBuffPills")
    local startX = math.floor(panelX)
    local y = math.floor(PlayerBuffPills.getBandTop(panelY)
        - GAP_ABOVE_PILLS - cellHeight())

    slotPos = {}
    local mx, my = love.mouse.getPosition()
    local font = FontManager.getResponsiveFont(0.021, 13)
    local plateY = y + SIZE + GAP_GEM_PLATE
    local plateInset = 3
    local plateW = SIZE - plateInset * 2

    for i = 1, (p.orbSlots or 3) do
        local x = startX + (i - 1) * (SIZE + SPACING)
        local cx, cy = x + SIZE / 2, y + SIZE / 2
        slotPos[i] = { x = cx, y = cy }
        local orb = (not inbound[i]) and p.orbs and p.orbs[i] or nil

        if not orb then
            love.graphics.setColor(0.10, 0.07, 0.05, 0.55)
            love.graphics.circle("fill", cx, cy, SIZE / 2 - 8)
            love.graphics.setColor(0.45, 0.40, 0.32, 0.45)
            love.graphics.setLineWidth(1)
            love.graphics.circle("line", cx, cy, SIZE / 2 - 8)
            if previewMode == "channel" and (p.orbs and #p.orbs + 1 == i or (not p.orbs and i == 1)) then
                local blink = reducedMotion() and 0.9
                    or (0.5 + math.sin(animTime * 6) * 0.4)
                love.graphics.setColor(0.95, 0.85, 0.30, blink * 0.7)
                love.graphics.setLineWidth(2)
                love.graphics.circle("line", cx, cy, SIZE / 2 - 4)
            end
        else
            local color = OrbRow.COLORS[orb.type] or { 0.7, 0.7, 0.7 }
            local inEvokePreview = (previewMode == "evoke_all")
                or (previewMode == "evoke_one" and i == 1)

            local kick = slotAnim[i] or 0
            local bob = 0
            if not reducedMotion() then
                bob = math.sin(animTime * 2.2 + i * 1.3) * 2 - kick * 6
            end
            local gy = y + bob

            local haloC = inEvokePreview and EVOKE_CYAN or color
            local haloA = 0.26 * (0.75 + math.sin(animTime * 3 + i) * 0.25)
            if inEvokePreview then haloA = 0.50 + math.sin(animTime * 6) * 0.18 end
            if reducedMotion() then haloA = inEvokePreview and 0.58 or 0.26 end
            love.graphics.setColor(haloC[1], haloC[2], haloC[3], haloA)
            love.graphics.circle("fill", cx, gy + SIZE / 2, SIZE * 0.42)

            local pf = pulseFlash[i] or 0
            if not drawGem(orb.type, x, gy, 1, math.max(pf * 0.8, kick * 0.6), gemClock(i)) then
                love.graphics.setColor(color[1], color[2], color[3], 0.9)
                love.graphics.setLineWidth(2)
                love.graphics.circle("line", cx, gy + SIZE / 2, SIZE / 2 - 6)
            end

            local shown, unit = OrbRow.readout(orb, focus,
                inEvokePreview and "evoke" or "pulse")
            drawPlate(x + plateInset, plateY, plateW,
                inEvokePreview and EVOKE_CYAN or color,
                unit, shown, font)
            if inEvokePreview then
                local txt = tostring(shown)
                love.graphics.setFont(font)
                local tw = font:getWidth(txt)
                local gh = PLATE_H - 8
                local total = gh + 3 + tw
                love.graphics.setColor(EVOKE_CYAN[1], EVOKE_CYAN[2], EVOKE_CYAN[3], 1)
                love.graphics.print(txt,
                    math.floor(x + plateInset + plateW / 2 - total / 2 + gh + 3),
                    math.floor(plateY + PLATE_H / 2 - font:getHeight() / 2))
            end

            if i == 1 and #p.orbs > 0 then
                local a = reducedMotion() and 0.9
                    or (0.70 + math.sin(animTime * 3.5) * 0.2)
                love.graphics.setColor(1, 1, 1, a)
                love.graphics.setLineWidth(1)
                love.graphics.rectangle("line", x - 3, y - 3,
                    SIZE + 6, cellHeight() + 6)
            end
        end

        require("src.ui.NavCursor").target("orb:" .. tostring(x), x, y, SIZE, cellHeight())
        if mx >= x and mx <= x + SIZE and my >= y and my <= y + cellHeight() then
            if orb then
                StatusTooltip.show("orb_" .. orb.type, mx, my, {
                    stacks = EffectSystem.orbPulseValue(orb, focus),
                    duration = EffectSystem.orbEvokeValue(orb, focus),
                })
            else
                StatusTooltip.show("orb_empty", mx, my, {
                    stacks = p.orbSlots or 3, duration = 0,
                })
            end
        end
    end

    do
        local Tutorial = require("src.systems.Tutorial")
        local n = p.orbSlots or 3
        local rowW = (n - 1) * (SIZE + SPACING) + SIZE
        Tutorial.anchor("orbs", startX - 4, y - 4, rowW + 8, cellHeight() + 16)
        if #(p.orbs or {}) > 0 then
            Tutorial.anchor("orb_next", startX - 4, y - 4, SIZE + 8, cellHeight() + 8)
        end
    end

    OrbRow._drawFx()

    if #(p.orbs or {}) > 0 then
        local railY = y + cellHeight() + 6
        local railX2 = startX + (math.min(#p.orbs, p.orbSlots or 3) - 1)
            * (SIZE + SPACING) + SIZE / 2
        love.graphics.setColor(0.72, 0.66, 0.52, 0.55)
        love.graphics.setLineWidth(1)
        love.graphics.line(startX + 2, railY, railX2, railY)
        love.graphics.polygon("fill",
            startX - 5, railY, startX + 3, railY - 4, startX + 3, railY + 4)
        local fx = startX + SIZE / 2
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.polygon("fill",
            fx, railY - 4, fx + 4, railY, fx, railY + 4, fx - 4, railY)
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
end

function OrbRow._drawFx()
    if not slotPos then return end

    local ox, oy = spellOrigin()
    for i, fx in pairs(inbound) do
        local pos = slotPos[i]
        if pos then
            local k = math.min(1, fx.t / fx.dur)
            local e = k * k
            local x = ox + (pos.x - ox) * e
            local y = oy + (pos.y - oy) * e
            local c = fx.color
            for tr = 4, 1, -1 do
                local et = math.max(0, e - tr * 0.06)
                local tx = ox + (pos.x - ox) * et
                local ty = oy + (pos.y - oy) * et
                love.graphics.setColor(c[1], c[2], c[3], 0.16 * (5 - tr))
                love.graphics.circle("fill", tx, ty, SIZE * 0.13 * (1 - tr * 0.12))
            end
            love.graphics.setColor(c[1], c[2], c[3], 0.30 + 0.35 * e)
            love.graphics.circle("fill", x, y, SIZE * (0.18 + 0.24 * e))
            if not drawGem(fx.otype, x - SIZE / 2, y - SIZE / 2, 1, 0.35 * (1 - e), gemClock(i)) then
                love.graphics.setColor(1, 1, 1, 0.85)
                love.graphics.setLineWidth(2)
                love.graphics.circle("line", x, y, SIZE * 0.3)
            end
        end
    end

    for _, fx in ipairs(outbound) do
        local pos = slotPos[fx.slot]
        if pos then
            local k = math.min(1, fx.t / fx.dur)
            local e = 1 - (1 - k) * (1 - k)
            local tx, ty = spellOrigin()
            local x = pos.x + (tx - pos.x) * e * 0.55
            local y = pos.y + (ty - pos.y) * e * 0.55
            local c, a = fx.color, 1 - k
            love.graphics.setColor(c[1], c[2], c[3], 0.65 * a)
            love.graphics.circle("fill", x, y, SIZE * 0.40)
            if not drawGem(fx.otype, x - SIZE / 2, y - SIZE / 2, a, 0.5 * a, gemClock(fx.slot)) then
                love.graphics.setColor(1, 1, 1, 0.95 * a)
                love.graphics.setLineWidth(3)
                love.graphics.circle("line", x, y, SIZE * 0.35)
            end
        end
    end
end

return OrbRow
