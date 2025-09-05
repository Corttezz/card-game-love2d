-- src/Animation.lua
-- Sistema de animações profissionais para o jogo

local Animation = {}

-- Tipos de easing (funções de transição)
Animation.Easing = {
    -- Linear (sem easing)
    LINEAR = function(t) return t end,
    
    -- Easing suave (ease-in-out)
    SMOOTH = function(t) return t * t * (3 - 2 * t) end,
    
    -- Easing com bounce
    BOUNCE = function(t)
        if t < 1/2.75 then
            return 7.5625 * t * t
        elseif t < 2/2.75 then
            t = t - 1.5/2.75
            return 7.5625 * t * t + 0.75
        elseif t < 2.5/2.75 then
            t = t - 2.25/2.75
            return 7.5625 * t * t + 0.9375
        else
            t = t - 2.625/2.75
            return 7.5625 * t * t + 0.984375
        end
    end,
    
    -- Easing elástico
    ELASTIC = function(t)
        if t == 0 then return 0 end
        if t == 1 then return 1 end
        
        return math.pow(2, -10 * t) * math.sin((t - 0.075) * (2 * math.pi) / 0.3) + 1
    end,
    
    -- Easing de entrada suave
    EASE_IN = function(t) return t * t end,
    
    -- Easing de saída suave
    EASE_OUT = function(t) return 1 - (1 - t) * (1 - t) end,
    
    -- Easing de entrada e saída
    EASE_IN_OUT = function(t)
        if t < 0.5 then
            return 2 * t * t
        else
            return 1 - 2 * (1 - t) * (1 - t)
        end
    end
}

-- Classe de animação individual
local AnimationInstance = {}
AnimationInstance.__index = AnimationInstance

function AnimationInstance:new(target, property, startValue, endValue, duration, easing, onComplete)
    local instance = setmetatable({}, AnimationInstance)
    instance.target = target
    instance.property = property
    instance.startValue = startValue
    instance.endValue = endValue
    instance.duration = duration
    instance.easing = easing or Animation.Easing.SMOOTH
    instance.onComplete = onComplete
    instance.currentTime = 0
    instance.isComplete = false
    instance.isPaused = false
    
    return instance
end

function AnimationInstance:update(dt)
    if self.isComplete or self.isPaused then return end
    
    self.currentTime = self.currentTime + dt
    
    if self.currentTime >= self.duration then
        -- Animação completa
        self.currentTime = self.duration
        self.isComplete = true
        self.target[self.property] = self.endValue
        
        if self.onComplete then
            self.onComplete()
        end
    else
        -- Atualiza valor
        local progress = self.currentTime / self.duration
        local easedProgress = self.easing(progress)
        
        if type(self.startValue) == "table" then
            -- Para valores de cor (interpola cada componente)
            self.target[self.property] = {
                self.startValue[1] + (self.endValue[1] - self.startValue[1]) * easedProgress,
                self.startValue[2] + (self.endValue[2] - self.startValue[2]) * easedProgress,
                self.startValue[3] + (self.endValue[3] - self.startValue[3]) * easedProgress,
                self.startValue[4] + (self.endValue[4] - self.startValue[4]) * easedProgress
            }
        else
            -- Para valores numéricos
            self.target[self.property] = self.startValue + (self.endValue - self.startValue) * easedProgress
        end
    end
end

function AnimationInstance:pause()
    self.isPaused = true
end

function AnimationInstance:resume()
    self.isPaused = false
end

function AnimationInstance:stop()
    self.isComplete = true
end

function AnimationInstance:reset()
    self.currentTime = 0
    self.isComplete = false
    self.target[self.property] = self.startValue
end

-- Gerenciador de animações
local AnimationManager = {}
AnimationManager.__index = AnimationManager

function AnimationManager:new()
    local instance = setmetatable({}, AnimationManager)
    instance.animations = {}
    instance.nextId = 1
    
    return instance
end

function AnimationManager:addAnimation(target, property, startValue, endValue, duration, easing, onComplete)
    local animation = AnimationInstance:new(target, property, startValue, endValue, duration, easing, onComplete)
    local id = self.nextId
    self.nextId = self.nextId + 1
    
    self.animations[id] = animation
    return id
