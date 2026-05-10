-- engine/ParticlesManager.lua
-- Registry global das instâncias Particles ativas. Único lugar onde update/draw
-- de partículas é tickado (exceto SmokeSystem, que tem físicas próprias).
--
-- USO:
--   local p = ParticlesManager.spawn(x, y, w, h, config)
--   ParticlesManager.update(dt)   -- chamar uma vez no love.update
--   ParticlesManager.draw()       -- chamar uma vez no love.draw
--   ParticlesManager.clear()      -- limpa tudo (ex: troca de cena)

local Particles = require("engine.Particles")

local ParticlesManager = {}

local instances = {}

-- Cria e registra um Particles. Retorna a instância (chamável pra :fade, :remove).
function ParticlesManager.spawn(x, y, w, h, config)
    local p = Particles:new(x, y, w, h, config)
    table.insert(instances, p)
    return p
end

function ParticlesManager.add(particles)
    table.insert(instances, particles)
end

function ParticlesManager.update(dt)
    for i = #instances, 1, -1 do
        instances[i]:update(dt)
        if instances[i]:isDead() then
            table.remove(instances, i)
        end
    end
end

-- Desenho ordenado por layer (z-order). Estável: layers iguais mantêm ordem
-- de spawn (mais antigos primeiro).
function ParticlesManager.draw()
    if #instances == 0 then return end
    -- Single-pass se todos no mesmo layer (caso comum).
    local sameLayer = true
    local firstLayer = instances[1].layer
    for i = 2, #instances do
        if instances[i].layer ~= firstLayer then sameLayer = false break end
    end

    if sameLayer then
        for _, p in ipairs(instances) do p:draw() end
        return
    end

    -- Caso misto: ordena cópia por layer.
    local sorted = {}
    for i = 1, #instances do sorted[i] = instances[i] end
    table.sort(sorted, function(a, b) return (a.layer or 0) < (b.layer or 0) end)
    for _, p in ipairs(sorted) do p:draw() end
end

function ParticlesManager.clear()
    instances = {}
end

function ParticlesManager.activeCount()
    return #instances
end

return ParticlesManager
