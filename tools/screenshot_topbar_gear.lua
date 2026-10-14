local M = {}

function M.run()
    require("src.i18n.I18n").init()
    require("src.ui.PixelCanvas").enableNearest()

    local Game = require("src.core.Game")
    local game = Game:new()
    game:startNewRun("warrior")
    game:startGame()
    _G.game = game

    local TopBar = require("components.TopBar")
    local topBar = TopBar:new()
    topBar:setGame(game)
    for _ = 1, 30 do topBar:update(1 / 30, game) end

    local stages = {
        { hover = 0, spin = 0,   name = "topbar_gear_idle.png" },
        { hover = 1, spin = 0.6, name = "topbar_gear_hover.png" },
        { hover = 1, spin = 1.4, name = "topbar_gear_hover_spin.png" },
    }
    for _, st in ipairs(stages) do
        topBar.configHover = st.hover
        topBar.configSpin = st.spin
        topBar.isConfigHovered = false
        love.graphics.clear(0.12, 0.09, 0.07, 1)
        topBar:draw()
        love.graphics.captureScreenshot(function(imageData)
            imageData:encode("png", st.name)
            print("[gear] " .. st.name .. " salvo")
        end)
        love.graphics.present()
    end

    love.event.quit()
end

return M
