local TK = require("tools.testkit")

local M = {}

local W, H = 1920, 1080
local TOP = 80
local BAND = 8
local WIN = 48
local STRIP_MEAN = 0.06
local STRIP_WIN = 0.55
local SWITCH_MAX = 0.03
local RHYTHM_MAX = 0.20
local SMOOTH = 6
local WEDGE_MIN_W = 6
local GROUND_TOL = 0.15
local WEDGE_COVER = 0.55
local WEDGE_CARPET = { [3] = 0.9, [4] = 0.45 }
local ROUGH_MIN = 0.42
local ROUGH_EDGE_MIN = 0.12

local function setup(WorldRoad, bio, scene, canvas)
    WorldRoad.clearCache()
    WorldRoad.resetRun()
    love.math.setRandomSeed(7)
    math.randomseed(7)
    WorldRoad._rng = love.math.newRandomGenerator(0xC0FFEE)
    WorldRoad._time = 0
    WorldRoad._birds, WorldRoad._critters, WorldRoad._ambient = {}, {}, {}
    WorldRoad.setBiome(bio)
    WorldRoad._blend = nil
    WorldRoad._prevBiomeIndex = nil
    WorldRoad._birdTimer = 1e9
    local function tick(n)
        for _ = 1, n do
            WorldRoad.update(1 / 30)
            love.graphics.setCanvas(canvas)
            love.graphics.clear(0, 0, 0, 1)
            WorldRoad.draw(0, TOP, W, H - TOP, bio)
            love.graphics.setCanvas()
        end
    end
    WorldRoad._camZ = 5.5
    tick(30)
    if scene == "fork" or scene == "forkbare" then
        local nodes = { { type = "battle" }, { type = "rest" }, { type = "shop" } }
        if scene == "forkbare" then
            nodes = { { type = "wedge_a" }, { type = "wedge_b" }, { type = "wedge_c" } }
        end
        WorldRoad.showFork(nodes, function() end)
    end
    tick(60)
    WorldRoad.setTimeOfDay(0.85, true)
    WorldRoad.update(1 / 30)
end

local function render(WorldRoad, bio, canvas)
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 1)
    WorldRoad.draw(0, TOP, W, H - TOP, bio)
    love.graphics.setCanvas()
    return canvas:newImageData()
end

local function isDirt(img, x, y)
    local r, g = img:getPixel(x, y)
    return r > g + 0.025
end

local function same(a, b, x, y)
    local r1, g1, b1 = a:getPixel(x, y)
    local r2, g2, b2 = b:getPixel(x, y)
    return math.abs(r1 - r2) + math.abs(g1 - g2) + math.abs(b1 - b2) < 0.02
end

