local TK = require("tools.testkit")
local M = {}

local function poolPixels(Lum, tod, bid)
    local cv = love.graphics.newCanvas(256, 128)
    love.graphics.push("all")
    love.graphics.setCanvas(cv)
    love.graphics.clear(0, 0, 0, 1)
    Lum.drawPool(bid, Lum.catalog(bid).lantern and "lantern" or "brazier",
        { gx = 128, gy = 64, flameH = 80, t = 1, seed = 3, capR = 1e9, alphaK = 1, tod = tod })
    love.graphics.setCanvas()
    love.graphics.pop()
    local d = cv:newImageData()
    local lit, maxV, up, down = 0, 0, 0, 0
    local levels = {}
    for y = 0, 127 do
        for x = 0, 255 do
            local r, g, b = d:getPixel(x, y)
            local v = math.max(r, g, b)
            if v > 0.002 then
                lit = lit + 1
                if y < 64 then up = up + 1 else down = down + 1 end
                levels[math.floor(v * 255 + 0.5)] = true
            end
            maxV = math.max(maxV, v)
        end
    end
    local nLevels = 0
    for _ in pairs(levels) do nLevels = nLevels + 1 end
    return lit, maxV, up, down, nLevels
end

function M.run()
    local t = TK.new("Poça emissiva das luminárias: aditiva, posterizada, só ao entardecer")
    local Lum = require("engine.LuminaireEngine")
    local LightEngine = require("engine.LightEngine")
    LightEngine.setEnabled(true)
    for _, bid in ipairs({ "fields", "abyss", "dusk" }) do
        local litDay = poolPixels(Lum, 0.30, bid)
        t:eq(bid .. ": de dia a poça não acende", litDay, 0)
        local lit, maxV, up, down, nLevels = poolPixels(Lum, 1.0, bid)
        t:truthy(bid .. ": ao anoitecer a poça acende", lit > 200)
        t:truthy(bid .. ": intensidade natural (pico <= 0,35)", maxV <= 0.35)
        t:truthy(bid .. ": posterizada (poucos degraus, sem gradiente liso)", nLevels <= 4)
        t:truthy(bid .. ": mais chão na frente da base que atrás", down > up * 1.5)
        local _, maxMid = poolPixels(Lum, 0.65, bid)
        t:truthy(bid .. ": cresce com o entardecer", maxMid < maxV)
    end
    LightEngine.setEnabled(false)
    t:eq("iluminação desligada: sem poça", (poolPixels(Lum, 1.0, "fields")), 0)
    LightEngine.setEnabled(nil)
    return t:done()
end

return M
