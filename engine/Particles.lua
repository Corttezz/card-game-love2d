-- engine/Particles.lua
-- Emissor de partículas unificado, inspirado em
-- balatro-source/engine/particles.lua. Substitui o trio anterior:
-- ParticleSystem.Manager / CardParticles.Emitter / (smoke continua independente).
--
-- Diferenças vs Balatro:
--   - Não herda Moveable. Posição própria + opção de `attach` (target com .x/.y).
--   - Suporte a textura sprite opcional (Balatro só desenhava retângulos).
--   - API standalone (sem G.E_MANAGER, G.TIMERS, G.SETTINGS.paused).
--
-- USO:
--   local p = Particles:new(cx, cy, w, h, {
--       fill = true,                       -- spawn em rect; false = no centro
--       attach = card,                     -- opcional: segue card.x/card.y
--       timer = 0.03,                      -- intervalo de spawn (s)
--       lifespan = 0.6,
--       scale = 0.3,
--       speed = 80,
--       colours = { {1,0.5,0,1}, {1,0.2,0,1} },
--       texture = nil,                     -- love.Image opcional
--       max = 200,                         -- pool máximo
--       pulse_max = nil,                   -- nil = contínuo; N = one-shot
--       vel_variation = 1,                 -- 0..1 (1 = velocidade plena)
--       gravity = 0,                       -- px/s² em vy (negativo = sobe: fogo/fumaça)
--       layer = 0,                         -- z-order (maior = mais por cima)
--   })
--   p:fade(0.3)   -- inicia fade-out em 0.3s
--   p:remove()    -- mata imediatamente
--
-- Auto-cleanup: instâncias removidas saem do ParticlesManager no próximo update.

local Utils = require("engine.Utils")

local Particles = {}
Particles.__index = Particles

function Particles:new(x, y, w, h, config)
    config = config or {}

    local self = setmetatable({
        x = x or 0,
        y = y or 0,
        w = w or 0,
        h = h or 0,

        -- Attach: se setado, x/y seguem este target a cada frame.
        attach          = config.attach,
        attach_offset_x = config.attach_offset_x or 0,
        attach_offset_y = config.attach_offset_y or 0,

        fill          = config.fill or false,
        timer         = config.timer or 0.05,
        last_spawn    = 0,
        clock         = 0,

        lifespan      = config.lifespan or 1,
        scale         = config.scale or 1,
        speed         = config.speed or 60,
        max           = config.max or 200,
        pulse_max     = config.pulse_max,
        pulsed        = 0,
        vel_variation = config.vel_variation or 1,
        gravity       = config.gravity or 0,
        colours       = config.colours or { {1, 1, 1, 1} },
        texture       = config.texture,
        size_jitter   = config.size_jitter or 5, -- aplicado quando texture==nil
        size_base     = config.size_base or 3,

        layer         = config.layer or 0,

        particles     = {},
        fade_alpha    = 0,
        fade_speed    = 0,
        dead          = false,
    }, Particles)

    return self
end

-- Atualiza a posição se há `attach`. Recolhe x/y, w/h direto do target
-- (interpretamos `card.x/card.y` como canto superior-esquerdo no projeto;
-- se attach.image existe, calcula bbox).
local function syncAttach(self)
    local a = self.attach
    if not a then return end

    if a._removed then
        -- Target morreu: marcar para limpeza após esvaziar pool.
        self.dead = true
        return
    end

    if a.image and a.currentScale then
        local w = a.image:getWidth() * a.currentScale
        local h = a.image:getHeight() * a.currentScale
        self.x = (a.x or 0) + self.attach_offset_x
        self.y = (a.y or 0) + self.attach_offset_y
        self.w = w
        self.h = h
    else
        self.x = (a.x or 0) + self.attach_offset_x
        self.y = (a.y or 0) + self.attach_offset_y
    end
end

