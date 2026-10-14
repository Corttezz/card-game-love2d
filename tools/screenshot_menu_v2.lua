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

    local Menu = require("components.Menu")
    local menu = Menu:new()
    menu:enterWithIntro()
    for _ = 1, 45 do
        EM.update(dt)
        menu:update(dt)
    end
    if menu.buttons.play then menu.buttons.play.hover = true end
    love.graphics.clear(0, 0, 0, 1)
    menu:draw()
    capture("menu_v2_osd.png")

    local BootScene = require("src.scenes.BootScene")
    BootScene.init({ onComplete = function() end })
    local elapsed = 0
    while elapsed < 0.65 do
        EM.update(dt)
        BootScene.update(dt)
        elapsed = elapsed + dt
    end
    love.graphics.clear(0, 0, 0, 1)
    BootScene.draw()
    capture("menu_v2_boot_tune.png")

    while elapsed < 0.5 + 3.10 do
        EM.update(dt)
        BootScene.update(dt)
        elapsed = elapsed + dt
    end
    love.graphics.clear(0, 0, 0, 1)
    BootScene.draw()
    capture("menu_v2_boot_casc.png")

    while elapsed < 0.5 + 3.85 do
        EM.update(dt)
        BootScene.update(dt)
        elapsed = elapsed + dt
    end
    love.graphics.clear(0, 0, 0, 1)
    BootScene.draw()
    capture("menu_v2_boot_dive.png")

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
