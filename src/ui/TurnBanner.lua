local FontManager = require("src.ui.FontManager")
local I18n = require("src.i18n.I18n")
local DissolveShader = require("src.ui.DissolveShader")

local TurnBanner = {}

local active = nil
local canvasCache = {}

function TurnBanner.clearCache() canvasCache = {} end

local COLORS = {
    player = { band = { 0.09, 0.07, 0.05, 0.88 },
               text = { 0.92, 0.82, 0.58, 1 },
               line = { 0.72, 0.58, 0.32, 1 } },
    enemy  = { band = { 0.10, 0.05, 0.04, 0.88 },
               text = { 0.95, 0.58, 0.45, 1 },
               line = { 0.62, 0.20, 0.14, 1 } },
}

local DUR = 1.05

function TurnBanner.show(kind)
    active = { kind = kind or "player", t = 0 }
    TurnBanner._ensureCanvas(active.kind)
end

function TurnBanner.update(dt)
    if not active then return end
    active.t = active.t + dt
    if active.t >= DUR then active = nil end
end

function TurnBanner.isActive() return active ~= nil end

local BAND_H = 46
local BAND_Y_RATIO = 0.24

function TurnBanner.bandRect()
    return math.floor(love.graphics.getHeight() * BAND_Y_RATIO), BAND_H
end

local function bandCanvas(kind, sw)
    local key = kind .. sw .. "|" .. tostring(I18n.getLocale and I18n.getLocale())
    if canvasCache[key] then return canvasCache[key] end
    local sx0, sy0, sw0, sh0 = love.graphics.getScissor()
    love.graphics.setScissor()
    local c = COLORS[kind] or COLORS.player
    local text = I18n.t(kind == "enemy"
        and "battle.enemy_turn" or "battle.your_turn")
    local font = FontManager.getFont(22)
    local canvas = love.graphics.newCanvas(sw, BAND_H)
    love.graphics.push("all")
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.origin()
    love.graphics.setColor(c.band)
    love.graphics.rectangle("fill", 0, 0, sw, BAND_H)
    love.graphics.setColor(c.line[1], c.line[2], c.line[3], 0.9)
    love.graphics.rectangle("fill", 0, 0, sw, 2)
    love.graphics.rectangle("fill", 0, BAND_H - 2, sw, 2)
    love.graphics.setFont(font)
    local tw = font:getWidth(text)
    local cyt = BAND_H / 2
    for side = -1, 1, 2 do
        local gx = math.floor(sw / 2 + side * (tw / 2 + 26))
        love.graphics.setColor(c.line[1], c.line[2], c.line[3], 0.95)
        love.graphics.polygon("fill", gx, cyt - 4, gx + 4, cyt,
            gx, cyt + 4, gx - 4, cyt)
    end
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.print(text, math.floor((sw - tw) / 2) + 2,
        math.floor((BAND_H - font:getHeight()) / 2) + 2)
    love.graphics.setColor(c.text)
    love.graphics.print(text, math.floor((sw - tw) / 2),
        math.floor((BAND_H - font:getHeight()) / 2))
    love.graphics.setCanvas()
    love.graphics.pop()
    if sx0 then love.graphics.setScissor(sx0, sy0, sw0, sh0) end
    canvasCache[key] = canvas
    return canvas
end

function TurnBanner._ensureCanvas(kind)
    bandCanvas(kind, love.graphics.getWidth())
end

local BURN = {
    player = { { 1.00, 0.85, 0.35, 1.0 }, { 0.85, 0.55, 0.15, 1.0 } },
    enemy  = { { 0.85, 0.20, 0.10, 1.0 }, { 1.00, 0.50, 0.10, 1.0 } },
}

function TurnBanner.draw()
    if not active then return end
    local sw = love.graphics.getWidth()
    local t = active.t

    local dissolve
    if t < 0.30 then
        local k = t / 0.30
        dissolve = 1 - k * k * (3 - 2 * k)
    elseif t < 0.75 then
        dissolve = 0
    else
        local k = math.min(1, (t - 0.75) / 0.30)
        dissolve = k * k * (3 - 2 * k)
    end

    if not DissolveShader.isAvailable() and not TurnBanner._shaderTried then
        TurnBanner._shaderTried = true
        DissolveShader.load()
    end

    local canvas = bandCanvas(active.kind, sw)
    local y = TurnBanner.bandRect()
    love.graphics.setColor(1, 1, 1, 1)
    local ns = { 5.5 * sw / BAND_H, 5.5 }
    if not DissolveShader.apply(canvas, dissolve, BURN[active.kind], false, ns) then
        love.graphics.setColor(1, 1, 1, 1 - dissolve)
    end
    local gx0, gy0, gw0, gh0 = love.graphics.getScissor()
    love.graphics.setScissor(0, y, sw, BAND_H)
    love.graphics.draw(canvas, 0, y)
    love.graphics.setScissor(gx0, gy0, gw0, gh0)
    DissolveShader.clear()
    love.graphics.setColor(1, 1, 1, 1)
end

return TurnBanner
