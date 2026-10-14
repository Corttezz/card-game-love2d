local MapManager = require("src.systems.MapManager")

local M = {}

function M.run()
    local pass, fail = 0, 0
    local function check(name, cond)
        if cond then pass = pass + 1; print("  [ok] " .. name)
        else fail = fail + 1; print("  [FAIL] " .. name) end
    end

    print("---- Fase 4 map smoke test ----")

    local nodes = MapManager.generate(3, 1, 3)
    check("gera 3 nos em floor 3", #nodes == 3)

    local ok = true
    for _, n in ipairs(nodes) do
        if not n.type or not n.label or not n.floorInAct then ok = false end
    end
    check("nodes tem type/label/floorInAct", ok)

    local bossNodes = MapManager.generate(MapManager.FLOORS_PER_ACT, 1, 3)
    check("floor final gera apenas boss", #bossNodes == 1 and bossNodes[1].type == "boss")

    local miniNodes = MapManager.generate(MapManager.FLOORS_PER_ACT - 1, 1, 3)
    check("floor penultimo = mini_boss", #miniNodes == 1 and miniNodes[1].type == "mini_boss")

    local a, f = MapManager.floorToAct(1)
    check("floor 1 -> ato 1, floorInAct 1", a == 1 and f == 1)
    local a2, f2 = MapManager.floorToAct(MapManager.FLOORS_PER_ACT + 1)
    check("floor floorsPerAct+1 -> ato 2, floorInAct 1", a2 == 2 and f2 == 1)

    local seen = {}
    for i = 1, 100 do
        local nns = MapManager.generate(3, 1, 3)
        for _, n in ipairs(nns) do seen[n.type] = (seen[n.type] or 0) + 1 end
    end
    local typeCount = 0
    for _ in pairs(seen) do typeCount = typeCount + 1 end
    check("100 rolls geram 3+ tipos distintos", typeCount >= 3)
    check("BATTLE aparece em maioria das rolagens", seen.battle and seen.battle >= 60)

    local meta = MapManager.NODE_META[MapManager.NODE_TYPES.BATTLE]
    check("NODE_META.BATTLE tem icon", meta and meta.icon)

    print(string.format("\n  TOTAL: %d pass / %d fail", pass, fail))
    return fail == 0
end

return M
