local Config         = require("src.core.Config")
local FontManager    = require("src.ui.FontManager")
local Palette        = require("src.ui.Palette")
local I18n           = require("src.i18n.I18n")
local DissolveShader = require("src.ui.DissolveShader")
local TurnBanner     = require("src.ui.TurnBanner")

local ComboBanner = {}

local queue  = {}
local active = nil
local canvasCache = {}
local canvasCount = 0

local PAD_V      = 10
local TITLE_H    = 30
local ROW_H      = 30
local TITLE_FONT = 24
local LABEL_FONT = 20
local VALUE_FONT = 26

local TOP_BAR_H_DEFAULT = 52
local TOP_MARGIN        = 8
local CARD_IMG_H        = 144
local LAND_RATIO        = 0.45
local HOP_MARGIN        = 26

local topInset = TOP_BAR_H_DEFAULT

local function announceZone()
    local sh = love.graphics.getHeight()
    local cardH = CARD_IMG_H * (Config.Cards and Config.Cards.BASE_SCALE or 1.333)
    local bottom = math.floor(sh * LAND_RATIO - cardH / 2 - HOP_MARGIN)
    local top = topInset + TOP_MARGIN
    return top, bottom
end

local FADE_IN, FADE_OUT = 0.30, 0.30
local HOLD_BASE, HOLD_PER_ROW = 0.55, 0.30

local STALE_AFTER = 5.0

local function rgba(c, a)
    return { c[1], c[2], c[3], a or 1 }
end

local function now()
    return (love.timer and love.timer.getTime and love.timer.getTime()) or 0
end

local function formatBonus(b)
    if not b then return nil end
    local t = b.type
    if t == "damage_multiplier" or t == "defense_multiplier" then
        return "×" .. string.format("%g", b.value or 1)
    elseif t == "damage_bonus" or t == "defense_bonus" or t == "card_bonus" then
        return "+" .. string.format("%g", b.value or 0)
    elseif t == "heal" then
        return "+" .. string.format("%g", b.value or 0) .. " HP"
    elseif t == "apply_debuff" then
        local name = I18n.t("status." .. (b.debuff or "poison") .. ".name",
            nil, b.debuff or "")
        return "+" .. string.format("%g", b.stacks or 1) .. " " .. name
    elseif t == "evoke_on_combo" then
        return I18n.t("battle.combo_evoke", { n = b.value or 1 })
    end
    return nil
end

local function comboName(combo)
    return I18n.t("combos." .. tostring(combo.id), nil,
        combo.label or tostring(combo.id))
end

local function ensureGeometry(entry)
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    if entry.geo and entry.geo.sw == sw and entry.geo.sh == sh
        and entry.geo.inset == topInset then
        return entry.geo
    end

    local n = #entry.rows
    local natural = PAD_V * 2 + TITLE_H + n * ROW_H
    local zTop, zBottom = announceZone()
    local zoneH = math.max(40, zBottom - zTop)
    local s = math.min(1, zoneH / natural)

    local geo = {
        sw = sw, sh = sh, inset = topInset, scale = s,
        padV    = math.floor(PAD_V * s),
        titleH  = math.floor(TITLE_H * s),
        rowH    = math.floor(ROW_H * s),
        titleF  = math.max(10, math.floor(TITLE_FONT * s)),
        labelF  = math.max(9,  math.floor(LABEL_FONT * s)),
        valueF  = math.max(10, math.floor(VALUE_FONT * s)),
    }
    geo.h = geo.padV * 2 + geo.titleH + n * geo.rowH
    geo.y = math.max(zTop, zBottom - geo.h)
    geo.key = entry.key .. "|" .. sw .. "|" .. geo.h .. "|"
        .. tostring(I18n.getLocale and I18n.getLocale())
    entry.geo = geo
    return geo
end

