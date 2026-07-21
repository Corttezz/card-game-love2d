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
local powerAnim = nil   -- { from, to, dur, t, cb, ease }
-- Coreografia do power (v3.6): o shader tem DUAS coreografias distintas —
-- ligar (ponto → linha → abre rolando → assenta) e desligar (colapso →
-- linha → ponto de fósforo que esfria e apaga). powerDirection escolhe.
local powerDirection = 1   -- 1 = ligando/estável, -1 = desligando

-- Tremidinha ocasional (sync jitter): evento raro de instabilidade de
-- sinal — banda horizontal treme por ~0.15s a cada 4-9s. Agendado aqui,
-- executado no shader (uniforms glitch/glitchY).
local glitchAmount = 0
local glitchBandY = 0.5
local glitchTimer = 3.0   -- primeiro evento cedo (o jogador percebe a identidade)
local glitchActive = 0

-- SURTO de TV velha (v3.8, pedido do dono): o baseline é limpo/legível,
-- mas a cada 8-20s o sinal "degrada" por 0.6-2s — vinheta/CA/ruído/
-- flicker sobem e uma hum bar rola pela tela. Envelope: ataque rápido
-- (0.12s), decaimento suave (0.35s). Intensidade de pico varia por evento.
local degradeAmount = 0
local degradeTimer = 6.0      -- primeiro surto cedo, mas não imediato
local degradeActive = 0       -- tempo restante do surto corrente
local degradeDur = 1.0        -- duração total do surto corrente
local degradePeak = 1.0       -- pico 0.55..1.0 sorteado por evento

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
-- dir opcional: força a coreografia (1 ligando, -1 desligando) — usado
-- pelas ferramentas de captura pra congelar um estágio específico.
function CRTShader.setPower(p, dir)
    power = math.max(0, math.min(1, p or 1))
    if dir then powerDirection = dir end
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
    -- Desligar DE VERDADE (to≈0) usa a coreografia do colapso; qualquer
    -- outra animação (ligar, blip de canal) usa a do warm-up.
    local turningOff = to <= 0.01
    powerDirection = turningOff and -1 or 1
    powerAnim = { from = power, to = to, dur = math.max(0.05, dur or 0.8),
                  t = 0, cb = cb,
                  -- desligar: colapso RÁPIDO no começo, ponto de fósforo
                  -- demorando pra apagar no fim (easeOutQuad no k)
                  ease = turningOff and "outquad" or nil }
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
    -- agendador da tremidinha (só com o tubo ligado e estável)
    if enabled and shader and power > 0.99 then
        if glitchActive > 0 then
            glitchActive = glitchActive - dt
            glitchAmount = math.max(0, math.min(1, glitchActive / 0.08))
            if glitchActive <= 0 then
                glitchAmount = 0
                glitchTimer = 4.0 + love.math.random() * 5.0
            end
        else
            glitchTimer = glitchTimer - dt
            if glitchTimer <= 0 then
                glitchActive = 0.10 + love.math.random() * 0.14
                glitchBandY = 0.15 + love.math.random() * 0.7
                glitchAmount = 1.0
            end
        end
    else
        glitchAmount = 0
    end

    -- agendador do SURTO (mesma condição: tubo ligado e estável)
    if enabled and shader and power > 0.99 then
        if degradeActive > 0 then
            degradeActive = degradeActive - dt
            local elapsed = degradeDur - degradeActive
            -- envelope: ataque 0.12s, decaimento 0.35s
            local env = math.min(1, elapsed / 0.12)
                * math.min(1, math.max(0, degradeActive) / 0.35)
            degradeAmount = degradePeak * math.max(0, math.min(1, env))
            if degradeActive <= 0 then
                degradeAmount = 0
                degradeTimer = 8.0 + love.math.random() * 12.0
            end
        else
            degradeTimer = degradeTimer - dt
            if degradeTimer <= 0 then
                degradeDur = 0.6 + love.math.random() * 1.4
                degradeActive = degradeDur
                degradePeak = 0.55 + love.math.random() * 0.45
                -- surto costuma vir com uma tremidinha junto (TV real)
                if glitchActive <= 0 and love.math.random() < 0.6 then
                    glitchActive = 0.10 + love.math.random() * 0.14
                    glitchBandY = 0.15 + love.math.random() * 0.7
                    glitchAmount = 1.0
                end
            end
        end
    else
        degradeAmount = 0
    end

    if not powerAnim then return end
    powerAnim.t = powerAnim.t + dt
    local k = math.min(1, powerAnim.t / powerAnim.dur)
    local e = k
    if powerAnim.ease == "outquad" then e = 1 - (1 - k) * (1 - k) end
    power = powerAnim.from + (powerAnim.to - powerAnim.from) * e
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

-- Força o surto (ferramentas de captura/preview — não usar no gameplay,
-- o agendador do update cuida do timing aleatório).
function CRTShader.setDegrade(v)
    degradeAmount = math.max(0, math.min(1, v or 0))
    degradeActive = 0
end

function CRTShader.getStrength()
    return strength
end

-- ===== MOUSE ATRAVÉS DO VIDRO (Jul/2026) =====
-- O shader distorce a IMAGEM (gabinete come borda, domo curva o resto),
-- mas o mouse chega em coordenadas físicas da janela — perto do topo e da
-- base o pixel clicado não é o pixel mostrado (bug do dono: filtros da
-- Coleção "clicam acima de onde aparecem"). Esta função replica EXATAMENTE
-- a matemática de amostragem do crt.glsl (tela → conteúdo): é o mesmo
-- caminho que o pixel percorre, então o clique cai onde o olho vê.
-- MANTENHA EM SINCRONIA com shaders/crt.glsl (BEZEL_PX, halfExt, domo).
function CRTShader.screenToContent(x, y)
    -- passthrough: CRT desligado, sem shader, ou strength ~0 (o shader
    -- também faz passthrough nesse caso)
    if not shader or not enabled or strength < 0.01 then return x, y end
    local w, h = love.graphics.getDimensions()
    if w <= 0 or h <= 0 then return x, y end

    local ar = w / h
    -- pp: espaço centrado com aspecto (idem shader)
    local ppx = (x / w - 0.5) * ar
    local ppy = (y / h - 0.5)
    -- interior do tubo (gabinete de BEZEL_PX descontado)
    local bezelU = 20.0 / h                 -- = BEZEL_PX do crt.glsl
    local hex = 0.5 * ar - bezelU
    local hey = 0.5 - bezelU
    if hex <= 0 or hey <= 0 then return x, y end
    -- tuv: 0..1 dentro da abertura
    local tx = (ppx / hex) * 0.5 + 0.5
    local ty = (ppy / hey) * 0.5 + 0.5
    -- domo r² + r⁴ (o shader desloca a AMOSTRA — replicamos igual)
    local cx, cy = tx - 0.5, ty - 0.5
    local r2 = cx * cx + cy * cy
    local kx = 0.060 * strength
    local ky = 0.080 * strength
    local sx = tx + cx * (kx * r2 * 1.6 + kx * r2 * r2 * 7.0)
    local sy = ty + cy * (ky * r2 * 1.6 + ky * r2 * r2 * 7.0)
    -- sem clamp: clique no gabinete extrapola pra fora do conteúdo e
    -- naturalmente não acerta UI (não inventa hits na borda)
    return sx * w, sy * h
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
    shader:send("powerDir", powerDirection)
    shader:send("glitch", glitchAmount)
    shader:send("glitchY", glitchBandY)
    shader:send("degrade", degradeAmount)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(sceneCanvas, 0, 0)
    love.graphics.setShader()
end

return CRTShader
