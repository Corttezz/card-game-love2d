-- components/Button.lua
local Theme = require("src.ui.Theme")

local Button = {}
Button.__index = Button

function Button:new(x, y, width, height, text, onClick, color, fontSize)
    local btn = setmetatable({}, Button)
    btn.x = x
    btn.y = y
    btn.width = width or 200
    btn.height = height or 60
    btn.text = text
    btn.onClick = onClick or function() end
    btn.hover = false
    btn.pressed = false
    btn.disabled = false
    btn.visible = true
    
    -- Cores baseadas no tema
    btn.baseColor = color or Theme.Colors.PRIMARY
    btn.hoverColor = Theme.Utils.interpolateColor(btn.baseColor, {1, 1, 1, 1}, 0.2)
    btn.pressColor = Theme.Utils.interpolateColor(btn.baseColor, {0, 0, 0, 0.3}, 0.3)
    btn.disabledColor = Theme.Colors.TEXT_DISABLED
    
    -- Fonte
    btn.font = love.graphics.newFont(fontSize or 20)
    
    -- Estado de animação simples
    btn.alpha = 1
    btn.scale = 1
    btn.targetScale = 1
    
    return btn
end

function Button:update(dt)
    if not self.visible or self.disabled then return end

    local mx, my = love.mouse.getPosition()
    local wasHover = self.hover
    self.hover = mx > self.x and mx < self.x + self.width and
                 my > self.y and my < self.y + self.height
    
    -- Debug: loga mudanças de hover
    if wasHover ~= self.hover then
        print("Button '" .. (self.text or "unnamed") .. "' hover changed: " .. tostring(wasHover) .. " -> " .. tostring(self.hover))
        print("  - Mouse at: (" .. mx .. ", " .. my .. ")")
        print("  - Button at: (" .. self.x .. ", " .. self.y .. ") size (" .. self.width .. "x" .. self.height .. ")")
    end

    -- Animação de escala simples
    if self.hover then
        self.targetScale = 1.02
    else
        self.targetScale = 1.0
    end
    
    -- Transição suave da escala
    self.scale = self.scale + (self.targetScale - self.scale) * 10 * dt
end

function Button:draw()
    if not self.visible then return end

    -- Aplica escala
    local scale = self.scale
    local offsetX = (self.width * (scale - 1)) / 2
    local offsetY = (self.height * (scale - 1)) / 2

    -- Cor do botão baseada no estado
    local currentColor
    if self.disabled then
        currentColor = self.disabledColor
    elseif self.pressed then
        currentColor = self.pressColor
    elseif self.hover then
        currentColor = self.hoverColor
    else
        currentColor = self.baseColor
    end

    -- Sombra sutil
    love.graphics.setColor(0, 0, 0, 0.2)
    love.graphics.rectangle("fill", 
        self.x - offsetX + 2, 
        self.y - offsetY + 2, 
        self.width * scale, 
        self.height * scale, 
        8, 8
    )

    -- Botão principal
    love.graphics.setColor(currentColor)
    love.graphics.rectangle("fill", 
        self.x - offsetX, 
        self.y - offsetY, 
        self.width * scale, 
        self.height * scale, 
        8, 8
    )

    -- Borda sutil
    love.graphics.setColor(Theme.Colors.UI_BORDER)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", 
        self.x - offsetX, 
        self.y - offsetY, 
        self.width * scale, 
        self.height * scale, 
        8, 8
    )

    -- Texto centralizado
    love.graphics.setFont(self.font)
    local textWidth = self.font:getWidth(self.text)
    local textHeight = self.font:getHeight(self.text)

    -- Sombra do texto
    local textColor = self.disabled and Theme.Colors.TEXT_DISABLED or Theme.Colors.TEXT_PRIMARY
    
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.print(self.text, 
        self.x + (self.width - textWidth) / 2 - offsetX + 1, 
        self.y + (self.height - textHeight) / 2 - offsetY + 1)
    
    -- Texto principal
    love.graphics.setColor(textColor)
    love.graphics.print(self.text, 
        self.x + (self.width - textWidth) / 2 - offsetX, 
        self.y + (self.height - textHeight) / 2 - offsetY)
end

function Button:mousepressed(x, y, button)
    if not self.visible or self.disabled then return end
    
    if button == 1 and self.hover then
        self.pressed = true
    end
end

function Button:mousereleased(x, y, button)
    if not self.visible or self.disabled then return end
    
    if button == 1 and self.pressed then
        -- Debug: verifica se o callback existe
        if self.onClick then
            print("Button clicked: " .. (self.text or "unnamed"))
            self.onClick()
        else
            print("WARNING: Button has no onClick callback: " .. (self.text or "unnamed"))
        end
    end
    self.pressed = false
end

-- Métodos para controle externo
function Button:setEnabled(enabled)
    self.disabled = not enabled
end

function Button:setVisible(visible)
    self.visible = visible
end

function Button:setText(newText)
    self.text = newText
end

function Button:setPosition(newX, newY)
    self.x = newX
    self.y = newY
end

return Button
