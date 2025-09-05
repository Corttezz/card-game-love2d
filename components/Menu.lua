local Button = require("components.Button")
local Config = require("src.core.Config")
local FontManager = require("src.ui.FontManager")
local Theme = require("src.ui.Theme")

local Menu = {}
Menu.__index = Menu

function Menu:new()
    local instance = setmetatable({}, Menu)
    instance.buttons = {}
    instance.visible = true
    instance.title = "jogo"
    instance.subtitle = "jogo"
    
    -- Cria os botões do menu
    instance:createButtons()
    
    return instance
end

function Menu:createButtons()
    -- Usa coordenadas relativas à resolução da tela
    local centerX = love.graphics.getWidth() / 2
    local startY = love.graphics.getHeight() * 0.5 -- 50% da altura
    local buttonWidth = Config.Utils.getResponsiveSize(Config.UI.BUTTON_WIDTH_RATIO, 250, "width")
    local buttonHeight = Config.Utils.getResponsiveSize(Config.UI.BUTTON_HEIGHT_RATIO, 60, "height")
    local spacing = Config.Utils.getResponsiveSize(Config.UI.BUTTON_SPACING_RATIO, 80, "height")
    
    -- Botão Jogar
    self.buttons.play = Button:new(
        centerX - buttonWidth / 2,
        startY,
        buttonWidth,
        buttonHeight,
        "JOGAR",
        function() self:onPlayClick() end,
        Theme.Colors.SUCCESS,
        24
    )
    
    -- Botão Configurações
    self.buttons.settings = Button:new(
        centerX - buttonWidth / 2,
        startY + spacing,
        buttonWidth,
        buttonHeight,
        "CONFIGURAÇÕES",
        function() self:onSettingsClick() end,
        Theme.Colors.WARNING,
        20
    )
    
    -- Botão Sobre
    self.buttons.about = Button:new(
        centerX - buttonWidth / 2,
        startY + spacing * 2,
        buttonWidth,
        buttonHeight,
        "SOBRE",
        function() self:onAboutClick() end,
        Theme.Colors.INFO,
        20
    )
    
    -- Botão Sair
    self.buttons.quit = Button:new(
        centerX - buttonWidth / 2,
        startY + spacing * 3,
        buttonWidth,
        buttonHeight,
        "SAIR",
        function() self:onQuitClick() end,
        Theme.Colors.ERROR,
        20
    )
end

function Menu:updatePositions()
    -- Reposiciona os botões dinamicamente baseado na resolução atual
    local centerX = love.graphics.getWidth() / 2
    local startY = love.graphics.getHeight() * 0.5
    local buttonWidth = Config.Utils.getResponsiveSize(Config.UI.BUTTON_WIDTH_RATIO, 250, "width")
    local buttonHeight = Config.Utils.getResponsiveSize(Config.UI.BUTTON_HEIGHT_RATIO, 60, "height")
    local spacing = Config.Utils.getResponsiveSize(Config.UI.BUTTON_SPACING_RATIO, 80, "height")
    
    -- Reposiciona cada botão
    if self.buttons.play then
        self.buttons.play:setPosition(centerX - buttonWidth / 2, startY)
        self.buttons.play.width = buttonWidth
        self.buttons.play.height = buttonHeight
    end
    
    if self.buttons.settings then
        self.buttons.settings:setPosition(centerX - buttonWidth / 2, startY + spacing)
        self.buttons.settings.width = buttonWidth
        self.buttons.settings.height = buttonHeight
    end
    
    if self.buttons.about then
        self.buttons.about:setPosition(centerX - buttonWidth / 2, startY + spacing * 2)
        self.buttons.about.width = buttonWidth
        self.buttons.about.height = buttonHeight
    end
    
    if self.buttons.quit then
        self.buttons.quit:setPosition(centerX - buttonWidth / 2, startY + spacing * 3)
        self.buttons.quit.width = buttonWidth
        self.buttons.quit.height = buttonHeight
    end
end

function Menu:update(dt)
    if not self.visible then return end
    
    -- Atualiza posições dos botões a cada frame
    self:updatePositions()
    
    -- Atualiza todos os botões
    for _, button in pairs(self.buttons) do
        button:update(dt)
    end
end

