-- tools/screenshot_weather.lua
-- Captura o CLIMA do WorldRoad (WeatherEngine) num bioma, já assentado
-- (8 s simulados com draw a cada frame — a projeção precisa do frame).
--
--   love . test_one screenshot_weather 4                 (geleira, janela atual)
--   love . test_one screenshot_weather 2:1920x1080:strike (raio no quadro)
--   love . test_one screenshot_weather 2:storm            (pico da tempestade)
--   love . test_one screenshot_weather 4:off              (A/B: clima desligado)
--   love . test_one screenshot_weather 4:travel           (viajando — o clima vem em você)
--
-- Saída: weather_<bioma>[_<modo>].png no save dir.

local M = {}

function M.run(arg)
    local bio, size, modes = 1, nil, {}
    for part in tostring(arg or "1"):gmatch("[^:]+") do
        if part:match("^%d+x%d+$") then size = part
        elseif part:match("^%d$") then bio = tonumber(part)
        else modes[part] = true end
    end
    if size then
        local w, h = size:match("(%d+)x(%d+)")
        love.window.setMode(tonumber(w), tonumber(h))
    end
    require("src.ui.PixelCanvas").enableNearest()
    local WorldRoad = require("src.ui.WorldRoad")
    local WeatherEngine = require("engine.WeatherEngine")
    WeatherEngine.disabled = modes.off == true
    if modes.storm or modes.strike then WeatherEngine.setIntensityOverride(1) end

    local width, height = love.graphics.getDimensions()
    local topBarH = math.floor(height * 0.08)
    WorldRoad.clearCache()
    WorldRoad.setBiome(bio)
    WorldRoad.setTimeOfDay(0.8, true)
    WorldRoad._camZ = 5.5
    local function frame()
        love.graphics.clear(0, 0, 0, 1)
        WorldRoad.draw(0, topBarH, width, height - topBarH, bio)
        WorldRoad.drawOverlays(0, topBarH, width, height - topBarH)
        love.graphics.setColor(0.1, 0.08, 0.06, 1)
        love.graphics.rectangle("fill", 0, 0, width, topBarH)
        love.graphics.setColor(1, 1, 1, 1)
    end
    for i = 1, 240 do
        WorldRoad.update(1 / 30)
        if i == 2 then WorldRoad._blend = nil; WorldRoad._prevBiomeIndex = nil end
        if modes.travel and i == 200 then
            WorldRoad.travel({ distance = 28, duration = 6.5 })
        end
        frame()
        love.graphics.present()
    end
    if modes.strike then
        WeatherEngine.strike(0.30)
        WorldRoad.update(0.02)
    end
    frame()
    print(string.format("[weather] ms update %.3f  sort %.3f  build %.3f", WeatherEngine.stats.msUpdate or -1, WeatherEngine.stats.msSort or -1, WeatherEngine.stats.msBuild or -1))
    print(string.format("[weather] bioma %d  partículas %d  quads %d  fatias %d  flash %.2f",
        bio, WeatherEngine.count(), WeatherEngine.stats.quads,
        WeatherEngine.stats.flushes, WeatherEngine.flash()))
    if modes.dbg then
        local P, n = WeatherEngine._particles()
        local hist = {}
        for i = 1, n do
            local p = P[i]
            local k = (p.st == 1 and "pous" or "ar") .. (p.fg and "FG" or "")
                .. string.format("_rel%02d", math.floor((p.z - WorldRoad._camZ) / 4) * 4)
            hist[k] = (hist[k] or 0) + 1
        end
        for k, v in pairs(hist) do print("[dbg]", k, v) end
        for i = 1, math.min(8, n) do
            local p = P[i]
            print(string.format("[dbg] lx %.2f rel %.1f hg %.3f vf %.3f st %d",
                p.lx, p.z - WorldRoad._camZ, p.hg, p.vf, p.st))
        end
    end
    local suffix = ""
    for _, k in ipairs({ "storm", "strike", "off", "travel" }) do
        if modes[k] then suffix = suffix .. "_" .. k end
    end
    local name = "weather_" .. bio .. suffix .. ".png"
    local done = false
    love.graphics.captureScreenshot(function(imageData)
        imageData:encode("png", name)
        print("[screenshot] salvo em save-dir: " .. name)
        done = true
    end)
    love.graphics.present()
    -- captureScreenshot dispara no present; garante a escrita antes de sair
    if not done then frame(); love.graphics.present() end
    WeatherEngine.setIntensityOverride(nil)
    return true
end

return M
