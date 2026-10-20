local M = {}

local VW, VH = (os.getenv("REVISAO_VIRTUAL") or ""):match("^(%d+)x(%d+)$")
VW, VH = tonumber(VW) or 1920, tonumber(VH) or 1080
local TOPBAR = 80
local REL_CREST, T_POW = 26, 1.35

local FORKS = {
    a = { "battle", "elite", "shop" },
    b = { "event", "rest", "battle" },
}
local LANDMARKS = {
    battle = { "a", 1 }, elite = { "a", 2 }, shop = { "a", 3 },
    event = { "b", 1 }, rest = { "b", 2 },
}

local cv
local dir
local saved = {}
local clutterLog = {}

local function hookClutter()
    local GC = require("engine.GroundClutter")
    if GC._revisaoHook then return end
    GC._revisaoHook = true
    local orig = GC.draw
    GC.draw = function(p, env)
        local img = p.img
        if img then
            local w, h = img:getWidth() * p.s, img:getHeight() * p.s
            clutterLog[#clutterLog + 1] = string.format("clutter %s %s t=%.2f s=%.2f box=%d,%d,%d,%d",
                p.e and p.e.kind or "?", p.bid or "-", p.t or -1, p.s or -1,
                math.floor(p.px - w / 2), math.floor(p.py - h), math.floor(p.px + w / 2), math.floor(p.py))
        end
        return orig(p, env)
    end
end

local function tOf(rel)
    local t = 1 - rel / REL_CREST
    if t < 0 then return nil end
    return math.min(1, t) ^ T_POW
end

local function canvas()
    if cv then return cv end
    cv = love.graphics.newCanvas(VW, VH)
    love.graphics.getWidth = function() return VW end
    love.graphics.getHeight = function() return VH end
    love.graphics.getDimensions = function() return VW, VH end
    return cv
end

local function hitRows(WorldRoad, rows)
    for _, he in ipairs(WorldRoad._hitScene or {}) do
        local p = he.ref
        local rel = p and p.z and (p.z - WorldRoad._camZ) or nil
        rows[#rows + 1] = string.format("prop %s %s t=%.2f s=%.2f box=%d,%d,%d,%d",
            he.kind or "?", tostring(p and p.sprite or p and p.variant or "-"),
            rel and tOf(rel) or -1, he.s or -1,
            math.floor(he.x1), math.floor(he.y1), math.floor(he.x2), math.floor(he.y2))
    end
end

