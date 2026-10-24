local ffi = require("ffi")
local TK = require("tools.testkit")
local Seq = require("tools.estrada_seq")

local M = {}

M.DT = 1 / 60
M.NEXT = { "battle", "rest", "shop" }
M.WALK = { battle = true, elite = true, mini_boss = true, boss = true }
M.COVER_K = 0.22
M.THUMB_W = 480
M.SMALL_W = 480
M.MEM_CAP = tonumber(os.getenv("SEQ_MEM_CAP") or "4000")

M.PLANS = {
    { tag = "3_loja", types = { "battle", "rest", "shop" }, pick = "shop" },
    { tag = "3_descanso", types = { "battle", "rest", "shop" }, pick = "rest" },
    { tag = "3_batalha", types = { "battle", "rest", "shop" }, pick = "battle" },
    { tag = "3_evento", types = { "event", "battle", "rest" }, pick = "event" },
    { tag = "3_semluta_meio", types = { "rest", "shop", "event" }, pick = "shop" },
    { tag = "3_semluta_lado", types = { "rest", "shop", "event" }, pick = "event" },
    { tag = "3_elite_lado", types = { "battle", "elite", "shop" }, pick = "elite" },
    { tag = "2_loja", types = { "battle", "shop" }, pick = "shop" },
    { tag = "2_batalha", types = { "shop", "battle" }, pick = "battle" },
    { tag = "2_semluta", types = { "rest", "event" }, pick = "rest" },
}

local function patchDims(w, h)
    local o = { love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions }
    love.graphics.getWidth = function() return w end
    love.graphics.getHeight = function() return h end
    love.graphics.getDimensions = function() return w, h end
    return function()
        love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions = o[1], o[2], o[3]
    end
end

local function api() return _G.__cheatApi end
local function state() return api() and api().state() end
local function run()
    local g = api() and api().game()
    return g and g.runManager and g.runManager.currentRun
end

local Ctx = {}

pcall(ffi.cdef, [[
typedef struct { unsigned long cb; unsigned long PageFaultCount; size_t PeakWorkingSetSize; size_t WorkingSetSize;
  size_t QuotaPeakPagedPoolUsage; size_t QuotaPagedPoolUsage; size_t QuotaPeakNonPagedPoolUsage;
  size_t QuotaNonPagedPoolUsage; size_t PagefileUsage; size_t PeakPagefileUsage; } ESTRADA_PMC;
void* GetCurrentProcess(void);
int K32GetProcessMemoryInfo(void* h, ESTRADA_PMC* c, unsigned long cb);
]])

function M.mem()
    local luaMB = collectgarbage("count") / 1024
    local ok, priv, peak = pcall(function()
        local c = ffi.new("ESTRADA_PMC")
        c.cb = ffi.sizeof(c)
        ffi.C.K32GetProcessMemoryInfo(ffi.C.GetCurrentProcess(), c, c.cb)
        return tonumber(c.PagefileUsage) / 1048576, tonumber(c.PeakPagefileUsage) / 1048576
    end)
    if not ok then priv, peak = -1, -1 end
    return luaMB, priv, peak
end

local function overlapK(a, b)
    local ix = math.min(a.x2, b.x2) - math.max(a.x1, b.x1)
    local iy = math.min(a.y2, b.y2) - math.max(a.y1, b.y1)
    if ix <= 0 or iy <= 0 then return 0 end
    return ix * iy / math.max(1, (a.x2 - a.x1) * (a.y2 - a.y1))
end

