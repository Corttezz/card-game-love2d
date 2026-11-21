local M = {}

M.VW, M.VH = 1920, 1080
M.OW, M.OH = 960, 540
M.EVERY = 2
M.TAIL = 1.4
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

local function outDir()
    local d = os.getenv("GIF_OUT")
    assert(d and d ~= "", "GIF_OUT ausente")
    return d
end

local function writeData(d, path)
    local fd = d:encode("png")
    local f = assert(io.open(path, "wb"))
    f:write(fd:getString())
    f:close()
    fd:release()
end

local function shrink(cv, small)
    love.graphics.setCanvas(small)
    love.graphics.clear(0, 0, 0, 1)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(cv, 0, 0, 0, M.OW / M.VW, M.OH / M.VH)
    love.graphics.setCanvas()
    local d = small:newImageData()
    return d
end

local function footRow(full, fx, fy)
    if not fx then return nil end
    local W, H = full:getDimensions()
    local x0 = math.max(0, math.floor(fx - 160))
    local x1 = math.min(W - 1, math.floor(fx + 160))
    return x0, x1
end

local function writeFrame(cv, small, prefix, n, crop)
    local d = shrink(cv, small)
    writeData(d, string.format("%s/%s_%03d.png", outDir(), prefix, n))
    d:release()
    if crop then
        local full = cv:newImageData()
        local W, H = full:getDimensions()
        local cw, ch = 560, 520
        local x0 = math.floor(math.max(0, math.min(W - cw, crop.x - cw / 2)))
        local y0 = math.floor(math.max(0, math.min(H - ch, crop.y - ch * 0.8)))
        local c = love.image.newImageData(cw, ch)
        c:paste(full, 0, 0, x0, y0, cw, ch)
        writeData(c, string.format("%s/%s_crop_%03d.png", outDir(), prefix, n))
        c:release()
        full:release()
    end
end

local function captureEntry(entry, cv, small, prefix)
    local Entradas = require("tools.entradas")
    local GameplayScene = require("src.scenes.GameplayScene")
    local WorldRoad = require("src.ui.WorldRoad")
    local Shake = require("src.systems.ScreenShake")
    local CardParticles = require("src.systems.CardParticles")
    local UiScale = require("src.ui.UiScale")
    local ER = require("src.ui.EnemyRenderer")
    local ctx = Entradas.mount(entry, { dt = DT })
    local function draw()
        love.graphics.setCanvas(cv)
        love.graphics.clear(0, 0, 0, 1)
        Shake.push()
        GameplayScene.draw()
        Shake.pop()
        UiScale.begin()
        CardParticles.draw()
        UiScale.finish()
        love.graphics.setCanvas()
    end
    draw()
    Entradas.startEntrance(ctx, DT)
    local frame, n, after = 0, 0, nil
    local lines = {}
    local crop = os.getenv("GIF_CROP") == "1" and { x = M.VW / 2, y = M.VH * 0.62 } or nil
    while frame < 30 * 20 do
        local was = WorldRoad.isTraveling()
        GameplayScene.update(DT)
        if _G.EventManager and _G.EventManager.update then _G.EventManager.update(DT) end
        Shake.update(DT)
        CardParticles.update(DT)
        draw()
        local S = require("src.ui.EnemyEntrance").state()
        if crop and S and S.footX then crop.x, crop.y = S.footX, S.footY end
        if frame % M.EVERY == 0 then
            writeFrame(cv, small, prefix, n, crop)
            local lf = ER.getLastFoot and ER.getLastFoot()
            lines[#lines + 1] = string.format("%03d t=%.2f %s foot=%s battleFoot=%s", n, frame * DT, Entradas.phase(),
                S and S.footY and string.format("%.1f,%.1f", S.footX, S.footY) or "-",
                (not S and lf) and string.format("%s", tostring(lf.y or "")) or "-")
            n = n + 1
        end
        frame = frame + 1
        if was and not WorldRoad.isTraveling() then after = frame end
        if after and frame - after >= math.floor(M.TAIL / DT) then break end
    end
    local f = io.open(string.format("%s/%s_timeline.txt", outDir(), prefix), "w")
    if f then f:write(table.concat(lines, "\n")); f:close() end
    return n
end

