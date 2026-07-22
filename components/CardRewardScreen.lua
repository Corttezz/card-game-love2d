-- components/CardRewardScreen.lua
-- Tela de recompensas de cartas após vitória em batalha.

local CardRewardScreen = {}
CardRewardScreen.__index = CardRewardScreen

-- FILA DEDICADA das animações desta tela (fix DEFINITIVO Jul/2026 do bug
-- "cartas invisíveis até o hover"): os helpers parallel/parallelEase são
-- blocking=false mas BLOCKABLE=true — na fila "base" eles ficavam PRESOS
-- atrás do rabo bloqueante da sequência de combate que acabou de terminar
-- (EM.after do Game/CombatSequence é blocking). A entrada das cartas só
-- rodava quando a base destravava, segundos depois. Fila própria = o combate
-- nunca trava as animações da loja/recompensa. Limpa a cada show().
local FXQ = "reward_fx"

-- ============ DEBUG (caça ao bug "cartas não renderizam") ============
-- Loga em print E em arquivo (save dir: reward_debug.log) — o arquivo é
-- sobrescrito a cada show(), então contém sempre a ÚLTIMA abertura.
-- Desligar depois: REWARD_DBG = false.
local REWARD_DBG = true
local _dbgStart = 0

local function dbg(fmt, ...)
    if not REWARD_DBG then return end
    local ok, line = pcall(string.format, fmt, ...)
    if not ok then line = fmt .. " (fmt err)" end
    local t = love.timer.getTime() - _dbgStart
    line = string.format("[RDBG %+7.2fs] %s", t, line)
    print(line)
    pcall(love.filesystem.append, "reward_debug.log", line .. "\n")
end

