-- components/JokerCard.lua
-- Componente de carta joker que funciona como as cartas normais da mão

local Config = require("src.core.Config")
local Theme = require("src.ui.Theme")
local CardInfoDisplay = require("src.ui.CardInfoDisplay")

local JokerCard = {}
JokerCard.__index = JokerCard

-- Cache de áudio para hover
local hoverSoundCache = nil

function JokerCard:new(jokerData)
    local instance = setmetatable({}, JokerCard)
    
    -- Dados do joker
    instance.id = jokerData.id
    instance.name = jokerData.name
    instance.cost = jokerData.cost or 0
    instance.type = "joker"
    instance.subtype = jokerData.subtype
    instance.description = jokerData.description
    instance.effects = jokerData.effects or {}
    
    -- Carrega a imagem
    if jokerData.image and jokerData.image ~= "" then
        local success, image = pcall(love.graphics.newImage, jokerData.image)
        if success then
            instance.image = image
        else
            print("ERROR: Não foi possível carregar imagem do joker: " .. tostring(jokerData.image))
            instance.image = love.graphics.newImage("assets/cards/attack/theRock.png")
        end
    else
        instance.image = love.graphics.newImage("assets/cards/attack/theRock.png")
    end
    
    -- Propriedades para hover e animação
    instance.x = 0
    instance.y = 0
    instance.baseScale = Config.Cards.BASE_SCALE -- Jokers têm tamanho normal
    instance.targetScale = instance.baseScale
    instance.currentScale = instance.baseScale
    instance.width = instance.image:getWidth() * instance.baseScale
    instance.height = instance.image:getHeight() * instance.baseScale
    instance.isHovered = false
    
    -- Efeitos 3D
    instance.offsetHoverX = 0
    instance.offsetHoverY = 0
    instance.tiltX = 0
    instance.tiltY = 0
    instance.liftOffset = 0
    instance.perspectiveRotation = 0
    instance.shadowOffsetX = 0
    instance.shadowOffsetY = 0
    instance.shadowScale = 0.9
    
    -- Animação da borda
    instance.borderAnimationTime = 0
    
    -- Componente para exibir informações da carta
    instance.cardInfoDisplay = CardInfoDisplay:new()
    
    return instance
end

