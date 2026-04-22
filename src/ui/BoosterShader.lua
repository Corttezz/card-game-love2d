-- src/ui/BoosterShader.lua
-- Wrapper do shaders/booster.glsl. Aplica textura iridescente azul-prata
-- animada sobre uma imagem de carta — usado em "cartas seladas" / pacotes.
--
-- Uso:
--   BoosterShader.apply(image, phase, dissolve)
--   love.graphics.draw(image, ...)
--   BoosterShader.clear()
--
-- phase: number (fase da animação iridescente; passe love.timer.getTime()
--        pra animação contínua, ou um valor fixo pra freeze)
-- dissolve: 0..1 — combina com dissolve mask (opcional, default 0)

local BoosterShader = {}

local shader
local loaded = false

function BoosterShader.load()
    local ok, s = pcall(love.graphics.newShader, "shaders/booster.glsl")
    if not ok then
        print("[BoosterShader] falha ao carregar shaders/booster.glsl: " .. tostring(s))
        return false
    end
    shader = s
    loaded = true
    return true
end

function BoosterShader.isAvailable()
    return loaded
end

function BoosterShader.apply(image, phase, dissolve)
    if not loaded then return false end
    love.graphics.setShader(shader)
    shader:send("booster", {phase or love.timer.getTime(), 0})
    shader:send("dissolve", dissolve or 0)
    shader:send("time", love.timer.getTime())
    shader:send("texture_details", {0, 0, image:getWidth(), image:getHeight()})
    shader:send("image_details", {image:getWidth(), image:getHeight()})
    shader:send("burn_colour_1", {0, 0, 0, 0})
    shader:send("burn_colour_2", {0, 0, 0, 0})
    shader:send("shadow", false)
    return true
end

function BoosterShader.clear()
    love.graphics.setShader()
end

function BoosterShader.draw(image, x, y, phase, dissolve, r, sx, sy, ox, oy)
    if not BoosterShader.apply(image, phase, dissolve) then
        love.graphics.draw(image, x, y, r or 0, sx or 1, sy or 1, ox or 0, oy or 0)
        return
    end
    love.graphics.draw(image, x, y, r or 0, sx or 1, sy or 1, ox or 0, oy or 0)
    BoosterShader.clear()
end

return BoosterShader