local function bannerCanvas(entry)
    local geo = entry.geo
    if canvasCache[geo.key] then return canvasCache[geo.key] end

    local sx0, sy0, sw0, sh0 = love.graphics.getScissor()
    love.graphics.setScissor()

    local sw, h = geo.sw, geo.h
    local titleFont = FontManager.getFont(geo.titleF)
    local rowFont   = FontManager.getFont(geo.labelF)
    local valueFont = FontManager.getFont(geo.valueF)

    local canvas = love.graphics.newCanvas(sw, h)
    love.graphics.push("all")
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.origin()

    love.graphics.setColor(rgba(Palette.ARCANE_INK, 0.90))
    love.graphics.rectangle("fill", 0, 0, sw, h)
    love.graphics.setColor(rgba(Palette.ARCANE, 0.95))
    love.graphics.rectangle("fill", 0, 0, sw, 2)
    love.graphics.rectangle("fill", 0, h - 2, sw, 2)

    local title = I18n.t("battle.combo")
    love.graphics.setFont(titleFont)
    local tw = titleFont:getWidth(title)
    local titleY = geo.padV + math.floor((geo.titleH - titleFont:getHeight()) / 2)
    local cyt = geo.padV + math.floor(geo.titleH / 2)
    for side = -1, 1, 2 do
        local gx = math.floor(sw / 2 + side * (tw / 2 + 26))
        love.graphics.setColor(rgba(Palette.ARCANE, 0.95))
        love.graphics.polygon("fill", gx, cyt - 5, gx + 5, cyt,
            gx, cyt + 5, gx - 5, cyt)
    end
    FontManager.drawWithOutline(title, math.floor((sw - tw) / 2), titleY,
        Palette.ARCANE_LIGHT, 0.75)

    local gap = math.max(8, math.floor(14 * geo.scale))
    for i, row in ipairs(entry.rows) do
        local lw = rowFont:getWidth(row.label)
        local vw = row.value and valueFont:getWidth(row.value) or 0
        local total = lw + (row.value and (gap + vw) or 0)
        local x = math.floor((sw - total) / 2)
        local rowY = geo.padV + geo.titleH + (i - 1) * geo.rowH
        love.graphics.setFont(rowFont)
        FontManager.drawWithOutline(row.label, x,
            rowY + math.floor((geo.rowH - rowFont:getHeight()) / 2),
            Palette.PARCHMENT_LIGHT, 0.8)
        if row.value then
            love.graphics.setFont(valueFont)
            FontManager.drawWithOutline(row.value, x + lw + gap,
                rowY + math.floor((geo.rowH - valueFont:getHeight()) / 2),
                Palette.ARCANE_LIGHT, 0.95)
        end
    end

    love.graphics.setCanvas()
    love.graphics.pop()
    if sx0 then love.graphics.setScissor(sx0, sy0, sw0, sh0) end

    if canvasCount > 24 then
        canvasCache = {}
        canvasCount = 0
    end
    canvasCache[geo.key] = canvas
    canvasCount = canvasCount + 1
    return canvas
end

function ComboBanner.show(combos)
    if type(combos) ~= "table" or #combos == 0 then return end

    local rows, keyParts = {}, {}
    for _, combo in ipairs(combos) do
        rows[#rows + 1] = {
            label = comboName(combo),
            value = formatBonus(combo.bonus),
        }
        keyParts[#keyParts + 1] = tostring(combo.id)
    end

    local entry = {
        rows = rows,
        key  = table.concat(keyParts, "+"),
        dur  = FADE_IN + FADE_OUT + HOLD_BASE + HOLD_PER_ROW * #rows,
        t    = 0,
        born = now(),
    }
    ensureGeometry(entry)
    bannerCanvas(entry)
    queue[#queue + 1] = entry
end

function ComboBanner.update(dt)
    local tnow = now()
    for i = #queue, 1, -1 do
        if tnow - queue[i].born > STALE_AFTER then table.remove(queue, i) end
    end
    if active and tnow - active.born > active.dur + STALE_AFTER then
        active = nil
    end
    if not active then
        if TurnBanner.isActive() then return end
        active = table.remove(queue, 1)
        if not active then return end
        active.t = 0
        active.born = tnow
    end
    local geo = ensureGeometry(active)
    if not canvasCache[geo.key] then bannerCanvas(active) end

    active.t = active.t + dt
    if active.t >= active.dur then active = nil end
end

function ComboBanner.isActive() return active ~= nil end

function ComboBanner.clearCache()
    canvasCache = {}
    canvasCount = 0
    if active then active.geo = nil end
end

function ComboBanner.clear()
    active = nil
    for i = #queue, 1, -1 do queue[i] = nil end
end

local BURN = { { 0.55, 0.30, 0.85, 1.0 }, { 0.95, 0.65, 0.95, 1.0 } }

function ComboBanner.draw(topBarH)
    if topBarH and topBarH > 0 then topInset = topBarH end
    if not active then return end
    local geo = active.geo
    if not geo then return end
    local sw = geo.sw
    local t = active.t

    local reduced = _G.gameSettings and _G.gameSettings.reducedMotion

    local dissolve, alpha = 0, 1
    if reduced then
        local FADE = 0.12
        if t < FADE then
            alpha = t / FADE
        elseif t > active.dur - FADE then
            alpha = math.max(0, (active.dur - t) / FADE)
        end
    else
        local outStart = active.dur - FADE_OUT
        if t < FADE_IN then
            local k = t / FADE_IN
            dissolve = 1 - k * k * (3 - 2 * k)
        elseif t < outStart then
            dissolve = 0
        else
            local k = math.min(1, (t - outStart) / FADE_OUT)
            dissolve = k * k * (3 - 2 * k)
        end
    end

    if not reduced and not DissolveShader.isAvailable()
        and not ComboBanner._shaderTried then
        ComboBanner._shaderTried = true
        DissolveShader.load()
    end

    local canvas = canvasCache[geo.key]
    if not canvas then return end
    local y = geo.y

    love.graphics.setColor(1, 1, 1, alpha)
    if not reduced then
        local ns = { 5.5 * sw / geo.h, 5.5 }
        if not DissolveShader.apply(canvas, dissolve, BURN, false, ns) then
            love.graphics.setColor(1, 1, 1, 1 - dissolve)
        end
    end
    local gx0, gy0, gw0, gh0 = love.graphics.getScissor()
    love.graphics.setScissor(0, y, sw, geo.h)
    love.graphics.draw(canvas, 0, y)
    love.graphics.setScissor(gx0, gy0, gw0, gh0)
    DissolveShader.clear()
    love.graphics.setColor(1, 1, 1, 1)
end

return ComboBanner
