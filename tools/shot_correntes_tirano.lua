local M = {}

local ID = "abyss_tyrant"

local function mount()
    local Game = require("src.core.Game")
    local Enemy = require("src.entities.Enemy")
    local EnemyRoster = require("src.systems.EnemyRoster")
    local ActSystem = require("src.systems.ActSystem")
    local GameplayScene = require("src.scenes.GameplayScene")
    local EnemyRenderer = require("src.ui.EnemyRenderer")
    local BossCinematic = require("src.ui.BossCinematic")
    local InteriorFX = require("src.ui.InteriorFX")
    local WorldRoad = require("src.ui.WorldRoad")
    local TopBar = require("components.TopBar")
    local GameUI = require("components.GameUI")
    local Button = require("components.Button")

    _G.EventManager.clear()
    BossCinematic.reset()
    local game = Game:new()
    game:startNewRun("warrior")
    game:startGame()
    local run = game.runManager.currentRun
    run.actNumber = 3
    run.floorInAct = 8
    run.currentNode = { type = "boss" }
    local stats = ActSystem.getEnemyStats(3, 8, "boss")
    game.enemy = EnemyRoster.spawn(Enemy, ID, stats, 3)
    game.enemy.isBoss = true
    game.messageSystem = nil
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
    GameplayScene.setGame(game)
    GameplayScene._debugForceBossEntered()
    WorldRoad.setBiome(3)
    WorldRoad.setTimeOfDay(1, true)
    run.currentNode.enemyId = ID

    local canvas = love.graphics.newCanvas(w, h)
    local K = { game = game }
    function K.frame()
        love.graphics.setCanvas(canvas)
        love.graphics.clear(0, 0, 0, 1)
        GameplayScene.draw()
        love.graphics.setCanvas()
    end
    function K.step(secs)
        for _ = 1, math.floor(secs * 30 + 0.5) do
            love.timer.step()
            _G.EventManager.update(1 / 30)
            BossCinematic.update(1 / 30, game, { inHall = true })
            EnemyRenderer.update(1 / 30)
            InteriorFX.update(1 / 30, 3)
            K.frame()
        end
    end
    function K.shot(name)
        K.frame()
        love.filesystem.createDirectory("correntes_tirano")
        canvas:newImageData():encode("png", ("correntes_tirano/%dx%d_%s.png"):format(w, h, name))
    end
    return K
end

local function cross(K, ratio)
    local e = K.game.enemy
    local target = math.floor(e.maxHealth * ratio) - 1
    e:takeDamage(math.max(1, e.health - target))
    K.game:settleEnemyDamage(nil)
end

function M.run()
    local I18n = require("src.i18n.I18n")
    I18n.init()
    require("src.ui.PixelCanvas").enableNearest()
    _G.EventManager = _G.EventManager or require("engine.EventManager")
    _G.Event = _G.Event or require("engine.Event")
    _G.gameSettings = _G.gameSettings or {}
    _G.gameSettings.reducedMotion = false
    local sw, sh = (os.getenv("SHOT_SIZE") or ""):match("^(%d+)x(%d+)$")
    if sw then love.window.setMode(tonumber(sw), tonumber(sh)) end
    local BM = require("src.systems.BossMechanics")

    local K = mount()
    K.frame()
    K.step(1.5)
    K.shot("1_tres_correntes")
    cross(K, 0.75)
    K.step(0.10)
    K.shot("2_snap")
    K.step(0.30)
    K.shot("3_snap_caindo")
    K.step(1.5)
    K.shot("4_duas_correntes")
    cross(K, 0.50)
    K.step(1.8)
    K.shot("5_uma_corrente")
    cross(K, 0.25)
    K.step(1.8)
    K.shot("6_sem_correntes")

    K = mount()
    local GameplayScene = require("src.scenes.GameplayScene")
    GameplayScene._debugStartBossIntro()
    K.frame()
    K.step(2.9)
    K.shot("7_entrada_arrasta")
    K.step(0.9)
    K.shot("8_entrada_chegando")
    K.step(1.3)
    K.shot("9_entrada_esticou")
    K.step(2.4)
    K.shot("10_entrada_titulo")

    K = mount()
    K.step(1.0)
    BM.setStacks(K.game.enemy, "chains", 2)
    K.step(1.5)
    K.shot("11_antes_da_morte")
    K.game.enemy.health = 0
    require("src.ui.BossCinematic").startDeath(K.game)
    require("src.ui.EnemyRenderer").triggerDeath(ID)
    K.step(0.12)
    K.shot("12_morte_rompe")
    K.step(0.5)
    K.shot("13_morte_caindo")
    K.step(1.5)
    K.shot("14_morte_fim")
    return true
end

return M
