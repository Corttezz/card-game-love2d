local TK = require("tools.testkit")

local M = {}

M.SEEDS = 2000

local function roll(Rng, weights)
    local total = 0
    for _, e in ipairs(weights) do total = total + (e.weight or 1) end
    local r = Rng.get():random("map") * total
    local acc = 0
    for _, e in ipairs(weights) do
        acc = acc + (e.weight or 1)
        if r <= acc then return e.type end
    end
    return weights[#weights].type
end

local function legacyGenerate(MapManager, Rng, floorInAct, act, numNodes)
    local weights = MapManager.weightsFor(floorInAct, act)
    if floorInAct >= MapManager.FLOORS_PER_ACT - 1 then return { weights[1].type } end
    local out, used, attempts = {}, {}, 0
    while #out < numNodes and attempts < 20 do
        attempts = attempts + 1
        local t = roll(Rng, weights)
        if not used[t] then used[t] = true; out[#out + 1] = t end
    end
    local fallback = #out < numNodes
    while #out < numNodes do out[#out + 1] = roll(Rng, weights) end
    return out, fallback
end

M.legacyGenerate = legacyGenerate

local function hasDup(types)
    local seen = {}
    for _, t in ipairs(types) do
        if seen[t] then return true end
        seen[t] = true
    end
    return false
end

M.hasDup = hasDup

local function typesOf(nodes)
    local out = {}
    for i, n in ipairs(nodes) do out[i] = n.type end
    return out
end

local function sweep(t, MapManager, Rng, WorldRoad)
    local acts = (require("src.core.Config").TotalActs or 6) + 1
    local before, after = {}, {}
    local nBefore, nAfter = 0, 0
    local dupBefore, dupAfter, badCount, badMid, sameSeed = 0, 0, 0, 0, true
    local forks = 0
    for seed = 1, M.SEEDS do
        Rng.setActive(Rng.new(seed))
        local legacy = {}
        for act = 1, acts do
            for f = 1, MapManager.FLOORS_PER_ACT do
                local ty, fb = legacyGenerate(MapManager, Rng, f, act, 3)
                legacy[#legacy + 1] = (not fb) and ty or false
                if hasDup(ty) then dupBefore = dupBefore + 1 end
                for _, x in ipairs(ty) do before[x] = (before[x] or 0) + 1; nBefore = nBefore + 1 end
            end
        end
        Rng.setActive(Rng.new(seed))
        local k = 0
        for act = 1, acts do
            local eliteMul = (act == acts and seed % 2 == 0) and 1.6 or nil
            for f = 1, MapManager.FLOORS_PER_ACT do
                local nodes = MapManager.generate(f, act, 3, { eliteMul = eliteMul })
                local ty = typesOf(nodes)
                forks = forks + 1
                k = k + 1
                if hasDup(ty) then dupAfter = dupAfter + 1 end
                local want = (f >= MapManager.FLOORS_PER_ACT - 1) and 1 or 3
                if #ty ~= want then badCount = badCount + 1 end
                if not eliteMul and legacy[k] and table.concat(legacy[k], ",") ~= table.concat(ty, ",") then
                    sameSeed = false
                end
                for _, x in ipairs(ty) do after[x] = (after[x] or 0) + 1; nAfter = nAfter + 1 end
                if #nodes > 1 then
                    local dirs = WorldRoad.forkDirs(nodes, #nodes)
                    for i, nd in ipairs(nodes) do
                        if nd.type == "battle" and dirs[i] ~= 0 then badMid = badMid + 1 end
                    end
                end
            end
        end
    end
    print(("    encruzilhadas: %d (2000 seeds x 8 andares x %d atos, o ultimo = endless)"):format(forks, acts))
    print(("    com tipo repetido: antes %d, depois %d"):format(dupBefore, dupAfter))
    print("    tipo        antes     depois    antes%   depois%")
    local maxShift = 0
    for _, ty in ipairs({ "battle", "elite", "shop", "rest", "event", "mini_boss", "boss" }) do
        local a, b = before[ty] or 0, after[ty] or 0
        local pa, pb = a / nBefore * 100, b / nAfter * 100
        maxShift = math.max(maxShift, math.abs(pa - pb))
        print(("    %-10s %8d %10d %8.2f %9.2f"):format(ty, a, b, pa, pb))
    end
    t:eq("nenhuma encruzilhada com dois nos do mesmo tipo", dupAfter, 0)
    t:truthy("a regra antiga REPETIA tipo (o bug existe na referencia)", dupBefore > 0)
    t:eq("toda encruzilhada tem 3 opcoes (1 no mini-chefe e no chefe)", badCount, 0)
    t:eq("batalha sempre na estrada do meio", badMid, 0)
    t:truthy("mesma seed = mesmas opcoes de antes (fora o caso que repetia)", sameSeed)
    t:truthy(("distribuicao de tipos quase igual (maior desvio %.2f pp)"):format(maxShift), maxShift < 0.5)
end

local function pools(t, MapManager, Rng)
    Rng.setActive(Rng.new(4242))
    local big = MapManager.generate(4, 2, 9)
    t:eq("pedir mais opcoes que tipos encolhe a encruzilhada em vez de repetir", #big, 5)
    t:falsy("encruzilhada encolhida sem repeticao", hasDup(typesOf(big)))
    local real = MapManager.weightsFor
    MapManager.weightsFor = function()
        return { { type = "battle", weight = 9 }, { type = "rest", weight = 1 }, { type = "elite", weight = 0 } }
    end
    local ok, small = pcall(MapManager.generate, 3, 1, 3)
    MapManager.weightsFor = real
    t:truthy("pool de 2 tipos: gera sem erro", ok)
    t:eq("pool de 2 tipos (peso 0 fora): 2 opcoes", ok and #small or -1, 2)
    t:falsy("pool de 2 tipos: sem repeticao", ok and hasDup(typesOf(small)))
    local a, b = {}, {}
    Rng.setActive(Rng.new(99))
    for f = 1, 6 do a[#a + 1] = table.concat(typesOf(MapManager.generate(f, 5, 3)), ",") end
    Rng.setActive(Rng.new(99))
    for f = 1, 6 do b[#b + 1] = table.concat(typesOf(MapManager.generate(f, 5, 3)), ",") end
    t:eq("reprodutivel pela seed (stream map)", table.concat(a, "|"), table.concat(b, "|"))
end

local function repair(t, MapManager)
    local MM = MapManager
    local nodes = {
        MM._makeNode("shop", 4, 5), MM._makeNode("battle", 4, 5), MM._makeNode("battle", 4, 5),
    }
    nodes[2].enemyId, nodes[3].enemyId = "a", "b"
    local fixed, removed = MM.dedupeNodes(nodes)
    t:eq("dedupe tira 1 repetido", removed, 1)
    t:eq("dedupe mantem a ordem e o primeiro", table.concat(typesOf(fixed), ","), "shop,battle")
    t:eq("dedupe mantem o inimigo ja sorteado do primeiro", fixed[2].enemyId, "a")
    local again = select(1, MM.dedupeNodes(nodes))
    t:eq("dedupe deterministico", table.concat(typesOf(again), ","), "shop,battle")
    t:noerror("dedupe aceita lixo sem quebrar", function()
        MM.dedupeNodes(nil)
        MM.dedupeNodes({ {}, "x", MM._makeNode("rest", 2, 1) })
    end)

    local g = TK.newRunGame("warrior")
    local rm = g.runManager
    rm.currentRun.actNumber, rm.currentRun.floorInAct = 5, 4
    rm.currentRun.pendingNodes = {
        MM._makeNode("shop", 4, 5), MM._makeNode("battle", 4, 5), MM._makeNode("battle", 4, 5),
    }
    rm.currentRun.stage = "fork"
    rm:saveRun()
    local Game = require("src.core.Game")
    local g2 = Game:new()
    local ok = g2.runManager:loadRun()
    t:truthy("save com encruzilhada repetida carrega", ok)
    local pend = ok and g2.runManager.currentRun.pendingNodes or {}
    t:eq("Continuar repara a encruzilhada salva", table.concat(typesOf(pend), ","), "shop,battle")
    t:eq("Continuar segue na encruzilhada", require("src.systems.ResumeFlow").stageAction(g2.runManager.currentRun), "fork")
    local WorldRoad = require("src.ui.WorldRoad")
    t:eq("encruzilhada reparada: batalha no meio", table.concat(WorldRoad.forkDirs(pend, #pend), ","), "-1,0")
    g2.runManager:deleteSave()
end

function M.run()
    local t = TK.new("encruzilhada nunca repete tipo de no")
    local MapManager = require("src.systems.MapManager")
    local Rng = require("src.systems.Rng")
    local WorldRoad = require("src.ui.WorldRoad")
    local ok, err = pcall(function()
        sweep(t, MapManager, Rng, WorldRoad)
        pools(t, MapManager, Rng)
        repair(t, MapManager)
    end)
    t:truthy("execucao sem erro: " .. tostring(err), ok)
    return t:done()
end

return M
