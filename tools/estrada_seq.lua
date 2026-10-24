local ffi = require("ffi")

local M = {}

M.DT = 1 / 60
M.MIN_A = 0.35
M.ALPHA_STEP = 0.34
M.JUMP_PX = 5
M.JUMP_K = 0.6
M.SCALE_STEP = 0.25
M.ROAD_K = 2.4
M.ROAD_MIN = 2.0
M.BAND_K = 0.05

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

M.NEXT = { "shop", "event", "rest" }

function M.capture(act, types, pick, opts)
    opts = opts or {}
    local VW, VH = opts.w or 1920, opts.h or 1080
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
    local EE = require("src.ui.EnemyEntrance")

    local restore = patchDims(VW, VH)
    local cv = love.graphics.newCanvas(VW, VH)
    local cropX, cropY, cropW, cropH = math.floor(VW * 0.25), math.floor(VH * 0.37), math.floor(VW * 0.5), math.floor(VH * 0.63)
    local thumbW = 384
    local thumbH = math.floor(thumbW * cropH / cropW)
    local cropQ = love.graphics.newQuad(cropX, cropY, cropW, cropH, VW, VH)
    local thumb = opts.thumbs and love.graphics.newCanvas(thumbW, thumbH) or nil
    local floor = 3
    local game = Game:new()
    game:startNewRun("warrior")
    game:startGame()
    local run = game.runManager.currentRun
    run.actNumber, run.floorInAct = act, floor
    run.currentNode = { type = "battle" }
    local function spawn()
        local sid = EnemyRenderer.resolveSpriteId(act, "battle")
        game.enemy = EnemyRoster.spawn(Enemy, sid, ActSystem.getEnemyStats(act, floor, "battle"))
        game.enemy.isBoss = false
    end
    spawn()
    _G.game = game
    require("src.ui.HandDeal").setCurtain(true, game)
    local topBar = TopBar:new()
    topBar:setGame(game)
    GameplayScene.init({ game = game, topBar = topBar, gameUI = GameUI:new(),
        playButton = Button:new(VW * 0.8, VH * 0.8, 150, 46, "Jogar") })
    if game.messageSystem then game.messageSystem.messages = {} end
    local seed = opts.seed or 12648430
    WorldRoad._lastRect = nil
    WorldRoad.restoreProgress(act, floor)
    WorldRoad._rng:setSeed(seed)
    WorldRoad._props = {}
    WorldRoad.setBiome(act)
    WorldRoad._blend, WorldRoad._prevBiomeIndex, WorldRoad._birdTimer = nil, nil, 1e9
    love.math.setRandomSeed(seed)
    WorldRoad.planStop(WorldRoad._camZ, true)
    if os.getenv("SEQ_NOLIGHT") == "1" then require("engine.LightEngine").setEnabled(false) end
    local WE = require("engine.WeatherEngine")
    local weOff = WE.disabled
    WE.disabled = true
    local warm = love.graphics.newCanvas(VW, VH)
    for _ = 1, 150 do
        WorldRoad.update(M.DT)
        EnemyRenderer.update(M.DT)
        love.graphics.setCanvas(warm)
        love.graphics.clear(0, 0, 0, 1)
        GameplayScene.WORLD_ONLY = true
        GameplayScene.draw()
        GameplayScene.WORLD_ONLY = nil
        love.graphics.setCanvas()
    end
    warm:release()

    local g = WorldRoad.domeGeom(0, 0, VW, VH)
    local log = { frames = {}, road = {}, phase = {}, act = act, types = types, pick = pick, w = VW, h = VH,
        crest = g.crestApexY, cuts = {}, g = g }
    local cur = nil
    WorldRoad._seq = function(kind, ref, sub, x, y, w, h, a, hideBelow)
        local rk = type(ref) == "table" and string.format("%s:%.3f:%s:%s", tostring(ref.kind), ref.z or 0,
            tostring(ref.side), tostring(ref.variant)) or tostring(ref)
        local key = kind .. "|" .. rk .. "|" .. tostring(sub)
        local r = cur[key]
        if r and r.a >= a then return end
        local vis = h or 0
        if hideBelow then vis = math.max(0, math.min(h or 0, hideBelow - (y - (h or 0)))) end
        cur[key] = { x = x, y = y, w = w or 0, h = h or 0, a = a or 1, kind = kind, vis = vis }
        local watch = os.getenv("SEQ_KEY")
        if watch and key:find(watch, 1, true) then
            print(string.format("WATCH f%d %s x=%.1f y=%.1f h=%.1f a=%.2f rel=%.2f", log.curFrame or 0, key, x, y, h or 0, a or 1,
                type(ref) == "table" and (ref.z or 0) - WorldRoad._camZ or 0))
        end
    end

    local rx0, rx1 = math.floor(VW * 0.18), math.floor(VW * 0.82)
    local ry0, ry1 = math.floor(g.crestApexY + 8), math.floor(VH - 40)
    local stepPx = 3
    local grid = {}
    local prevGrid = nil
    local ring = {}
    log.flags = {}
    local function pix(fa, fb, r)
        local A, B = ring[fa], ring[fb]
        if not A or not B then return 0 end
        local pa = ffi.cast("uint8_t*", A:getFFIPointer())
        local pb = ffi.cast("uint8_t*", B:getFFIPointer())
        local x0 = math.max(0, math.floor(r.x - r.w * 0.5))
        local x1 = math.min(VW - 1, math.floor(r.x + r.w * 0.5))
        local y0 = math.max(0, math.floor(r.y - r.h))
        local y1 = math.min(VH - 1, math.floor(r.y))
        if x1 < x0 or y1 < y0 then return 0 end
        local sx = math.max(1, math.floor((x1 - x0) / 40))
        local sy = math.max(1, math.floor((y1 - y0) / 40))
        local sum, n = 0, 0
        for y = y0, y1, sy do
            local row = y * VW * 4
            for x = x0, x1, sx do
                local o = row + x * 4
                sum = sum + math.abs((pa[o] - pb[o]) * 0.299 + (pa[o + 1] - pb[o + 1]) * 0.587
                    + (pa[o + 2] - pb[o + 2]) * 0.114)
                n = n + 1
            end
        end
        return n > 0 and sum / n or 0
    end
    local frame = 0
    local phase = "fork"
    local function draw()
        frame = frame + 1
        log.curFrame = frame
        cur = {}
        log.frames[frame] = cur
        log.phase[frame] = phase
        love.graphics.setCanvas(cv)
        love.graphics.clear(0, 0, 0, 1)
        GameplayScene.WORLD_ONLY = true
        GameplayScene.draw()
        GameplayScene.WORLD_ONLY = nil
        love.graphics.setCanvas()
        local d = cv:newImageData()
        local px = ffi.cast("uint8_t*", d:getFFIPointer())
        local n = 0
        local diff, cnt = 0, 0
        local hasEnemy = game.enemy ~= nil or WorldRoad._encounter ~= nil
        local ex0, ex1 = VW * 0.5 - VW * 0.12, VW * 0.5 + VW * 0.12
        local ey1 = g.latY(0, g.tOf(WorldRoad.BATTLE_REL) or 0.5) + 16
        for y = ry0, ry1, stepPx do
            local row = y * VW * 4
            for x = rx0, rx1, stepPx do
                local o = row + x * 4
                local l = px[o] * 0.299 + px[o + 1] * 0.587 + px[o + 2] * 0.114
                n = n + 1
                if prevGrid and not (hasEnemy and x > ex0 and x < ex1 and y < ey1) then
                    diff = diff + math.abs(l - prevGrid[n])
                    cnt = cnt + 1
                end
                grid[n] = l
            end
        end
        log.road[frame] = cnt > 0 and diff / cnt or 0
        prevGrid, grid = grid, prevGrid or {}
        if opts.raw and opts.raw(frame) then
            love.filesystem.createDirectory(opts.dir)
            d:encode("png", string.format("%s/%s_%04d.png", opts.dir, opts.tag, frame))
        end
        ring[frame] = d
        if ring[frame - 3] then ring[frame - 3]:release(); ring[frame - 3] = nil end
        if frame >= 2 then M.checkStep(log, frame, pix, log.flags) end
        if thumb and frame % 2 == 0 then
            love.graphics.setCanvas(thumb)
            love.graphics.clear(0, 0, 0, 1)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(cv, cropQ, 0, 0, 0, thumbW / cropW, thumbH / cropH)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print(tostring(frame), 4, 4)
            love.graphics.setCanvas()
            love.filesystem.createDirectory(opts.dir .. "/thumbs")
            thumb:newImageData():encode("png", string.format("%s/thumbs/%s_%04d.png", opts.dir, opts.tag, frame))
        end
        local dbg = os.getenv("SEQ_DBG")
        if dbg then
            local a0, a1 = dbg:match("(%d+)%-(%d+)")
            if frame >= tonumber(a0) and frame <= tonumber(a1) then
                local SG = require("engine.SceneGrade")
                local fr, fg, fb = SG.fogColor()
                print(string.format("DBG f%d tod=%.4f dim=%.3f luma=%.4f cam=%.3f fog=%.3f,%.3f,%.3f fa=%.3f br=%.2f veil=%.3f bi=%s blend=%s seg=%s",
                    frame, WorldRoad._timeOfDay,
                    EE.wx("dim"), require("engine.LightEngine").ambientLuma(), WorldRoad._camZ, fr or 0, fg or 0, fb or 0,
                    SG.fogAlpha(0.2), WorldRoad.BATTLE_REL, require("engine.WeatherEngine").renderedFog(),
                    tostring(WorldRoad._biomeIndex), tostring(WorldRoad._blend ~= nil), tostring(WorldRoad._segBase)))
            end
        end
        if frame % 30 == 0 then collectgarbage() end
    end
    local afterUpdate = nil
    local function step(n, cond)
        local i = 0
        while (n and i < n) or (cond and cond()) do
            i = i + 1
            WorldRoad.update(M.DT)
            if afterUpdate then afterUpdate() end
            EnemyRenderer.update(M.DT)
            draw()
            if i > 3000 then break end
        end
    end
    local ok, err = pcall(function()
        game.enemy = nil
        phase = "fork"
        WorldRoad.showFork(nodesFor(types), function() end)
        log.cuts[frame + 1] = "showFork"
        step(40)
        local f = WorldRoad._fork
        local b = f and f.markBoxes and f.markBoxes[pick]
        if b then WorldRoad.forkMousePressed((b.x1 + b.x2) / 2, (b.y1 + b.y2) / 2) end
        log.clickFrame = frame + 1
        phase = "converge"
        local ty = types[pick]
        local fights = ty == "battle" or ty == "elite"
        local waitN = tonumber(os.getenv("SEQ_WAIT") or "0")
        afterUpdate = function()
            if WorldRoad._fork == nil and waitN > 0 then waitN = waitN - 1 return end
            if WorldRoad._fork == nil and fights and not WorldRoad.isTraveling() then
                afterUpdate = nil
                if os.getenv("SEQ_NOSPAWN") ~= "1" then spawn() end
                phase = "travel"
                WorldRoad.travel({
                    encounter = os.getenv("SEQ_NOENC") ~= "1" and game.enemy and EnemyRenderer.getEncounterBillboard(game.enemy) or nil,
                    onComplete = function()
                        EnemyRenderer.triggerArrival(nil, { still = not EE.endsWithLanding() })
                    end,
                })
            end
        end
        step(nil, function() return WorldRoad._fork ~= nil end)
        afterUpdate = nil
        if fights then
            step(nil, function() return WorldRoad.isTraveling() end)
            phase = "arrival"
            step(45)
        else
            phase = "landmark"
            step(45)
        end
        phase = "nextfork"
        game.enemy = nil
        log.cuts[frame + 1] = "showFork"
        WorldRoad.showFork(nodesFor(M.NEXT), function() end)
        step(50)
    end)
    WorldRoad._seq = nil
    WE.disabled = weOff
    for k, d in pairs(ring) do d:release(); ring[k] = nil end
    restore()
    cv:release()
    if thumb then thumb:release() end
    log.ok, log.err = ok, err
    log.n = frame
    return log
