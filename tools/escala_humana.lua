local M = {}

local VW, VH = (os.getenv("ESCALA_VIRTUAL") or ""):match("^(%d+)x(%d+)$")
VW, VH = tonumber(VW) or 1920, tonumber(VH) or 1080
local TOPBAR = 80
local REL_CREST, T_POW = 26, 1.35

local function tOf(rel)
    local t = 1 - rel / REL_CREST
    if t < 0 then return nil end
    return math.min(1, t) ^ T_POW
end

local function virtualCanvas()
    local cv = love.graphics.newCanvas(VW, VH)
    love.graphics.getWidth = function() return VW end
    love.graphics.getHeight = function() return VH end
    love.graphics.getDimensions = function() return VW, VH end
    return cv
end

local function hitRows(WorldRoad, y0)
    local rows = {}
    for _, he in ipairs(WorldRoad._hitScene) do
        local p = he.ref
        local rel = p and p.z and (p.z - WorldRoad._camZ) or nil
        local t = rel and tOf(rel) or -1
        rows[#rows + 1] = string.format(
            "prop %-9s t=%5.2f rel=%5.1f big=%4.2f s=%5.2f h=%4.0f w=%4.0f base=%4.0f x=%4.0f box=%d,%d,%d,%d",
            he.kind, t or -1, rel or -1, p and p.big or 1, he.s or -1,
            he.y2 - he.y1, he.x2 - he.x1, he.y2 - (y0 or 0), (he.x1 + he.x2) / 2,
            he.x1, he.y1, he.x2, he.y2)
    end
    table.sort(rows)
    return rows
end

local function castleRow(WorldRoad, y0)
    local c = WorldRoad._castleTop
    if not c or not c.h then return "castle none" end
    return string.format("castle progress=%.2f h=%4.0f w=%4.0f base=%4.0f x=%4.0f",
        c.progress or -1, c.h, c.w, (c.baseY or 0) - (y0 or 0), c.cx or 0)
end

