local M = {}

local REL_CREST, T_POW = 26, 1.35

local function setupLandmark()
    local WorldRoad = require("src.ui.WorldRoad")
    local width, height = love.graphics.getDimensions()
    local topBarH = 80
    WorldRoad.clearCache()
    WorldRoad.resetRun()
    love.math.setRandomSeed(7)
    WorldRoad.setBiome(1)
    WorldRoad._blend = nil
    WorldRoad._prevBiomeIndex = nil
    WorldRoad._birdTimer = 1e9
    local function tick(n, draw)
        for _ = 1, n do
            WorldRoad.update(1 / 30)
            if draw then
                love.graphics.clear(0, 0, 0, 1)
                WorldRoad.draw(0, topBarH, width, height - topBarH, 1)
                WorldRoad.drawOverlays(0, topBarH, width, height - topBarH)
            end
        end
    end
    WorldRoad._camZ = 5.5
    tick(30, false)
    require("src.i18n.I18n").init()
    require("src.i18n.I18n").setLocale("en", true)
    local MM = require("src.systems.MapManager")
    local nodes = {}
    for i, ty in ipairs({ "battle", "rest", "shop" }) do
        nodes[i] = { type = ty, label = MM.labelFor(ty), desc = MM.descFor(ty) }
    end
    WorldRoad.showFork(nodes, function() end)
    tick(20, true)
    local f = WorldRoad._fork
    local b = f and f.markBoxes and f.markBoxes[2]
    if b then WorldRoad.forkMousePressed((b.x1 + b.x2) / 2, (b.y1 + b.y2) / 2) end
    tick(85, true)
    WorldRoad.setTimeOfDay(0.5, true)
    WorldRoad.update(1 / 30)
    love.graphics.clear(0, 0, 0, 1)
    WorldRoad.draw(0, topBarH, width, height - topBarH, 1)
    WorldRoad.drawOverlays(0, topBarH, width, height - topBarH)
    return WorldRoad, topBarH, height - topBarH
end

function M.run()
    require("src.ui.PixelCanvas").enableNearest()
    local realTime = love.timer.getTime
    love.timer.getTime = function() return 100 end
    local WorldRoad, y0, h = setupLandmark()
    local rows = {}
    for _, he in ipairs(WorldRoad._hitScene) do
        local p = he.ref
        local rel = p and p.z and (p.z - WorldRoad._camZ) or nil
        local t = rel and (1 - rel / REL_CREST)
        if t and t >= 0 then t = math.min(1, t) ^ T_POW end
        rows[#rows + 1] = string.format("%-9s t=%5.2f rel=%5.1f big=%4.2f  h=%4.0f w=%4.0f  base=%4.0f  x=%4.0f",
            he.kind, t or -1, rel or -1, p and p.big or 1,
            he.y2 - he.y1, he.x2 - he.x1, he.y2 - y0, (he.x1 + he.x2) / 2)
    end
    table.sort(rows)
    for _, r in ipairs(rows) do print(r) end
    print(string.format("area h=%d crest=%d  tree@t=1 target=%.0f px  persp(0.5)=%.3f persp(0.25)=%.3f",
        h, math.floor(h * 0.40), 4.6 * h * 0.115 * 1.25, 0.14 + 0.86 * 0.5 ^ 1.65, 0.14 + 0.86 * 0.25 ^ 1.65))
    love.timer.getTime = realTime
    love.event.quit()
    return true
end

return M
