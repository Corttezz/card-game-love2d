local Button = require("components.Button")
local Config = require("src.core.Config")
local FontManager = require("src.ui.FontManager")
local Theme = require("src.ui.Theme")
local PixelBackground = require("src.ui.PixelBackground")
local PixelCanvas = require("src.ui.PixelCanvas")
local Palette = require("src.ui.Palette")
local I18n = require("src.i18n.I18n")

local Menu = {}
Menu.__index = Menu

function Menu:new()
    local instance = setmetatable({}, Menu)
    instance.buttons = {}
    instance.visible = true

    -- Cria os botões do menu
    instance:createButtons()

    -- Re-cria botões quando trocar idioma (textos mudam)
    I18n.onLocaleChanged(function()
        if instance.visible ~= nil then instance:createButtons() end
    end)

    return instance
end

function Menu:_title()    return I18n.t("menu.title") end
function Menu:_subtitle() return I18n.t("menu.subtitle") end

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
        I18n.t("menu.play"),
        function() self:onPlayClick() end,
        Theme.Colors.SUCCESS,
        24
    )

    -- Botão Coleção
    self.buttons.collection = Button:new(
        centerX - buttonWidth / 2,
        startY + spacing,
        buttonWidth,
        buttonHeight,
        I18n.t("menu.collection"),
        function() self:onCollectionClick() end,
        Theme.Colors.ACCENT or Theme.Colors.INFO,
        20
    )

    -- Botão Configurações
    self.buttons.settings = Button:new(
        centerX - buttonWidth / 2,
        startY + spacing * 2,
        buttonWidth,
        buttonHeight,
        I18n.t("menu.settings"),
        function() self:onSettingsClick() end,
        Theme.Colors.WARNING,
        20
    )

    -- Botão Sair
    self.buttons.quit = Button:new(
        centerX - buttonWidth / 2,
        startY + spacing * 3,
        buttonWidth,
        buttonHeight,
        I18n.t("menu.quit"),
        function() self:onQuitClick() end,
        Theme.Colors.ERROR,
        20
    )

    -- Ícones pixel em cada botão (deixa o Button fazer auto-scale pela altura)
    self.buttons.play:setIcon("play_triangle")
    self.buttons.collection:setIcon("scroll")
    self.buttons.settings:setIcon("gear")
    self.buttons.quit:setIcon("x_close")
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
    
    if self.buttons.collection then
        self.buttons.collection:setPosition(centerX - buttonWidth / 2, startY + spacing)
        self.buttons.collection.width = buttonWidth
        self.buttons.collection.height = buttonHeight
    end

    if self.buttons.settings then
        self.buttons.settings:setPosition(centerX - buttonWidth / 2, startY + spacing * 2)
        self.buttons.settings.width = buttonWidth
        self.buttons.settings.height = buttonHeight
    end

    if self.buttons.quit then
        self.buttons.quit:setPosition(centerX - buttonWidth / 2, startY + spacing * 3)
        self.buttons.quit.width = buttonWidth
        self.buttons.quit.height = buttonHeight
    end
end