local function extraRows(WorldRoad, rows)
    local c = WorldRoad._castleTop
    if c and c.h then
        rows[#rows + 1] = string.format("castle - t=%.2f s=1 box=%d,%d,%d,%d", c.progress or -1,
            math.floor((c.cx or 0) - c.w / 2), math.floor((c.baseY or 0) - c.h),
            math.floor((c.cx or 0) + c.w / 2), math.floor(c.baseY or 0))
    end
    local f = WorldRoad._fork
    if f and f._geo then
        for i = 1, (f.n or 0) do
            local ge = f._geo[i]
            if ge and ge.ih then
                local key = f.nodes and f.nodes[i] and f.nodes[i].type or "?"
                local w, h = ge.iw * ge.s, ge.ih * ge.s
                rows[#rows + 1] = string.format("mark %s - t=0 s=%.2f box=%d,%d,%d,%d", key, ge.s,
                    math.floor(ge.px - w / 2), math.floor(ge.py - h), math.floor(ge.px + w / 2), math.floor(ge.py))
            end
        end
    end
    local lm = WorldRoad._lmMark
    if lm and lm.h and lm.drawn then
        rows[#rows + 1] = string.format("landmark %s - t=%.2f s=1 box=%d,%d,%d,%d",
            lm.lm and lm.lm.key or "?", lm.t or -1,
            math.floor((lm.px or 0) - lm.w / 2), math.floor((lm.py or 0) - lm.h),
            math.floor((lm.px or 0) + lm.w / 2), math.floor(lm.py or 0))
    end
    hitRows(WorldRoad, rows)
    for _, r in ipairs(clutterLog) do rows[#rows + 1] = r end
end

local function save(name, rows)
    local base = dir .. "/" .. name
    local data = cv:newImageData()
    data:encode("png", base .. ".png")
    data:release()
    love.filesystem.write(base .. ".txt", table.concat(rows or {}, "\n") .. "\n")
    saved[#saved + 1] = base
end

local function onlyKinds(bio)
    local only = os.getenv("REVISAO_ONLY")
    if not only or only == "" then return end
    local b = require("src.data.biomes")[bio]
    local w = {}
    for k in only:gmatch("[^,]+") do if b.propWeights[k] then w[k] = b.propWeights[k] * 4 end end
    for k, v in pairs(b.propWeights) do
        if v and os.getenv("REVISAO_STRICT") ~= "1" and (k == "tree" or k == "pine" or k == "deadtree") then w[k] = v end
    end
    b.propWeights = w
end

local function worldSetup(bio)
    local WorldRoad = require("src.ui.WorldRoad")
    onlyKinds(bio)
    canvas()
    WorldRoad.clearCache()
    WorldRoad.resetRun()
    love.math.setRandomSeed(7)
    WorldRoad.setBiome(bio)
    WorldRoad._blend = nil
    WorldRoad._prevBiomeIndex = nil
    WorldRoad._birdTimer = 1e9
    local function frame()
        for i = #clutterLog, 1, -1 do clutterLog[i] = nil end
        love.graphics.setCanvas(cv)
        love.graphics.clear(0, 0, 0, 1)
        WorldRoad.draw(0, TOPBAR, VW, VH - TOPBAR, bio)
        WorldRoad.drawOverlays(0, TOPBAR, VW, VH - TOPBAR)
        love.graphics.setColor(0.1, 0.08, 0.06, 1)
        love.graphics.rectangle("fill", 0, 0, VW, TOPBAR)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setCanvas()
    end
    local function tick(n, draw)
        for _ = 1, n do
            WorldRoad.update(1 / 30)
            if draw then frame() end
        end
    end
    return WorldRoad, frame, tick
end

local function openFork(WorldRoad, tick, which)
    local I18n = require("src.i18n.I18n")
    I18n.init()
    I18n.setLocale("en", true)
    local MM = require("src.systems.MapManager")
    local nodes = {}
    for i, ty in ipairs(FORKS[which]) do
        nodes[i] = { type = ty, label = MM.labelFor(ty), desc = MM.descFor(ty) }
    end
    WorldRoad._camZ = 5.5
    tick(30, false)
    WorldRoad.showFork(nodes, function() end)
    tick(20, true)
end

local function settle(WorldRoad, tod, frame)
    WorldRoad._blend = nil
    WorldRoad._prevBiomeIndex = nil
    WorldRoad.setTimeOfDay(tod, true)
    WorldRoad.update(1 / 30)
    frame()
end

local function shotFork(bio, which, tod)
    local WorldRoad, frame, tick = worldSetup(bio)
    openFork(WorldRoad, tick, which)
    if WorldRoad._fork then WorldRoad._fork.hover = nil end
    settle(WorldRoad, tod, frame)
    local rows = {}
    extraRows(WorldRoad, rows)
    save(string.format("fork%s_tod%02d", which, math.floor(tod * 100 + 0.5)), rows)
end

local function clickMark(WorldRoad, idx)
    local f = WorldRoad._fork
    local b = f and f.markBoxes and f.markBoxes[idx]
    if b then WorldRoad.forkMousePressed((b.x1 + b.x2) / 2, (b.y1 + b.y2) / 2) end
end

local function shotLandmark(bio, kind, tod)
    local WorldRoad, frame, tick = worldSetup(bio)
    local spec = LANDMARKS[kind]
    openFork(WorldRoad, tick, spec[1])
    clickMark(WorldRoad, spec[2])
    tick(85, true)
    settle(WorldRoad, tod, frame)
    local rows = {}
    extraRows(WorldRoad, rows)
    save(string.format("lm_%s_tod%02d", kind, math.floor(tod * 100 + 0.5)), rows)
end

local function shotTravel(bio, tod)
    local WorldRoad, frame, tick = worldSetup(bio)
    local EnemyRenderer = require("src.ui.EnemyRenderer")
    openFork(WorldRoad, tick, "a")
    WorldRoad.setTimeOfDay(tod, true)
    clickMark(WorldRoad, 1)
    local n = 0
    for i = 1, 80 do
        tick(1, true)
        if i % 16 == 0 then
            n = n + 1
            local rows = {}
            extraRows(WorldRoad, rows)
            save(string.format("viagem_%02d", n), rows)
        end
    end
    WorldRoad.travel({
        encounter = EnemyRenderer.getEncounterBillboard({
            spriteId = EnemyRenderer.resolveSpriteId(bio, "battle") }),
    })
    local step = tonumber(os.getenv("REVISAO_STEP") or "") or 14
    for i = 1, 140 do
        tick(1, true)
        if i % step == 0 then
            n = n + 1
            local rows = {}
            extraRows(WorldRoad, rows)
            save(string.format("viagem_%02d", n), rows)
        end
        if not WorldRoad.isTraveling() and i > 20 then break end
    end
    frame()
    n = n + 1
    local rows = {}
    extraRows(WorldRoad, rows)
    save(string.format("viagem_%02d", n), rows)
end

local function shotCastle(bio, tod)
    local WorldRoad, frame, tick = worldSetup(bio)
    WorldRoad._segBase = 0
    WorldRoad._camZ = WorldRoad.TRAVEL_DISTANCE * 8 * 0.85
    tick(30, false)
    settle(WorldRoad, tod, frame)
    local rows = {}
    extraRows(WorldRoad, rows)
    save(string.format("castelo_tod%02d", math.floor(tod * 100 + 0.5)), rows)
end

local function shotBattle(act, nodeType, tod)
    local I18n = require("src.i18n.I18n")
    I18n.init()
    I18n.setLocale("en", true)
    require("src.ui.PixelCanvas").enableNearest()
    canvas()
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
    run.floorInAct = 3
    run.currentNode = { type = nodeType }
    local sid = EnemyRenderer.resolveSpriteId(act, nodeType)
    game.enemy = EnemyRoster.spawn(Enemy, sid, ActSystem.getEnemyStats(act, 3, nodeType))
    game.enemy.isBoss = false
    _G.game = game
    local topBar = TopBar:new()
    topBar:setGame(game)
    local gameUI = GameUI:new()
    local playButton = Button:new(VW * 0.80, VH * 0.80, 150, 46, "Jogar")
    GameplayScene.init({ game = game, topBar = topBar, gameUI = gameUI, playButton = playButton })
    if game.messageSystem then game.messageSystem.messages = {} end
    WorldRoad.clearCache()
    WorldRoad.restoreProgress(act, 3)
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
    for i = #clutterLog, 1, -1 do clutterLog[i] = nil end
    love.graphics.setCanvas(cv)
    love.graphics.clear(0, 0, 0, 1)
    GameplayScene.draw()
    love.graphics.setCanvas()
    EnemyRenderer.draw = origDraw
    local rows = {}
    if bbox then
        rows[#rows + 1] = string.format("enemy %s t=0 s=1 box=%d,%d,%d,%d", sid,
            math.floor(bbox.cx - bbox.width / 2), math.floor(bbox.topY),
            math.floor(bbox.cx + bbox.width / 2), math.floor(bbox.bottomY))
    end
    extraRows(WorldRoad, rows)
    save(string.format("%s_tod%02d", nodeType, math.floor(tod * 100 + 0.5)), rows)
end

function M.run(arg)
    local act, what = tostring(arg or "1"):match("^(%d)[:]?(.*)$")
    act = tonumber(act) or 1
    if what == nil or what == "" then what = "all" end
    dir = string.format("revisao_cenas/ato%d/%s", act, os.getenv("REVISAO_TAG") or "raw")
    love.filesystem.createDirectory(dir)
    require("src.ui.PixelCanvas").enableNearest()
    hookClutter()
    local realTime = love.timer.getTime
    love.timer.getTime = function() return 100 end
    local function want(k) return what == "all" or what == k end
    if want("fork") then
        for _, w in ipairs({ "a", "b" }) do
            for _, tod in ipairs({ 0.3, 0.65, 0.85 }) do shotFork(act, w, tod) end
        end
    end
    if want("lm") then
        for _, k in ipairs({ "battle", "elite", "shop", "event", "rest" }) do
            for _, tod in ipairs({ 0.65, 0.85 }) do shotLandmark(act, k, tod) end
        end
    end
    if want("castelo") then
        for _, tod in ipairs({ 0.65, 0.85 }) do shotCastle(act, tod) end
    end
    if want("viagem") then shotTravel(act, 0.65) end
    if want("batalha") then
        for _, nt in ipairs({ "battle", "elite" }) do
            for _, tod in ipairs({ 0.65, 0.85 }) do shotBattle(act, nt, tod) end
        end
    end
    love.timer.getTime = realTime
    print(love.filesystem.getSaveDirectory() .. "/" .. dir .. " " .. #saved)
    love.event.quit()
    return true
end

return M
