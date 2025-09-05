-- src/ui/HudEnemyPanel.lua
-- Painel de HUD para informações do inimigo (vida, dano)

local HudPanel = require("src.ui.HudPanel")
local FontManager = require("src.ui.FontManager")
local Config = require("src.core.Config")

local HudEnemyPanel = {}
HudEnemyPanel.__index = HudEnemyPanel
setmetatable(HudEnemyPanel, {__index = HudPanel})

function HudEnemyPanel:new(x, y, width, height)
    local instance = HudPanel:new(x, y, width, height, {
        backgroundColor = {0.15, 0.05, 0.05, 0.95}, -- Vermelho escuro
        borderColor = {0.6, 0.2, 0.2, 0.8}, -- Vermelho médio
        accentColor = {0.8, 0.3, 0.3, 1.0}, -- Vermelho claro
        textColor = {1.0, 0.9, 0.9, 1.0}, -- Vermelho muito claro
        -- Cores de hover elegantes
        hoverBackgroundColor = {0.22, 0.08, 0.08, 0.98}, -- Vermelho mais claro no hover
        hoverBorderColor = {0.8, 0.4, 0.4, 1.0}, -- Vermelho brilhante no hover
        hoverAccentColor = {1.0, 0.5, 0.5, 1.0} -- Vermelho muito brilhante no hover
    })
    setmetatable(instance, HudEnemyPanel)
    
    -- Configurações específicas do inimigo
    instance.title = ""
    instance.iconSpacing = 24
    instance.infoSpacing = 24
    
    -- Cache de ícones
    instance.icons = {}
    instance:loadIcons()
    
    return instance
end

function HudEnemyPanel:loadIcons()
    -- Carrega ícones com tratamento de erro
    local iconPaths = {
        attack = "assets/icons/attack.png"
    }
    
    for iconName, path in pairs(iconPaths) do
        local success, icon = pcall(love.graphics.newImage, path)
        if success then
            self.icons[iconName] = icon
            print("HudEnemyPanel: Ícone carregado:", iconName)
        else
            print("HudEnemyPanel: Erro ao carregar ícone:", iconName, path)
        end
    end
    
    -- Cria ícones programaticamente se não existirem
    if not self.icons.health then
        self.icons.health = self:createHealthIcon()
    end
    
    if not self.icons.skull then
        self.icons.skull = self:createSkullIcon()
    end
end

function HudEnemyPanel:createHealthIcon()
    -- Salva estado atual do graphics
    local oldCanvas = love.graphics.getCanvas()
    local oldR, oldG, oldB, oldA = love.graphics.getColor()
    
    -- Cria um ícone de coração simples usando canvas
    local size = 32
    local canvas = love.graphics.newCanvas(size, size)
    
    love.graphics.setCanvas(canvas)
    love.graphics.clear()
    
    -- Desenha um coração simples
    love.graphics.setColor(0.8, 0.3, 0.3, 1)
    
    -- Parte superior esquerda do coração
    love.graphics.circle("fill", size * 0.3, size * 0.35, size * 0.15)
    -- Parte superior direita do coração
    love.graphics.circle("fill", size * 0.7, size * 0.35, size * 0.15)
    -- Parte inferior (triângulo)
    love.graphics.polygon("fill", 
        size * 0.5, size * 0.8,   -- ponta inferior
        size * 0.15, size * 0.45, -- esquerda
        size * 0.85, size * 0.45  -- direita
    )
    
    -- Restaura estado do graphics
    love.graphics.setCanvas(oldCanvas)
    love.graphics.setColor(oldR, oldG, oldB, oldA)
    
    return canvas
end

