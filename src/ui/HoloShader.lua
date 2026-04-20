-- src/ui/HoloShader.lua
-- Wrapper do shader holográfico para cartas (rare/legendary).
-- Aplicado seletivamente: ao desenhar uma carta com effect="holo" ou "glow" raro,
-- chama HoloShader.draw(image, x, y, strength).

local HoloShader = {}

local shader
local loaded = false

function HoloShader.load()
    local ok, s = pcall(love.graphics.newShader, "shaders/holo.glsl")
    if not ok then
        print("[HoloShader] falha ao carregar shaders/holo.glsl: " .. tostring(s))
        return false
    end
    shader = s
    loaded = true
    return true
end

function HoloShader.isAvailable()
    return loaded
end

-- Desenha uma imagem aplicando holo com a intensidade dada.
-- Uso: HoloShader.draw(cardCanvas, x, y, 0.75)
function HoloShader.draw(image, x, y, strength, rotation, sx, sy, ox, oy)
    if not loaded then
        love.graphics.draw(image, x, y, rotation or 0, sx or 1, sy or 1, ox or 0, oy or 0)
        return
    end
    love.graphics.setShader(shader)
    shader:send("time", love.timer.getTime())
    shader:send("strength", math.max(0, math.min(1, strength or 0.5)))
    love.graphics.draw(image, x, y, rotation or 0, sx or 1, sy or 1, ox or 0, oy or 0)
    love.graphics.setShader()
end

return HoloShader
