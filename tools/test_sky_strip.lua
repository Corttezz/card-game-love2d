local TK = require("tools.testkit")
local M = {}

function M.run()
    local t = TK.new("Faixa de montanha: sol pintado com deriva limitada e luz no sol real")
    local biomes = require("src.data.biomes")
    local WorldRoad = require("src.ui.WorldRoad")
    local saved = { WorldRoad._camZ, WorldRoad._segBase, WorldRoad._biomeIndex, WorldRoad._segBasePrev }

    for i, b in ipairs(biomes) do
        local cel = b.celestial
        WorldRoad.resetRun()
        WorldRoad._biomeIndex = i
        WorldRoad._segBase = 0
        local xs = {}
        for f = 1, 8 do
            WorldRoad._camZ = (f - 1) * WorldRoad.TRAVEL_DISTANCE
            xs[f] = WorldRoad.sunXr()
        end
        if cel.painted then
            t:truthy(b.id .. ": sol pintado declara deriva", cel.drift and cel.drift > 0)
            t:truthy(b.id .. ": deriva no máximo 0,04 da largura", (cel.drift or 1) <= 0.04 + 1e-9)
            t:near(b.id .. ": andar 1 no extremo da deriva", xs[1], cel.xr + cel.drift, 1e-6)
            t:near(b.id .. ": andar 8 no outro extremo", xs[8], cel.xr - cel.drift, 1e-6)
            local mono = true
            for f = 2, 8 do mono = mono and xs[f] < xs[f - 1] end
            t:truthy(b.id .. ": horizonte anda em todo andar", mono)
            local side = (cel.xr > 0.5)
            t:truthy(b.id .. ": o sol não troca de lado na deriva",
                ((xs[1] > 0.5) == side) and ((xs[8] > 0.5) == side))
            WorldRoad._camZ = 1000
            t:near(b.id .. ": deriva para no fim do ato", WorldRoad.sunXr(), cel.xr - cel.drift, 1e-6)
        else
            local fixed = true
            for f = 1, 8 do fixed = fixed and xs[f] == cel.xr end
            t:truthy(b.id .. ": sem astro pintado a luz segue xr", fixed)
        end
    end

    WorldRoad.resetRun()
    WorldRoad._camZ, WorldRoad._segBase, WorldRoad._biomeIndex, WorldRoad._segBasePrev =
        saved[1], saved[2], saved[3], saved[4]
    return t:done()
end

return M