function HudEnemyPanel:createSkullIcon()
    -- Salva estado atual do graphics
    local oldCanvas = love.graphics.getCanvas()
    local oldR, oldG, oldB, oldA = love.graphics.getColor()
    
    -- Cria um ícone de caveira simples usando canvas
    local size = 32
    local canvas = love.graphics.newCanvas(size, size)
    
    love.graphics.setCanvas(canvas)
    love.graphics.clear()
    
    -- Desenha uma caveira simples
    love.graphics.setColor(0.9, 0.9, 0.9, 1)
    
    -- Cabeça
    love.graphics.circle("fill", size * 0.5, size * 0.4, size * 0.25)
    
    -- Olhos
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.circle("fill", size * 0.4, size * 0.35, size * 0.06)
    love.graphics.circle("fill", size * 0.6, size * 0.35, size * 0.06)
    
    -- Nariz (triângulo)
    love.graphics.polygon("fill",
        size * 0.5, size * 0.45,  -- ponta superior
        size * 0.45, size * 0.55, -- esquerda
        size * 0.55, size * 0.55  -- direita
    )
    
    -- Boca
    love.graphics.rectangle("fill", size * 0.42, size * 0.6, size * 0.04, size * 0.08)
    love.graphics.rectangle("fill", size * 0.48, size * 0.6, size * 0.04, size * 0.08)
    love.graphics.rectangle("fill", size * 0.54, size * 0.6, size * 0.04, size * 0.08)
    
    -- Restaura estado do graphics
    love.graphics.setCanvas(oldCanvas)
    love.graphics.setColor(oldR, oldG, oldB, oldA)
    
    return canvas
end

function HudEnemyPanel:draw(enemy, currentPhase)
    if not enemy then return end
    
    -- Desenha o background do painel
    self:drawBackground()
    
    -- Título do painel
    self:drawTitle()
    
    -- Informações do inimigo
    self:drawEnemyStats(enemy, currentPhase or 1)
    
    -- Efeitos de partículas sutis (incluindo hover)
    self:drawParticleEffects(enemy)
end

function HudEnemyPanel:drawTitle()
    local titleFont = FontManager.getResponsiveFont(0.022, 18, "height")
    local titleY = self.y + 8
    local titleX = self.x + self.padding
    
    -- Sombra do título
    love.graphics.setFont(titleFont)
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.print(self.title, titleX + 1, titleY + 1)
    
    -- Título principal com glow
    local glowIntensity = math.sin(self.animationTime * 2) * 0.2 + 0.8
    love.graphics.setColor(
        self.accentColor[1] * glowIntensity,
        self.accentColor[2] * glowIntensity,
        self.accentColor[3] * glowIntensity,
        1
    )
    love.graphics.print(self.title, titleX, titleY)
    
    -- Ícone de inimigo (skull) no título se disponível
    if self.icons.skull then
        self:drawIcon(self.icons.skull, 
            titleX + titleFont:getWidth(self.title) + 8, 
            titleY - 2, 
            0.02, 
            {self.accentColor[1], self.accentColor[2], self.accentColor[3], 0.8}
        )
    end
end

function HudEnemyPanel:drawEnemyStats(enemy, currentPhase)
    local startY = self.y + 35
    local currentY = startY
    
    -- Barra de Vida
    currentY = self:drawStatusBar(
        "", 
        enemy.health or 0, 
        enemy.maxHealth or 100,
        nil, currentY, nil, 20,
        {0.8, 0.3, 0.3, 1.0}, -- Vermelho para vida
        true
    )
    
    -- Ícone de vida
    if self.icons.health then
        self:drawIcon(self.icons.health, 
            self.x + self.width - 30, 
            currentY - 30, 
            0.025, 
            {0.8, 0.3, 0.3, 0.8}
        )
    end
    
    currentY = currentY + 8
    
    -- Informações adicionais do inimigo
    self:drawEnemyInfo(enemy, currentPhase, currentY)
end

