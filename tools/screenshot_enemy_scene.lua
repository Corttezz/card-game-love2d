-- tools/screenshot_enemy_scene.lua
-- Captura o CENÁRIO DE COMBATE real (GameplayScene.draw) pra um node
-- específico: prova em que cena cada tipo de encontro acontece e onde o pé
-- do inimigo pousa.
--
--   love . screenshot_enemy_scene <ato>_<nodeType>
--   love . screenshot_enemy_scene 2_elite      → elite do ato 2 (estrada)
--   love . screenshot_enemy_scene 2_boss       → chefe do ato 2 (hall)
--   love . screenshot_enemy_scene 1_boss
--   love . screenshot_enemy_scene 6_battle     → dusk_shade (flutuante)
--
-- Sufixo "_hud" desenha a cena SEM o HUD/mão (default inclui tudo, que é o
-- que o jogador vê). Saída: enemy_scene_<modo>.png no save dir.
--
-- Por que existe: `screenshot_worldroad interior` só sabia desenhar o hall
-- com um inimigo colado no meio da tela — não passava pelo `GameplayScene`
-- e por isso não provava NADA sobre qual cena o jogo escolhe. Este tool
-- roda o caminho real.

local M = {}

function M.run(mode)
    mode = mode or "2_boss"
    local act = tonumber(mode:match("^(%d+)")) or 1
    local nodeType = mode:match("^%d+_(%a[%a_]*)") or "boss"

    local I18n = require("src.i18n.I18n")
    I18n.init()
    require("src.ui.PixelCanvas").enableNearest()

    local Game = require("src.core.Game")
    local GameplayScene = require("src.scenes.GameplayScene")
    local EnemyRenderer = require("src.ui.EnemyRenderer")
    local WorldRoad = require("src.ui.WorldRoad")
    local TopBar = require("components.TopBar")
    local GameUI = require("components.GameUI")
    local Button = require("components.Button")

    local game = Game:new()
    game:startNewRun("warrior")
    game:startGame()

    -- Força o node/ato pedidos (o mapa normalmente decide isto).
    local run = game.runManager.currentRun
    run.actNumber = act
    run.floorInAct = (nodeType == "boss") and 8 or 3
    run.currentNode = { type = nodeType }
    game.enemy.spriteId = EnemyRenderer.resolveSpriteId(act, nodeType)
    game.enemy.isBoss = (nodeType == "boss")

    _G.game = game
    local topBar = TopBar:new()
    topBar:setGame(game)
    local gameUI = GameUI:new()
    local width, height = love.graphics.getDimensions()
    local playButton = Button:new(width * 0.80, height * 0.80, 150, 46, "Jogar")

    GameplayScene.init({
        game = game, topBar = topBar, gameUI = gameUI,
        playButton = playButton,
    })

    -- BOSS: o jogo só mostra o interior DEPOIS da cutscene da porta. O tool
    -- pula a cerimônia (é o estado de combate que interessa aqui).
    if nodeType == "boss" then GameplayScene._debugForceBossEntered() end

    WorldRoad.setBiome(act)
    WorldRoad.setTimeOfDay(nodeType == "boss" and 1 or 0.75, true)
    for _ = 1, 90 do
        WorldRoad.update(1 / 30)
        EnemyRenderer.update(1 / 30)
        require("src.ui.InteriorFX").update(1 / 30, math.min(3, act))
    end

    love.graphics.clear(0, 0, 0, 1)
    GameplayScene.draw()

    love.graphics.captureScreenshot(function(imageData)
        local path = "enemy_scene_" .. mode .. ".png"
        imageData:encode("png", path)
        print("[screenshot] salvo em save-dir: " .. path)
        love.event.quit()
    end)
    love.graphics.present()
end

return M
