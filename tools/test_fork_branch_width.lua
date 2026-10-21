local TK = require("tools.testkit")

local M = {}

local W, H = 1920, 1080
local TOP = 80
local TOL_PX = 1.0
local TOL_PAINT = 4.0

local function frame(WorldRoad, bio, canvas)
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 1)
    WorldRoad.draw(0, TOP, W, H - TOP, bio)
    love.graphics.setCanvas()
end

local function setup(WorldRoad, bio, types, canvas)
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
    WorldRoad._camZ = 5.5
    for _ = 1, 20 do WorldRoad.update(1 / 30); frame(WorldRoad, bio, canvas) end
    local nodes = {}
    for i, ty in ipairs(types) do nodes[i] = { type = ty } end
    WorldRoad.showFork(nodes, function() end)
end

local function measure(WorldRoad, bio, canvas, i, rel)
    local p = { i = i, rel = rel, n = 0, sum = 0, geo = 0 }
    WorldRoad._armProbe = p
    frame(WorldRoad, bio, canvas)
    WorldRoad._armProbe = nil
    if p.n == 0 then return nil end
    return p.geo / p.n, p.half, p.sum / p.n
end

local function spread(list, k)
    local lo, hi, worst = math.huge, -math.huge, 0
    for _, s in ipairs(list) do
        lo, hi = math.min(lo, s[k]), math.max(hi, s[k])
    end
    for _, s in ipairs(list) do
        worst = math.max(worst, (hi - lo) * s[2])
    end
    return worst, #list
end

function M.run()
    local t = TK.new("ramo escolhido da encruzilhada com largura fixa (abrir, clique, convergir, chegar)")
    _G.EventManager = _G.EventManager or require("engine.EventManager")
    _G.Event = _G.Event or require("engine.Event")
    local WorldRoad = require("src.ui.WorldRoad")
    local canvas = love.graphics.newCanvas(W, H)
    local realTime = love.timer.getTime
    love.timer.getTime = function() return 100 end
    local ok, err = pcall(function()
        local MARK = WorldRoad.FORK_MARK_REL
        for _, bio in ipairs({ 1, 4 }) do
            for _, pick in ipairs({ "shop", "battle", "rest", "event" }) do
                local types = (pick == "event") and { "battle", "event", "shop" } or { "battle", "rest", "shop" }
                local idx
                for i, ty in ipairs(types) do if ty == pick then idx = i end end
                setup(WorldRoad, bio, types, canvas)
                local opening = {}
                for _ = 1, 24 do
                    WorldRoad.update(1 / 30)
                    local r, h, v = measure(WorldRoad, bio, canvas, idx, MARK)
                    if r then opening[#opening + 1] = { r, h, v } end
                end
                local wo, no = spread(opening, 1)
                t:check(("ato %d %s: abrindo, meia-largura do ramo no marco varia %.2f px <= %.1f (%d quadros)")
                    :format(bio, pick, wo, TOL_PX, no), no >= 10 and wo <= TOL_PX)
                local f = WorldRoad._fork
                local b = f.markBoxes[idx]
                WorldRoad.forkMousePressed((b.x1 + b.x2) / 2, (b.y1 + b.y2) / 2)
                local conv = {}
                local z0 = f.converge.z0
                for _ = 1, 150 do
                    WorldRoad.update(1 / 30)
                    if WorldRoad._fork ~= f then break end
                    local rel = MARK - (WorldRoad._camZ - z0)
                    if rel < WorldRoad.FORK_REL_MIN + 0.6 then break end
                    local r, h, v = measure(WorldRoad, bio, canvas, idx, rel)
                    if r then conv[#conv + 1] = { r, h, v } end
                end
                local wc, nc = spread(conv, 1)
                t:check(("ato %d %s: clique até a chegada, meia-largura do ramo no marco varia %.2f px <= %.1f (%d quadros)")
                    :format(bio, pick, wc, TOL_PX, nc), nc >= 10 and wc <= TOL_PX)
                local wv = spread(conv, 3)
                t:check(("ato %d %s: largura pintada (com a borda irregular) varia %.2f px <= %.1f")
                    :format(bio, pick, wv, TOL_PAINT), wv <= TOL_PAINT)
            end
        end
    end)
    love.timer.getTime = realTime
    WorldRoad._armProbe = nil
    canvas:release()
    t:truthy("medição sem erro: " .. tostring(err), ok)
    WorldRoad.resetRun()
    WorldRoad.clearCache()
    return t:done()
end

return M
