local TK = require("tools.testkit")
local M = {}

function M.run()
    local t = TK.new("Faixa de montanha: sol pintado com deriva limitada, luz no sol real, ladrilho sem espelho")
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

    for _, b in ipairs(biomes) do
        local base = "assets/sprites/world/" .. b.id .. "_mountains.png"
        local front = "assets/sprites/world/" .. b.id .. "_mountains_front.png"
        if love.filesystem.getInfo(base) then
            local d = love.image.newImageData(base)
            t:truthy(b.id .. ": faixa cabe na largura de referência (escala não muda)",
                d:getWidth() <= 400 and d:getWidth() >= 320)
            if love.filesystem.getInfo(front) then
                local f = love.image.newImageData(front)
                t:truthy(b.id .. ": _front com o mesmo tamanho da faixa (ladrilho alinhado)",
                    f:getWidth() == d:getWidth() and f:getHeight() == d:getHeight())
            end
        end
    end

    WorldRoad.resetRun()
    WorldRoad._camZ, WorldRoad._segBase, WorldRoad._biomeIndex, WorldRoad._segBasePrev =
        saved[1], saved[2], saved[3], saved[4]
    return t:done()
end

return M
