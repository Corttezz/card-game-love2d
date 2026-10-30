local M = {}

local VW, VH = 1920, 1080
do
    local rw, rh = (os.getenv("CONT_RES") or ""):match("^(%d+)x(%d+)$")
    if rw then VW, VH = tonumber(rw), tonumber(rh) end
end
M.ROAD_GAP_TOL = 0.03
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

M.SCENARIOS = {
    path1 = { last = { "battle", "rest", "shop" }, after = { "battle", "rest", "shop" } },
    path2 = { landmarks = { { { "shop", "event" }, 1 } }, last = { "battle", "event", "rest" }, after = { "shop", "event" } },
    path3 = { landmarks = { { { "battle", "rest", "shop" }, 3 } }, last = { "battle", "rest", "shop" }, after = { "rest", "event" } },
    lm2 = { landmarks = { { { "rest", "shop" }, 1 }, { { "event", "shop" }, 2 } }, last = { "battle", "rest", "shop" }, after = { "battle", "shop" } },
    resume = { resume = true, last = { "battle", "shop", "event" }, after = { "battle", "rest", "shop" } },
    resumefork = { resume = true, forkNow = { "battle", "event", "shop" } },
}

function M.capture(act, seed, scenario, saveDir, creature)
    local I18n = require("src.i18n.I18n")
    I18n.init()
    I18n.setLocale("en", true)
    require("src.ui.PixelCanvas").enableNearest()
    local Game = require("src.core.Game")
    local GameplayScene = require("src.scenes.GameplayScene")
    local EnemyRenderer = require("src.ui.EnemyRenderer")
    local WorldRoad = require("src.ui.WorldRoad")
    local ShadowEngine = require("engine.ShadowEngine")
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
    local floor = (scenario == "castle") and 8 or 3

    local game = Game:new()
    game:startNewRun("warrior")
    local Rng = require("src.systems.Rng")
    Rng.setActive(Rng.new(seed))
    game:startGame()
    local run = game.runManager.currentRun
    run.actNumber = act
    run.floorInAct = floor
    run.currentNode = { type = (creature and creature.node) or "battle" }
    local function spawn()
        local sid = (creature and creature.id) or EnemyRenderer.resolveSpriteId(act, "battle")
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
    if scenario ~= "castle" then WorldRoad.planStop(WorldRoad._camZ + WorldRoad.TRAVEL_DISTANCE, true) end
    for _ = 1, 30 do WorldRoad.update(DT); EnemyRenderer.update(DT) end
    love.graphics.setCanvas(cv)
    GameplayScene.draw()
    love.graphics.setCanvas()

    local log = { lums = {}, shadow = {}, body = {}, frames = 0, phase = {}, cover = {} }
    local LEc = require("engine.LuminaireEngine")
    local font13 = require("src.ui.FontManager").getFont(13)
    M.NEAR_BAND = { -3, 13 }
    log.presence = {}
    local function nearPosts()
        local n = 0
        for _, he in ipairs(WorldRoad._hitScene) do
            local q = he.ref
            local d = q and LEc.def(q.bid, q.kind)
            local rel = q and q.z and q.z - WorldRoad._camZ
            if d and d.roadside and rel and rel >= M.NEAR_BAND[1] and rel <= M.NEAR_BAND[2]
               and he.x2 > 0 and he.x1 < VW and he.y2 > 0 and he.y1 < VH then n = n + 1 end
        end
        return n
    end
    log.road = {}
    local function checkCover(frame, phase)
        for _, he in ipairs(WorldRoad._hitScene) do
            local q = he.ref
            local d = q and q.z and LEc.def(q.bid, q.kind)
            if d and d.roadside and not log.road[q.uid or 0] and not (WorldRoad._fork and WorldRoad._fork.converge) then
                local on, branch = WorldRoad._postBaseOnRoad(q)
                if on then
                    log.road[q.uid or 0] = { uid = q.uid or 0, kind = q.kind, frame = frame, phase = phase,
                        rel = q.z - WorldRoad._camZ, branch = branch, x = he.x1, y = he.y2 }
                end
            end
        end
        local f = WorldRoad._fork
        if f and not f.converge and phase == "fork" then
            local key = "fork@" .. string.format("%.1f", f.markZ)
            log.presence[key] = math.max(log.presence[key] or 0, nearPosts())
        elseif not f and phase == "battle" then
            log.presence.battle = math.max(log.presence.battle or 0, nearPosts())
        elseif not f and phase == "arrival" and not WorldRoad._travel then
            local key = "arrival@" .. string.format("%.1f", WorldRoad._camZ)
            log.presence[key] = math.max(log.presence[key] or 0, nearPosts())
        end
        local lm = WorldRoad._lmMark
        if not f and WorldRoad._landmark and lm and lm.lm == WorldRoad._landmark and lm.px and not WorldRoad._travel then
            for _, he in ipairs(WorldRoad._hitScene) do
                local q = he.ref
                local d = q and q.z and LEc.def(q.bid, q.kind)
                if d and d.roadside and q.z - WorldRoad._camZ < lm.rel
                   and he.x1 < lm.px + lm.w * 0.5 and he.x2 > lm.px - lm.w * 0.5
                   and he.y1 < lm.py and he.y2 > lm.py - lm.h then
                    log.cover[#log.cover + 1] = { uid = q.uid or 0, kind = q.kind, frame = frame, mark = 0,
                        phase = "landmark", rel = q.z - WorldRoad._camZ, x = he.x1, y = he.y1 }
                end
            end
        end
        if not f or not f._geo then return end
        local relM = f.markZ - WorldRoad._camZ
        for i = 1, f.n do
            local geo = f._geo[i]
            if geo and geo.aMul > 0.5 and not f.converge then
                local label = WorldRoad.forkLabel(f.nodes[i]) or ""
                local hw = math.max(geo.iw * geo.s * 0.5, (font13:getWidth(label) + 16) * 0.5)
                local top = geo.py - geo.ih * geo.s - 26
                for _, he in ipairs(WorldRoad._hitScene) do
                    local q = he.ref
                    local d = q and LEc.def(q.bid, q.kind)
                    if d and d.roadside and q.z - WorldRoad._camZ < relM
                       and he.x1 < geo.px + hw and he.x2 > geo.px - hw and he.y1 < geo.py and he.y2 > top then
                        log.cover[#log.cover + 1] = { uid = q.uid or 0, kind = q.kind, frame = frame, mark = i,
                            phase = phase, rel = q.z - WorldRoad._camZ, x = he.x1, y = he.y1 }
                    end
                end
            end
        end
    end
    local frame, phase = 0, "battle"
    local inEnemy = false
    local origDraw = EnemyRenderer.draw
    EnemyRenderer.draw = function(...)
        inEnemy = true
        local r = origDraw(...)
        inEnemy = false
        local lf = EnemyRenderer.getLastFoot()
        if lf and phase == "arrival" or (lf and phase == "travel" and not WorldRoad._travel) then
            log.body[frame] = { x = lf.drawX, y = lf.drawY - EnemyRenderer.getArrivalOffset(), src = "battle", phase = phase }
            if not log.firstBattleFrame then log.firstBattleFrame = lf.frame end
        end
        return r
    end
    log.anchor = {}
    local EE = require("src.ui.EnemyEntrance")
    EE._trace = function(p, px, py, t, s, a)
        local A = log.anchor[p.uid]
        if not A then
            local src = p.front and p.ref or p
            A = { name = (src and src.name or "?") .. (p.front and "_frente" or ""), f = {} }
            log.anchor[p.uid] = A
        end
        A.f[frame] = { x = px, y = py, t = t, s = s, a = a, phase = phase }
    end
    local origSil = ShadowEngine.silhouette
    ShadowEngine.silhouette = function(fx, fy, o, fn)
        local src = inEnemy and "battle" or (WorldRoad._encounter and "encounter") or nil
        if src and o then
            log.shadow[frame] = {
                src = src, x = fx, y = fy,
                len = (o.lenK or 1) * (o.contentH or 0),
                wid = (o.widthK or 1) * (o.smear or 0),
                a = o.alphaK or 1, phase = phase,
            }
        end
        return origSil(fx, fy, o, fn)
    end
    WorldRoad._traceEnemy = function(x, y, src, lat)
        log.body[frame] = { x = x, y = y, src = src, phase = phase, lat = lat }
    end
    local LE = require("engine.LuminaireEngine")
    WorldRoad._trace = function(p, x, y, a, t, src, h, w, roadC, roadHalf)
        local L = log.lums[p.uid]
        if not L then
            local d = LE.def(p.bid, p.kind)
            L = { kind = p.kind, bid = p.bid, side = p.side, f = {}, road = d and d.roadside or false }
            log.lums[p.uid] = L
        end
        local prev = L.f[frame]
        if prev and prev.a >= a and (prev.h or not h) then return end
        L.f[frame] = { x = x, y = y, a = a, t = t, src = src, z = p.z, lane = p.lane,
            phase = phase, cam = WorldRoad._camZ, h = h or (prev and prev.h), w = w or (prev and prev.w),
            gap = (roadC and roadHalf) and ((x - roadC) * p.side - roadHalf) / (2 * roadHalf) or nil }
    end

    local shotN = 0
    local function draw()
        frame = frame + 1
        log.phase[frame] = phase
        love.graphics.setCanvas(cv)
        love.graphics.clear(0, 0, 0, 1)
        GameplayScene.draw()
        love.graphics.setCanvas()
        checkCover(frame, phase)
        love.graphics.present()
        if frame % 30 == 0 then collectgarbage() end
        if saveDir and saveDir.png and (frame % 6 == 0) then
            shotN = shotN + 1
            love.filesystem.createDirectory(saveDir.dir)
            cv:newImageData():encode("png", string.format("%s/f_%03d_%s.png", saveDir.dir, frame, phase))
        end
    end
    local function step(n, cond)
        local i = 0
        while (n and i < n) or (cond and cond()) do
            i = i + 1
            WorldRoad.update(DT)
            EnemyRenderer.update(DT)
            draw()
            if i > 2000 then break end
        end
    end
    local function chooseFork(types, pick, onPick)
        phase = "fork"
        WorldRoad.showFork(nodesFor(types), function(node) onPick(node) end)
        step(25)
        local f = WorldRoad._fork
        local b = f and f.markBoxes and f.markBoxes[pick]
        if b then WorldRoad.forkMousePressed((b.x1 + b.x2) / 2, (b.y1 + b.y2) / 2) end
        phase = "converge"
        step(nil, function() return WorldRoad._fork ~= nil end)
    end
    local function travelBattle()
        spawn()
        phase = "travel"
        log.firstBattleFrame = nil
        local f0 = frame + 1
        WorldRoad.travel({
            encounter = EnemyRenderer.getEncounterBillboard(game.enemy),
            onComplete = function()
                EnemyRenderer.triggerArrival(nil, { still = not EE.endsWithLanding() })
            end,
        })
        step(nil, function() return WorldRoad.isTraveling() end)
        log.travels = log.travels or {}
        log.travels[#log.travels + 1] = { f0 = f0, f1 = frame, secs = (frame - f0 + 1) * DT,
            info = EE._last, firstBattleFrame = nil }
        phase = "arrival"
        step(60)
        log.travels[#log.travels].firstBattleFrame = log.firstBattleFrame
    end

    local ok, err = pcall(function()
        if scenario == "castle" then
            phase = "stop"
            step(10)
            phase = "travel"
            WorldRoad.travel({})
            step(nil, function() return WorldRoad.isTraveling() end)
            phase = "stop"
            step(20)
        elseif scenario == "entradas" then
            travelBattle()
            phase = "battle"
            step(15)
            phase = "fork"
            WorldRoad.showFork(nodesFor({ "shop", "event" }), function() end)
            step(25)
        else
            travelBattle()
            phase = "battle"
            step(15)
            local plan = M.SCENARIOS[scenario] or M.SCENARIOS.path1
            if plan.resume then
                log.cuts = log.cuts or {}
                log.cuts[frame + 1] = true
                WorldRoad.restoreProgress(act, floor + 1)
                WorldRoad._rng:setSeed(seed + 17)
                WorldRoad._props = {}
                WorldRoad.setBiome(act)
                WorldRoad._blend = nil
                if plan.forkNow then
                    phase = "fork"
                    WorldRoad._props = {}
                    WorldRoad.showFork(nodesFor(plan.forkNow), function() end)
                    step(25)
                    return
                end
                phase = "battle"
                step(20)
            end
            for _, lm in ipairs(plan.landmarks or {}) do
                chooseFork(lm[1], lm[2], function() end)
                phase = "landmark"
                step(30)
            end
            chooseFork(plan.last or { "battle", "rest", "shop" }, 1, function() end)
            travelBattle()
            phase = "fork"
            WorldRoad.showFork(nodesFor(plan.after or { "shop", "event" }), function() end)
            step(25)
        end
    end)

    EnemyRenderer.draw = origDraw
    ShadowEngine.silhouette = origSil
    WorldRoad._trace = nil
    WorldRoad._traceEnemy = nil
    EE._trace = nil
    restore()
    love.window.setVSync(vsync)
    cv:release()
    collectgarbage()
    if not ok then error(err) end
    log.frames = frame
    return log
end

local function dist(a, b) return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2) end

