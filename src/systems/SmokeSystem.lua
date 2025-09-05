-- src/systems/SmokeSystem.lua
-- Sistema de partículas de smoke para efeitos de fundo sutis

local SmokeSystem = {}

-- Configurações do sistema
SmokeSystem.config = {
    maxParticles = 4,            -- Número máximo de partículas (muito reduzido)
    spawnRate = 2.0,             -- Taxa de spawn (segundos) - Mais lento
    minScale = 1.2,              -- Escala mínima (reduzida)
    maxScale = 2.0,              -- Escala máxima (reduzida)
    minOpacity = 0.02,           -- Opacidade mínima (muito sutil)
    maxOpacity = 0.08,           -- Opacidade máxima (ainda sutil)
    minSpeed = 15,                -- Velocidade mínima (pixels/segundo) - Reduzida
    maxSpeed = 25,                -- Velocidade máxima (pixels/segundo) - Reduzida
    windEffect = 0.3,             -- Efeito de vento (pixels/segundo) - Reduzido
    fadeInTime = 1.5,            -- Tempo para aparecer (segundos) - Mais lento
    centerZone = 1.0,            -- Zona da tela (100% - toda a tela)
    maxOffscreenDistance = 200   -- Distância máxima fora da tela antes de remover
}

-- Partículas ativas
SmokeSystem.particles = {}

-- Texturas de smoke
SmokeSystem.textures = {}

-- Tempo desde o último spawn
SmokeSystem.lastSpawnTime = 0

function SmokeSystem:new()
    local instance = setmetatable({}, { __index = SmokeSystem })
    instance:initialize()
    return instance
end

function SmokeSystem:initialize()
    -- Carrega as texturas de smoke
    self:loadTextures()
    
    -- Inicializa partículas
    self.particles = {}
    self.lastSpawnTime = 0
    
    print("SmokeSystem inicializado com", #self.textures, "texturas")
end

function SmokeSystem:loadTextures()
    local texturePaths = {
        "assets/effects/smoke1.png",
        "assets/effects/smoke2.png",
        "assets/effects/smoke3.png",
        "assets/effects/smoke4.png"
    }
    
    for i, path in ipairs(texturePaths) do
        local success, texture = pcall(love.graphics.newImage, path)
        if success then
            -- Configura a textura para alpha blending
            texture:setFilter("linear", "linear")
            table.insert(self.textures, texture)
            print("Smoke texture carregada:", path)
        else
            print("ERRO: Não foi possível carregar smoke texture:", path)
        end
    end
end

function SmokeSystem:update(dt)
    -- Atualiza partículas existentes
    for i = #self.particles, 1, -1 do
        local particle = self.particles[i]
        particle.age = particle.age + dt
        
        -- Atualiza posição com movimento contínuo e mais dinâmico
        particle.x = particle.x + particle.vx * dt
        particle.y = particle.y + particle.vy * dt
        
        -- Aplica efeito de vento mais forte
        particle.x = particle.x + self.config.windEffect * dt
        
        -- Adiciona movimento vertical sutil para mais naturalidade
        particle.vy = particle.vy + math.sin(particle.age * 2) * 0.5 * dt
        particle.vy = math.max(-30, math.min(30, particle.vy)) -- Limita movimento vertical
        
        -- Atualiza rotação
        particle.rotation = particle.rotation + particle.rotationSpeed * dt
        
        -- Atualiza escala com crescimento sutil
        particle.currentScale = particle.scale * (1 + dt * 0.01)
        
        -- Atualiza opacidade baseada no fade in
        if particle.fadeInProgress < 1 then
            particle.fadeInProgress = particle.fadeInProgress + dt / self.config.fadeInTime
            particle.currentOpacity = particle.opacity * math.min(1, particle.fadeInProgress)
        else
            particle.currentOpacity = particle.opacity
        end
        
        -- Verifica se a partícula saiu muito da tela
        local screenWidth = love.graphics.getWidth()
        local screenHeight = love.graphics.getHeight()
        local offscreenDistance = self.config.maxOffscreenDistance
        
        if particle.x < -offscreenDistance or 
           particle.x > screenWidth + offscreenDistance or
           particle.y < -offscreenDistance or 
           particle.y > screenHeight + offscreenDistance then
            -- Remove partícula que saiu muito da tela
            table.remove(self.particles, i)
        end
    end
    
    -- Spawn de novas partículas
    self.lastSpawnTime = self.lastSpawnTime + dt
    if self.lastSpawnTime >= self.config.spawnRate and #self.particles < self.config.maxParticles then
        self:spawnParticle()
        self.lastSpawnTime = 0
    end
end

function SmokeSystem:spawnParticle()
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    -- Escolhe uma textura aleatória
    local texture = self.textures[love.math.random(1, #self.textures)]
    if not texture then return end
    
    -- Posição inicial aleatória por toda a tela (não apenas centro)
    local startX = love.math.random(0, screenWidth)
    local startY = love.math.random(0, screenHeight)
    
    -- Velocidade com movimento vertical natural (para cima)
    local speed = love.math.random(self.config.minSpeed, self.config.maxSpeed)
    
    -- Movimento principalmente vertical para cima com variação horizontal
    local vx = love.math.random(-8, 8) -- Movimento horizontal sutil
    local vy = -speed -- Movimento vertical para cima (negativo)
    
            -- Propriedades da partícula
        local particle = {
            x = startX,
            y = startY,
            vx = vx,
            vy = vy,
            scale = love.math.random(self.config.minScale * 100, self.config.maxScale * 100) / 100,
            currentScale = 1,
            opacity = love.math.random(self.config.minOpacity * 100, self.config.maxOpacity * 100) / 100,
            currentOpacity = 0, -- Começa transparente
            fadeInProgress = 0, -- Progresso do fade in
            texture = texture,
            rotation = love.math.random(0, math.pi * 2), -- Rotação aleatória
            rotationSpeed = love.math.random(-0.05, 0.05), -- Velocidade de rotação muito reduzida
            age = 0 -- Idade da partícula
        }
    
    table.insert(self.particles, particle)
end

function SmokeSystem:draw()
    -- Desenha todas as partículas de smoke
    for _, particle in ipairs(self.particles) do
        if particle.currentOpacity > 0 then
            -- Configura cor e opacidade
            love.graphics.setColor(1, 1, 1, particle.currentOpacity)
            
            -- Desenha a partícula
            love.graphics.draw(
                particle.texture,
                particle.x,
                particle.y,
                particle.rotation,
                particle.currentScale,
                particle.currentScale,
                particle.texture:getWidth() / 2,
                particle.texture:getHeight() / 2
            )
        end
    end
    
    -- Reseta cor
    love.graphics.setColor(1, 1, 1, 1)
end

function SmokeSystem:clear()
    self.particles = {}
    self.lastSpawnTime = 0
end

function SmokeSystem:setConfig(newConfig)
    for key, value in pairs(newConfig) do
        if self.config[key] ~= nil then
            self.config[key] = value
        end
    end
end

-- Função para obter estatísticas (debug)
function SmokeSystem:getStats()
    return {
        activeParticles = #self.particles,
        maxParticles = self.config.maxParticles,
        texturesLoaded = #self.textures
    }
end

return SmokeSystem
