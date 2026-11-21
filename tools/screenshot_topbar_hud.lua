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

    local run = game.runManager.currentRun
    local stages = {
        { act = 1, floor = 3, gold = 10, score = 0, name = "topbar_hud_a1.png" },
        { act = 2, floor = 8, gold = 47, score = 1840, name = "topbar_hud_a2.png" },
        { act = 3, floor = 5, gold = 132, score = 25600, record = true, name = "topbar_hud_a3.png" },
    }
    for _, st in ipairs(stages) do
        run.actNumber, run.floorInAct = st.act, st.floor
        game.economySystem.currentGold = st.gold
        topBar.disp.gold = st.gold
        game.score = st.score
        game.scoreSystem.recordBroken = st.record or false
        love.graphics.clear(0.16, 0.13, 0.10, 1)
        topBar:draw()
        love.graphics.captureScreenshot(function(imageData)
            imageData:encode("png", st.name)
            print("[hud] " .. st.name)
        end)
        love.graphics.present()
    end

    love.event.quit()
end

return M
