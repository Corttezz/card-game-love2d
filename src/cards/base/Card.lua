local Config = require("src.core.Config")
local CardInfoDisplay = require("src.ui.CardInfoDisplay")

local Card = {}
Card.__index = Card

-- Cache de áudio para hover e seleção (evita criar a cada frame) 
local hoverSoundCache = nil
local clickSelectSoundCache = nil

function Card:new(name, cost, attack, defense, passive, type, subtype, imagePath)
    local instance = setmetatable({}, Card)
    instance.name = name
    instance.cost = cost
    instance.attack = attack
    instance.defense = defense
    instance.passive = passive or function()
    end
    instance.type = type
    instance.subtype = subtype
    
    -- Validação do caminho da imagem
    if not imagePath or imagePath == "" then
        print("WARNING: Carta '" .. (name or "unnamed") .. "' tem caminho de imagem inválido: " .. tostring(imagePath))
        -- Usa uma imagem padrão como fallback
        imagePath = "assets/cards/attack/theRock.png"
    end
    
    -- Tenta carregar a imagem com tratamento de erro
    local success, image = pcall(love.graphics.newImage, imagePath)
    if success then
        instance.image = image
    else
        print("ERROR: Não foi possível carregar imagem para carta '" .. (name or "unnamed") .. "': " .. tostring(imagePath))
        print("Erro: " .. tostring(image))
        -- Usa uma imagem padrão como fallback
        instance.image = love.graphics.newImage("assets/cards/attack/theRock.png")
    end

    -- Propriedades para hover e animação usando Config
    instance.x = 0 -- Posição X
    instance.y = 0 -- Posição Y
    instance.baseScale = Config.Cards.BASE_SCALE -- Tamanho base
    instance.targetScale = instance.baseScale -- Escala-alvo
    instance.currentScale = instance.baseScale -- Escala atual
    instance.width = instance.image:getWidth() * instance.baseScale
    instance.height = instance.image:getHeight() * instance.baseScale
    instance.isHovered = false -- Estado de hover
    
    -- Animação da borda
    instance.borderAnimationTime = 0 -- Tempo para animação da borda
    
    -- Componente para exibir informações da carta
    instance.cardInfoDisplay = CardInfoDisplay:new()
    -- Configura para cartas na mão (sem raridade por padrão)
    instance.cardInfoDisplay:configure({
        showRarity = false,
        showStats = true,
        showDescription = true
    })
    
    -- Carrega ícones para ataque, defesa e mana
    local success, attackIcon = pcall(love.graphics.newImage, "assets/icons/attack.png")
    if success then
        instance.attackIcon = attackIcon
    else
        print("ERROR: Não foi possível carregar ícone de ataque")
        instance.attackIcon = nil
    end
    
    local success, manaIcon = pcall(love.graphics.newImage, "assets/icons/mana.png")
    if success then
        instance.manaIcon = manaIcon
    else
        print("ERROR: Não foi possível carregar ícone de mana")
        instance.manaIcon = nil
    end
    
    local success, armorIcon = pcall(love.graphics.newImage, "assets/icons/armor.png")
    if success then
        instance.armorIcon = armorIcon
    else
        print("ERROR: Não foi possível carregar ícone de armadura")
        instance.armorIcon = nil
    end
    
    return instance
end

function Card:use(target)
    if self.type == "attack" then
        target:takeDamage(self.attack)
    elseif self.type == "defense" then
        target:addDefense(self.defense)
    end

    self.passive(target)
end

