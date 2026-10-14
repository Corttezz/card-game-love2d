local M = {}

function M.run()
    local I18n = require("src.i18n.I18n")
    I18n.init()
    require("src.ui.PixelCanvas").enableNearest()

    local CRTShader = require("src.ui.CRTShader")
    CRTShader.load()

    local MapScreen = require("components.MapScreen")
    local MapManager = require("src.systems.MapManager")
    local screen = MapScreen:new()

    local nodes = {
        MapManager._makeNode(MapManager.NODE_TYPES.BATTLE, 3, 1),
        MapManager._makeNode(MapManager.NODE_TYPES.REST,   3, 1),
        MapManager._makeNode(MapManager.NODE_TYPES.ELITE,  3, 1),
    }
    screen:show(nodes, function() end, "Escolha o proximo caminho")

    screen.hoverIndex = 2

    love.graphics.clear(0, 0, 0, 1)
    screen:draw()

    love.graphics.captureScreenshot(function(imageData)
        imageData:encode("png", "mapscreen_screenshot.png")
        print("[screenshot] mapscreen salvo")
        love.event.quit()
    end)
    love.graphics.present()
end

return M
