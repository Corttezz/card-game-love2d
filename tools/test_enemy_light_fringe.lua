local TK = require("tools.testkit")
local M = {}

local FLAT = { 0.85, 0.85, 0.85 }

local function render(LightEngine, mode, ox, oy)
    local cv = love.graphics.newCanvas(96, 96)
    local d = love.image.newImageData(10, 14)
    d:mapPixel(function() return 1, 1, 1, 1 end)
    local img = love.graphics.newImage(d)
    img:setFilter("nearest", "nearest")
    love.graphics.push("all")
    love.graphics.setCanvas(cv)
    love.graphics.clear(1, 1, 1, 1)
    LightEngine.beginFrame({ 0.4, 0.4, 0.4 })
    LightEngine.submit({ x = 48, y = 48, radius = 400, color = { 1, 0.6, 0.2 }, intensity = 0.3, z = 100 })
    if mode ~= "none" then
        LightEngine.submitOccluder({ z = 0, flatColor = FLAT, cover = (mode == "cover"),
            img = img, x = ox, y = oy, sx = 1, sy = 1, bx = ox, by = oy, w = 10, h = 14 })
    end
    LightEngine.composite(0, 0, 96, 96)
    love.graphics.setCanvas()
    love.graphics.pop()
    return cv:newImageData()
end

local function bodyDev(data, ox, oy)
    local worst = 0
    for y = oy, oy + 13 do
        for x = ox, ox + 9 do
            local r, g, b = data:getPixel(x, y)
            worst = math.max(worst, math.abs(r - FLAT[1]), math.abs(g - FLAT[2]), math.abs(b - FLAT[3]))
        end
    end
    return worst
end

local function ringDev(data, ref, ox, oy)
    local worst = 0
    for y = oy - 4, oy + 17 do
        for x = ox - 4, ox + 13 do
            local inside = x >= ox and x <= ox + 9 and y >= oy and y <= oy + 13
            if not inside and x >= 0 and y >= 0 and x < 96 and y < 96 then
                local r, g, b = data:getPixel(x, y)
                local r2, g2, b2 = ref:getPixel(x, y)
                worst = math.max(worst, math.abs(r - r2), math.abs(g - g2), math.abs(b - b2))
            end
        end
    end
    return worst
end

function M.run()
    local t = TK.new("Monstro sem franja de luz: corpo com a luz dele, chão em volta com a luz da cena, pixel a pixel")
    local LightEngine = require("engine.LightEngine")
    LightEngine.setEnabled(true)
    local ref = render(LightEngine, "none", 0, 0)
    local bodyCover, bodyPlain, ringCover, ringPlain = 0, 0, 0, 0
    for _, o in ipairs({ { 13, 13 }, { 14, 15 }, { 21, 30 }, { 41, 18 }, { 43, 43 } }) do
        local c = render(LightEngine, "cover", o[1], o[2])
        local p = render(LightEngine, "plain", o[1], o[2])
        bodyCover = math.max(bodyCover, bodyDev(c, o[1], o[2]))
        bodyPlain = math.max(bodyPlain, bodyDev(p, o[1], o[2]))
        ringCover = math.max(ringCover, ringDev(c, ref, o[1], o[2]))
        ringPlain = math.max(ringPlain, ringDev(p, ref, o[1], o[2]))
    end
    t:truthy(("controle: oclusor de 1/4 erra a borda (corpo %.2f, chão %.2f)"):format(bodyPlain, ringPlain),
        bodyPlain > 0.05 or ringPlain > 0.05)
    t:truthy(("corpo inteiro com a luz dele (desvio %.3f)"):format(bodyCover), bodyCover <= 0.01)
    t:truthy(("chão em volta igual a sem monstro: nenhum contorno claro (desvio %.3f)"):format(ringCover),
        ringCover <= 0.01)
    LightEngine.setEnabled(nil)
    return t:done()
end

return M