function Card:updateMouse(mx, my, dt, isHovered)
    -- Atualiza escala
    local scaleFactor = self.currentScale
    local cardWidth = self.image:getWidth() * scaleFactor
    local cardHeight = self.image:getHeight() * scaleFactor

    -- Calcula deslocamento vertical se estiver em hover
    local offsetY = 0
    if self.isHovered then
        -- Usa a mesma lógica de offset do draw() para consistência
        if self.isRewardCard then
            offsetY = Config.Cards.DEPTH_OFFSET -- Reward cards go UP
        else
            offsetY = -Config.Cards.DEPTH_OFFSET -- Hand cards go DOWN
        end
    end

    -- Verifica se o mouse está sobre a carta ajustada
    local wasHovered = self.isHovered
    if mx >= self.x and mx <= self.x + cardWidth and my >= (self.y + offsetY) and my <= (self.y + offsetY + cardHeight) and
        isHovered then
        self.isHovered = true
        self.targetScale = Config.Cards.HOVER_SCALE -- Aumenta o tamanho usando Config
        if not wasHovered then
            -- Usa o sistema de áudio global se disponível
            if _G.audioSystem and _G.audioSystem:isAudioAvailable() then
                _G.audioSystem:playSound("hoverCard")
            else
                -- Fallback para sistema antigo
                if not hoverSoundCache then
                    hoverSoundCache = love.audio.newSource("audio/hoverCard.wav", "static")
                    hoverSoundCache:setVolume(Config.Audio.HOVER_VOLUME)
                end
                
                -- Garante que o som seja tocado corretamente
                if hoverSoundCache then
                    -- Para o som anterior se estiver tocando
                    hoverSoundCache:stop()
                    -- Toca o som
                    hoverSoundCache:play()
                end
            end
        end

        -- *** Efeito de movimento 3D Balatro-style ***
        local mouseXRelative = (mx - self.x) / cardWidth -- Proporção X [0, 1]
        local mouseYRelative = (my - (self.y + offsetY)) / cardHeight -- Proporção Y [0, 1]
        
        -- Normaliza para [-1, 1] para efeitos mais naturais
        local normalizedX = (mouseXRelative - 0.5) * 2
        local normalizedY = (mouseYRelative - 0.5) * 2

        -- *** Efeito de profundidade baseado na posição do mouse ***
        local depthStrength = Config.Cards.PERSPECTIVE_STRENGTH
        local depthOffset = Config.Cards.DEPTH_OFFSET
        
        -- Quanto mais próximo do centro, mais "profunda" a carta fica
        local centerDistance = math.sqrt(normalizedX^2 + normalizedY^2)
        local depthMultiplier = 1 - (centerDistance * 0.3)
        
        -- Deslocamento baseado na profundidade percebida
        self.offsetHoverX = normalizedX * Config.Cards.MOVE_RANGE * depthMultiplier
        self.offsetHoverY = normalizedY * Config.Cards.MOVE_RANGE * depthMultiplier
        
        -- *** Efeito de rotação 3D Balatro-style ***
        local tiltRange = Config.Cards.TILT_RANGE
        local depthTiltX = Config.Cards.DEPTH_TILT_X
        local depthTiltY = Config.Cards.DEPTH_TILT_Y
        
        -- Inclinação baseada na posição do mouse + profundidade
        self.tiltX = normalizedX * tiltRange + (normalizedX * depthTiltX * depthMultiplier)
        self.tiltY = normalizedY * tiltRange + (normalizedY * depthTiltY * depthMultiplier)
        
        -- *** Efeito de elevação (carta "levanta" do fundo) ***
        local liftAmount = Config.Cards.LIFT_AMOUNT
        if self.isRewardCard then
            -- Cartas de reward sobem no hover (liftOffset negativo)
            self.liftOffset = -liftAmount * depthMultiplier
        else
            -- Cartas da mão descem no hover (liftOffset positivo)
            self.liftOffset = liftAmount * depthMultiplier
        end
        
        -- *** Sombra dinâmica baseada na profundidade ***
        local shadowOffsetBaseX = Config.Cards.SHADOW_OFFSET_BASE_X
        local shadowOffsetBaseY = Config.Cards.SHADOW_OFFSET_BASE_Y
        local shadowStretchX = Config.Cards.SHADOW_STRETCH_X
        local shadowStretchY = Config.Cards.SHADOW_STRETCH_Y
        
        -- Sombra se move conforme a profundidade da carta
        self.shadowOffsetX = shadowOffsetBaseX + (normalizedX * shadowStretchX * depthMultiplier)
        self.shadowOffsetY = shadowOffsetBaseY + (normalizedY * shadowStretchY * depthMultiplier)
        
        -- Escala da sombra varia com a profundidade
        local shadowScaleBase = Config.Cards.SHADOW_SCALE_BASE
        local shadowScaleVariation = Config.Cards.SHADOW_SCALE_VARIATION
        self.shadowScale = shadowScaleBase - (centerDistance * shadowScaleVariation)
        
        -- *** Efeito de perspectiva adicional ***
        -- A carta parece "girar" ligeiramente em 3D
        self.perspectiveRotation = normalizedX * 0.05 * depthMultiplier

    else
        self.isHovered = false
        self.targetScale = self.baseScale -- Volta ao tamanho normal

        -- Reseta os deslocamentos quando não estiver em hover
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

    -- Suaviza a transição para o tamanho alvo usando Config
    self.currentScale = self.currentScale + (self.targetScale - self.currentScale) * Config.Cards.SCALE_ANIMATION_SPEED * dt
    
    -- Atualiza animação da borda
    self.borderAnimationTime = self.borderAnimationTime + dt * Config.Cards.BORDER_ANIMATION_SPEED
