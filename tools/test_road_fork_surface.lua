local TK = require("tools.testkit")

local M = {}

local W, H = 1920, 1080
local TOP = 80

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
    for _ = 1, 10 do WorldRoad.update(1 / 30); frame(WorldRoad, bio, canvas) end
    local nodes = {}
    for i, ty in ipairs(types) do nodes[i] = { type = ty } end
    WorldRoad.showFork(nodes, function() end)
    for _ = 1, 40 do WorldRoad.update(1 / 30) end
end

local function probe(WorldRoad, bio, canvas)
    local fp = {}
    WorldRoad._forkSurfaceProbe = fp
    frame(WorldRoad, bio, canvas)
    WorldRoad._forkSurfaceProbe = nil
    return fp
end

local function unit(t)
    local RoadFork = require("engine.RoadFork")
    local A = {
        { c = 100, xL = 40, xR = 160, a = 1 },
        { c = 130, xL = 70, xR = 190, a = 1 },
        { c = 160, xL = 100, xR = 220, a = 1 },
    }
    local ord, m = RoadFork.partition(A, 3, nil, 60, false)
    local ov = RoadFork.overlapPx(A, ord, m)
    t:check(("ramos sobrepostos: nenhum pinta por cima do vizinho além da transição (%.1f px)"):format(ov),
        ov <= 0.01)
    t:check("borda de dentro não conta como borda (ramo do meio)", not A[2].dL and not A[2].dR)
    local C = { { c = 100, xL = 40, xR = 160, a = 0.5 }, { c = 120, xL = 60, xR = 180, a = 1 },
        { c = 140, xL = 80, xR = 200, a = 0.5 } }
    RoadFork.partition(C, 3, 2, 60, false)
    t:check("convergindo: o ramo escolhido mantém a largura inteira", C[2].sL == 60 and C[2].sR == 180)
    t:check("convergindo: os outros ramos nunca pintam sobre o escolhido", C[1].sR <= 60 and C[3].sL >= 180)
    local D = { { c = 100, xL = 40, xR = 160, a = 1 }, { c = 100, xL = 40, xR = 160, a = 1 } }
    ord, m = RoadFork.partition(D, 2, nil, 60, true)
    t:check("junta dura (passarela): sem faixa de transição",
        (D[2].band or 0) == 0 and RoadFork.overlapPx(D, ord, m) <= 0)
end

function M.run()
    local t = TK.new("encruzilhada: ramos como um chão só (sem sobreposição, textura sem esticar)")
    _G.EventManager = _G.EventManager or require("engine.EventManager")
    _G.Event = _G.Event or require("engine.Event")
    unit(t)
    local WorldRoad = require("src.ui.WorldRoad")
    local canvas = love.graphics.newCanvas(W, H)
    local realTime = love.timer.getTime
    love.timer.getTime = function() return 100 end
    local ok, err = pcall(function()
        for bio = 1, 6 do
            for _, types in ipairs({ { "battle", "rest", "shop" }, { "battle", "shop" } }) do
                setup(WorldRoad, bio, types, canvas)
                local fp = probe(WorldRoad, bio, canvas)
                local tag = ("ato %d, %d opções"):format(bio, #types)
                t:check(("%s: linhas da encruzilhada medidas (%d)"):format(tag, fp.rows or 0), (fp.rows or 0) >= 40)
                t:check(("%s: sobreposição entre ramos %.1f px <= 0"):format(tag, fp.overlap or 0),
                    (fp.overlap or 0) <= 0.01)
                t:check(("%s: densidade da textura ao longo do ramo / tronco em [0.55, 1.8] (%.2f a %.2f)")
                    :format(tag, fp.minRatio or 0, fp.maxRatio or 0),
                    (fp.minRatio or 0) >= 0.55 and (fp.maxRatio or 99) <= 1.8)
                t:check(("%s: o ramo inclina de verdade (%.1f px/linha; o mapeamento antigo daria %.2f)")
                    :format(tag, fp.maxSlope or 0, fp.minNaive or 1), (fp.maxSlope or 0) > 0.5)
                local f = WorldRoad._fork
                local b = f.markBoxes[#types]
                WorldRoad.forkMousePressed((b.x1 + b.x2) / 2, (b.y1 + b.y2) / 2)
                local worst = 0
                for _ = 1, 60 do
                    WorldRoad.update(1 / 30)
                    if WorldRoad._fork ~= f then break end
                    local cp = probe(WorldRoad, bio, canvas)
                    worst = math.max(worst, cp.overlap or 0)
                end
                t:check(("%s: convergindo, sobreposição %.1f px <= 0"):format(tag, worst), worst <= 0.01)
            end
        end
    end)
    love.timer.getTime = realTime
    WorldRoad._forkSurfaceProbe = nil
    canvas:release()
    t:truthy("medição sem erro: " .. tostring(err), ok)
    WorldRoad.resetRun()
    WorldRoad.clearCache()
    return t:done()
end

return M
