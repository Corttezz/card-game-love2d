local M = {}

M.DT = 1 / 30
M.SEED = 0xC0FFEE
M.TOL_ART = 1.0
M.CELL_W, M.CELL_H = 480, 270
M.COLS, M.ROWS = 4, 4
M.CROP_W, M.CROP_H = 320, 180
M.CROP_K = 3
M.CROP_N = 12
M.CROP_EVERY = 3
M.NEXT_PREF = { "hollow_farmer", "storm_harpy", "hellhound", "frost_wight", "plague_toad", "dusk_bat" }

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

function M.propBearers(act)
    local Data = require("src.data.enemy_entrances")
    local out = {}
    for _, r in ipairs(require("tools.entradas").roster()) do
        local spec = Data.BY_ID[r.id]
        local anc = spec and spec.anchor
        if (not act or r.act == act) and anc and not anc.veil then out[#out + 1] = r end
    end
    return out
end

function M.nextFor(act, id)
    local Data = require("src.data.enemy_entrances")
    local roster = require("src.data.enemies").ROSTER[act]
    local pref = M.NEXT_PREF[act]
    if pref and pref ~= id then return { id = pref, act = act, node = "battle" } end
    for _, cid in ipairs(roster.battle) do
        local spec = Data.BY_ID[cid]
        if cid ~= id and not (spec and spec.anchor) then return { id = cid, act = act, node = "battle" } end
    end
    return { id = roster.battle[1] ~= id and roster.battle[1] or roster.battle[2], act = act, node = "battle" }
end

local function newSheet(cols, rows, cw, ch)
    local cv = love.graphics.newCanvas(cols * cw, rows * ch)
    love.graphics.setCanvas(cv)
    love.graphics.clear(0.08, 0.08, 0.1, 1)
    love.graphics.setCanvas()
    return { cv = cv, cols = cols, rows = rows, cw = cw, ch = ch, n = 0 }
end

local function sheetPut(sh, src, qx, qy, qw, qh, label, mark)
    if sh.n >= sh.cols * sh.rows then return end
    local i = sh.n
    sh.n = sh.n + 1
    local x0, y0 = (i % sh.cols) * sh.cw, math.floor(i / sh.cols) * sh.ch
    love.graphics.setCanvas(sh.cv)
    love.graphics.origin()
    love.graphics.setColor(1, 1, 1, 1)
    local q = love.graphics.newQuad(qx, qy, qw, qh, src:getWidth(), src:getHeight())
    local k = sh.cw / qw
    love.graphics.draw(src, q, x0, y0, 0, k, sh.ch / qh)
    q:release()
    if mark then
        love.graphics.setColor(1, 0.2, 0.9, 1)
        for _, m in ipairs(mark) do
            local mx, my = x0 + (m[1] - qx) * k, y0 + (m[2] - qy) * (sh.ch / qh)
            love.graphics.rectangle("fill", math.floor(mx) - 1, math.floor(my) - 1, 3, 3)
        end
    end
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", x0, y0, sh.cw, 15)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(label, x0 + 3, y0 + 1)
    love.graphics.setCanvas()
end

local function sheetSave(sh, path)
    local d = sh.cv:newImageData()
    d:encode("png", path)
    d:release()
    sh.cv:release()
end

function M.capture(act, creature, nextCr, opts)
    opts = opts or {}
    local VW, VH = opts.w or 1920, opts.h or 1080
    local DT = M.DT
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
    local function spawn(cr)
        run.currentNode = { type = cr.node or "battle" }
        game.enemy = EnemyRoster.spawn(Enemy, cr.id, ActSystem.getEnemyStats(act, floor, cr.node or "battle"))
        game.enemy.isBoss = false
    end
    spawn(creature)
    _G.game = game
    local topBar = TopBar:new()
    topBar:setGame(game)
    GameplayScene.init({ game = game, topBar = topBar, gameUI = GameUI:new(),
        playButton = Button:new(VW * 0.8, VH * 0.8, 150, 46, "Jogar") })
    if game.messageSystem then game.messageSystem.messages = {} end

    WorldRoad._lastRect = nil
    WorldRoad.restoreProgress(act, floor)
    WorldRoad._rng:setSeed(opts.seed or M.SEED)
    WorldRoad._props = {}
    WorldRoad.setBiome(act)
    WorldRoad._blend = nil
    WorldRoad._prevBiomeIndex = nil
    WorldRoad._birdTimer = 1e9
    love.math.setRandomSeed(opts.seed or M.SEED)
    WorldRoad.planStop(WorldRoad._camZ + WorldRoad.TRAVEL_DISTANCE, true)
    for _ = 1, 30 do WorldRoad.update(DT); EnemyRenderer.update(DT) end
    love.graphics.setCanvas(cv)
    GameplayScene.draw()
    love.graphics.setCanvas()

    local spec = require("src.data.enemy_entrances").BY_ID[creature.id] or {}
    local anc = spec.anchor or {}
    local log = { mustAttach = (anc.at or "stage") == "stage" or anc.lift ~= nil, act = act, id = creature.id, nextId = nextCr.id, w = VW, h = VH, frames = {}, flags = {},
        oldVisible = 0, oldLeft = 0, firstOld = nil, oldStill = 0, maxOff = 0, maxOffAt = nil, attached = 0,
        crestHits = 0, roadHits = 0, n = 0 }
    local frame, phase = 0, "entrada"
    local cur
    local g = WorldRoad.domeGeom(0, 0, VW, VH)
    EE._trace = function(p, px, py, t, s, a, y0, gy, wpx, behind)
        if not cur then return end
        local src = p.front and p.ref or p
        cur.anch[#cur.anch + 1] = { uid = src.uid, front = p.front and true or false, entrId = src.entrId, name = src.name,
            side = src.side, x = px, y = py, t = t, s = s, a = a, y0 = y0, gy = gy, w = wpx, behind = behind,
            flat = EE.isFlat(src), straddle = src.straddle }
    end
    EE._traceGround = function(x, y, s, rel, where, lat)
        if not cur then return end
        cur.body = { x = x, y = y, s = s, rel = rel, where = where, lat = lat }
    end
    local origDraw = EnemyRenderer.draw
    EnemyRenderer.draw = function(...)
        local r = origDraw(...)
        local lf = EnemyRenderer.getLastFoot()
        if cur and lf and not WorldRoad._travel and phase ~= "converge" then
            cur.body = { x = lf.drawX + lf.iw * lf.scale / 2, y = lf.groundY, s = lf.scale, where = "battle" }
        end
        return r
    end

    local sheetE = opts.png and newSheet(M.COLS, M.ROWS, M.CELL_W, M.CELL_H)
    local sheetC = opts.png and newSheet(3, 4, M.CROP_W * M.CROP_K, M.CROP_H * M.CROP_K)
    local sheetD = opts.png and newSheet(M.COLS, M.ROWS, M.CELL_W, M.CELL_H)
    local travelFrames = 1
    local entStart, depStart, depFrames = 0, 0, 1
    local cropN, cropFrom = 0, nil
    local oldUids = {}

    local function analyzeFrame(fr)
        local S = EE.state()
        local b = fr.body
        for _, A in ipairs(fr.anch) do
            if not A.front and A.a > 0.01 then
                local own = A.entrId == creature.id and not oldUids[A.uid]
                if own and phase ~= "partida" and phase ~= "proxima" and b then
                    local attached = A.side == 0 or (S and S.sideFrac == 1 and S.dxK == 0)
                    if attached and (b.where ~= "battle" or A.side == 0) then
                        local ss = math.max(0.01, A.s)
                        local inset = (A.side ~= 0 and S and S.inset) or 0
                        local dx, dy = (A.x - b.x) / ss, (A.y - b.y) / ss
                        if inset > 0 then
                            dx = dx - (A.x > b.x and 1 or -1) * 2 * inset * S.anchorHalfW
                            dy = 0
                        end
                        local off = math.max(math.abs(dx), math.abs(dy))
                        log.attached = log.attached + 1
                        if off > log.maxOff then log.maxOff, log.maxOffAt = off, { f = fr.f, dx = dx, dy = dy, where = b.where, ph = fr.phase } end
                        if off > M.TOL_ART then
                            log.flags[#log.flags + 1] = string.format("f%d %s desalinhado dx=%.2f dy=%.2f arte-px (%s)", fr.f, fr.phase, dx, dy, b.where)
                        end
                    end
                end
                if not A.behind and A.t and A.t > 0 then
                    local crest = g.crestYAt(A.x)
                    if A.flat and A.y0 and A.y0 < crest - 1 then
                        log.crestHits = log.crestHits + 1
                        log.flags[#log.flags + 1] = string.format("f%d %s %s passa da crista topo=%.1f crista=%.1f", fr.f, fr.phase, A.name, A.y0, crest)
                    end
                    if A.gy and A.gy < crest - 1 then
                        log.crestHits = log.crestHits + 1
                        log.flags[#log.flags + 1] = string.format("f%d %s %s base acima da crista base=%.1f crista=%.1f", fr.f, fr.phase, A.name, A.gy, crest)
                    end
                    if A.flat and A.side == 0 then
                        local half = 0.15 * VW * (0.30 + 0.70 * (A.t ^ 1.15))
                        if math.abs(A.x - g.cx) > half then
                            log.roadHits = log.roadHits + 1
                            log.flags[#log.flags + 1] = string.format("f%d %s %s fora da estrada x=%.1f", fr.f, fr.phase, A.name, A.x)
                        end
                    end
                end
                if oldUids[A.uid] and (phase == "proxima") then
                    local onScreen = (A.y0 or A.y) < VH and A.x + (A.w or 0) / 2 > 0 and A.x - (A.w or 0) / 2 < VW
                    if onScreen then
                        log.oldVisible = log.oldVisible + 1
                        log.firstOld = log.firstOld or fr.f
                    end
                end
                if oldUids[A.uid] and (phase == "partida" or phase == "proxima") then
                    local pv = log.prevOld and log.prevOld[A.uid]
                    log.prevOld = log.prevOld or {}
                    local onScreen = (A.y0 or A.y) < VH
                    if pv and onScreen and math.abs(A.y - pv.y) < 0.01 and math.abs(A.s - pv.s) < 1e-6 and fr.moved then
                        log.oldStill = log.oldStill + 1
                        log.flags[#log.flags + 1] = string.format("f%d %s %s parada na tela com a camera andando y=%.1f", fr.f, fr.phase, A.name, A.y)
                    end
                    log.prevOld[A.uid] = { y = A.y, s = A.s }
                end
            end
        end
    end

    local lastCam = WorldRoad._camZ
    local function draw()
        frame = frame + 1
        cur = { f = frame, phase = phase, anch = {}, body = nil, cam = WorldRoad._camZ }
        cur.moved = math.abs(WorldRoad._camZ - lastCam) > 1e-4
        lastCam = WorldRoad._camZ
        love.graphics.setCanvas(cv)
        love.graphics.clear(0, 0, 0, 1)
        GameplayScene.draw()
        love.graphics.setCanvas()
        local fr = cur
        cur = nil
        analyzeFrame(fr)
        log.n = frame
        if opts.png then
            local mainA
            for _, A in ipairs(fr.anch) do
                if not A.front and A.entrId == creature.id and not oldUids[A.uid] then mainA = A end
            end
            if phase == "entrada" or phase == "chegada" then
                local i = frame - entStart
                local every = math.max(1, math.floor(travelFrames / (M.COLS * M.ROWS - 1)))
                if i % every == 0 then
                    local lab = string.format("f%d %s", frame, phase)
                    if mainA and fr.body then
                        lab = lab .. string.format(" d=%.1f,%.1f", (mainA.x - fr.body.x) / mainA.s, (mainA.y - fr.body.y) / mainA.s)
                    end
                    sheetPut(sheetE, cv, 0, 0, VW, VH, lab)
                end
                if mainA and mainA.a > 0.01 and cropN < M.CROP_N then
                    cropFrom = cropFrom or frame
                    if (frame - cropFrom) % math.max(M.CROP_EVERY, math.floor(travelFrames / 24)) == 0 then
                        cropN = cropN + 1
                        local by = fr.body and fr.body.y or mainA.y
                        local cy0 = math.max(mainA.gy or mainA.y, by) - M.CROP_H * 0.8
                        local cxm = fr.body and (mainA.x + fr.body.x) * 0.5 or mainA.x
                        local qx = math.max(0, math.min(VW - M.CROP_W, math.floor(cxm - M.CROP_W / 2)))
                        local qy = math.max(0, math.min(VH - M.CROP_H, math.floor(cy0)))
                        local marks = { { mainA.x, mainA.y } }
                        if fr.body then marks[2] = { fr.body.x, fr.body.y } end
                        local lab = string.format("f%d x3 %s", frame, fr.body and fr.body.where or "-")
                        if fr.body then
                            lab = lab .. string.format(" d=%.1f,%.1f", (mainA.x - fr.body.x) / mainA.s, (mainA.y - fr.body.y) / mainA.s)
                        end
                        sheetPut(sheetC, cv, qx, qy, M.CROP_W, M.CROP_H, lab, marks)
                    end
                end
            elseif phase == "partida" or phase == "proxima" or phase == "garfo" then
                local i = frame - depStart
                local every = math.max(1, math.floor(depFrames / (M.COLS * M.ROWS - 1)))
                if i % every == 0 then
                    local nOld = 0
                    for _, A in ipairs(fr.anch) do if oldUids[A.uid] and A.a > 0.01 and (A.y0 or A.y) < VH then nOld = nOld + 1 end end
                    sheetPut(sheetD, cv, 0, 0, VW, VH, string.format("f%d %s antigos_na_tela=%d", frame, phase, nOld))
                end
            end
        end
        love.graphics.present()
        if frame % 30 == 0 then collectgarbage() end
    end
    local function step(n, cond)
        local i = 0
        while (n and i < n) or (cond and cond()) do
            i = i + 1
            WorldRoad.update(DT)
            EnemyRenderer.update(DT)
            draw()
            if i > 3000 then break end
        end
    end
    local function travelBattle(cr)
        spawn(cr)
        WorldRoad.travel({
            encounter = EnemyRenderer.getEncounterBillboard(game.enemy),
            onComplete = function()
                EnemyRenderer.triggerArrival(nil, { still = not EE.endsWithLanding() })
            end,
        })
        local tr = WorldRoad._travel
        travelFrames = math.floor(((tr.duration or 6.5) + (tr.settle or 0)) / DT) + 30
        step(nil, function() return WorldRoad.isTraveling() end)
    end

    local ok, err = pcall(function()
        phase = "entrada"
        entStart = frame
        travelBattle(creature)
        phase = "chegada"
        step(30)
        for _, p in ipairs(WorldRoad._props) do
            if p.anchor then oldUids[(p.front and p.ref or p).uid] = true end
        end
        log.ownAnchors = 0
        for _ in pairs(oldUids) do log.ownAnchors = log.ownAnchors + 1 end
        phase = "garfo"
        depStart = frame
        depFrames = math.floor((0.8 + 2.4 + 9.5) / DT)
        game.enemy = nil
        step(10)
        WorldRoad.showFork(nodesFor(opts.forkTypes or { "battle", "shop" }), function() end)
        step(25)
        local f = WorldRoad._fork
        local pick = 1
        for i = 1, f.n do if f.nodes[i].type == (opts.pick or "battle") then pick = i end end
        local b = f and f.markBoxes and f.markBoxes[pick]
        if b then WorldRoad.forkMousePressed((b.x1 + b.x2) / 2, (b.y1 + b.y2) / 2) end
        phase = "partida"
        step(nil, function() return WorldRoad._fork ~= nil end)
        if (opts.pick or "battle") == "battle" then
            phase = "proxima"
            travelBattle(nextCr)
            step(10)
        else
            phase = "proxima"
            step(60)
        end
        for _, p in ipairs(WorldRoad._props) do
            if p.anchor and oldUids[(p.front and p.ref or p).uid] then log.oldLeft = log.oldLeft + 1 end
        end
    end)

    EnemyRenderer.draw = origDraw
    EE._trace = nil
    EE._traceGround = nil
    if opts.png and opts.dir then
        love.filesystem.createDirectory(opts.dir)
        sheetSave(sheetE, string.format("%s/%s_entrada.png", opts.dir, creature.id))
        sheetSave(sheetC, string.format("%s/%s_fundo_x3.png", opts.dir, creature.id))
        sheetSave(sheetD, string.format("%s/%s_partida.png", opts.dir, creature.id))
    end
    restore()
    love.window.setVSync(vsync)
    cv:release()
    collectgarbage()
    log.ok, log.err = ok, err
    return log
end

function M.verdict(log)
    local bad = {}
    if not log.ok then bad[#bad + 1] = "erro: " .. tostring(log.err) end
    if log.attached == 0 and log.mustAttach then bad[#bad + 1] = "nenhum quadro com ancora e corpo juntos" end
    if log.maxOff > M.TOL_ART then bad[#bad + 1] = string.format("desalinhado %.2f arte-px", log.maxOff) end
    if log.crestHits > 0 then bad[#bad + 1] = "passa da crista " .. log.crestHits end
    if log.roadHits > 0 then bad[#bad + 1] = "fora da estrada " .. log.roadHits end
    if log.oldLeft > 0 then bad[#bad + 1] = "sobrou ancora antiga " .. log.oldLeft end
    if log.oldStill > 0 then bad[#bad + 1] = "ancora antiga parada na tela " .. log.oldStill end
    return #bad == 0, bad
end

function M.run(arg)
    io.stdout:setvbuf("line")
    local a, only, pick = tostring(arg or ""):match("^(%d*):?([%w_]*):?(%a*)$")
    local act = tonumber(a)
    local list = M.propBearers(act)
    local W, H = (os.getenv("PROPS_RES") or "1920x1080"):match("^(%d+)x(%d+)$")
    W, H = tonumber(W), tonumber(H)
    local dir = "props_inimigo"
    local png = os.getenv("PROPS_PNG") ~= "0"
    local total, bad = 0, 0
    for _, cr in ipairs(list) do
        if not only or only == "" or only == cr.id then
            local nx = M.nextFor(cr.act, cr.id)
            local log = M.capture(cr.act, cr, nx, { w = W, h = H, png = png, dir = dir,
                pick = (pick and pick ~= "") and pick or "battle" })
            local okv, why = M.verdict(log)
            total = total + 1
            if not okv then bad = bad + 1 end
            local ma = log.maxOffAt
            print(string.format("[%s] ato%d %s -> %s quadros=%d juntos=%d desvio_max=%.2f arte-px%s crista=%d estrada=%d antigas_visiveis=%d (1o f%s) antigas_paradas=%d sobraram=%d %s",
                okv and "ok" or "FAIL", cr.act, cr.id, log.nextId, log.n, log.attached, log.maxOff,
                ma and string.format(" (f%d %s %s dx=%.2f dy=%.2f)", ma.f, ma.ph, ma.where, ma.dx, ma.dy) or "",
                log.crestHits, log.roadHits, log.oldVisible, tostring(log.firstOld), log.oldStill, log.oldLeft,
                table.concat(why, "; ")))
            for i, fl in ipairs(log.flags) do
                if i <= 6 then print("    " .. fl) end
            end
            log = nil
            collectgarbage("collect")
        end
    end
    print(string.format("TOTAL %d inimigos com prop, %d com defeito -> %s/%s", total, bad,
        love.filesystem.getSaveDirectory(), dir))
    return bad == 0
end

return M
