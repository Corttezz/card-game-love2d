-- src/ui/HudPanel.lua
-- Componente base para painéis de HUD com design elegante

local FontManager = require("src.ui.FontManager")
local Theme = require("src.ui.Theme")
local Config = require("src.core.Config")

local HudPanel = {}
HudPanel.__index = HudPanel

function HudPanel:new(x, y, width, height, options)
    local instance = setmetatable({}, HudPanel)
    
    instance.x = x or 0
    instance.y = y or 0
    instance.width = width or 200
    instance.height = height or 120
    
    -- Opções visuais
    instance.cornerRadius = 12
    instance.borderWidth = 2
    instance.padding = 16
    instance.animationTime = 0
    
    -- Estados de hover
    instance.isHovered = false
    instance.hoverTransition = 0 -- 0 = não hover, 1 = hover completo
    instance.hoverSpeed = 8.0
    
    -- Cores do tema
    instance.backgroundColor = options and options.backgroundColor or {0.08, 0.08, 0.12, 0.95}
    instance.borderColor = options and options.borderColor or {0.3, 0.3, 0.4, 0.8}
    instance.accentColor = options and options.accentColor or {0.4, 0.7, 1.0, 1.0}
    instance.textColor = options and options.textColor or {1, 1, 1, 1}
    
    -- Cores para hover
    instance.hoverBackgroundColor = options and options.hoverBackgroundColor or {0.12, 0.12, 0.18, 0.98}
    instance.hoverBorderColor = options and options.hoverBorderColor or {0.5, 0.5, 0.7, 1.0}
    instance.hoverAccentColor = options and options.hoverAccentColor or {0.6, 0.8, 1.0, 1.0}
    
    -- Efeitos visuais
    instance.glowIntensity = 0.3
    instance.pulseSpeed = 2.0
    instance.shadowOffset = 4
    instance.hoverShadowOffset = 8
    instance.hoverGlowIntensity = 0.6
    
    -- Partículas removidas - hover apenas com efeitos visuais básicos
    
    return instance
end

function HudPanel:update(dt)
    self.animationTime = self.animationTime + dt
    
    -- Detecção de hover
    local mx, my = love.mouse.getPosition()
    local wasHovered = self.isHovered
    self.isHovered = mx >= self.x and mx <= self.x + self.width and
                     my >= self.y and my <= self.y + self.height
    
    -- Animação suave de transição do hover
    local targetHover = self.isHovered and 1 or 0
    self.hoverTransition = self.hoverTransition + (targetHover - self.hoverTransition) * self.hoverSpeed * dt
    
    -- Partículas removidas - apenas efeitos básicos de hover
end

-- Funções de partículas removidas - hover apenas com efeitos visuais básicos

function HudPanel:setPosition(x, y)
    self.x = x
    self.y = y
end

function HudPanel:setSize(width, height)
    self.width = width
    self.height = height
end

function HudPanel:drawBackground()
    -- Salva estado atual do graphics
    local oldR, oldG, oldB, oldA = love.graphics.getColor()
    local oldLineWidth = love.graphics.getLineWidth()
    
    -- Calcula intensidade do hover
    local hoverIntensity = self.hoverTransition
    
    -- Sombra com efeito de hover (sombra maior e mais intensa)
    local shadowOffset = self.shadowOffset + (self.hoverShadowOffset - self.shadowOffset) * hoverIntensity
    local shadowAlpha = 0.3 + 0.2 * hoverIntensity
    love.graphics.setColor(0, 0, 0, shadowAlpha)
    love.graphics.rectangle("fill", 
        self.x + shadowOffset, 
        self.y + shadowOffset, 
        self.width, 
        self.height, 
        self.cornerRadius, 
        self.cornerRadius
    )
    
    -- Background principal com gradiente (mais brilhante no hover)
    self:drawGradientBackground()
    
    -- Borda com efeito de glow (mais intensa no hover)
    self:drawGlowBorder()
    
    -- Overlay de vidro
    self:drawGlassOverlay()
    
    -- Efeito de brilho no hover
    if hoverIntensity > 0 then
        self:drawHoverGlow()
    end
    
    -- Partículas removidas
    
    -- Restaura estado do graphics
    love.graphics.setColor(oldR, oldG, oldB, oldA)
    love.graphics.setLineWidth(oldLineWidth)
