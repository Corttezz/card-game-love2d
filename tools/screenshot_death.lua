-- tools/screenshot_death.lua
-- Captura 3 screenshots em momentos diferentes da animação death pra validar
-- visualmente que ela está sendo tocada (frame 0, frame 3, frame 6).

local M = {}

local Game = require("src.core.Game")
local CRTShader = require("src.ui.CRTShader")
local SceneLayer = require("src.ui.SceneLayer")
local EnemyRenderer = require("src.ui.EnemyRenderer")

function M.run()
    require("src.i18n.I18n").init()
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

    local SmokeSystem = require("src.systems.SmokeSystem")
    local SmokeConfig = require("src.config.SmokeConfig")
    _G.smokeSystem = SmokeSystem:new()
    SmokeConfig.applyToSystem(_G.smokeSystem, "act1")

    -- Avança 1s pra entrar em regime
    SceneLayer._currentAct = 1
    for _ = 1, 30 do
        SceneLayer.update(1/30)
        EnemyRenderer.update(1/30)
        _G.smokeSystem:update(1/30)
    end

    -- Dispara death
    print("[death-screenshot] disparando triggerDeath")
    EnemyRenderer.triggerDeath(game.enemy.spriteId)

    -- Captura em 3 momentos: frame 1 (0.1s), frame 3 (0.3s), frame 6 (0.6s)
    local frameTime = 1/30
    local moments = { 0.05, 0.30, 0.65 }
    local outFiles = { "death_early.png", "death_mid.png", "death_late.png" }

    -- Acumula tempo até cada momento e captura
    local totalElapsed = 0
    local captureIdx = 1

    local function renderFrame()
        local width, height = love.graphics.getDimensions()
        local topBarHeight = _G.topBar.height or 80
        love.graphics.clear(0, 0, 0, 1)
        SceneLayer.draw(0, topBarHeight, width, height - topBarHeight, 1)
        _G.topBar:draw()
        local cx = math.floor(width / 2)
        local cy = math.floor(height * 0.74)
        EnemyRenderer.draw(game, cx, cy)
        _G.gameUI:draw(game)
        _G.smokeSystem:draw()
    end

    local function captureNext()
        if captureIdx > #moments then
            print("[death-screenshot] OK - 3 frames capturados")
            love.event.quit()
            return
        end
        local target = moments[captureIdx]
        while totalElapsed < target do
            EnemyRenderer.update(frameTime)
            SceneLayer.update(frameTime)
            totalElapsed = totalElapsed + frameTime
        end
        renderFrame()
        local outName = outFiles[captureIdx]
        love.graphics.captureScreenshot(function(imageData)
            imageData:encode("png", outName)
            print("[death-screenshot] " .. outName .. " salvo (t=" .. target .. "s)")
            captureIdx = captureIdx + 1
            captureNext()
        end)
        love.graphics.present()
    end

    captureNext()
end

return M
