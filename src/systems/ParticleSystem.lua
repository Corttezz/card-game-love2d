-- src/ParticleSystem.lua
-- Sistema de partículas para efeitos visuais inspirado no Balatro

local ParticleSystem = {}

-- Classe de partícula individual
local Particle = {}
Particle.__index = Particle

function Particle:new(x, y, vx, vy, life, color, size)
    local instance = setmetatable({}, Particle)
    instance.x = x
    instance.y = y
    instance.vx = vx or 0
    instance.vy = vy or 0
    instance.life = life or 1.0
    instance.maxLife = life or 1.0
    instance.color = color or {1, 1, 1, 1}
    instance.size = size or 2
    instance.rotation = 0
    instance.rotationSpeed = (math.random() - 0.5) * 10
    instance.gravity = 0
    instance.friction = 0.98
    instance.alpha = 1
    
    return instance
end

function Particle:update(dt)
    -- Atualiza posição
    self.x = self.x + self.vx * dt
    self.y = self.y + self.vy * dt
    
    -- Aplica gravidade
    self.vy = self.vy + self.gravity * dt
    
    -- Aplica fricção
    self.vx = self.vx * self.friction
    self.vy = self.vy * self.friction
    
    -- Atualiza rotação
    self.rotation = self.rotation + self.rotationSpeed * dt
    
    -- Atualiza vida
    self.life = self.life - dt
    self.alpha = self.life / self.maxLife
    
    -- Atualiza cor com alpha (com verificação de segurança)
    if self.color and self.color[1] and self.color[2] and self.color[3] and self.color[4] then
        self.currentColor = {
            self.color[1],
            self.color[2], 
            self.color[3],
            self.color[4] * self.alpha
        }
    else
        -- Cor padrão se algo estiver nil
        self.currentColor = {1, 1, 1, self.alpha}
    end
end

function Particle:draw()
    if self.life <= 0 then return end
    
    -- Verificação de segurança para cor
    if self.currentColor and self.currentColor[1] and self.currentColor[2] and self.currentColor[3] and self.currentColor[4] then
        love.graphics.setColor(self.currentColor)
    else
        love.graphics.setColor(1, 1, 1, 1) -- Cor padrão
    end
    
    love.graphics.push()
    love.graphics.translate(self.x, self.y)
    love.graphics.rotate(self.rotation)
    
    -- Desenha partícula como quadrado rotacionado
    love.graphics.rectangle("fill", -self.size/2, -self.size/2, self.size, self.size)
    
    love.graphics.pop()
end

function Particle:isDead()
    return self.life <= 0
end

-- Gerenciador de partículas
local ParticleManager = {}
ParticleManager.__index = ParticleManager

function ParticleManager:new()
    local instance = setmetatable({}, ParticleManager)
    instance.particles = {}
    instance.emitters = {}
    
    return instance
end

function ParticleManager:addParticle(particle)
    table.insert(self.particles, particle)
end

function ParticleManager:addEmitter(emitter)
    table.insert(self.emitters, emitter)
end

function ParticleManager:update(dt)
    -- Atualiza partículas
    for i = #self.particles, 1, -1 do
        local particle = self.particles[i]
        particle:update(dt)
        
        if particle:isDead() then
            table.remove(self.particles, i)
        end
    end
    
    -- Atualiza emissores
    for i = #self.emitters, 1, -1 do
        local emitter = self.emitters[i]
        emitter:update(dt, self)
        
        if emitter:isDead() then
            table.remove(self.emitters, i)
        end
    end
end

function ParticleManager:draw()
    for _, particle in ipairs(self.particles) do
        particle:draw()
    end
end

-- Emissor de partículas
local Emitter = {}
Emitter.__index = Emitter

function Emitter:new(x, y, config)
    local instance = setmetatable({}, Emitter)
    instance.x = x
    instance.y = y
    instance.config = config or {}
    instance.life = config.life or 1.0
    instance.maxLife = config.life or 1.0
    instance.rate = config.rate or 10 -- partículas por segundo
    instance.timer = 0
    instance.particleLife = config.particleLife or 1.0
    instance.particleSpeed = config.particleSpeed or 50
    instance.particleSize = config.particleSize or 2
    instance.particleColor = config.particleColor or {1, 1, 1, 1}
    instance.spread = config.spread or math.pi * 2 -- 360 graus
    instance.direction = config.direction or 0
    
    return instance
end

function Emitter:update(dt, particleManager)
    self.life = self.life - dt
    self.timer = self.timer + dt
    
    local particlesPerFrame = self.rate * dt
    local particlesToEmit = math.floor(particlesPerFrame)
    
    -- Emite partículas
    for i = 1, particlesToEmit do
        local angle = self.direction + (math.random() - 0.5) * self.spread
        local speed = self.particleSpeed * (0.5 + math.random() * 0.5)
        local vx = math.cos(angle) * speed
        local vy = math.sin(angle) * speed
        
        local particle = Particle:new(
            self.x, self.y, vx, vy, 
            self.particleLife, self.particleColor, self.particleSize
        )
        
        particleManager:addParticle(particle)
    end
end

function Emitter:isDead()
    return self.life <= 0
end

-- Presets de partículas inspirados no Balatro
ParticleSystem.Presets = {
    -- Efeito de joker ativado
    JOKER_ACTIVATED = function(x, y)
        return Emitter:new(x, y, {
            life = 0.5,
            rate = 20,
            particleLife = 1.0,
            particleSpeed = 100,
            particleSize = 3,
            particleColor = {1, 0.8, 0.2, 1}, -- Dourado
            spread = math.pi * 0.5,
            direction = -math.pi / 2 -- Para cima
        })
    end,
    
    -- Efeito de carta jogada
    CARD_PLAYED = function(x, y)
        return Emitter:new(x, y, {
            life = 0.3,
            rate = 15,
            particleLife = 0.8,
            particleSpeed = 80,
            particleSize = 2,
            particleColor = {0.8, 0.6, 0.2, 1}, -- Dourado escuro
            spread = math.pi * 0.3,
            direction = 0
        })
    end,
    
    -- Efeito de hover
    HOVER_EFFECT = function(x, y)
        return Emitter:new(x, y, {
            life = 0.2,
            rate = 8,
            particleLife = 0.6,
            particleSpeed = 30,
            particleSize = 1,
            particleColor = {0.6, 0.8, 1, 0.8}, -- Azul claro
            spread = math.pi * 0.2,
            direction = 0
        })
    end,
    
    -- Efeito de dano
    DAMAGE_EFFECT = function(x, y)
        return Emitter:new(x, y, {
            life = 0.4,
            rate = 25,
            particleLife = 0.7,
            particleSpeed = 120,
            particleSize = 2,
            particleColor = {1, 0.3, 0.3, 1}, -- Vermelho
            spread = math.pi * 0.4,
            direction = 0
        })
    end
}

-- Instância global do gerenciador de partículas
ParticleSystem.Manager = ParticleManager:new()

return ParticleSystem
