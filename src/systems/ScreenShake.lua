-- src/systems/ScreenShake.lua
-- Screen shake global. Substitui o trio (shakeTime, shakeIntensity, shakeDuration)
-- + _G.triggerShake que vivia solto em main.lua.
--
-- Uso:
--   ScreenShake.trigger(intensity, duration)  -- ou _G.triggerShake(...)
--   ScreenShake.update(dt)                    -- no love.update
--   ScreenShake.push()                        -- antes do draw (translate)
--   ScreenShake.pop()                         -- depois do draw
--
-- Mantém _G.triggerShake registrado em .install() pra chamadas legadas
-- (Game:_onEnemyDeath, CombatSequence._handleResult, EnemyRenderer) funcionarem
-- sem refactor.

local ScreenShake = {}

local time = 0
local intensity = 0
local duration = 0
local activePush = false

-- Dispara um shake. Se outro já estiver ativo, pega a intensidade/duração max.
function ScreenShake.trigger(i, d)
    intensity = math.max(intensity, i or 6)
    duration = math.max(duration, d or 0.22)
    time = duration
end

function ScreenShake.update(dt)
    if time > 0 then
        time = math.max(0, time - dt)
        if time == 0 then
            intensity = 0
            duration = 0
        end
    end
end

-- Translação aleatória aplicada ao contexto gráfico. Sempre pair com pop().
function ScreenShake.push()
    if time > 0 then
        local t = time / math.max(0.001, duration)
        local mag = intensity * t
        local dx = (love.math.random() - 0.5) * 2 * mag
        local dy = (love.math.random() - 0.5) * 2 * mag
        love.graphics.push()
        love.graphics.translate(dx, dy)
        activePush = true
    else
        activePush = false
    end
end

function ScreenShake.pop()
    if activePush then
        love.graphics.pop()
        activePush = false
    end
end

function ScreenShake.isActive()
    return time > 0
end

-- Registra _G.triggerShake global pra back-compat com sistemas que já usam.
function ScreenShake.install()
    _G.triggerShake = ScreenShake.trigger
end

return ScreenShake
