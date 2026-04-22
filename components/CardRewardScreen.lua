-- components/CardRewardScreen.lua
-- Tela de recompensas de cartas após vitória em batalha

local CardRewardScreen = {}
CardRewardScreen.__index = CardRewardScreen

local Config = require("src.core.Config")
local FontManager = require("src.ui.FontManager")
local Theme = require("src.ui.Theme")
local Palette = require("src.ui.Palette")
local PixelCanvas = require("src.ui.PixelCanvas")
local SceneBackground = require("src.ui.SceneBackground")
local Button = require("components.Button")
local CardDatabase = require("src.systems.CardDatabase")
local CardInfoDisplay = require("src.ui.CardInfoDisplay")
local ShopSystem = require("src.systems.ShopSystem")
local I18n = require("src.i18n.I18n")
local Sfx = require("src.systems.Sfx")

function CardRewardScreen:new()
    local instance = setmetatable({}, CardRewardScreen)
    
    instance.visible = false
    instance.shopOffers = {} -- As ofertas da loja
    instance.cardInstances = {} -- Instâncias reais de Card
    instance.cardButtons = {} -- Botões das cartas
    instance.skipButton = nil
    instance.refreshButton = nil
    instance.onCardPurchased = nil -- Callback quando carta é comprada
    instance.onSkipped = nil -- Callback quando pula recompensa
    
    -- Sistema de confirmação de compra
    instance.selectedOffer = nil -- Oferta selecionada para compra
    instance.showConfirmation = false -- Se está mostrando confirmação
    instance.confirmButton = nil -- Botão de confirmação
    instance.cancelButton = nil -- Botão de cancelar
    instance.hoveredOffer = nil -- Oferta em hover
    
    -- Sistema de loja
    instance.shopSystem = ShopSystem:new()
    
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