function JokerCard:updateMouse(mx, my, dt, isHovered)
    -- Atualiza escala
    local scaleFactor = self.currentScale
    local cardWidth = self.image:getWidth() * scaleFactor
    local cardHeight = self.image:getHeight() * scaleFactor

    -- Calcula deslocamento vertical se estiver em hover
    local offsetY = self.isHovered and -30 or 0

    -- Verifica se o mouse está sobre a carta ajustada
    local wasHovered = self.isHovered
    if mx >= self.x and mx <= self.x + cardWidth and my >= (self.y + offsetY) and my <= (self.y + offsetY + cardHeight) and
        isHovered then
        self.isHovered = true
        self.targetScale = Config.Cards.HOVER_SCALE -- Jokers têm hover normal
        
        if not wasHovered then
            -- Toca som de hover
            if not hoverSoundCache then
                hoverSoundCache = love.audio.newSource("audio/hoverCard.wav", "static")
                hoverSoundCache:setVolume(Config.Audio.HOVER_VOLUME)
            end
            
            if hoverSoundCache then
                hoverSoundCache:stop()
                hoverSoundCache:play()
            end
        end

        -- Efeitos 3D Balatro-style
        local mouseXRelative = (mx - self.x) / cardWidth
        local mouseYRelative = (my - (self.y + offsetY)) / cardHeight
        
        local normalizedX = (mouseXRelative - 0.5) * 2
        local normalizedY = (mouseYRelative - 0.5) * 2

        -- Efeito de profundidade
        local centerDistance = math.sqrt(normalizedX^2 + normalizedY^2)
        local depthMultiplier = 1 - (centerDistance * 0.3)
        
        -- Deslocamento baseado na profundidade
        self.offsetHoverX = normalizedX * Config.Cards.MOVE_RANGE * depthMultiplier
        self.offsetHoverY = normalizedY * Config.Cards.MOVE_RANGE * depthMultiplier
        
        -- Efeito de rotação 3D
        local tiltRange = Config.Cards.TILT_RANGE
        local depthTiltX = Config.Cards.DEPTH_TILT_X
        local depthTiltY = Config.Cards.DEPTH_TILT_Y
        
        self.tiltX = normalizedX * tiltRange + (normalizedX * depthTiltX * depthMultiplier)
        self.tiltY = normalizedY * tiltRange + (normalizedY * depthTiltY * depthMultiplier)
        
        -- Efeito de elevação
        local liftAmount = Config.Cards.LIFT_AMOUNT
        self.liftOffset = liftAmount * depthMultiplier
        
        -- Sombra dinâmica
        local shadowOffsetBaseX = Config.Cards.SHADOW_OFFSET_BASE_X
        local shadowOffsetBaseY = Config.Cards.SHADOW_OFFSET_BASE_Y
        local shadowStretchX = Config.Cards.SHADOW_STRETCH_X
        local shadowStretchY = Config.Cards.SHADOW_STRETCH_Y
        
        self.shadowOffsetX = shadowOffsetBaseX + (normalizedX * shadowStretchX * depthMultiplier)
        self.shadowOffsetY = shadowOffsetBaseY + (normalizedY * shadowStretchY * depthMultiplier)
        
        local shadowScaleBase = Config.Cards.SHADOW_SCALE_BASE
        local shadowScaleVariation = Config.Cards.SHADOW_SCALE_VARIATION
        self.shadowScale = shadowScaleBase - (centerDistance * shadowScaleVariation)
        
        -- Rotação de perspectiva
        self.perspectiveRotation = normalizedX * 0.05 * depthMultiplier

    else
        self.isHovered = false
        self.targetScale = self.baseScale

        -- Reseta os deslocamentos
        self.offsetHoverX = 0
        self.offsetHoverY = 0
        self.tiltX = 0
        self.tiltY = 0
        self.liftOffset = 0
        self.perspectiveRotation = 0
        self.shadowOffsetX = 0
        self.shadowOffsetY = 0
        self.shadowScale = 0.9
    end

    -- Suaviza a transição para o tamanho alvo
    self.currentScale = self.currentScale + (self.targetScale - self.currentScale) * Config.Cards.SCALE_ANIMATION_SPEED * dt
    
    -- Atualiza animação da borda
    self.borderAnimationTime = self.borderAnimationTime + dt * Config.Cards.BORDER_ANIMATION_SPEED
end