-- Radiografia da fila do EventManager (trigger/blocking/timer de cada evento).
-- ⚠️ require PRÓPRIO: este bloco vive ANTES dos requires do arquivo — o local
-- `EventManager` de baixo não está em escopo aqui (upvalue só existe abaixo
-- da declaração; o global não existe nos tools).
local function dbgQueue(name)
    if not REWARD_DBG then return end
    local okEM, EM = pcall(require, "engine.EventManager")
    if not okEM or not EM then dbg("dbgQueue: sem EventManager"); return end
    local q = EM.queues and EM.queues[name]
    if not q then dbg("queue '%s': (inexistente)", name); return end
    dbg("queue '%s': %d eventos | EM.paused=%s", name, #q, tostring(EM.paused))
    for i, ev in ipairs(q) do
        dbg("   [%d] trig=%s blocking=%s blockable=%s timer=%.2f delay=%.2f done=%s%s",
            i, tostring(ev.trigger), tostring(ev.blocking), tostring(ev.blockable),
            ev.timer or -1, ev.delay or -1, tostring(ev.completed),
            ev.ease and (" ease:" .. tostring(ev.ease.ref_value)) or "")
    end
end

-- Snapshot por carta: tudo que decide se ela aparece e onde.
local function dbgCards(self, tag)
    if not REWARD_DBG then return end
    for i, inst in ipairs(self.cardInstances or {}) do
        local offer = inst.shopOffer
        local slot = offer and offer._slot
        local anim = slot and self.cardAnimations and self.cardAnimations[slot]
        dbg("%s inst[%d] id=%s slot=%s x=%s y=%s entryOy=%s dissolve=%s curScale=%s animScale=%s animElapsed=%s hover=%s",
            tag, i, tostring(offer and offer.id), tostring(slot),
            tostring(inst.x), tostring(inst.y),
            tostring(inst._entryOy), tostring(inst.dissolve),
            tostring(inst.currentScale),
            tostring(anim and anim.scale), tostring(anim and anim.elapsed),
            tostring(inst.isHovered))
    end
end

local Config = require("src.core.Config")
local Debug = require("src.core.Debug")
local FontManager = require("src.ui.FontManager")
local HintBar = require("src.ui.HintBar")
local Panel9 = require("src.ui.Panel9")
local Theme = require("src.ui.Theme")
local Palette = require("src.ui.Palette")
local PixelCanvas = require("src.ui.PixelCanvas")
local SceneBackground = require("src.ui.SceneBackground")
local Button = require("components.Button")
local CardDatabase = require("src.systems.CardDatabase")
local CardInfoDisplay = require("src.ui.CardInfoDisplay")
local I18n = require("src.i18n.I18n")
local Sfx = require("src.systems.Sfx")
local EventManager = require("engine.EventManager")
local DissolveShader = require("src.ui.DissolveShader")
local ImageCache = require("src.ui.ImageCache")

-- shopSystem: instância singleton injetada (ver Game:new). Param opcional pra
-- compatibilidade com chamadas antigas — fallback gera warning.
function CardRewardScreen:new(shopSystem)
    local instance = setmetatable({}, CardRewardScreen)

    instance.visible = false
    instance.shopOffers = {}
    instance.cardInstances = {}
    instance.cardButtons = {}
    instance.skipButton = nil
    instance.refreshButton = nil
    instance.onCardPurchased = nil
    instance.onSkipped = nil

    -- Confirmação de compra
    -- Selection (CLICK): mini-buttons Balatro-style (Buy + Cancel) attached
    -- compactos sob a carta clicada.
    instance.selectedOffer = nil
    instance.selectedIdx = nil
    instance._selectionAnim = 0
    instance._selectionButtons = {}
    -- Hover (mouse-over sem clicar): drives os painéis laterais que aparecem
    -- FORA da janela da loja (left = info, right = preview ampliado).
    instance.hoveredOffer = nil
    instance.hoveredIdx = nil
    instance._hoverAnim = 0  -- 0..1 fade dos painéis laterais
    -- LEGACY: showConfirmation/confirmButton/cancelButton removidos (modal antigo).
    instance.hoveredOffer = nil

    if not shopSystem then
        Debug.warn("CardRewardScreen criado sem ShopSystem injetado — caindo em fallback (Game:new deve passar shopSystem)")
        local ShopSystem = require("src.systems.ShopSystem")
        shopSystem = ShopSystem:new()
    end
    instance.shopSystem = shopSystem

    instance.animationTime = 0
    instance.cardAnimations = {}

    instance.cardDatabase = CardDatabase:new()
    instance.cardInfoDisplay = CardInfoDisplay:new()

    instance:updateLayout()

    return instance
end

-- Layout fiel ao Balatro source (UI_definitions.lua:637-740):
--   ROOT
--   └─ COLUMN (BOSS_MAIN bg)
--      ├─ ROW1 — Buttons | Cards
--      │   ├─ COL: [Next Round] + [Reroll]
--      │   └─ COL: shop_jokers (4 slots)
--      ├─ spacer
--      └─ ROW2 — Voucher | Boosters
--          ├─ COL: voucher (label vertical "Ato X")
--          └─ COL: 2 boosters (cardW × 1.27)
--
-- Modo "rewards": 3 cartas, layout simplificado em 1 row.
-- F10.3: Layout container-based compacto seguindo Balatro source
-- (UI_definitions.lua:637-740). Hierarquia:
--   Painel principal (BOSS_MAIN bg, dual-border dourado) ocupa centro da tela.
--   Dentro: title bar dourado + row1 (buttons col | cards container) +
--   row2 (voucher container | packs container) + skip footer.
--   Tudo lado-a-lado com padding interno (não slots flutuantes na cena).
function CardRewardScreen:updateLayout()
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()
    local cfg = self.modeConfig or { cards = 3, upgrades = 0, boosters = 0 }
    self.layoutMode = self.mode

    self.cardPositions = {}

    if self.mode == "shop" then
        -- ========== Painel Principal ==========
        -- F13: ainda maior pra fit Balatro-feel + cartas grandes legíveis.
        -- panelW cap 1100→1200, panelH cap 800→820.
        -- Topo do painel respeita altura do TopBar pra HUD ficar sempre visível.
        local topBarH = 56  -- TopBar.height + padding folga
        local panelW = math.floor(math.min(sw * 0.94, 1200))
        local panelH = math.floor(math.min(sh * 0.90, 820))
        local panelX = math.floor((sw - panelW) * 0.5)
        local panelY = math.floor(math.max(topBarH + 4, (sh - panelH) * 0.5))
        -- Reclampa altura se ficou abaixo do topBar (telas pequenas).
        if panelY + panelH > sh - 4 then panelH = sh - panelY - 4 end
        self.panel = { x = panelX, y = panelY, w = panelW, h = panelH }

        local titleH = 50     -- altura do title bar
        local pad = 16        -- padding interno do painel
        local subPad = 6      -- padding mínimo dentro de subcontainers (6→ menor pra cartas maiores)

        -- ========== Cards row (ocupa full width interna do painel) ==========
        local nCards = cfg.cards or 4
        local nVouchers = cfg.upgrades or 1
        local nPacks = cfg.boosters or 2

        -- Buttons column à esquerda. Largura 18% panel.
        local buttonsW = math.floor(panelW * 0.18)
        local buttonsX = panelX + pad
        local buttonsY = panelY + titleH + pad

        -- Cards container ocupa o resto da largura horizontal.
        local cardsX = buttonsX + buttonsW + 12
        local cardsContainerW = panelX + panelW - pad - cardsX

        -- Card width: PREENCHE o container inteiro descontando apenas os spacings
        -- entre cartas (sem subPad). Antes subPad*2 era descontado, deixando
        -- ~22px "off-center" (visível como left-align em telas largas).
        local cardSpacing = 4  -- lado-a-lado Balatro-style
        self.cardWidth = math.floor((cardsContainerW - cardSpacing * (nCards - 1)) / nCards)
        -- F13: cards mais altos (1.4→1.45) pra ratio mais "card-like" Balatro.
        self.cardHeight = math.floor(self.cardWidth * 1.45)

        local cardsContainerH = self.cardHeight + subPad * 2
        self.cardsContainer = { x = cardsX, y = buttonsY, w = cardsContainerW, h = cardsContainerH }

        -- Cards positions: CENTRALIZADAS no container.
        local cardsTotalW = nCards * self.cardWidth + (nCards - 1) * cardSpacing
        local cardsStartX = cardsX + (cardsContainerW - cardsTotalW) / 2
        local cardsStartY = buttonsY + (cardsContainerH - self.cardHeight) / 2
        for i = 1, nCards do
            self.cardPositions[i] = {
                x = math.floor(cardsStartX + (i - 1) * (self.cardWidth + cardSpacing)),
                y = math.floor(cardsStartY),
                row = 1,
                kind = "card",
            }
        end

        -- Buttons column dimensions.
        self.buttonsContainer = { x = buttonsX, y = buttonsY, w = buttonsW, h = cardsContainerH }
        self.buttonsColX = buttonsX + 8
        self.buttonsColY = buttonsY + 12

        -- ========== Row 2: Voucher + Packs ==========
        local row2Y = buttonsY + cardsContainerH + 14
        local row2H = self.cardHeight + subPad * 2

        -- Voucher container (esquerda, 22% panel). Vouchers centralizados.
        local voucherContainerW = math.floor(panelW * 0.22)
        local voucherX = panelX + pad
        self.voucherContainer = { x = voucherX, y = row2Y, w = voucherContainerW, h = row2H }
        local voucherTotalW = nVouchers * self.cardWidth + math.max(0, nVouchers - 1) * cardSpacing
        local voucherStartX = voucherX + (voucherContainerW - voucherTotalW) / 2
        local voucherStartY = row2Y + (row2H - self.cardHeight) / 2
        for v = 1, nVouchers do
            local idx = nCards + v
            self.cardPositions[idx] = {
                x = math.floor(voucherStartX + (v - 1) * (self.cardWidth + cardSpacing)),
                y = math.floor(voucherStartY),
                row = 2, kind = "voucher",
                w = self.cardWidth, h = self.cardHeight,
            }
        end

        -- Packs container (direita, ocupa o resto até o fim do painel). Packs centralizados.
        local packsX = voucherX + voucherContainerW + 12
        local packsContainerW = panelX + panelW - pad - packsX
        self.packsContainer = { x = packsX, y = row2Y, w = packsContainerW, h = row2H }
        local packsTotalW = nPacks * self.cardWidth + math.max(0, nPacks - 1) * cardSpacing
        local packsStartX = packsX + (packsContainerW - packsTotalW) / 2
        local packsStartY = voucherStartY  -- alinhado verticalmente com vouchers
        for p = 1, nPacks do
            local idx = nCards + nVouchers + p
            self.cardPositions[idx] = {
                x = math.floor(packsStartX + (p - 1) * (self.cardWidth + cardSpacing)),
                y = math.floor(packsStartY),
                row = 2, kind = "pack",
                w = self.cardWidth, h = self.cardHeight,
            }
        end

        self.slotCount = nCards + nVouchers + nPacks

        -- Skip button no rodapé do painel.
        self.skipButtonX = panelX + panelW * 0.5 - 90
        self.skipButtonY = panelY + panelH - 50

    else
        -- ========== Modo rewards v3 "StS FLUTUANTE" (Jul/2026) ==========
        -- Feedback do dono: o painel parecia descentralizado, pills eram "só
        -- um quadrado com texto", tudo apertado. Como no Slay the Spire: SEM
        -- painel — o mundo (limpo) escurece atrás, um BANNER ornamental no
        -- topo, 3 cartas GRANDES flutuando centralizadas, marcadores sem
        -- caixa e o botão Seguir embaixo. Centralização é na TELA inteira.
        self.panel = nil
        self.cardsContainer = nil
        self.buttonsContainer = nil
        self.voucherContainer = nil
        self.packsContainer = nil
        self.buttonsColX = nil
        self.buttonsColY = nil

        local nCards = cfg.cards or 3
        local spacing = 30
        local wByWidth = math.floor((sw * 0.76 - spacing * (nCards - 1)) / nCards)
        local wByHeight = math.floor((sh * 0.46) / 1.4)
        self.cardWidth = math.min(wByWidth, wByHeight)
        self.cardHeight = math.floor(self.cardWidth * 1.4)

        local cardsTotalW = nCards * self.cardWidth + (nCards - 1) * spacing
        local cardsStartX = math.floor((sw - cardsTotalW) / 2)
        local cardsY = math.floor(sh * 0.28)
        for i = 1, nCards do
            self.cardPositions[i] = {
                x = math.floor(cardsStartX + (i - 1) * (self.cardWidth + spacing)),
                y = cardsY,
                row = 1, kind = "card",
            }
        end

        self.bannerY = math.floor(sh * 0.105)
        self.slotCount = nCards

        self.skipButtonX = math.floor(sw * 0.5) - 100   -- recentrado na criação
        self.skipButtonY = sh - 96
    end

    Debug.trace("[CardRewardScreen] Layout", self.mode, sw, "x", sh,
                "slots", self.slotCount, "card", self.cardWidth, "x", self.cardHeight)
end

-- mode: "rewards" | "shop"   (default "rewards" pra back-compat com chamadas antigas).
--   "rewards" = pós-batalha, 3 cartas, sem reroll. Skip = continuar sem bônus.
--   "shop"    = SHOP node, 4 cartas + 1 voucher + 2 packs, reroll exponencial,
--               Skip dá +3 ouro de bônus.
function CardRewardScreen:show(game, onCardPurchased, onSkipped, mode)
    self.visible = true
    self.game = game
    self.onCardPurchased = onCardPurchased
    self.onSkipped = onSkipped
    self.animationTime = 0
    self.mode = mode or "rewards"

    -- Contexto da run pro cérebro de ofertas (classe filtra pool; deck liga
    -- afinidade e anti-duplicata — "as escolhas anteriores importam").
    local run = game.runManager and game.runManager.currentRun
    local actNumber = (run and run.actNumber) or 1

    -- P0.7 (rebalance Jul/2026): elites/bosses pisam a raridade da recompensa
    -- — o mapa promete risco, a vitrine paga. Só em modo rewards (a loja do
    -- SHOP node não é recompensa de combate).
    local minRarity = nil
    if self.mode == "rewards" and run and run.currentNode then
        local nt = run.currentNode.type
        if nt == "elite" then
            minRarity = "uncommon"
        elseif nt == "boss" then
            minRarity = "rare"
        end
    end

    -- P0.3/P0.4: pesos de raridade POR ATO (Config.Acts via ActSystem — antes
    -- era o fixo 70/25/5 da loja; a tabela por ato era código morto).
    local ActSystem = require("src.systems.ActSystem")
    self.shopSystem:setContext({
        classId = (run and run.classId) or game.selectedClass,
        deckIds = (game.runManager and game.runManager.getDeckCardIds)
            and game.runManager:getDeckCardIds() or nil,
        runManager = game.runManager, -- forja (custo crescente) + dedup de joker (P0.10)
        actNumber = actNumber,        -- P0.5: cap de afinidade progressivo por ato
        rarityWeights = ActSystem.getRarityWeights(actNumber),
        minRarity = minRarity,
    })

    self.shopSystem:setMode(self.mode)
    self.shopSystem:generateOffers()
    self.shopOffers = self.shopSystem:getCurrentOffers()
    self.modeConfig = self.shopSystem:getModeConfig()

    -- Slot FIXO por oferta (F2): comprada uma carta, as demais NÃO trocam de
    -- lugar. Antes, draw/hover/selection indexavam shopOffers[i] contra
    -- cardInstances compactado — hover mostrava info da carta errada e os
    -- botões de compra apareciam no slot errado após a 1ª compra.
    for i, o in ipairs(self.shopOffers) do o._slot = i end

    -- FX de compra (carta voando pro deck + popups de ouro).
    self._flyCards = {}
    self._goldPopups = {}
    -- Regra "escolha 1" (rewards): flag zera a cada abertura — sem isto a
    -- SEGUNDA recompensa da run nasceria travada.
    self._rewardTaken = false

    Debug.log("[CardRewardScreen] Aberta em modo", self.mode, "com", #self.shopOffers, "ofertas")

    self:updateLayout()
    self:createCardInstances()
    self:createOfferButtons()

    -- ===== DEBUG: arquivo novo por abertura + radiografia do momento =====
    if REWARD_DBG then
        _dbgStart = love.timer.getTime()
        self._dbgNext = 0
        self._dbgDrawNext = 0
        pcall(love.filesystem.write, "reward_debug.log", "")
        dbg("======== SHOW mode=%s tela=%dx%d state-time ========",
            tostring(self.mode), love.graphics.getWidth(), love.graphics.getHeight())
        dbg("ofertas=%d | lastScreenW=%s lastScreenH=%s",
            #self.shopOffers, tostring(self.lastScreenWidth), tostring(self.lastScreenHeight))
        dbgQueue("base")
        dbgQueue(FXQ)
    end

    -- Zera a fila dedicada: eventos zumbis de uma abertura anterior morrem
    -- aqui (o close atrasado do "escolha 1" já é guardado por self.visible).
    EventManager.clear(FXQ)

    -- Slide-in animation (Fase 4.4): painel desce do topo da tela em 0.43s.
    -- Padrão Balatro: easing 'smooth' (cubic in-out) chega "encaixando".
    self.slideOffsetY = -love.graphics.getHeight()
    EventManager.ease(self, "slideOffsetY", 0, 0.43, "smooth", FXQ)

    -- ENTRADA v3 (rewards): cada carta CAI de cima com back_out (stagger) +
    -- tick sonoro em pitch crescente + juice ao pousar — fluidez pedida no
    -- feedback ("animações, coisas legais, jogo satisfatório").
    if self.mode == "rewards" then
        local Moveable = require("engine.Moveable")
        for i, inst in ipairs(self.cardInstances) do
            inst._entryOy = -70   -- de CIMA pra baixo (negativo = acima do lugar)
            local d = 0.15 + (i - 1) * 0.13
            dbg("entry AGENDADA carta %d: ease em t=+%.2fs (fila %s)", i, d, FXQ)
            EventManager.parallel(d, function()
                dbg("entry ease DISPAROU carta %d (entryOy=%s)", i, tostring(inst._entryOy))
                EventManager.parallelEase(inst, "_entryOy", 0, 0.45, "back_out", FXQ)
                Sfx.play("cardDraw", { pitch = 0.95 + i * 0.06, volume = 0.55 })
            end, FXQ)
            EventManager.parallel(d + 0.45, function()
                Moveable.juice_up(inst, 0.22, 0.05)
            end, FXQ)
        end
        dbgCards(self, "pos-show")
    end

    -- Materialize cascade nas cartas: cada cardInstance arranca em dissolve=1
    -- e tweena pra 0 com stagger de 80ms — Balatro pack-opening style.
    -- ⚠️ SÓ NA LOJA (fix Jul/2026): em rewards, deixar dissolve=1 esperando o
    -- start_materialize agendado deixou as cartas INVISÍVEIS no jogo real
    -- (print do dono: só banner+marcadores). A entrada do rewards é a QUEDA
    -- (_entryOy) — dissolve fica 0 desde o início, visibilidade garantida
    -- sem corrida com o EventManager.
    if self.mode ~= "rewards" then
        local stagger = 0.08
        for i, cardInstance in ipairs(self.cardInstances) do
            cardInstance.dissolve = 1
            cardInstance.dissolve_colours = DissolveShader.palette("booster")
            EventManager.parallel(0.43 + (i - 1) * stagger, function()
                if cardInstance.start_materialize then
                    cardInstance:start_materialize(DissolveShader.palette("booster"), true, 0.9)
                else
                    cardInstance.dissolve = 0
                end
            end, FXQ)
        end
    end

    -- Skip/Continue. Em modo shop dá +N ouro de bônus (configurado em MODE_CONFIG).
    -- F2: em modo shop vira o botão PRINCIPAL da coluna esquerda (Balatro:
    -- "Next Round" vermelho grande no topo da column), não um botãozinho no
    -- rodapé. Em rewards continua compacto no rodapé.
    local skipBonus = (self.modeConfig and self.modeConfig.skipBonus) or 0
    local skipLabel = I18n.t("reward.continue")
    if self.mode == "rewards" then
        -- Clareza: "Continuar" não dizia O QUE acontecia (perder a carta).
        skipLabel = I18n.t("reward.skip_no_card")
    end
    if self.mode == "shop" and skipBonus > 0 then
        skipLabel = skipLabel .. " (+" .. skipBonus .. "g)"
    end
    -- Reforma Jul/2026 (feedback "Seguir ..."): 130px NÃO cabia "Seguir sem
    -- carta" (~190px em Press Start 2P 12) e o TextFit truncava com "...".
    -- Largura agora é MEDIDA pelo texto (+ícone/padding) e o botão recentra.
    local skipFont = 12
    local skipW = FontManager.getFont(skipFont):getWidth(skipLabel) + 64
    skipW = math.max(200, skipW)
    local skipX = (self.panel and (self.panel.x + self.panel.w / 2) or (love.graphics.getWidth() / 2)) - skipW / 2
    local skipY, skipH = self.skipButtonY, 40
    if self.mode == "shop" and self.buttonsColX and self.buttonsContainer then
        skipX, skipY = self.buttonsColX, self.buttonsColY
        skipW = math.max(80, self.buttonsContainer.w - 16)
        skipH = 52
        skipFont = 13
    end
    self.skipButton = Button:new(
        skipX, skipY, skipW, skipH,
        skipLabel,
        function()
            if self.mode == "shop" and skipBonus > 0 and self.game.economySystem then
                self.game.economySystem:earnGold(skipBonus, "shop_skip")
                self.game:addMessage("+" .. skipBonus .. "g (pulou loja)", "info")
            end
            self:hide()
            if self.onSkipped then
                self.onSkipped()
            end
        end, nil, skipFont
    )
    self.skipButton:setIcon("arrow_right")
    if self.mode == "shop" then self.skipButton:setColorScheme("red") end

    -- Refresh button só existe se o modo permitir (rewards = false).
    if self.modeConfig and self.modeConfig.canReroll then
    local refreshCost = self.shopSystem:getRefreshCost()
    -- Em modo shop fica em column à esquerda dos cards (Balatro layout).
    -- Em modo rewards fica ao lado do Skip (legacy).
    local rerollX, rerollY, rerollW, rerollH
    if self.mode == "shop" and self.buttonsColX and self.buttonsContainer then
        -- F12: dimensões derivadas da column (não hardcoded 130). Antes overflow
        -- de 4-8px porque a column responsiva podia ser menor que o botão.
        -- Largura = column inteira - 2*8px de padding lateral interno.
        -- F2: fica ABAIXO do Continuar (que agora abre a coluna).
        rerollX = self.buttonsColX
        rerollY = self.buttonsColY + 52 + 10
        rerollW = math.max(80, self.buttonsContainer.w - 16)
        rerollH = 44
    else
        rerollX = self.skipButtonX + 145
        rerollY = self.skipButtonY
        rerollW = 130
        rerollH = 32
    end
    self.refreshButton = Button:new(
        rerollX, rerollY, rerollW, rerollH,
        I18n.t("reward.refresh", { n = refreshCost }),
        function()
            local currentRefreshCost = self.shopSystem:getRefreshCost()
            if self.game.economySystem:canAfford(currentRefreshCost) then
                self.game.economySystem:spendGold(currentRefreshCost, "refresh", "shop")
                Sfx.play("shopReroll")  -- F11.5: dedicado pra reroll (riffle paper).
                self:_spawnGoldPopup(self.refreshButton.x + self.refreshButton.width / 2,
                    self.refreshButton.y, "-$" .. currentRefreshCost)
                self.shopSystem:refreshOffers()
                self.shopOffers = self.shopSystem:getCurrentOffers()
                for i, o in ipairs(self.shopOffers) do o._slot = i end

                self:createCardInstances()
                self:createOfferButtons()

                self.cardAnimations = {}
                for i = 1, #self.shopOffers do
                    self.cardAnimations[i] = {
                        scale = 0,
                        targetScale = 1,
                        delay = (i - 1) * 0.1,
                        elapsed = 0
                    }
                end

                local newCost = self.shopSystem:getRefreshCost()
                self.refreshButton.text = I18n.t("reward.refresh", { n = newCost })

                self.game:addMessage(I18n.t("reward.shop_refreshed"), "info")
            else
                self.game:addMessage(I18n.t("reward.refresh_fail"), "error")
                Sfx.play("purchaseDeny")
            end
        end
    )
    end  -- end if canReroll

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

    -- F2: itera pelas ofertas usando o _slot FIXO de cada uma — depois de uma
    -- compra as cartas restantes ficam onde estavam (slot comprado vira vazio
    -- com stamp VENDIDO, desenhado em draw()).
    local maxSlots = self.slotCount or 3
    for _, offer in ipairs(self.shopOffers) do
        if offer.type == "card" and not offer.purchased
            and (offer._slot or math.huge) <= maxSlots then
        local cardData = self.cardDatabase:getCard(offer.id)
        if not cardData then
            Debug.err("[CardRewardScreen] Card data not found for", offer.id)
            goto continue
        end

        local cardInstance = self.cardDatabase:createCardInstance(cardData)

        if cardInstance then
            local pos = self.cardPositions[offer._slot] or { x = 0, y = 0 }

            -- F13.1: card scale = ~85% do slot (breathing room nas bordas e
            -- espaço pro hover scale-up sem extravasar pra vizinhos). Antes
            -- 100% fill ficava grande demais.
            local imgW = cardInstance.image and cardInstance.image:getWidth() or 96
            local imgH = cardInstance.image and cardInstance.image:getHeight() or 144
            local slotW = pos.w or self.cardWidth
            local slotH = pos.h or self.cardHeight
            local fitScale = math.min(slotW / imgW, slotH / imgH) * 0.86
            local renderW = imgW * fitScale
            local renderH = imgH * fitScale
            -- Centraliza a carta DENTRO do slot. Slot continua sendo a área
            -- clicável (cardButton); o sprite visualmente ocupa apenas o centro.
            cardInstance.x = math.floor(pos.x + (slotW - renderW) / 2)
            cardInstance.y = math.floor(pos.y + (slotH - renderH) / 2)
            -- ÂNCORA IMUTÁVEL do layout (fix Jul/2026 do feedback loop):
            -- Card:draw grava self.y = y a cada frame; desenhar a partir de
            -- self.y + entryOy fazia y ACUMULAR o offset (70px/frame — as
            -- cartas estabilizavam em y≈-1900, fora da tela; era o bug
            -- "não renderizam até o hover"). O draw parte SEMPRE daqui.
            cardInstance.homeX = cardInstance.x
            cardInstance.homeY = cardInstance.y

            cardInstance.baseScale = fitScale
            cardInstance.currentScale = fitScale
            -- targetScale começa = baseScale; Card:updateMouse aplica hover bump
            -- proporcional (HOVER_SCALE_MULT) automaticamente.
            cardInstance.targetScale = fitScale
            -- Shop/relic: sem lift vertical no hover. Mantém scale + tilt 3D
            -- mas zera baseOffsetY/liftOffset (Balatro shop pattern — cartas
            -- ficam paradas, só "respiram" em scale).
            cardInstance.noHoverLift = true

            -- Rarity border pulsante removida em F10.1 (poluía visualmente).
            -- offer.rarity ainda existe pra ordenar/filtrar; só não desenhamos halo.

            if not cardInstance.description and offer.description then
                cardInstance.description = offer.description
            end

            cardInstance.isRewardCard = false
            cardInstance.shopOffer = offer

            if cardInstance.cardInfoDisplay then
                cardInstance.cardInfoDisplay:configure({
                    showRarity = true,
                    showStats = true,
                    showDescription = true
                })
            end

            -- Link bidirecional: purchaseOffer usa offer.cardInstance pro FX
            -- de compra (antes NUNCA era atribuído — o feedback não disparava).
            offer.cardInstance = cardInstance
            table.insert(self.cardInstances, cardInstance)
        else
            Debug.err("[CardRewardScreen] Could not create card instance for", offer.id)
        end
        ::continue::
        end
    end
end

function CardRewardScreen:createOfferButtons()
    self.cardButtons = {}

    -- F2: botão invisível ancorado no _slot fixo da oferta.
    local maxSlots = self.slotCount or 3
    for _, offer in ipairs(self.shopOffers) do
        if not offer.purchased and (offer._slot or math.huge) <= maxSlots then
            local pos = self.cardPositions[offer._slot] or { x = 0, y = 0 }
            -- Voucher/pack podem ter w/h custom no layout (pos.w/pos.h).
            local btnW = pos.w or self.cardWidth
            local btnH = pos.h or self.cardHeight
            local capturedOffer = offer  -- closure capture
            local button = Button:new(
                pos.x, pos.y, btnW, btnH,
                "",
                function()
                    self:setSelectedOffer(capturedOffer, capturedOffer._slot)
                end
            )
            button:setVariant("invisible")
            table.insert(self.cardButtons, button)
        end
    end
end

function CardRewardScreen:purchaseOffer(offer, offerId)
    Debug.log("[CardRewardScreen] Purchasing", offer.name, "($" .. offer.cost .. ")")

    -- REGRA "ESCOLHA 1" (fix Jul/2026 — dava pra pegar as 3): depois da
    -- primeira carta, cliques atrasados durante o fade/close são ignorados.
    if self.mode == "rewards" and self._rewardTaken then return end

    if not self.game.economySystem:canAfford(offer.cost) then
        self.game:addMessage(I18n.t("reward.insufficient_gold"), "error")
        Sfx.play("purchaseDeny")
        return
    end

    -- Pre-check: joker com slots cheios não pode ser comprado (evita gold drain).
    if offer.type == "card" then
        local cd = self.game.deckManager.cardDatabase:getCard(offer.id)
        if cd and cd.type == "joker" and not self.game:canAcceptJoker() then
            self.game:addMessage("Slots de joker cheios — venda um primeiro", "warning")
            Sfx.play("purchaseDeny")
            return
        end
    end

    if self.game.economySystem:spendGold(offer.cost, offer.type, offer.id) then
        -- Marca purchased ANTES de qualquer side-effect (pack open, addCardToRun)
        -- pra evitar duplo-buy caso input leak durante overlay/animação.
        offer.purchased = true

        -- F4 (Voto de Pobreza): qualquer compra em LOJA marca a run.
        if self.mode == "shop" and self.game.runManager
            and self.game.runManager.currentRun then
            self.game.runManager.currentRun._usedShop = true
        end

        local offerName = offer.type == "card" and I18n.cardName({ id = offer.id, name = offer.name }) or offer.name
        -- Screen jiggle no momento da compra (Fase 6.4) — feedback tátil leve.
        if _G.jiggleScreen then _G.jiggleScreen(0.25) end

        -- Popup de ouro "-$N" flutuando do slot comprado (todo tipo de oferta).
        do
            local pos = self.cardPositions[offer._slot or 0]
            if pos then
                local pw = pos.w or self.cardWidth
                self:_spawnGoldPopup(pos.x + pw - 14, pos.y + 10, "-$" .. offer.cost)
            end
        end

        if offer.type == "card" then
            -- Feedback visual F2 (Balatro): a carta VOA até o ícone de deck na
            -- TopBar, encolhendo — comunica "foi pro seu deck" sem texto.
            self:_startFlyToDeck(offer)
            self.game:addCardToRun(offer.id)
            self.game:addMessage(I18n.t("reward.bought", { name = offerName }), "success")
        elseif offer.type == "upgrade" then
            self:applyUpgrade(offer)
            self.game:addMessage(I18n.t("reward.bought", { name = offerName }), "success")
        elseif offer.type == "booster_pack" then
            -- Fase 5: abre o pack imediatamente via PackOpenScreen overlay.
            -- main.lua expõe _G.openBoosterPack(packData, onComplete) que orquestra.
            local BoosterPackSystem = require("src.systems.BoosterPackSystem")
            local run = self.game.runManager and self.game.runManager.currentRun
            local classId = run and run.classId
            -- P0.6/P0.10: runManager liga o dedup de joker possuído (Buffoon)
            -- e actNumber os pesos de raridade por ato (Arcana/Celestial/Spectral).
            local pack = BoosterPackSystem.expandPackRecord({
                id = offer.id, kind = offer.kind,
                size = offer.size, choose = offer.choose,
            }, classId, {
                runManager = self.game.runManager,
                actNumber = (run and run.actNumber) or 1,
            })

            if _G.openBoosterPack then
                _G.openBoosterPack(pack, function(selected)
                    -- Cards escolhidas vão pro deck — passa edition/seal via meta
                    -- pra que essa cópia específica preserve o modifier (Fase 5.4).
                    for _, card in ipairs(selected or {}) do
                        if card.id then
                            self.game:addCardToRun(card.id, {
                                edition = card.edition,
                                seal = card.seal,
                            })
                        end
                    end
                    self.game:addMessage("+" .. #(selected or {}) .. " carta(s) ao deck", "success")
                end)
            else
                Debug.warn("[CardRewardScreen] _G.openBoosterPack não setado — pack ignorado")
            end
            self.game:addMessage(offerName .. " aberto", "info")
        end
        Sfx.play("purchaseConfirm")

        -- offer.purchased já foi setado antes do side-effect

        self:createCardInstances()
        self:createOfferButtons()

        if self.onCardPurchased then
            self.onCardPurchased(offer)
        end

        -- REGRA "ESCOLHA 1" (rewards, StS): pegar UMA carta ENCERRA os
        -- espólios — os botões morrem na hora, as cartas restantes DISSOLVEM
        -- (queima Balatro) e a tela fecha sozinha seguindo o fluxo (mesmo
        -- caminho do Seguir). Antes dava pra pegar as 3.
        if self.mode == "rewards" and offer.type == "card" then
            self._rewardTaken = true
            self.cardButtons = {}
            self:clearSelection()
            self.hoveredOffer, self.hoveredInst = nil, nil
            for _, inst in ipairs(self.cardInstances) do
                local o = inst.shopOffer
                if o and o ~= offer and not o.purchased and inst.start_dissolve then
                    inst:start_dissolve(nil, true, 0.55, true)
                end
            end
            EventManager.parallel(0.65, function()
                if self.visible then
                    self:hide()
                    if self.onSkipped then self.onSkipped() end
                end
            end, FXQ)
        end
    end
end

-- Marca uma oferta como "selecionada" — dispara o overlay 3-zone (info-left,
-- carta-com-buttons-attached, preview-right). Substitui o modal centralizado
-- antigo (showPurchaseConfirmation + drawPurchaseConfirmation, removidos).
-- Pattern Balatro: create_shop_card_ui (UI_definitions.lua:802-880) cria
-- buy_button como CHILD da carta, popup info side-anchored via align_h_popup.
function CardRewardScreen:setSelectedOffer(offer, idx)
    if not offer then return end
    -- Re-clicar na mesma → toggle off (Balatro card.lua:4610-4623).
    if self.selectedOffer == offer then
        self:clearSelection()
        return
    end

    self.selectedOffer = offer
    self.selectedIdx = idx
    self:_buildSelectionButtons(offer, idx)

    -- Slide-in dos painéis laterais (anim 0→1 em 0.18s smooth).
    if EventManager and EventManager.parallelEase then
        EventManager.parallelEase(self, "_selectionAnim", 1, 0.18, "smooth", "shop_select")
    else
        self._selectionAnim = 1
    end

    -- Sfx leve (cardSelect com pitch alto). hoverCard com +0.2 também serve.
    if Sfx.playWithVariation then
        Sfx.playWithVariation("hoverCard", 1.1, 0.08, 0.5, 0.05)
    end
end

-- Mini-buttons Balatro-style (UI_definitions.lua:382 card_focus_button) attached
-- compactos sob a carta. Sem texto verbal — apenas cor semântica:
--   Buy: verde-grimório com "$N" (custo é a única info necessária)
--   Cancel: vermelho-crimson com ícone X
-- Largura ~50% da carta dividida em 2; altura 32px.
function CardRewardScreen:_buildSelectionButtons(offer, idx)
    self._selectionButtons = {}
    local pos = self.cardPositions[idx]
    if not pos then return end

    local pw = pos.w or self.cardWidth
    local ph = pos.h or self.cardHeight

    -- Reforma Jul/2026 (feedback "aquele P e aquele X"): 90px + fonte 12 NÃO
    -- cabia "PEGAR" e o TextFit degradava até virar UMA LETRA. Largura agora
    -- é MEDIDA pelo texto; linha desce pra baixo da faixa de afinidade.
    local btnH = 38
    local gap = 8
    local buyLabel = (offer.cost or 0) > 0 and ("$" .. tostring(offer.cost))
        or I18n.t("common.take"):upper()
    local buyW = math.max(110, FontManager.getFont(12):getWidth(buyLabel) + 56)
    local cancelW = btnH   -- quadrado: só o ícone X, sem texto pra truncar
    local totalW = buyW + cancelW + gap
    local bx0 = math.floor(pos.x + (pw - totalW) / 2)
    local by0 = math.floor(pos.y + ph + (self.mode == "rewards" and 24 or 8))

    -- Buy button: "$N" (loja) ou "PEGAR" (recompensa grátis). Verde-grimório.
    local buyBtn = Button:new(bx0, by0, buyW, btnH, buyLabel, function()
        local toBuy = self.selectedOffer
        self:clearSelection()
        if toBuy then self:purchaseOffer(toBuy, toBuy.id) end
    end, nil, 12)
    buyBtn:setColorScheme("green")
    if self.game and not self.game.economySystem:canAfford(offer.cost) then
        buyBtn:setEnabled(false)
    end
    table.insert(self._selectionButtons, buyBtn)

    -- Cancel button: QUADRADO só com o ícone X (nada de texto pra truncar).
    local cancelBtn = Button:new(bx0 + buyW + gap, by0, cancelW, btnH, "", function()
        self:clearSelection()
    end, nil, 14)
    cancelBtn:setColorScheme("red")
    cancelBtn:setIcon("x_close")
    table.insert(self._selectionButtons, cancelBtn)
end

-- Limpa estado de seleção e anima fade-out dos painéis laterais.
function CardRewardScreen:clearSelection()
    self.selectedOffer = nil
    self.selectedIdx = nil
    self._selectionButtons = {}
    if EventManager and EventManager.parallelEase then
        EventManager.parallelEase(self, "_selectionAnim", 0, 0.12, "smooth", "shop_select")
    else
        self._selectionAnim = 0
    end
end

-- Aliases legacy mantidos pra eventual call site externo. Internamente apenas
-- delegam pra setSelectedOffer/clearSelection.
function CardRewardScreen:showPurchaseConfirmation(offer)
    -- Encontra idx da offer pra build dos buttons.
    local idx = nil
    for i, o in ipairs(self.shopOffers or {}) do
        if o == offer then idx = i; break end
    end
    self:setSelectedOffer(offer, idx)
end

function CardRewardScreen:confirmPurchase()
    if not self.selectedOffer then return end
    local toBuy = self.selectedOffer
    self:clearSelection()
    self:purchaseOffer(toBuy, toBuy.id)
end

-- Legacy alias: agora apenas delega pra clearSelection.
function CardRewardScreen:cancelPurchase()
    self:clearSelection()
end

-- ============================================================================
-- FX DE COMPRA (F2) — carta voa pro deck + popups de ouro + stamp VENDIDO
-- ============================================================================

-- Carta comprada voa até o ícone de deck da TopBar (x≈200), encolhendo com
-- ease_in (sucção). Entry vive em self._flyCards; desenhada em screen-space
-- (fora do slide do painel) no fim do draw().
function CardRewardScreen:_startFlyToDeck(offer)
    local inst = offer.cardInstance
    if not inst or not inst.image then return end
    self._flyCards = self._flyCards or {}

    local fly = {
        img = inst.image,
        x = inst.x, y = inst.y,
        scale = inst.currentScale or inst.baseScale or 1,
        alpha = 1,
        rot = 0,
    }
    table.insert(self._flyCards, fly)

    -- Alvo: ícone de deck da TopBar (padding 20 + 180 — ver TopBar.lua).
    local targetX, targetY = 205, 6
    local dur = 0.45
    if EventManager and EventManager.parallelEase then
        EventManager.parallelEase(fly, "x", targetX, dur, "ease_in", "shop_fly")
        EventManager.parallelEase(fly, "y", targetY, dur, "ease_in", "shop_fly")
        EventManager.parallelEase(fly, "scale", 0.12, dur, "ease_in", "shop_fly")
        EventManager.parallelEase(fly, "rot", 0.35, dur, "smooth", "shop_fly")
        EventManager.parallel(dur, function()
            fly._done = true
            Sfx.play("cardDraw", { pitch = 1.15, volume = 0.7 })
        end, "shop_fly")
    else
        fly._done = true
    end
end

-- Popup "-$N" que flutua pra cima e some (age controlada em update()).
function CardRewardScreen:_spawnGoldPopup(x, y, text)
    self._goldPopups = self._goldPopups or {}
    table.insert(self._goldPopups, { text = text, x = x, y = y, age = 0 })
end

local POPUP_LIFE = 0.9

function CardRewardScreen:_updatePurchaseFx(dt)
    if self._flyCards then
        for i = #self._flyCards, 1, -1 do
            if self._flyCards[i]._done then table.remove(self._flyCards, i) end
        end
    end
    if self._goldPopups then
        for i = #self._goldPopups, 1, -1 do
            local p = self._goldPopups[i]
            p.age = p.age + dt
            if p.age >= POPUP_LIFE then table.remove(self._goldPopups, i) end
        end
    end
end

-- Desenhados em SCREEN-SPACE (após o pop do slide) — voam por cima de tudo.
function CardRewardScreen:_drawPurchaseFx()
    for _, fly in ipairs(self._flyCards or {}) do
        love.graphics.setColor(1, 1, 1, fly.alpha)
        love.graphics.draw(fly.img, fly.x, fly.y, fly.rot, fly.scale, fly.scale)
    end
    local font = FontManager.getFont(13)
    love.graphics.setFont(font)
    for _, p in ipairs(self._goldPopups or {}) do
        local t = p.age / POPUP_LIFE
        local a = 1 - t * t
        local y = p.y - 36 * t
        love.graphics.setColor(0, 0, 0, 0.7 * a)
        love.graphics.print(p.text, p.x + 1, y + 1)
        love.graphics.setColor(0.95, 0.78, 0.25, a)
        love.graphics.print(p.text, p.x, y)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Slot de carta comprada: moldura vazia esmaecida + stamp "VENDIDO" diagonal
-- (Balatro deixa o buraco no shelf — comunicar "você JÁ comprou isto aqui").
function CardRewardScreen:_drawSoldSlot(pos)
    local w = pos.w or self.cardWidth
    local h = pos.h or self.cardHeight
    love.graphics.setColor(0, 0, 0, 0.30)
    love.graphics.rectangle("fill", pos.x + 4, pos.y + 4, w - 8, h - 8, 4, 4)
    love.graphics.setColor(Palette.AGED_GOLD_DARK[1], Palette.AGED_GOLD_DARK[2],
        Palette.AGED_GOLD_DARK[3], 0.5)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", pos.x + 4, pos.y + 4, w - 8, h - 8, 4, 4)

    local font = FontManager.getFont(14)
    love.graphics.setFont(font)
    local txt = I18n.t("reward.sold")
    local tw = font:getWidth(txt)
    love.graphics.push()
    love.graphics.translate(pos.x + w / 2, pos.y + h / 2)
    love.graphics.rotate(-0.28)
    love.graphics.setColor(Palette.BLOOD[1], Palette.BLOOD[2], Palette.BLOOD[3], 0.75)
    love.graphics.rectangle("line", -tw / 2 - 8, -14, tw + 16, 28)
    love.graphics.print(txt, -tw / 2, -font:getHeight() / 2)
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
end

function CardRewardScreen:applyUpgrade(upgrade)
    if upgrade.effect == "forge_card" then
        -- Forja comprada: registra (o custo da PRÓXIMA cresce) e abre o picker
        -- de carta por cima da loja. O pagamento já aconteceu em purchaseOffer.
        if self.game.runManager and self.game.runManager.registerPaidForge then
            self.game.runManager:registerPaidForge()
        end
        if _G.openForgeScreen then
            _G.openForgeScreen()
        else
            Debug.warn("[CardRewardScreen] _G.openForgeScreen não registrado — forja ignorada")
        end
        return
    end
    -- P3.2 (rebalance Jul/2026): os branches toast-only (increase_card_draw /
    -- increase_attack_damage / increase_defense) foram REMOVIDOS junto com as
    -- ofertas correspondentes (ShopSystem:initializeShopPools) — upgrade
    -- comprado tem que aplicar efeito real, nunca só mensagem.
    if upgrade.effect == "increase_max_health" then
        self.game.player.maxHealth = self.game.player.maxHealth + upgrade.value
        self.game.player.health = self.game.player.health + upgrade.value
    elseif upgrade.effect == "increase_base_mana" then
        self.game.player.baseMaxMana = self.game.player.baseMaxMana + upgrade.value
        self.game.player.maxMana = self.game.player.maxMana + upgrade.value
        self.game.player.mana = self.game.player.mana + upgrade.value
    else
        Debug.warn("[CardRewardScreen] upgrade sem efeito implementado: "
            .. tostring(upgrade.effect) .. " — não deveria estar na vitrine (P3.2)")
    end
end

function CardRewardScreen:hide()
    self.visible = false
    self.shopOffers = {}
    self.cardInstances = {}
    self.cardButtons = {}
    self.skipButton = nil
    self.refreshButton = nil
    self._flyCards = {}
    self._goldPopups = {}

    self:cancelPurchase()
end

function CardRewardScreen:update(dt)
    if not self.visible then return end

    local currentWidth = love.graphics.getWidth()
    local currentHeight = love.graphics.getHeight()
    if not self.lastScreenWidth or self.lastScreenWidth ~= currentWidth or self.lastScreenHeight ~= currentHeight then
        dbg("RESIZE branch! %sx%s -> %dx%d (recria instancias/botoes)",
            tostring(self.lastScreenWidth), tostring(self.lastScreenHeight),
            currentWidth, currentHeight)
        self.lastScreenWidth = currentWidth
        self.lastScreenHeight = currentHeight
        self:updateLayout()
        if #self.shopOffers > 0 then
            self:createCardInstances()
            self:createOfferButtons()
            if self.skipButton then
                -- F2: em modo shop o Continuar mora na column esquerda.
                if self.mode == "shop" and self.buttonsColX and self.buttonsContainer then
                    self.skipButton.x = self.buttonsColX
                    self.skipButton.y = self.buttonsColY
                    self.skipButton.width = math.max(80, self.buttonsContainer.w - 16)
                else
                    -- rewards: recentra pela LARGURA MEDIDA (não o -90 fixo)
                    self.skipButton.x = math.floor(love.graphics.getWidth() / 2
                        - self.skipButton.width / 2)
                    self.skipButton.y = self.skipButtonY
                end
            end
            if self.refreshButton then
                -- Em modo shop o reroll fica em column dedicada à esquerda
                -- (Balatro UI_definitions.lua:706-716), abaixo do Continuar.
                -- Em modo rewards fica ao lado do skip (legacy 1-row layout).
                if self.mode == "shop" and self.buttonsColX and self.buttonsContainer then
                    self.refreshButton.x = self.buttonsColX
                    self.refreshButton.y = self.buttonsColY + 52 + 10
                    self.refreshButton.width = math.max(80, self.buttonsContainer.w - 16)
                else
                    self.refreshButton.x = self.skipButtonX + 180
                    self.refreshButton.y = self.skipButtonY
                end
            end
        end
    end

    self.animationTime = self.animationTime + dt

    -- DEBUG: snapshot a cada 0.5s nos primeiros 6s da tela (o suficiente
    -- pra pegar a entrada travada sem inundar o log).
    if REWARD_DBG and self.animationTime < 6 then
        self._dbgNext = self._dbgNext or 0
        if self.animationTime >= self._dbgNext then
            self._dbgNext = self._dbgNext + 0.5
            dbg("UPDATE t=%.2f slideY=%.1f paused=%s pend(base)=%d pend(%s)=%d",
                self.animationTime, self.slideOffsetY or 0,
                tostring(EventManager.paused),
                EventManager.pendingCount("base"), FXQ,
                EventManager.pendingCount(FXQ))
            dbgCards(self, "  upd")
        end
    end

    local slotCount = self.slotCount or 3
    for i = 1, slotCount do
        local anim = self.cardAnimations[i]
        if anim then
            anim.elapsed = anim.elapsed + dt

            if anim.elapsed >= anim.delay then
                local progress = math.min(1, (anim.elapsed - anim.delay) / 0.3)
                anim.scale = anim.targetScale * self:easeOutBack(progress)
            end
        end
    end

    -- Hover/click nas cartas e seus invisible-buttons sempre rodam
    -- (sem modal bloqueando entrada). Selection overlay coexiste com hover.
    for i, cardInstance in ipairs(self.cardInstances) do
        if cardInstance and cardInstance.updateMouse then
            local mx, my = love.mouse.getPosition()
            cardInstance:updateMouse(mx, my, dt, true)
        end
    end

    -- Hover state pra side panels (left info / right preview).
    self:_updateHoverState()

    for _, button in ipairs(self.cardButtons) do
        button:update(dt)
    end

    if self.skipButton then
        self.skipButton:update(dt)
    end

    if self.refreshButton then
        self.refreshButton:update(dt)
    end

    -- Buttons attached da carta selecionada (Balatro pattern: filhos da carta).
    if self._selectionButtons then
        for _, b in ipairs(self._selectionButtons) do b:update(dt) end
    end

    self:_updatePurchaseFx(dt)
end

function CardRewardScreen:easeOutBack(t)
    local c1 = 1.70158
    local c3 = c1 + 1
    return 1 + c3 * math.pow(t - 1, 3) + c1 * math.pow(t - 1, 2)
end

function CardRewardScreen:draw()
    if not self.visible then return end

    local w, h = love.graphics.getDimensions()
    -- Backdrop FIXO (não desliza com o painel) — fica sempre cobrindo o gameplay
    -- atrás. Só o conteúdo (título + slots + botões) entra pelo topo.
    -- Background: cena DEDICADA do interior da loja (shop_interior). Não usa
    -- mais path_shop porque esse é o ícone do node de loja no mapa — repetir
    -- o mesmo visual entre map node e shop interior cria sensação de pobreza.
    -- Ver tools/pixellab_generate_shop_interior.py + memory/balatro_fidelity_directive.md.
    -- Fallback: se shop_interior não existe (ex: PixelLab ainda não gerou), usa
    -- path_shop temporariamente. Fallback final: backdrop preto.
    if self.mode == "rewards" then
        -- IMERSÃO (feedback Jul/2026): espólios de batalha acontecem NO LUGAR
        -- da batalha — main.lua já desenha o mundo vivo atrás (GameplayScene
        -- antes deste draw; WorldRoad continua tickando). Só um véu escuro
        -- pra dar foco ao painel — nada de interior de loja aqui.
        love.graphics.setColor(0.02, 0.015, 0.01, 0.60)
        love.graphics.rectangle("fill", 0, 0, w, h)
        love.graphics.setColor(1, 1, 1, 1)
    elseif not SceneBackground.draw("shop_interior", w, h, 0.55) then
        if not SceneBackground.draw("path_shop", w, h, 0.55) then
            love.graphics.setColor(0, 0, 0, 0.7)
            love.graphics.rectangle("fill", 0, 0, w, h)
        end
    end

    -- Slide-in: tudo dentro deste push é translado pelo offset animado em show().
    love.graphics.push()
    love.graphics.translate(0, self.slideOffsetY or 0)

    -- ========== F10.3: Containers Balatro-style ==========
    -- Painel principal (BOSS_MAIN bg + dual-border dourado). Modo rewards v3
    -- NÃO tem painel — banner flutuante estilo StS.
    if self.panel then
        self:_drawPanel(self.panel.x, self.panel.y, self.panel.w, self.panel.h, "main")
        -- Title bar dourado dentro do painel.
        self:_drawTitleBar(self.panel.x, self.panel.y, self.panel.w)
    elseif self.mode == "rewards" then
        self:_drawRewardsBanner()
    end

    -- Subcontainers L_BLACK (cards row, voucher, packs).
    if self.cardsContainer then
        self:_drawPanel(self.cardsContainer.x, self.cardsContainer.y,
                        self.cardsContainer.w, self.cardsContainer.h, "inner")
    end
    if self.voucherContainer then
        self:_drawPanel(self.voucherContainer.x, self.voucherContainer.y,
                        self.voucherContainer.w, self.voucherContainer.h, "inner")
    end
    if self.packsContainer then
        self:_drawPanel(self.packsContainer.x, self.packsContainer.y,
                        self.packsContainer.w, self.packsContainer.h, "inner")
    end
    if self.buttonsContainer then
        self:_drawPanel(self.buttonsContainer.x, self.buttonsContainer.y,
                        self.buttonsContainer.w, self.buttonsContainer.h, "inner")
        -- F2: painel de OURO no rodapé da column (Balatro: dinheiro sempre
        -- visível ao lado das ações de gastar). Leitura em 1 fixação.
        if self.game and self.game.economySystem then
            local bc = self.buttonsContainer
            local gy = bc.y + bc.h - 64
            love.graphics.setColor(0, 0, 0, 0.35)
            love.graphics.rectangle("fill", bc.x + 8, gy, bc.w - 16, 52, 4, 4)
            Palette.set(Palette.AGED_GOLD_DARK)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", bc.x + 8, gy, bc.w - 16, 52, 4, 4)
            love.graphics.setFont(FontManager.getFont(9))
            Palette.set(Palette.PARCHMENT)
            love.graphics.printf("OURO", bc.x + 8, gy + 8, bc.w - 16, "center")
            love.graphics.setFont(FontManager.getFont(16))
            Palette.set(Palette.AGED_GOLD_LIGHT)
            love.graphics.printf("$" .. self.game.economySystem.currentGold,
                bc.x + 8, gy + 22, bc.w - 16, "center")
        end
    end

    -- DEBUG: por 6s, loga o GATE de draw de cada carta a cada 0.5s.
    local dbgDrawTick = false
    if REWARD_DBG and self.animationTime < 6 then
        if self.animationTime >= (self._dbgDrawNext or 0) then
            self._dbgDrawNext = (self._dbgDrawNext or 0) + 0.5
            dbgDrawTick = true
        end
    end

    for _, cardInstance in ipairs(self.cardInstances) do
        if cardInstance and cardInstance.draw then
            -- F2: anim e affordability vêm da OFERTA da própria instância
            -- (indexar shopOffers[i] quebrava após a 1ª compra).
            local offer = cardInstance.shopOffer
            local slot = offer and offer._slot
            local anim = slot and self.cardAnimations[slot]
            local scale = anim and anim.scale or 1

            if dbgDrawTick then
                dbg("DRAW gate slot=%s scale=%.2f -> %s | x=%s y=%s+%s dissolve=%s slideY=%.1f",
                    tostring(slot), scale, (scale > 0) and "DESENHA" or "PULA",
                    tostring(cardInstance.x), tostring(cardInstance.y),
                    tostring(cardInstance._entryOy), tostring(cardInstance.dissolve),
                    self.slideOffsetY or 0)
            end
            if REWARD_DBG and scale > 0 and not cardInstance._dbgDrawn then
                cardInstance._dbgDrawn = true
                dbg("PRIMEIRO draw da carta slot=%s (t=%.2f)", tostring(slot), self.animationTime)
            end

            if scale > 0 then
                -- Impagável = carta escurecida (2º canal além do preço
                -- vermelho; pesquisa: nunca comunicar só por cor do número)
                cardInstance.saleDim = (self.mode == "shop") and offer
                    and offer.cost and self.game
                    and not self.game.economySystem:canAfford(offer.cost)
                    or false
                -- _entryOy: queda de entrada do modo rewards (0 após pousar).
                -- Base = homeX/homeY (âncora IMUTÁVEL) — nunca self.x/y, que o
                -- Card:draw sobrescreve a cada frame (feedback loop y+=entryOy
                -- mandava as cartas pra y≈-1900; bug "não renderizam").
                local pos = {x = cardInstance.homeX or cardInstance.x,
                             y = (cardInstance.homeY or cardInstance.y)
                                 + (cardInstance._entryOy or 0)}
                cardInstance:draw(pos.x, pos.y, false, true)
                self:drawPriceOverlay(cardInstance, pos.x, pos.y, slot)
                -- Badges de clareza no modo rewards: raridade NOMEADA +
                -- afinidade com o deck (modo shop fica como está — F13).
                if self.mode == "rewards" then
                    self:drawRewardBadges(cardInstance, slot)
                end
            end
        end
    end

    local slotCount = self.slotCount or 3
    for _, offer in ipairs(self.shopOffers) do
        local slot = offer._slot or math.huge
        if offer.type ~= "card" and slot <= slotCount and not offer.purchased then
            local anim = self.cardAnimations[slot]
            local scale = anim and anim.scale or 1

            if scale > 0 then
                local pos = self.cardPositions[slot] or {x = 0, y = 0}
                self:drawOffer(offer, pos.x, pos.y, slot, pos.w, pos.h)
            end
        end
        -- Slot já comprado: buraco com stamp VENDIDO (posições estáveis).
        if offer.purchased and slot <= slotCount and self.cardPositions[slot] then
            self:_drawSoldSlot(self.cardPositions[slot])
        end
    end

    if self.skipButton then
        self.skipButton:draw()
    end

    if self.refreshButton then
        self.refreshButton:draw()
    end

    self:drawInstructions()

    -- Fecha o push do slide.
    love.graphics.pop()

    -- ========== SEGUNDA PASS: Tooltip overlay (F10.2) ==========
    -- Tooltip de hover desenhado AQUI (após cards, packs, vouchers, buttons),
    -- F13: tooltip default DESABILITADO no shop. Hover panels laterais
    -- (_drawHoverInfoPanels) já mostram nome/desc/preview fora da janela —
    -- tooltip duplicaria info e cobriria as cartas adjacentes.
    -- Mantemos o método pra eventual re-enable em outro contexto.

    -- Hover info panels (FORA do shop window, esquerda + direita). Mostra
    -- info detalhada e preview ampliado da carta sob o mouse. (Só na LOJA —
    -- em rewards o hover usa o tooltip canônico abaixo.)
    self:_drawHoverInfoPanels()

    -- REWARDS: tooltip canônico do jogo (o mesmo da mão/deck viewer) acima
    -- da carta em hover — some quando há seleção ativa (os botões mandam).
    if self.mode == "rewards" and self.hoveredInst and not self.selectedOffer then
        local inst = self.hoveredInst
        self.cardInfoDisplay:draw(inst, inst.x or 0, inst.y or 0, {
            showRarity = false,   -- o pill de raridade já está acima da carta
            showStats = true,
            showDescription = true,
        })
    end

    -- Selection overlay (CLICK): halo pulsante + mini-buttons Balatro-style
    -- (UI_definitions.lua:382 card_focus_button) attached compactos sob a carta.
    self:_drawSelectionOverlay()

    -- FX de compra por cima de tudo (carta voando pro deck + popups -$N).
    self:_drawPurchaseFx()

    -- Inspeção completa (clique DIREITO numa oferta): mesma visão da Coleção
    -- — carta grande + painel de detalhes. Por cima de tudo.
    if self.inspectModal then
        self.inspectModal:update(love.timer.getDelta())
        self.inspectModal:draw()
    end
end

-- F10.3 + F11.2 → design system Jul/2026: o painel Balatro-style virou o
-- CANÔNICO do jogo e mora em src/ui/UiPanel.lua (fonte única com PauseMenu
-- e futuras telas). Este método é só o adapter do call site legado.
function CardRewardScreen:_drawPanel(x, y, w, h, depth)
    local UiPanel = require("src.ui.UiPanel")
    UiPanel.draw(x, y, w, h, { depth = depth or "main" })
end

-- F10.3: Title bar dourado no topo do painel principal com nome da loja +
-- ouro à direita. Fica DENTRO do painel principal (não solto na cena).
function CardRewardScreen:_drawTitleBar(panelX, panelY, panelW)
    local h = 36
    local x = panelX + 8
    local y = panelY + 6
    local w = panelW - 16

    PixelCanvas.rect(x, y, w, h, Palette.PANEL_FILL or {0.18, 0.12, 0.08, 1})
    PixelCanvas.rectOutline(x, y, w, h, Palette.AGED_GOLD or {0.78, 0.65, 0.20, 1})
    PixelCanvas.rectOutline(x + 2, y + 2, w - 4, h - 4, Palette.AGED_GOLD_DARK or {0.45, 0.32, 0.10, 1})

    -- Texto principal centralizado. Modo rewards ganha título próprio +
    -- subtítulo que diz a REGRA ("escolha 1") — a tela antiga não contava.
    local isRewards = self.mode == "rewards"
    Palette.set(Palette.AGED_GOLD_LIGHT or {1, 0.92, 0.55, 1})
    love.graphics.setFont(FontManager.getFont(14))
    local title = isRewards and I18n.t("reward.rewards_title")
        or (I18n.t("reward.shop_title") or "LOJA DE RELIQUIAS")
    love.graphics.printf(title, x, y + (isRewards and 5 or 10), w, "center")

    if isRewards then
        Palette.set(Palette.PARCHMENT or {0.85, 0.78, 0.62, 1})
        love.graphics.setFont(FontManager.getFont(8))
        love.graphics.printf(I18n.t("reward.rewards_subtitle"), x, y + 23, w, "center")
    end

    -- Ouro à direita — SÓ na loja (feedback Jul/2026: em recompensas era
    -- redundante — a TopBar já mostra, e as ofertas são grátis).
    if self.mode == "shop" and self.game and self.game.economySystem then
        local goldText = "Ouro: $" .. self.game.economySystem.currentGold
        love.graphics.setFont(FontManager.getFont(10))
        Palette.set(Palette.PARCHMENT_LIGHT or {0.92, 0.85, 0.70, 1})
        love.graphics.printf(goldText, x, y + 12, w - 12, "right")
    end

    -- "?" no canto esquerdo do title bar: explica as REGRAS de oferta (pity,
    -- afinidade, raridade por ato) em linguagem de jogador — hover abre tooltip.
    local hx, hy, hr = x + 18, y + math.floor(h / 2), 10
    love.graphics.setColor(0.10, 0.08, 0.05, 1)
    love.graphics.circle("fill", hx, hy, hr)
    Palette.set(Palette.AGED_GOLD or {0.78, 0.65, 0.20, 1})
    love.graphics.setLineWidth(1)
    love.graphics.circle("line", hx, hy, hr)
    Palette.set(Palette.AGED_GOLD_LIGHT or {1, 0.92, 0.55, 1})
    love.graphics.setFont(FontManager.getFont(11))
    love.graphics.print("?", hx - 3, hy - 8)

    -- Hitbox em coordenadas de tela: o painel desenha dentro do translate do
    -- slide — converte o mouse pro espaço local antes de comparar.
    local mx, my = love.mouse.getPosition()
    local myLocal = my - (self.slideOffsetY or 0)
    if mx >= hx - hr - 3 and mx <= hx + hr + 3
        and myLocal >= hy - hr - 3 and myLocal <= hy + hr + 3 then
        local okST, StatusTooltip = pcall(require, "src.ui.StatusTooltip")
        if okST and StatusTooltip.show then
            StatusTooltip.show("reward_rules", mx, my)
        end
    end
end

-- Banner flutuante do modo rewards (v3 StS): título grande com outline ink,
-- filetes ornamentais com losango dos dois lados, subtítulo com respiro e o
-- "?" das regras (pity/afinidade/raridade) à direita do título.
function CardRewardScreen:_drawRewardsBanner()
    local sw = love.graphics.getWidth()
    local y = self.bannerY or 80
    local cx = math.floor(sw / 2)

    local title = I18n.t("reward.rewards_title")
    local tf = FontManager.getFont(20)
    love.graphics.setFont(tf)
    local tw = tf:getWidth(title)
    local th = tf:getHeight()

    -- filetes ornamentais: linha dupla desvanecendo pra fora + losango interno
    local lineY = y + math.floor(th / 2)
    local gap = math.floor(tw / 2) + 26
    local lineW = math.min(190, math.floor(sw * 0.17))
    local g = Palette.AGED_GOLD
    for _, side in ipairs({ -1, 1 }) do
        local x0 = cx + side * gap
        local x1 = cx + side * (gap + lineW)
        for seg = 0, 7 do
            local a = 0.85 * (1 - seg / 8)
            local sx0 = x0 + side * (lineW / 8) * seg
            love.graphics.setColor(g[1], g[2], g[3], a)
            love.graphics.rectangle("fill", math.min(sx0, sx0 + side * (lineW / 8)),
                lineY - 1, lineW / 8, 2)
        end
        -- losango na ponta interna
        local px = x0 - side * 4
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.polygon("fill", px, lineY - 5 + 1, px + 5, lineY + 1,
            px, lineY + 5 + 1, px - 5, lineY + 1)
        Palette.set(Palette.AGED_GOLD_LIGHT)
        love.graphics.polygon("fill", px, lineY - 5, px + 5, lineY,
            px, lineY + 5, px - 5, lineY)
    end

    -- título: outline ink 4-direções + face dourada (mesma linguagem do boot)
    local tx = cx - math.floor(tw / 2)
    love.graphics.setColor(0, 0, 0, 0.85)
    for _, o in ipairs({ {2, 0}, {-2, 0}, {0, 2}, {0, -2}, {2, 2} }) do
        love.graphics.print(title, tx + o[1], y + o[2])
    end
    Palette.set(Palette.AGED_GOLD_LIGHT)
    love.graphics.print(title, tx, y)

    -- subtítulo com RESPIRO (feedback: "texto meio apertado")
    local sub = I18n.t("reward.rewards_subtitle")
    local sf = FontManager.getFont(9)
    love.graphics.setFont(sf)
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.print(sub, cx - math.floor(sf:getWidth(sub) / 2) + 1, y + th + 15)
    Palette.set(Palette.PARCHMENT_LIGHT)
    love.graphics.print(sub, cx - math.floor(sf:getWidth(sub) / 2), y + th + 14)

    -- "?" das regras à direita do filete (tooltip de pity/afinidade)
    local hx = cx + gap + lineW + 22
    local hy = lineY
    local hr = 10
    love.graphics.setColor(0.10, 0.08, 0.05, 0.9)
    love.graphics.circle("fill", hx, hy, hr)
    Palette.set(Palette.AGED_GOLD)
    love.graphics.setLineWidth(1)
    love.graphics.circle("line", hx, hy, hr)
    Palette.set(Palette.AGED_GOLD_LIGHT)
    love.graphics.setFont(FontManager.getFont(11))
    love.graphics.print("?", hx - 3, hy - 8)
    local mx, my = love.mouse.getPosition()
    local myLocal = my - (self.slideOffsetY or 0)
    if mx >= hx - hr - 3 and mx <= hx + hr + 3
        and myLocal >= hy - hr - 3 and myLocal <= hy + hr + 3 then
        local okST, StatusTooltip = pcall(require, "src.ui.StatusTooltip")
        if okST and StatusTooltip.show then
            StatusTooltip.show("reward_rules", mx, my)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Badges do modo rewards: pill de raridade NOMEADA na folga superior do slot
-- (a carta ocupa ~86% — sobra espaço real) + pill "AFINIDADE" na folga
-- inferior quando a oferta foi puxada pelas tags fortes do deck (Step 2).
-- Clareza: raridade não é só uma borda colorida; afinidade não é mágica.
function CardRewardScreen:drawRewardBadges(cardInstance, slot)
    local offer = cardInstance.shopOffer
    if not offer or offer.purchased then return end
    -- Carta ainda caindo (entrada animada): marcadores esperam ela pousar.
    if (cardInstance._entryOy or 0) > 1 then return end
    local pos = self.cardPositions[slot]
    if not pos then return end
    local w = pos.w or self.cardWidth
    local h = pos.h or self.cardHeight

    -- Reforma v3 (feedback: "só um quadrado com texto, feio"): marcador SEM
    -- caixa — texto colorido com outline ink e LOSANGOS dos dois lados
    -- (◆ RARA ◆), mesma linguagem ornamental do banner.
    local function marker(cx, cy, text, color, fontSize, dia)
        local f = FontManager.getFont(fontSize)
        love.graphics.setFont(f)
        local tw = f:getWidth(text)
        local fh = f:getHeight()
        -- losangos
        local dx = math.floor(tw / 2) + 12
        for _, sx in ipairs({ -1, 1 }) do
            local px = cx + sx * dx
            love.graphics.setColor(0, 0, 0, 0.8)
            love.graphics.polygon("fill", px, cy - dia + 1, px + dia, cy + 1,
                px, cy + dia + 1, px - dia, cy + 1)
            love.graphics.setColor(color[1], color[2], color[3], 1)
            love.graphics.polygon("fill", px, cy - dia, px + dia, cy,
                px, cy + dia, px - dia, cy)
        end
        -- texto com outline ink
        local tx = cx - math.floor(tw / 2)
        local ty = cy - math.floor(fh / 2)
        love.graphics.setColor(0, 0, 0, 0.85)
        for _, o in ipairs({ {1, 0}, {-1, 0}, {0, 1}, {0, -1} }) do
            love.graphics.print(text, tx + o[1], ty + o[2])
        end
        love.graphics.setColor(color[1], color[2], color[3], 1)
        love.graphics.print(text, tx, ty)
    end

    if offer.rarity then
        local label = (I18n.t("rarity." .. offer.rarity, nil, offer.rarity)):upper()
        marker(pos.x + math.floor(w / 2), pos.y - 15, label,
            Palette.forRarity(offer.rarity), 9, 4)
    end

    if offer.affinity then
        marker(pos.x + math.floor(w / 2), pos.y + h + 15,
            I18n.t("reward.affinity_badge"), Palette.AGED_GOLD_LIGHT, 8, 3)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Tooltip de carta em pass separado pra ficar acima de tudo (F10.2). Calcula
-- posição relativa à carta, idêntico ao que Card:draw fazia inline.
function CardRewardScreen:_drawCardTooltipOverlay(cardInstance)
    if not cardInstance.cardInfoDisplay then return end

    -- Posição: ABAIXO da carta (smart positioning fará fallback acima se
    -- ultrapassar bottom da tela). Usa renderX/Y se Card tem interpolação,
    -- senão x/y direto.
    local px = cardInstance.renderX or cardInstance.x or 0
    local py = cardInstance.renderY or cardInstance.y or 0

    cardInstance.cardInfoDisplay:draw(cardInstance, px, py, {
        showRarity = false,
        showStats = true,
        showDescription = true,
    })
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

    local padX, padY = 20, 8
    local bx, by = titleX - padX, titleY - padY
    local bw, bh = titleWidth + padX * 2, titleFont:getHeight() + padY * 2
    PixelCanvas.rect(bx, by, bw, bh, Palette.PANEL_FILL)
    PixelCanvas.rectOutline(bx, by, bw, bh, Palette.PANEL_OUTLINE)
    PixelCanvas.rectOutline(bx + 2, by + 2, bw - 4, bh - 4, Palette.PANEL_OUTLINE_INNER)

    Palette.set(Palette.AGED_GOLD_LIGHT)
    love.graphics.print(title, titleX, titleY)

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

function CardRewardScreen:drawOffer(offer, x, y, index, customW, customH)
    local canAfford = self.game and self.game.economySystem:canAfford(offer.cost)
    local w = customW or self.cardWidth
    local h = customH or self.cardHeight

    -- Booster pack: usa o sleeve PixelLab via PackSleeve em vez de retângulo plano.
    -- Sleeve preenche o slot inteiro, preço fica overlaid embaixo.
    if offer.type == "booster_pack" then
        local PackSleeve = require("src.ui.PackSleeve")
        local sleeveW, sleeveH = PackSleeve.getDimensions()

        -- Header (nome) ocupa top ~16px; price banner ocupa bottom 22px.
        -- Sleeve preenche o resto centralizado.
        local headerH = 16
        local priceH = 22
        local availH = h - headerH - priceH - 8
        local availW = w - 8
        local scale = math.min(availW / sleeveW, availH / sleeveH)

        local cx = math.floor(x + w * 0.5)
        local cy = math.floor(y + headerH + 4 + (sleeveH * scale) * 0.5)
        PackSleeve.drawAt(offer.id, offer.kind, cx, cy, scale, 1)

        -- Nome do pack no topo do slot (dentro).
        Palette.set(Palette.AGED_GOLD_LIGHT)
        love.graphics.setFont(FontManager.getFont(9))
        love.graphics.printf(offer.name, x + 4, y + 4, w - 8, "center")

        -- Preço banner no rodapé do slot.
        local pricecolor = canAfford and Palette.AGED_GOLD or Palette.BLOOD
        local bx = math.floor(x + 4)
        local by = math.floor(y + h - priceH - 4)
        PixelCanvas.rect(bx, by, math.floor(w - 8), priceH, Palette.PANEL_FILL)
        PixelCanvas.rectOutline(bx, by, math.floor(w - 8), priceH, pricecolor)
        Palette.set(canAfford and Palette.AGED_GOLD_LIGHT or Palette.BLOOD)
        -- Fonte 11: no tamanho 10 o glifo "6" da fonte pixel rasteriza como "G".
        love.graphics.setFont(FontManager.getFont(11))
        love.graphics.printf("$" .. offer.cost, bx, by + 5, math.floor(w - 8), "center")
        return
    end

    -- Upgrade (voucher) ou outro: card-style frame.
    PixelCanvas.rect(math.floor(x), math.floor(y), math.floor(w), math.floor(h), Palette.PANEL_FILL)
    PixelCanvas.rectOutline(math.floor(x), math.floor(y), math.floor(w), math.floor(h),
        canAfford and Palette.AGED_GOLD or Palette.BLOOD)

    local displayName = offer.type == "card" and I18n.cardName({ id = offer.id, name = offer.name }) or offer.name
    local displayDesc = offer.type == "card" and I18n.cardDesc({ id = offer.id, description = offer.description }) or offer.description
    Palette.set(Palette.PARCHMENT_LIGHT)
    love.graphics.setFont(FontManager.getFont(10))
    love.graphics.printf(displayName, x + 8, y + 12, w - 16, "center")

    -- Voucher: sprite PixelLab específico do offer.id ocupa o centro.
    -- Fallback: texto "✦ VOUCHER ✦" se o PNG não foi gerado pra esse id.
    if offer.type == "upgrade" then
        local spritePath = "assets/sprites/vouchers/" .. tostring(offer.id) .. ".png"
        -- tryGet: miss = nil (o get() devolvia o FALLBACK theRock e o
        -- voucher sem arte mostrava a carta placeholder antiga na loja)
        local sprite = ImageCache.tryGet(spritePath)
        local hasSprite = sprite ~= nil
        -- Layout: nome no topo, sprite centralizado vertical+horizontal, desc+preço no rodapé.
        -- Slots de Y: nameTop(28) → spriteArea(meio) → descBottom(38) → priceBottom(24).
        local nameTopH   = 28      -- de y+8 até y+28 reserva pro nome
        local descBottomH = 38     -- desc fica acima do preço
        local priceBottomH = 24    -- preço no rodapé
        local spriteAreaY = y + nameTopH
        local spriteAreaH = h - nameTopH - descBottomH - priceBottomH
        if hasSprite and spriteAreaH > 16 then
            local sw, sh = sprite:getWidth(), sprite:getHeight()
            -- Aproveita melhor o espaço: padding lateral 12px, vertical 4px.
            local areaW = w - 24
            local areaH = spriteAreaH - 8
            local rawScale = math.min(areaW / sw, areaH / sh)
            -- Pixel art prefere integer scale, mas se area < sprite usa float pra caber.
            local scale = rawScale >= 1 and math.floor(rawScale) or rawScale
            local drawW = sw * scale
            local drawH = sh * scale
            local dx = math.floor(x + (w - drawW) / 2)
            local dy = math.floor(spriteAreaY + 4 + (areaH - drawH) / 2)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(sprite, dx, dy, 0, scale, scale)
        end

        -- Descrição compacta acima do preço (não no meio como antes).
        Palette.set(Palette.PARCHMENT)
        love.graphics.setFont(FontManager.getFont(8))
        love.graphics.printf(displayDesc, x + 6, y + h - descBottomH, w - 12, "center")
    else
        Palette.set(Palette.PARCHMENT)
        love.graphics.setFont(FontManager.getFont(8))
        love.graphics.printf(displayDesc, x + 8, y + 36, w - 16, "center")
    end

    -- Tag visual no header: rarity p/ cards, BOOSTER p/ packs, UPGRADE p/ vouchers.
    if offer.type == "card" and offer.rarity then
        Palette.set(Palette.forRarity(offer.rarity))
        love.graphics.rectangle("fill", math.floor(x + 6), math.floor(y + 4), math.floor(w - 12), 3)
    elseif offer.type == "upgrade" then
        Palette.set(Palette.MOSS or {0.4, 0.65, 0.35, 1})
        love.graphics.rectangle("fill", math.floor(x + 6), math.floor(y + 4), math.floor(w - 12), 3)
    end

    Palette.set(canAfford and Palette.AGED_GOLD_LIGHT or Palette.BLOOD)
    -- Fonte 11: no tamanho 10 o glifo "6" da fonte pixel rasteriza como "G".
    love.graphics.setFont(FontManager.getFont(11))
    love.graphics.printf("$" .. offer.cost, x + 8, y + h - 24, w - 16, "center")
end

-- Medalhão dourado canto superior-direito da carta. Inspirado em Balatro
-- create_shop_card_ui (UI_definitions.lua:802-880) que usa UIBox flutuante
-- com DynaText `$<cost>`. Aqui simplificamos com disco + texto centrado.
-- Tem halo glow externo, disco principal, outline preto, $N centralizado.
-- Estado: dourado se canAfford, blood-red se não.
function CardRewardScreen:drawPriceOverlay(cardInstance, x, y, index)
    local offer = cardInstance.shopOffer
    if not offer or offer.purchased then return end
    -- Recompensa grátis (rewards mode): sem medalhão de preço.
    if (offer.cost or 0) <= 0 then return end

    local canAfford = self.game and self.game.economySystem:canAfford(offer.cost)

    -- Posição: canto superior-direito da carta. Coordenadas em screen-space.
    local imgW = cardInstance.image:getWidth() * (cardInstance.currentScale or 1)
    local cx = math.floor(x + imgW - 14)
    local cy = math.floor(y + 14)
    local r = 14

    -- Sombra atrás do disco (offset 2,2).
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.circle("fill", cx + 2, cy + 2, r + 1)

    -- Halo externo glow (cor combina com afford).
    if canAfford then
        love.graphics.setColor(1.0, 0.85, 0.30, 0.45)
    else
        love.graphics.setColor(0.85, 0.18, 0.18, 0.45)
    end
    love.graphics.circle("fill", cx, cy, r + 3)

    -- Disco principal.
    if canAfford then
        love.graphics.setColor(0.95, 0.78, 0.25, 1)
    else
        love.graphics.setColor(0.55, 0.14, 0.10, 1)
    end
    love.graphics.circle("fill", cx, cy, r)

    -- Borda interna mais clara (highlight).
    love.graphics.setColor(canAfford and {1, 0.92, 0.55, 0.6} or {0.85, 0.30, 0.20, 0.6})
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", cx, cy, r - 1)

    -- Outline externo escuro pra contrastar com fundo claro.
    love.graphics.setColor(0.05, 0.04, 0.02, 1)
    love.graphics.setLineWidth(1.5)
    love.graphics.circle("line", cx, cy, r)

    -- Texto $N centralizado. Cor escura sobre dourado, clara sobre vermelho.
    local font = FontManager.getFont(11)
    love.graphics.setFont(font)
    local txt = "$" .. tostring(offer.cost)
    local tw = font:getWidth(txt)
    local th = font:getHeight()
    if canAfford then
        love.graphics.setColor(0.10, 0.06, 0.02, 1)
    else
        love.graphics.setColor(1, 0.95, 0.85, 1)
    end
    love.graphics.print(txt, cx - tw * 0.5, cy - th * 0.5)
    love.graphics.setColor(1, 1, 1, 1)
end

-- LEGACY: drawPurchaseConfirmation (modal centralizado) removido. Substituído
-- pelo _drawSelectionOverlay (3-zone Balatro pattern). Mantido como stub no-op
-- caso algum call site externo ainda chame.
function CardRewardScreen:drawPurchaseConfirmation() end

-- ============================================================================
-- SELECTION (CLICK) — mini-buttons Balatro-style sob a carta
-- ============================================================================
-- Quando uma carta é clicada (setSelectedOffer), desenha:
--   1) Halo dourado pulsante na carta (feedback visual de selecionada).
--   2) Mini-buttons compactos (BUY $N + X) attached embaixo da carta.
-- Os painéis info (left) e preview (right) NÃO são parte deste overlay —
-- são driven por hover separadamente (_drawHoverInfoPanels).
function CardRewardScreen:_drawSelectionOverlay()
    local anim = self._selectionAnim or 0
    if anim < 0.01 and not self.selectedOffer then return end
    if not self.selectedOffer or not self.selectedIdx then return end

    local pos = self.cardPositions[self.selectedIdx]
    if not pos then return end
    local anchorW = pos.w or self.cardWidth
    local anchorH = pos.h or self.cardHeight
    local anchorX = pos.x
    local anchorY = pos.y

    -- Halo dourado pulsante na carta selecionada.
    local haloAlpha = 0.55 * anim * (0.7 + 0.3 * math.sin(love.timer.getTime() * 3.5))
    love.graphics.setColor(Palette.AGED_GOLD[1], Palette.AGED_GOLD[2], Palette.AGED_GOLD[3], haloAlpha)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", anchorX - 3, anchorY - 3, anchorW + 6, anchorH + 6)
    love.graphics.setColor(Palette.AGED_GOLD_LIGHT[1], Palette.AGED_GOLD_LIGHT[2], Palette.AGED_GOLD_LIGHT[3], haloAlpha * 0.6)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", anchorX - 1, anchorY - 1, anchorW + 2, anchorH + 2)

    -- Buttons attached (criados em _buildSelectionButtons). Reposiciona a cada
    -- frame pra acompanhar mudanças de layout. Larguras podem ser diferentes
    -- entre buy (largo, mostra $N) e cancel (estreito, só X).
    if self._selectionButtons and #self._selectionButtons > 0 then
        local gap = 6
        local totalW = 0
        for _, b in ipairs(self._selectionButtons) do
            totalW = totalW + b.width
        end
        totalW = totalW + (#self._selectionButtons - 1) * gap
        local bx0 = math.floor(anchorX + (anchorW - totalW) / 2)
        local by0 = math.floor(anchorY + anchorH + 8)
        local cursorX = bx0
        for _, b in ipairs(self._selectionButtons) do
            b.x = cursorX
            b.y = by0
            b:draw()
            cursorX = cursorX + b.width + gap
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================================
-- HOVER INFO PANELS — aparecem FORA da janela da loja
-- ============================================================================
-- Quando o mouse pasa sobre uma carta/voucher/pack, aparecem 2 painéis:
--   LEFT  — info (nome + tipo + descrição) à ESQUERDA do shop panel
--   RIGHT — preview ampliado da carta à DIREITA do shop panel
-- Posicionados FORA do shop panel pra não cobrir nada do conteúdo principal.
-- Se a tela é estreita demais, eles podem ficar parcialmente fora — caller
-- pode reduzir scale do preview ou limitar largura do info.
function CardRewardScreen:_drawHoverInfoPanels()
    -- Reforma Jul/2026 (feedback: painel esquerdo "espremido" + "foto" solta
    -- na direita): em REWARDS os painéis laterais morreram — o hover usa o
    -- tooltip canônico do jogo (CardInfoDisplay) acima da carta, e o clique
    -- DIREITO abre a inspeção completa (mesma da Coleção). Loja mantém.
    if self.mode == "rewards" then return end
    local anim = self._hoverAnim or 0
    if anim < 0.01 and not self.hoveredOffer then return end
    if not self.hoveredOffer or not self.hoveredInst then return end

    local offer = self.hoveredOffer
    local cardInst = self.hoveredInst
    if not cardInst then return end
    if not self.panel then return end

    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local p = self.panel
    local gap = 16

    -- ===== LEFT panel: info =====
    local panelW = math.min(280, p.x - 10)  -- não vaza pra esquerda da tela
    if panelW > 80 then  -- só desenha se tem espaço útil
        local panelH = math.min(p.h, 320)
        local panelX = p.x - panelW - gap
        local panelY = p.y + (p.h - panelH) / 2
        -- slide-in horizontal
        panelX = panelX - (1 - anim) * 16

        love.graphics.setColor(Palette.INK[1], Palette.INK[2], Palette.INK[3], 0.94 * anim)
        love.graphics.rectangle("fill", panelX, panelY, panelW, panelH)
        love.graphics.setColor(Palette.AGED_GOLD[1], Palette.AGED_GOLD[2], Palette.AGED_GOLD[3], anim)
        love.graphics.rectangle("line", panelX, panelY, panelW, panelH)
        love.graphics.setColor(Palette.AGED_GOLD_DARK[1], Palette.AGED_GOLD_DARK[2], Palette.AGED_GOLD_DARK[3], anim)
        love.graphics.rectangle("line", panelX + 2, panelY + 2, panelW - 4, panelH - 4)

        local PAD = 14
        local TEXT_W = panelW - PAD * 2

        -- Nome
        love.graphics.setColor(Palette.AGED_GOLD_LIGHT[1], Palette.AGED_GOLD_LIGHT[2], Palette.AGED_GOLD_LIGHT[3], anim)
        love.graphics.setFont(FontManager.getFont(13))
        local displayName = offer.type == "card"
            and I18n.cardName({ id = offer.id, name = offer.name })
            or offer.name
        love.graphics.printf(displayName, panelX + PAD, panelY + 14, TEXT_W, "left")

        -- Tipo + custo
        love.graphics.setColor(Palette.PARCHMENT[1], Palette.PARCHMENT[2], Palette.PARCHMENT[3], 0.85 * anim)
        love.graphics.setFont(FontManager.getFont(9))
        local typeLabel = offer.type == "upgrade" and "Voucher"
                       or offer.type == "booster_pack" and "Booster Pack"
                       or offer.type == "card" and "Carta"
                       or "Item"
        local priceLabel = (offer.cost or 0) > 0
            and ("$" .. tostring(offer.cost)) or "Gratis"
        love.graphics.printf(typeLabel .. "  ·  " .. priceLabel,
                             panelX + PAD, panelY + 50, TEXT_W, "left")

        -- Afinidade: POR QUE esta carta apareceu (tags fortes do seu deck).
        if offer.affinity and offer.affinityTags then
            love.graphics.setColor(Palette.AGED_GOLD_LIGHT[1], Palette.AGED_GOLD_LIGHT[2],
                Palette.AGED_GOLD_LIGHT[3], anim)
            love.graphics.setFont(FontManager.getFont(8))
            love.graphics.printf(
                I18n.t("reward.affinity_line", { tags = table.concat(offer.affinityTags, ", ") }),
                panelX + PAD, panelY + 62, TEXT_W, "left")
        end

        -- Separador
        love.graphics.setColor(Palette.AGED_GOLD[1], Palette.AGED_GOLD[2], Palette.AGED_GOLD[3], 0.6 * anim)
        love.graphics.rectangle("fill", panelX + PAD, panelY + 72, TEXT_W, 1)

        -- Descrição
        love.graphics.setColor(Palette.PARCHMENT_LIGHT[1], Palette.PARCHMENT_LIGHT[2], Palette.PARCHMENT_LIGHT[3], 0.95 * anim)
        love.graphics.setFont(FontManager.getFont(10))
        local displayDesc = offer.type == "card"
            and I18n.cardDesc({ id = offer.id, description = offer.description })
            or offer.description
        love.graphics.printf(displayDesc or "", panelX + PAD, panelY + 86, TEXT_W, "left")
    end

    -- ===== RIGHT panel: preview ampliado =====
    local availRight = sw - (p.x + p.w) - 10
    if availRight > 100 and cardInst.image then
        local previewScale = math.min(1.6, availRight / cardInst.image:getWidth())
        local previewW = cardInst.image:getWidth() * previewScale
        local previewH = cardInst.image:getHeight() * previewScale
        local previewX = p.x + p.w + gap + (1 - anim) * 16
        local previewY = p.y + (p.h - previewH) / 2

        love.graphics.setColor(0, 0, 0, 0.5 * anim)
        love.graphics.rectangle("fill", previewX + 6, previewY + 8, previewW, previewH)
        love.graphics.setColor(1, 1, 1, anim)
        love.graphics.draw(cardInst.image, previewX, previewY, 0, previewScale, previewScale)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- Atualiza estado de hover lendo cardInstance.isHovered. Chamado em :update.
function CardRewardScreen:_updateHoverState()
    local newHovered = nil
    local newInst = nil
    for _, inst in ipairs(self.cardInstances or {}) do
        if inst and inst.isHovered then
            -- F2: a oferta vem da própria instância (shopOffers[i] mostrava
            -- a info da carta ERRADA depois de uma compra).
            local offer = inst.shopOffer
            if offer and not offer.purchased then
                newHovered = offer
                newInst = inst
                break
            end
        end
    end
    if newHovered ~= self.hoveredOffer then
        self.hoveredOffer = newHovered
        self.hoveredInst = newInst
        local target = newHovered and 1 or 0
        if EventManager and EventManager.parallelEase then
            EventManager.parallelEase(self, "_hoverAnim", target, 0.12, "smooth", "shop_hover")
        else
            self._hoverAnim = target
        end
    end
end

function CardRewardScreen:drawInstructions()
    -- F1 do UI Overhaul: HintBar padronizada — SEMPRE cabe na tela (o texto
    -- antigo estourava dos dois lados e atropelava o botão Pular)
    HintBar.draw(I18n.t("reward.instructions"))
end

function CardRewardScreen:mousepressed(x, y, button)
    if not self.visible then return false end

    -- Inspeção aberta consome tudo (clique nas setas/fora fecha — igual Coleção).
    if self.inspectModal and self.inspectModal:isVisible() then
        self.inspectModal:mousepressed(x, y, button)
        return true
    end

    -- Clique DIREITO numa oferta → inspeção completa (mesma da Coleção).
    if button == 2 then
        for _, inst in ipairs(self.cardInstances or {}) do
            if inst and inst.isHovered and inst.shopOffer
                and not inst.shopOffer.purchased then
                self.inspectModal = self.inspectModal
                    or require("src.ui.CardInspectModal"):new()
                self.inspectModal:show(inst)
                return true
            end
        end
    end

    -- Selection buttons attached na carta selecionada têm prioridade —
    -- consomem o click antes dos cardButtons (que ficariam re-selecionando).
    if self._selectionButtons then
        for _, b in ipairs(self._selectionButtons) do
            if b:mousepressed(x, y, button) then return true end
        end
    end

    for _, cardButton in ipairs(self.cardButtons) do
        if cardButton:mousepressed(x, y, button) then
            return true
        end
    end

    if self.skipButton and self.skipButton:mousepressed(x, y, button) then
        return true
    end

    if self.refreshButton and self.refreshButton:mousepressed(x, y, button) then
        return true
    end

    -- Click fora de qualquer card/button enquanto há seleção → desselleciona
    -- (Balatro: re-clicar na mesma carta também alterna; aqui aceitamos ambos).
    if self.selectedOffer then
        self:clearSelection()
        return true
    end

    return false
end

function CardRewardScreen:mousereleased(x, y, button)
    if not self.visible then return false end

    -- Inspeção aberta: engole releases (nada atrás pode reagir).
    if self.inspectModal and self.inspectModal:isVisible() then
        return true
    end

    if self._selectionButtons then
        for _, b in ipairs(self._selectionButtons) do
            if b:mousereleased(x, y, button) then return true end
        end
    end

    for _, cardButton in ipairs(self.cardButtons) do
        if cardButton:mousereleased(x, y, button) then
            return true
        end
    end

    if self.skipButton and self.skipButton:mousereleased(x, y, button) then
        return true
    end

    if self.refreshButton and self.refreshButton:mousereleased(x, y, button) then
        return true
    end

    return false
end

-- drawRarityBorder removida em F10.1 (poluição visual). Cards agora não têm
-- halo pulsante de raridade. Se voltar a precisar, recriar dentro do CardFrame
-- como acabamento sutil de borda (não animação fullscreen).

function CardRewardScreen:isVisible()
    return self.visible
end

-- Desliza loja pra fora da tela (Fase 7.4 do refactor Balatro). Chamado quando
-- pack opening assume o foco. Padrão Balatro: shop fica off-screen embaixo
-- (não usa backdrop preto sobre ela).
function CardRewardScreen:slideOut()
    if not self.visible then return end
    local h = love.graphics.getHeight()
    EventManager.parallelEase(self, "slideOffsetY", h, 0.45, "smooth", FXQ)
end

-- Volta a loja pro lugar quando pack fecha.
function CardRewardScreen:slideIn()
    if not self.visible then return end
    EventManager.parallelEase(self, "slideOffsetY", 0, 0.45, "smooth", FXQ)
end

return CardRewardScreen
