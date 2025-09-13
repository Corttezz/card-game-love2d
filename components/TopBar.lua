-- components/TopBar.lua
-- Barra superior com informações do jogo

local TopBar = {}
TopBar.__index = TopBar

local FontManager = require("src.ui.FontManager")
local Button = require("components.Button")

function TopBar:new()
    local instance = setmetatable({}, TopBar)
    
    instance.visible = true
    instance.height = 60
    
    -- Ícones
    instance.coinIcon = love.graphics.newImage("assets/icons/coin.png")
    instance.deckIcon = love.graphics.newImage("assets/icons/deck.png")
    instance.configIcon = love.graphics.newImage("assets/icons/config.png")
    
    -- Dados do jogo
    instance.game = nil
    
    -- Animação do ícone de config
    instance.configHoverTime = 0
    instance.configRotation = 0
    instance.isConfigHovered = false
    
    return instance
end

function TopBar:setGame(game)
    self.game = game
    -- Não cria mais o botão de config
end

function TopBar:update(dt)
    if not self.visible then return end
    
    -- Atualiza animação do ícone de config
    local mx, my = love.mouse.getPosition()
    self.isConfigHovered = self:isConfigIconClicked(mx, my)
    
    if self.isConfigHovered then
        self.configHoverTime = self.configHoverTime + dt
        -- Rotação contínua enquanto hover
        self.configRotation = self.configHoverTime * 3 -- Velocidade de rotação
    else
        self.configHoverTime = 0
        self.configRotation = 0
    end
end

function TopBar:draw()
    if not self.visible then return end
    
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    -- Fundo da barra superior
    love.graphics.setColor(0.1, 0.1, 0.15, 0.95)
    love.graphics.rectangle("fill", 0, 0, screenWidth, self.height)
    
    -- Borda inferior
    love.graphics.setColor(0.3, 0.3, 0.4, 1)
    love.graphics.setLineWidth(2)
    love.graphics.line(0, self.height, screenWidth, self.height)
    
    -- Desenha informações
    self:drawGameInfo()
    
    -- Desenha ícone de config (sem botão)
    self:drawConfigIcon()
end

function TopBar:drawGameInfo()
    local padding = 20
    local iconScale = 0.05 -- Escala maior para ser mais visível
    local spacing = 15
    
    -- Calcula altura central da barra
    local centerY = self.height / 2
    
    -- Moeda
    if self.game and self.game.economySystem then
        local coinX = padding
        local coinY = centerY - 25 -- Centraliza o ícone
        
        -- Ícone da moeda
        love.graphics.setColor(1, 1, 0.2, 1) -- Amarelo para moeda
        love.graphics.draw(self.coinIcon, coinX, coinY, 0, iconScale, iconScale)
        
        -- Quantidade de moeda
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setFont(FontManager.getFont(16))
        local goldText = "$" .. self.game.economySystem.currentGold
        love.graphics.print(goldText, coinX + 50, centerY - 16) -- Centraliza o texto
        
        -- Juros (se houver)
        local interestGold = self.game.economySystem:calculateInterest()
        if interestGold > 0 then
            love.graphics.setColor(0.8, 0.8, 0.8, 1)
            love.graphics.setFont(FontManager.getFont(12))
            local interestText = "(+" .. math.floor(interestGold) .. " juros)"
            love.graphics.print(interestText, coinX + 50, centerY ) -- Centraliza o texto
        end
    end  
    
    -- Deck
    if self.game and self.game.deck then
        local deckX = padding + 180 -- Mais espaço entre moeda e deck
        local deckY = centerY - 25 -- Centraliza o ícone
        
        -- Ícone do deck
        love.graphics.setColor(0.2, 0.6, 0.8, 1) -- Azul para deck
        love.graphics.draw(self.deckIcon, deckX, deckY, 0, iconScale, iconScale)
        
        -- Quantidade de cartas no deck
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setFont(FontManager.getFont(16))
        local deckSize = #self.game.deck
        local deckText = deckSize .. " cartas"
        love.graphics.print(deckText, deckX + 50, centerY - 16) -- Centraliza o texto
        
        -- Cartas na mão (se disponível)
        if self.game.hand then
            love.graphics.setColor(0.8, 0.8, 0.8, 1)
            love.graphics.setFont(FontManager.getFont(12))
            local handSize = #self.game.hand
            local handText = "(" .. handSize .. " na mão)"
            love.graphics.print(handText, deckX + 50, centerY) -- Centraliza o texto
        end
    end
end

function TopBar:drawConfigIcon()
    local screenWidth = love.graphics.getWidth()
    local iconScale = 0.05 -- Mesma escala dos outros ícones
    local padding = 14
    local iconSize = 32
    
    -- Posição do ícone de config (canto direito)
    local configX = screenWidth - iconSize - padding - 20
    local configY = (self.height - iconSize) / 2 - 10
    
    -- Calcula o centro real do ícone escalado
    local scaledWidth = self.configIcon:getWidth() * iconScale
    local scaledHeight = self.configIcon:getHeight() * iconScale
    local centerX = configX + scaledWidth / 2
    local centerY = configY + scaledHeight / 2
    
    -- Salva o estado atual
    love.graphics.push()
    
    -- Move para o centro e aplica rotação
    love.graphics.translate(centerX, centerY)
    love.graphics.rotate(self.configRotation)
    love.graphics.translate(-centerX, -centerY)
    
    -- Desenha o ícone na posição original
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.configIcon, configX, configY, 0, iconScale, iconScale)
    
    -- Restaura o estado
    love.graphics.pop()
end

function TopBar:mousepressed(x, y, button)
    if not self.visible then return false end
    
    -- Verifica se clicou na barra superior
    if y <= self.height then
        -- Verifica se clicou no ícone de config
        if self:isConfigIconClicked(x, y) then
            if self.game and self.game.toggleMenu then
                self.game:toggleMenu()
            end
            return true
        end
        
        -- Consome o clique se foi na barra (evita propagação)
        return true
    end
    
    return false
end

function TopBar:mousereleased(x, y, button)
    if not self.visible then return false end
    
    -- Verifica se foi na barra superior
    if y <= self.height then
        return true
    end
    
    return false
end

function TopBar:resize()
    -- Não precisa mais recalcular posições do botão
end

function TopBar:isConfigIconClicked(x, y)
    local screenWidth = love.graphics.getWidth()
    local iconScale = 0.05
    local padding = 14
    local iconSize = 32
    
    -- Posição do ícone de config (mesma do drawConfigIcon)
    local configX = screenWidth - iconSize - padding - 20
    local configY = (self.height - iconSize) / 2 - 10
    
    -- Verifica se o clique foi dentro da área do ícone
    return x >= configX and x <= configX + iconSize and 
           y >= configY and y <= configY + iconSize
end

return TopBar
