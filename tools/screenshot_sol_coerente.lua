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
    WorldRoad._birdTimer = 1e9
    WorldRoad._camZ = camZ
    for _ = 1, 30 do WorldRoad.update(1 / 30) end
    WorldRoad._camZ = camZ
    WorldRoad.setTimeOfDay(tod, true)
    WorldRoad.update(1 / 30)
end

function M.run(arg)
    require("src.ui.PixelCanvas").enableNearest()
    love.graphics.getWidth = function() return VW end
    love.graphics.getHeight = function() return VH end
    love.graphics.getDimensions = function() return VW, VH end
    local WorldRoad = require("src.ui.WorldRoad")
    local Biomes = require("src.data.biomes")
    local label = tostring(arg or "medida")
    local dir = "sol_coerente/" .. label
    love.filesystem.createDirectory(dir)
    local realTime = love.timer.getTime
    love.timer.getTime = function() return 100 end
    local canvas = love.graphics.newCanvas(VW, VH)
    local rows = {}
    for bio = 1, #Biomes do
        local cel = Biomes[bio].celestial
        local keep = cel.color
        for f = 1, 8 do
            local camZ = (f - 1) * WorldRoad.TRAVEL_DISTANCE
            prep(WorldRoad, bio, camZ, 0.65)
            render(WorldRoad, bio, canvas)
            local data = canvas:newImageData()
            data:encode("png", string.format("%s/deriva_b%d_f%d.png", dir, bio, f))
            cel.color = { 1, 0, 1 }
            render(WorldRoad, bio, canvas)
            local md = canvas:newImageData()
            local n = 0
            for yy = 0, VH - 1, 2 do
                for xx = 0, VW - 1, 2 do
                    local r, g, b = md:getPixel(xx, yy)
                    if r > 0.9 and g < 0.15 and b > 0.9 then n = n + 1 end
                end
            end
            cel.color = keep
            rows[#rows + 1] = string.format("disco b%d f%d magenta=%d", bio, f, n)
        end
    end
    for bio = 1, #Biomes do
        for _, tod in ipairs({ 0.65, 0.95 }) do
            prep(WorldRoad, bio, 5.5, tod)
            require("src.i18n.I18n").init()
            local MM = require("src.systems.MapManager")
            local nodes = {}
            for i, ty in ipairs({ "battle", "rest", "shop" }) do
                nodes[i] = { type = ty, label = MM.labelFor(ty), desc = MM.descFor(ty) }
            end
            WorldRoad.showFork(nodes, function() end)
            for _ = 1, 20 do WorldRoad.update(1 / 30) end
            WorldRoad.setTimeOfDay(tod, true)
            WorldRoad.update(1 / 30)
            render(WorldRoad, bio, canvas)
            canvas:newImageData():encode("png", string.format("%s/fork_b%d_t%s.png", dir, bio, tostring(tod)))
        end
    end
    love.timer.getTime = realTime
    for _, r in ipairs(rows) do print(r) end
    print(love.filesystem.getSaveDirectory() .. "/" .. dir)
    love.event.quit()
    return true
end

return M