end

function HudPanel:drawGradientBackground()
    -- Interpola cores baseado no hover
    local hoverIntensity = self.hoverTransition
    local currentBgColor = {
        self.backgroundColor[1] + (self.hoverBackgroundColor[1] - self.backgroundColor[1]) * hoverIntensity,
        self.backgroundColor[2] + (self.hoverBackgroundColor[2] - self.backgroundColor[2]) * hoverIntensity,
        self.backgroundColor[3] + (self.hoverBackgroundColor[3] - self.backgroundColor[3]) * hoverIntensity,
        self.backgroundColor[4] + (self.hoverBackgroundColor[4] - self.backgroundColor[4]) * hoverIntensity
    }
    
    -- Gradiente vertical sutil
    local steps = 20
    local stepHeight = self.height / steps
    
    for i = 0, steps do
        local progress = i / steps
        local alpha = currentBgColor[4] * (1 - progress * 0.1)
        
        love.graphics.setColor(
            currentBgColor[1], 
            currentBgColor[2], 
            currentBgColor[3], 
            alpha
        )
        
        if i == 0 then
            love.graphics.rectangle("fill", 
                self.x, 
                self.y + i * stepHeight, 
                self.width, 
                stepHeight + 1, 
                self.cornerRadius, 
                self.cornerRadius
            )
        elseif i == steps then
            love.graphics.rectangle("fill", 
                self.x, 
                self.y + i * stepHeight, 
                self.width, 
                stepHeight, 
                self.cornerRadius, 
                self.cornerRadius
            )
        else
            love.graphics.rectangle("fill", 
                self.x, 
                self.y + i * stepHeight, 
                self.width, 
                stepHeight + 1
            )
        end
    end
end

function HudPanel:drawGlowBorder()
    -- Intensidade do hover
    local hoverIntensity = self.hoverTransition
    
    -- Interpola cores da borda baseado no hover
    local currentBorderColor = {
        self.borderColor[1] + (self.hoverBorderColor[1] - self.borderColor[1]) * hoverIntensity,
        self.borderColor[2] + (self.hoverBorderColor[2] - self.borderColor[2]) * hoverIntensity,
        self.borderColor[3] + (self.hoverBorderColor[3] - self.borderColor[3]) * hoverIntensity,
        self.borderColor[4] + (self.hoverBorderColor[4] - self.borderColor[4]) * hoverIntensity
    }
    
    local currentAccentColor = {
        self.accentColor[1] + (self.hoverAccentColor[1] - self.accentColor[1]) * hoverIntensity,
        self.accentColor[2] + (self.hoverAccentColor[2] - self.accentColor[2]) * hoverIntensity,
        self.accentColor[3] + (self.hoverAccentColor[3] - self.accentColor[3]) * hoverIntensity,
        self.accentColor[4] + (self.hoverAccentColor[4] - self.accentColor[4]) * hoverIntensity
    }
    
    -- Efeito de pulso na borda (mais intenso no hover)
    local pulseIntensity = math.sin(self.animationTime * self.pulseSpeed) * 0.3 + 0.7
    local currentGlowIntensity = self.glowIntensity + (self.hoverGlowIntensity - self.glowIntensity) * hoverIntensity
    
    local glowColor = {
        currentAccentColor[1],
        currentAccentColor[2],
        currentAccentColor[3],
        currentAccentColor[4] * pulseIntensity * currentGlowIntensity
    }
    
    -- Múltiplas bordas para efeito de glow (mais bordas no hover)
    local glowLayers = 3 + math.floor(2 * hoverIntensity)
    for i = 1, glowLayers do
        love.graphics.setColor(glowColor[1], glowColor[2], glowColor[3], glowColor[4] / i)
        love.graphics.setLineWidth(self.borderWidth + i - 1)
        love.graphics.rectangle("line", 
            self.x - i + 1, 
            self.y - i + 1, 
            self.width + 2 * (i - 1), 
            self.height + 2 * (i - 1), 
            self.cornerRadius + i - 1, 
            self.cornerRadius + i - 1
        )
    end
    
    -- Borda principal
    love.graphics.setColor(currentBorderColor)
    love.graphics.setLineWidth(self.borderWidth)
    love.graphics.rectangle("line", 
        self.x, 
        self.y, 
        self.width, 
        self.height, 
        self.cornerRadius, 
        self.cornerRadius
    )
    
    -- Reset da linha para não afetar outros elementos
    love.graphics.setLineWidth(1)