function CardRewardScreen:show(game, onCardPurchased, onSkipped)
    self.visible = true
    self.game = game
    self.onCardPurchased = onCardPurchased
    self.onSkipped = onSkipped
    self.animationTime = 0
    
    -- Gera ofertas da loja
    self.shopSystem:generateOffers()
    self.shopOffers = self.shopSystem:getCurrentOffers()
    
    -- Debug: verificar ofertas da loja
    print("[CardRewardScreen] Showing shop with", #self.shopOffers, "offers")
    for i, offer in ipairs(self.shopOffers) do
        print("  Offer", i, ":", offer.name, "($" .. offer.cost .. ")")
    end
    
    -- Recalcula layout para tela atual
    self:updateLayout()
    
    -- Cria instâncias reais de Card apenas para cartas
    self:createCardInstances()
    
    -- Cria botões para as ofertas
    self:createOfferButtons()
    
    -- Cria botão de pular
    self.skipButton = Button:new(
        self.skipButtonX, self.skipButtonY, 160, 40,
        I18n.t("reward.continue"),
        function()
            self:hide()
            if self.onSkipped then
                self.onSkipped()
            end
        end, nil, 12
    )
    self.skipButton:setIcon("arrow_right")

    -- Cria botão de refresh
    local refreshCost = self.shopSystem:getRefreshCost()
    print("[CardRewardScreen] Creating refresh button at:", self.skipButtonX + 180, self.skipButtonY, "cost:", refreshCost)
    self.refreshButton = Button:new(
        self.skipButtonX + 180, self.skipButtonY, 180, 40,
        I18n.t("reward.refresh", { n = refreshCost }),
        function()
            local currentRefreshCost = self.shopSystem:getRefreshCost()
            print("[CardRewardScreen] Refresh clicked! Cost:", currentRefreshCost, "Can afford:", self.game.economySystem:canAfford(currentRefreshCost))
            
            if self.game.economySystem:canAfford(currentRefreshCost) then
                self.game.economySystem:spendGold(currentRefreshCost, "refresh", "shop")
                Sfx.play("purchaseDeny")
                self.shopSystem:refreshOffers()
                self.shopOffers = self.shopSystem:getCurrentOffers()
                
                -- Recria instâncias de cartas e botões
                self:createCardInstances()
                self:createOfferButtons()
                
                -- Reinicia animações
                self.cardAnimations = {}
                for i = 1, #self.shopOffers do
                    self.cardAnimations[i] = {
                        scale = 0,
                        targetScale = 1,
                        delay = (i - 1) * 0.1,
                        elapsed = 0
                    }
                end
                
                -- Atualiza texto do botão
                local newCost = self.shopSystem:getRefreshCost()
                self.refreshButton.text = I18n.t("reward.refresh", { n = newCost })

                self.game:addMessage(I18n.t("reward.shop_refreshed"), "info")
            else
                self.game:addMessage(I18n.t("reward.refresh_fail"), "error")
            end
        end
    )
    
    -- Inicializa animações das cartas
    for i = 1, #self.shopOffers do
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
    
    local availableOffers = {}
    local availablePositions = {}
    
    -- Coleta ofertas de cartas disponíveis e suas posições
    for i, offer in ipairs(self.shopOffers) do
        if offer.type == "card" and not offer.purchased and i <= 3 then
            table.insert(availableOffers, offer)
            table.insert(availablePositions, self.cardPositions[i] or {x = 0, y = 0})
        end
    end
    
    -- Cria instâncias de cartas para ofertas disponíveis
    for i, offer in ipairs(availableOffers) do
        -- Busca dados completos da carta primeiro
        local cardData = self.cardDatabase:getCard(offer.id)
        if not cardData then
            print("[CardRewardScreen] ERROR: Card data not found for", offer.id)
            goto continue
        end
        
        -- Cria instância real de Card usando o CardDatabase
        local cardInstance = self.cardDatabase:createCardInstance(cardData)
        
        if cardInstance then
            -- Configura a carta para a tela de rewards
            local pos = availablePositions[i]
            cardInstance.x = pos.x
            cardInstance.y = pos.y
            
            -- Usa a mesma escala das cartas da mão
            cardInstance.baseScale = Config.Cards.BASE_SCALE
            cardInstance.currentScale = Config.Cards.BASE_SCALE
            cardInstance.targetScale = Config.Cards.HOVER_SCALE
            
            -- Adiciona informações de raridade para a borda
            cardInstance.rarity = offer.rarity
            cardInstance.rarityBorderTime = 0
            
            -- Garante que a descrição está definida
            if not cardInstance.description and offer.description then
                cardInstance.description = offer.description
            end
            
            -- Remove a marcação de reward para comportamento normal das cartas
            cardInstance.isRewardCard = false
            
            -- Armazena referência da oferta para facilitar compra
            cardInstance.shopOffer = offer
            
            -- Configura o CardInfoDisplay para mostrar raridade (específico para recompensas)
            if cardInstance.cardInfoDisplay then
                cardInstance.cardInfoDisplay:configure({
                    showRarity = true,
                    showStats = true,
                    showDescription = true
                })
            end
            
            table.insert(self.cardInstances, cardInstance)
            print("[CardRewardScreen] Created card instance", i, "for", offer.name, "rarity:", offer.rarity)
        else
            print("[CardRewardScreen] ERROR: Could not create card instance for", offer.id)
        end
        ::continue::
    end
end

function CardRewardScreen:createOfferButtons()
    self.cardButtons = {}
    
    local availableOffers = {}
    local availablePositions = {}
    
    print("[CardRewardScreen] Creating buttons - Total offers:", #self.shopOffers)
    
    -- Coleta ofertas disponíveis e suas posições
    for i, offer in ipairs(self.shopOffers) do
        print("  Offer", i, ":", offer.name, "purchased:", offer.purchased, "type:", offer.type)
        if not offer.purchased and i <= 3 then
            table.insert(availableOffers, offer)
            table.insert(availablePositions, self.cardPositions[i] or {x = 0, y = 0})
            print("    -> Added to available offers at position", i)
        end
    end
    
    print("[CardRewardScreen] Available offers count:", #availableOffers)
    
    -- Cria botões para ofertas disponíveis
    for i, offer in ipairs(availableOffers) do
        local pos = availablePositions[i]
        
        -- Botão invisível sobre a oferta para capturar cliques
        local button = Button:new(
            pos.x, pos.y, self.cardWidth, self.cardHeight,
            "",
            function()
                print("[CardRewardScreen] Offer", i, "clicked:", offer.name)
                self:showPurchaseConfirmation(offer)
            end
        )
        button:setVariant("invisible")

        table.insert(self.cardButtons, button)
        print("[CardRewardScreen] Created button", i, "for", offer.name, "at", pos.x, pos.y, "size", self.cardWidth, self.cardHeight)
    end
    
    print("[CardRewardScreen] Total buttons created:", #self.cardButtons)
end

function CardRewardScreen:purchaseOffer(offer, offerId)
    print("[CardRewardScreen] Purchasing offer:", offer.name, "($" .. offer.cost .. ")")
    
    -- Verifica se tem ouro suficiente
    if not self.game.economySystem:canAfford(offer.cost) then
        self.game:addMessage(I18n.t("reward.insufficient_gold"), "error")
        return
    end

    -- Gasta o ouro
    if self.game.economySystem:spendGold(offer.cost, offer.type, offer.id) then
        local offerName = offer.type == "card" and I18n.cardName({ id = offer.id, name = offer.name }) or offer.name
        if offer.type == "card" then
            -- Feedback visual: carta dissolve pra indicar "absorvida no deck".
            -- Palette "booster" = roxo/magenta, diferente do exhaust vermelho.
            if offer.cardInstance and offer.cardInstance.start_dissolve then
                local DissolveShader = require("src.ui.DissolveShader")
                offer.cardInstance:start_dissolve(
                    DissolveShader.palette("booster"),
                    true,  -- silent (purchaseConfirm sfx já toca)
                    0.8,   -- timeFac
                    true   -- noJuice
                )
            end
            -- Adiciona carta ao deck
            self.game:addCardToRun(offer.id)
            self.game:addMessage(I18n.t("reward.bought", { name = offerName }), "success")
        elseif offer.type == "upgrade" then
            -- Aplica upgrade
            self:applyUpgrade(offer)
            self.game:addMessage(I18n.t("reward.bought", { name = offerName }), "success")
        end
        Sfx.play("purchaseConfirm")
        
        -- Marca a oferta como comprada (não remove da lista)
        offer.purchased = true
        
        -- Recria instâncias de cartas e botões
        self:createCardInstances()
        self:createOfferButtons()
        
        if self.onCardPurchased then
            self.onCardPurchased(offer)
        end
    end
end

function CardRewardScreen:showPurchaseConfirmation(offer)
    if self.showConfirmation then return end -- Já tem uma confirmação aberta
    
    self.selectedOffer = offer
    self.showConfirmation = true
    
    -- Cria botões de confirmação
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    -- Posição do modal de confirmação
    local modalWidth = 400
    local modalHeight = 200
    local modalX = (screenWidth - modalWidth) / 2
    local modalY = (screenHeight - modalHeight) / 2
    
    -- Botão de confirmar
    self.confirmButton = Button:new(
        modalX + modalWidth / 2 - 160, modalY + modalHeight - 60, 150, 40,
        I18n.t("reward.buy", { n = offer.cost }),
        function()
            self:confirmPurchase()
        end, nil, 10
    )
    self.confirmButton:setIcon("check")

    -- Se não pode pagar, desabilita visualmente o confirmar
    local canAfford = self.game and self.game.economySystem:canAfford(offer.cost)
    if not canAfford then
        self.confirmButton:setEnabled(false)
    end

    -- Botão de cancelar
    self.cancelButton = Button:new(
        modalX + modalWidth / 2 + 20, modalY + modalHeight - 60, 150, 40,
        I18n.t("reward.cancel"),
        function()
            self:cancelPurchase()
        end, nil, 12
    )
    self.cancelButton:setIcon("x_close")
end

function CardRewardScreen:confirmPurchase()
    if not self.selectedOffer then return end
    
    self:purchaseOffer(self.selectedOffer, self.selectedOffer.id)
    self:cancelPurchase() -- Fecha o modal
end

function CardRewardScreen:cancelPurchase()
    self.selectedOffer = nil
    self.showConfirmation = false
    self.confirmButton = nil
    self.cancelButton = nil
end

function CardRewardScreen:applyUpgrade(upgrade)
    if upgrade.effect == "increase_max_health" then
        self.game.player.maxHealth = self.game.player.maxHealth + upgrade.value
        self.game.player.health = self.game.player.health + upgrade.value
    elseif upgrade.effect == "increase_base_mana" then
        self.game.player.baseMaxMana = self.game.player.baseMaxMana + upgrade.value
        self.game.player.maxMana = self.game.player.maxMana + upgrade.value
        self.game.player.mana = self.game.player.mana + upgrade.value
    elseif upgrade.effect == "increase_card_draw" then
        -- Implementar sistema de cartas extras por turno
        self.game:addMessage(I18n.t("reward.extra_draw", { n = upgrade.value }), "info")
    elseif upgrade.effect == "increase_attack_damage" then
        -- Implementar bônus de dano global
        self.game:addMessage(I18n.t("reward.atk_bonus", { n = upgrade.value }), "info")
    elseif upgrade.effect == "increase_defense" then
        -- Implementar bônus de defesa global
        self.game:addMessage(I18n.t("reward.def_bonus", { n = upgrade.value }), "info")
    end
end

function CardRewardScreen:hide()
    self.visible = false
    self.shopOffers = {}
    self.cardInstances = {}
    self.cardButtons = {}
    self.skipButton = nil
    self.refreshButton = nil
    
    -- Limpa confirmação de compra
    self:cancelPurchase()
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
        if #self.shopOffers > 0 then
            self:createCardInstances()
            self:createOfferButtons()
            -- Recria botões
            if self.skipButton then
                self.skipButton.x = self.skipButtonX
                self.skipButton.y = self.skipButtonY
            end
            if self.refreshButton then
                self.refreshButton.x = self.skipButtonX + 180
                self.refreshButton.y = self.skipButtonY
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
    
    -- Atualiza instâncias de cartas (só se não há confirmação aberta)
    if not self.showConfirmation then
        for i, cardInstance in ipairs(self.cardInstances) do
            if cardInstance and cardInstance.updateMouse then
                local mx, my = love.mouse.getPosition()
                
                -- Usa o sistema natural de hover das cartas (igual às cartas na mão)
                cardInstance:updateMouse(mx, my, dt, true)
                
                -- Atualiza animação da borda de raridade
                if cardInstance.rarityBorderTime then
                    cardInstance.rarityBorderTime = cardInstance.rarityBorderTime + dt * Config.Cards.RARITY_BORDER_ANIMATION_SPEED
                end
            end
        end
    end
    
    -- Atualiza botões (só se não há confirmação aberta)
    if not self.showConfirmation then
        for _, button in ipairs(self.cardButtons) do
            button:update(dt)
        end
    end
    
    if self.skipButton then
        self.skipButton:update(dt)
    end
    
    if self.refreshButton then
        self.refreshButton:update(dt)
    end
    
    -- Atualiza botões de confirmação
    if self.confirmButton then
        self.confirmButton:update(dt)
    end
    
    if self.cancelButton then
        self.cancelButton:update(dt)
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

    local w, h = love.graphics.getDimensions()
    -- Fundo: cena altar de recompensas + overlay escuro denso (é overlay modal)
    if not SceneBackground.draw("cardReward", w, h, 0.65) then
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", 0, 0, w, h)
    end
    
    -- Título da loja
    self:drawTitle()
    
    -- Desenha as instâncias de cartas (igual ao sistema original)
    for i, cardInstance in ipairs(self.cardInstances) do
        if cardInstance and cardInstance.draw then
            local anim = self.cardAnimations[i]
            local scale = anim and anim.scale or 1
            
            if scale > 0 then
                -- Usa a posição armazenada na própria carta
                local pos = {x = cardInstance.x, y = cardInstance.y}
                
                -- Desenha borda de raridade antes da carta (só quando não está em hover)
                if not cardInstance.isHovered then
                    self:drawRarityBorder(cardInstance, pos.x, pos.y)
                end
                
                -- Desenha a carta com o mesmo comportamento das cartas na mão
                -- O CardInfoDisplay será renderizado automaticamente pela carta
                cardInstance:draw(pos.x, pos.y, false, false)
                
                -- Desenha overlay de preço sobre a carta
                self:drawPriceOverlay(cardInstance, pos.x, pos.y, i)
            end
        end
    end
    
    -- Desenha ofertas que não são cartas (upgrades)
    for i, offer in ipairs(self.shopOffers) do
        if offer.type ~= "card" and i <= 3 and not offer.purchased then
            local anim = self.cardAnimations[i]
            local scale = anim and anim.scale or 1
            
            if scale > 0 then
                local pos = self.cardPositions[i] or {x = 0, y = 0}
                self:drawOffer(offer, pos.x, pos.y, i)
            end
        end
    end
    
    -- Botões
    if self.skipButton then
        self.skipButton:draw()
    end
    
    if self.refreshButton then
        self.refreshButton:draw()
    end
    
    -- Instruções
    self:drawInstructions()
    
    -- Modal de confirmação de compra
    if self.showConfirmation then
        self:drawPurchaseConfirmation()
    end
end

function CardRewardScreen:drawTitle()
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()

    local titleFont = FontManager.getFont(16)
    love.graphics.setFont(titleFont)

    local title = I18n.t("reward.shop_title")
    local titleWidth = titleFont:getWidth(title)
    local titleX = math.floor((screenWidth - titleWidth) / 2)
    local titleY = math.floor(screenHeight * 0.1)

    -- Banner pixel do título
    local padX, padY = 20, 8
    local bx, by = titleX - padX, titleY - padY
    local bw, bh = titleWidth + padX * 2, titleFont:getHeight() + padY * 2
    PixelCanvas.rect(bx, by, bw, bh, Palette.PANEL_FILL)
    PixelCanvas.rectOutline(bx, by, bw, bh, Palette.PANEL_OUTLINE)
    PixelCanvas.rectOutline(bx + 2, by + 2, bw - 4, bh - 4, Palette.PANEL_OUTLINE_INNER)

    Palette.set(Palette.AGED_GOLD_LIGHT)
    love.graphics.print(title, titleX, titleY)

    -- Ouro atual
    if self.game and self.game.economySystem then
        local goldText = I18n.t("reward.gold_label", { n = self.game.economySystem.currentGold })
        local goldFont = FontManager.getFont(10)
        love.graphics.setFont(goldFont)
        local goldWidth = goldFont:getWidth(goldText)
        Palette.set(Palette.PARCHMENT_LIGHT)
        love.graphics.print(goldText,
            math.floor((screenWidth - goldWidth) / 2),
            titleY + bh)
    end
end

function CardRewardScreen:drawOffer(offer, x, y, index)
    local canAfford = self.game and self.game.economySystem:canAfford(offer.cost)
    local w, h = self.cardWidth, self.cardHeight

    -- Fundo pixel (sem cantos arredondados)
    PixelCanvas.rect(math.floor(x), math.floor(y), math.floor(w), math.floor(h), Palette.PANEL_FILL)
    PixelCanvas.rectOutline(math.floor(x), math.floor(y), math.floor(w), math.floor(h),
        canAfford and Palette.AGED_GOLD or Palette.BLOOD)

    -- Nome (cards traduzidos via I18n; upgrades mantêm o nome literal da oferta)
    local displayName = offer.type == "card" and I18n.cardName({ id = offer.id, name = offer.name }) or offer.name
    local displayDesc = offer.type == "card" and I18n.cardDesc({ id = offer.id, description = offer.description }) or offer.description
    Palette.set(Palette.PARCHMENT_LIGHT)
    love.graphics.setFont(FontManager.getFont(10))
    love.graphics.printf(displayName, x + 8, y + 12, w - 16, "center")

    -- Descrição
    Palette.set(Palette.PARCHMENT)
    love.graphics.setFont(FontManager.getFont(8))
    love.graphics.printf(displayDesc, x + 8, y + 36, w - 16, "center")

    -- Preço
    Palette.set(canAfford and Palette.AGED_GOLD_LIGHT or Palette.BLOOD)
    love.graphics.setFont(FontManager.getFont(10))
    love.graphics.printf("$" .. offer.cost, x + 8, y + h - 24, w - 16, "center")

    -- Faixa de raridade no topo
    if offer.type == "card" and offer.rarity then
        Palette.set(Palette.forRarity(offer.rarity))
        love.graphics.rectangle("fill", math.floor(x + 6), math.floor(y + 4), math.floor(w - 12), 3)
    end
end

function CardRewardScreen:drawPriceOverlay(cardInstance, x, y, index)
    local offer = cardInstance.shopOffer
    if not offer or offer.purchased then return end

    local canAfford = self.game and self.game.economySystem:canAfford(offer.cost)
    local w = math.floor(self.cardWidth) - 10
    local bx, by = math.floor(x + 5), math.floor(y + self.cardHeight - 255)

    PixelCanvas.rect(bx, by, w, 20, Palette.PANEL_FILL)
    PixelCanvas.rectOutline(bx, by, w, 20, canAfford and Palette.AGED_GOLD or Palette.BLOOD)

    Palette.set(canAfford and Palette.AGED_GOLD_LIGHT or Palette.BLOOD)
    love.graphics.setFont(FontManager.getFont(10))
    love.graphics.printf("$" .. offer.cost, bx, by + 5, w, "center")
end

function CardRewardScreen:drawPurchaseConfirmation()
    if not self.selectedOffer then return end

    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()

    -- Overlay escuro global
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)

    local modalW, modalH = 420, 220
    local modalX = math.floor((screenWidth - modalW) / 2)
    local modalY = math.floor((screenHeight - modalH) / 2)
    local canAfford = self.game and self.game.economySystem:canAfford(self.selectedOffer.cost)

    -- Modal pixel: ink fill + dual outline
    PixelCanvas.rect(modalX, modalY, modalW, modalH, Palette.PANEL_FILL)
    PixelCanvas.rectOutline(modalX, modalY, modalW, modalH,
        canAfford and Palette.AGED_GOLD or Palette.BLOOD)
    PixelCanvas.rectOutline(modalX + 2, modalY + 2, modalW - 4, modalH - 4, Palette.AGED_GOLD_DARK)

    -- Título
    Palette.set(Palette.AGED_GOLD_LIGHT)
    love.graphics.setFont(FontManager.getFont(14))
    love.graphics.printf(I18n.t("reward.confirm_title"), modalX, modalY + 20, modalW, "center")

    Palette.set(Palette.PARCHMENT_LIGHT)
    love.graphics.setFont(FontManager.getFont(12))
    local confName = self.selectedOffer.type == "card"
        and I18n.cardName({ id = self.selectedOffer.id, name = self.selectedOffer.name })
        or self.selectedOffer.name
    love.graphics.printf(confName, modalX, modalY + 54, modalW, "center")

    -- Preço
    Palette.set(canAfford and Palette.AGED_GOLD_LIGHT or Palette.BLOOD)
    love.graphics.setFont(FontManager.getFont(16))
    love.graphics.printf("$" .. self.selectedOffer.cost, modalX, modalY + 84, modalW, "center")

    -- Status
    love.graphics.setFont(FontManager.getFont(8))
    if not canAfford then
        Palette.set(Palette.BLOOD)
        love.graphics.printf(I18n.t("reward.insufficient_gold"), modalX, modalY + 120, modalW, "center")
    else
        Palette.set(Palette.PARCHMENT)
        local currentGold = self.game.economySystem.currentGold
        local remaining = currentGold - self.selectedOffer.cost
        love.graphics.printf(I18n.t("reward.gold_transition", { from = currentGold, to = remaining }),
            modalX, modalY + 120, modalW, "center")
    end

    if self.confirmButton then self.confirmButton:draw() end
    if self.cancelButton  then self.cancelButton:draw()  end

    love.graphics.setColor(1, 1, 1, 1)
end

function CardRewardScreen:drawInstructions()
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    local instructionFont = FontManager.getFont(14)
    love.graphics.setFont(instructionFont)
    
    local instructions = I18n.t("reward.instructions")
    local instructionWidth = instructionFont:getWidth(instructions)
    local instructionX = (screenWidth - instructionWidth) / 2
    local instructionY = screenHeight - 40
    
    -- Fundo das instruções
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", instructionX - 10, instructionY - 5, instructionWidth + 20, 20, 5)
    
    -- Instruções
    love.graphics.setColor(0.8, 0.8, 0.8, 1)
    love.graphics.print(instructions, instructionX, instructionY)
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
    
    -- Propaga para botões das cartas (só se não há confirmação aberta)
    if not self.showConfirmation then
        for i, cardButton in ipairs(self.cardButtons) do
            local inBounds = x >= cardButton.x and x <= cardButton.x + cardButton.width and
                            y >= cardButton.y and y <= cardButton.y + cardButton.height
            print("  Card button", i, "bounds check:", inBounds, "(", cardButton.x, cardButton.y, cardButton.width, cardButton.height, ")")
            
            if cardButton:mousepressed(x, y, button) then
                print("  Card button", i, "handled the click")
                return true
            end
        end
    end
    
    -- Botão de pular
    if self.skipButton and self.skipButton:mousepressed(x, y, button) then
        print("  Skip button handled the click")
        return true
    end
    
    -- Botão de refresh
    if self.refreshButton then
        print("  Refresh button exists, checking bounds:", self.refreshButton.x, self.refreshButton.y, self.refreshButton.width, self.refreshButton.height)
        if self.refreshButton:mousepressed(x, y, button) then
            print("  Refresh button handled the click")
            return true
        end
    else
        print("  Refresh button is nil!")
    end
    
    -- Botões de confirmação (têm prioridade)
    if self.showConfirmation then
        if self.confirmButton and self.confirmButton:mousepressed(x, y, button) then
            print("  Confirm button handled the click")
            return true
        end
        
        if self.cancelButton and self.cancelButton:mousepressed(x, y, button) then
            print("  Cancel button handled the click")
            return true
        end
        
        -- Se clicou fora do modal, cancela
        local screenWidth = love.graphics.getWidth()
        local screenHeight = love.graphics.getHeight()
        local modalWidth = 400
        local modalHeight = 200
        local modalX = (screenWidth - modalWidth) / 2
        local modalY = (screenHeight - modalHeight) / 2
        
        if x < modalX or x > modalX + modalWidth or y < modalY or y > modalY + modalHeight then
            self:cancelPurchase()
        end
        
        return true -- Consome o clique para não propagar
    end
    
    print("  No button handled the click")
    return false
end

-- Adiciona suporte a mousereleased
function CardRewardScreen:mousereleased(x, y, button)
    if not self.visible then return false end
    
    print("[CardRewardScreen] Mouse released at", x, y, "button:", button)
    
    -- Propaga para botões das cartas (só se não há confirmação aberta)
    if not self.showConfirmation then
        for i, cardButton in ipairs(self.cardButtons) do
            if cardButton:mousereleased(x, y, button) then
                print("  Card button", i, "handled the release")
                return true
            end
        end
    end
    
    -- Botão de pular
    if self.skipButton and self.skipButton:mousereleased(x, y, button) then
        print("  Skip button handled the release")
        return true
    end
    
    -- Botão de refresh
    if self.refreshButton and self.refreshButton:mousereleased(x, y, button) then
        print("  Refresh button handled the release")
        return true
    end
    
    -- Botões de confirmação
    if self.showConfirmation then
        if self.confirmButton and self.confirmButton:mousereleased(x, y, button) then
            print("  Confirm button handled the release")
            return true
        end
        
        if self.cancelButton and self.cancelButton:mousereleased(x, y, button) then
            print("  Cancel button handled the release")
            return true
        end
        
        return true -- Consome o release para não propagar
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
