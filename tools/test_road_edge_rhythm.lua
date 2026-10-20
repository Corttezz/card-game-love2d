local TK = require("tools.testkit")

local M = {}

local W, H = 1920, 1080
local TOP = 80
local BAND = 8
local WIN = 48
local STRIP_MEAN = 0.06
local STRIP_WIN = 0.25
local SWITCH_MAX = 0.03
local RHYTHM_MAX = 0.20

local function setup(WorldRoad, bio, scene, canvas)
    WorldRoad.clearCache()
    WorldRoad.resetRun()
    love.math.setRandomSeed(7)
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
    if scene == "fork" then
        local nodes = { { type = "battle" }, { type = "rest" }, { type = "shop" } }
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
    full:release()
    bare:release()
    return R
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
        end
    end)
    t:truthy("medição sem erro: " .. tostring(err), ok)
    require("src.ui.WorldRoad").resetRun()
    require("src.ui.WorldRoad").clearCache()
    return t:done()
end

return M
