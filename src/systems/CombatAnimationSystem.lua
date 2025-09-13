-- src/systems/CombatAnimationSystem.lua
-- Sistema de animação de combate estilo Balatro

local FontManager = require("src.ui.FontManager")
local Config = require("src.core.Config")

local CombatAnimationSystem = {}
CombatAnimationSystem.__index = CombatAnimationSystem

function CombatAnimationSystem:new()
    local instance = setmetatable({}, CombatAnimationSystem)
    
    -- Estado da animação
    instance.isActive = false
    instance.currentPhase = "idle" -- idle, cards_flying, processing, damage_dealing, complete
    instance.animationTime = 0
    instance.totalDuration = 0
    
    -- Cartas sendo animadas
    instance.animatingCards = {}
    instance.currentCardIndex = 1
    
    -- Posições na tela
    instance.centerX = 0
    instance.centerY = 0
    instance.cardSpacing = 150
    
    -- Callbacks
    instance.onComplete = nil
    instance.onCardProcessed = nil
    
    -- Efeitos visuais
    instance.damageNumbers = {}
    instance.effectTexts = {}
    
    -- Configurações de timing
    instance.timings = {
        cardFly = 0.6,        -- Tempo para carta voar para centro
        cardProcess = 0.8,    -- Tempo para processar cada carta (reduzido)
        damageShow = 0.6,     -- Tempo mostrando dano (reduzido)
        cardInterval = 0.2    -- Intervalo entre cartas (reduzido)
    }
    
    -- Cache de áudio para performance
    instance.audioCache = {}
    instance:loadAudioFiles()
    

    
    return instance
end

function CombatAnimationSystem:loadAudioFiles()
    -- Usa o sistema de áudio global se disponível
    if _G.audioSystem and _G.audioSystem:isAudioAvailable() then
        print("[CombatAnimation] Usando sistema de áudio global")
        return
    end
    
    -- Fallback: carrega arquivos de áudio com tratamento de erro
    local audioFiles = {
        cardSelect = "audio/clickselect2-92097.mp3",
        swordSound = "audio/sword-sound-260274.mp3",
        armorSound = "audio/punching-light-armour-87442.mp3"
    }
    
    for soundName, path in pairs(audioFiles) do
        local success, sound = pcall(love.audio.newSource, path, "static")
        if success and sound then
            -- Testa se consegue definir volume (verifica se áudio funciona)
            local volumeSuccess = pcall(function() sound:setVolume(0.7) end)
            if volumeSuccess then
                self.audioCache[soundName] = sound
                print("[CombatAnimation] Áudio carregado:", soundName)
            end
        end
    end
    
    local count = 0
    for _ in pairs(self.audioCache) do count = count + 1 end
    if count > 0 then
        print("[CombatAnimation] Sistema de áudio ativo -", count, "sons carregados")
    else
        print("[CombatAnimation] Sistema sem áudio - executando silenciosamente")
    end
end

function CombatAnimationSystem:playSound(soundName)
    -- Usa o sistema de áudio global se disponível
    if _G.audioSystem and _G.audioSystem:isAudioAvailable() then
        _G.audioSystem:playSound(soundName)
        return
    end
    
    -- Fallback para sistema local
    local sound = self.audioCache[soundName]
    if sound then
        -- Tenta tocar com proteção para WSL2/sistemas sem áudio
        pcall(function()
            sound:stop()
            sound:play()
        end)
    end
end

function CombatAnimationSystem:getAvailableSounds()
    local sounds = {}
    for name, _ in pairs(self.audioCache) do
        table.insert(sounds, name)
    end
    return sounds
end

