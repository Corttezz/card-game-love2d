local Debug = require("src.core.Debug")

local SmokeSystem = {}

SmokeSystem.config = {
    maxParticles = 4,
    spawnRate = 2.0,
    minScale = 1.2,
    maxScale = 2.0,
    minOpacity = 0.02,
    maxOpacity = 0.08,
    minSpeed = 15,
    maxSpeed = 25,
    windEffect = 0.3,
    fadeInTime = 1.5,
    centerZone = 1.0,
    maxOffscreenDistance = 200
}

SmokeSystem.particles = {}

SmokeSystem.textures = {}

SmokeSystem.lastSpawnTime = 0

function SmokeSystem:new()
    local instance = setmetatable({}, { __index = SmokeSystem })
    instance:initialize()
    return instance
end

function SmokeSystem:initialize()
    self:loadTextures()

    self.particles = {}
    self.lastSpawnTime = 0

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
            texture:setFilter("linear", "linear")
            table.insert(self.textures, texture)
        else
            Debug.warn("[SmokeSystem] AVISO: não foi possível carregar textura:", path)
        end
    end
end

function SmokeSystem:update(dt)
    for i = #self.particles, 1, -1 do
        local particle = self.particles[i]
        particle.age = particle.age + dt

        particle.x = particle.x + particle.vx * dt
        particle.y = particle.y + particle.vy * dt

        particle.x = particle.x + self.config.windEffect * dt

        particle.vy = particle.vy + math.sin(particle.age * 2) * 0.5 * dt
        particle.vy = math.max(-30, math.min(30, particle.vy))

        particle.rotation = particle.rotation + particle.rotationSpeed * dt

        particle.currentScale = particle.scale * (1 + dt * 0.01)

        if particle.fadeInProgress < 1 then
            particle.fadeInProgress = particle.fadeInProgress + dt / self.config.fadeInTime
            particle.currentOpacity = particle.opacity * math.min(1, particle.fadeInProgress)
        else
            particle.currentOpacity = particle.opacity
        end

        local screenWidth = love.graphics.getWidth()
        local screenHeight = love.graphics.getHeight()
        local offscreenDistance = self.config.maxOffscreenDistance

        if particle.x < -offscreenDistance or
           particle.x > screenWidth + offscreenDistance or
           particle.y < -offscreenDistance or
           particle.y > screenHeight + offscreenDistance then
            table.remove(self.particles, i)
        end
    end

    self.lastSpawnTime = self.lastSpawnTime + dt
    if self.lastSpawnTime >= self.config.spawnRate and #self.particles < self.config.maxParticles then
        self:spawnParticle()
        self.lastSpawnTime = 0
    end
end

function SmokeSystem:spawnParticle()
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()

    local texture = self.textures[love.math.random(1, #self.textures)]
    if not texture then return end

    local startX = love.math.random(0, screenWidth)
    local startY = love.math.random(0, screenHeight)

    local speed = love.math.random(self.config.minSpeed, self.config.maxSpeed)

    local vx = love.math.random(-8, 8)
    local vy = -speed

        local particle = {
            x = startX,
            y = startY,
            vx = vx,
            vy = vy,
            scale = love.math.random(self.config.minScale * 100, self.config.maxScale * 100) / 100,
            currentScale = 1,
            opacity = love.math.random(self.config.minOpacity * 100, self.config.maxOpacity * 100) / 100,
            currentOpacity = 0,
            fadeInProgress = 0,
            texture = texture,
            rotation = (love.math.random() - 0.5) * 0.3,
            rotationSpeed = 0,
            age = 0
        }

    table.insert(self.particles, particle)
end

function SmokeSystem:draw()
    for _, particle in ipairs(self.particles) do
        if particle.currentOpacity > 0 then
            love.graphics.setColor(1, 1, 1, particle.currentOpacity)

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

function SmokeSystem:getStats()
    return {
        activeParticles = #self.particles,
        maxParticles = self.config.maxParticles,
        texturesLoaded = #self.textures
    }
end

return SmokeSystem