local function traceEdges(full, bare, y0, y1)
    local edges, active = {}, {}
    for y = y0, y1 do
        local trans = {}
        local prev = isDirt(bare, 0, y)
        for x = 1, W - 1 do
            local d = isDirt(bare, x, y)
            if d ~= prev then
                trans[#trans + 1] = { x = x, dir = d and 1 or -1 }
            end
            prev = d
        end
        local nextActive = {}
        for _, tr in ipairs(trans) do
            local x0, x1
            if tr.dir > 0 then x0, x1 = tr.x, tr.x + BAND - 1 else x0, x1 = tr.x - BAND, tr.x - 1 end
            local ok = x0 >= 0 and x1 < W
            for x = x0, x1 do
                if ok and not isDirt(bare, x, y) then ok = false end
            end
            if ok then
                local n = 0
                for x = x0, x1 do
                    if same(full, bare, x, y) then n = n + 1 end
                end
                local f = n / BAND
                local hit
                for i, e in ipairs(active) do
                    if e.dir == tr.dir and math.abs(e.x - tr.x) <= 6 and e.y == y - 1 then
                        hit = e
                        table.remove(active, i)
                        break
                    end
                end
                if not hit then
                    hit = { dir = tr.dir, s = {} }
                    edges[#edges + 1] = hit
                end
                hit.x, hit.y = tr.x, y
                hit.s[#hit.s + 1] = f
                hit.xs = hit.xs or {}
                hit.xs[#hit.s] = tr.x
                nextActive[#nextActive + 1] = hit
            end
        end
        active = nextActive
    end
    return edges
end

local function stripState(f)
    if f <= 0.15 then return 1 end
    if f >= 0.85 then return 2 end
    return 0
end

local function windowStats(s, i0)
    local strips, switches = 0, 0
    local prev
    for i = i0, i0 + WIN - 1 do
        local st = stripState(s[i])
        if st == 1 then strips = strips + 1 end
        if prev and st ~= prev and st * prev == 2 then switches = switches + 1 end
        prev = st
    end
    local m = strips / WIN
    local best = 0
    if strips > 0 and strips < WIN then
        local v = 0
        for i = i0, i0 + WIN - 1 do
            local b = (stripState(s[i]) == 1 and 1 or 0) - m
            v = v + b * b
        end
        for L = 3, 20 do
            local c = 0
            for i = i0, i0 + WIN - 1 - L do
                local a = (stripState(s[i]) == 1 and 1 or 0) - m
                local b = (stripState(s[i + L]) == 1 and 1 or 0) - m
                c = c + a * b
            end
            c = c / v * WIN / (WIN - L)
            if c > best then best = c end
        end
    end
    return m, switches / WIN, best * math.sqrt(m)
end

function M.measure(bio, scene)
    local WorldRoad = require("src.ui.WorldRoad")
    local GrassField = require("engine.GrassField")
    local canvas = love.graphics.newCanvas(W, H)
    local realTime = love.timer.getTime
    love.timer.getTime = function() return 100 end
    setup(WorldRoad, bio, scene, canvas)
    local full = render(WorldRoad, bio, canvas)
    GrassField.disabled = true
    local bare = render(WorldRoad, bio, canvas)
    GrassField.disabled = nil
    love.timer.getTime = realTime
    canvas:release()
    local edges = traceEdges(full, bare, math.floor(H * 0.55), H - 8)
    local dump = os.getenv("BORDA_DUMP")
    if dump then
        local out = {}
        for _, e in ipairs(edges) do
            if #e.s >= WIN then
                local parts = {}
                for k = 1, #e.s do parts[k] = string.format("%.3f", e.s[k]) end
                out[#out + 1] = e.dir .. " " .. e.x .. " " .. e.y .. " " .. table.concat(parts, ",")
            end
        end
        love.filesystem.write(dump .. "_" .. scene .. ".txt", table.concat(out, string.char(10)))
        full:encode("png", dump .. "_" .. scene .. "_full.png")
        bare:encode("png", dump .. "_" .. scene .. "_bare.png")
    end
    local R = { stripMean = 0, stripMax = 0, switchMax = 0, rhythm = 0, wins = 0 }
    for _, e in ipairs(edges) do
        local s = e.s
        local i = 1
        while i + WIN - 1 <= #s do
            local m, sw, rh = windowStats(s, i)
            R.stripMean = R.stripMean + m
            R.stripMax = math.max(R.stripMax, m)
            R.switchMax = math.max(R.switchMax, sw)
            R.rhythm = math.max(R.rhythm, rh)
            R.wins = R.wins + 1
            i = i + WIN
        end
    end
    R.stripMean = R.stripMean / math.max(1, R.wins)
    local rough, rows = 0, 0
    R.roughMin = 1
    for _, e in ipairs(edges) do
        local xs = e.xs
        if xs and #xs >= WIN then
            local er, en = 0, 0
            for i = 1 + SMOOTH, #xs - SMOOTH do
                local a = 0
                for k = i - SMOOTH, i + SMOOTH do a = a + xs[k] end
                a = a / (2 * SMOOTH + 1)
                en = en + 1
                if math.abs(xs[i] - a) >= 1 then er = er + 1 end
            end
            rough, rows = rough + er, rows + en
            if en > 0 then R.roughMin = math.min(R.roughMin, er / en) end
        end
    end
    R.rough = rows > 0 and rough / rows or 0
    full:release()
    bare:release()
    return R
end

function M.wedge(bio)
    local WorldRoad = require("src.ui.WorldRoad")
    local GrassField = require("engine.GrassField")
    local canvas = love.graphics.newCanvas(W, H)
    local realTime = love.timer.getTime
    love.timer.getTime = function() return 100 end
    local RoadWear = require("engine.RoadWear")
    local realWear = RoadWear.draw
    RoadWear.draw = function() end
    setup(WorldRoad, bio, "forkbare", canvas)
    local full = render(WorldRoad, bio, canvas)
    GrassField.disabled = true
    local bare = render(WorldRoad, bio, canvas)
    local realOff = WorldRoad.roadEdgeOff
    WorldRoad.roadEdgeOff = function() return -1e5 end
    local none = render(WorldRoad, bio, canvas)
    WorldRoad.roadEdgeOff = realOff
    RoadWear.draw = realWear
    GrassField.disabled = nil
    love.timer.getTime = realTime
    canvas:release()
    local cx = W / 2
    local x0, x1 = math.floor(cx - W * 0.30), math.floor(cx + W * 0.30)
    local covered, total, rows = 0, 0, 0
    local road = {}
    local dump = os.getenv("BORDA_DUMP")
    local dumpImg = dump and full:clone() or nil
    for y = math.floor(H * 0.40), math.floor(H * 0.75) do
        for x = x0, x1 do road[x] = not same(bare, none, x, y) end
        local rs, gs, bs = {}, {}, {}
        for x = x0, x1, 4 do
            local r, g2, b = none:getPixel(x, y)
            rs[#rs + 1], gs[#gs + 1], bs[#bs + 1] = r, g2, b
        end
        table.sort(rs) table.sort(gs) table.sort(bs)
        local mi = math.floor(#rs / 2) + 1
        local mr, mg, mb = rs[mi], gs[mi], bs[mi]
        local runs, inRoad, start = 0, false, nil
        local gaps = {}
        for x = x0, x1 do
            if road[x] and not inRoad then
                runs = runs + 1
                if start then gaps[#gaps + 1] = { start, x - 1 } end
                inRoad = true
            elseif not road[x] and inRoad then
                inRoad = false
                start = x
            end
        end
        if runs >= 2 then
            local any = false
            for _, gp in ipairs(gaps) do
                local gw = gp[2] - gp[1] + 1
                if gw >= WEDGE_MIN_W and gw <= W * 0.25 then
                    any = true
                    for x = gp[1] + 1, gp[2] - 1 do
                        local r, g2, b = none:getPixel(x, y)
                        if math.abs(r - mr) + math.abs(g2 - mg) + math.abs(b - mb) < GROUND_TOL then
                            total = total + 1
                            local cv = not same(full, bare, x, y)
                            if cv then covered = covered + 1 end
                            if dumpImg then dumpImg:setPixel(x, y, cv and 0 or 1, cv and 1 or 0, 0, 1) end
                        end
                    end
                end
            end
            if any then rows = rows + 1 end
        end
    end
    if dumpImg then
        dumpImg:encode("png", dump .. "_cunha_" .. bio .. ".png")
        dumpImg:release()
    end
    full:release()
    bare:release()
    none:release()
    return total > 0 and covered / total or 0, rows, total
end

function M.run()
    local t = TK.new("borda grama/estrada sem ritmo de faixas (autocorrelação por fileira)")
    _G.EventManager = _G.EventManager or require("engine.EventManager")
    _G.Event = _G.Event or require("engine.Event")
    local ok, err = pcall(function()
        for _, sc in ipairs({ "fork", "tronco" }) do
            local R = M.measure(1, sc)
            t:check(("ato 1 %s: janelas de borda medidas (%d)"):format(sc, R.wins), R.wins >= 4)
            t:check(("ato 1 %s: fileiras-faixa na borda (média) %.3f <= %.2f"):format(sc, R.stripMean, STRIP_MEAN),
                R.stripMean <= STRIP_MEAN)
            t:check(("ato 1 %s: fileiras-faixa na pior janela %.2f <= %.2f"):format(sc, R.stripMax, STRIP_WIN),
                R.stripMax <= STRIP_WIN)
            t:check(("ato 1 %s: alternância faixa/vão %.3f <= %.2f"):format(sc, R.switchMax, SWITCH_MAX),
                R.switchMax <= SWITCH_MAX)
            t:check(("ato 1 %s: ritmo (autocorrelação das faixas) %.2f <= %.2f"):format(sc, R.rhythm, RHYTHM_MAX),
                R.rhythm <= RHYTHM_MAX)
            t:check(("ato 1 %s: borda irregular, linhas fora do ajuste suave >= 1 px %.2f >= %.2f"):format(sc, R.rough, ROUGH_MIN),
                R.rough >= ROUGH_MIN)
            t:check(("ato 1 %s: nenhuma borda reta (pior borda %.2f >= %.2f)"):format(sc, R.roughMin, ROUGH_EDGE_MIN),
                R.roughMin >= ROUGH_EDGE_MIN)
        end
        for bio = 1, 6 do
            local cov, rows, px = M.wedge(bio)
            t:check(("ato %d: cunha entre ramos medida (%d linhas, %d px)"):format(bio, rows, px), rows >= 20)
            local need = WEDGE_COVER * (WEDGE_CARPET[bio] or 1)
            t:check(("ato %d: cunha entre ramos coberta de grama %.2f >= %.2f"):format(bio, cov, need), cov >= need)
        end
    end)
    t:truthy("medição sem erro: " .. tostring(err), ok)
    require("src.ui.WorldRoad").resetRun()
    require("src.ui.WorldRoad").clearCache()
    return t:done()
end

return M
