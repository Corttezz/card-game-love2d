-- components/TopBar.lua
-- Barra superior com informações do jogo (ouro, deck, config).
-- Pixel chrome: ink fill + borda dourada + ícones via IconLoader.

local FontManager = require("src.ui.FontManager")
local ImageCache  = require("src.ui.ImageCache")
local IconLoader  = require("src.ui.IconLoader")
local PixelCanvas = require("src.ui.PixelCanvas")
local Palette     = require("src.ui.Palette")
local I18n        = require("src.i18n.I18n")

local TopBar = {}
TopBar.__index = TopBar

function TopBar:new()
    local instance = setmetatable({}, TopBar)

    instance.visible = true
    instance.height = 52

    -- Ícones PNG legados (coin/deck ainda carregam do assets/icons/)
    instance.coinIcon = ImageCache.get("assets/icons/coin.png")
    instance.deckIcon = ImageCache.get("assets/icons/deck.png")

    -- Gear (pixel) via IconLoader — substitui config.png
    instance.gearIcon = IconLoader.get("gear")

    instance.game = nil

    instance.configHoverTime = 0
    instance.configRotation = 0
    instance.isConfigHovered = false

    return instance
end

function TopBar:setGame(game)
    self.game = game
end

function TopBar:update(dt)
    if not self.visible then return end

    local mx, my = love.mouse.getPosition()
    self.isConfigHovered = self:isConfigIconClicked(mx, my)

    if self.isConfigHovered then
        self.configHoverTime = self.configHoverTime + dt
        self.configRotation = self.configHoverTime * 3
    else
        self.configHoverTime = 0
        self.configRotation = 0
    end
end

function TopBar:draw()
    if not self.visible then return end

    local screenWidth = love.graphics.getWidth()

    -- Fundo pixel: ink fill + borda dourada dupla
    PixelCanvas.rect(0, 0, screenWidth, self.height, Palette.PANEL_FILL)
    PixelCanvas.hline(0, self.height,     screenWidth, Palette.AGED_GOLD)
    PixelCanvas.hline(0, self.height + 1, screenWidth, Palette.AGED_GOLD_DARK)

    -- Rivets dourados espaçados (rectangles 4x4 inteiros)
    for i = 0, 4 do
        local x = 20 + math.floor(i * (screenWidth - 40) / 4)
        PixelCanvas.rect(x - 2, self.height - 6, 4, 4, Palette.AGED_GOLD)
        PixelCanvas.pixel(x - 1, self.height - 5, Palette.AGED_GOLD_LIGHT)
    end

    self:drawGameInfo()
    self:drawConfigIcon()
end

function TopBar:drawGameInfo()
    local padding = 20
    local iconScale = 0.05
    local centerY = math.floor(self.height / 2)

    -- Moeda
    if self.game and self.game.economySystem then
        local coinX = padding
        local coinY = centerY - 22

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(self.coinIcon, coinX, coinY, 0, iconScale, iconScale)

        Palette.set(Palette.AGED_GOLD_LIGHT)
        love.graphics.setFont(FontManager.getFont(12))
        local goldText = "$" .. self.game.economySystem.currentGold
        love.graphics.print(goldText, coinX + 50, centerY - 10)

        local interestGold = self.game.economySystem:calculateInterest()
        if interestGold > 0 then
            Palette.set(Palette.PARCHMENT)
            love.graphics.setFont(FontManager.getFont(8))
            local interestText = I18n.t("top_bar.interest_suffix", { amount = math.floor(interestGold) })
            love.graphics.print(interestText, coinX + 50, centerY + 6)
        end
    end

    -- Deck
    if self.game and self.game.deck then
        local deckX = padding + 180
        local deckY = centerY - 22

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(self.deckIcon, deckX, deckY, 0, iconScale, iconScale)

        Palette.set(Palette.PARCHMENT_LIGHT)
        love.graphics.setFont(FontManager.getFont(12))
        local deckSize = #self.game.deck
        local deckText = I18n.t("top_bar.deck_cards", { n = deckSize })
        love.graphics.print(deckText, deckX + 50, centerY - 10)

        if self.game.hand then
            Palette.set(Palette.PARCHMENT)
            love.graphics.setFont(FontManager.getFont(8))
            local handSize = #self.game.hand
            local handText = I18n.t("top_bar.hand_suffix", { n = handSize })
            love.graphics.print(handText, deckX + 50, centerY + 6)
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function TopBar:_getConfigRect()
    local screenWidth = love.graphics.getWidth()
    local iconPxSize = 32                                -- pixel size on screen
    local configX = screenWidth - iconPxSize - 20
    local configY = math.floor((self.height - iconPxSize) / 2)
    return configX, configY, iconPxSize
end

function TopBar:drawConfigIcon()
    local configX, configY, iconPxSize = self:_getConfigRect()
    local scale = iconPxSize / 16    -- matriz gear é 16×16

    local centerX = configX + iconPxSize / 2
    local centerY = configY + iconPxSize / 2

    love.graphics.push()
    love.graphics.translate(centerX, centerY)
    love.graphics.rotate(self.configRotation)
    love.graphics.translate(-centerX, -centerY)

    -- Highlight ao hover: círculo dourado por trás
    if self.isConfigHovered then
        PixelCanvas.rect(configX - 2, configY - 2, iconPxSize + 4, iconPxSize + 4, Palette.AGED_GOLD_DARK)
    end
    self.gearIcon.draw(configX, configY, scale)

    love.graphics.pop()
end

function TopBar:mousepressed(x, y, button)
    if not self.visible then return false end
    if y <= self.height then
        if self:isConfigIconClicked(x, y) then
            if self.game and self.game.toggleMenu then
                self.game:toggleMenu()
            end
            return true
        end
        return true
    end
    return false
end

function TopBar:mousereleased(x, y, button)
    if not self.visible then return false end
    return y <= self.height
end

function TopBar:resize() end

function TopBar:isConfigIconClicked(x, y)
    local configX, configY, iconPxSize = self:_getConfigRect()
    return x >= configX and x <= configX + iconPxSize
        and y >= configY and y <= configY + iconPxSize
end

return TopBar
