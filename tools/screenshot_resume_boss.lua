local M = {}

function M.run(modo)
    local antes = (modo == "antes")

    local I18n = require("src.i18n.I18n")
    I18n.init()
    require("src.ui.PixelCanvas").enableNearest()

    local Game          = require("src.core.Game")
    local GameplayScene = require("src.scenes.GameplayScene")
    local EnemyRenderer = require("src.ui.EnemyRenderer")
    local WorldRoad     = require("src.ui.WorldRoad")
    local InteriorFX    = require("src.ui.InteriorFX")
    local ResumeFlow    = require("src.systems.ResumeFlow")
    local TopBar        = require("components.TopBar")
    local GameUI        = require("components.GameUI")
    local Button        = require("components.Button")

    local gA = Game:new()
    gA:startNewRun("warrior")
    gA:startGame()
    local runA = gA.runManager.currentRun
    runA.actNumber = 2
    runA.floorInAct = 8
    runA.pendingNodes = nil
    runA.currentNode = { type = "boss", label = "Chefe", actNumber = 2, floorInAct = 8 }
    gA:checkpointRun()

    local game = Game:new()
    assert(game.runManager:loadRun(), "save do chefe nao carregou")
    game:resumeRun()
    _G.game = game

    local width, height = love.graphics.getDimensions()
    local topBar = TopBar:new()
    topBar:setGame(game)
    local gameUI = GameUI:new()
    local playButton = Button:new(width * 0.80, height * 0.80, 150, 46, "Jogar")

    GameplayScene.setGame(game)
    GameplayScene.init({
        game = game, topBar = topBar, gameUI = gameUI, playButton = playButton,
    })

    if antes then
        GameplayScene.resumeWorld(game)
    else
        ResumeFlow.apply(game, GameplayScene)
    end

    for _ = 1, 90 do
        WorldRoad.update(1 / 30)
        EnemyRenderer.update(1 / 30)
        InteriorFX.update(1 / 30, 2)
    end

    love.graphics.clear(0, 0, 0, 1)
    GameplayScene.draw()

    local nome = "resume_boss_" .. (antes and "antes" or "depois") .. ".png"
    love.graphics.captureScreenshot(function(imageData)
        imageData:encode("png", nome)
        print("[screenshot] salvo em save-dir: " .. nome)
        game.runManager:deleteSave()
        love.event.quit()
    end)
    love.graphics.present()
end

return M
