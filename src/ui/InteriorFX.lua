-- src/ui/InteriorFX.lua
-- Vida para os interiores de castelo (castle_hall_1/2/3): brasas subindo das
-- tochas/candelabros/lava + glow quente pulsante nos emissores. Mesmo padrão
-- dos fireEmbers da SceneLayer (partículas locais baratas, sem ParticleSystem
-- global). Chamado pelo GameplayScene quando o backdrop é interior.
--
-- Posições dos emissores são RELATIVAS à tela (xr, yr) — casadas com onde as
-- fontes de fogo estão pintadas em cada hall (cover-fit corta as laterais,
-- valores calibrados visualmente no screenshot interior).

local InteriorFX = {}

-- Emissores por ato: {xr, yr, spread}
local EMITTERS = {
    [1] = {   -- salão do trono quente: tochas nas paredes L/R
        { 0.075, 0.42, 10 }, { 0.925, 0.42, 10 },
    },
    [2] = {   -- hall gótico: candelabros L/R (chama pálida, mais calma)
        { 0.135, 0.52, 8 }, { 0.865, 0.52, 8 },
    },
    [3] = {   -- cidadela infernal: rios de lava nas bordas + trono ao fundo
        { 0.09, 0.74, 26 }, { 0.91, 0.74, 26 }, { 0.50, 0.24, 14 },
    },
}

-- Cor das brasas por ato
local EMBER_COLOR = {
    [1] = { 1.00, 0.62, 0.22 },
    [2] = { 1.00, 0.86, 0.55 },
    [3] = { 1.00, 0.42, 0.14 },
}

local embers = {}
local spawnTimer = 0
local time = 0

function InteriorFX.clear()
    embers = {}
    spawnTimer = 0
end

function InteriorFX.update(dt, act)
    time = time + dt
    local a = math.min(3, math.max(1, act or 1))
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()

    spawnTimer = spawnTimer - dt
    if spawnTimer <= 0 and #embers < 54 then
        spawnTimer = 0.07 + love.math.random() * 0.05
        for _, em in ipairs(EMITTERS[a]) do
            if love.math.random() < 0.75 then
                table.insert(embers, {
                    x = em[1] * w + (love.math.random() - 0.5) * em[3] * 2,
                    y = em[2] * h,
                    vx = (love.math.random() - 0.5) * 16,
                    vy = -(34 + love.math.random() * 46),
                    life = 0.8 + love.math.random() * 0.9,
                    maxLife = 1.7,
                    size = 2 + love.math.random(0, 2),
                    hot = love.math.random() > 0.4,
                })
            end
        end
    end

    for i = #embers, 1, -1 do
        local e = embers[i]
        e.x = e.x + e.vx * dt
        e.y = e.y + e.vy * dt
        e.vy = e.vy + 14 * dt          -- desacelera subindo
        e.vx = e.vx * 0.95
        e.life = e.life - dt
        if e.life <= 0 then table.remove(embers, i) end
    end
end

function InteriorFX.draw(act)
    local a = math.min(3, math.max(1, act or 1))
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local c = EMBER_COLOR[a]

    -- glow pulsante nos emissores (2 anéis, flicker rápido tipo tocha)
    for gi, em in ipairs(EMITTERS[a]) do
        local flick = 0.75 + 0.25 * math.sin(time * 13 + gi * 2.4)
            + 0.10 * math.sin(time * 31 + gi * 7.1)
        local r = (26 + 10 * flick) * (em[3] / 10)
        love.graphics.setColor(c[1], c[2] * 0.85, c[3] * 0.6, 0.10 * flick)
        love.graphics.circle("fill", em[1] * w, em[2] * h, r * 1.9)
        love.graphics.setColor(c[1], c[2], c[3], 0.13 * flick)
        love.graphics.circle("fill", em[1] * w, em[2] * h, r)
    end

    -- brasas
    for _, e in ipairs(embers) do
        local alpha = math.min(1, e.life / 0.9)
        local t = 1 - (e.life / e.maxLife)
        local g = e.hot and (c[2] - t * 0.35) or (c[2] * 0.7 - t * 0.3)
        love.graphics.setColor(c[1], math.max(0.1, g), math.max(0, c[3] - t * 0.1),
            alpha * 0.9)
        love.graphics.rectangle("fill", math.floor(e.x), math.floor(e.y),
            e.size, e.size)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return InteriorFX