end

function HudPanel:drawGlassOverlay()
    -- Efeito de vidro no topo
    love.graphics.setColor(1, 1, 1, 0.1)
    love.graphics.rectangle("fill", 
        self.x, 
        self.y, 
        self.width, 
        self.height * 0.3, 
        self.cornerRadius, 
        self.cornerRadius
    )
    
    -- Highlight no topo
    love.graphics.setColor(1, 1, 1, 0.05)
    love.graphics.rectangle("fill", 
        self.x, 
        self.y, 
        self.width, 
        2, 
        self.cornerRadius, 
        self.cornerRadius
    )
end

function HudPanel:drawHoverGlow()
    -- Efeito de brilho suave que pulsa no hover
    local hoverIntensity = self.hoverTransition
    local pulseGlow = math.sin(self.animationTime * 4) * 0.2 + 0.8
    local glowAlpha = hoverIntensity * pulseGlow * 0.15
    
    -- Brilho interno
    love.graphics.setColor(self.hoverAccentColor[1], self.hoverAccentColor[2], self.hoverAccentColor[3], glowAlpha)
    love.graphics.rectangle("fill", 
        self.x, 
        self.y, 
        self.width, 
        self.height, 
        self.cornerRadius, 
        self.cornerRadius
    )
    
    -- Brilho nas bordas
    love.graphics.setColor(1, 1, 1, glowAlpha * 0.5)
    love.graphics.rectangle("fill", 
        self.x, 
        self.y, 
        self.width, 
        3, 
        self.cornerRadius, 
        self.cornerRadius
    )
    love.graphics.rectangle("fill", 
        self.x, 
        self.y + self.height - 3, 
        self.width, 
        3, 
        self.cornerRadius, 
        self.cornerRadius
    )
end

-- Função de desenho de partículas removida

