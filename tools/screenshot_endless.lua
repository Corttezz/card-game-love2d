-- tools/screenshot_endless.lua
-- Captura do PÓS-JOGO (Out/2026): escolha de maldição do ciclo do endless e
-- a TopBar com Selo + ciclo + maldições. memory/endless_and_seals.md.
--
--   END_W=1920 END_H=1080 END_LOCALE=de END_TAG=x_ love . test_one screenshot_endless
-- Saída (save dir): <tag>endless_1_escolha.png, <tag>endless_2_topbar.png

local M = {}

function M.run()
    local w, h = tonumber(os.getenv("END_W")), tonumber(os.getenv("END_H"))
    if w and h then love.window.setMode(w, h, { resizable = true }) end
    local tag = os.getenv("END_TAG") or ""
    _G.EventManager = require("engine.EventManager")
    _G.Event = require("engine.Event")
    local I18n = require("src.i18n.I18n")
    I18n.init()
    if os.getenv("END_LOCALE") then I18n.setLocale(os.getenv("END_LOCALE")) end
    require("src.ui.PixelCanvas").enableNearest()

    local Game = require("src.core.Game")
    local Config = require("src.core.Config")
    local RM = require("src.systems.RunModifiers")
    local game = Game:new()
    game:startNewRun("warrior", { seal = 3 })
    game:startGame()
    require("src.systems.Rng").setActive(require("src.systems.Rng").new(4242))
    local run = game.runManager.currentRun
    run.actNumber, run.floorInAct = Config.TotalActs, 8
    run.currentFloor = Config.TotalActs * 8
    run.campaignWon = true
    game.runManager:advanceFloorInAct()          -- ciclo 1: escolha aberta
    RM.chooseCurse(run, RM.pending(run)[1])      -- já carrega uma maldição
    for _ = 1, 8 do game.runManager:advanceFloorInAct() end -- ciclo 2 aberto
    game.economySystem.currentGold = 87

    local topBar = require("components.TopBar"):new()
    topBar:setGame(game)
    local screen = require("components.EndlessCurseScreen"):new()
    screen:show(game)

    local function frame(withModal)
        love.graphics.clear(0.10, 0.08, 0.07, 1)
        topBar:update(1 / 60, game)
        topBar:draw()
        if withModal then
            screen:update(1 / 60)
            screen:draw()
        end
    end
    -- Canvas + encode síncrono: roda dentro do test_one sem depender do
    -- callback do captureScreenshot.
    local function snap(name, withModal)
        for _ = 1, 30 do screen.time = screen.time + 1 / 60 end
        local cv = love.graphics.newCanvas(love.graphics.getWidth(), love.graphics.getHeight())
        love.graphics.setCanvas(cv)
        frame(withModal)
        love.graphics.setCanvas()
        cv:newImageData():encode("png", tag .. name)
        print("[screenshot_endless] " .. tag .. name)
    end
    snap("endless_1_escolha.png", true)
    screen:choose(2)
    snap("endless_2_topbar.png", false)
    return true
end

return M
