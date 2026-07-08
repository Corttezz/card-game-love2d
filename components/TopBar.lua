-- components/TopBar.lua
-- Barra superior com informações do jogo (ouro, deck, config).
-- Pixel chrome: ink fill + borda dourada + ícones via IconLoader.

local FontManager = require("src.ui.FontManager")
local ImageCache  = require("src.ui.ImageCache")
local IconLoader  = require("src.ui.IconLoader")
local PixelCanvas = require("src.ui.PixelCanvas")
local Palette     = require("src.ui.Palette")
local I18n        = require("src.i18n.I18n")
local ValueEasing = require("src.ui.ValueEasing")

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

    -- Valores eased pra display de gold/deck suavemente mutando.
    instance.disp = {}

    return instance
end

function TopBar:setGame(game)
    self.game = game
end

function TopBar:update(dt, game)
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

    -- Ease gold toward real (ease_dollars-style do Balatro). Counter sobe/desce
    -- suave em vez de saltar quando ganhar/gastar ouro.
    local g = game or self.game
    if g and g.economySystem then
        local realGold = g.economySystem.currentGold or 0
        -- Detecta delta de gold (ganho/gasto) e dispara micro-jiggle Balatro-style
        -- (engine/ui.lua:990 pattern: cada evento monetário empurra o accumulator).
        -- Skip primeiro frame onde _lastGold é nil pra não jigglar no boot.
        if self._lastGold and self._lastGold ~= realGold and _G.jiggleScreen then
            local delta = math.abs(realGold - self._lastGold)
            local amt = math.min(0.6, 0.05 + delta * 0.02) -- cap pra não enjoar em ganhos grandes
            _G.jiggleScreen(amt)
        end
        self._lastGold = realGold
        ValueEasing.tick(self.disp, "gold", realGold, dt, 6)
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
        -- Ambient pulse Balatro-style (engine/text.lua:228 pulse pattern):
        -- ícone ondula scale ±3% em sin lento (0.7 rad/s) pra não ficar estático.
        -- Reduced motion zera a oscilação.
        local rm = _G.gameSettings and _G.gameSettings.reducedMotion
        local pulse = rm and 1 or (1 + math.sin(love.timer.getTime() * 0.7) * 0.03)
        local cw, ch = self.coinIcon:getWidth(), self.coinIcon:getHeight()
        local scaledIcon = iconScale * pulse
        love.graphics.draw(self.coinIcon, coinX + cw * iconScale * 0.5, coinY + ch * iconScale * 0.5, 0,
                           scaledIcon, scaledIcon, cw / 2, ch / 2)

        Palette.set(Palette.AGED_GOLD_LIGHT)
        love.graphics.setFont(FontManager.getFont(12))
        -- Display eased pra counter Balatro-style (sobe/desce número suave)
        local goldDisp = math.floor((self.disp.gold or self.game.economySystem.currentGold or 0) + 0.001)
        local goldText = "$" .. goldDisp
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

    -- Score da run (F3 gameplay-overhaul): TINTA×SELO acumulado, sempre
    -- visível — o "quero bater meu recorde" do Balatro. Vira dourado pulsante
    -- pelo resto da run quando o recorde histórico é cruzado.
    if self.game and self.game.scoreSystem then
        local scoreX = padding + 380
        local IconLoader = require("src.ui.IconLoader")
        local icon = IconLoader.get("star")
        if icon and icon.draw and icon.size then
            local sc = 26 / icon.size.w
            love.graphics.setColor(1, 1, 1, 1)
            icon.draw(scoreX, centerY - 14, sc)
        end
        local record = self.game.scoreSystem.recordBroken
        if record then
            local pulse = 0.85 + math.sin(love.timer.getTime() * 2.5) * 0.15
            local g = Palette.AGED_GOLD_LIGHT
            love.graphics.setColor(g[1] * pulse, g[2] * pulse, g[3], 1)
        else
            Palette.set(Palette.PARCHMENT_LIGHT)
        end
        love.graphics.setFont(FontManager.getFont(12))
        love.graphics.print(tostring(self.game.score or 0), scoreX + 34, centerY - 10)
        Palette.set(record and Palette.AGED_GOLD or Palette.PARCHMENT)
        love.graphics.setFont(FontManager.getFont(8))
        love.graphics.print(record and I18n.t("top_bar.score_record")
            or I18n.t("top_bar.score_label"), scoreX + 34, centerY + 6)
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

function TopBar:setDeckClickCallback(cb) self.onDeckClick = cb end

function TopBar:mousepressed(x, y, button)
    if not self.visible then return false end
    if y <= self.height then
        if self:isConfigIconClicked(x, y) then
            if self.game and self.game.toggleMenu then
                self.game:toggleMenu()
            end
            return true
        end
        -- F5 do UI Overhaul: área do deck abre o Deck Viewer global
        local padding = 20
        local deckX = padding + 180
        if self.onDeckClick and x >= deckX and x <= deckX + 150 then
            self.onDeckClick()
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