function HudPanel:drawStatusBar(label, current, max, x, y, width, height, barColor, showNumbers)
    -- Salva estado atual do graphics
    local oldR, oldG, oldB, oldA = love.graphics.getColor()
    local oldFont = love.graphics.getFont()
    local oldLineWidth = love.graphics.getLineWidth()
    
    local barX = x or (self.x + self.padding)
    local barY = y or (self.y + self.padding)
    local barWidth = width or (self.width - 2 * self.padding)
    local barHeight = height or 20
    
    if showNumbers == nil then showNumbers = true end
    
    -- Label
    if label then
        local labelFont = FontManager.getResponsiveFont(0.016, 12, "height")
        love.graphics.setFont(labelFont)
        love.graphics.setColor(self.textColor)
        love.graphics.print(label, barX, barY - 18)
        
        -- Números no lado direito do label
        if showNumbers then
            local valueText = current .. "/" .. max
            local textWidth = labelFont:getWidth(valueText)
            love.graphics.print(valueText, barX + barWidth - textWidth, barY - 18)
        end
    end
    
    -- Background da barra
    love.graphics.setColor(0.1, 0.1, 0.1, 0.8)
    love.graphics.rectangle("fill", barX, barY, barWidth, barHeight, 6, 6)
    
    -- Preenchimento da barra
    local fillRatio = math.max(0, math.min(1, current / max))
    local fillWidth = barWidth * fillRatio
    
    if fillWidth > 0 then
        -- Gradiente da barra
        local steps = math.max(1, math.floor(fillWidth / 2))
        local stepWidth = fillWidth / steps
        
        for i = 0, steps - 1 do
            local progress = i / (steps - 1)
            local alpha = 1 - progress * 0.2
            
            love.graphics.setColor(
                barColor[1], 
                barColor[2], 
                barColor[3], 
                barColor[4] * alpha
            )
            
            if i == 0 then
                love.graphics.rectangle("fill", 
                    barX + i * stepWidth, 
                    barY, 
                    stepWidth + 1, 
                    barHeight, 
                    6, 6
                )
            elseif i == steps - 1 then
                love.graphics.rectangle("fill", 
                    barX + i * stepWidth, 
                    barY, 
                    stepWidth, 
                    barHeight, 
                    6, 6
                )
            else
                love.graphics.rectangle("fill", 
                    barX + i * stepWidth, 
                    barY, 
                    stepWidth + 1, 
                    barHeight
                )
            end
        end
        
        -- Highlight no topo da barra
        love.graphics.setColor(1, 1, 1, 0.3)
        love.graphics.rectangle("fill", barX, barY, fillWidth, 2, 6, 6)
        
        -- Brilho sutil
        if fillRatio > 0.1 then
            local glowAlpha = math.sin(self.animationTime * 3) * 0.1 + 0.1
            love.graphics.setColor(barColor[1], barColor[2], barColor[3], glowAlpha)
            love.graphics.rectangle("fill", barX, barY, fillWidth, barHeight, 6, 6)
        end
    end
    
    -- Borda da barra
    love.graphics.setColor(0.4, 0.4, 0.4, 0.8)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", barX, barY, barWidth, barHeight, 6, 6)
    
    -- Restaura estado do graphics
    love.graphics.setColor(oldR, oldG, oldB, oldA)
    love.graphics.setFont(oldFont)
    love.graphics.setLineWidth(oldLineWidth)
    
    return barY + barHeight + 8 -- Retorna a posição Y para a próxima barra
end

function HudPanel:drawText(text, x, y, font, color, shadow)
    -- Salva estado atual do graphics
    local oldR, oldG, oldB, oldA = love.graphics.getColor()
    local oldFont = love.graphics.getFont()
    
    local textX = x or (self.x + self.padding)
    local textY = y or (self.y + self.padding)
    local textFont = font or FontManager.getResponsiveFont(0.018, 14, "height")
    local textColor = color or self.textColor
    
    love.graphics.setFont(textFont)
    
    -- Sombra do texto
    if shadow ~= false then
        love.graphics.setColor(0, 0, 0, 0.6)
        love.graphics.print(text, textX + 1, textY + 1)
    end
    
    -- Texto principal
    love.graphics.setColor(textColor)
    love.graphics.print(text, textX, textY)
    
    -- Restaura estado do graphics
    love.graphics.setColor(oldR, oldG, oldB, oldA)
    love.graphics.setFont(oldFont)
end

function HudPanel:drawIcon(icon, x, y, scale, color)
    if not icon then return end
    
    -- Salva estado atual do graphics
    local oldR, oldG, oldB, oldA = love.graphics.getColor()
    
    local iconX = x or (self.x + self.padding)
    local iconY = y or (self.y + self.padding)
    local iconScale = scale or 0.03
    local iconColor = color or {1, 1, 1, 1}
    
    love.graphics.setColor(iconColor)
    love.graphics.draw(icon, iconX, iconY, 0, iconScale, iconScale)
    
    -- Restaura estado do graphics
    love.graphics.setColor(oldR, oldG, oldB, oldA)
end

return HudPanel
