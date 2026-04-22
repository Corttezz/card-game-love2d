-- src/systems/CardParticles.lua
-- Emissor de partículas que segue uma carta (posição, fade, lifespan).
-- Versão leve do `engine/particles.lua` do Balatro, sem herança Moveable.
--
-- ARQUITETURA:
--   Global singleton (CardParticles.manager) que tick todos os emitters ativos.
--   Cada emitter tem attachCard (referência) + pool local de partículas.
--   Quando attachCard.removed == true ou fade terminou, emitter é dropado.
--
-- USO:
--   local emitter = CardParticles.emit(card, {
--       timer = 0.02,         -- intervalo entre spawns
--       lifespan = 0.6,       -- vida de cada partícula
--       scale = 0.3,
--       speed = 80,           -- px/s
--       colours = {{1,0.5,0,1}, {1,0.2,0,1}},
--       fill = true,          -- spawna em área do card (fill) ou no centro
--       max = 40,             -- tamanho máximo do pool
--       pulse_max = nil,      -- se setado, spawna até N e para
--   })
--   emitter:fade(0.3)  -- começa a sumir em 0.3s
--
-- No love.update:
--   CardParticles.update(dt)
-- No love.draw (depois de desenhar o jogo):
--   CardParticles.draw()

local CardParticles = {}

local Emitter = {}
Emitter.__index = Emitter

local manager = {
    emitters = {},
}

-- Cria emitter atachado a uma carta. Retorna o emitter (pode chamar :fade, :remove).
function CardParticles.emit(card, cfg)
    cfg = cfg or {}
    local e = setmetatable({
        card = card,
        timer = cfg.timer or 0.03,
        last_spawn = 0,
        lifespan = cfg.lifespan or 0.8,
        scale = cfg.scale or 0.3,
        speed = cfg.speed or 80,
        colours = cfg.colours or {{1, 1, 1, 1}},
        fill = cfg.fill,
        max = cfg.max or 200,
        pulse_max = cfg.pulse_max, -- nil = emissão contínua; N = spawna até N e para
        pulsed = 0,
        vel_variation = cfg.vel_variation or 1,
        particles = {},
        fade_alpha = 0,
        fade_speed = 0,
        dead = false,
        clock = 0,
    }, Emitter)
    table.insert(manager.emitters, e)
    return e
end

-- Começa fade out em `delay` segundos (linear até alpha 0 = invisível).
function Emitter:fade(delay)
    self.fade_speed = 1 / math.max(0.01, delay or 0.3)
end

-- Para emissão imediatamente (partículas existentes continuam vivendo seu lifespan).
function Emitter:stop()
    self.timer = math.huge
end

-- Remove imediatamente (limpa partículas).
function Emitter:remove()
    self.dead = true
    self.particles = {}
end

-- ===== update / draw =====

function CardParticles.update(dt)
    for i = #manager.emitters, 1, -1 do
        local e = manager.emitters[i]
        e.clock = e.clock + dt

        -- Fade global do emitter (não das partículas individuais)
        if e.fade_speed > 0 then
            e.fade_alpha = math.min(1, e.fade_alpha + dt * e.fade_speed)
        end

        -- Spawn novas partículas se card vivo e pool não cheio
        local cardAlive = e.card and not e.card._removed
        if cardAlive and not e.dead
            and (e.pulse_max == nil or e.pulsed < e.pulse_max)
            and #e.particles < e.max
            and e.fade_alpha < 1 then

            while e.clock >= e.last_spawn + e.timer
                and #e.particles < e.max
                and (e.pulse_max == nil or e.pulsed < e.pulse_max) do
                e.last_spawn = e.last_spawn + e.timer

                -- Área de spawn: centro da carta ou espalhado no rect dela
                local ox, oy = 0, 0
                if e.fill and e.card.image then
                    local w = e.card.image:getWidth() * (e.card.currentScale or 1)
                    local h = e.card.image:getHeight() * (e.card.currentScale or 1)
                    ox = (love.math.random() - 0.5) * w
                    oy = (love.math.random() - 0.5) * h
                end

                local dir = love.math.random() * 2 * math.pi
                local speed = e.speed * (e.vel_variation * love.math.random() + (1 - e.vel_variation))

                table.insert(e.particles, {
                    age = 0,
                    x = ox,
                    y = oy,
                    vx = math.cos(dir) * speed,
                    vy = math.sin(dir) * speed,
                    rot = love.math.random() * math.pi * 2,
                    r_vel = (love.math.random() - 0.5) * 4,
                    scale = 0,
                    size = 3 + love.math.random() * 5,
                    colour = e.colours[love.math.random(#e.colours)],
                })

                e.pulsed = e.pulsed + 1
            end
        end

        -- Atualiza partículas (movimento + age)
        for j = #e.particles, 1, -1 do
            local p = e.particles[j]
            p.age = p.age + dt
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            p.rot = p.rot + p.r_vel * dt
            p.vx = p.vx * 0.96
            p.vy = p.vy * 0.96

            -- Scale: cresce no começo, encolhe no fim (curva triangular)
            local lifeT = p.age / e.lifespan
            if lifeT >= 1 then
                table.remove(e.particles, j)
            else
                local fade = math.min(lifeT * 3, (1 - lifeT) * 3, 1)
                p.scale = e.scale * fade * p.size
            end
        end

        -- Dead condition: card sumiu ou fade completo e sem partículas
        if e.dead or (e.fade_alpha >= 1 and #e.particles == 0)
           or (not cardAlive and #e.particles == 0) then
            table.remove(manager.emitters, i)
        end
    end
end

function CardParticles.draw()
    for _, e in ipairs(manager.emitters) do
        if e.card and not e.card._removed and #e.particles > 0 then
            local card = e.card
            -- Centro da carta na tela (mesma matemática do Card:draw).
            local cx = (card.x or 0) + ((card.image and card.image:getWidth() or 100) * (card.currentScale or 1)) / 2
            local cy = (card.y or 0) + ((card.image and card.image:getHeight() or 140) * (card.currentScale or 1)) / 2
            local globalAlpha = 1 - e.fade_alpha

            for _, p in ipairs(e.particles) do
                if p.scale > 0.1 then
                    local c = p.colour
                    love.graphics.setColor(c[1], c[2], c[3], (c[4] or 1) * globalAlpha)
                    love.graphics.push()
                    love.graphics.translate(cx + p.x, cy + p.y)
                    love.graphics.rotate(p.rot)
                    love.graphics.rectangle("fill", -p.scale / 2, -p.scale / 2, p.scale, p.scale)
                    love.graphics.pop()
                end
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function CardParticles.clear()
    manager.emitters = {}
end

-- Diagnóstico.
function CardParticles.activeCount()
    return #manager.emitters
end

return CardParticles