local function battle(act, tod, spriteId)
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

    local game = Game:new()
    game:startNewRun("warrior")
    game:startGame()
    local run = game.runManager.currentRun
    run.actNumber = act
    run.floorInAct = tonumber(os.getenv("ESCALA_FLOOR") or "") or 3
    run.currentNode = { type = "battle" }
    local sid = spriteId or EnemyRenderer.resolveSpriteId(act, "battle")
    game.enemy = EnemyRoster.spawn(Enemy, sid, ActSystem.getEnemyStats(act, run.floorInAct, "battle"))
    game.enemy.isBoss = false
    _G.game = game
    local topBar = TopBar:new()
    topBar:setGame(game)
    local gameUI = GameUI:new()
    local playButton = Button:new(VW * 0.80, VH * 0.80, 150, 46, "Jogar")
    GameplayScene.init({ game = game, topBar = topBar, gameUI = gameUI, playButton = playButton })
    if game.messageSystem then game.messageSystem.messages = {} end

    local seed = tonumber(os.getenv("ESCALA_SEED") or "")
    if seed then
        WorldRoad.restoreProgress(act, 3)
        WorldRoad._rng:setSeed(seed)
        WorldRoad._props = {}
    end
    WorldRoad.setBiome(act)
    WorldRoad.setTimeOfDay(tod, true)
    for _ = 1, 90 do
        WorldRoad.update(1 / 30)
        EnemyRenderer.update(1 / 30)
    end
    local bbox
    local origDraw = EnemyRenderer.draw
    EnemyRenderer.draw = function(...)
        local b = origDraw(...)
        bbox = b
        return b
    end
    local ShadowEngine = require("engine.ShadowEngine")
    local shadowLog = {}
    local origEnd = ShadowEngine.endFrame
    ShadowEngine.endFrame = function(...)
        shadowLog[#shadowLog + 1] = ShadowEngine.stats.queued or 0
        return origEnd(...)
    end
    local silDrawn = 0
    local origSil = ShadowEngine.silhouette
    ShadowEngine.silhouette = function(...)
        local r = origSil(...)
        if r then silDrawn = silDrawn + 1 end
        return r
    end
    local cv = virtualCanvas()
    love.graphics.setCanvas(cv)
    love.graphics.clear(0, 0, 0, 1)
    GameplayScene.draw()
    love.graphics.setCanvas()
    EnemyRenderer.draw = origDraw
    ShadowEngine.endFrame = origEnd
    ShadowEngine.silhouette = origSil

    local areaH = VH - (topBar.height or TOPBAR)
    local sizeK = WorldRoad.battleSizeK() * WorldRoad.enemyScreenK(areaH)
    local rows = {}
    rows[#rows + 1] = string.format("scene battle act=%d sprite=%s tod=%.2f rel=%.2f t=%.3f sizeK=%.3f",
        act, sid, tod, WorldRoad.BATTLE_REL, tOf(WorldRoad.BATTLE_REL) or -1, sizeK)
    if bbox then
        rows[#rows + 1] = string.format("enemy h=%4.0f visible=%4.0f w=%4.0f base=%4.0f x=%4.0f top=%4.0f",
            bbox.height, 250 * sizeK, bbox.width, bbox.bottomY - (topBar.height or TOPBAR), bbox.cx, bbox.topY)
    else
        rows[#rows + 1] = "enemy none"
    end
    rows[#rows + 1] = castleRow(WorldRoad, topBar.height or TOPBAR)
    rows[#rows + 1] = string.format("shadows endFrame queued=%s silhouettes=%d bands=%d",
        table.concat(shadowLog, ","), silDrawn, ShadowEngine.stats.bands or 0)
    for _, r in ipairs(hitRows(WorldRoad, topBar.height or TOPBAR)) do rows[#rows + 1] = r end
    return cv, rows
end

local function world(scene, tod, bio)
    bio = bio or 1
    require("src.ui.PixelCanvas").enableNearest()
    local WorldRoad = require("src.ui.WorldRoad")
    local cv = virtualCanvas()
    local width, height = VW, VH
    local topBarH = TOPBAR
    WorldRoad.clearCache()
    WorldRoad.resetRun()
    love.math.setRandomSeed(7)
    WorldRoad.setBiome(bio)
    WorldRoad._blend = nil
    WorldRoad._prevBiomeIndex = nil
    WorldRoad._birdTimer = 1e9
    local function frame()
        love.graphics.setCanvas(cv)
        love.graphics.clear(0, 0, 0, 1)
        WorldRoad.draw(0, topBarH, width, height - topBarH, bio)
        WorldRoad.drawOverlays(0, topBarH, width, height - topBarH)
        love.graphics.setColor(0.1, 0.08, 0.06, 1)
        love.graphics.rectangle("fill", 0, 0, width, topBarH)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setCanvas()
    end
    local function tick(n, draw)
        for _ = 1, n do
            WorldRoad.update(1 / 30)
            if draw then frame() end
        end
    end
    if scene == "castelo" then
        WorldRoad._segBase = 0
        WorldRoad._camZ = WorldRoad.TRAVEL_DISTANCE * 8 * 0.85
        tick(30, false)
    elseif scene == "viagem" then
        local EnemyRenderer = require("src.ui.EnemyRenderer")
        WorldRoad._camZ = 5.5
        tick(30, false)
        WorldRoad.travel({
            encounter = EnemyRenderer.getEncounterBillboard({ spriteId = "cursed_scarecrow" }),
        })
        tick(70, true)
    else
        WorldRoad._camZ = 5.5
        tick(30, false)
        require("src.i18n.I18n").init()
        require("src.i18n.I18n").setLocale("en", true)
        local MM = require("src.systems.MapManager")
        local nodes = {}
        for i, ty in ipairs({ "battle", "rest", "shop" }) do
            nodes[i] = { type = ty, label = MM.labelFor(ty), desc = MM.descFor(ty) }
        end
        WorldRoad.showFork(nodes, function() end)
        tick(20, true)
        if scene == "fork" then
            if WorldRoad._fork then WorldRoad._fork.hover = 2 end
        else
            local f = WorldRoad._fork
            local b = f and f.markBoxes and f.markBoxes[2]
            if b then WorldRoad.forkMousePressed((b.x1 + b.x2) / 2, (b.y1 + b.y2) / 2) end
            tick(85, true)
        end
    end
    WorldRoad._blend = nil
    WorldRoad._prevBiomeIndex = nil
    WorldRoad.setTimeOfDay(tod, true)
    WorldRoad.update(1 / 30)
    local ShadowEngine = require("engine.ShadowEngine")
    local shadowLog = {}
    local origEnd = ShadowEngine.endFrame
    ShadowEngine.endFrame = function(...)
        shadowLog[#shadowLog + 1] = ShadowEngine.stats.queued or 0
        return origEnd(...)
    end
    frame()
    ShadowEngine.endFrame = origEnd
    local rows = {}
    rows[#rows + 1] = string.format("scene %s bio=%d tod=%.2f camZ=%.1f", scene, bio, tod, WorldRoad._camZ)
    rows[#rows + 1] = castleRow(WorldRoad, topBarH)
    rows[#rows + 1] = string.format("shadows endFrame queued=%s bands=%d luma=%.2f",
        table.concat(shadowLog, ","), ShadowEngine.stats.bands or 0,
        require("engine.LightEngine").ambientLuma())
    local f = WorldRoad._fork
    if f and f._geo then
        for i = 1, (f.n or 0) do
            local ge = f._geo[i]
            if ge then
                local key = f.nodes and f.nodes[i] and f.nodes[i].type or "?"
                rows[#rows + 1] = string.format("mark %-7s h=%4.0f w=%4.0f base=%4.0f x=%4.0f",
                    tostring(key), ge.ih * ge.s, ge.iw * ge.s, ge.py - topBarH, ge.px)
            end
        end
    end
    local lm = WorldRoad._lmMark
    if lm and lm.h and lm.drawn then
        rows[#rows + 1] = string.format("landmark %-16s t=%5.2f h=%4.0f w=%4.0f base=%4.0f x=%4.0f",
            lm.lm and lm.lm.key or "?", lm.t or -1, lm.h, lm.w, (lm.py or 0) - topBarH, lm.px or 0)
    end
    for _, r in ipairs(hitRows(WorldRoad, topBarH)) do rows[#rows + 1] = r end
    return cv, rows
end

function M.run(arg)
    local label, scene = tostring(arg or "captura:b1"):match("^([^:]+):(.+)$")
    if not label then label, scene = "captura", tostring(arg or "b1") end
    local tod = tonumber(os.getenv("ESCALA_TOD") or "") or 0.65
    local realTime = love.timer.getTime
    love.timer.getTime = function() return 100 end
    if os.getenv("ESCALA_NOMASK") == "1" then require("engine.ShadowEngine").MASK = false end
    local tdLift = tonumber(os.getenv("ESCALA_TDLIFT") or "")
    if tdLift then require("src.data.scene_integration").fields.grade.treeDepth.lift = tdLift end
    if os.getenv("ESCALA_NOGATE") == "1" then require("engine.LuminaireEngine").dayK = function() return 1 end end
    if os.getenv("ESCALA_ONLY_LANTERN") == "1" then
        local SE = require("engine.ShadowEngine")
        local origQ = SE.queue
        SE.queue = function(img, ...)
            if not img or img:getWidth() ~= 72 or img:getHeight() ~= 72 then return true end
            return origQ(img, ...)
        end
        SE.silhouette = function() return true end
    end
    if os.getenv("ESCALA_NOSHADOW") == "1" then
        local SE = require("engine.ShadowEngine")
        local orig = SE.setAlphaK
        SE.setAlphaK = function() orig(0) end
    end
    local cv, rows
    local act = scene:match("^b(%d)$")
    if act then
        act = tonumber(act)
        cv, rows = battle(act, tod, act == 1 and "cursed_scarecrow" or nil)
    else
        local sc, bio = scene:match("^(%a+)(%d*)$")
        cv, rows = world(sc, tod, tonumber(bio) or 1)
    end
    love.timer.getTime = realTime
    local dir = "escala_humana/" .. label
    love.filesystem.createDirectory(dir)
    local base = string.format("%s/%s_tod%02d", dir, scene, math.floor(tod * 100 + 0.5))
    if VW ~= 1920 or VH ~= 1080 then base = base .. "_" .. VW .. "x" .. VH end
    cv:newImageData():encode("png", base .. ".png")
    love.filesystem.write(base .. ".txt", table.concat(rows, "\n") .. "\n")
    for _, r in ipairs(rows) do print(r) end
    print(love.filesystem.getSaveDirectory() .. "/" .. base .. ".png")
    love.event.quit()
    return true
end

return M
