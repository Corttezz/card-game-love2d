-- src/ui/FoilShader.lua
-- Wrapper do shaders/foil.glsl. Edition "Foil": brilho metálico frio.
-- Diferente de Holo (rainbow) — Foil é prata-azulada, mais sutil.
--
-- Uso típico em Card:draw quando card.edition == "foil":
--   FoilShader.draw(cardImage, x, y, 0.6)

local FoilShader = {}

local shader
local loaded = false

function FoilShader.load()
    local ok, s = pcall(love.graphics.newShader, "shaders/foil.glsl")
    if not ok then
        print("[FoilShader] falha ao carregar shaders/foil.glsl: " .. tostring(s))
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