end

-- Métodos para compatibilidade com o sistema de jokers
function Card:getWidth()
    return self.width or (self.image and self.image:getWidth() * (self.currentScale or self.baseScale) or 0)
end

function Card:getHeight()
    return self.height or (self.image and self.image:getHeight() * (self.currentScale or self.baseScale) or 0)
end

function Card:draw(x, y, showPlayableBorder, isRewardCard)
    -- Atualiza posição
    self.x = x
    self.y = y

    -- Calcula deslocamentos para hover com efeito 3D
    local baseOffsetY = 0
    if self.isHovered then
        if isRewardCard then
            -- Cartas de reward sobem no hover (efeito mais natural)
            baseOffsetY = Config.Cards.DEPTH_OFFSET
        else
            -- Cartas da mão descem no hover (efeito Balatro original)
            baseOffsetY = -Config.Cards.DEPTH_OFFSET
        end
    end
    local hoverOffsetY = self.liftOffset or 0
    local totalOffsetY = baseOffsetY + hoverOffsetY
    
    local offsetX = self.offsetHoverX or 0
    local offsetY = self.offsetHoverY or 0

    -- *** Aplica transformação de perspectiva 3D Balatro-style ***
    local tiltX = self.tiltX or 0
    local tiltY = self.tiltY or 0
    local perspectiveRotation = self.perspectiveRotation or 0
    
    -- Escala dinâmica baseada na inclinação
    local scaleX = self.currentScale * (1 + math.abs(tiltX) * 0.3)
    local scaleY = self.currentScale * (1 + math.abs(tiltY) * 0.3)

    -- *** Sombra Dinâmica 3D ***
    local shadowX = x + (self.shadowOffsetX or -Config.Cards.SHADOW_OFFSET_BASE_X)
    local shadowY = y + (self.shadowOffsetY or Config.Cards.SHADOW_OFFSET_BASE_Y)
    local shadowScaleX = (self.shadowScale or Config.Cards.SHADOW_SCALE_BASE) * 1.1
    local shadowScaleY = (self.shadowScale or Config.Cards.SHADOW_SCALE_BASE) * 0.9

    -- Desenha sombra com intensidade baseada na profundidade
    local shadowAlpha = Config.Cards.SHADOW_INTENSITY * (1 - (self.liftOffset or 0) / Config.Cards.LIFT_AMOUNT)
    love.graphics.setColor(0, 0, 0, shadowAlpha)
    love.graphics.draw(self.image, shadowX, shadowY, 0, scaleX * shadowScaleX, scaleY * shadowScaleY)

    -- Desenha borda azul animada ANTES da carta (para ficar atrás)
    if showPlayableBorder then
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
    end

    -- *** Carta Principal com Efeito 3D Balatro-style ***
    love.graphics.setColor(1, 1, 1, 1) -- Reseta para branco
    
    -- Aplica transformação 3D na carta
    love.graphics.push()
    
    -- Move para o centro da carta para aplicar rotação
    local cardCenterX = x + offsetX + (self.image:getWidth() * scaleX) / 2
    local cardCenterY = y + totalOffsetY + (self.image:getHeight() * scaleY) / 2
    
    love.graphics.translate(cardCenterX, cardCenterY)
    
    -- Aplica rotação de perspectiva 3D
    love.graphics.rotate(perspectiveRotation)
    
    -- Aplica inclinação 3D usando escala dinâmica
    -- Simula profundidade alterando a escala baseada na inclinação
    
    -- Desenha a carta com offset do centro
    local drawX = -((self.image:getWidth() * scaleX) / 2)
    local drawY = -((self.image:getHeight() * scaleY) / 2)
    
    -- Desenha a carta com escala dinâmica para efeito 3D
    love.graphics.draw(self.image, drawX, drawY, 0, scaleX, scaleY)
    
    -- Restaura transformações
    love.graphics.pop()

    -- Texto só aparece no hover e agora está na parte de cima
    -- Mas não desenha se for uma carta de reward (a descrição será desenhada pela CardRewardScreen)
    if self.isHovered and not isRewardCard then
        -- Define altura proporcional à escala atual
        local textOffsetY = y + totalOffsetY - 70
        
        -- Usa o componente CardInfoDisplay para desenhar as informações
        self.cardInfoDisplay:draw(self, x, textOffsetY + 20, {
            showRarity = false, -- Cartas na mão não mostram raridade
            showStats = true,
            showDescription = true  -- Agora mostra a descrição no hover
        })
    end
end

return Card
