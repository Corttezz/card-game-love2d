local FontManager = require("src.ui.FontManager")
local Palette     = require("src.ui.Palette")
local UiScale     = require("src.ui.UiScale")
local I18n        = require("src.i18n.I18n")

local ForkMapButton = {}

ForkMapButton.W, ForkMapButton.H = 214, 58
ForkMapButton.MARGIN = 22
ForkMapButton._rect = nil

function ForkMapButton.available(r)
    local WorldRoad = require("src.ui.WorldRoad")
    return WorldRoad.isForkActive() and r ~= nil and r.actMap ~= nil and not r.endlessMode
end

function ForkMapButton.rect()
    local k = UiScale.k()
    local W, H = UiScale.realDimensions()
    local w, h = math.floor(ForkMapButton.W * k), math.floor(ForkMapButton.H * k)
    local m = math.floor(ForkMapButton.MARGIN * k)
    return m, H - h - m, w, h, k
end

local function inside(x, y)
    local r = ForkMapButton._rect
    return r and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

function ForkMapButton.draw(r)
    if not ForkMapButton.available(r) then ForkMapButton._rect = nil return end
    local x, y, w, h, k = ForkMapButton.rect()
    ForkMapButton._rect = { x = x, y = y, w = w, h = h }
    local mx, my = love.mouse.getPosition()
    local hot = inside(mx, my)
    local t = love.timer.getTime()
    local pulse = 0.5 + 0.5 * math.sin(t * 3.2)
    local g = love.graphics
    local gold, ink = Palette.AGED_GOLD, Palette.INK

    g.setColor(0, 0, 0, 0.35)
    g.rectangle("fill", x + 4 * k, y + 5 * k, w, h)
    local glow = hot and 1 or (0.35 + 0.35 * pulse)
    g.setColor(gold[1], gold[2], gold[3], 0.5 * glow)
    g.rectangle("fill", x - 4 * k, y - 4 * k, w + 8 * k, h + 8 * k)
    local p = hot and Palette.PARCHMENT_LIGHT or Palette.PARCHMENT
    g.setColor(p[1], p[2], p[3], 1)
    g.rectangle("fill", x, y, w, h)
    g.setLineWidth(math.max(2, math.floor(2 * k)))
    g.setColor(ink[1], ink[2], ink[3], 1)
    g.rectangle("line", x + k, y + k, w - 2 * k, h - 2 * k)
    g.setLineWidth(1)

    local box = math.floor(38 * k)
    g.setColor(1, 1, 1, 1)
    require("src.ui.IconLoader").drawFit("ui_map", x + 10 * k + box / 2, y + h / 2, box)

    local tx = x + 18 * k + box
    local label = I18n.t("act_map.fork_button", nil, "Ver o mapa")
    local sub = I18n.t("act_map.fork_button_sub", nil, "planeje a rota")
    local f1 = FontManager.getFontAt(FontManager.MAP_TEXT, math.floor(24 * k))
    local f2 = FontManager.getFontAt(FontManager.MAP_TEXT, math.floor(16 * k))
    local keyW = math.floor(26 * k)
    local room = x + w - tx - keyW - 14 * k
    local size = 24
    while f1:getWidth(label) > room and size > 14 do
        size = size - 1
        f1 = FontManager.getFontAt(FontManager.MAP_TEXT, math.floor(size * k))
    end
    g.setColor(ink[1], ink[2], ink[3], 1)
    g.setFont(f1)
    g.print(label, math.floor(tx), math.floor(y + 5 * k))
    g.setColor(Palette.BLOOD[1], Palette.BLOOD[2], Palette.BLOOD[3], 1)
    g.setFont(f2)
    g.print(sub, math.floor(tx), math.floor(y + h - f2:getHeight() - 6 * k))

    local kx, ky = x + w - keyW - 10 * k, y + (h - keyW) / 2
    g.setColor(ink[1], ink[2], ink[3], 0.85)
    g.rectangle("fill", kx, ky, keyW, keyW)
    g.setColor(p[1], p[2], p[3], 1)
    local fk = FontManager.getFontAt(FontManager.MAP_TITLE, math.floor(22 * k))
    g.setFont(fk)
    g.print("M", math.floor(kx + (keyW - fk:getWidth("M")) / 2), math.floor(ky + (keyW - fk:getHeight()) / 2))
    g.setColor(1, 1, 1, 1)

    require("src.ui.NavCursor").target("fork:map", x, y, w, h)
    require("src.systems.Tutorial").anchor("fork_map", x - 4 * k, y - 4 * k, w + 8 * k, h + 8 * k)
end

function ForkMapButton.mousepressed(r, x, y, button)
    if button ~= 1 or not ForkMapButton.available(r) or not inside(x, y) then return false end
    if _G.toggleActMap then _G.toggleActMap() end
    return true
end

return ForkMapButton
