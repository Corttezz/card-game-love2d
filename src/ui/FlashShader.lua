local Debug = require("src.core.Debug")

local FlashShader = {}

local shader
local loaded = false
local intensity = 0
local decayTimer = 0
local decayDuration = 0.3
local attackTimer, attackDuration, target = 0, 0, 0

function FlashShader.load()
    local ok, s = pcall(love.graphics.newShader, "shaders/flash.glsl")
    if not ok then
        Debug.warn("[FlashShader] falha ao carregar shaders/flash.glsl: " .. tostring(s))
        return false
    end
    shader = s
    loaded = true
    return true
end

function FlashShader.isAvailable()
    return loaded
end

function FlashShader.trigger(i, duration, attack)
    local v = math.max(0, math.min(1, i or 0.5))
    decayDuration = duration or 0.3
    if attack and attack > 0 then
        target = math.max(target, v)
        attackDuration, attackTimer = attack, attack
        return
    end
    intensity = math.max(intensity, v)
    decayTimer = decayDuration
end

function FlashShader.intensity() return intensity end

function FlashShader.update(dt)
    if attackTimer > 0 then
        attackTimer = attackTimer - dt
        local k = 1 - math.max(0, attackTimer) / attackDuration
        intensity = math.max(intensity, target * k * k)
        if attackTimer <= 0 then
            intensity, target, attackTimer = math.max(intensity, target), 0, 0
            decayTimer = decayDuration
        end
        return
    end
    if decayTimer > 0 then
        decayTimer = decayTimer - dt
        if decayTimer <= 0 then
            intensity = 0
            decayTimer = 0
        else
            intensity = intensity * (decayTimer / decayDuration)
        end
    end
end

function FlashShader.draw()
    if not loaded or intensity <= 0.001 then return end
    local w, h = love.graphics.getDimensions()
    love.graphics.setShader(shader)
    shader:send("time", love.timer.getTime())
    shader:send("mid_flash", intensity)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, w, h)
    love.graphics.setShader()
end

function FlashShader.drawPlain(alpha)
    alpha = math.max(0, math.min(1, alpha or 0))
    if alpha <= 0 then return end
    local w, h = love.graphics.getDimensions()
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.rectangle("fill", 0, 0, w, h)
    love.graphics.setColor(1, 1, 1, 1)
end

return FlashShader