function M.analyze(log)
    local LE = require("engine.LuminaireEngine")
    local jumps, pops = {}, {}
    local roads = {}
    for _, L in pairs(log.lums) do
        if L.road then roads[L.bid .. ":" .. L.kind] = true end
    end
    local nRoad = 0
    for _ in pairs(roads) do nRoad = nRoad + 1 end
    if nRoad > 1 then
        pops[#pops + 1] = { uid = 0, kind = "catalogo", frame = 0, how = "dois_postes",
            a0 = nRoad, a1 = 1, phase = "-", at = { t = 0, x = 0, y = 0 } }
    end
    for uid, L in pairs(log.lums) do
        local prevVis = nil
        for k = 1, log.frames do
            local c, p = L.f[k], L.f[k - 1]
            local cv = (c and c.a > 0.02) and true or false
            local pv = (p and p.a > 0.02) and true or false
            if L.road and cv and c.src == "front" and c.a < 0.95 and not L._fade then
                L._fade = true
                pops[#pops + 1] = { uid = uid, kind = L.kind, frame = k, how = "esmaece",
                    a0 = p and p.a or 0, a1 = c.a, phase = c.phase, at = c }
            end
            local want = (require("src.ui.WorldRoad").postLateral(1, L.bid) - 1) / 2
            if L.road and c and c.gap and math.abs(c.gap - want) > M.ROAD_GAP_TOL and c.a > 0.02 and not L._far then
                L._far = true
                pops[#pops + 1] = { uid = uid, kind = L.kind, frame = k, how = "longe",
                    a0 = c.gap, a1 = want, phase = c.phase, at = c }
            end
            if L.road and c and math.abs((c.lane or 0) - LE.ROAD_LANE) > 1e-6 and not L._far then
                L._far = true
                pops[#pops + 1] = { uid = uid, kind = L.kind, frame = k, how = "longe",
                    a0 = c.lane, a1 = LE.ROAD_LANE, phase = c.phase, at = c }
            end
            if cv and pv then
                local d = dist(c, p)
                local dPrev = L.f[k - 2] and L.f[k - 2].a > 0.02 and dist(p, L.f[k - 2]) or nil
                local nx = L.f[k + 1]
                local dNext = nx and nx.a > 0.02 and dist(nx, c) or nil
                local ref = math.max(dPrev or 0, dNext or 0)
                if d > 4 and (dPrev or dNext) and d > 2.5 * ref + 4 then
                    jumps[#jumps + 1] = { uid = uid, kind = L.kind, frame = k, d = d, ref = ref,
                        phase = c.phase, from = p, to = c }
                end
                if math.abs(c.a - p.a) > 0.5 then
                    pops[#pops + 1] = { uid = uid, kind = L.kind, frame = k, how = "alpha",
                        a0 = p.a, a1 = c.a, phase = c.phase, at = c }
                end
            elseif L.road and cv ~= pv and k > 1 then
                local at = cv and c or p
                local onScreen = at.h and at.w and at.x + at.w / 2 > 0 and at.x - at.w / 2 < VW
                    and at.y - at.h < VH and at.src == "front"
                local crest = at.src == "behind" or (at.t or 0) < 0.03
                if (cv and not crest) or (not cv and onScreen) then
                    pops[#pops + 1] = { uid = uid, kind = L.kind, frame = k,
                        how = cv and "surge" or "some", a0 = pv and p.a or 0, a1 = cv and c.a or 0,
                        phase = at.phase, at = at }
                end
            elseif cv ~= pv and k > 1 then
                local at = cv and c or p
                local edge = at.src == "behind" or at.x < -40 or at.x > VW + 40 or at.y > VH + 40
                    or (at.t or 0) < 0.03
                local soft = at.a <= 0.5
                if not edge and not soft then
                    pops[#pops + 1] = { uid = uid, kind = L.kind, frame = k,
                        how = cv and "surge" or "some", a0 = pv and p.a or 0, a1 = cv and c.a or 0,
                        phase = at.phase, at = at }
                end
            end
        end
    end
    log.empty = 0
    for _, n in pairs(log.presence or {}) do
        if n < 1 then log.empty = log.empty + 1 end
    end
    for _, c in pairs(log.road or {}) do
        pops[#pops + 1] = { uid = c.uid, kind = c.kind, frame = c.frame, how = "na_estrada",
            a0 = c.branch or 0, a1 = c.rel, phase = c.phase, at = { t = c.rel, x = c.x, y = c.y } }
    end
    if log.cuts then
        local keep = {}
        for _, pp in ipairs(pops) do if not log.cuts[pp.frame] then keep[#keep + 1] = pp end end
        pops = keep
        local keepJ = {}
        for _, j in ipairs(jumps) do if not log.cuts[j.frame] then keepJ[#keepJ + 1] = j end end
        jumps = keepJ
    end
    local seenCover = {}
    for _, c in ipairs(log.cover or {}) do
        if not seenCover[c.uid] then
            seenCover[c.uid] = true
            pops[#pops + 1] = { uid = c.uid, kind = c.kind, frame = c.frame, how = "cobre",
                a0 = c.mark, a1 = c.rel, phase = c.phase, at = { t = c.rel, x = c.x, y = c.y } }
        end
    end
    local shadowJumps = {}
    for k = 2, log.frames do
        local c, p = log.shadow[k], log.shadow[k - 1]
        if c and p then
            local rl = math.abs(c.len - p.len) / math.max(1, p.len)
            local rw = math.abs(c.wid - p.wid) / math.max(0.01, p.wid)
            local da = math.abs(c.a - p.a)
            local dp = dist(c, p)
            local pp, nx = log.shadow[k - 2], log.shadow[k + 1]
            local ref = math.max(pp and dist(p, pp) or 0, nx and dist(nx, c) or 0)
            if rl > 0.12 or rw > 0.12 or da > 0.12 or (dp > 4 and dp > 2.5 * ref + 4) then
                shadowJumps[#shadowJumps + 1] = { frame = k, src0 = p.src, src1 = c.src,
                    rl = rl, rw = rw, da = da, dp = dp, phase = c.phase }
            end
        elseif (c == nil) ~= (p == nil) and log.phase[k] == "arrival" then
            shadowJumps[#shadowJumps + 1] = { frame = k, src0 = p and p.src or "-",
                src1 = c and c.src or "-", rl = 1, rw = 1, da = 1, dp = 0, phase = log.phase[k] }
        end
    end
    for k = 2, log.frames do
        local c, p = log.body[k], log.body[k - 1]
        if c and p then
            local dp = dist(c, p)
            local pp = log.body[k - 2]
            local ref = pp and dist(p, pp) or 0
            local nx = log.body[k + 1]
            local refN = nx and dist(nx, c) or 0
            local cross = c.src ~= p.src
            local behindCross = cross and (c.src == "behind" or p.src == "behind")
            local tol = cross and 6 or 10
            if not behindCross and dp > tol and dp > 2.5 * math.max(ref, cross and 0 or refN) + tol then
                shadowJumps[#shadowJumps + 1] = { frame = k, src0 = string.format("corpo %s(%.0f,%.0f)", p.src, p.x, p.y),
                    src1 = string.format("%s(%.0f,%.0f)", c.src, c.x, c.y),
                    rl = 0, rw = 0, da = 0, dp = dp, phase = c.phase }
            end
            if c.lat and p.lat then
                local dl = math.abs(c.lat - p.lat)
                local refL = pp and pp.lat and math.abs(p.lat - pp.lat) or 0
                local refLN = nx and nx.lat and math.abs(nx.lat - c.lat) or 0
                if dl > 6 and dl > 2.5 * math.max(refL, refLN) + 6 then
                    shadowJumps[#shadowJumps + 1] = { frame = k, src0 = string.format("lateral %s(%.0f)", p.src, p.lat),
                        src1 = string.format("%s(%.0f)", c.src, c.lat),
                        rl = 0, rw = 0, da = 0, dp = dl, phase = c.phase }
                end
            end
        end
    end
    for uid, A in pairs(log.anchor or {}) do
        local first = nil
        for k = 1, log.frames do
            local c, p = A.f[k], A.f[k - 1]
            if c and not first then
                first = c
                if c.t >= 0.05 then
                    pops[#pops + 1] = { uid = uid, kind = "ancora_" .. A.name, frame = k, how = "surge",
                        a0 = 0, a1 = c.a, phase = c.phase, at = c }
                end
            end
            if c and p and c.a > 0.02 and p.a > 0.02 then
                local d = dist(c, p)
                local pp = A.f[k - 2]
                local ref = pp and pp.a > 0.02 and dist(p, pp) or 0
                local nx = A.f[k + 1]
                local refN = nx and nx.a > 0.02 and dist(nx, c) or 0
                if d > 4 and d > 2.5 * math.max(ref, refN) + 4 then
                    jumps[#jumps + 1] = { uid = uid, kind = "ancora_" .. A.name, frame = k, d = d, ref = ref,
                        phase = c.phase, from = { x = p.x, y = p.y, z = 0, lane = 0, src = "front", t = p.t },
                        to = { x = c.x, y = c.y, z = 0, lane = 0, src = "front", t = c.t } }
                end
                if math.abs(c.a - p.a) > 0.5 then
                    pops[#pops + 1] = { uid = uid, kind = "ancora_" .. A.name, frame = k, how = "alpha",
                        a0 = p.a, a1 = c.a, phase = c.phase, at = c }
                end
            elseif c and p and (c.a > 0.02) ~= (p.a > 0.02) and p.a > 0.5 and c.phase ~= "fork" then
                pops[#pops + 1] = { uid = uid, kind = "ancora_" .. A.name, frame = k, how = "some",
                    a0 = p.a, a1 = c.a, phase = c.phase, at = c }
            end
        end
    end
    local Data = require("src.data.enemy_entrances")
    for _, tr in ipairs(log.travels or {}) do
        local info = tr.info
        local cap = Data.BASE + require("src.ui.EnemyEntrance").maxExtra(info and info.id)
        if tr.secs > cap + 2 * DT + 1e-6 then
            pops[#pops + 1] = { uid = 0, kind = "entrada", frame = tr.f1, how = "longa",
                a0 = tr.secs, a1 = cap, phase = "travel", at = { t = 0, x = 0, y = 0 } }
        end
        if info and info.endFrame1 and tr.firstBattleFrame and tr.firstBattleFrame ~= 1 then
            pops[#pops + 1] = { uid = 0, kind = "entrada", frame = tr.f1 + 1, how = "quadro",
                a0 = tr.firstBattleFrame, a1 = 1, phase = "arrival", at = { t = 0, x = 0, y = 0 } }
        end
    end
    return jumps, pops, shadowJumps
end

local function report(tag, jumps, pops, sh, verbose)
    local rows = {}
    for _, j in ipairs(jumps) do
        rows[#rows + 1] = string.format("  salto  %s uid=%d %-8s f=%d d=%.0fpx (ref %.0f) %s z %.2f->%.2f lane %.2f->%.2f %s->%s t=%.3f (%.0f,%.0f)->(%.0f,%.0f)",
            tag, j.uid, j.kind, j.frame, j.d, j.ref, j.phase, j.from.z, j.to.z, j.from.lane, j.to.lane,
            j.from.src, j.to.src, j.to.t or -1, j.from.x, j.from.y, j.to.x, j.to.y)
    end
    for _, p in ipairs(pops) do
        rows[#rows + 1] = string.format("  %-6s %s uid=%d %-8s f=%d a %.2f->%.2f %s t=%.2f x=%.0f y=%.0f",
            p.how, tag, p.uid, p.kind, p.frame, p.a0, p.a1, p.phase, p.at.t or -1, p.at.x, p.at.y)
    end
    for _, s in ipairs(sh) do
        rows[#rows + 1] = string.format("  sombra %s f=%d %s->%s len %.0f%% wid %.0f%% alpha %.2f pos %.0fpx %s",
            tag, s.frame, s.src0, s.src1, s.rl * 100, s.rw * 100, s.da, s.dp, s.phase)
    end
    if verbose then for _, r in ipairs(rows) do print(r) end end
    return rows
end

local function writeCsv(path, log)
    local out = { "frame,uid,kind,phase,x,y,a,t,z,lane,cam,src" }
    for uid, L in pairs(log.lums) do
        for k = 1, log.frames do
            local c = L.f[k]
            if c then
                out[#out + 1] = string.format("%d,%d,%s,%s,%.1f,%.1f,%.3f,%.3f,%.3f,%.3f,%.3f,%s",
                    k, uid, L.kind, c.phase, c.x, c.y, c.a, c.t or -1, c.z, c.lane, c.cam, c.src)
            end
        end
    end
    for k = 1, log.frames do
        local s = log.shadow[k]
        if s then
            out[#out + 1] = string.format("%d,-1,shadow_%s,%s,%.1f,%.1f,%.3f,%.1f,%.1f,0,0,%s",
                k, s.src, s.phase, s.x, s.y, s.a, s.len, s.wid, s.src)
        end
    end
    love.filesystem.write(path, table.concat(out, "\n"))
end

function M.run(arg)
    io.stdout:setvbuf("line")
    local acts = { 1, 2, 3, 4, 5, 6 }
    local seeds = { 0xC0FFEE, 7331, 90210 }
    local scenarios = { "path1", "path2", "path3", "lm2", "resume", "resumefork", "castle" }
    local saveTag
    if not arg or arg == "" then
        seeds = { seeds[1] }
        scenarios = { "path3" }
    else
        local a, s, sc, sv = arg:match("^(%d*):?(%d*):?(%w*):?(%a*)$")
        if a and a ~= "" then acts = { tonumber(a) } end
        if s and s ~= "" then seeds = { tonumber(s) } end
        if sc and sc ~= "" then scenarios = { sc } end
        if sv ~= "" then saveTag = sv end
    end
    local verbose = os.getenv("CONT_VERBOSE") == "1"
    local total, bad = 0, 0
    local onlyId = os.getenv("CONT_ID")
    local function creaturesFor(act, sc)
        if sc ~= "entradas" then return { false } end
        local out = {}
        for _, r in ipairs(require("tools.entradas").roster()) do
            if r.act == act and (not onlyId or onlyId == "" or r.id == onlyId) then out[#out + 1] = r end
        end
        return out
    end
    for _, act in ipairs(acts) do
        for _, seed in ipairs(seeds) do
            for _, sc in ipairs(scenarios) do
            for _, cr in ipairs(creaturesFor(act, sc)) do
                local tag = string.format("a%d/%s/%d", act, cr and (sc .. "/" .. cr.id) or sc, seed)
                local dir = saveTag and string.format("continuidade/%s/%d_%s_%d", os.getenv("CONT_TAG") or "run", act,
                    cr and (sc .. "_" .. cr.id) or sc, seed) or nil
                if dir then love.filesystem.createDirectory(dir) end
                local log = M.capture(act, seed, sc, dir and { dir = dir, png = saveTag == "png" }, cr or nil)
                if dir then writeCsv(dir .. "/trace.csv", log) end
                local j, p, s = M.analyze(log)
                local n = #j + #p + #s
                total = total + 1
                local nl = 0
                for _ in pairs(log.lums) do nl = nl + 1 end
                if n > 0 then bad = bad + 1 end
                local gmin, gmax = 1, -1
                for _, L in pairs(log.lums) do
                    if L.road then
                        for _, c in pairs(L.f) do
                            if c.gap and c.a > 0.02 then
                                gmin, gmax = math.min(gmin, c.gap), math.max(gmax, c.gap)
                            end
                        end
                    end
                end
                print(string.format("[%s] %s luminarias=%d quadros=%d saltos=%d pops=%d sombra=%d folga_estrada=%.3f..%.3f sem_poste_perto=%d",
                    n == 0 and "ok" or "FAIL", tag, nl, log.frames, #j, #p, #s, gmin, gmax, log.empty or 0))
                report(tag, j, p, s, verbose or n > 0)
                if os.getenv("CONT_MEM") then
                    local st = love.graphics.getStats()
                    print(string.format("  mem lua=%.0fMB tex=%.0fMB canvases=%d images=%d", collectgarbage("count") / 1024,
                        st.texturememory / 1048576, st.canvases, st.images))
                end
            end
            end
        end
    end
    print(string.format("TOTAL %d cenas, %d com descontinuidade", total, bad))
    return bad == 0
end

return M
