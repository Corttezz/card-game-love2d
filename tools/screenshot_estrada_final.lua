local M = {}

local function virtual()
    local vw, vh = (os.getenv("ESTRADA_VIRTUAL") or "1920x1080"):match("^(%d+)x(%d+)$")
    vw, vh = tonumber(vw), tonumber(vh)
    love.graphics.getWidth = function() return vw end
    love.graphics.getHeight = function() return vh end
    love.graphics.getDimensions = function() return vw, vh end
    return vw, vh
end

local function forkNodes(n)
    local MM = require("src.systems.MapManager")
    local types = n == 2 and { "battle", "shop" } or { "battle", "rest", "shop" }
    local nodes = {}
    for i, ty in ipairs(types) do
        nodes[i] = { type = ty, label = MM.labelFor(ty), desc = MM.descFor(ty) }
    end
    return nodes
end

local function setup(WorldRoad, bio, scene, width, height, topBarH, canvas, tod)
    WorldRoad.resetRun()
    love.math.setRandomSeed(7)
    math.randomseed(7)
    WorldRoad._rng = love.math.newRandomGenerator(0xC0FFEE)
    WorldRoad._time = 0
    WorldRoad._birds, WorldRoad._critters, WorldRoad._ambient = {}, {}, {}
    WorldRoad.setBiome(bio)
    WorldRoad._blend = nil
    WorldRoad._prevBiomeIndex = nil
    WorldRoad._birdTimer = 1e9
    WorldRoad.setTimeOfDay(tod, true)
    local function tick(n, draw)
        for i = 1, n do
            WorldRoad.update(1 / 30)
            if draw or i % 6 == 0 or i == n then
                love.graphics.setCanvas(canvas)
                love.graphics.clear(0, 0, 0, 1)
                WorldRoad.draw(0, topBarH, width, height - topBarH, bio)
                love.graphics.setCanvas()
            end
        end
    end
    WorldRoad._camZ = 5.5
    tick(30, true)
    require("src.i18n.I18n").init()
    require("src.i18n.I18n").setLocale("en", true)
    if scene == "fork3" or scene == "fork2" or scene == "converge" or scene == "chegada" then
        WorldRoad.showFork(forkNodes(scene == "fork2" and 2 or 3), function() end)
        tick(60, true)
        if scene == "converge" or scene == "chegada" then
            local f = WorldRoad._fork
            local b = f.markBoxes[3]
            if b then
                WorldRoad.forkMousePressed((b.x1 + b.x2) / 2, (b.y1 + b.y2) / 2)
            end
            if scene == "converge" then
                tick(32, true)
            else
                tick(64, true)
            end
        end
    elseif scene == "continuar" then
        WorldRoad.resetRun()
        WorldRoad.restoreProgress(bio, 4)
        WorldRoad.setTimeOfDay(tod, true)
        tick(4, true)
        WorldRoad.showFork(forkNodes(3), function() end)
        tick(8, true)
    end
    WorldRoad._blend = nil
    WorldRoad._prevBiomeIndex = nil
    WorldRoad.setTimeOfDay(tod, true)
end

local function battleSetup(act, tod)
    local I18n = require("src.i18n.I18n")
    I18n.init()
    I18n.setLocale("en", true)
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
    local run = game.runManager.currentRun
    run.actNumber = act
    run.floorInAct = 3
    run.currentNode = { type = "battle" }
    local EnemyRoster = require("src.systems.EnemyRoster")
    local ActSystem = require("src.systems.ActSystem")
    local Enemy = require("src.entities.Enemy")
    local sid = EnemyRenderer.resolveSpriteId(act, "battle")
    game.enemy = EnemyRoster.spawn(Enemy, sid, ActSystem.getEnemyStats(act, 3, "battle"))
    _G.game = game
    local topBar = TopBar:new()
    topBar:setGame(game)
    local width, height = love.graphics.getDimensions()
    GameplayScene.init({
        game = game, topBar = topBar, gameUI = GameUI:new(),
        playButton = Button:new(width * 0.80, height * 0.80, 150, 46, "Jogar"),
    })
    WorldRoad.resetRun()
    WorldRoad._fork = nil
    WorldRoad.setBiome(act)
    WorldRoad._blend = nil
    WorldRoad._prevBiomeIndex = nil
    WorldRoad._birdTimer = 1e9
    WorldRoad.setTimeOfDay(tod, true)
    for _ = 1, 120 do
        WorldRoad.update(1 / 30)
        EnemyRenderer.update(1 / 30)
    end
    GameplayScene.WORLD_ONLY = true
    return GameplayScene
end

function M.run(arg)
    local width, height = virtual()
    local canvas = love.graphics.newCanvas(width, height)
    require("src.ui.PixelCanvas").enableNearest()
    local WorldRoad = require("src.ui.WorldRoad")
    local bios, scenes = tostring(arg or ""):match("^([%d,]*):?([%a%d,]*)$")
    local bl, sl = {}, {}
    for b in ((bios and bios ~= "") and bios or "1,2,3,4,5,6"):gmatch("%d+") do bl[#bl + 1] = tonumber(b) end
    for s in ((scenes and scenes ~= "") and scenes or "fork3,fork2,converge,battle"):gmatch("[%a%d]+") do
        sl[#sl + 1] = s
    end
    local tod = tonumber(os.getenv("ESTRADA_TOD") or "0.65")
    local tag = os.getenv("ESTRADA_TAG") or "depois"
    local dir = "estrada_final/" .. tag
    love.filesystem.createDirectory(dir)
    local realTime = love.timer.getTime
    local clock = 100
    love.timer.getTime = function() return clock end
    local topBarH = 80
    local n = 0
    WorldRoad.clearCache()
    for _, bio in ipairs(bl) do
        for _, scene in ipairs(sl) do
            local drawFn
            if scene == "battle" then
                local GS = battleSetup(bio, tod)
                drawFn = function() GS.draw() end
            else
                setup(WorldRoad, bio, scene, width, height, topBarH, canvas, tod)
                drawFn = function()
                    WorldRoad.draw(0, topBarH, width, height - topBarH, bio)
                    WorldRoad.drawOverlays(0, topBarH, width, height - topBarH)
                end
            end
            for _ = 1, 2 do
                love.graphics.setCanvas(canvas)
                love.graphics.clear(0, 0, 0, 1)
                drawFn()
                love.graphics.setCanvas()
            end
            local path = string.format("%s/ato%d_%s_%dx%d.png", dir, bio, scene, width, height)
            canvas:newImageData():encode("png", path)
            n = n + 1
            if scene == "battle" then require("src.scenes.GameplayScene").WORLD_ONLY = nil end
        end
    end
    print(love.filesystem.getSaveDirectory() .. "/" .. dir .. " " .. n)
    love.timer.getTime = realTime
    canvas:release()
    love.event.quit()
    return true
end

return M
