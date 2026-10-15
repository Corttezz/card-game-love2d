local M = {}

local ACT = { tower_lich = 2, abyss_tyrant = 3, winter_monarch = 4, rot_colossus = 5,
              eclipse_queen = 6 }

local function mount(id)
    local Game = require("src.core.Game")
    local Enemy = require("src.entities.Enemy")
    local EnemyRoster = require("src.systems.EnemyRoster")
    local ActSystem = require("src.systems.ActSystem")
    local GameplayScene = require("src.scenes.GameplayScene")
    local EnemyRenderer = require("src.ui.EnemyRenderer")
    local WorldRoad = require("src.ui.WorldRoad")
    local TopBar = require("components.TopBar")
    local GameUI = require("components.GameUI")
    local Button = require("components.Button")
    local act = ACT[id]

    _G.EventManager.clear()
    local game = Game:new()
    game:startNewRun("warrior")
    game:startGame()
    local run = game.runManager.currentRun
    run.actNumber = act
    run.floorInAct = 8
    run.currentNode = { type = "boss" }
    local stats = ActSystem.getEnemyStats(act, 8, "boss")
    game.enemy = EnemyRoster.spawn(Enemy, id, stats, act)
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
    WorldRoad.setBiome(act)
    WorldRoad.setTimeOfDay(1, true)
    run.currentNode.enemyId = id

    local canvas = love.graphics.newCanvas(w, h)
    local K = {}
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
            EnemyRenderer.update(1 / 30)
            pcall(function() require("src.ui.InteriorFX").update(1 / 30, act) end)
            K.frame()
        end
    end
    function K.shot(name)
        K.frame()
        local dir = "mecanicas_chefes"
        love.filesystem.createDirectory(dir)
        canvas:newImageData():encode("png", dir .. "/" .. id .. "_" .. name .. ".png")
    end
    K.game = game
    return K
end

local SEQ = {}

function SEQ.tower_lich(K)
    local BM = require("src.systems.BossMechanics")
    local ER = require("src.ui.EnemyRenderer")
    local e = K.game.enemy
    K.frame()
    K.step(1.5)
    K.shot("1_runa")
    BM.setStacks(e, "runes", 4)
    K.step(0.25)
    K.shot("2_runas_acendendo")
    K.step(1.5)
    K.shot("3_quatro_runas")
    BM.setStacks(e, "runes", 3)
    K.step(0.12)
    K.shot("4_runa_quebrando")
    K.step(1.0)
    ER.triggerAttack("multi", function() BM.setStacks(e, "runes", BM.stacks(e, "runes") - 1) end,
        { strike = "rune" })
    K.step(0.24)
    K.shot("5_cataclismo_voo")
    K.step(0.11)
    K.shot("6_cataclismo_impacto")
    K.step(0.8)
    K.shot("7_depois")
end

function SEQ.abyss_tyrant(K)
    local BM = require("src.systems.BossMechanics")
    local ER = require("src.ui.EnemyRenderer")
    local g = K.game
    local e = g.enemy
    K.frame()
    K.step(1.5)
    K.shot("1_tres_correntes")
    e:takeDamage(math.floor(e.maxHealth * 0.26))
    g:settleEnemyDamage(nil)
    K.step(0.10)
    K.shot("2_corrente_estalando")
    K.step(0.35)
    K.shot("3_corrente_caindo")
    K.step(1.5)
    K.shot("4_duas_correntes")
    ER.triggerAttack("strong", nil, { strike = "fireball" })
    K.step(0.22)
    K.shot("5_fogo_infernal_voo")
    K.step(0.13)
    K.shot("6_fogo_infernal_impacto")
    BM.setStacks(e, "chains", 0)
    K.step(1.5)
    K.shot("7_sem_correntes")
end

function M.run(which)
    local I18n = require("src.i18n.I18n")
    I18n.init()
    require("src.ui.PixelCanvas").enableNearest()
    _G.EventManager = _G.EventManager or require("engine.EventManager")
    _G.Event = _G.Event or require("engine.Event")
    _G.gameSettings = _G.gameSettings or {}
    _G.gameSettings.reducedMotion = false
    local sw, sh = (os.getenv("SHOT_SIZE") or ""):match("^(%d+)x(%d+)$")
    if sw then love.window.setMode(tonumber(sw), tonumber(sh)) end
    local ids = {}
    if not which or which == "all" then
        for id in pairs(SEQ) do ids[#ids + 1] = id end
        table.sort(ids)
    else
        ids = { which }
    end
    for _, id in ipairs(ids) do
        SEQ[id](mount(id))
    end
    return true
end

return M