function Particles:update(dt)
    -- Só early-return quando totalmente morto (dead E pool vazia). Sem isso,
    -- quando syncAttach seta dead=true (attach._removed), o NEXT frame congelava
    -- as partículas existentes — paravam de envelhecer e o fade_alpha travava
    -- mid-fade, deixando partículas semi-transparentes presas na tela pra sempre.
    if self.dead and #self.particles == 0 then return end
    syncAttach(self)
    self.clock = self.clock + dt

    -- Fade do emitter (visual; partículas continuam vivendo seus lifespans).
    if self.fade_speed > 0 then
        self.fade_alpha = math.min(1, self.fade_alpha + dt * self.fade_speed)
    end

    -- Spawn novas partículas: enquanto não atingiu pulse_max, pool não cheio
    -- e ainda não estourou fade.
    local canSpawn = (self.pulse_max == nil or self.pulsed < self.pulse_max)
                     and #self.particles < self.max
                     and self.fade_alpha < 1
                     and not self.dead

    if canSpawn then
        local spawned = 0
        while self.clock >= self.last_spawn + self.timer
              and #self.particles < self.max
              and (self.pulse_max == nil or self.pulsed < self.pulse_max)
              and spawned < 20 do
            self.last_spawn = self.last_spawn + self.timer

            local ox, oy = 0, 0
            if self.fill then
                ox = (math.random() - 0.5) * self.w
                oy = (math.random() - 0.5) * self.h
            end

            local dir = math.random() * 2 * math.pi
            local v = self.speed * (self.vel_variation * math.random() + (1 - self.vel_variation))

            table.insert(self.particles, {
                age    = 0,
                ox     = ox,
                oy     = oy,
                vx     = math.cos(dir) * v,
                vy     = math.sin(dir) * v,
                rot    = math.random() * math.pi * 2,
                r_vel  = (math.random() - 0.5) * 4,
                size   = self.size_base + math.random() * self.size_jitter,
                colour = Utils.pseudorandom_element(self.colours) or {1, 1, 1, 1},
            })

            self.pulsed = self.pulsed + 1
            spawned = spawned + 1
        end
    end

    -- Atualiza partículas existentes.
    for i = #self.particles, 1, -1 do
        local p = self.particles[i]
        p.age = p.age + dt
        p.ox  = p.ox + p.vx * dt
        p.oy  = p.oy + p.vy * dt
        p.rot = p.rot + p.r_vel * dt
        p.vx  = p.vx * 0.96
        p.vy  = p.vy * 0.96 + self.gravity * dt

        local lifeT = p.age / self.lifespan
        if lifeT >= 1 then
            table.remove(self.particles, i)
        else
            -- Curva triangular: cresce até meio do lifespan, encolhe até zero.
            p.alpha_factor = math.min(lifeT * 3, (1 - lifeT) * 3, 1)
        end
    end

    -- Pronta pra remover quando: (a) dead manual, ou (b) fade completo + pool vazio,
    -- ou (c) attach morreu + pool vazio.
    if (self.fade_alpha >= 1 and #self.particles == 0)
       or (self.dead and #self.particles == 0) then
        self.dead = true
    end
end

function Particles:draw()
    if self.dead and #self.particles == 0 then return end

    local globalA = 1 - self.fade_alpha
    local cx = self.x + (self.fill and 0 or self.w / 2)
    local cy = self.y + (self.fill and 0 or self.h / 2)

    if self.attach and self.attach.image and self.attach.currentScale then
        -- Centro real do bbox do target.
        cx = self.x + self.w / 2
        cy = self.y + self.h / 2
    end

    if self.texture then
        local tw = self.texture:getWidth()
        local th = self.texture:getHeight()
        for _, p in ipairs(self.particles) do
            if p.alpha_factor and p.alpha_factor > 0 then
                local c = p.colour
                love.graphics.setColor(c[1], c[2], c[3], (c[4] or 1) * globalA * p.alpha_factor)
                local s = self.scale * p.alpha_factor
                love.graphics.draw(self.texture, cx + p.ox, cy + p.oy, p.rot, s, s, tw / 2, th / 2)
            end
        end
    else
        for _, p in ipairs(self.particles) do
            if p.alpha_factor and p.alpha_factor > 0 then
                local c = p.colour
                love.graphics.setColor(c[1], c[2], c[3], (c[4] or 1) * globalA * p.alpha_factor)
                local s = self.scale * p.size * p.alpha_factor
                if s > 0.1 then
                    love.graphics.push()
                    love.graphics.translate(cx + p.ox, cy + p.oy)
                    love.graphics.rotate(p.rot)
                    love.graphics.rectangle("fill", -s / 2, -s / 2, s, s)
                    love.graphics.pop()
                end
            end
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- Inicia fade-out linear ao longo de `duration` segundos.
function Particles:fade(duration)
    self.fade_speed = 1 / math.max(0.01, duration or 0.3)
end

-- Para emissão imediatamente; partículas existentes continuam até morrer.
function Particles:stop()
    self.timer = math.huge
end

-- Remove imediatamente (limpa pool).
function Particles:remove()
    self.dead = true
    self.particles = {}
end

function Particles:isDead()
    return self.dead and #self.particles == 0
end

return Particles