end

local function inside(log, r)
    local W, H = log.w, log.h
    if r.vis and r.vis < 2 then return false end
    local band = (log.g and log.g.crestYAt(r.x) or log.crest) + M.BAND_K * H
    if r.x < W * 0.03 or r.x > W * 0.97 then return false end
    if r.y < band or r.y - r.h > H - 2 then return false end
    if r.y > H + r.h then return false end
    return true
end

M.PIX_MIN = 6
M.PIX_K = 2.0

local function visibleChange(pix, f, r)
    local now = pix(f - 1, f, r)
    local before = pix(f - 2, f - 1, r)
    return now > math.max(M.PIX_MIN, M.PIX_K * before), now, before
end

function M.checkStep(log, f, pix, flags)
    local function add(kind, what, key, info)
        flags[#flags + 1] = { f = f, kind = kind, what = what, key = key, info = info }
    end
    local A, B = log.frames[f - 1], log.frames[f]
    local cut = log.cuts[f] and "_no_corte" or ""
    for key, r in pairs(B) do
        local p = A[key]
        if not p then
            if r.a >= M.MIN_A and inside(log, r) then
                local vis, d1, d0 = visibleChange(pix, f, r)
                if vis then add(r.kind, "aparece" .. cut, key, string.format("x=%.0f y=%.0f a=%.2f pix %.1f/%.1f", r.x, r.y, r.a, d1, d0)) end
            end
        else
            if math.abs(r.a - p.a) >= M.ALPHA_STEP and inside(log, r) and inside(log, p) then
                local vis, d1 = visibleChange(pix, f, r)
                if vis then add(r.kind, "alpha_salta" .. cut, key, string.format("%.2f->%.2f pix %.1f", p.a, r.a, d1)) end
            end
            local dp, dr = math.sqrt(p.w * p.w + p.h * p.h), math.sqrt(r.w * r.w + r.h * r.h)
            if dp > 6 and dr > 6 and math.abs(dr / dp - 1) > M.SCALE_STEP and inside(log, r) then
                local vis, d1 = visibleChange(pix, f, r)
                if vis then add(r.kind, "escala_salta" .. cut, key, string.format("tam %.0f->%.0f pix %.1f", dp, dr, d1)) end
            end
            local P0 = log.frames[f - 2] and log.frames[f - 2][key]
            if P0 and inside(log, P0) and inside(log, p) and inside(log, r) and r.y < log.h * 0.96 then
                local vx, vy = p.x - P0.x, p.y - P0.y
                local ax, ay = r.x - 2 * p.x + P0.x, r.y - 2 * p.y + P0.y
                local acc = math.sqrt(ax * ax + ay * ay)
                local v = math.sqrt(vx * vx + vy * vy)
                if acc > math.max(M.JUMP_PX, M.JUMP_K * v) then
                    local vis, d1 = visibleChange(pix, f, r)
                    if vis then add(r.kind, "teleporte" .. cut, key, string.format("v=%.1f acc=%.1f x=%.0f y=%.0f pix %.1f", v, acc, r.x, r.y, d1)) end
                end
            end
        end
    end
    for key, p in pairs(A) do
        if not B[key] and p.a >= M.MIN_A and inside(log, p) then
            local vis, d1, d0 = visibleChange(pix, f, p)
            if vis then add(p.kind, "some" .. cut, key, string.format("x=%.0f y=%.0f a=%.2f pix %.1f/%.1f", p.x, p.y, p.a, d1, d0)) end
        end
    end
end

function M.analyze(log)
    local flags = {}
    for _, fl in ipairs(log.flags or {}) do flags[#flags + 1] = fl end
    for f = 4, log.n do
        local d = log.road[f]
        if not log.cuts[f] and not log.cuts[f + 1] then
            local win = {}
            for k = math.max(3, f - 5), math.min(log.n, f + 5) do
                if k ~= f then win[#win + 1] = log.road[k] end
            end
            table.sort(win)
            local med = win[math.floor(#win / 2) + 1] or 0
            if d > M.ROAD_K * med + M.ROAD_MIN then
                flags[#flags + 1] = { f = f, kind = "road", what = "chao_muda", key = "road",
                    info = string.format("diff %.2f med %.2f", d, med) }
            end
        end
    end
    table.sort(flags, function(a, b) return a.f < b.f end)
    return flags
end

function M.summary(flags)
    local by = {}
    for _, fl in ipairs(flags) do
        local k = fl.kind .. ":" .. fl.what
        by[k] = (by[k] or 0) + 1
    end
    local ks = {}
    for k, v in pairs(by) do ks[#ks + 1] = k .. "=" .. v end
    table.sort(ks)
    return table.concat(ks, " ")
end

M.PLANS = {
    { types = { "battle", "rest", "shop" }, pick = 1, tag = "3esq" },
    { types = { "battle", "rest", "shop" }, pick = 2, tag = "3meio" },
    { types = { "battle", "rest", "shop" }, pick = 3, tag = "3dir" },
    { types = { "battle", "shop" }, pick = 1, tag = "2esq" },
    { types = { "shop", "battle" }, pick = 2, tag = "2dir" },
}

function M.run(arg)
    _G.EventManager = _G.EventManager or require("engine.EventManager")
    _G.Event = _G.Event or require("engine.Event")
    local acts, plansArg = tostring(arg or ""):match("^([%d,]*):?([%w,]*)$")
    local al = {}
    for a in ((acts and acts ~= "") and acts or "1,2,3,4,5,6"):gmatch("%d+") do al[#al + 1] = tonumber(a) end
    local want = {}
    for t in (plansArg or ""):gmatch("[%w]+") do want[t] = true end
    local W, H = (os.getenv("SEQ_RES") or "1920x1080"):match("^(%d+)x(%d+)$")
    W, H = tonumber(W), tonumber(H)
    local dir = "estrada_seq/" .. W .. "x" .. H
    local thumbs = os.getenv("SEQ_THUMBS") ~= "0"
    local rawTag = os.getenv("SEQ_RAW")
    local rf0, rf1 = (os.getenv("SEQ_RAWF") or ""):match("^(%d+)%-(%d+)$")
    rf0, rf1 = tonumber(rf0), tonumber(rf1)
    local lines = {}
    local total = 0
    for _, act in ipairs(al) do
        for _, pl in ipairs(M.PLANS) do
            if not next(want) or want[pl.tag] then
                local tag = string.format("ato%d_%s", act, pl.tag)
                local log = M.capture(act, pl.types, pl.pick, { w = W, h = H, thumbs = thumbs, dir = dir, tag = tag,
                    raw = (rawTag == tag or rawTag == "all")
                        and function(f) return not rf0 or (f >= rf0 and f <= rf1) end or nil })
                local flags = M.analyze(log)
                total = total + #flags
                local line = string.format("%s quadros=%d clique=%s flags=%d %s %s", tag, log.n, tostring(log.clickFrame),
                    #flags, M.summary(flags), log.ok and "" or ("ERRO " .. tostring(log.err)))
                print(line)
                lines[#lines + 1] = line
                for i, fl in ipairs(flags) do
                    if i <= 40 then
                        local l2 = string.format("  f%04d %s %s %s %s", fl.f, log.phase[fl.f] or "?", fl.kind, fl.what, fl.info or "")
                        lines[#lines + 1] = l2
                    end
                end
                love.filesystem.createDirectory(dir)
                local fh = love.filesystem.newFile(dir .. "/" .. tag .. "_flags.txt", "w")
                for _, fl in ipairs(flags) do
                    fh:write(string.format("%d %s %s %s %s %s\n", fl.f, log.phase[fl.f] or "?", fl.kind, fl.what, fl.key, fl.info or ""))
                end
                fh:close()
                local rh = love.filesystem.newFile(dir .. "/" .. tag .. "_meta.txt", "w")
                for f = 1, log.n do rh:write(string.format("%d %s %.3f\n", f, log.phase[f], log.road[f] or 0)) end
                rh:close()
                collectgarbage()
            end
        end
    end
    love.filesystem.createDirectory(dir)
    local fh = love.filesystem.newFile(dir .. "/resumo.txt", "w")
    fh:write(table.concat(lines, "\n"))
    fh:close()
    print(string.format("TOTAL flags %d -> %s/%s", total, love.filesystem.getSaveDirectory(), dir))
    love.event.quit()
    return total == 0
end

return M
