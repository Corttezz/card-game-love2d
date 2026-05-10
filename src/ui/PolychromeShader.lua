-- src/ui/PolychromeShader.lua
-- Wrapper do shaders/polychrome.glsl. Edition "Polychrome": hue cycle saturado.
-- Mais agressivo que Holo (substitui mais cor da carta).
--
-- Uso: PolychromeShader.draw(cardImage, x, y, 0.7)

local PolychromeShader = {}

local shader
local loaded = false

function PolychromeShader.load()
    local ok, s = pcall(love.graphics.newShader, "shaders/polychrome.glsl")
    if not ok then
        print("[PolychromeShader] falha ao carregar shaders/polychrome.glsl: " .. tostring(s))
        return false
    end
    shader = s
    loaded = true
    return true
end

function PolychromeShader.isAvailable()
    return loaded
end

function PolychromeShader.draw(image, x, y, strength, rotation, sx, sy, ox, oy)
    if not loaded then
        love.graphics.draw(image, x, y, rotation or 0, sx or 1, sy or 1, ox or 0, oy or 0)
        return
    end
    love.graphics.setShader(shader)
    shader:send("time", love.timer.getTime())
    shader:send("strength", math.max(0, math.min(1, strength or 0.7)))
    love.graphics.draw(image, x, y, rotation or 0, sx or 1, sy or 1, ox or 0, oy or 0)
    love.graphics.setShader()
end

return PolychromeShader