local function captureBoss(act, cv, small, prefix)
    _G.EventManager = require("engine.EventManager")
    _G.Event = require("engine.Event")
    local simT = 100
    local realTime = love.timer.getTime
    local realBase = realTime()
    love.timer.getTime = function() return simT + (realTime() - realBase) end
    love.timer.getDelta = function() return DT end
    local Game = require("src.core.Game")
    local GameplayScene = require("src.scenes.GameplayScene")
    local BossCinematic = require("src.ui.BossCinematic")
    local EnemyRenderer = require("src.ui.EnemyRenderer")
    local WorldRoad = require("src.ui.WorldRoad")
    local ScreenShake = require("src.systems.ScreenShake")
    local TopBar = require("components.TopBar")
    local GameUI = require("components.GameUI")
    local Button = require("components.Button")
    local EnemyRoster = require("src.systems.EnemyRoster")
    local ActSystem = require("src.systems.ActSystem")
    local Enemy = require("src.entities.Enemy")
    local game = Game:new()
    game:startNewRun("warrior")
    game:startGame()
    local run = game.runManager.currentRun
    run.actNumber = act
    run.floorInAct = 8
    run.currentNode = { type = "boss" }
    local bossId = EnemyRenderer.resolveSpriteId(act, "boss")
    local stats = ActSystem.getEnemyStats(act, 8, "boss")
    game.enemy = EnemyRoster.spawn(Enemy, bossId, stats)
    game.enemy.spriteId = bossId
    run.currentNode.enemyId = bossId
    game.enemy.isBoss = true
    game.messageSystem = nil
    _G.game = game
    local topBar = TopBar:new()
    topBar:setGame(game)
    GameplayScene.init({
        game = game, topBar = topBar, gameUI = GameUI:new(),
        playButton = Button:new(M.VW * 0.80, M.VH * 0.80, 150, 46, "Jogar"),
        endTurnButton = Button:new(M.VW * 0.80, M.VH * 0.88, 150, 40, "Encerrar"),
        setCurrentState = function() end, onPhaseCleared = function() end,
    })
    GameplayScene.setGame(game)
    WorldRoad.setBiome(act)
    WorldRoad.setTimeOfDay(1, true)
    local IFX = require("src.ui.InteriorFX")
    for _ = 1, 90 do
        WorldRoad.update(DT)
        EnemyRenderer.update(DT)
        IFX.update(DT, IFX.hallFor(act))
    end
    local function step()
        simT = simT + DT
        realBase = realTime()
        _G.EventManager.update(DT)
        ScreenShake.update(DT)
        GameplayScene.update(DT)
        if game.enemy and game.enemy.update then game.enemy:update(DT) end
    end
    GameplayScene._debugStartBossIntro()
    assert(BossCinematic.isActive(), "entrada do chefe nao comecou")
    local frame, n, tail = 0, 0, 0.8
    local lines = {}
    local every = tonumber(os.getenv("GIF_EVERY") or "") or M.EVERY
    while frame < 30 * 30 do
        if frame % every == 0 then
            love.graphics.setCanvas(cv)
            love.graphics.clear(0, 0, 0, 1)
            ScreenShake.push()
            GameplayScene.draw()
            ScreenShake.pop()
            love.graphics.setCanvas()
            writeFrame(cv, small, prefix, n, nil)
            local d = BossCinematic._debug()
            lines[#lines + 1] = string.format("%03d t=%.2f step=%s", n, frame * DT,
                d.seq and d.seq.steps[d.seq.idx] and d.seq.steps[d.seq.idx].kind or "-")
            n = n + 1
        end
        step()
        frame = frame + 1
        if not BossCinematic.isActive() then
            tail = tail - DT
            if tail <= 0 then break end
        end
    end
    local f = io.open(string.format("%s/%s_timeline.txt", outDir(), prefix), "w")
    if f then f:write(table.concat(lines, "\n")); f:close() end
    return n
end

function M.run(arg)
    local I18n = require("src.i18n.I18n")
    I18n.init()
    I18n.setLocale("en", true)
    require("src.ui.PixelCanvas").enableNearest()
    require("src.systems.ScreenShake").install()
    local prefix = os.getenv("GIF_PREFIX") or arg or "x"
    local restore = patchDims(M.VW, M.VH)
    love.window.setVSync(0)
    local cv = love.graphics.newCanvas(M.VW, M.VH)
    local small = love.graphics.newCanvas(M.OW, M.OH)
    small:setFilter("linear", "linear")
    local ok, res
    local bossAct = arg and arg:match("^boss(%d)$")
    if bossAct then
        ok, res = pcall(captureBoss, tonumber(bossAct), cv, small, prefix)
    else
        local Entradas = require("tools.entradas")
        local entry = nil
        for _, r in ipairs(Entradas.roster()) do if r.id == arg then entry = r end end
        if not entry then
            print("[FAIL] criatura desconhecida: " .. tostring(arg))
            restore()
            return false
        end
        ok, res = pcall(captureEntry, entry, cv, small, prefix)
    end
    restore()
    if not ok then
        print("[FAIL] " .. tostring(arg) .. ": " .. tostring(res))
        return false
    end
    print(string.format("[ok] %s: %d quadros", tostring(arg), res))
    return true
end

return M
