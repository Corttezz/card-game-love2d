-- components/CardRewardScreen.lua
-- Tela de recompensas de cartas após vitória em batalha

local CardRewardScreen = {}
CardRewardScreen.__index = CardRewardScreen

local Config = require("src.core.Config")
local FontManager = require("src.ui.FontManager")
local Theme = require("src.ui.Theme")
local VisualEffects = require("src.ui.VisualEffects")
local Button = require("components.Button")
local CardDatabase = require("src.systems.CardDatabase")
local CardInfoDisplay = require("src.ui.CardInfoDisplay")

function CardRewardScreen:new()
    local instance = setmetatable({}, CardRewardScreen)
    
    instance.visible = false
    instance.rewardCards = {} -- As 3 cartas oferecidas
    instance.cardInstances = {} -- Instâncias reais de Card
    instance.cardButtons = {} -- Botões das cartas
    instance.skipButton = nil
    instance.onCardSelected = nil -- Callback quando carta é selecionada
    instance.onSkipped = nil -- Callback quando pula recompensa
    
    -- Animações
    instance.animationTime = 0
    instance.cardAnimations = {}
    
    -- Sistema de cartas
    instance.cardDatabase = CardDatabase:new()
    
    -- Componente de exibição de informações das cartas
    instance.cardInfoDisplay = CardInfoDisplay:new()
    
    -- Layout responsivo
    instance:updateLayout()
    
    return instance
end

function CardRewardScreen:updateLayout()
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    -- Dimensões das cartas responsivas baseadas na menor dimensão da tela
    local baseSize = math.min(screenWidth, screenHeight)
    local minCardWidth = 120
    local maxCardWidth = 220
    
    -- Calcula tamanho da carta baseado na tela, com limites
    self.cardWidth = math.max(minCardWidth, math.min(maxCardWidth, baseSize * 0.15))
    self.cardHeight = self.cardWidth * 1.4 -- Proporção clássica de carta
    
    -- Espaçamento proporcional ao tamanho da carta
    local cardSpacing = self.cardWidth * 0.3
    
    -- Área total ocupada pelas cartas
    local totalCardsWidth = self.cardWidth * 3 + cardSpacing * 2
    local totalCardsHeight = self.cardHeight
    
    -- Área disponível (deixando margem)
    local availableWidth = screenWidth * 0.9
    local availableHeight = screenHeight * 0.7
    
    -- Se as cartas não cabem, redimensiona
    if totalCardsWidth > availableWidth then
        local scale = availableWidth / totalCardsWidth
        self.cardWidth = self.cardWidth * scale
        self.cardHeight = self.cardHeight * scale
        cardSpacing = cardSpacing * scale
        totalCardsWidth = availableWidth
    end
    
    -- Centralização COMPLETA na tela
    local startX = (screenWidth - totalCardsWidth) / 2
    local cardY = (screenHeight - self.cardHeight) / 2
    
    -- Ajuste fino para considerar título e botão
    local titleHeight = screenHeight * 0.08 -- Espaço para título
    local buttonHeight = 60 -- Altura do botão + margem
    local contentHeight = titleHeight + self.cardHeight + buttonHeight
    
    -- Se o conteúdo total não cabe, ajusta
    if contentHeight > screenHeight * 0.9 then
        cardY = titleHeight + (screenHeight * 0.9 - contentHeight) / 2
    else
        cardY = (screenHeight - contentHeight) / 2 + titleHeight
    end
    
    self.cardPositions = {}
    for i = 1, 3 do
        self.cardPositions[i] = {
            x = startX + (i - 1) * (self.cardWidth + cardSpacing),
            y = cardY
        }
    end
    
    -- Botão de pular centralizado abaixo das cartas
    local skipButtonWidth = 180
    self.skipButtonX = (screenWidth - skipButtonWidth) / 2
    self.skipButtonY = cardY + self.cardHeight + 20
    
    print("[CardRewardScreen] Layout updated - Screen:", screenWidth, "x", screenHeight, "Card size:", self.cardWidth, "x", self.cardHeight, "Start at:", startX, cardY)
end