end

function AnimationManager:update(dt)
    local completedAnimations = {}
    
    for id, animation in pairs(self.animations) do
        animation:update(dt)
        
        if animation.isComplete then
            table.insert(completedAnimations, id)
        end
    end
    
    -- Remove animações completas
    for _, id in ipairs(completedAnimations) do
        self.animations[id] = nil
    end
end

function AnimationManager:stopAnimation(id)
    if self.animations[id] then
        self.animations[id]:stop()
        self.animations[id] = nil
    end
end

function AnimationManager:stopAllAnimations()
    self.animations = {}
end

function AnimationManager:getAnimationCount()
    local count = 0
    for _ in pairs(self.animations) do
        count = count + 1
    end
    return count
end

-- Animações pré-definidas comuns
Animation.Presets = {
    -- Fade in
    FADE_IN = function(target, duration, onComplete)
        return Animation.Manager:addAnimation(target, "alpha", 0, 1, duration, Animation.Easing.SMOOTH, onComplete)
    end,
    
    -- Fade out
    FADE_OUT = function(target, duration, onComplete)
        return Animation.Manager:addAnimation(target, "alpha", 1, 0, duration, Animation.Easing.SMOOTH, onComplete)
    end,
    
    -- Slide in da esquerda
    SLIDE_IN_LEFT = function(target, distance, duration, onComplete)
        local startX = target.x - distance
        local endX = target.x
        target.x = startX
        return Animation.Manager:addAnimation(target, "x", startX, endX, duration, Animation.Easing.BOUNCE, onComplete)
    end,
    
    -- Slide in da direita
    SLIDE_IN_RIGHT = function(target, distance, duration, onComplete)
        local startX = target.x + distance
        local endX = target.x
        target.x = startX
        return Animation.Manager:addAnimation(target, "x", startX, endX, duration, Animation.Easing.BOUNCE, onComplete)
    end,
    
    -- Scale in
    SCALE_IN = function(target, duration, onComplete)
        local startScale = 0
        local endScale = 1
        target.scale = startScale
        return Animation.Manager:addAnimation(target, "scale", startScale, endScale, duration, Animation.Easing.BOUNCE, onComplete)
    end,
    
    -- Scale out
    SCALE_OUT = function(target, duration, onComplete)
        local startScale = 1
        local endScale = 0
        target.scale = startScale
        return Animation.Manager:addAnimation(target, "scale", startScale, endScale, duration, Animation.Easing.SMOOTH, onComplete)
    end,
    
    -- Pulse (scale in e out)
    PULSE = function(target, duration, onComplete)
        local startScale = 1
        local endScale = 1.2
        target.scale = startScale
        
        local id1 = Animation.Manager:addAnimation(target, "scale", startScale, endScale, duration/2, Animation.Easing.EASE_OUT)
        local id2 = Animation.Manager:addAnimation(target, "scale", endScale, startScale, duration/2, Animation.Easing.EASE_IN)
        
        -- Chama onComplete quando a segunda animação terminar
        if onComplete then
            Animation.Manager.animations[id2].onComplete = onComplete
        end
        
        return id1, id2
    end,
    
    -- Shake (tremor)
    SHAKE = function(target, intensity, duration, onComplete)
        local originalX = target.x
        local shakeCount = math.floor(duration * 20) -- 20 shakes por segundo
        
        local function createShake()
            local shakeId = Animation.Manager:addAnimation(target, "x", originalX, originalX + (math.random() - 0.5) * intensity, 0.05, Animation.Easing.LINEAR)
            
            if shakeCount > 0 then
                shakeCount = shakeCount - 1
                -- Agenda próximo shake
                Timer.after(0.05, createShake)
            else
                -- Retorna à posição original
                Animation.Manager:addAnimation(target, "x", target.x, originalX, 0.1, Animation.Easing.SMOOTH, onComplete)
            end
        end
        
        createShake()
    end
}

-- Instância global do gerenciador de animações
Animation.Manager = AnimationManager:new()

return Animation
