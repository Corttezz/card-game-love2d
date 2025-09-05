-- components/JokerSlot.lua
-- Componente de slot de joker com design clean e moderno inspirado no Balatro

local JokerSlot = {}
JokerSlot.__index = JokerSlot

local Theme = require("src.ui.Theme")
local VisualEffects = require("src.ui.VisualEffects")

function JokerSlot:new(x, y, size)
    local instance = setmetatable({}, JokerSlot)
    instance.x = x
    instance.y = y
    instance.size = size
    instance.joker = nil
    instance.hover = false
    instance.animationTime = 0
    instance.glowIntensity = 0
    instance.targetGlow = 0
    instance.scale = 1
    instance.targetScale = 1
    instance.pulseIntensity = 0
    
    return instance
end

function JokerSlot:update(dt)
    self.animationTime = self.animationTime + dt
    
    -- Atualiza hover
    local mx, my = love.mouse.getPosition()
    local wasHovered = self.hover
    self.hover = mx > self.x and mx < self.x + self.size and
                 my > self.y and my < self.y + self.size
    
    -- Efeitos de hover
    if self.hover then
        self.targetGlow = 1
        self.targetScale = 1.05
        self.pulseIntensity = 1
        
    else
        self.targetGlow = 0
        self.targetScale = 1
        self.pulseIntensity = 0
    end
    
    -- Animações suaves
    self.glowIntensity = self.glowIntensity + (self.targetGlow - self.glowIntensity) * 8 * dt
    self.scale = self.scale + (self.targetScale - self.scale) * 10 * dt
end

function JokerSlot:draw()
    local centerX = self.x + self.size / 2
    local centerY = self.y + self.size / 2
    
    love.graphics.push()
    love.graphics.translate(centerX, centerY)
    love.graphics.scale(self.scale, self.scale)
    
    if self.joker then
        self:drawOccupiedSlot()
    else
        self:drawEmptySlot()
    end
    
    love.graphics.pop()
end

function JokerSlot:drawOccupiedSlot()
    local halfSize = self.size / 2
    
    -- IMAGEM DA CARTA (principal)
    if self.joker and self.joker.image then
        -- Calcula o tamanho da imagem para caber no slot
        local imageWidth = self.joker.image:getWidth()
        local imageHeight = self.joker.image:getHeight()
        local scale = math.min(self.size / imageWidth, self.size / imageHeight) -- 80% do slot
        
        -- Desenha a imagem da carta centralizada
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(
            self.joker.image, 
            0, -5, -- Ligeiramente acima do centro
            0, -- Sem rotação
            scale, scale, -- Escala
            imageWidth/2, imageHeight/2 -- Ponto de origem no centro
        )
    end
    
end

function JokerSlot:drawEmptySlot()
    local halfSize = self.size / 2
    
    -- Background com transparência (sem bordas)
    love.graphics.setColor(0.1, 0.1, 0.15, 0.3)
    love.graphics.rectangle("fill", -halfSize, -halfSize, self.size, self.size, 40, 40)
    
    -- Símbolo de "+" minimalista
    local plusFont = love.graphics.newFont(20)
    love.graphics.setFont(plusFont)
    love.graphics.setColor(0.5, 0.5, 0.6, 0.8)
    
    
    -- Texto "VAZIO" com tipografia clean
    local emptyFont = love.graphics.newFont(8)
    love.graphics.setFont(emptyFont)
    love.graphics.setColor(0.4, 0.4, 0.5, 0.7)    
end


function JokerSlot:setJoker(joker)
    self.joker = joker
    
end

function JokerSlot:removeJoker()
    self.joker = nil
end

function JokerSlot:isOccupied()
    return self.joker ~= nil
end

return JokerSlot