function CardRewardScreen:show(rewardCards, onCardSelected, onSkipped)
    self.visible = true
    self.rewardCards = rewardCards or {}
    self.onCardSelected = onCardSelected
    self.onSkipped = onSkipped
    self.animationTime = 0
    
    -- Debug: verificar dados das cartas
    print("[CardRewardScreen] Showing reward screen with", #self.rewardCards, "cards")
    for i, card in ipairs(self.rewardCards) do
        print("  Card", i, ":", card.cardId, "(", card.rarity, ")")
    end
    
    -- Recalcula layout para tela atual
    self:updateLayout()
    
    -- Cria instâncias reais de Card
    self:createCardInstances()
    
    -- Cria botões para as cartas
    self:createCardButtons()
    
    -- Cria botão de pular
    self.skipButton = Button:new(
        self.skipButtonX, self.skipButtonY, 160, 40,
        "Pular Recompensa",
        function()
            self:hide()
            if self.onSkipped then
                self.onSkipped()
            end
        end
    )
    
    -- Inicializa animações das cartas
    for i = 1, 3 do
        self.cardAnimations[i] = {
            scale = 0,
            targetScale = 1,
            delay = (i - 1) * 0.1,
            elapsed = 0
        }
    end
end

function CardRewardScreen:createCardInstances()
    self.cardInstances = {}
    
    for i, rewardCard in ipairs(self.rewardCards) do
        if i <= 3 then -- Máximo 3 cartas
            -- Busca dados completos da carta primeiro
            local cardData = self.cardDatabase:getCard(rewardCard.cardId)
            if not cardData then
                print("[CardRewardScreen] ERROR: Card data not found for", rewardCard.cardId)
                goto continue
            end
            
            -- Cria instância real de Card usando o CardDatabase
            local cardInstance = self.cardDatabase:createCardInstance(cardData)
            
            if cardInstance then
                -- Configura a carta para a tela de rewards
                local pos = self.cardPositions[i]
                cardInstance.x = pos.x
                cardInstance.y = pos.y
                
                -- Usa a mesma escala das cartas da mão
                cardInstance.baseScale = Config.Cards.BASE_SCALE
                cardInstance.currentScale = Config.Cards.BASE_SCALE
                cardInstance.targetScale = Config.Cards.HOVER_SCALE
                
                -- Adiciona informações de raridade para a borda
                cardInstance.rarity = rewardCard.rarity
                cardInstance.rarityBorderTime = 0
                
                -- Garante que a descrição está definida
                if not cardInstance.description and rewardCard.description then
                    cardInstance.description = rewardCard.description
                end
                
                -- Remove a marcação de reward para comportamento normal das cartas
                cardInstance.isRewardCard = false
                
                -- Configura o CardInfoDisplay para mostrar raridade (específico para recompensas)
                if cardInstance.cardInfoDisplay then
                    cardInstance.cardInfoDisplay:configure({
                        showRarity = true,
                        showStats = true,
                        showDescription = true
                    })
                end
                
                table.insert(self.cardInstances, cardInstance)
                print("[CardRewardScreen] Created card instance", i, "for", rewardCard.cardId, "rarity:", rewardCard.rarity)
            else
                print("[CardRewardScreen] ERROR: Could not create card instance for", rewardCard.cardId)
            end
        end
        ::continue::
    end
end

function CardRewardScreen:createCardButtons()
    self.cardButtons = {}
    
    for i, rewardCard in ipairs(self.rewardCards) do
        if i <= 3 then -- Máximo 3 cartas
            local pos = self.cardPositions[i]
            
            -- Botão invisível sobre a carta para capturar cliques
            local button = Button:new(
                pos.x, pos.y, self.cardWidth, self.cardHeight,
                "", -- Sem texto, será desenhado customizado
                function()
                    print("[CardRewardScreen] Card", i, "clicked:", rewardCard.cardId)
                    self:selectCard(rewardCard, i)
                end
            )
            
            -- Personaliza o botão para ser completamente transparente
            button.baseColor = {0, 0, 0, 0}
            button.hoverColor = {0, 0, 0, 0}
            button.pressColor = {0, 0, 0, 0}
            button.disabledColor = {0, 0, 0, 0}
            
            table.insert(self.cardButtons, button)
            print("[CardRewardScreen] Created button", i, "at", pos.x, pos.y, "size", self.cardWidth, self.cardHeight)
        end
    end
end

function CardRewardScreen:selectCard(rewardCard, cardIndex)
    print("[CardRewardScreen] Selecting card:", rewardCard.cardId, "(index:", cardIndex, ")")
    
    -- Animação de seleção
    local pos = self.cardPositions[cardIndex]
    
    -- Feedback visual
    if VisualEffects and VisualEffects.Particles and VisualEffects.Particles.createCardSelectEffect then
    VisualEffects.Particles.createCardSelectEffect(pos.x + self.cardWidth/2, pos.y + self.cardHeight/2)
    end
    
    self:hide()
    
    if self.onCardSelected then
        print("[CardRewardScreen] Calling onCardSelected with:", rewardCard.cardId)
        self.onCardSelected(rewardCard.cardId)
    else
        print("[CardRewardScreen] WARNING: No onCardSelected callback")
    end
end

function CardRewardScreen:hide()
    self.visible = false
    self.rewardCards = {}
    self.cardInstances = {}
    self.cardButtons = {}
    self.skipButton = nil
end

function CardRewardScreen:update(dt)
    if not self.visible then return end
    
    -- Verifica se o tamanho da tela mudou e recalcula layout se necessário
    local currentWidth = love.graphics.getWidth()
    local currentHeight = love.graphics.getHeight()
    if not self.lastScreenWidth or self.lastScreenWidth ~= currentWidth or self.lastScreenHeight ~= currentHeight then
        self.lastScreenWidth = currentWidth
        self.lastScreenHeight = currentHeight
        self:updateLayout()
        -- Recria instâncias e botões com as novas posições
        if #self.rewardCards > 0 then
            self:createCardInstances()
            self:createCardButtons()
            -- Recria botão de pular
            if self.skipButton then
                self.skipButton.x = self.skipButtonX
                self.skipButton.y = self.skipButtonY
            end
        end
    end
    
    self.animationTime = self.animationTime + dt
    
    -- Atualiza animações das cartas
    for i = 1, 3 do
        local anim = self.cardAnimations[i]
        if anim then
            anim.elapsed = anim.elapsed + dt
            
            if anim.elapsed >= anim.delay then
                local progress = math.min(1, (anim.elapsed - anim.delay) / 0.3)
                anim.scale = anim.targetScale * self:easeOutBack(progress)
            end
        end
    end
    
    -- Atualiza instâncias de cartas
    for i, cardInstance in ipairs(self.cardInstances) do
        if cardInstance and cardInstance.updateMouse then
            local pos = self.cardPositions[i]
            local mx, my = love.mouse.getPosition()
            
            -- Usa o sistema natural de hover das cartas (igual às cartas na mão)
            cardInstance:updateMouse(mx, my, dt, true)
            
            -- Atualiza animação da borda de raridade
            if cardInstance.rarityBorderTime then
                cardInstance.rarityBorderTime = cardInstance.rarityBorderTime + dt * Config.Cards.RARITY_BORDER_ANIMATION_SPEED
            end
        end
    end
    
    -- Atualiza botões
    for _, button in ipairs(self.cardButtons) do
        button:update(dt)
    end
    
    if self.skipButton then
        self.skipButton:update(dt)
    end
end

-- Função de easing para animação suave
function CardRewardScreen:easeOutBack(t)
    local c1 = 1.70158
    local c3 = c1 + 1
    return 1 + c3 * math.pow(t - 1, 3) + c1 * math.pow(t - 1, 2)
end

function CardRewardScreen:draw()
    if not self.visible then return end
    
    -- Fundo escurecido
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    -- Título
    self:drawTitle()
    
    -- Desenha as instâncias de cartas
    for i, cardInstance in ipairs(self.cardInstances) do
        if cardInstance and cardInstance.draw then
            local anim = self.cardAnimations[i]
            local scale = anim and anim.scale or 1
            
            if scale > 0 then
                local pos = self.cardPositions[i]
                
                -- Desenha borda de raridade antes da carta (só quando não está em hover)
                if not cardInstance.isHovered then
                    self:drawRarityBorder(cardInstance, pos.x, pos.y)
                end
                
                -- Desenha a carta com o mesmo comportamento das cartas na mão
                -- O CardInfoDisplay será renderizado automaticamente pela carta
                cardInstance:draw(pos.x, pos.y, false, false)
            end
        end
    end
    
    -- Não desenha os botões das cartas para evitar bordas visuais
    -- Os cliques ainda funcionam através do sistema de mousepressed/mousereleased
    
    if self.skipButton then
        self.skipButton:draw()
    end
    
    -- Instruções
    self:drawInstructions()
end

function CardRewardScreen:drawTitle()
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    -- local titleFont = FontManager.getResponsiveFont(0.06, math.max(24, screenHeight * 0.04))
    -- love.graphics.setFont(titleFont)
    
    -- local title = "Escolha sua Recompensa"
    -- local titleWidth = titleFont:getWidth(title)
    -- local titleX = (screenWidth - titleWidth) / 2
    
    -- -- Posição do título baseada no layout das cartas
    -- local titleY = math.max(20, (self.cardPositions[1] and self.cardPositions[1].y or screenHeight * 0.3) - 60)
    
    -- -- Sombra do título
    -- if Theme and Theme.Utils and Theme.Utils.drawTextWithShadow then
    --     Theme.Utils.drawTextWithShadow(title, titleX, titleY, titleFont, Theme.Colors.TEXT_PRIMARY)
    -- else
    --     -- Fallback: desenho simples com sombra
    --     love.graphics.setColor(0, 0, 0, 0.5)
    --     love.graphics.print(title, titleX + 2, titleY + 2)
    --     love.graphics.setColor(1, 1, 1, 1)
    --     love.graphics.print(title, titleX, titleY)
    -- end
end

function CardRewardScreen:drawInstructions()
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    local instrFont = FontManager.getResponsiveFont(0.025, math.max(14, screenHeight * 0.025))
    love.graphics.setFont(instrFont)
    love.graphics.setColor(0.8, 0.8, 0.8, 1)
    
    local instruction = "Clique em uma carta para adicioná-la ao seu deck"
    local instrWidth = instrFont:getWidth(instruction)
    local instrX = (screenWidth - instrWidth) / 2
    
    -- Posiciona instruções abaixo do botão de pular
    local instrY = self.skipButtonY + 60
    
    -- Se não houver espaço suficiente, coloca acima das cartas
    if instrY + instrFont:getHeight() > screenHeight - 20 then
        instrY = math.max(10, (self.cardPositions[1] and self.cardPositions[1].y or screenHeight * 0.3) - 90)
    end
    
    love.graphics.print(instruction, instrX, instrY)
end

-- Função removida - agora usa o sistema natural de hover das cartas
-- function CardRewardScreen:isCardHovered(cardIndex)
--     if not self.cardButtons[cardIndex] then return false end
--     
--     local button = self.cardButtons[cardIndex]
--     local mx, my = love.mouse.getPosition()
--     
--     return mx >= button.x and mx <= button.x + button.width and
--            my >= button.y and my <= button.y + button.height
-- end

function CardRewardScreen:mousepressed(x, y, button)
    if not self.visible then return false end
    
    print("[CardRewardScreen] Mouse pressed at", x, y, "button:", button)
    
    -- Propaga para botões das cartas
    for i, cardButton in ipairs(self.cardButtons) do
        local inBounds = x >= cardButton.x and x <= cardButton.x + cardButton.width and
                        y >= cardButton.y and y <= cardButton.y + cardButton.height
        print("  Card button", i, "bounds check:", inBounds, "(", cardButton.x, cardButton.y, cardButton.width, cardButton.height, ")")
        
        if cardButton:mousepressed(x, y, button) then
            print("  Card button", i, "handled the click")
            return true
        end
    end
    
    -- Botão de pular
    if self.skipButton and self.skipButton:mousepressed(x, y, button) then
        print("  Skip button handled the click")
        return true
    end
    
    print("  No button handled the click")
    return false
end

-- Adiciona suporte a mousereleased
function CardRewardScreen:mousereleased(x, y, button)
    if not self.visible then return false end
    
    print("[CardRewardScreen] Mouse released at", x, y, "button:", button)
    
    -- Propaga para botões das cartas
    for i, cardButton in ipairs(self.cardButtons) do
        if cardButton:mousereleased(x, y, button) then
            print("  Card button", i, "handled the release")
            return true
        end
    end
    
    -- Botão de pular
    if self.skipButton and self.skipButton:mousereleased(x, y, button) then
        print("  Skip button handled the release")
        return true
    end
    
    return false
end

function CardRewardScreen:drawRarityBorder(cardInstance, x, y)
    if not cardInstance.rarity then return end
    
    local rarityColor = Config.Cards.RARITY_COLORS[cardInstance.rarity]
    if not rarityColor then return end
    
    -- Calcula animação da borda
    local pulseAlpha = 0.6 + math.sin(cardInstance.rarityBorderTime) * Config.Cards.RARITY_BORDER_PULSE_RANGE
    local borderColor = {
        rarityColor[1],
        rarityColor[2], 
        rarityColor[3],
        pulseAlpha
    }
    
    -- Calcula dimensões da carta
    local cardWidth = cardInstance.image:getWidth() * cardInstance.currentScale
    local cardHeight = cardInstance.image:getHeight() * cardInstance.currentScale
    
    -- Desenha múltiplas bordas para efeito de profundidade
    for i = 1, 2 do
        local currentOffset = (i - 1) * 2
        local currentAlpha = borderColor[4] * (1 - (i - 1) * 0.3)
        
        love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], currentAlpha)
        love.graphics.setLineWidth(Config.Cards.RARITY_BORDER_THICKNESS)
        
        -- Desenha retângulo de borda
        love.graphics.rectangle("line", 
            x + currentOffset, 
            y + currentOffset, 
            cardWidth - currentOffset * 2, 
            cardHeight - currentOffset * 2, 
            8, 8 -- Bordas arredondadas
        )
    end
end

-- Função removida - as cartas agora usam CardInfoDisplay automaticamente
-- function CardRewardScreen:drawRarityInDescription(cardInstance, x, y)
--     if not cardInstance.rarity then return end
--     
--     -- Usa o componente CardInfoDisplay para desenhar as informações
--     self.cardInfoDisplay:draw(cardInstance, x, y, {
--         showRarity = true,
--         showStats = true,
--         showDescription = true
--     })
-- end

function CardRewardScreen:isVisible()
    return self.visible
end

return CardRewardScreen
