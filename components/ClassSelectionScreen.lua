-- components/ClassSelectionScreen.lua
-- Tela para seleção de classe antes de iniciar uma run

local Button = require("components.Button")
local Config = require("src.core.Config")
local FontManager = require("src.ui.FontManager")
local Theme = require("src.ui.Theme")
local CardRegistry = require("src.systems.CardRegistry")

local ClassSelectionScreen = {}
ClassSelectionScreen.__index = ClassSelectionScreen

function ClassSelectionScreen:new()
    local instance = setmetatable({}, ClassSelectionScreen)
    instance.visible = false
    instance.buttons = {}
    instance.cardRegistry = CardRegistry:new()
    instance.selectedClass = nil
    
    -- Callbacks
    instance.onClassSelected = nil
    instance.onBackToMenu = nil
    
    -- Cria os botões das classes
    instance:createClassButtons()
    
    return instance
end

function ClassSelectionScreen:createClassButtons()
    local classes = self.cardRegistry:getAllClasses()
    print("ClassSelectionScreen: Creating buttons for classes:")
    for classId, classInfo in pairs(classes) do
        print("  - " .. classId .. ": " .. tostring(classInfo.name) .. " (color: " .. tostring(classInfo.color and "valid" or "nil") .. ")")
    end
    
    local centerX = love.graphics.getWidth() / 2
    local startY = love.graphics.getHeight() * 0.4
    local buttonWidth = Config.Utils.getResponsiveSize(Config.UI.BUTTON_WIDTH_RATIO, 300, "width")
    local buttonHeight = Config.Utils.getResponsiveSize(Config.UI.BUTTON_HEIGHT_RATIO, 80, "height")
    local spacing = Config.Utils.getResponsiveSize(Config.UI.BUTTON_SPACING_RATIO, 100, "height")
    
    local classIndex = 1
    for classId, classInfo in pairs(classes) do
        print("Creating button for class: " .. classId)
        local button = Button:new(
            centerX - buttonWidth / 2,
            startY + (classIndex - 1) * spacing,
            buttonWidth,
            buttonHeight,
            classInfo.name:upper(),
            function() self:selectClass(classId) end,
            classInfo.color or Theme.Colors.PRIMARY,
            22
        )
        
        self.buttons[classId] = button
        classIndex = classIndex + 1
    end
    
    -- Botão voltar ao menu
    local backButtonWidth = Config.Utils.getResponsiveSize(Config.UI.BUTTON_WIDTH_RATIO, 200, "width")
    local backButtonHeight = Config.Utils.getResponsiveSize(Config.UI.BUTTON_HEIGHT_RATIO, 50, "height")
    
    self.buttons.back = Button:new(
        centerX - backButtonWidth / 2,
        startY + (classIndex - 1) * spacing + 50,
        backButtonWidth,
        backButtonHeight,
        "VOLTAR AO MENU",
        function() self:goBackToMenu() end,
        Theme.Colors.WARNING,
        18
    )
end

function ClassSelectionScreen:updatePositions()
    local classes = self.cardRegistry:getAllClasses()
    local centerX = love.graphics.getWidth() / 2
    local startY = love.graphics.getHeight() * 0.4
    local buttonWidth = Config.Utils.getResponsiveSize(Config.UI.BUTTON_WIDTH_RATIO, 300, "width")
    local buttonHeight = Config.Utils.getResponsiveSize(Config.UI.BUTTON_HEIGHT_RATIO, 80, "height")
    local spacing = Config.Utils.getResponsiveSize(Config.UI.BUTTON_SPACING_RATIO, 100, "height")
    
    local classIndex = 1
    for classId, button in pairs(self.buttons) do
        if classId ~= "back" then
            button:setPosition(centerX - buttonWidth / 2, startY + (classIndex - 1) * spacing)
            button.width = buttonWidth
            button.height = buttonHeight
            classIndex = classIndex + 1
        end
    end
    
    -- Reposiciona botão voltar
    if self.buttons.back then
        local backButtonWidth = Config.Utils.getResponsiveSize(Config.UI.BUTTON_WIDTH_RATIO, 200, "width")
        local backButtonHeight = Config.Utils.getResponsiveSize(Config.UI.BUTTON_HEIGHT_RATIO, 50, "height")
        self.buttons.back:setPosition(
            centerX - backButtonWidth / 2,
            startY + (classIndex - 1) * spacing + 50
        )
        self.buttons.back.width = backButtonWidth
        self.buttons.back.height = backButtonHeight
    end
end

function ClassSelectionScreen:selectClass(classId)
    print("ClassSelectionScreen: selectClass called with classId: " .. tostring(classId))
    self.selectedClass = classId
    if self.onClassSelected then
        print("Calling onClassSelected callback...")
        self.onClassSelected(classId)
    else
        print("WARNING: onClassSelected callback is nil!")
    end
