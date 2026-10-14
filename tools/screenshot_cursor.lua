local M = {}

function M.run()
    local I18n = require("src.i18n.I18n")
    I18n.init()
    require("src.ui.PixelCanvas").enableNearest()
    local Game = require("src.core.Game")
    local game = Game:new()
    game:startNewRun("warrior")
    game:startGame()
    _G.game = game

    local Menu = require("components.Menu")
    local menu = Menu:new()
    for _ = 1, math.floor(2.4 * 30) do menu:update(1 / 30) end

    local CursorManager = require("src.ui.CursorManager")
    CursorManager.load()
    love.window.hasMouseFocus = function() return true end

    love.graphics.clear(0, 0, 0, 1)
    menu:draw()

    local W, H = love.graphics.getDimensions()

    local rawGetPos = love.mouse.getPosition
    love.mouse.getPosition = function() return W * 0.35, H * 0.45 end
    CursorManager.draw()
    love.mouse.getPosition = function() return W * 0.62, H * 0.52 end
    CursorManager.request("hand")
    CursorManager.draw()
    love.mouse.getPosition = rawGetPos

    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", 8, H - 190, 340, 182, 8, 8)
    local rawH = love.graphics.getHeight
    love.graphics.getHeight = function() return 384 * 6 end
    love.mouse.getPosition = function() return 40, H - 180 end
    CursorManager.draw()
    love.mouse.getPosition = function() return 230, H - 180 end
    CursorManager.request("hand")
    CursorManager.draw()
    love.mouse.getPosition = rawGetPos
    love.graphics.getHeight = rawH

    love.graphics.captureScreenshot(function(imageData)
        imageData:encode("png", "cursor_preview.png")
        print("[screenshot] cursor_preview.png salvo")
        love.event.quit()
    end)
    love.graphics.present()
end

return M
