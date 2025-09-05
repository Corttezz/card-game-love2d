local Config = require("src.Config")

local MessageSystem = {}
MessageSystem.__index = MessageSystem

function MessageSystem:new()
    local instance = setmetatable({}, MessageSystem)
    instance.messages = {}
    instance.maxMessages = Config.Game.MAX_MESSAGES
    instance.messageDuration = Config.Game.MESSAGE_DURATION -- 3 segundos
    return instance
end

function MessageSystem:addMessage(text, type)
    type = type or "info"
    local message = {
        text = text,
        type = type,
        duration = self.messageDuration,
        alpha = 1.0,
        y = 0
    }
    
    table.insert(self.messages, message)
    
    -- Remove mensagens antigas se exceder o limite
    if #self.messages > self.maxMessages then
        table.remove(self.messages, 1)
    end
end

function MessageSystem:update(dt)
    for i = #self.messages, 1, -1 do
        local message = self.messages[i]
        message.duration = message.duration - dt
        
        -- Animação de fade out
        if message.duration < 1.0 then
            message.alpha = message.duration
        end
        
        -- Remove mensagens expiradas
        if message.duration <= 0 then
            table.remove(self.messages, i)
        end
    end
end

function MessageSystem:draw()
    local y = 100
    for i, message in ipairs(self.messages) do
        local color = self:getColorByType(message.type)
        love.graphics.setColor(color[1], color[2], color[3], message.alpha)
        
        -- Sombra do texto
        love.graphics.setColor(0, 0, 0, message.alpha * 0.7)
        love.graphics.print(message.text, 12, y + 2)
        
        -- Texto principal
        love.graphics.setColor(color[1], color[2], color[3], message.alpha)
        love.graphics.print(message.text, 10, y)
        
        y = y + 25
    end
    
    -- Reseta cor
    love.graphics.setColor(1, 1, 1, 1)
end

function MessageSystem:getColorByType(type)
    if type == "error" then
        return {1, 0.3, 0.3} -- Vermelho
    elseif type == "warning" then
        return {1, 1, 0.3} -- Amarelo
    elseif type == "success" then
        return {0.3, 1, 0.3} -- Verde
    elseif type == "info" then
        return {0.3, 0.7, 1} -- Azul
    else
        return {1, 1, 1} -- Branco
    end
end

return MessageSystem
