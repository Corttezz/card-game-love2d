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
local strength = 0.45  -- 0 = desligado, 1 = efeito total. 0.45 é sutil (tela não treme).
local enabled = true

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
    sceneCanvas:setFilter("nearest", "nearest")
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
        sceneCanvas:setFilter("nearest", "nearest")
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
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(sceneCanvas, 0, 0)
    love.graphics.setShader()
end

return CRTShader
