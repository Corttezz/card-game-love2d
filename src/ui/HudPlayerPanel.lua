-- src/ui/HudPlayerPanel.lua
-- Painel de HUD para informações do jogador (vida, armadura, mana)

local HudPanel = require("src.ui.HudPanel")
local FontManager = require("src.ui.FontManager")
local Config = require("src.core.Config")

local HudPlayerPanel = {}
HudPlayerPanel.__index = HudPlayerPanel
setmetatable(HudPlayerPanel, {__index = HudPanel})

function HudPlayerPanel:new(x, y, width, height)
    local instance = HudPanel:new(x, y, width, height, {
        backgroundColor = {0.05, 0.15, 0.05, 0.95}, -- Verde escuro
        borderColor = {0.2, 0.6, 0.2, 0.8}, -- Verde médio
        accentColor = {0.3, 0.8, 0.3, 1.0}, -- Verde claro
        textColor = {0.9, 1.0, 0.9, 1.0}, -- Verde muito claro
        -- Cores de hover elegantes
        hoverBackgroundColor = {0.08, 0.22, 0.08, 0.98}, -- Verde mais claro no hover
        hoverBorderColor = {0.4, 0.8, 0.4, 1.0}, -- Verde brilhante no hover
        hoverAccentColor = {0.5, 1.0, 0.5, 1.0} -- Verde muito brilhante no hover
    })
    setmetatable(instance, HudPlayerPanel)
    
    -- Configurações específicas do jogador
    instance.title = ""
    instance.iconSpacing = 24
    instance.barSpacing = 28
    
    -- Cache de ícones
    instance.icons = {}
    instance:loadIcons()
    
    return instance
end

function HudPlayerPanel:loadIcons()
    -- Carrega ícones com tratamento de erro
    local iconPaths = {
        armor = "assets/icons/armor.png",
        mana = "assets/icons/mana.png"
    }
    
    for iconName, path in pairs(iconPaths) do
        local success, icon = pcall(love.graphics.newImage, path)
        if success then
            self.icons[iconName] = icon
            print("HudPlayerPanel: Ícone carregado:", iconName)
        else
            print("HudPlayerPanel: Erro ao carregar ícone:", iconName, path)
        end
    end
    
    -- Cria ícone de health programaticamente se não existir
    if not self.icons.health then
        self.icons.health = self:createHealthIcon()
    end
end

function HudPlayerPanel:createHealthIcon()
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

function HudPlayerPanel:draw(player)
    if not player then return end
    
    -- Desenha o background do painel
    self:drawBackground()
    
    -- Título do painel
    self:drawTitle()
    
    -- Informações do jogador
    self:drawPlayerStats(player)
    
    -- Efeitos de partículas sutis (incluindo hover)
    self:drawParticleEffects(player)
end

function HudPlayerPanel:drawTitle()
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
end

function HudPlayerPanel:drawPlayerStats(player)
    local startY = self.y + 25
    local currentY = startY
    
    -- Barra de Vida
    currentY = self:drawStatusBar(
        "", 
        player.health or 0, 
        player.maxHealth or 100,
        nil, currentY, nil, 18,
        {0.8, 0.3, 0.3, 1.0}, -- Vermelho para vida
        true
    )
    
    -- Ícone de vida
    if self.icons.health then
        self:drawIcon(self.icons.health, 
            self.x + self.width - 30, 
            currentY - 28, 
            0.025, 
            {0.8, 0.3, 0.3, 0.8}
        )
    end
    
    currentY = currentY + 4
    
    -- Barra de Armadura
    currentY = self:drawStatusBar(
        "", 
        player.armor or 0, 
        player.maxArmor or 50,
        nil, currentY + 10, nil, 18,
        {0.6, 0.6, 0.8, 1.0}, -- Azul acinzentado para armadura
        true
    )
    
    -- Ícone de armadura
    if self.icons.armor then
        self:drawIcon(self.icons.armor, 
            self.x + self.width - 30, 
            currentY - 30, 
            0.025, 
            {0.6, 0.6, 0.8, 1}
        )
    end
    
    currentY = currentY + 4
    
    -- Barra de Mana
    currentY = self:drawStatusBar(
        "", 
        player.mana or 0, 
        player.maxMana or 3,
        nil, currentY + 10, nil, 18,
        {0.3, 0.5, 0.9, 1.0}, -- Azul para mana
        true
    )
    
    -- Ícone de mana
    if self.icons.mana then
        self:drawIcon(self.icons.mana, 
            self.x + self.width - 30, 
            currentY - 30, 
            0.025, 
            {0.3, 0.5, 0.9, 1}
        )
    end
end

function HudPlayerPanel:updatePosition()
    -- Atualiza posição para canto inferior esquerdo
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    self.width = Config.Utils.getResponsiveSize(0.28, 280, "width")
    self.height = Config.Utils.getResponsiveSize(0.18, 140, "height")
    self.x = Config.Utils.getResponsiveSize(0.02, 20, "width")
    self.y = screenHeight - self.height - Config.Utils.getResponsiveSize(0.02, 20, "height")
end

function HudPlayerPanel:getHealthPercentage(player)
    if not player or not player.maxHealth or player.maxHealth == 0 then
        return 0
    end
    return (player.health or 0) / player.maxHealth
end

function HudPlayerPanel:getArmorPercentage(player)
    if not player or not player.maxArmor or player.maxArmor == 0 then
        return 0
    end
    return (player.armor or 0) / player.maxArmor
end

function HudPlayerPanel:getManaPercentage(player)
    if not player or not player.maxMana or player.maxMana == 0 then
        return 0
    end
    return (player.mana or 0) / player.maxMana
end

function HudPlayerPanel:drawParticleEffects(player)
    -- Função vazia - sem partículas, apenas efeitos básicos de hover
end

return HudPlayerPanel
