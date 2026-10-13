-- tools/screenshot_intro.lua
-- Capturas da ABERTURA (página + televisor + mergulho) quadro a quadro,
-- numa janela falsificada, e a fita do menu.
--   love . test_one screenshot_intro [locale] [WxH]
-- Saída: intro_<fase>_<W>x<H>_<loc>.png e intro_menu_ribbon_<W>x<H>_<loc>.png
local M = {}

function M.run(arg)
    local locale, size = "pt_BR", "1920x1080"
    for a in tostring(arg or ""):gmatch("[^:%s]+") do
        if a:match("^%d+x%d+$") then size = a elseif a ~= "" then locale = a end
    end
    local W, H = size:match("(%d+)x(%d+)")
    W, H = tonumber(W), tonumber(H)
    _G.EventManager = _G.EventManager or require("engine.EventManager")
    local I18n = require("src.i18n.I18n")
    I18n.init(); I18n.setLocale(locale)
    require("src.ui.PixelCanvas").enableNearest()
    local CRT = require("src.ui.CRTShader")
    CRT.load()
    local rw, rh, rd = love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions
    love.graphics.getWidth = function() return W end
    love.graphics.getHeight = function() return H end
    love.graphics.getDimensions = function() return W, H end
    local IntroTube = require("src.scenes.IntroTube")
    _G.gameSettings = _G.gameSettings or {}
    _G.gameSettings.reducedMotion = false
    IntroTube.init({})
    local canvas = love.graphics.newCanvas(W, H)
    local function shot(name)
        love.graphics.setCanvas(canvas)
        love.graphics.clear(0, 0, 0, 1)
        IntroTube.draw()
        love.graphics.setCanvas()
        local f = ("intro_%s_%dx%d_%s.png"):format(name, W, H, locale)
        canvas:newImageData():encode("png", f)
        print("[screenshot_intro] " .. f)
    end
    local dt = 1 / 60
    local function run(secs) for _ = 1, math.floor(secs * 60) do IntroTube.update(dt) end end
    run(0.5);  shot("1_pagina")
    run(1.2);  shot("2_titulo")
    for _ = 1, 60 * 8 do IntroTube.update(dt); if IntroTube.phase() == "dive" then break end end
    shot("3_texto")
    IntroTube.update(IntroTube.T.dive * 0.45); shot("4_mergulho")
    IntroTube.update(IntroTube.T.dive * 0.45); shot("5_tubo")
    -- fita do menu
    local Menu = require("components.Menu")
    local menu = Menu:new()
    menu:show(function() end, function() end)
    for _ = 1, 90 do _G.EventManager.update(dt); menu:update(dt) end
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 1)
    menu:draw()
    love.graphics.setCanvas()
    local f = ("intro_menu_ribbon_%dx%d_%s.png"):format(W, H, locale)
    canvas:newImageData():encode("png", f)
    print("[screenshot_intro] " .. f)
    if menu.hide then menu:hide() end
    love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions = rw, rh, rd
    return true
end

return M
