local M = {}

local WorldRoad = require("src.ui.WorldRoad")
local LightEngine = require("engine.LightEngine")

local TOP_BAR = 80

local function renderFrame(bio, noLights, w, h)
    LightEngine.debugNoLights = noLights and true or false
    WorldRoad.clearCache()
    WorldRoad.setBiome(bio)
    WorldRoad._camZ = 5.5
    for _ = 1, 30 do WorldRoad.update(1 / 30) end
    WorldRoad._blend = nil
    WorldRoad._prevBiomeIndex = nil
    love.graphics.clear(0, 0, 0, 1)
    WorldRoad.draw(0, TOP_BAR, w, h - TOP_BAR, bio)
    WorldRoad.drawOverlays(0, TOP_BAR, w, h - TOP_BAR)
end

local function reportAmbient(bio)
    local b = require("src.data.biomes")[bio]
    local function luma(t)
        return 0.2126 * t[1] + 0.7152 * t[2] + 0.0722 * t[3]
    end
    local d, n = b.lightDay, b.lightNight
    local function lerp(t)
        return { d[1] + (n[1] - d[1]) * t,
                 d[2] + (n[2] - d[2]) * t,
                 d[3] + (n[3] - d[3]) * t }
    end
    local l1, lb = luma(lerp(0.62)), luma(n)
    print(string.format(
        "[pool] ambiente de '%s': andar 1 (tod .62) luma %.3f | boss (tod 1) luma %.3f",
        b.id, l1, lb))
    print(string.format(
        "[pool] piso MIN_AMBIENT_LUMA 0.35: %s  |  gate de glow (<0.75): %s",
        (math.min(l1, lb) >= 0.35) and "OK" or "VIOLADO",
        (lb < 0.75) and "dispara" or "NUNCA dispara"))
end

function M.run(arg)
    require("src.ui.PixelCanvas").enableNearest()
    local bio = tonumber(arg) or 4
    local w, h = love.graphics.getDimensions()

    reportAmbient(bio)

    local shots = {}
    for i, noLights in ipairs({ false, true }) do
        renderFrame(bio, noLights, w, h)
        local name = noLights and "lightpool_off.png" or "lightpool_on.png"
        love.graphics.captureScreenshot(function(imageData)
            imageData:encode("png", name)
            shots[i] = imageData
            print("[pool] salvo: " .. name)
        end)
        love.graphics.present()
    end
    LightEngine.debugNoLights = false

    love.graphics.present()
    if not (shots[1] and shots[2]) then
        print("[pool] ERRO: capturas nao resolveram; rode de novo")
        love.event.quit()
        return
    end

    local onI, offI = shots[1], shots[2]
    local diff = love.image.newImageData(w, h)
    local maxD, sumD = 0, 0
    local bandTop, bandGround = 0, 0
    local crestY = h * 0.52
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local r1, g1, b1 = onI:getPixel(x, y)
            local r2, g2, b2 = offI:getPixel(x, y)
            local d = math.max(math.abs(r1 - r2),
                               math.abs(g1 - g2), math.abs(b1 - b2))
            if d > maxD then maxD = d end
            sumD = sumD + d
            if y < crestY then bandTop = bandTop + d
            else bandGround = bandGround + d end
            local v = math.min(1, d * 6)
            diff:setPixel(x, y, v, v, v, 1)
        end
    end
    diff:encode("png", "lightpool_diff.png")

    local total = bandTop + bandGround
    print(string.format("[pool] delta MAXIMO: %.1f/255  (criterio de sucesso: >= 12)",
        maxD * 255))
    print(string.format("[pool] delta MEDIO: %.2f/255", sumD / (w * h) * 255))
    if total > 0 then
        print(string.format(
            "[pool] energia da diferenca: CHAO %.1f%%  |  ACIMA DA CRISTA %.1f%%",
            bandGround / total * 100, bandTop / total * 100))
    end
    print(string.format("[pool] VEREDITO: %s",
        (maxD * 255 >= 12) and "PASSOU (poca visivel)" or "REPROVOU (poca invisivel)"))
    love.event.quit()
end

return M
