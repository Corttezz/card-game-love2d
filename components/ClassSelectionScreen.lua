-- components/ClassSelectionScreen.lua
-- Tela para seleção de classe antes de iniciar uma run

local Button = require("components.Button")
local Config = require("src.core.Config")
local FontManager = require("src.ui.FontManager")
local Theme = require("src.ui.Theme")
local Palette = require("src.ui.Palette")
local PixelCanvas = require("src.ui.PixelCanvas")
local SceneBackground = require("src.ui.SceneBackground")
local CardRegistry = require("src.systems.CardRegistry")
local Debug = require("src.core.Debug")
local I18n = require("src.i18n.I18n")

local CLASS_ICONS = {
    warrior = "sword_short",
    mage    = "orb",
    rogue   = "dagger",
}

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
    local centerX = love.graphics.getWidth() / 2
    local startY = love.graphics.getHeight() * 0.4
    local buttonWidth = Config.Utils.getResponsiveSize(Config.UI.BUTTON_WIDTH_RATIO, 300, "width")
    local buttonHeight = Config.Utils.getResponsiveSize(Config.UI.BUTTON_HEIGHT_RATIO, 80, "height")
    local spacing = Config.Utils.getResponsiveSize(Config.UI.BUTTON_SPACING_RATIO, 100, "height")
    
    local classIndex = 1
    for classId, classInfo in pairs(classes) do
        local button = Button:new(
            centerX - buttonWidth / 2,
            startY + (classIndex - 1) * spacing,
            buttonWidth,
            buttonHeight,
            classInfo.name:upper(),
            function() self:selectClass(classId) end,
            classInfo.color or Theme.Colors.PRIMARY,
            16
        )
        button:setIcon(CLASS_ICONS[classId] or "scroll")

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
        I18n.t("class_select.back"),
        function() self:goBackToMenu() end,
        Theme.Colors.WARNING,
        12
    )
    self.buttons.back:setIcon("arrow_left")

    -- Recria botões ao trocar idioma (textos mudam)
    if not self._localeListenerWired then
        self._localeListenerWired = true
        I18n.onLocaleChanged(function()
            self.buttons = {}
            self:createClassButtons()
        end)
    end
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
    self.selectedClass = classId
    if self.onClassSelected then
        self.onClassSelected(classId)
    else
        Debug.warn("onClassSelected callback nil em selectClass(" .. tostring(classId) .. ")")
    end
end

function ClassSelectionScreen:goBackToMenu()
    if self.onBackToMenu then
        self.onBackToMenu()
    end
end

function ClassSelectionScreen:show(onClassSelected, onBackToMenu)
    self.visible = true
    self.onClassSelected = onClassSelected
    self.onBackToMenu = onBackToMenu
    self:updatePositions()
end

function ClassSelectionScreen:hide()
    self.visible = false
end

function ClassSelectionScreen:update(dt)
    if not self.visible then return end

    for _, button in pairs(self.buttons) do
        button:update(dt)
    end
end

function ClassSelectionScreen:draw()
    if not self.visible then return end

    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()

    -- Fundo: cena PNG (classSelection → fallback menu → fallback gradiente)
    if not SceneBackground.draw("classSelection", width, height, 0.45) then
        if not SceneBackground.draw("menu", width, height, 0.55) then
            local bgColors = {
                {0.1, 0.1, 0.2, 1},
                {0.05, 0.05, 0.1, 1}
            }
            Theme.Utils.drawVerticalGradient(0, 0, width, height, bgColors)
        end
    end

    self:drawTitle()
    self:drawDescription()

    for _, button in pairs(self.buttons) do
        button:draw()
    end
end

function ClassSelectionScreen:drawTitle()
    local titleFont = FontManager.getResponsiveFont(Config.UI.TITLE_FONT_RATIO, 24)
    love.graphics.setFont(titleFont)

    local title = I18n.t("class_select.title")
    local width = love.graphics.getWidth()
    local titleX = math.floor(width / 2 - titleFont:getWidth(title) / 2)
    local titleY = math.floor(love.graphics.getHeight() * 0.10)

    -- Banner pixel: ink fill + dual outline gold
    local padX, padY = 20, 10
    local bw = titleFont:getWidth(title) + padX * 2
    local bh = titleFont:getHeight() + padY * 2
    local bx, by = titleX - padX, titleY - padY
    PixelCanvas.rect(bx, by, bw, bh, Palette.PANEL_FILL)
    PixelCanvas.rectOutline(bx, by, bw, bh, Palette.PANEL_OUTLINE)
    PixelCanvas.rectOutline(bx + 3, by + 3, bw - 6, bh - 6, Palette.PANEL_OUTLINE_INNER)

    -- Título
    Palette.set(Palette.INK)
    love.graphics.print(title, titleX + 1, titleY + 1)
    Palette.set(Palette.AGED_GOLD_LIGHT)
    love.graphics.print(title, titleX, titleY)
end

function ClassSelectionScreen:drawDescription()
    local descFont = FontManager.getResponsiveFont(Config.UI.INSTRUCTION_FONT_RATIO, 10)
    love.graphics.setFont(descFont)

    local description = I18n.t("class_select.description")
    local descX = math.floor(love.graphics.getWidth() / 2 - descFont:getWidth(description) / 2)
    local descY = math.floor(love.graphics.getHeight() * 0.22)

    Palette.set(Palette.INK)
    love.graphics.print(description, descX + 1, descY + 1)
    Palette.set(Palette.PARCHMENT_LIGHT)
    love.graphics.print(description, descX, descY)
end

function ClassSelectionScreen:mousepressed(x, y, button)
    if not self.visible then return end
    for _, btn in pairs(self.buttons) do
        btn:mousepressed(x, y, button)
    end
end

function ClassSelectionScreen:mousereleased(x, y, button)
    if not self.visible then return end
    for _, btn in pairs(self.buttons) do
        btn:mousereleased(x, y, button)
    end
end

return ClassSelectionScreen
