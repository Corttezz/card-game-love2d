-- tools/screenshot_menu_v2.lua
-- Valida o Menu+Entrada v2 (docs/plan/menu-crt-v2.md):
--   menu_v2_osd.png       — menu com OSD do aparelho + hover CRT no botão
--   menu_v2_boot_tune.png — boot logo após sintonia (chuvisco forte)
--   menu_v2_boot_casc.png — boot no auge da cascade espiral + glitch título
--   menu_v2_settings.png  — settings com barras de segmento OSD
-- Capturas SEM CRT (doutrina — o shader é validado por screenshot_crt).
--   love . screenshot_menu_v2

local M = {}

local function capture(name)
    love.graphics.captureScreenshot(function(imageData)
        imageData:encode("png", name)
        print("[menu_v2] " .. name .. " salvo")
    end)
    love.graphics.present()
end

function M.run()
    _G.EventManager = require("engine.EventManager")
    _G.Event = require("engine.Event")
    require("src.i18n.I18n").init()
    require("src.ui.PixelCanvas").enableNearest()

    local EM = _G.EventManager
    local dt = 1 / 30

    -- ===== 1. MENU com OSD + hover =====
    local Menu = require("components.Menu")
    local menu = Menu:new()
    menu:enterWithIntro()
    for _ = 1, 45 do
        EM.update(dt)
        menu:update(dt)
    end
    -- força hover no botão Jogar (pra fotografar a estética CRT do hover)
    if menu.buttons.play then menu.buttons.play.hover = true end
    love.graphics.clear(0, 0, 0, 1)
    menu:draw()
    capture("menu_v2_osd.png")

    -- ===== 2/3. BOOT: sintonia + cascade =====
    local BootScene = require("src.scenes.BootScene")
    BootScene.init({ onComplete = function() end })
    -- pump até o splash começar + 0.12s (chuvisco ainda forte)
    local elapsed = 0
    while elapsed < 0.65 do
        EM.update(dt)
        BootScene.update(dt)
        elapsed = elapsed + dt
    end
    love.graphics.clear(0, 0, 0, 1)
    BootScene.draw()
    capture("menu_v2_boot_tune.png")

    -- pump até o auge da cascade + glitch do título (~2.2s de splash)
    while elapsed < 0.5 + 2.25 do
        EM.update(dt)
        BootScene.update(dt)
        elapsed = elapsed + dt
    end
    love.graphics.clear(0, 0, 0, 1)
    BootScene.draw()
    capture("menu_v2_boot_casc.png")

    -- ===== 4. SETTINGS com barras OSD =====
    local SettingsMenu = require("components.SettingsMenu")
    local settings = SettingsMenu:new()
    settings:show()
    settings:update(dt)
    love.graphics.clear(0.10, 0.08, 0.06, 1)
    settings:draw()
    capture("menu_v2_settings.png")

    love.event.quit()
end

return M