function HudEnemyPanel:drawEnemyInfo(enemy, currentPhase, startY)
    local infoFont = FontManager.getResponsiveFont(0.018, 14, "height")
    local currentY = startY
    
    -- Container para informações
    local infoWidth = self.width - 2 * self.padding
    local infoHeight = 40
    local infoX = self.x + self.padding
    
    -- Background sutil para as informações
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.rectangle("fill", infoX, currentY, infoWidth, infoHeight, 6, 6)
    
    -- Borda sutil
    love.graphics.setColor(self.accentColor[1], self.accentColor[2], self.accentColor[3], 0.4)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", infoX, currentY, infoWidth, infoHeight, 6, 6)
    
    -- Dano do inimigo
    local damageText = "DANO: " .. (enemy.damage or 0)
    self:drawText(damageText, infoX + 8, currentY + 6, infoFont, self.textColor)
    
    -- Ícone de ataque
    if self.icons.attack then
        self:drawIcon(self.icons.attack, 
            infoX + infoFont:getWidth(damageText) + 12, 
            currentY + 4, 
            0.02, 
            {0.8, 0.4, 0.4, 0.8}
        )
    end
    
    -- Fase atual
    local phaseText = "FASE: " .. currentPhase
    local phaseWidth = infoFont:getWidth(phaseText)
    self:drawText(phaseText, infoX + infoWidth - phaseWidth - 8, currentY + 6, infoFont, self.textColor)
    
    -- Indicador de nível de ameaça baseado na fase
    self:drawThreatLevel(currentPhase, infoX + 8, currentY + 22)
end

function HudEnemyPanel:drawThreatLevel(phase, x, y)
    local threatLevel = math.min(5, math.max(1, math.floor(phase / 2) + 1))
    local threatColors = {
        {0.4, 0.8, 0.4, 1.0}, -- Verde (fácil)
        {0.8, 0.8, 0.4, 1.0}, -- Amarelo
        {0.8, 0.6, 0.4, 1.0}, -- Laranja
        {0.8, 0.4, 0.4, 1.0}, -- Vermelho
        {0.8, 0.2, 0.8, 1.0}  -- Roxo (muito difícil)
    }
    
    local threatColor = threatColors[threatLevel] or threatColors[5]
    local dotSize = 4
    local dotSpacing = 8
    
    -- Label de ameaça
    local threatFont = FontManager.getResponsiveFont(0.014, 11, "height")
    love.graphics.setFont(threatFont)
    love.graphics.setColor(self.textColor[1], self.textColor[2], self.textColor[3], 0.8)
    love.graphics.print("AMEAÇA:", x, y)
    
    -- Pontos indicadores de nível
    local startX = x + threatFont:getWidth("AMEAÇA: ") + 4
    for i = 1, 5 do
        if i <= threatLevel then
            love.graphics.setColor(threatColor)
        else
            love.graphics.setColor(0.3, 0.3, 0.3, 0.6)
        end
        love.graphics.circle("fill", startX + (i - 1) * dotSpacing, y + 6, dotSize)
        
        -- Glow para pontos ativos
        if i <= threatLevel then
            love.graphics.setColor(threatColor[1], threatColor[2], threatColor[3], 0.3)
            love.graphics.circle("fill", startX + (i - 1) * dotSpacing, y + 6, dotSize + 1)
        end
    end
end

function HudEnemyPanel:updatePosition()
    -- Atualiza posição para canto inferior direito
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    self.width = Config.Utils.getResponsiveSize(0.28, 280, "width")
    self.height = Config.Utils.getResponsiveSize(0.18, 140, "height")
    self.x = screenWidth - self.width - Config.Utils.getResponsiveSize(0.02, 20, "width")
    self.y = screenHeight - self.height - Config.Utils.getResponsiveSize(0.02, 20, "height")
end

function HudEnemyPanel:drawParticleEffects(enemy)
    -- Função vazia - sem partículas, apenas efeitos básicos de hover
end

function HudEnemyPanel:getHealthPercentage(enemy)
    if not enemy or not enemy.maxHealth or enemy.maxHealth == 0 then
        return 0
    end
    return (enemy.health or 0) / enemy.maxHealth
end

return HudEnemyPanel
