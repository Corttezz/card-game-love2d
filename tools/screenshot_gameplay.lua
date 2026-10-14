local M = {}

local Game = require("src.core.Game")
local CRTShader = require("src.ui.CRTShader")

function M.run()
    local I18n = require("src.i18n.I18n")
    I18n.init()

    require("src.ui.PixelCanvas").enableNearest()
    CRTShader.load()

    local game = Game:new()
    game:startNewRun("warrior")
    game:startGame()

    _G.game = game

    local TopBar = require("components.TopBar")
    local GameUI = require("components.GameUI")
    _G.topBar = TopBar:new()
    _G.topBar:setGame(game)
    _G.gameUI = GameUI:new()

    local SceneLayer = require("src.ui.SceneLayer")
    local SmokeSystem = require("src.systems.SmokeSystem")
    local SmokeConfig = require("src.config.SmokeConfig")
    local EnemyRenderer = require("src.ui.EnemyRenderer")
    local ParticleSystem = require("src.systems.ParticleSystem")

    _G.smokeSystem = SmokeSystem:new()
    SmokeConfig.applyToSystem(_G.smokeSystem, "act1")

    local simDt = 1 / 30
    for _ = 1, 60 do
        SceneLayer.update(simDt)
        EnemyRenderer.update(simDt)
        _G.smokeSystem:update(simDt)
        if ParticleSystem.Manager then ParticleSystem.Manager:update(simDt) end
    end

    SceneLayer._debugLog = true
    SceneLayer._currentAct = 1
    local stats = _G.smokeSystem:getStats()
    for _ = 1, 30 do SceneLayer.update(simDt) end
    SceneLayer._debugLog = false

    love.graphics.clear(0, 0, 0, 1)

    local width, height = love.graphics.getDimensions()
    local topBarHeight = _G.topBar.height or 80

    SceneLayer.draw(0, topBarHeight, width, height - topBarHeight, 1)

    _G.topBar:draw()

    local cx = math.floor(width / 2)
    local cy = math.floor(height * 0.74)
    EnemyRenderer.draw(game, cx, cy)

    _G.gameUI:draw(game)

    _G.smokeSystem:draw()

    if ParticleSystem.Manager then ParticleSystem.Manager:draw() end

    love.graphics.captureScreenshot(function(imageData)
        local path = "gameplay_screenshot.png"
        imageData:encode("png", path)
        print("[screenshot] salvo em save-dir: " .. path)
        love.event.quit()
    end)

    love.graphics.present()
end

return M
