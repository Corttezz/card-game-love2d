local Config = require("src.core.Config")

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
    -- Toasts CENTRADOS no topo (sob a TopBar) — o canto esquerdo em
    -- x=10/y=100 caía EM CIMA do quadro de coringas do combate (feedback
    -- Jul/2026: "os jokers ficam em cima de onde aparecem os textos").
    -- Centro é o padrão StS/Balatro e fica livre em todas as telas.
    local FontManager = require("src.ui.FontManager")
    local sw = love.graphics.getWidth()
    local font = FontManager.getFont(12)
    love.graphics.setFont(font)
    local y = 64
    for i, message in ipairs(self.messages) do
        local color = self:getColorByType(message.type)
        local x = math.floor((sw - font:getWidth(message.text)) / 2)

        -- Sombra do texto
        love.graphics.setColor(0, 0, 0, message.alpha * 0.7)
        love.graphics.print(message.text, x + 2, y + 2)

        -- Texto principal
        love.graphics.setColor(color[1], color[2], color[3], message.alpha)
        love.graphics.print(message.text, x, y)

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
