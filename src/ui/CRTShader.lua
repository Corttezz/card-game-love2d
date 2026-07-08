-- src/ui/CRTShader.lua
-- Wrapper do shader CRT pós-processamento (Balatro-style).
-- Uso típico:
--   CRTShader.load()
--   CRTShader.setStrength(0.8)
--   function love.draw()
--     CRTShader.beginScene()
--     ...draw all game stuff...
--     CRTShader.endScene()
--   end

local CRTShader = {}

local shader
local sceneCanvas
local strength = 0.75  -- identidade CRT v2 FORTE (pedido do dono): tubo de verdade.
local enabled = true

-- ===== ESTADO FÍSICO DO TUBO (identidade CRT v2, Jul/2026) =====
-- power 0..1: 0 = TV desligada, 1 = ligada. powerOn/powerOff animam com
-- animador PRÓPRIO (não EventManager: o desligar precisa rodar até
-- durante transições de estado e no caminho do quit).
local power = 1
local powerAnim = nil   -- { from, to, dur, t, cb }

-- Carrega o shader e cria canvas de cena. Chamar em love.load.
function CRTShader.load()
    local ok, s = pcall(love.graphics.newShader, "shaders/crt.glsl")
    if not ok then
        print("[CRTShader] falha ao carregar shaders/crt.glsl: " .. tostring(s))
        shader = nil
        return false
    end
    shader = s
    sceneCanvas = love.graphics.newCanvas()
    sceneCanvas:setFilter("linear", "linear")  -- barrel em nearest serrilha; linear = vidro
    return true
end

-- Toggle liga/desliga.
function CRTShader.setEnabled(v)
    enabled = v
end

function CRTShader.isEnabled()
    return enabled
end

function CRTShader.toggle()
    enabled = not enabled
end

-- ===== API do power =====
function CRTShader.setPower(p)
    power = math.max(0, math.min(1, p or 1))
end

function CRTShader.getPower() return power end
function CRTShader.isPowering() return powerAnim ~= nil end

local function animatePower(to, dur, cb)
    -- Acessibilidade: com CRT desligado, corte seco (o fluxo não espera).
    if not enabled or not shader then
        power = to
        if cb then cb() end
        return
    end
    powerAnim = { from = power, to = to, dur = math.max(0.05, dur or 0.8),
                  t = 0, cb = cb }
end

-- TV ligando (boot, religar após game over).
function CRTShader.powerOn(dur, cb)  animatePower(1, dur or 1.2, cb) end
-- TV desligando (morte, sair).
function CRTShader.powerOff(dur, cb) animatePower(0, dur or 0.6, cb) end

-- "Pulo de canal": dip rápido 1 → 0.86 → 1 (transições leves).
function CRTShader.blip()
    if not enabled or not shader then return end
    powerAnim = { from = 1, to = 0.86, dur = 0.09, t = 0, cb = function()
        powerAnim = { from = 0.86, to = 1, dur = 0.14, t = 0 }
    end }
end

-- Tick do animador (chamar no love.update).
function CRTShader.update(dt)
    if not powerAnim then return end
    powerAnim.t = powerAnim.t + dt
    local k = math.min(1, powerAnim.t / powerAnim.dur)
    power = powerAnim.from + (powerAnim.to - powerAnim.from) * k
    if k >= 1 then
        local cb = powerAnim.cb
        powerAnim = nil
        if cb then cb() end
    end
end

-- Intensidade do efeito (0..1).
function CRTShader.setStrength(s)
    strength = math.max(0, math.min(1, s or 0))
end

function CRTShader.getStrength()
    return strength
end

-- Abre uma "cena" — tudo que desenhar depois é capturado no canvas.
function CRTShader.beginScene()
    if not shader or not enabled then return end
    -- Se a janela redimensionar, recria canvas.
    local w, h = love.graphics.getDimensions()
    if sceneCanvas:getWidth() ~= w or sceneCanvas:getHeight() ~= h then
        sceneCanvas = love.graphics.newCanvas(w, h)
        sceneCanvas:setFilter("linear", "linear")  -- barrel em nearest serrilha; linear = vidro
    end
    love.graphics.setCanvas(sceneCanvas)
    love.graphics.clear(0, 0, 0, 1)
end

-- Fecha a cena e desenha com o shader aplicado.
function CRTShader.endScene()
    if not shader or not enabled then return end
    love.graphics.setCanvas()
    love.graphics.setShader(shader)
    local w, h = love.graphics.getDimensions()
    shader:send("time", love.timer.getTime())
    shader:send("resolution", { w, h })
    shader:send("strength", strength)
    shader:send("power", power)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(sceneCanvas, 0, 0)
    love.graphics.setShader()
end

return CRTShader
