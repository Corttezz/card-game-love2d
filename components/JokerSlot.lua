local JokerSlot = {}
JokerSlot.__index = JokerSlot

local Moveable = require("engine.Moveable")

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

    Moveable.initJuice(instance)

    return instance
end

function JokerSlot:juice_up(scale_mod, rot_mod)
    Moveable.juice_up(self, scale_mod, rot_mod)
end

function JokerSlot:update(dt)
    self.animationTime = self.animationTime + dt

    local mx, my = love.mouse.getPosition()
    self.hover = mx > self.x and mx < self.x + self.size and
                 my > self.y and my < self.y + self.size

    if self.hover then
        self.targetGlow = 1
        self.targetScale = 1.05
        self.pulseIntensity = 1

    else
        self.targetGlow = 0
        self.targetScale = 1
        self.pulseIntensity = 0
    end

    local glowEase = 1 - math.exp(-8 * dt)
    self.glowIntensity = self.glowIntensity + (self.targetGlow - self.glowIntensity) * glowEase
    local scaleEase = 1 - math.exp(-10 * dt)
    self.scale = self.scale + (self.targetScale - self.scale) * scaleEase

    Moveable.updateJuice(self, dt)
end

function JokerSlot:draw()
    local centerX = self.x + self.size / 2
    local centerY = self.y + self.size / 2

    love.graphics.push()
    love.graphics.translate(centerX, centerY)
    local finalScale = self.scale * Moveable.scaleFactor(self)
    love.graphics.scale(finalScale, finalScale)
    love.graphics.rotate(Moveable.rotOffset(self))

    if self.joker then
        self:drawOccupiedSlot()
    else
        self:drawEmptySlot()
    end

    love.graphics.pop()
end

function JokerSlot:drawOccupiedSlot()
    if self.joker and self.joker.image then
        local img = require("src.ui.CardFrame").displayImage(self.joker) or self.joker.image
        local imageWidth = img:getWidth()
        local imageHeight = img:getHeight()
        local scale = math.min(self.size / imageWidth, self.size / imageHeight)

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(
            img,
            0, -5,
            0,
            scale, scale,
            imageWidth/2, imageHeight/2
        )
    end

end

function JokerSlot:drawEmptySlot()
    local halfSize = self.size / 2

    love.graphics.setColor(0.1, 0.1, 0.15, 0.3)
    love.graphics.rectangle("fill", -halfSize, -halfSize, self.size, self.size, 40, 40)
end

function JokerSlot:setJoker(joker)
    self.joker = joker
    Moveable.juice_up(self, 0.4, 0.12)
end

function JokerSlot:removeJoker()
    self.joker = nil
end

function JokerSlot:isOccupied()
    return self.joker ~= nil
end

return JokerSlot
