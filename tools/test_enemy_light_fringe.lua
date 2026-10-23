local TK = require("tools.testkit")
local M = {}

local function render(LightEngine, cover, ox, oy)
    local cv = love.graphics.newCanvas(96, 96)
    local d = love.image.newImageData(10, 14)
    d:mapPixel(function() return 1, 1, 1, 1 end)
    local img = love.graphics.newImage(d)
    img:setFilter("nearest", "nearest")
    love.graphics.push("all")
    love.graphics.setCanvas(cv)
    love.graphics.clear(1, 1, 1, 1)
    LightEngine.beginFrame({ 0.4, 0.4, 0.4 })
    LightEngine.submit({ x = 48, y = 48, radius = 400, color = { 1, 0.6, 0.2 }, intensity = 1, z = 100 })
    LightEngine.submitOccluder({ z = 0, flatColor = { 0.4, 0.4, 0.4 }, cover = cover,
        img = img, x = ox, y = oy, sx = 1, sy = 1, bx = ox, by = oy, w = 10, h = 14 })
    LightEngine.composite(0, 0, 96, 96)
    love.graphics.setCanvas()
    love.graphics.pop()
    local out = cv:newImageData()
    local worst = 0
    for y = oy, oy + 13 do
        for x = ox, ox + 9 do
            local r, g, b = out:getPixel(x, y)
            worst = math.max(worst, math.abs(r - 0.4), math.abs(g - 0.4), math.abs(b - 0.4))
        end
    end
    return worst
end

function M.run()
    local t = TK.new("Monstro sem franja de luz: oclusor cobre a borda inteira no lightmap de 1/4")
    local LightEngine = require("engine.LightEngine")
    LightEngine.setEnabled(true)
    local maxCover, maxPlain = 0, 0
    for _, o in ipairs({ { 13, 13 }, { 14, 15 }, { 21, 30 }, { 41, 18 }, { 43, 43 } }) do
        maxCover = math.max(maxCover, render(LightEngine, true, o[1], o[2]))
        maxPlain = math.max(maxPlain, render(LightEngine, false, o[1], o[2]))
    end
    t:truthy(("sem cobertura a luz vaza na borda (controle, desvio %.2f)"):format(maxPlain), maxPlain > 0.05)
    t:truthy(("com cobertura nenhum pixel do corpo recebe luz da cena (desvio %.3f)"):format(maxCover), maxCover <= 0.01)
    LightEngine.setEnabled(nil)
    return t:done()
end

return M
