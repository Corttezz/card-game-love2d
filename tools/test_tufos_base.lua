local TK = require("tools.testkit")
local M = {}

function M.measure(act, dropSeed)
    local GrassField = require("engine.GrassField")
    local WorldRoad = require("src.ui.WorldRoad")
    local W, H = love.graphics.getDimensions()
    local cv = love.graphics.newCanvas(W, H)
    GrassField._legacyTuftHash = dropSeed or nil
    WorldRoad.clearCache()
    WorldRoad.resetRun()
    love.math.setRandomSeed(7 + act)
    WorldRoad.setBiome(act)
    WorldRoad._blend = nil
    WorldRoad._prevBiomeIndex = nil
    WorldRoad._birdTimer = 1e9
    WorldRoad._camZ = 5.5
    for _ = 1, 20 do WorldRoad.update(1 / 30) end
    WorldRoad.travel({ distance = WorldRoad.TRAVEL_DISTANCE })
    local track, keyOf = {}, {}
    local worst, blades, unseeded = 0, 0, 0
    for _ = 1, 60 do
        WorldRoad.update(1 / 30)
        GrassField.tuftProbe = {}
        love.graphics.setCanvas(cv)
        love.graphics.clear(0, 0, 0, 1)
        WorldRoad.draw(0, 52, W, H - 52, act)
        love.graphics.setCanvas()
        for _, b in ipairs(GrassField.tuftProbe) do
            blades = blades + 1
            local key = b.seed and (b.seed * 64 + b.bi) or nil
            if not key then
                unseeded = unseeded + 1
                key = math.floor(b.qx * 4) * 64 + b.bi
            end
            local r = (b.x - b.qx) / b.w
            local prev = track[key]
            if prev then
                local dev = math.abs(r - prev) * b.w
                if dev > worst then worst = dev end
            end
            track[key] = r
            keyOf[key] = true
        end
        GrassField.tuftProbe = nil
    end
    GrassField._legacyTuftHash = nil
    cv:release()
    return worst, blades, unseeded
end

function M.run()
    local t = TK.new("tufo da base de prop ancorado no mundo durante a viagem")
    for _, act in ipairs({ 1, 2, 3, 4, 5, 6 }) do
        local worst, blades, unseeded = M.measure(act, false)
        t:truthy(string.format("ato %d: lâminas de tufo medidas (%d)", act, blades), blades > 50)
        t:eq(string.format("ato %d: tufo sem âncora de mundo", act), unseeded, 0)
        t:truthy(string.format("ato %d: lâmina acompanha a base (desvio máx %.2f px <= 1)", act, worst), worst <= 1)
        if act == 1 or act == 4 then
            local old = M.measure(act, true)
            t:truthy(string.format("ato %d: hash antigo pela posição de tela salta (%.2f px > 1, a trava pega)", act, old), old > 1)
        end
    end
    return t:done()
end

return M
