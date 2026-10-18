local M = {}

function M.run(mode)
    mode = mode or "2_boss"
    local act = tonumber(mode:match("^(%d+)")) or 1
    local nodeType = mode:match("^%d+_(%a[%a_]*)") or "boss"

    local vw, vh = (os.getenv("ENEMY_SCENE_VIRTUAL") or ""):match("^(%d+)x(%d+)$")
    local vcanvas
    if vw then
        vw, vh = tonumber(vw), tonumber(vh)
        vcanvas = love.graphics.newCanvas(vw, vh)
        love.graphics.getWidth = function() return vw end
        love.graphics.getHeight = function() return vh end
        love.graphics.getDimensions = function() return vw, vh end
    end

    local I18n = require("src.i18n.I18n")
    I18n.init()
    if os.getenv("TUT_LOCALE") then I18n.setLocale(os.getenv("TUT_LOCALE"), true) end
    require("src.ui.PixelCanvas").enableNearest()

    local Game = require("src.core.Game")
    local GameplayScene = require("src.scenes.GameplayScene")
    local EnemyRenderer = require("src.ui.EnemyRenderer")
    local WorldRoad = require("src.ui.WorldRoad")
    local TopBar = require("components.TopBar")
    local GameUI = require("components.GameUI")
    local Button = require("components.Button")

    local game = Game:new()
    game:startNewRun(os.getenv("ENEMY_SCENE_CLASS") or "warrior")
    game:startGame()

    local run = game.runManager.currentRun
    run.actNumber = act
    run.floorInAct = (nodeType == "boss") and 8 or 3
    run.currentNode = { type = nodeType }
    local forcedId = os.getenv("ENEMY_SCENE_ID")
    if forcedId and forcedId ~= "" then mode = mode .. "_" .. forcedId end
    game.enemy.spriteId = (forcedId and forcedId ~= "") and forcedId
        or EnemyRenderer.resolveSpriteId(act, nodeType)
    game.enemy.isBoss = (nodeType == "boss")

    do
        local EnemyRoster = require("src.systems.EnemyRoster")
        local ActSystem = require("src.systems.ActSystem")
        local Enemy = require("src.entities.Enemy")
        local stats = ActSystem.getEnemyStats(act, run.floorInAct, nodeType)
        local sid = game.enemy.spriteId
        game.enemy = EnemyRoster.spawn(Enemy, sid, stats)
        game.enemy.isBoss = (nodeType == "boss")
        local mv = os.getenv("ENEMY_SCENE_MOVE")
        if mv and mv ~= "" then
            game.enemy:forceIntent(mv, game.player)
            mode = mode .. "_" .. mv
        end
        for name in (os.getenv("ENEMY_SCENE_DEBUFFS") or ""):gmatch("[^,]+") do
            game.player:addDebuff(name, 2, (name == "poison" or name == "burn") and 4 or 1)
        end
        local vis = os.getenv("ENEMY_SCENE_VISIBILITY")
        if vis and vis ~= "" then
            local IV = require("src.systems.IntentVisibility")
            local level, cause = vis:match("^([%a_]+):?(%a*)$")
            game.enemy.fogContext = IV.contextFor(run)
            game.enemy.intentVisibility = level
            game.enemy.intentVeilCause = (cause == "veil") and "veil" or "fog"
            IV.noteActive(game.enemy)
            mode = mode .. "_vis_" .. level .. ((cause == "veil") and "_veil" or "")
        end
    end

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

    if nodeType == "boss" then GameplayScene._debugForceBossEntered() end

    WorldRoad.setBiome(act)
    WorldRoad.setTimeOfDay(nodeType == "boss" and 1 or 0.75, true)
    for _ = 1, 90 do
        WorldRoad.update(1 / 30)
        EnemyRenderer.update(1 / 30)
        local IFX = require("src.ui.InteriorFX"); IFX.update(1 / 30, IFX.hallFor(act))
    end
    if os.getenv("ENEMY_SCENE_VISIBILITY") then
        local WE = require("engine.WeatherEngine")
        print(string.format("[screenshot] clima: intensidade=%.2f (boost da névoa=%.2f) partículas=%d",
            WE.intensity(), WE.veilBoost(), WE.count()))
    end

    local EnemyHud = require("src.ui.EnemyHud")
    local lastL
    local origLayout = EnemyHud.layout
    EnemyHud.layout = function(...)
        local L = origLayout(...)
        lastL = L
        return L
    end
    local intentSpec = os.getenv("ENEMY_SCENE_INTENT")
    if intentSpec and intentSpec ~= "" then
        local it = { perHit = 0, hits = 0, armor = 0, strength = 0, heal = 0,
            summon = 0, debuffs = {} }
        for k, v in intentSpec:gmatch("(%w+)=([%w_]+)") do
            if k == "debuff" then
                it.debuffs[#it.debuffs + 1] = { name = v, stacks = 2, duration = 2 }
            elseif k == "kind" then it.kind = v
            elseif k == "pierce" or k == "charge" then it[k] = (v == "1")
            else it[k] = tonumber(v) or v end
        end
        it.id = it.id or it.kind
        it.raw = it.perHit
        mode = mode .. "_intent_" .. it.kind .. ((it.pierce and "_pierce") or "")
        game.enemy.intent = it
        game.enemy.nextIntent = it.kind
        game.enemy.nextIntentDamage = it.raw
    end

    local pdeb = os.getenv("ENEMY_SCENE_PLAYER_DEBUFFS")
    if pdeb and pdeb ~= "" and game.player.addDebuff then
        for name in pdeb:gmatch("[%w_]+") do game.player:addDebuff(name, 2, 2) end
    end

    if os.getenv("ENEMY_SCENE_WORLD_ONLY") == "1" then
        GameplayScene.WORLD_ONLY = true
        mode = mode .. "_world"
    end
    local tod = tonumber(os.getenv("ENEMY_SCENE_TOD") or "")
    if tod then
        WorldRoad.setTimeOfDay(tod, true)
        for _ = 1, 30 do WorldRoad.update(1 / 30); EnemyRenderer.update(1 / 30) end
    end

    if os.getenv("ENEMY_SCENE_CLEAN") == "1" and game.messageSystem then
        game.messageSystem.messages = {}
    end

    if os.getenv("TUT_SELECT") then
        game.selectedCards = { game.hand[1] }
        if game.hand[1] then game.hand[1].isSelected = true end
        require("src.ui.DamagePreviewPanel").update(game, nil, 1)
    end
    if vcanvas then love.graphics.setCanvas(vcanvas) end
    love.graphics.clear(0, 0, 0, 1)
    GameplayScene.draw()
    if os.getenv("TUT_TIP") then
        local Tutorial = require("src.systems.Tutorial")
        local conv, line = os.getenv("TUT_TIP"):match("^([%w_]+):?([%w_]*)$")
        Tutorial._show(conv, line ~= "" and line or nil, game)
        Tutorial.draw()
        mode = mode .. "_tut_" .. conv .. "_" .. (line or "") .. "_" .. (os.getenv("TUT_LOCALE") or "pt_BR")
            .. "_" .. love.graphics.getWidth() .. "x" .. love.graphics.getHeight()
    end
    if os.getenv("ENEMY_SCENE_HOVER") == "1" then
        local L = lastL
        if L and L.iw > 0 then
            local hx = math.floor(L.cx - L.totalW / 2 + L.iw / 2)
            local hy = math.floor(L.rowY + L.rowH / 2)
            love.mouse.getPosition = function() return hx, hy end
            love.graphics.clear(0, 0, 0, 1)
            GameplayScene.draw()
            local ST = require("src.ui.StatusTooltip")
            local realTime = love.timer.getTime
            love.timer.getTime = function() return realTime() + 2 end
            if ST.draw then ST.draw() end
            love.timer.getTime = realTime
        end
    end
    if vcanvas then
        love.graphics.setCanvas()
        local path = "enemy_scene_" .. mode .. "_" .. vw .. "x" .. vh .. ".png"
        vcanvas:newImageData():encode("png", path)
        print("[screenshot] salvo em save-dir: " .. path)
        local sn, sdt = (os.getenv("ENEMY_SCENE_SEQ") or ""):match("^(%d+):([%d%.]+)$")
        sn, sdt = tonumber(sn), tonumber(sdt)
        if sn and sdt and sdt > 0 then
            for i = 1, sn - 1 do
                local steps = math.max(1, math.floor(sdt * 60 + 0.5))
                for _ = 1, steps do WorldRoad.update(1 / 60); EnemyRenderer.update(1 / 60) end
                love.graphics.setCanvas(vcanvas)
                love.graphics.clear(0, 0, 0, 1)
                GameplayScene.draw()
                love.graphics.setCanvas()
                local pi = path:gsub("%.png$", "_seq" .. i .. ".png")
                vcanvas:newImageData():encode("png", pi)
                print("[screenshot] salvo em save-dir: " .. pi)
            end
        end
        love.event.quit()
        return
    end

    love.graphics.captureScreenshot(function(imageData)
        local path = "enemy_scene_" .. mode .. ".png"
        imageData:encode("png", path)
        print("[screenshot] salvo em save-dir: " .. path)
        love.event.quit()
    end)
    love.graphics.present()
end

return M
