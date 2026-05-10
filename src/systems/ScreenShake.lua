-- src/systems/ScreenShake.lua
-- Screen shake global Balatro-style: sine waves multifrequência em X/Y/rot
-- + jiggle decay exponencial + parallax sutil do cursor.
--
-- Uso:
--   ScreenShake.trigger(intensity, duration)  -- ou _G.triggerShake(...)
--   ScreenShake.jiggle(amount)                -- empilha "energia" (Balatro)
--   ScreenShake.update(dt)                    -- no love.update
--   ScreenShake.push()                        -- antes do draw (translate+rotate)
--   ScreenShake.pop()                         -- depois do draw
--
-- Mantém _G.triggerShake registrado em .install() pra chamadas legadas
-- (Game:_onEnemyDeath, CombatSequence._handleResult, EnemyRenderer) funcionarem.

local ScreenShake = {}

-- API legacy (intensity-based) — mantida pra back-compat.
local time = 0
local intensity = 0
local duration = 0

-- API nova (jiggle accumulator Balatro-style).
local jiggle = 0
local timer = 0  -- tempo absoluto pra alimentar as sines (cresce sempre)

-- Estado runtime do push/pop.
local activePush = false

-- Tunables (mais em Config se quiser expor).
local JIGGLE_DECAY_RATE = 5.0     -- decay exponencial: jiggle *= (1 - 5*dt)
local SHAKE_BASE = 1.0            -- amplitude base (sem jiggle ativo)
local SHAKE_JIGGLE = 1.0          -- amplitude amplificada por jiggle
local CURSOR_PARALLAX = 0.0       -- 0 = desliga; 0.005 = sutil. Reservado pra futuro.

-- Configurações globais (lidas em Settings se existirem).
local function userScreenshakeAmt()
    if _G.gameSettings and _G.gameSettings.screenshake then
        return _G.gameSettings.screenshake  -- 0..1
    end
    return 1
end

-- ============ API legacy ============

-- Dispara shake intensity-based (compat). Também adiciona jiggle proporcional.
function ScreenShake.trigger(i, d)
    intensity = math.max(intensity, i or 6)
    duration = math.max(duration, d or 0.22)
    time = duration
    -- Pequeno empurrão no jiggle pra integrar com o sistema novo.
    jiggle = jiggle + math.min(1.0, (i or 6) * 0.12)
end

-- ============ API nova (Balatro) ============

-- Empilha energia no jiggle (decay automático). Use em juice grandes:
--   ScreenShake.jiggle(0.3)  -- carta jogada
--   ScreenShake.jiggle(0.7)  -- crítico / explosão pequena
--   ScreenShake.jiggle(1.5)  -- pack abrindo / boss death
function ScreenShake.jiggle(amt)
    jiggle = jiggle + (amt or 0.5)
    if jiggle > 4 then jiggle = 4 end  -- clamp pra não explodir
end

-- ============ Update + render ============

function ScreenShake.update(dt)
    timer = timer + dt
    if time > 0 then
        time = math.max(0, time - dt)
        if time == 0 then
            intensity = 0
            duration = 0
        end
    end
    -- Decay exponencial do jiggle.
    if jiggle > 0 then
        jiggle = jiggle * (1 - JIGGLE_DECAY_RATE * dt)
        if jiggle < 0.01 then jiggle = 0 end
    end
end

-- Calcula offsets (x, y, rot) atuais. Usado por push() e por testes.
function ScreenShake.computeOffsets()
    local userAmt = userScreenshakeAmt()
    if userAmt <= 0 then return 0, 0, 0 end

    -- Componente legacy (random pulse) — desaparece no fim do timer.
    local lx, ly = 0, 0
    if time > 0 then
        local t = time / math.max(0.001, duration)
        local mag = intensity * t * userAmt
        lx = (love.math.random() - 0.5) * 2 * mag
        ly = (love.math.random() - 0.5) * 2 * mag
    end

    -- Componente novo (sine multifreq + jiggle).
    local shakeAmt = SHAKE_BASE * userAmt
    local jamp = jiggle * SHAKE_JIGGLE * userAmt

    -- Rotação: sine lenta (drift) + sine alta (jiggle quando ativo).
    local rot = (0.001 * math.sin(0.3 * timer)
               + 0.002 * jamp * math.sin(39.913 * timer)) * shakeAmt

    -- X: drift lento + sine alta com jiggle. Amplitudes em pixels (~ a 1024×768).
    local sx = shakeAmt * (
        2.5 * math.sin(0.913 * timer)
      + 1.6 * jamp * math.sin(19.913 * timer)
    )

    -- Y: outras frequências pra X≠Y (mais natural).
    local sy = shakeAmt * (
        2.5 * math.sin(0.952 * timer)
      + 1.6 * jamp * math.sin(21.913 * timer)
    )

    return lx + sx, ly + sy, rot
end

-- Translação + rotação aplicadas ao contexto gráfico. Sempre pair com pop().
function ScreenShake.push()
    local dx, dy, dr = ScreenShake.computeOffsets()
    if dx ~= 0 or dy ~= 0 or dr ~= 0 then
        love.graphics.push()
        -- Origem = centro da tela pra rotação não vir do canto.
        local w, h = love.graphics.getDimensions()
        love.graphics.translate(w * 0.5 + dx, h * 0.5 + dy)
        love.graphics.rotate(dr)
        love.graphics.translate(-w * 0.5, -h * 0.5)
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
    return time > 0 or jiggle > 0.01
end

-- Para testes/debug.
function ScreenShake.getState()
    return { time = time, intensity = intensity, jiggle = jiggle, timer = timer }
end

-- Registra _G.triggerShake global pra back-compat com sistemas que já usam.
function ScreenShake.install()
    _G.triggerShake = ScreenShake.trigger
    _G.jiggleScreen = ScreenShake.jiggle
end

return ScreenShake
