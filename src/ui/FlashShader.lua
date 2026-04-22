-- src/ui/FlashShader.lua
-- Wrapper do shaders/flash.glsl. Overlay branco pixelado pra impactos,
-- booster opening, buffs aplicados. Desenha um quad fullscreen ou per-card
-- com alfa modulado.
--
-- Uso típico (fullscreen flash, via EventManager):
--   FlashShader.trigger(0.6)  -- intensidade 0..1
-- Em love.draw (depois de tudo):
--   FlashShader.draw()
-- Em love.update:
--   FlashShader.update(dt)

local FlashShader = {}

local shader
local loaded = false
local intensity = 0
local decayTimer = 0
local decayDuration = 0.3

function FlashShader.load()
    local ok, s = pcall(love.graphics.newShader, "shaders/flash.glsl")
    if not ok then
        print("[FlashShader] falha ao carregar shaders/flash.glsl: " .. tostring(s))
        return false
    end
    shader = s
    loaded = true
    return true
end

function FlashShader.isAvailable()
    return loaded
end

-- Dispara um flash. Intensidade 0..1 (0 desliga; 0.5 médio; 1 ofuscante).
-- duration em segundos (decay linear até 0).
function FlashShader.trigger(i, duration)
    intensity = math.max(intensity, math.max(0, math.min(1, i or 0.5)))
    decayDuration = duration or 0.3
    decayTimer = decayDuration
end

function FlashShader.update(dt)
    if decayTimer > 0 then
        decayTimer = decayTimer - dt
        if decayTimer <= 0 then
            intensity = 0
            decayTimer = 0
        else
            intensity = intensity * (decayTimer / decayDuration)
        end
    end
end

-- Desenha overlay fullscreen. Chame DEPOIS de todo o resto no love.draw.
function FlashShader.draw()
    if not loaded or intensity <= 0.001 then return end
    local w, h = love.graphics.getDimensions()
    love.graphics.setShader(shader)
    shader:send("time", love.timer.getTime())
    shader:send("mid_flash", intensity)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, w, h)
    love.graphics.setShader()
end

-- Flash simples sem shader (fallback / uso leve): alpha branco fullscreen.
-- Use quando só quer "piscar" sem o look pixelado do flash shader.
function FlashShader.drawPlain(alpha)
    alpha = math.max(0, math.min(1, alpha or 0))
    if alpha <= 0 then return end
    local w, h = love.graphics.getDimensions()
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.rectangle("fill", 0, 0, w, h)
    love.graphics.setColor(1, 1, 1, 1)
end

return FlashShader
