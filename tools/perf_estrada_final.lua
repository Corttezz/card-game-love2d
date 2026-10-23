local M = {}

function M.run(arg)
    local vw, vh = (os.getenv("ESTRADA_VIRTUAL") or "1920x1080"):match("^(%d+)x(%d+)$")
    vw, vh = tonumber(vw), tonumber(vh)
    love.graphics.getWidth = function() return vw end
    love.graphics.getHeight = function() return vh end
    love.graphics.getDimensions = function() return vw, vh end
    _G.EventManager = _G.EventManager or require("engine.EventManager")
    _G.Event = _G.Event or require("engine.Event")
    local WorldRoad = require("src.ui.WorldRoad")
    local canvas = love.graphics.newCanvas(vw, vh)
    local topBarH = 52
    local function frame(bio)
        WorldRoad.update(1 / 60)
        love.graphics.setCanvas(canvas)
        love.graphics.clear(0, 0, 0, 1)
        WorldRoad.draw(0, topBarH, vw, vh - topBarH, bio)
        WorldRoad.drawOverlays(0, topBarH, vw, vh - topBarH)
        love.graphics.setCanvas()
    end
    WorldRoad.clearCache()
    WorldRoad.resetRun()
    WorldRoad._birdTimer = 1e9
    local rows = {}
    local ok = true
    for bio = 1, 6 do
        local B = require("src.data.biomes")[bio]
        local tb = love.timer.getTime()
        require("engine.RoadTiles").bake(B.id, B)
        rows[#rows + 1] = string.format("ato%d bake do tile %.0f ms", bio, (love.timer.getTime() - tb) * 1000)
        print(rows[#rows])
        WorldRoad.setBiome(bio)
        WorldRoad._blend = nil
        WorldRoad._prevBiomeIndex = nil
        for _ = 1, 4000 do
            if WorldRoad.isPrewarmed(bio) then break end
            WorldRoad.prewarmTick(0.05)
        end
        for _ = 1, 240 do frame(bio) end
        WorldRoad._blend = nil
        for _, v in ipairs({ "trilha", "encruzilhada" }) do
            if v == "encruzilhada" then
                WorldRoad.showFork({ { type = "battle" }, { type = "rest" }, { type = "shop" } }, function() end)
            end
            for _ = 1, 60 do frame(bio) end
            local s0 = love.graphics.getStats().drawcalls
            frame(bio)
            local dc = love.graphics.getStats().drawcalls - s0
            local samples = {}
            for r = 1, 3 do
                collectgarbage("collect")
                collectgarbage("stop")
                local k0 = collectgarbage("count")
                for _ = 1, 30 do frame(bio) end
                samples[r] = (collectgarbage("count") - k0) / 30
                collectgarbage("restart")
            end
            table.sort(samples)
            local t0 = love.timer.getTime()
            for _ = 1, 30 do
                WorldRoad._camZ = WorldRoad._camZ + 0.05
                frame(bio)
            end
            love.graphics.getStats()
            local ms = (love.timer.getTime() - t0) / 30 * 1000
            local line = string.format("ato%d %-12s dc=%d alloc=%.1fKB ms_andando=%.2f", bio, v, dc, samples[2], ms)
            rows[#rows + 1] = line
            print(line)
            if dc > 600 or samples[2] > 40 then ok = false end
        end
        WorldRoad._fork = nil
    end
    local f = love.filesystem.newFile("perf_estrada_final.txt", "w")
    f:write(table.concat(rows, "\n"))
    f:close()
    print(ok and "[ok] orcamento de draw calls e alocacao" or "[FAIL] orcamento estourado")
    canvas:release()
    love.event.quit(ok and 0 or 1)
    return ok
end

return M
