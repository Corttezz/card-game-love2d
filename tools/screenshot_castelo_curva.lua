local M = {}

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

M.SCRIPT = {
    { pick = 1, types = { "battle", "rest", "shop" }, tag = "esq" },
    { pick = 1, types = { "shop", "battle", "rest" }, tag = "esq2_loja" },
    { pick = 3, types = { "rest", "shop", "battle" }, tag = "dir" },
    { pick = 2, types = { "rest", "battle", "shop" }, tag = "meio" },
    { pick = 2, types = { "rest", "battle", "shop" }, tag = "meio2" },
    { pick = 1, types = { "boss" }, tag = "chefe" },
}

M.SCRIPT_DIR = {
    { pick = 3, types = { "rest", "shop", "battle" }, tag = "dir" },
    { pick = 3, types = { "battle", "rest", "battle" }, tag = "dir2" },
    { pick = 1, types = { "battle", "rest", "shop" }, tag = "esq" },
    { pick = 2, types = { "rest", "battle", "shop" }, tag = "meio" },
    { pick = 2, types = { "rest", "battle", "shop" }, tag = "meio2" },
    { pick = 1, types = { "boss" }, tag = "chefe" },
}

function M.capture(act, VW, VH, dir, every, script)
    local I18n = require("src.i18n.I18n")
    I18n.init()
    I18n.setLocale("pt_BR", true)
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
    local floor = 1
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
    WorldRoad.restoreProgress(act, floor)
    WorldRoad._props = {}
    WorldRoad.setBiome(act)
    WorldRoad._blend = nil
    WorldRoad._prevBiomeIndex = nil
    WorldRoad._birdTimer = 1e9
    love.math.setRandomSeed(0xC0FFEE)
    WorldRoad.planStop(WorldRoad._camZ + WorldRoad.TRAVEL_DISTANCE, true)
    WorldRoad.setTimeOfDay(0.8, true)
    for _ = 1, 30 do WorldRoad.update(DT); EnemyRenderer.update(DT) end

    love.filesystem.createDirectory(dir)
    local trace = { "frame,phase,camZ,progress,dx_px,dx_frac" }
    local frame, phase, seqN, label = 0, "travel", 0, "inicio"
    local function render()
        love.graphics.setCanvas(cv)
        love.graphics.clear(0, 0, 0, 1)
        if phase == "fork" or phase == "converge" or phase == "boss" then
            GameplayScene.drawWorldOnly()
            topBar:draw()
        else
            GameplayScene.draw()
        end
        love.graphics.setCanvas()
        love.graphics.present()
        local ct = WorldRoad._castleTop
        if ct then
            trace[#trace + 1] = string.format("%d,%s,%.3f,%.4f,%.2f,%.5f", frame, label .. "_" .. phase,
                WorldRoad._camZ, ct.progress, ct.cx - VW / 2, (ct.cx - VW / 2) / VW)
        end
    end
    local function save(name)
        local path = dir .. "/" .. name .. ".png"
        cv:newImageData():encode("png", path)
        local ct = WorldRoad._castleTop
        print(string.format("[ok] %s dx=%.1f px (%.2f%%) progress=%.2f", path,
            ct and (ct.cx - VW / 2) or 0, ct and (ct.cx - VW / 2) / VW * 100 or 0, ct and ct.progress or 0))
    end
    local function step(n, cond, seq)
        local i = 0
        while (n and i < n) or (cond and cond()) do
            i = i + 1
            frame = frame + 1
            WorldRoad.setTimeOfDay(0.8, true)
            WorldRoad.update(DT)
            EnemyRenderer.update(DT)
            render()
            if seq and frame % every == 0 then
                seqN = seqN + 1
                save(string.format("seq_%03d_%s_%s", seqN, label, phase))
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
        step(45, nil, seq)
    end
    local ok, err = pcall(function()
        travelBattle(false)
        step(10)
        save("00_batalha")
        for si, sc in ipairs(script) do
            label = string.format("%d%s", si, sc.tag)
            phase = "fork"
            WorldRoad.showFork(nodesFor(sc.types), function() end)
            step(25, nil, true)
            save(string.format("%02d_%s_a_encruzilhada", si, sc.tag))
            local f = WorldRoad._fork
            local b = f and f.markBoxes and f.markBoxes[sc.pick]
            if b then WorldRoad.forkMousePressed((b.x1 + b.x2) / 2, (b.y1 + b.y2) / 2) end
            phase = "converge"
            step(nil, function() return WorldRoad._fork ~= nil end, true)
            local nt = sc.types[sc.pick]
            if nt == "battle" then
                travelBattle(true)
                save(string.format("%02d_%s_b_parada", si, sc.tag))
            elseif nt == "boss" then
                phase = "boss"
                WorldRoad._landmark = nil
                WorldRoad.travel({})
                step(nil, function() return WorldRoad.isTraveling() end, true)
                step(10, nil, true)
                save(string.format("%02d_%s_b_porta", si, sc.tag))
            else
                phase = "fork"
                step(20, nil, true)
                save(string.format("%02d_%s_b_parada", si, sc.tag))
                WorldRoad._landmark = nil
            end
        end
    end)
    love.filesystem.write(dir .. "/trace.csv", table.concat(trace, "\n") .. "\n")
    print("[ok] " .. love.filesystem.getSaveDirectory() .. "/" .. dir .. "/trace.csv")
    restore()
    love.window.setVSync(vsync)
    cv:release()
    collectgarbage()
    if not ok then error(err) end
end

function M.run(arg)
    io.stdout:setvbuf("line")
    local a, res, var = (arg or ""):match("^(%d*):?([%dx]*):?(%a*)$")
    local script = var == "dir" and M.SCRIPT_DIR or M.SCRIPT
    local acts = (a and a ~= "") and { tonumber(a) } or { 1, 4 }
    local w, h = (res or ""):match("^(%d+)x(%d+)$")
    w, h = tonumber(w) or 1920, tonumber(h) or 1080
    local every = tonumber(os.getenv("CASTELO_EVERY") or "") or 12
    for _, act in ipairs(acts) do
        M.capture(act, w, h, string.format("castelo_curva/a%d_%dx%d%s", act, w, h,
            var == "dir" and "_dir" or ""), every, script)
    end
    return true
end

return M