function Menu:update(dt)
    if not self.visible then return end

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
    Palette.set(Palette.PARCHMENT)
    local subtitleFont = FontManager.getResponsiveFont(Config.UI.SUBTITLE_FONT_RATIO, 14)
    love.graphics.setFont(subtitleFont)
    local subtitle = self:_subtitle()
    local subtitleWidth = subtitleFont:getWidth(subtitle)
    love.graphics.print(subtitle,
        math.floor(love.graphics.getWidth() / 2 - subtitleWidth / 2),
        math.floor(love.graphics.getHeight() * 0.42))
    
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

    -- Tenta usar PNG gerado (scene_menu.png); fallback pra voidStars procedural.
    local BackgroundLoader = require("src.ui.card.BackgroundLoader")
    local SceneBackground = require("src.ui.SceneBackground")
    if SceneBackground.draw("menu", width, height) then
        -- Overlay grimório pulsante dourado sutil
        local pulse = 0.04 + math.sin(love.timer.getTime() * 0.5) * 0.02
        love.graphics.setColor(Palette.AGED_GOLD[1], Palette.AGED_GOLD[2], Palette.AGED_GOLD[3], pulse)
        love.graphics.rectangle("fill", 0, 0, width, height)
        love.graphics.setColor(1, 1, 1, 1)
        return
    end

    -- Fallback: voidStars + overlay ink (sem magenta)
    local bg = PixelBackground.voidStars(width, height)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(bg, 0, 0)
    love.graphics.setColor(Palette.INK[1], Palette.INK[2], Palette.INK[3], 0.45)
    love.graphics.rectangle("fill", 0, 0, width, height)
    love.graphics.setColor(1, 1, 1, 1)
end

function Menu:drawTitle()
    local titleFont = FontManager.getResponsiveFont(Config.UI.TITLE_FONT_RATIO, 40)
    love.graphics.setFont(titleFont)

    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    local title = self:_title()
    local tw = titleFont:getWidth(title)
    local th = titleFont:getHeight(title)
    local tx = math.floor(width / 2 - tw / 2)
    local ty = math.floor(height * 0.22)

    -- Banner pixel: ink fill + borda dourada dupla via PixelCanvas
    local padX, padY = 28, 12
    local bx, by = tx - padX, ty - padY
    local bw, bh = tw + padX * 2, th + padY * 2
    PixelCanvas.rect(bx, by, bw, bh, Palette.PANEL_FILL)
    PixelCanvas.rectOutline(bx, by, bw, bh, Palette.PANEL_OUTLINE)
    PixelCanvas.rectOutline(bx + 3, by + 3, bw - 6, bh - 6, Palette.PANEL_OUTLINE_INNER)

    -- Sombra de texto pixel (offset 2px)
    Palette.set(Palette.INK)
    love.graphics.print(title, tx + 2, ty + 2)

    -- Título com leve pulsação dourada
    local pulse = 0.85 + math.sin(love.timer.getTime() * 1.2) * 0.15
    love.graphics.setColor(Palette.AGED_GOLD_LIGHT[1] * pulse,
                           Palette.AGED_GOLD_LIGHT[2] * pulse,
                           Palette.AGED_GOLD_LIGHT[3] * pulse, 1)
    love.graphics.print(title, tx, ty)
end

function Menu:drawInstructions()
    Palette.set(Palette.PARCHMENT_DARK)
    local instructionFont = FontManager.getResponsiveFont(Config.UI.INSTRUCTION_FONT_RATIO, 10)
    love.graphics.setFont(instructionFont)

    local instructions = {
        I18n.t("menu.instr_mouse"),
        I18n.t("menu.instr_space"),
        I18n.t("menu.instr_restart"),
        I18n.t("menu.instr_jokers"),
    }

    local y = math.floor(love.graphics.getHeight() * 0.88)
    for i, instruction in ipairs(instructions) do
        local x = math.floor(love.graphics.getWidth() / 2 - instructionFont:getWidth(instruction) / 2)
        love.graphics.print(instruction, x, y + (i - 1) * (instructionFont:getHeight() + 4))
    end
end

function Menu:onPlayClick()
    self.visible = false
    if self.onPlayCallback then
        self.onPlayCallback()
    end
end

function Menu:onSettingsClick()
    if self.onSettingsCallback then
        self.onSettingsCallback()
    else
        print("Configurações - callback não definido")
    end
end

function Menu:onCollectionClick()
    if self.onCollectionCallback then
        self.onCollectionCallback()
    else
        print("Coleção - callback não definido")
    end
end

function Menu:setCollectionCallback(cb) self.onCollectionCallback = cb end
function Menu:setSettingsCallback(cb) self.onSettingsCallback = cb end

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
