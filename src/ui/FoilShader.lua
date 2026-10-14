local Debug = require("src.core.Debug")

local FoilShader = {}

local shader
local loaded = false

function FoilShader.load()
    local ok, s = pcall(love.graphics.newShader, "shaders/foil.glsl")
    if not ok then
        Debug.warn("[FoilShader] falha ao carregar shaders/foil.glsl: " .. tostring(s))
        return false
    end
    shader = s
    loaded = true
    return true
end

function FoilShader.isAvailable()
    return loaded
end

function FoilShader.draw(image, x, y, strength, rotation, sx, sy, ox, oy)
    if not loaded then
        love.graphics.draw(image, x, y, rotation or 0, sx or 1, sy or 1, ox or 0, oy or 0)
        return
    end
    love.graphics.setShader(shader)
    shader:send("time", love.timer.getTime())
    shader:send("strength", math.max(0, math.min(1, strength or 0.6)))
    love.graphics.draw(image, x, y, rotation or 0, sx or 1, sy or 1, ox or 0, oy or 0)
    love.graphics.setShader()
end

return FoilShader