function JokerCard:draw(x, y)
    -- Atualiza posição
    self.x = x
    self.y = y

    -- Calcula deslocamentos para hover com efeito 3D
    local baseOffsetY = self.isHovered and -Config.Cards.DEPTH_OFFSET or 0
    local hoverOffsetY = self.liftOffset or 0
    local totalOffsetY = baseOffsetY + hoverOffsetY
    
    local offsetX = self.offsetHoverX or 0
    local offsetY = self.offsetHoverY or 0

    -- Aplica transformação de perspectiva 3D
    local tiltX = self.tiltX or 0
    local tiltY = self.tiltY or 0
    local perspectiveRotation = self.perspectiveRotation or 0
    
    -- Escala dinâmica baseada na inclinação
    local scaleX = self.currentScale * (1 + math.abs(tiltX) * 0.3)
    local scaleY = self.currentScale * (1 + math.abs(tiltY) * 0.3)

    -- Sombra dinâmica 3D
    local shadowX = x + (self.shadowOffsetX or -Config.Cards.SHADOW_OFFSET_BASE_X)
    local shadowY = y + (self.shadowOffsetY or Config.Cards.SHADOW_OFFSET_BASE_Y)
    local shadowScaleX = (self.shadowScale or Config.Cards.SHADOW_SCALE_BASE) * 1.1
    local shadowScaleY = (self.shadowScale or Config.Cards.SHADOW_SCALE_BASE) * 0.9

    -- Desenha sombra
    local shadowAlpha = Config.Cards.SHADOW_INTENSITY * (1 - (self.liftOffset or 0) / Config.Cards.LIFT_AMOUNT)
    love.graphics.setColor(0, 0, 0, shadowAlpha)
    love.graphics.draw(self.image, shadowX, shadowY, 0, scaleX * shadowScaleX, scaleY * shadowScaleY)

    -- Desenha borda azul animada (jokers sempre podem ser "jogados")
    local borderThickness = Config.Cards.PLAYABLE_BORDER_THICKNESS
    local cardWidth = self.image:getWidth() * scaleX
    local cardHeight = self.image:getHeight() * scaleY
    
    -- Calcula animação da borda
    local pulseAlpha = 0.5 + math.sin(self.borderAnimationTime) * Config.Cards.BORDER_PULSE_RANGE
    local borderColor = {
        Config.Cards.PLAYABLE_BORDER_COLOR[1],
        Config.Cards.PLAYABLE_BORDER_COLOR[2], 
        Config.Cards.PLAYABLE_BORDER_COLOR[3],
        pulseAlpha
    }
    
    -- Borda vem menos para dentro da carta
    local innerOffset = Config.Cards.BORDER_INNER_OFFSET
    
    -- Desenha múltiplas bordas para efeito de profundidade
    for i = 1, 3 do
        local currentOffset = innerOffset - (i - 1) * 2
        local currentAlpha = borderColor[4] * (1 - (i - 1) * 0.3)
        
        love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], currentAlpha)
        
        -- Desenha retângulo de borda com offset interno
        love.graphics.rectangle("line", 
            x + offsetX + currentOffset, 
            y + totalOffsetY + currentOffset, 
            cardWidth - currentOffset * 2, 
            cardHeight - currentOffset * 2, 
            borderThickness, 
            borderThickness
        )
    end

    -- Carta principal com efeito 3D
    love.graphics.setColor(1, 1, 1, 1)
    
    -- Aplica transformação 3D na carta
    love.graphics.push()
    
    -- Move para o centro da carta para aplicar rotação
    local cardCenterX = x + offsetX + (self.image:getWidth() * scaleX) / 2
    local cardCenterY = y + totalOffsetY + (self.image:getHeight() * scaleY) / 2
    
    love.graphics.translate(cardCenterX, cardCenterY)
    
    -- Aplica rotação de perspectiva 3D
    love.graphics.rotate(perspectiveRotation)
    
    -- Desenha a carta com offset do centro
    local drawX = -((self.image:getWidth() * scaleX) / 2)
    local drawY = -((self.image:getHeight() * scaleY) / 2)
    
    love.graphics.draw(self.image, drawX, drawY, 0, scaleX, scaleY)
    
    -- Restaura transformações
    love.graphics.pop()

    -- Texto de descrição no hover
    if self.isHovered then
        local textOffsetY = y + totalOffsetY - 80
        
        -- Background semi-transparente para o texto
        love.graphics.setColor(0, 0, 0, 0.8)
        local textWidth = 200
        local textHeight = 60
        love.graphics.rectangle("fill", x - 10, textOffsetY - 5, textWidth, textHeight, 10, 10)
        
        -- Usa o componente CardInfoDisplay para desenhar as informações
        self.cardInfoDisplay:draw(self, x, textOffsetY, {
            showRarity = false,
            showStats = true,
            showDescription = true
        })
        
        -- Adiciona o label "JOKER" específico
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("JOKER", x + 10, textOffsetY + 20)
    end
end

function JokerCard:getWidth()
    return self.width
end

function JokerCard:getHeight()
    return self.height
end

return JokerCard
