local M = {}

function M.run()
    local I18n = require("src.i18n.I18n")
    I18n.init()
    require("src.ui.PixelCanvas").enableNearest()
    _G.EventManager = _G.EventManager or require("engine.EventManager")
    _G.Event = _G.Event or require("engine.Event")
    _G.gameSettings = _G.gameSettings or {}
    _G.gameSettings.reducedMotion = false

    local Game = require("src.core.Game")
    local GameplayScene = require("src.scenes.GameplayScene")
    local EnemyRenderer = require("src.ui.EnemyRenderer")
    local BossAura = require("src.ui.BossAura")
    local WorldRoad = require("src.ui.WorldRoad")
    local TopBar = require("components.TopBar")
    local GameUI = require("components.GameUI")
    local Button = require("components.Button")

    local game = Game:new()
    game:startNewRun("warrior")
    game:startGame()
    local run = game.runManager.currentRun
    run.actNumber = 1
    run.floorInAct = 8
    run.currentNode = { type = "boss" }
    game.messageSystem = nil
    game.enemy.spriteId = EnemyRenderer.resolveSpriteId(1, "boss")
    game.enemy.isBoss = true
    EnemyRenderer.clearCache()
    EnemyRenderer.resetRun()

    _G.game = game
    local topBar = TopBar:new()
    topBar:setGame(game)
    local w, h = love.graphics.getDimensions()
    GameplayScene.init({
        game = game, topBar = topBar, gameUI = GameUI:new(),
        playButton = Button:new(w * 0.80, h * 0.80, 150, 46, "Jogar"),
    })
    GameplayScene._debugForceBossEntered()
    WorldRoad.setBiome(1)
    WorldRoad.setTimeOfDay(1, true)

    local canvas = love.graphics.newCanvas(w, h)
    local function frame()
        love.graphics.setCanvas(canvas)
        love.graphics.clear(0, 0, 0, 1)
        GameplayScene.draw()
        love.graphics.setCanvas()
    end
    local function step(secs)
        local n = math.floor(secs * 30 + 0.5)
        for _ = 1, n do
            love.timer.step()
            EnemyRenderer.update(1 / 30)
            pcall(function() require("src.ui.InteriorFX").update(1 / 30, 1) end)
            frame()
        end
    end
    local function shot(name)
        frame()
        canvas:newImageData():encode("png", "rei_carnica_" .. name .. ".png")
    end
    local function setCrows(n)
        game.enemy.statusEffects = {}
        if n > 0 then
            game.enemy:addStatusEffect({ name = "swarm", stacks = n, duration = 999 })
        end
    end

    frame()
    step(1.0)
    shot("0_corvos")
    setCrows(3)
    step(0.30)
    shot("3_corvos_rasante")
    step(2.5)
    shot("3_corvos")
    setCrows(6)
    step(3.0)
    shot("6_corvos")
    setCrows(12)
    step(3.5)
    shot("12_corvos_teto")
    setCrows(6)
    step(2.0)

    EnemyRenderer.triggerAttack("multi", nil, { swarm = true })
    step(0.20)
    shot("mergulho_a")
    step(0.13)
    shot("mergulho_b_impacto")
    step(0.20)
    shot("mergulho_c_volta")
    step(1.0)
    EnemyRenderer.triggerAttack("attack", nil, {})
    step(0.40)
    shot("bicada_real")
    BossAura.reset()
    return true
end

return M
