local M = {}

local VW, VH = 1920, 1080
do
    local rw, rh = (os.getenv("POSTES_RES") or ""):match("^(%d+)x(%d+)$")
    if rw then VW, VH = tonumber(rw), tonumber(rh) end
end
local DT = 1 / 30

local function patchDims(w, h)
    local o = { love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions }
    love.graphics.getWidth = function() return w end
    love.graphics.getHeight = function() return h end
    love.graphics.getDimensions = function() return w, h end
    return function()
        love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions = o[1], o[2], o[3]
    end
end

local function nodesFor(types)
    local MM = require("src.systems.MapManager")
    local nodes = {}
    for i, ty in ipairs(types) do
        nodes[i] = { type = ty, label = MM.labelFor(ty), desc = MM.descFor(ty) }
    end
    return nodes
end

function M.capture(act, seed, tod, dir, every)
    local I18n = require("src.i18n.I18n")
    I18n.init()
    I18n.setLocale("en", true)
    require("src.ui.PixelCanvas").enableNearest()
    local Game = require("src.core.Game")
    local GameplayScene = require("src.scenes.GameplayScene")
    local EnemyRenderer = require("src.ui.EnemyRenderer")
    local WorldRoad = require("src.ui.WorldRoad")
    local TopBar = require("components.TopBar")
    local GameUI = require("components.GameUI")
    local Button = require("components.Button")
    local EnemyRoster = require("src.systems.EnemyRoster")
    local ActSystem = require("src.systems.ActSystem")
    local Enemy = require("src.entities.Enemy")

    local restore = patchDims(VW, VH)
    local vsync = love.window.getVSync()
    love.window.setVSync(0)
    local cv = love.graphics.newCanvas(VW, VH)
    local floor = 3
    local game = Game:new()
    game:startNewRun("warrior")
    game:startGame()
    local run = game.runManager.currentRun
    run.actNumber = act
    run.floorInAct = floor
    run.currentNode = { type = "battle" }
    local function spawn()
        local sid = EnemyRenderer.resolveSpriteId(act, "battle")
        game.enemy = EnemyRoster.spawn(Enemy, sid, ActSystem.getEnemyStats(act, floor, "battle"))
        game.enemy.isBoss = false
    end
    spawn()
    _G.game = game
    local topBar = TopBar:new()
    topBar:setGame(game)
    GameplayScene.init({ game = game, topBar = topBar, gameUI = GameUI:new(),
        playButton = Button:new(VW * 0.8, VH * 0.8, 150, 46, "Jogar") })
    if game.messageSystem then game.messageSystem.messages = {} end
    WorldRoad._lastRect = nil
    WorldRoad.restoreProgress(act, floor)
    WorldRoad._rng:setSeed(seed)
    WorldRoad._props = {}
    WorldRoad.setBiome(act)
    WorldRoad._blend = nil
    WorldRoad._prevBiomeIndex = nil
    WorldRoad._birdTimer = 1e9
    love.math.setRandomSeed(seed)
    WorldRoad.planStop(WorldRoad._camZ + WorldRoad.TRAVEL_DISTANCE, true)
    WorldRoad.setTimeOfDay(tod, true)
    for _ = 1, 30 do WorldRoad.update(DT); EnemyRenderer.update(DT) end

    love.filesystem.createDirectory(dir)
    local frame, phase, seqN = 0, "travel", 0
    local function render()
        love.graphics.setCanvas(cv)
        love.graphics.clear(0, 0, 0, 1)
        if phase == "fork" or phase == "converge" then
            GameplayScene.drawWorldOnly()
            topBar:draw()
        else
            GameplayScene.draw()
        end
        love.graphics.setCanvas()
        love.graphics.present()
    end
    local function save(name)
        local path = dir .. "/" .. name .. ".png"
        cv:newImageData():encode("png", path)
        local LE = require("engine.LuminaireEngine")
        local n, rels, bases = 0, {}, {}
        for _, he in ipairs(WorldRoad._hitScene) do
            local q = he.ref
            local d = q and LE.def(q.bid, q.kind)
            if d and d.roadside and he.x2 > 0 and he.x1 < VW and he.y2 > 0 and he.y1 < VH then
                n = n + 1
                rels[#rels + 1] = string.format("%+d:%.1f", q.side, q.z - WorldRoad._camZ)
                if WorldRoad._postBase then
                    local B = WorldRoad._postBase(q, WorldRoad._camZ, WorldRoad._planGeo(), VW, {})
                    if B then
                        bases[#bases + 1] = string.format("%.0f,%.0f,%.0f", B.x1, B.x2, he.y2)
                    end
                end
            end
        end
        print("[ok] " .. path .. " postes=" .. n .. " " .. table.concat(rels, " ") .. " bases=" .. table.concat(bases, ";"))
    end
    local function step(n, cond, seq)
        local i = 0
        while (n and i < n) or (cond and cond()) do
            i = i + 1
            frame = frame + 1
            WorldRoad.setTimeOfDay(tod, true)
            WorldRoad.update(DT)
            EnemyRenderer.update(DT)
            render()
            if seq and frame % every == 0 then
                seqN = seqN + 1
                save(string.format("seq_%03d_%s", seqN, phase))
            end
            if frame % 30 == 0 then collectgarbage() end
            if i > 2000 then break end
        end
    end
    local function travelBattle(seq)
        spawn()
        phase = "travel"
        WorldRoad.travel({
            encounter = EnemyRenderer.getEncounterBillboard(game.enemy),
            onComplete = function() EnemyRenderer.triggerArrival() end,
        })
        step(nil, function() return WorldRoad.isTraveling() end, seq)
        phase = "arrival"
        step(60, nil, seq)
    end
    local ok, err = pcall(function()
        travelBattle(false)
        step(15)
        render()
        save("batalha")
        if os.getenv("POSTES_RESUME") then
            WorldRoad.restoreProgress(act, floor + 1)
            WorldRoad._rng:setSeed(seed + 17)
            WorldRoad._props = {}
            WorldRoad.setBiome(act)
            WorldRoad._blend = nil
            step(20)
        end
        phase = "fork"
        local types = {}
        for ty in (os.getenv("POSTES_FORK") or "battle,rest,shop"):gmatch("[%a_]+") do types[#types + 1] = ty end
        WorldRoad.showFork(nodesFor(types), function() end)
        step(25)
        render()
        save("encruzilhada")
        local f = WorldRoad._fork
        local b = f and f.markBoxes and f.markBoxes[1]
        if b then WorldRoad.forkMousePressed((b.x1 + b.x2) / 2, (b.y1 + b.y2) / 2) end
        phase = "converge"
        step(nil, function() return WorldRoad._fork ~= nil end, true)
        travelBattle(true)
        render()
        save("batalha2")
    end)
    restore()
    love.window.setVSync(vsync)
    cv:release()
    collectgarbage()
    if not ok then error(err) end
end

function M.run(arg)
    io.stdout:setvbuf("line")
    local a, tod, tag, seed = (arg or ""):match("^(%d*):?([%d%.]*):?([%w_]*):?(%d*)$")
    local acts = (a and a ~= "") and { tonumber(a) } or { 1, 2, 3, 4, 5, 6 }
    tod = tonumber(tod) or 0.85
    tag = (tag and tag ~= "") and tag or "run"
    seed = tonumber(seed) or 0xC0FFEE
    local every = tonumber(os.getenv("POSTES_EVERY") or "") or 12
    for _, act in ipairs(acts) do
        M.capture(act, seed, tod, string.format("postes_por_ato/%s/a%d_t%02d", tag, act, math.floor(tod * 100 + 0.5)), every)
    end
    return true
end

return M
