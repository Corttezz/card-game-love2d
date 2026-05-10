-- src/ui/NegativeShader.lua
-- Wrapper do shaders/negative.glsl. Edition "Negative": cores invertidas + halo.
-- Carta "espectral" — visual mais escuro/sombrio que as outras editions.
--
-- Uso: NegativeShader.draw(cardImage, x, y, 1.0)

local NegativeShader = {}

local shader
local loaded = false

function NegativeShader.load()
    local ok, s = pcall(love.graphics.newShader, "shaders/negative.glsl")
    if not ok then
        print("[NegativeShader] falha ao carregar shaders/negative.glsl: " .. tostring(s))
        return false
    end
    shader = s
    loaded = true
    return true
end

function NegativeShader.isAvailable()
    return loaded
end

function NegativeShader.draw(image, x, y, strength, rotation, sx, sy, ox, oy)
    if not loaded then
        love.graphics.draw(image, x, y, rotation or 0, sx or 1, sy or 1, ox or 0, oy or 0)
        return
    end
    love.graphics.setShader(shader)
    shader:send("time", love.timer.getTime())
    shader:send("strength", math.max(0, math.min(1, strength or 1.0)))
    love.graphics.draw(image, x, y, rotation or 0, sx or 1, sy or 1, ox or 0, oy or 0)
    love.graphics.setShader()
end

return NegativeShader
