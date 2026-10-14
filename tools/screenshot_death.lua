local M = {}

local Game = require("src.core.Game")
local CRTShader = require("src.ui.CRTShader")
local SceneLayer = require("src.ui.SceneLayer")
local EnemyRenderer = require("src.ui.EnemyRenderer")

function M.run(mode)
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

    SceneLayer._currentAct = 1
    for _ = 1, 30 do
        SceneLayer.update(1/30)
        EnemyRenderer.update(1/30)
        _G.smokeSystem:update(1/30)
    end

    local byPipeline = (mode == "orb")
    if byPipeline then
        game.player.orbs = {}
        game.player:addOrb({ type = "lightning", value = 99 })
        game.enemy.health = 5
        game:endTurn()
        local waited = 0
        while waited < 3.0 and not game._deathHandled do
            _G.EventManager.update(1 / 60)
            EnemyRenderer.update(1 / 60)
            waited = waited + 1 / 60
        end
        print("[death-screenshot] _deathHandled=" .. tostring(game._deathHandled)
            .. " clip=" .. tostring(EnemyRenderer.debugState().animName)
            .. " (vida do inimigo: " .. tostring(game.enemy.health) .. ")")
    else
        game.enemy.health = 0
        EnemyRenderer.triggerDeath(game.enemy.spriteId)
    end

    local frameTime = 1/30
    local moments = { 0.05, 0.30, 0.65, 1.05 }
    local prefix = byPipeline and "death_orb_" or "death_"
    local outFiles = { prefix .. "early.png", prefix .. "mid.png",
                       prefix .. "late.png", prefix .. "corpse.png" }

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

    local totalElapsed = 0
    for i, target in ipairs(moments) do
        while totalElapsed < target do
            EnemyRenderer.update(frameTime)
            SceneLayer.update(frameTime)
            totalElapsed = totalElapsed + frameTime
        end
        renderFrame()
        local outName = outFiles[i]
        love.graphics.captureScreenshot(function(imageData)
            imageData:encode("png", outName)
            print("[death-screenshot] " .. outName .. " salvo (t=" .. target .. "s)")
        end)
        love.graphics.present()
    end
    print("[death-screenshot] OK - " .. #moments .. " frames capturados")
    love.event.quit()
end

return M
