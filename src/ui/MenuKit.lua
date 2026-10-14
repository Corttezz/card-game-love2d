local Palette = require("src.ui.Palette")

local MenuKit = {}

MenuKit.ENTER_DUR = 0.24
MenuKit.ENTER_DROP = -36

local NAV = {
    up = "up", w = "up", kp8 = "up",
    down = "down", s = "down", kp2 = "down",
    left = "left", a = "left", kp4 = "left",
    right = "right", d = "right", kp6 = "right",
    ["return"] = "confirm", kpenter = "confirm", space = "confirm",
    escape = "back", backspace = "back",
    tab = "tab_next", e = "tab_next", pagedown = "tab_next",
    q = "tab_prev", pageup = "tab_prev",
}

function MenuKit.intent(key, shift)
    local it = NAV[key]
    if it == "tab_next" and key == "tab" and shift then return "tab_prev" end
    return it
end

local function shiftDown()
    return love.keyboard and love.keyboard.isDown
        and (love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift"))
end
MenuKit.shiftDown = shiftDown

function MenuKit.enterEase(t)
    local x = math.max(0, math.min(1, (t or 0) / MenuKit.ENTER_DUR))
    local c1 = 1.25
    local c3 = c1 + 1
    return 1 + c3 * (x - 1) ^ 3 + c1 * (x - 1) ^ 2
end

local function reducedMotion()
    return _G.gameSettings and _G.gameSettings.reducedMotion
end

function MenuKit.drawVeil(t, alpha)
    local x = math.max(0, math.min(1, (t or 0) / MenuKit.ENTER_DUR))
    love.graphics.setColor(0, 0, 0, (alpha or 0.62) * x)
    love.graphics.rectangle("fill", 0, 0,
        love.graphics.getWidth(), love.graphics.getHeight())
    love.graphics.setColor(1, 1, 1, 1)
end

function MenuKit.pushEnter(t)
    love.graphics.push()
    if reducedMotion() then return end
    local e = MenuKit.enterEase(t)
    love.graphics.translate(0, math.floor((1 - e) * MenuKit.ENTER_DROP))
end

function MenuKit.focusRing(x, y, w, h, time, pad)
    pad = pad or 3
    local pulse = reducedMotion() and 1 or (0.75 + 0.25 * math.sin((time or 0) * 5))
    local lw = love.graphics.getLineWidth()
    love.graphics.setLineWidth(2)
    Palette.set(Palette.AGED_GOLD_LIGHT, pulse)
    love.graphics.rectangle("line", x - pad, y - pad, w + pad * 2, h + pad * 2, 4, 4)
    Palette.set(Palette.INK, 0.8)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x - pad - 2, y - pad - 2, w + pad * 2 + 4, h + pad * 2 + 4, 5, 5)
    love.graphics.setLineWidth(lw)
    love.graphics.setColor(1, 1, 1, 1)
end

function MenuKit.hit(r, x, y)
    return r and x >= r.x and x < r.x + r.w and y >= r.y and y < r.y + r.h
end

function MenuKit.overlaps(a, b)
    return a.x < b.x + b.w and b.x < a.x + a.w
       and a.y < b.y + b.h and b.y < a.y + a.h
end

return MenuKit
