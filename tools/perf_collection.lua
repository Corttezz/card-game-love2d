local M = {}

local function pct(sorted, p)
    if #sorted == 0 then return 0 end
    local i = math.max(1, math.min(#sorted, math.floor(#sorted * p + 0.5)))
    return sorted[i]
end

function M.run(frames)
    frames = tonumber(frames) or 240
    local I18n = require("src.i18n.I18n")
    I18n.init()
    require("src.ui.PixelCanvas").enableNearest()
    pcall(love.window.setVSync, 0)
    local CardFrame = require("src.ui.CardFrame")
    local CollectionScreen = require("components.CollectionScreen")
    local okU, UnlockSystem = pcall(require, "src.systems.UnlockSystem")
    if okU and UnlockSystem.setRevealAll then UnlockSystem.setRevealAll(true) end

    local screen = CollectionScreen:new()
    screen:show(function() end)
    local guard = 0
    while not screen._buildDone and guard < 2000 do
        screen:_buildInstances(0.05); guard = guard + 1
    end

    local W, H = love.graphics.getDimensions()
    local origGetPos = love.mouse.getPosition
    local results = {}

    do
        love.mouse.getPosition = function() return 5, 5 end
        screen.scrollY = 0
        local worst, lastGrow, visibleAnimated = 0, 0, 0
        for f = 1, 300 do
            local before = CardFrame._liveCount()
            local t0 = love.timer.getTime()
            CardFrame.update()
            screen:update(1 / 60)
            love.graphics.clear(0, 0, 0, 1)
            screen:draw()
            local ms = (love.timer.getTime() - t0) * 1000
            if f > 2 and ms > worst then worst = ms end
            love.graphics.present()
            if CardFrame._liveCount() > before then lastGrow = f end
            if f - lastGrow >= 20 and f > 20 then break end
        end
        visibleAnimated = CardFrame._liveCount()
        local line = string.format(
            "[perf_collection] warmup  %d cartas vivas em %d quadros | pior quadro %.2fms | BUILD_PER_FRAME %d | camadas em espera %d",
            visibleAnimated, lastGrow, worst, CardFrame.BUILD_PER_FRAME, CardFrame._layerCount())
        print(line)
        results[#results + 1] = line
    end

    local function scenario(name, setup)
        local cpu, tot = {}, {}
        local stats = { drawcalls = 0, canvasswitches = 0, shaderswitches = 0 }
        for f = 1, frames do
            local mx, my = setup(f)
            love.mouse.getPosition = function() return mx, my end
            local t0 = love.timer.getTime()
            CardFrame.update()
            screen:update(1 / 60)
            love.graphics.clear(0, 0, 0, 1)
            screen:draw()
            local s = love.graphics.getStats()
            local t1 = love.timer.getTime()
            love.graphics.present()
            local t2 = love.timer.getTime()
            if f > 10 then
                cpu[#cpu + 1] = (t1 - t0) * 1000
                tot[#tot + 1] = (t2 - t0) * 1000
                stats.drawcalls = stats.drawcalls + s.drawcalls
                stats.canvasswitches = stats.canvasswitches + s.canvasswitches
                stats.shaderswitches = stats.shaderswitches + s.shaderswitches
            end
        end
        local n = #cpu
        local sc, st = 0, 0
        for i = 1, n do sc = sc + cpu[i]; st = st + tot[i] end
        table.sort(cpu); table.sort(tot)
        local line = string.format(
            "[perf_collection] %-7s cpu avg %.2fms p95 %.2fms max %.1fms | total avg %.2fms p95 %.2fms | drawcalls/f %.0f canvasSw/f %.1f shaderSw/f %.1f",
            name, sc / n, pct(cpu, 0.95), cpu[n], st / n, pct(tot, 0.95),
            stats.drawcalls / n, stats.canvasswitches / n, stats.shaderswitches / n)
        print(line)
        results[#results + 1] = line
    end

    screen.scrollY = 0
    scenario("idle", function() return 5, 5 end)
    scenario("hover", function(f)
        local i = math.floor(f / 6) % 15
        local col, row = i % 5, math.floor(i / 5)
        local ox = (W - (5 * 128 + 4 * 18)) / 2
        return ox + col * 146 + 64, 120 + row * 216 + 96
    end)
    scenario("scroll", function(f)
        screen.scrollY = (f * 7) % math.max(1, screen.maxScrollY)
        return W / 2, H / 2
    end)

    love.mouse.getPosition = origGetPos
    if okU and UnlockSystem.setRevealAll then UnlockSystem.setRevealAll(false) end
    pcall(love.filesystem.write, "perf_collection.txt", table.concat(results, "\n") .. "\n")
    return true
end

return M
