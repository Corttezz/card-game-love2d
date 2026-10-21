local M = {}

local VW, VH = 1920, 1080
local TOPBAR = 80

function M.run(arg)
    local act, what = tostring(arg or "1"):match("^(%d)[:]?(.*)$")
    act = tonumber(act) or 1
    local tag = os.getenv("TUFOS_TAG") or "raw"
    local dir = string.format("tufos_viagem/%s/ato%d", tag, act)
    love.filesystem.createDirectory(dir)
    require("src.ui.PixelCanvas").enableNearest()
    local realTime = love.timer.getTime
    love.timer.getTime = function() return 100 end
    local cv = love.graphics.newCanvas(VW, VH)
    love.graphics.getWidth = function() return VW end
    love.graphics.getHeight = function() return VH end
    love.graphics.getDimensions = function() return VW, VH end
    local GrassField = require("engine.GrassField")
    GrassField._legacyTuftHash = os.getenv("TUFOS_OLD") == "1" or nil
    local LE = require("engine.LuminaireEngine")
    local WorldRoad = require("src.ui.WorldRoad")
    WorldRoad.clearCache()
    WorldRoad.resetRun()
    love.math.setRandomSeed(7)
    WorldRoad.setBiome(act)
    WorldRoad._blend = nil
    WorldRoad._prevBiomeIndex = nil
    WorldRoad._birdTimer = 1e9
    WorldRoad.setTimeOfDay(0.5, true)
    local function frame()
        love.graphics.setCanvas(cv)
        love.graphics.clear(0, 0, 0, 1)
        WorldRoad.draw(0, TOPBAR, VW, VH - TOPBAR, act)
        love.graphics.setCanvas()
    end
    WorldRoad._camZ = 5.5
    for _ = 1, 20 do WorldRoad.update(1 / 30) end
    frame()
    local roadKind = LE.roadKind(require("src.data.biomes")[act].id)
    local target = os.getenv("TUFOS_KIND") or roadKind
    WorldRoad.travel({ distance = WorldRoad.TRAVEL_DISTANCE })
    local ref
    local saved = 0
    for i = 1, 90 do
        WorldRoad.update(1 / 30)
        frame()
        if not ref then
            local best
            for _, he in ipairs(WorldRoad._hitScene or {}) do
                if he.kind == target and he.y2 > VH * 0.62 and he.y2 < VH * 0.80 and he.ref then
                    if not best or he.y2 > best.y2 then best = he end
                end
            end
            ref = best and best.ref
        end
        if ref then
            local he
            for _, h in ipairs(WorldRoad._hitScene or {}) do if h.ref == ref then he = h end end
            if not he or saved >= 12 then break end
            local cx = math.floor((he.x1 + he.x2) / 2)
            local by = math.floor(he.y2)
            local x1, y1 = math.max(0, cx - 70), math.max(0, by - 60)
            local x2, y2 = math.min(VW, cx + 70), math.min(VH, by + 14)
            local data = cv:newImageData()
            local crop = love.image.newImageData(x2 - x1, y2 - y1)
            crop:paste(data, 0, 0, x1, y1, x2 - x1, y2 - y1)
            saved = saved + 1
            crop:encode("png", string.format("%s/f%02d.png", dir, saved))
            crop:release()
            data:release()
        end
    end
    love.timer.getTime = realTime
    print(love.filesystem.getSaveDirectory() .. "/" .. dir .. " " .. saved .. " " .. tostring(target))
    love.event.quit()
    return true
end

return M
