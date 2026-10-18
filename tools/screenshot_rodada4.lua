local M = {}

local VW, VH, TOP = 1920, 1080, 80

local function render(WorldRoad, bio, canvas)
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 1)
    WorldRoad.draw(0, TOP, VW, VH - TOP, bio)
    WorldRoad.drawOverlays(0, TOP, VW, VH - TOP)
    love.graphics.setCanvas()
end

local function prep(WorldRoad, bio, camZ, tod)
    WorldRoad.clearCache()
    WorldRoad.resetRun()
    love.math.setRandomSeed(7)
    WorldRoad.setBiome(bio)
    WorldRoad._blend = nil
    WorldRoad._prevBiomeIndex = nil
    WorldRoad._segBase = 0
    WorldRoad._birdTimer = 1e9
    WorldRoad._camZ = camZ
    for _ = 1, 30 do WorldRoad.update(1 / 30) end
    WorldRoad._camZ = camZ
    WorldRoad.setTimeOfDay(tod, true)
    WorldRoad.update(1 / 30)
end

local function sunOf(WorldRoad, Biomes, bio)
    if WorldRoad.sunXr then return WorldRoad.sunXr(Biomes[bio].id) end
    return Biomes[bio].celestial.xr
end

function M.run(arg)
    require("src.ui.PixelCanvas").enableNearest()
    love.graphics.getWidth = function() return VW end
    love.graphics.getHeight = function() return VH end
    love.graphics.getDimensions = function() return VW, VH end
    local WorldRoad = require("src.ui.WorldRoad")
    local Biomes = require("src.data.biomes")
    local label, mode = tostring(arg or "medida"):match("^([^:]+):?(.*)$")
    mode = (mode ~= "" and mode) or "andares"
    local dir = "rodada4/" .. label
    love.filesystem.createDirectory(dir)
    local realTime = love.timer.getTime
    love.timer.getTime = function() return 100 end
    local canvas = love.graphics.newCanvas(VW, VH)
    local rows = {}
    if mode == "andares" then
        for bio = 1, #Biomes do
            for f = 1, 8 do
                local camZ = (f - 1) * WorldRoad.TRAVEL_DISTANCE
                prep(WorldRoad, bio, camZ, 0.65)
                render(WorldRoad, bio, canvas)
                canvas:newImageData():encode("png", string.format("%s/b%d_f%d.png", dir, bio, f))
                rows[#rows + 1] = string.format("sol b%d f%d xr=%.4f px=%.1f", bio, f,
                    sunOf(WorldRoad, Biomes, bio), sunOf(WorldRoad, Biomes, bio) * VW)
            end
        end
    elseif mode == "viagem" then
        local bio = tonumber(os.getenv("RODADA4_BIO") or "1")
        for s = 0, 10 do
            local camZ = 2 * WorldRoad.TRAVEL_DISTANCE + s * WorldRoad.TRAVEL_DISTANCE / 10
            prep(WorldRoad, bio, camZ, 0.65)
            render(WorldRoad, bio, canvas)
            canvas:newImageData():encode("png", string.format("%s/b%d_s%02d.png", dir, bio, s))
        end
    end
    love.timer.getTime = realTime
    for _, r in ipairs(rows) do print(r) end
    print(love.filesystem.getSaveDirectory() .. "/" .. dir)
    love.event.quit()
    return true
end

return M