function CombatAnimationSystem:startCombat(selectedCards, onComplete, onCardProcessed)
    if self.isActive then return end
    
    self.isActive = true
    self.currentPhase = "cards_flying"
    self.animationTime = 0
    self.currentCardIndex = 1
    self.onComplete = onComplete
    self.onCardProcessed = onCardProcessed
    
    -- Calcula posições da tela
    self.centerX = love.graphics.getWidth() / 2
    self.centerY = love.graphics.getHeight() / 2
    
    -- Prepara cartas para animação
    self.animatingCards = {}
    for i, card in ipairs(selectedCards) do
        local animCard = self:createAnimatingCard(card, i)
        table.insert(self.animatingCards, animCard)
    end
    
    -- Limpa efeitos anteriores
    self.damageNumbers = {}
    self.effectTexts = {}
    
    print("[CombatAnimation] Iniciando combate com", #selectedCards, "cartas")
end

function CombatAnimationSystem:createAnimatingCard(card, index)
    return {
        card = card,
        index = index,
        
        -- Posição inicial (posição atual da carta na mão)
        startX = card.x or 0,
        startY = card.y or 0,
        
        -- Posição alvo (centro da tela com espaçamento, mais à esquerda)
        targetX = self.centerX + (index - (#self.animatingCards + 1) / 2) * self.cardSpacing - 100,
        targetY = self.centerY - 50,
        
        -- Posição atual
        currentX = card.x or 0,
        currentY = card.y or 0,
        
        -- Escala e rotação
        scale = card.currentScale or 1,
        targetScale = card.currentScale or 1, -- Mantém escala original
        rotation = 0,
        targetRotation = (love.math.random() - 0.5) * 0.1, -- Rotação mais sutil
        
        -- Estados de animação
        flyProgress = 0,
        isProcessing = false,
        isProcessed = false,
        
        -- Timing
        flyStartTime = (index - 1) * self.timings.cardInterval,
        processStartTime = 0,
        
        -- Efeitos visuais
        glowIntensity = 0,
        pulseTime = 0,
        alpha = 1, -- Controle de transparência
        
        -- Audio
        soundPlayed = false -- Flag para evitar tocar som múltiplas vezes
    }
end

function CombatAnimationSystem:update(dt)
    if not self.isActive then return end
    
    self.animationTime = self.animationTime + dt
    
    if self.currentPhase == "cards_flying" then
        self:updateCardFlying(dt)
    elseif self.currentPhase == "processing" then
        self:updateCardProcessing(dt)
    elseif self.currentPhase == "damage_dealing" then
        self:updateDamageDealing(dt)
    elseif self.currentPhase == "complete" then
        self:updateComplete(dt)
    end
    
    -- Atualiza efeitos visuais
    self:updateVisualEffects(dt)
end

function CombatAnimationSystem:updateCardFlying(dt)
    local allCardsReached = true
    
    for _, animCard in ipairs(self.animatingCards) do
        -- Verifica se é hora desta carta começar a voar
        if self.animationTime >= animCard.flyStartTime then
            -- Calcula progresso do voo
            local flyTime = self.animationTime - animCard.flyStartTime
            local oldProgress = animCard.flyProgress
            animCard.flyProgress = math.min(1, flyTime / self.timings.cardFly)
            
            -- Toca som quando carta chega ao centro (progresso próximo de 1.0)
            if oldProgress < 0.95 and animCard.flyProgress >= 0.95 and not animCard.soundPlayed then
                self:playSound("cardSelect")
                animCard.soundPlayed = true
            end
            
            -- Animação com easing suave
            local progress = self:easeOutQuart(animCard.flyProgress)
            
            -- Atualiza posição
            animCard.currentX = animCard.startX + (animCard.targetX - animCard.startX) * progress
            animCard.currentY = animCard.startY + (animCard.targetY - animCard.startY) * progress
            
            -- Atualiza rotação (mantém escala original)
            animCard.scale = animCard.card.currentScale or 1 -- Sempre mantém escala original
            animCard.rotation = animCard.targetRotation * progress
            
            -- Glow aumenta conforme chega ao centro
            animCard.glowIntensity = progress * 0.5
        end
        
        if animCard.flyProgress < 1 then
            allCardsReached = false
        end
    end
    
    -- Todas as cartas chegaram ao centro?
    if allCardsReached then
        self.currentPhase = "processing"
        self.animationTime = 0
        print("[CombatAnimation] Todas as cartas chegaram, iniciando processamento")
    end
end

function CombatAnimationSystem:updateCardProcessing(dt)
    if self.currentCardIndex > #self.animatingCards then
        self.currentPhase = "damage_dealing"
        self.animationTime = 0
        return
    end
    
    local currentCard = self.animatingCards[self.currentCardIndex]
    
    if not currentCard.isProcessing then
        -- Inicia processamento desta carta
        currentCard.isProcessing = true
        currentCard.processStartTime = self.animationTime
        currentCard.pulseTime = 0
        
        print("[CombatAnimation] Processando carta", self.currentCardIndex, ":", currentCard.card.name)
    end
    
    -- Atualiza efeitos da carta sendo processada
    currentCard.pulseTime = currentCard.pulseTime + dt * 4
    currentCard.glowIntensity = 0.8 + math.sin(currentCard.pulseTime) * 0.3
    
    -- Tempo de processamento da carta atual
    local processTime = self.animationTime - currentCard.processStartTime
    
    if processTime >= self.timings.cardProcess and not currentCard.isProcessed then
        -- Processa a carta
        self:processCard(currentCard)
        currentCard.isProcessed = true
        
        -- Avança para próxima carta imediatamente
        self.currentCardIndex = self.currentCardIndex + 1
    end
end

function CombatAnimationSystem:processCard(animCard)
    local card = animCard.card
    
    -- Toca som baseado no tipo da carta
    if card.type == "attack" then
        self:playSound("swordSound")
    elseif card.type == "defense" then
        self:playSound("armorSound")
    end
    
    -- Chama callback para processar carta no jogo
    if self.onCardProcessed then
        local result = self.onCardProcessed(card)
        
        -- Cria efeitos visuais baseados no resultado
        if result.damage and result.damage > 0 then
            self:createDamageNumber(result.damage, animCard.currentX, animCard.currentY - 60, {1, 0.3, 0.3})
            self:createEffectText(card.name, animCard.currentX, animCard.currentY + 80, {1, 1, 0.8})
        end
        
        if result.defense and result.defense > 0 then
            self:createDamageNumber("+" .. result.defense, animCard.currentX, animCard.currentY - 60, {0.3, 0.7, 1})
            self:createEffectText("Bloqueio", animCard.currentX, animCard.currentY + 80, {0.7, 0.9, 1})
        end
    end
    
    print("[CombatAnimation] Carta processada:", card.name, "| Tipo:", card.type)
end

function CombatAnimationSystem:updateDamageDealing(dt)
    -- Fase onde mostra números de dano acumulado
    if self.animationTime >= self.timings.damageShow then
        self.currentPhase = "complete"
        self.animationTime = 0
    end
end

function CombatAnimationSystem:updateComplete(dt)
    -- Animação de conclusão - cartas saem da tela
    local fadeTime = 0.5
    local fadeProgress = math.min(1, self.animationTime / fadeTime)
    
    for _, animCard in ipairs(self.animatingCards) do
        -- Mantém escala original, apenas aumenta rotação e diminui alpha
        animCard.scale = animCard.card.currentScale or 1
        animCard.rotation = animCard.targetRotation + fadeProgress * math.pi * 0.5 -- Rotação mais suave
        animCard.alpha = 1 - fadeProgress -- Adiciona controle de alpha
    end
    
    if fadeProgress >= 1 then
        self:endCombat()
    end
end

function CombatAnimationSystem:updateVisualEffects(dt)
    -- Atualiza números de dano
    for i = #self.damageNumbers, 1, -1 do
        local dmg = self.damageNumbers[i]
        dmg.life = dmg.life - dt
        dmg.y = dmg.y - 60 * dt
        dmg.alpha = math.max(0, dmg.life / dmg.maxLife)
        
        if dmg.life <= 0 then
            table.remove(self.damageNumbers, i)
        end
    end
    
    -- Atualiza textos de efeito
    for i = #self.effectTexts, 1, -1 do
        local txt = self.effectTexts[i]
        txt.life = txt.life - dt
        txt.y = txt.y + 30 * dt
        txt.alpha = math.max(0, txt.life / txt.maxLife)
        
        if txt.life <= 0 then
            table.remove(self.effectTexts, i)
        end
    end
end

function CombatAnimationSystem:createDamageNumber(damage, x, y, color)
    table.insert(self.damageNumbers, {
        text = tostring(damage),
        x = x,
        y = y,
        color = color,
        alpha = 1,
        life = 1.5,
        maxLife = 1.5,
        scale = 1.2
    })
end

function CombatAnimationSystem:createEffectText(text, x, y, color)
    table.insert(self.effectTexts, {
        text = text,
        x = x,
        y = y,
        color = color,
        alpha = 1,
        life = 1.2,
        maxLife = 1.2,
        scale = 0.8
    })
end

function CombatAnimationSystem:draw()
    if not self.isActive then return end
    
    -- Salva estado dos gráficos
    local oldR, oldG, oldB, oldA = love.graphics.getColor()
    
    -- Fundo escurecido
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    -- Desenha cartas animadas
    for _, animCard in ipairs(self.animatingCards) do
        self:drawAnimatingCard(animCard)
    end
    
    -- Desenha efeitos visuais
    self:drawVisualEffects()
    
    -- Restaura estado
    love.graphics.setColor(oldR, oldG, oldB, oldA)
end

function CombatAnimationSystem:drawAnimatingCard(animCard)
    local card = animCard.card
    local alpha = animCard.alpha or 1
    
    -- Não desenha cartas que já foram processadas
    if animCard.isProcessed then
        return
    end
    
    -- Salva transformações
    love.graphics.push()
    love.graphics.translate(animCard.currentX, animCard.currentY)
    love.graphics.rotate(animCard.rotation)
    love.graphics.scale(animCard.scale, animCard.scale)
    
    -- Carta principal
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.draw(card.image, -card.image:getWidth()/2, -card.image:getHeight()/2)
    
    -- Efeito de processamento (pulso amarelo sutil)
    if animCard.isProcessing and not animCard.isProcessed then
        love.graphics.setColor(1, 1, 0.5, (0.2 + math.sin(animCard.pulseTime) * 0.1) * alpha)
        love.graphics.draw(card.image, -card.image:getWidth()/2, -card.image:getHeight()/2)
    end
    
    love.graphics.pop()
end

function CombatAnimationSystem:drawVisualEffects()
    -- Desenha números de dano
    local damageFont = FontManager.getResponsiveFont(0.04, 32, "height")
    love.graphics.setFont(damageFont)
    
    for _, dmg in ipairs(self.damageNumbers) do
        love.graphics.setColor(dmg.color[1], dmg.color[2], dmg.color[3], dmg.alpha)
        local text = dmg.text
        local width = damageFont:getWidth(text)
        love.graphics.print(text, dmg.x - width/2, dmg.y)
    end
    
    -- Desenha textos de efeito
    local effectFont = FontManager.getResponsiveFont(0.025, 20, "height")
    love.graphics.setFont(effectFont)
    
    for _, txt in ipairs(self.effectTexts) do
        love.graphics.setColor(txt.color[1], txt.color[2], txt.color[3], txt.alpha)
        local width = effectFont:getWidth(txt.text)
        love.graphics.print(txt.text, txt.x - width/2, txt.y)
    end
end

function CombatAnimationSystem:endCombat()
    self.isActive = false
    self.currentPhase = "idle"
    self.animatingCards = {}
    self.damageNumbers = {}
    self.effectTexts = {}
    
    print("[CombatAnimation] Combate finalizado")
    
    if self.onComplete then
        self.onComplete()
    end
end

function CombatAnimationSystem:easeOutQuart(t)
    return 1 - math.pow(1 - t, 4)
end

function CombatAnimationSystem:isAnimating()
    return self.isActive
end

function CombatAnimationSystem:isBlocking()
    -- Retorna true se está em uma animação que deve bloquear mudanças de estado do jogo
    return self.isActive
end

return CombatAnimationSystem