function Menu:draw()
    if not self.visible then return end
    
    -- Background com gradiente profissional
    self:drawBackground()
    
    -- Título
    self:drawTitle()
    
    -- Subtítulo
    love.graphics.setColor(1, 1, 1, 0.8)
    local subtitleFont = FontManager.getResponsiveFont(Config.UI.SUBTITLE_FONT_RATIO, 18)
    love.graphics.setFont(subtitleFont)
    local subtitleWidth = subtitleFont:getWidth(self.subtitle)
    love.graphics.print(self.subtitle, 
        love.graphics.getWidth() / 2 - subtitleWidth / 2, 
        love.graphics.getHeight() * 0.42)
    
    -- Desenha todos os botões
    for _, button in pairs(self.buttons) do
        button:draw()
    end
    
    -- Instruções
    self:drawInstructions()
    
    -- Reseta cor
    love.graphics.setColor(1, 1, 1, 1)
end

function Menu:drawBackground()
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    
    -- Gradiente de fundo principal
    local bgColors = Theme.Gradients.BACKGROUND_MAIN(0, 0, width, height)
    Theme.Utils.drawVerticalGradient(0, 0, width, height, bgColors)
    
    -- Padrão de fundo sutil com partículas
    love.graphics.setColor(0.1, 0.1, 0.15, 0.1)
    for i = 0, width, 80 do
        for j = 0, height, 80 do
            local alpha = 0.1 + math.sin(love.timer.getTime() + i * 0.01 + j * 0.01) * 0.05
            love.graphics.setColor(0.2, 0.3, 0.4, alpha)
            love.graphics.circle("fill", i, j, 2)
        end
    end
    
    -- Linhas de energia sutis
    love.graphics.setColor(0.1, 0.2, 0.3, 0.1)
    love.graphics.setLineWidth(1)
    for i = 0, width, 120 do
        love.graphics.line(i, 0, i + 60, height)
    end
end

function Menu:drawTitle()
    local titleFont = FontManager.getResponsiveFont(Config.UI.TITLE_FONT_RATIO, 48)
    love.graphics.setFont(titleFont)
    
    -- Efeito de brilho no título
    local glowIntensity = 0.5 + math.sin(love.timer.getTime() * 2) * 0.2
    
    -- Sombra do título
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.print(self.title, 
        love.graphics.getWidth() / 2 - titleFont:getWidth(self.title) / 2 + 3, 
        love.graphics.getHeight() * 0.25 + 3)
    
    -- Título principal com brilho
    local titleColor = Theme.Utils.interpolateColor(
        Theme.Colors.ACCENT, 
        {1, 1, 1, 1}, 
        glowIntensity * 0.3
    )
    
    love.graphics.setColor(titleColor)
    love.graphics.print(self.title, 
        love.graphics.getWidth() / 2 - titleFont:getWidth(self.title) / 2, 
        love.graphics.getHeight() * 0.25)
    
    -- Borda brilhante
    love.graphics.setColor(Theme.Colors.ACCENT)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", 
        love.graphics.getWidth() / 2 - titleFont:getWidth(self.title) / 2 - 15, 
        love.graphics.getHeight() * 0.23, 
        titleFont:getWidth(self.title) + 30, 
        titleFont:getHeight() + 30,
        8, 8
    )
end

function Menu:drawInstructions()
    love.graphics.setColor(Theme.Colors.TEXT_SECONDARY)
    local instructionFont = FontManager.getResponsiveFont(Config.UI.INSTRUCTION_FONT_RATIO, 14)
    love.graphics.setFont(instructionFont)
    
    local instructions = {
        "Use o MOUSE para selecionar cartas",
        "ESPACO para comprar cartas",
        "R para reiniciar o jogo",
        "Jokers são cartas passivas que ficam ativas"
    }
    
    local y = love.graphics.getHeight() * 0.8
    for i, instruction in ipairs(instructions) do
        local x = love.graphics.getWidth() / 2 - instructionFont:getWidth(instruction) / 2
        love.graphics.print(instruction, x, y + (i - 1) * 20)
    end
end

function Menu:onPlayClick()
    self.visible = false
    if self.onPlayCallback then
        self.onPlayCallback()
    end
end

function Menu:onSettingsClick()
    -- TODO: Implementar menu de configurações
    print("Configurações - Em desenvolvimento")
end

function Menu:onAboutClick()
    -- TODO: Implementar tela sobre
    print("Sobre - Em desenvolvimento")
end

function Menu:onQuitClick()
    love.event.quit()
end

function Menu:setPlayCallback(callback)
    self.onPlayCallback = callback
end

function Menu:show()
    self.visible = true
end

function Menu:hide()
    self.visible = false
end

function Menu:mousepressed(x, y, button)
    if not self.visible then return end
    
    for name, btn in pairs(self.buttons) do
        btn:mousepressed(x, y, button)
    end
end

function Menu:mousereleased(x, y, button)
    if not self.visible then return end
    
    for name, btn in pairs(self.buttons) do
        btn:mousereleased(x, y, button)
    end
end

return Menu
