-- tools/screenshot_class_select.lua
-- Valida o "Salão dos Heróis" (docs/plan/class-select-v2.md):
--   class_select_v2.png       — tela parada (heróis em idle)
--   class_select_v2_hover.png — hover no guerreiro (passo à frente + spotlight)
--   class_select_v2_pick.png  — momento da escolha (flash + anel + faíscas)
--   love . screenshot_class_select

local M = {}

local function capture(name)
    love.graphics.captureScreenshot(function(imageData)
        imageData:encode("png", name)
        print("[class_select] " .. name .. " salvo")
    end)
    love.graphics.present()
end

function M.run()
    _G.EventManager = require("engine.EventManager")
    _G.Event = require("engine.Event")
    require("src.i18n.I18n").init()
    require("src.ui.PixelCanvas").enableNearest()

    local Screen = require("components.ClassSelectionScreen")
    local screen = Screen:new()
    screen:show(function() end, function() end)

    local dt = 1 / 30
    for _ = 1, 30 do
        _G.EventManager.update(dt)
        screen:update(dt)
    end

    love.graphics.clear(0, 0, 0, 1)
    screen:draw()
    capture("class_select_v2.png")

    -- hover no guerreiro
    if screen.buttons.warrior then screen.buttons.warrior.hover = true end
    for _ = 1, 20 do
        _G.EventManager.update(dt)
        screen:update(dt)
    end
    love.graphics.clear(0, 0, 0, 1)
    screen:draw()
    capture("class_select_v2_hover.png")

    -- momento da escolha (congela no meio do FX)
    screen:selectClass("warrior")
    for _ = 1, 5 do
        _G.EventManager.update(dt)
        screen:update(dt)
    end
    love.graphics.clear(0, 0, 0, 1)
    screen:draw()
    capture("class_select_v2_pick.png")

    love.event.quit()
end

return M
