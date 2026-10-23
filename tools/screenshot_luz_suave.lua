local M = {}

local DT = 1 / 30
M.RES = { { 1280, 720 }, { 1920, 1080 }, { 3440, 1440 } }

local function patchDims(w, h)
    local o = { love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions }
    love.graphics.getWidth = function() return w end
    love.graphics.getHeight = function() return h end
    love.graphics.getDimensions = function() return w, h end
    return function()
        love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions = o[1], o[2], o[3]
    end
end

local function outDir(sub)
    local d = love.filesystem.getSource() .. "/tools/preview_out/luz_suave/" .. sub .. "/"
    os.execute('mkdir "' .. d:gsub("/", "\\") .. '" 2>nul')
    return d
end

local function writePng(imageData, path)
    local fd = imageData:encode("png")
    local f = assert(io.open(path, "wb"))
    f:write(fd:getString())
    f:close()
end

local function crop(cv, x, y, w, h, k, path)
    local W, H = cv:getDimensions()
    x = math.max(0, math.min(W - w, math.floor(x)))
    y = math.max(0, math.min(H - h, math.floor(y)))
    local out = love.graphics.newCanvas(w * k, h * k)
    out:setFilter("nearest", "nearest")
    local q = love.graphics.newQuad(x, y, w, h, W, H)
    love.graphics.push("all")
    love.graphics.origin()
    love.graphics.setCanvas(out)
    love.graphics.clear(0, 0, 0, 1)
    love.graphics.setBlendMode("replace")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(cv, q, 0, 0, 0, k, k)
    love.graphics.pop()
    writePng(out:newImageData(), path)
    out:release()
    q:release()
end

local function pools(VW, VH)
    local LE = require("engine.LightEngine")
    local list = {}
    for i = 1, LE.queued() do
        local e = LE._entryAt(i)
        if e and (e.sy or 1) < 0.6 and e.r > 20 and e.x > 0 and e.x < VW and e.y > 0 and e.y < VH then
            list[#list + 1] = { x = e.x, y = e.y, r = e.r, sy = e.sy }
        end
    end
    table.sort(list, function(a, b) return a.r > b.r end)
    return list
end

function M.capture(act, VW, VH, dir, tag, tod, seed)
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
    local realTime = love.timer.getTime
    local fakeT = 100
    love.timer.getTime = function() return fakeT end
    local cv = love.graphics.newCanvas(VW, VH)
    local floor = 7
    love.math.setRandomSeed(seed)
    math.randomseed(seed)
    local game = Game:new()
    game:startNewRun("warrior")
    game:startGame()
    local run = game.runManager.currentRun
    run.actNumber = act
    run.floorInAct = floor
    run.currentNode = { type = "battle" }
    local sid = EnemyRenderer.resolveSpriteId(act, "battle")
    game.enemy = EnemyRoster.spawn(Enemy, sid, ActSystem.getEnemyStats(act, floor, "battle"))
    game.enemy.isBoss = false
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
    local function render()
        love.graphics.setCanvas(cv)
        love.graphics.clear(0, 0, 0, 1)
        GameplayScene.draw()
        love.graphics.setCanvas()
        love.graphics.present()
    end
    local function step(n, cond)
        local i = 0
        while (n and i < n) or (cond and cond()) do
            i = i + 1
            fakeT = fakeT + DT
            WorldRoad.setTimeOfDay(tod, true)
            WorldRoad.update(DT)
            EnemyRenderer.update(DT)
            if i % 4 == 0 then render() end
            if i % 30 == 0 then collectgarbage() end
            if i > 2000 then break end
        end
    end
    local ok, err = pcall(function()
        step(20)
        WorldRoad.travel({
            encounter = EnemyRenderer.getEncounterBillboard(game.enemy),
            onComplete = function() EnemyRenderer.triggerArrival() end,
        })
        step(nil, function() return WorldRoad.isTraveling() end)
        step(75)
        fakeT = 500
        render()
        local base = dir .. tag
        local onD = cv:newImageData()
        writePng(onD, base .. ".png")
        local LE, Lum = require("engine.LightEngine"), require("engine.LuminaireEngine")
        local list0 = pools(VW, VH)
        LE.debugNoLights, Lum.EMIT.on = true, false
        render()
        LE.debugNoLights, Lum.EMIT.on = false, true
        local offD = cv:newImageData()
        local gain = tonumber(os.getenv("LUZ_GAIN") or "") or 6
        offD:mapPixel(function(px, py, r, g, b)
            local r1, g1, b1 = onD:getPixel(px, py)
            return math.min(1, math.max(0, r1 - r) * gain), math.min(1, math.max(0, g1 - g) * gain),
                math.min(1, math.max(0, b1 - b) * gain), 1
        end)
        writePng(offD, base .. "_so_luz.png")
        local diffCv = love.graphics.newImage(offD)
        diffCv:setFilter("nearest", "nearest")
        M._diffImg = diffCv
        fakeT = 500
        render()
        local list = list0
        local k = VH / 1080
        for pi = 1, math.min(2, #list) do
            local p = list[pi]
            local ex = p.x + p.r * 0.82
            local w2 = math.floor(math.min(VW * 0.4, p.r * 1.25))
            local h2 = math.floor(math.max(60 * k, p.r * p.sy * 2.6))
            crop(cv, p.x - p.r * 0.05, p.y - h2 / 2, w2, h2, 2, string.format("%s_poca%d_2x.png", base, pi))
            local w4, h4 = math.floor(200 * k), math.floor(110 * k)
            crop(cv, ex - w4 / 2, p.y - h4 / 2, w4, h4, 4, string.format("%s_poca%d_borda_4x.png", base, pi))
            crop(M._diffImg, ex - w4 / 2, p.y - h4 / 2, w4, h4, 4, string.format("%s_poca%d_borda_4x_so_luz.png", base, pi))
            print(string.format("[ok] %s poca%d x=%.0f y=%.0f r=%.0f sy=%.2f", base, pi, p.x, p.y, p.r, p.sy))
        end
        if #list == 0 then print("[ok] " .. base .. " sem poca no quadro") end
    end)
    love.timer.getTime = realTime
    restore()
    cv:release()
    collectgarbage()
    if not ok then error(err) end
end

function M.run(arg)
    io.stdout:setvbuf("line")
    local label, res, acts = (arg or ""):match("^([%w_]*):?([%dx]*):?([%d,]*)$")
    label = (label and label ~= "") and label or "depois"
    local resList = M.RES
    if res and res ~= "" then
        local rw, rh = res:match("^(%d+)x(%d+)$")
        resList = { { tonumber(rw), tonumber(rh) } }
    end
    local actList = {}
    for a in (acts or ""):gmatch("%d") do actList[#actList + 1] = tonumber(a) end
    if #actList == 0 then actList = { 1, 2, 3, 4, 5, 6 } end
    local tod = tonumber(os.getenv("LUZ_TOD") or "") or 1.0
    local seed = tonumber(os.getenv("LUZ_SEED") or "") or 0xC0FFEE
    for _, r in ipairs(resList) do
        local dir = outDir(label .. "/" .. r[1] .. "x" .. r[2])
        for _, act in ipairs(actList) do
            M.capture(act, r[1], r[2], dir, "ato" .. act, tod, seed)
        end
    end
    return true
end

return M