end

function ClassSelectionScreen:goBackToMenu()
    if self.onBackToMenu then
        self.onBackToMenu()
    end
end

function ClassSelectionScreen:show(onClassSelected, onBackToMenu)
    print("ClassSelectionScreen: show() called")
    print("  - onClassSelected: " .. tostring(onClassSelected))
    print("  - onBackToMenu: " .. tostring(onBackToMenu))
    
    self.visible = true
    self.onClassSelected = onClassSelected
    self.onBackToMenu = onBackToMenu
    
    local buttonCount = 0
    for classId, button in pairs(self.buttons) do
        buttonCount = buttonCount + 1
    end
    print("  - Buttons created: " .. tostring(buttonCount))
    for classId, button in pairs(self.buttons) do
        print("    * " .. classId .. ": " .. tostring(button.text))
    end
    
    self:updatePositions()
end

function ClassSelectionScreen:hide()
    self.visible = false
end

function ClassSelectionScreen:update(dt)
    if not self.visible then return end
    
    -- Debug: verifica se está sendo chamada
    if not self.updateCalled then
        print("ClassSelectionScreen: update() called for the first time")
        self.updateCalled = true
    end
    
    -- CRÍTICO: Atualiza o estado de hover dos botões
    for classId, button in pairs(self.buttons) do
        button:update(dt)
    end
    
    -- Atualiza posições se a tela mudou de tamanho
    if love.graphics.getWidth() ~= self.lastWidth or love.graphics.getHeight() ~= self.lastHeight then
        self:updatePositions()
        self.lastWidth = love.graphics.getWidth()
        self.lastHeight = love.graphics.getHeight()
    end
end

function ClassSelectionScreen:draw()
    if not self.visible then return end
    
    -- Debug: verifica se está sendo chamada
    if not self.drawCalled then
        print("ClassSelectionScreen: draw() called for the first time")
        self.drawCalled = true
    end
    
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    
    -- Fundo com gradiente
    local bgColors = {
        {0.1, 0.1, 0.2, 1},
        {0.05, 0.05, 0.1, 1}
    }
    Theme.Utils.drawVerticalGradient(0, 0, width, height, bgColors)
    
    -- Título
    self:drawTitle()
    
    -- Descrição
    self:drawDescription()
    
    -- Botões das classes
    for _, button in pairs(self.buttons) do
        button:draw()
    end
end

function ClassSelectionScreen:drawTitle()
    local titleFont = FontManager.getResponsiveFont(Config.UI.TITLE_FONT_RATIO, 48)
    love.graphics.setFont(titleFont)
    
    local title = "ESCOLHA SUA CLASSE"
    local titleX = love.graphics.getWidth() / 2 - titleFont:getWidth(title) / 2
    local titleY = love.graphics.getHeight() * 0.15
    
    -- Sombra
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.print(title, titleX + 3, titleY + 3)
    
    -- Título principal
    love.graphics.setColor(Theme.Colors.ACCENT)
    love.graphics.print(title, titleX, titleY)
end

function ClassSelectionScreen:drawDescription()
    local descFont = FontManager.getResponsiveFont(Config.UI.INSTRUCTION_FONT_RATIO, 16)
    love.graphics.setFont(descFont)
    
    local description = "Cada classe tem um estilo de jogo único e cartas específicas"
    local descX = love.graphics.getWidth() / 2 - descFont:getWidth(description) / 2
    local descY = love.graphics.getHeight() * 0.25
    
    love.graphics.setColor(Theme.Colors.TEXT_SECONDARY)
    love.graphics.print(description, descX, descY)
end

function ClassSelectionScreen:mousepressed(x, y, button)
    if not self.visible then return end
    
    print("ClassSelectionScreen: mousepressed at (" .. x .. ", " .. y .. ") with button " .. button)
    
    for classId, btn in pairs(self.buttons) do
        print("  - Checking button: " .. classId .. " at (" .. btn.x .. ", " .. btn.y .. ") size (" .. btn.width .. "x" .. btn.height .. ")")
        btn:mousepressed(x, y, button)
    end
end

function ClassSelectionScreen:mousereleased(x, y, button)
    if not self.visible then return end
    
    print("ClassSelectionScreen: mousereleased at (" .. x .. ", " .. y .. ") with button " .. button)
    
    for classId, btn in pairs(self.buttons) do
        print("  - Checking button: " .. classId .. " at (" .. btn.x .. ", " .. btn.y .. ") size (" .. btn.width .. "x" .. btn.height .. ")")
        btn:mousereleased(x, y, button)
    end
end

return ClassSelectionScreen
