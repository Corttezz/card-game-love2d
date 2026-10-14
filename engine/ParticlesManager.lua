local Particles = require("engine.Particles")

local ParticlesManager = {}

local instances = {}

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

function ParticlesManager.draw()
    if #instances == 0 then return end
    local sameLayer = true
    local firstLayer = instances[1].layer
    for i = 2, #instances do
        if instances[i].layer ~= firstLayer then sameLayer = false break end
    end

    if sameLayer then
        for _, p in ipairs(instances) do p:draw() end
        return
    end

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
