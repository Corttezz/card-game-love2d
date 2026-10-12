-- tools/screenshot_guide.lua
-- Captura o GUIA (combos + glossário) num tamanho de janela FALSIFICADO.
--   love . test_one screenshot_guide pt_BR:1920x1080:1
--   (locale : WxH : aba 1=combos 2=glossário) — PNG no save dir:
--   guide_<locale>_<W>x<H>_<aba>.png

local M = {}

function M.run(arg)
    local loc, w, h, tab = (arg or "pt_BR:1024x768:1"):match("^([%w_]+):(%d+)x(%d+):?(%d*)$")
    loc = loc or "pt_BR"
    w, h, tab = tonumber(w) or 1024, tonumber(h) or 768, tonumber(tab) or 1
    love.graphics.getWidth = function() return w end
    love.graphics.getHeight = function() return h end
    love.graphics.getDimensions = function() return w, h end
    local I18n = require("src.i18n.I18n")
    I18n.init()
    I18n.setLocale(loc, true)
    require("src.ui.PixelCanvas").enableNearest()
    _G.EventManager = _G.EventManager or require("engine.EventManager")
    local Game = require("src.core.Game")
    local game = Game:new()
    game:startNewRun("warrior")
    game:startGame()
    local Guide = require("components.GuideScreen")
    local gs = Guide:new()
    gs:show(game)
    gs.tab = tab
    local canvas = love.graphics.newCanvas(w, h)
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0.2, 0.25, 0.2, 1)
    gs:draw()
    love.graphics.setCanvas()
    local name = ("guide_%s_%dx%d_%d.png"):format(loc, w, h, tab)
    canvas:newImageData():encode("png", name)
    print("[screenshot_guide] " .. name)
    return true
end

return M