function M.boot(VW, VH)
    Ctx.restoreDims = patchDims(VW, VH)
    TK.bootstrap()
    local okLoad, errLoad = pcall(love.load, {})
    if not okLoad then return false, errLoad end
    if _G.audioSystem and _G.audioSystem.setMasterVolume then _G.audioSystem:setMasterVolume(0) end
    require("src.ui.CRTShader").setEnabled(false)
    local CheatMode = require("src.systems.CheatMode")
    CheatMode.activate({ isolate = false })
    CheatMode.panelOpen = false
    Ctx.mouse = { love.mouse.getPosition, love.mouse.getX, love.mouse.getY }
    Ctx.mx, Ctx.my = VW * 0.5, VH * 0.08
    love.mouse.getPosition = function() return Ctx.mx, Ctx.my end
    love.mouse.getX = function() return Ctx.mx end
    love.mouse.getY = function() return Ctx.my end
    Ctx.VW, Ctx.VH = VW, VH
    Ctx.cv = love.graphics.newCanvas(VW, VH)
    Ctx.thumbH = math.floor(M.THUMB_W * VH / VW)
    Ctx.thumb = love.graphics.newCanvas(M.THUMB_W, Ctx.thumbH)
    Ctx.SW, Ctx.SH = M.SMALL_W, math.floor(M.SMALL_W * VH / VW)
    Ctx.small = love.graphics.newCanvas(Ctx.SW, Ctx.SH)
    for _ = 1, 240 do
        love.update(M.DT)
        if state() ~= "boot" then break end
    end
    love.keypressed("return")
    for _ = 1, 600 do
        love.update(M.DT)
        if state() == "menu" then break end
    end
    api().startGame("warrior", 0)
    for _ = 1, 3000 do
        love.update(M.DT)
        if CheatMode.combatReady(true) then break end
    end
    CheatMode.god = true
    return true
end

function M.shutdown()
    local CheatMode = require("src.systems.CheatMode")
    CheatMode.deactivate()
    if Ctx.mouse then
        love.mouse.getPosition, love.mouse.getX, love.mouse.getY = Ctx.mouse[1], Ctx.mouse[2], Ctx.mouse[3]
    end
    if _G.audioSystem and _G.audioSystem.stopAll then pcall(_G.audioSystem.stopAll, _G.audioSystem) end
    if Ctx.restoreDims then Ctx.restoreDims() end
    if Ctx.cv then Ctx.cv:release() end
    if Ctx.thumb then Ctx.thumb:release() end
    if Ctx.small then Ctx.small:release() end
end

local function dirsOf(f)
    local out = {}
    for i = 1, f.n do out[i] = f.dirs[i] end
    return out
end

