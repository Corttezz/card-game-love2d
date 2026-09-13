-- src/ui/PolychromeShader.lua
-- Wrapper do shaders/polychrome.glsl. Edition "Polychrome": iridescencia na
-- paleta do grimorio (ambar -> ocre -> ferrugem -> violeta -> musgo), que
-- MODULA a arte em vez de pintar por cima. Continua sendo a edition mais
-- notavel das tres -- ver o cabecalho do .glsl pro raciocinio.
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
    -- reducedMotion CONGELA a fase em vez de desligar o efeito: a matiz vira um
    -- gradiente estatico e a carta continua obviamente especial. Edition e
    -- informacao de RARIDADE, nao enfeite -- some a animacao, nao o sinal.
    local frozen = _G.gameSettings and _G.gameSettings.reducedMotion
    shader:send("time", frozen and 11.7 or love.timer.getTime())
    shader:send("strength", math.max(0, math.min(1, strength or 0.7)))
    love.graphics.draw(image, x, y, rotation or 0, sx or 1, sy or 1, ox or 0, oy or 0)
    love.graphics.setShader()
end

return PolychromeShader