function M.capture(act, plan, opts)
    opts = opts or {}
    local VW, VH = Ctx.VW, Ctx.VH
    local WorldRoad = require("src.ui.WorldRoad")
    local CheatMode = require("src.systems.CheatMode")
    local CastleDrift = require("src.ui.CastleDrift")
    local WE = require("engine.WeatherEngine")
    local MapManager = require("src.systems.MapManager")
    local EnemyRoster = require("src.systems.EnemyRoster")
    local cv = Ctx.cv
    local log = { frames = {}, road = {}, phase = {}, cuts = {}, flags = {}, act = act, w = VW, h = VH,
        events = {}, keys = {}, castle = {} }
    local weOff = WE.disabled
    WE.disabled = true

    local function settle(pred, maxN)
        for _ = 1, maxN or 900 do
            love.update(M.DT)
            if state() == "mapSelection" then
                CheatMode.rush = false
                CheatMode.pending().forkPick = nil
            end
            if pred() then return true end
        end
        return false
    end

    CheatMode.rush = false
    CheatMode.goToAct(act, false)
    settle(function()
        local f = WorldRoad._fork
        return state() == "mapSelection" and f and (f.animIn or 0) >= 1
    end, 900)
    for _ = 1, 30 do love.update(M.DT) end

    local r = run()
    local nodes = {}
    for i, ty in ipairs(plan.types) do nodes[i] = MapManager._makeNode(ty, r.floorInAct, r.actNumber) end
    EnemyRoster.assignNodes(r, nodes)
    r.pendingNodes = nodes
    WorldRoad._fork = nil
    WorldRoad._landmark = nil
    api().showMapSelection()

    local g = WorldRoad.domeGeom(0, 0, VW, VH)
    log.crest, log.g = g.crestApexY, g
    local cur
    WorldRoad._seq = function(kind, ref, sub, x, y, w, h, a, hideBelow)
        if not cur then return end
        local rk = type(ref) == "table" and string.format("%s:%.3f:%s:%s", tostring(ref.kind), ref.z or 0,
            tostring(ref.side), tostring(ref.variant)) or tostring(ref)
        local key = kind .. "|" .. rk .. "|" .. tostring(sub)
        local q = cur[key]
        if q and q.a >= a then return end
        local vis = h or 0
        if hideBelow then vis = math.max(0, math.min(h or 0, hideBelow - (y - (h or 0)))) end
        cur[key] = { x = x, y = y, w = w or 0, h = h or 0, a = a or 1, kind = kind, vis = vis, sub = sub }
        local watch = os.getenv("SEQ_KEY")
        if watch and key:find(watch, 1, true) then
            print(string.format("WATCH f%d %s x=%.1f y=%.1f h=%.1f a=%.2f vis=%.1f rel=%.2f", log.curFrame or 0, key, x, y,
                h or 0, a or 1, vis, type(ref) == "table" and (ref.z or 0) - WorldRoad._camZ or 0))
        end
    end

    local SW, SH = Ctx.SW, Ctx.SH
    local kx, ky = SW / VW, SH / VH
    local rx0, rx1 = math.floor(VW * 0.18 * kx), math.floor(VW * 0.82 * kx)
    local ry0, ry1 = math.floor((g.crestApexY + 8) * ky), math.floor((VH - 40) * ky)
    local stepPx = 1
    local grid, prevGrid = {}, nil
    local ring = {}
    local function pix(fa, fb, rr)
        local A, B = ring[fa], ring[fb]
        if not A or not B then return 0 end
        local pa = ffi.cast("uint8_t*", A:getFFIPointer())
        local pb = ffi.cast("uint8_t*", B:getFFIPointer())
        local x0 = math.max(0, math.floor((rr.x - rr.w * 0.5) * kx))
        local x1 = math.min(SW - 1, math.floor((rr.x + rr.w * 0.5) * kx))
        local y0 = math.max(0, math.floor((rr.y - rr.h) * ky))
        local y1 = math.min(SH - 1, math.floor(rr.y * ky))
        if x1 < x0 or y1 < y0 then return 0 end
        local sx = math.max(1, math.floor((x1 - x0) / 40))
        local sy = math.max(1, math.floor((y1 - y0) / 40))
        local sum, n = 0, 0
        for y = y0, y1, sy do
            local row = y * SW * 4
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
    local phase = "forkA"
    local recording = true
    local function addFlag(kind, what, key, info)
        log.flags[#log.flags + 1] = { f = frame, kind = kind, what = what, key = key, info = info }
    end
    local function saveKey(name, d)
        if not opts.dir then return end
        love.filesystem.createDirectory(opts.dir .. "/chave")
        d:encode("png", string.format("%s/chave/%s_%s.png", opts.dir, opts.tag, name))
        log.keys[#log.keys + 1] = name
    end
    local pendingKey = {}
    local function markKey(name)
        pendingKey[#pendingKey + 1] = name
        if os.getenv("SEQ_MEMLOG") == "1" then
            local lm, pm = M.mem()
            print(string.format("MEMF %s %s f%d lua=%.0f privado=%.0f", opts.tag or "?", name, frame, lm, pm))
        end
    end

    local function checkFork(d)
        local f = WorldRoad._fork
        if not f or f.converge or (f.animIn or 0) < 1 then return end
        local markZ = f.markZ
        for i = 1, f.n do
            local geo = f._geo and f._geo[i]
            local b = f.markBoxes and f.markBoxes[i]
            if not geo or not b then
                addFlag("opcao", "sem_caixa", "mark" .. i, phase)
            else
                local d = f.dirs[i]
                if d ~= 0 and (geo.px - g.cx) * d < 0 then
                    addFlag("opcao", "lado_trocado", "mark" .. i, string.format("dir %d x=%.0f centro=%.0f", d, geo.px, g.cx))
                end
                if b.x1 < 0 or b.x2 > VW or b.y1 < 0 or b.y2 > VH then
                    addFlag("opcao", "fora_da_tela", "mark" .. i, string.format("%.0f,%.0f-%.0f,%.0f", b.x1, b.y1, b.x2, b.y2))
                end
                local mb = { x1 = geo.px - geo.iw * geo.s * 0.5, x2 = geo.px + geo.iw * geo.s * 0.5,
                    y1 = geo.py - geo.ih * geo.s, y2 = geo.py }
                for key, e in pairs(cur) do
                    if e.a >= 0.35 and e.y > geo.py + 4 and (e.vis or e.h) > 2 then
                        local eb = { x1 = e.x - e.w * 0.5, x2 = e.x + e.w * 0.5, y1 = e.y - e.h, y2 = e.y }
                        local k = overlapK(mb, eb)
                        local mw = mb.x2 - mb.x1
                        local core = e.kind ~= "prop" or (e.x > mb.x1 + mw * 0.2 and e.x < mb.x2 - mw * 0.2)
                        if k > M.COVER_K and core then
                            addFlag("opcao", "coberta", key, string.format("opcao %d %s coberta %.0f%% por %s",
                                i, tostring(f.nodes[i] and f.nodes[i].type), k * 100, e.kind))
                        end
                    end
                end
            end
        end
        for key, e in pairs(cur) do
            if e.kind == "landmark" and e.a >= 0.35 and math.abs((e.sub or 0) - markZ) > 0.01 then
                addFlag("landmark", "parado_na_frente", key, string.format("x=%.0f y=%.0f h=%.0f a=%.2f", e.x, e.y, e.h, e.a))
            end
        end
    end

    local function draw()
        frame = frame + 1
        log.curFrame = frame
        cur = {}
        log.frames[frame] = cur
        log.frames[frame - 3] = nil
        log.phase[frame] = phase
        log.castle[frame] = CastleDrift.raw(WorldRoad._camZ)
        if require("src.ui.EnemyEntrance").flashAlpha() > 0.003 or require("src.systems.ScreenShake").isActive()
           or frame <= 8 then
            log.cuts[frame] = log.cuts[frame] or "flash"
            log.cuts[frame + 1] = log.cuts[frame + 1] or "flash"
        end
        local stNow = state()
        if log.lastState and stNow ~= log.lastState then
            log.cuts[frame] = log.cuts[frame] or ("estado_" .. tostring(stNow))
            log.cuts[frame + 1] = log.cuts[frame + 1] or ("estado_" .. tostring(stNow))
        end
        log.lastState = stNow
        love.graphics.setCanvas(cv)
        love.graphics.clear(0, 0, 0, 1)
        love.graphics.origin()
        love.draw()
        love.graphics.setCanvas()
        love.graphics.origin()
        love.graphics.setCanvas(Ctx.small)
        love.graphics.clear(0, 0, 0, 1)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(cv, 0, 0, 0, kx, ky)
        love.graphics.setCanvas()
        local d = Ctx.small:newImageData()
        local px = ffi.cast("uint8_t*", d:getFFIPointer())
        local n, diff, cnt = 0, 0, 0
        local g2 = api().game()
        local hasEnemy = (g2 and g2.enemy ~= nil) or WorldRoad._encounter ~= nil
        local ex0, ex1 = (VW * 0.38) * kx, (VW * 0.62) * kx
        local ey1 = (g.latY(0, g.tOf(WorldRoad.BATTLE_REL) or 0.5) + 16) * ky
        for y = ry0, ry1, stepPx do
            local row = y * SW * 4
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
        ring[frame] = d
        if ring[frame - 3] then ring[frame - 3]:release(); ring[frame - 3] = nil end
        if frame >= 2 and log.frames[frame - 1] then Seq.checkStep(log, frame, pix, log.flags) end
        checkFork(d)
        if #pendingKey > 0 and opts.dir then
            local full = cv:newImageData()
            for _, kn in ipairs(pendingKey) do saveKey(kn, full) end
            full:release()
        end
        for q = #pendingKey, 1, -1 do pendingKey[q] = nil end
        if opts.thumbs and opts.dir and frame % 3 == 0 then
            love.graphics.setCanvas(Ctx.thumb)
            love.graphics.clear(0, 0, 0, 1)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(cv, 0, 0, 0, M.THUMB_W / VW, Ctx.thumbH / VH)
            love.graphics.setColor(0, 0, 0, 0.6)
            love.graphics.rectangle("fill", 0, 0, 150, 16)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print(string.format("%d %s", frame, phase), 3, 1)
            love.graphics.setCanvas()
            love.filesystem.createDirectory(opts.dir .. "/thumbs")
            local td = Ctx.thumb:newImageData()
            td:encode("png", string.format("%s/thumbs/%s_%04d.png", opts.dir, opts.tag, frame))
            td:release()
        end
        love.graphics.present()
        if frame % 30 == 0 then collectgarbage() end
        if frame % 60 == 0 then
            local _, pm = M.mem()
            if pm > M.MEM_CAP then error(string.format("memoria do processo %.0f MB passou do teto %d", pm, M.MEM_CAP)) end
        end
    end

    local function snap(name)
        if not opts.dir then return end
        love.graphics.setCanvas(cv)
        love.graphics.clear(0, 0, 0, 1)
        love.graphics.origin()
        love.draw()
        love.graphics.setCanvas()
        love.graphics.origin()
        local d = cv:newImageData()
        saveKey(name, d)
        d:release()
        love.graphics.present()
    end

    local function step(n, pred)
        local i = 0
        while true do
            if n and i >= n then break end
            if pred and not pred() then break end
            i = i + 1
            love.update(M.DT)
            local st = state()
            if st == "mapSelection" then
                CheatMode.rush = false
                CheatMode.pending().forkPick = nil
            end
            if recording then draw() end
            if i > 6000 then
                log.events[#log.events + 1] = "timeout em " .. phase
                break
            end
        end
    end
    local function cut(name)
        log.cuts[frame + 1] = name
        prevGrid = nil
    end
    local function pause(name)
        recording = false
        log.events[#log.events + 1] = "pausa " .. name .. " f" .. frame
    end
    local function resume(name)
        recording = true
        cut(name)
        log.frames[frame] = nil
        log.events[#log.events + 1] = "retoma " .. name .. " f" .. (frame + 1)
    end

    local ok, err = pcall(function()
        cut("showFork")
        step(nil, function()
            local f = WorldRoad._fork
            return not (f and (f.animIn or 0) >= 1)
        end)
        step(20)
        local f = WorldRoad._fork
        if not f then error("encruzilhada A nao abriu") end
        log.dirsA = dirsOf(f)
        local idx
        for i = 1, f.n do if f.nodes[i].type == plan.pick then idx = i end end
        log.pickDir = f.dirs[idx]
        local b = f.markBoxes[idx]
        if not b then error("caixa da opcao " .. tostring(plan.pick) .. " ausente") end
        markKey("1_encruzilhada")
        Ctx.mx, Ctx.my = (b.x1 + b.x2) * 0.5, (b.y1 + b.y2) * 0.5
        step(6)
        love.mousepressed(Ctx.mx, Ctx.my, 1, false, 1)
        love.mousereleased(Ctx.mx, Ctx.my, 1, false, 1)
        log.clickFrame = frame + 1
        phase = "converge"
        step(nil, function() return WorldRoad._fork ~= nil end)
        Ctx.mx, Ctx.my = VW * 0.5, VH * 0.08
        markKey("2_chegou")
        local walk = M.WALK[plan.pick]
        if walk then
            phase = "viagem"
            step(60, function() return not WorldRoad.isTraveling() end)
            step(nil, function() return WorldRoad.isTraveling() end)
            phase = "chegada"
            step(60)
            markKey("3_luta")
            pause("luta")
            CheatMode.rush = true
            settle(function() return state() == "mapSelection" end, 6000)
            CheatMode.rush = false
            resume("saiu_da_luta")
        else
            phase = "no_lugar"
            step(20, function() return state() == "mapSelection" end)
            pause("tela_" .. plan.pick)
            CheatMode.rush = true
            local shown = settle(function() return state() ~= "mapSelection" end, 600)
            if not shown then log.events[#log.events + 1] = "tela do no nao abriu" end
            settle(function() return false end, 50)
            snap("3_tela")
            settle(function() return state() == "mapSelection" end, 6000)
            CheatMode.rush = false
            resume("saiu_" .. plan.pick)
        end
        phase = "partida"
        markKey("4_saiu")
        step(1)
        step(10)
        markKey("5_saiu_10q")
        step(nil, function()
            local f2 = WorldRoad._fork
            return not (f2 and (f2.animIn or 0) >= 1)
        end)
        phase = "forkB"
        markKey("6_proxima")
        local f2 = WorldRoad._fork
        log.dirsB = f2 and dirsOf(f2)
        step(40)
        markKey("7_proxima_40q")
    end)
    WorldRoad._seq = nil
    WE.disabled = weOff
    for k, d in pairs(ring) do d:release(); ring[k] = nil end
    CheatMode.rush = false
    Ctx.mx, Ctx.my = VW * 0.5, VH * 0.08
    log.ok, log.err, log.n = ok, err, frame
    return log
end

function M.analyze(log)
    local flags = Seq.analyze(log)
    local out, seen = {}, {}
    for _, fl in ipairs(flags) do
        local k = fl.what .. "|" .. tostring(fl.key)
        if fl.kind == "opcao" or fl.what == "parado_na_frente" then
            if not seen[k] then
                seen[k] = true
                out[#out + 1] = fl
            end
        else
            out[#out + 1] = fl
        end
    end
    return out
end

function M.run(arg)
    local acts, plansArg = tostring(arg or ""):match("^([%d,]*):?([%w_,]*)$")
    local al = {}
    for a in ((acts and acts ~= "") and acts or "1,2,3,4,5,6"):gmatch("%d+") do al[#al + 1] = tonumber(a) end
    local want = {}
    for t in (plansArg or ""):gmatch("[%w_]+") do want[t] = true end
    local W, H = (os.getenv("SEQ_RES") or "1920x1080"):match("^(%d+)x(%d+)$")
    W, H = tonumber(W), tonumber(H)
    local dir = "estrada_fluxo/" .. W .. "x" .. H
    local thumbs = os.getenv("SEQ_THUMBS") == "1"
    Ctx.t0 = love.timer.getTime()
    local okBoot, errBoot = M.boot(W, H)
    local lines = {}
    local total = 0
    if not okBoot then
        print("[FAIL] boot: " .. tostring(errBoot))
        M.shutdown()
        love.event.quit(1)
        return false
    end
    love.filesystem.createDirectory(dir)
    for _, act in ipairs(al) do
        for _, pl in ipairs(M.PLANS) do
            if not next(want) or want[pl.tag] then
                local tag = string.format("ato%d_%s", act, pl.tag)
                local log = M.capture(act, pl, { dir = dir, thumbs = thumbs, tag = tag })
                local flags = M.analyze(log)
                total = total + #flags + (log.ok and 0 or 1)
                local function ds(t)
                    if not t then return "-" end
                    local s = {}
                    for i, v in ipairs(t) do s[i] = tostring(v) end
                    return table.concat(s, ",")
                end
                local cmin, cmax = 0, 0
                for f = 1, log.n do
                    local c = log.castle[f]
                    if c then cmin, cmax = math.min(cmin, c), math.max(cmax, c) end
                end
                local line = string.format("%s quadros=%d dirsA=%s lado=%s dirsB=%s castelo=[%.3f,%.3f] flags=%d %s %s",
                    tag, log.n, ds(log.dirsA), tostring(log.pickDir), ds(log.dirsB), cmin, cmax, #flags,
                    Seq.summary(flags), log.ok and "" or ("ERRO " .. tostring(log.err)))
                print(line)
                lines[#lines + 1] = line
                local lm, pm, pk = M.mem()
                print(string.format("MEM %s lua=%.0fMB privado=%.0fMB pico=%.0fMB t=%.0fs", tag, lm, pm, pk,
                    love.timer.getTime() - (Ctx.t0 or 0)))
                for _, e in ipairs(log.events) do lines[#lines + 1] = "  # " .. e end
                for i, fl in ipairs(flags) do
                    if i <= 40 then
                        lines[#lines + 1] = string.format("  f%04d %s %s %s %s %s", fl.f, log.phase[fl.f] or "?", fl.kind,
                            fl.what, tostring(fl.key), fl.info or "")
                    end
                end
                local fh = love.filesystem.newFile(dir .. "/" .. tag .. "_flags.txt", "w")
                for _, fl in ipairs(flags) do
                    fh:write(string.format("%d %s %s %s %s %s\n", fl.f, log.phase[fl.f] or "?", fl.kind, fl.what,
                        tostring(fl.key), fl.info or ""))
                end
                fh:close()
                log = nil
                collectgarbage("collect")
                collectgarbage("collect")
            end
        end
    end
    local fh = love.filesystem.newFile(dir .. "/resumo.txt", "w")
    fh:write(table.concat(lines, "\n"))
    fh:close()
    print(string.format("TOTAL flags %d -> %s/%s", total, love.filesystem.getSaveDirectory(), dir))
    M.shutdown()
    return total == 0
end

return M
