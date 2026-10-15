local CardRewardScreen = {}
CardRewardScreen.__index = CardRewardScreen

local FXQ = "reward_fx"

local REWARD_DBG = require("src.core.Debug").enabled
local _dbgStart = 0

local function dbg(fmt, ...)
    if not REWARD_DBG then return end
    local ok, line = pcall(string.format, fmt, ...)
    if not ok then line = fmt .. " (fmt err)" end
    local t = love.timer.getTime() - _dbgStart
    line = string.format("[RDBG %+7.2fs] %s", t, line)
    pcall(love.filesystem.append, "reward_debug.log", line .. "\n")
end

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
local Palette = require("src.ui.Palette")
local PixelCanvas = require("src.ui.PixelCanvas")
local Button = require("components.Button")
local CardDatabase = require("src.systems.CardDatabase")
local CardInfoDisplay = require("src.ui.CardInfoDisplay")
local CardDetailPanel = require("src.ui.CardDetailPanel")
local UpgradeTile = require("src.ui.UpgradeTile")
local ShopEngraving = require("src.ui.ShopEngraving")
local Moveable = require("engine.Moveable")
local I18n = require("src.i18n.I18n")
local Sfx = require("src.systems.Sfx")
local EventManager = require("engine.EventManager")
local DissolveShader = require("src.ui.DissolveShader")
local ImageCache = require("src.ui.ImageCache")
local ShopServices = require("src.systems.ShopServices")
local ShopScene = require("src.ui.shop.ShopScene")
local ShopLayout = require("src.ui.shop.ShopLayout")
local RareReveal = require("src.ui.RareReveal")

local RARE_PAUSE = 0.35

local function reducedMotion()
    return (_G.gameSettings and _G.gameSettings.reducedMotion) or false
end

local _sfxWarned = {}
local function playFirstSfx(codes, opts)
    for _, code in ipairs(codes) do
        if Sfx.has(code) then
            Sfx.play(code, opts)
            return code
        end
    end
    if _G.audioSystem then
        local key = table.concat(codes, "/")
        if not _sfxWarned[key] then
            _sfxWarned[key] = true
            Debug.warn("[CardRewardScreen] nenhum sfx registrado em: " .. key)
        end
    end
    return nil
end

local SHOP_HOVER_LIFT = 12

local function offerKind(offer)
    if not offer then return nil end
    if offer.type == "booster_pack" then return "pack" end
    if offer.type == "upgrade" then return "voucher" end
    return "card"
end

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

    instance.selectedOffer = nil
    instance.selectedIdx = nil
    instance._selectionAnim = 0
    instance._selectionButtons = {}
    instance.hoveredOffer = nil
    instance.hoveredIdx = nil
    instance.hoveredInst = nil
    instance.hoveredKind = nil
    instance.detailPayload = nil
    instance._lastDetailPayload = nil
    instance._detailStale = false
    instance._detailAnim = 1

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

function CardRewardScreen:updateLayout()
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()
    ShopEngraving.clearCache()
    local cfg = self.modeConfig or { cards = 3, upgrades = 0, boosters = 0 }
    self.layoutMode = self.mode

    self.cardPositions = {}

    if self.mode == "shop" then
        self.scene = self.scene or ShopScene.new(self)
        local L = self.scene:layout()
        self.panel = L.wall
        self.cardWidth, self.cardHeight = L.cardW, L.cardH
        self.slotLabelH = 0

        local nCards = cfg.cards or 4
        local nVouchers = cfg.upgrades or 3
        local nPacks = cfg.boosters or 1
        for i = 1, nCards do
            local c = L.cards[i]
            if c then
                self.cardPositions[i] = { x = c.rect.x, y = c.rect.y, w = c.rect.w, h = c.rect.h,
                                          row = 1, kind = "card" }
            end
        end
        for j = 1, nVouchers do
            local r = L.relics[j]
            if r then
                self.cardPositions[nCards + j] = { x = r.rect.x, y = r.rect.y, w = r.rect.w, h = r.rect.h,
                                                   row = 2, kind = "voucher" }
            end
        end
        for p = 1, nPacks do
            if p == 1 then
                local r = L.pack.rect
                self.cardPositions[nCards + nVouchers + p] = { x = r.x, y = r.y, w = r.w, h = r.h,
                                                               row = 2, kind = "pack" }
            end
        end
        self.slotCount = nCards + nVouchers + nPacks

        self.gridArea = { x = L.wall.x, y = L.wall.y, w = L.limitX - L.wall.x, h = L.wall.h }
        self.detailPanel = L.scroll.body
        self.detailFooterH = 0
        self.actionBar = L.continueBtn
        self.cardsContainer = nil
        self.voucherContainer = nil
        self.packsContainer = nil
        self.buttonsContainer = nil
        self.buttonsColX = nil
        self.buttonsColY = nil
        self.skipButtonX = L.continueBtn.x
        self.skipButtonY = L.continueBtn.y

    else
        self.panel = nil
        self.cardsContainer = nil
        self.buttonsContainer = nil
        self.voucherContainer = nil
        self.packsContainer = nil
        self.gridArea = nil
        self.detailPanel = nil
        self.actionBar = nil
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

        self.skipButtonX = math.floor(sw * 0.5) - 100
        self.skipButtonY = sh - 96
    end

    self:_layoutActionButtons()
    if self.selectedOffer then
        self:_buildSelectionButtons(self.selectedOffer, self.selectedIdx)
    end

end

function CardRewardScreen:validateLayout()
    local bad = {}
    local function contains(outer, inner, label)
        if not (outer and inner) then return end
        if inner.x < outer.x - 1 or inner.y < outer.y - 1
            or inner.x + inner.w > outer.x + outer.w + 1
            or inner.y + inner.h > outer.y + outer.h + 1 then
            bad[#bad + 1] = string.format(
                "%s (%d,%d %dx%d) escapa do container (%d,%d %dx%d)", label,
                inner.x, inner.y, inner.w, inner.h,
                outer.x, outer.y, outer.w, outer.h)
        end
    end

    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local screen = { x = 0, y = 0, w = sw, h = sh }
    contains(screen, self.panel, "painel")

    if self.mode == "shop" then
        local L = self.scene and self.scene.L
        if not L then
            bad[#bad + 1] = "loja sem layout (updateLayout nao rodou)"
            return bad
        end
        for _, msg in ipairs(ShopLayout.validate(L)) do bad[#bad + 1] = msg end
        if self.skipButton then
            contains(L.continueBtn, { x = self.skipButton.x, y = self.skipButton.y,
                w = self.skipButton.width, h = self.skipButton.height }, "botao CONTINUAR")
        end
        if self.buyButton then
            contains(L.scroll, { x = self.buyButton.x, y = self.buyButton.y,
                w = self.buyButton.width, h = self.buyButton.height }, "botao COMPRAR")
        end
        if self.refreshButton then
            contains(L.bell.rect, { x = self.refreshButton.x, y = self.refreshButton.y,
                w = self.refreshButton.width, h = self.refreshButton.height }, "hitbox do sino")
        end
    else
        for i = 1, (self.slotCount or 0) do
            local p = self.cardPositions[i]
            if p then
                contains(screen, {
                    x = p.x, y = p.y, w = p.w or self.cardWidth,
                    h = p.h or self.cardHeight,
                }, "carta " .. i)
            end
        end
    end

    for i = 1, (self.mode ~= "shop") and ((self.slotCount or 0) - 1) or 0 do
        local a, b = self.cardPositions[i], self.cardPositions[i + 1]
        if a and b and a.row == b.row then
            local aRight = a.x + (a.w or self.cardWidth)
            if b.x < aRight then
                bad[#bad + 1] = string.format("slots %d e %d se sobrepoem (%d > %d)",
                    i, i + 1, aRight, b.x)
            end
        end
    end

    return bad
end

local function offerNodeKey(run, mode)
    return ("%s|%d|%d|%d"):format(tostring(mode), run.actNumber or 1,
        run.floorInAct or 1, #(run.mapHistory or {}))
end
CardRewardScreen._offerNodeKey = offerNodeKey

function CardRewardScreen:_run()
    local rm = self.game and self.game.runManager
    return rm and rm.currentRun
end

function CardRewardScreen:_restoreOffers(run)
    local st = run and run.shopState
    if not st then return false end
    if st.key ~= offerNodeKey(run, self.mode) then
        run.shopState = nil
        return false
    end
    self.shopSystem:importState(st)
    Debug.log("[CardRewardScreen] vitrine restaurada do save (" .. st.key .. ")")
    return true
end

function CardRewardScreen:_persistOffers(writeNow)
    local run = self:_run()
    if not run then return end
    local st = self.shopSystem:exportState()
    st.key = offerNodeKey(run, self.mode)
    run.shopState = st
    if writeNow and self.game.checkpointRun then self.game:checkpointRun() end
end

function CardRewardScreen:_clearPersistedOffers()
    local run = self:_run()
    if run then run.shopState = nil end
end

function CardRewardScreen:show(game, onCardPurchased, onSkipped, mode)
    self.visible = true
    self.game = game
    self.onCardPurchased = onCardPurchased
    self.onSkipped = onSkipped
    self.animationTime = 0
    self.mode = mode or "rewards"

    local run = game.runManager and game.runManager.currentRun
    local ShopSystem = require("src.systems.ShopSystem")
    self.shopSystem:setContext(ShopSystem.runContext(game, self.mode))

    self.shopSystem:setMode(self.mode)
    local restored = self:_restoreOffers(run)
    if not restored then self.shopSystem:generateOffers() end
    self.shopOffers = self.shopSystem:getCurrentOffers()
    self.modeConfig = self.shopSystem:getModeConfig()

    for i, o in ipairs(self.shopOffers) do o._slot = i end

    self._flyCards = {}
    self._goldPopups = {}
    self._rewardTaken = false
    if restored and self.mode == "rewards" then
        for _, o in ipairs(self.shopOffers) do
            if o.purchased and o.type == "card" then self._rewardTaken = true end
        end
    end
    if not restored then self:_persistOffers(true) end

    self:updateLayout()
    self:createCardInstances()
    self:createOfferButtons()
    self:_resetDetail()
    if self.mode == "shop" and self.scene then self.scene:enter() end

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

    EventManager.clear(FXQ)
    EventManager.clear("reward_exit")
    self._closing = false

    self.slideOffsetY = -love.graphics.getHeight()
    EventManager.ease(self, "slideOffsetY", 0, 0.43, "smooth", FXQ)

    if self.mode == "shop" then
        Sfx.play("shopOpen")
    end

    if self.mode == "rewards" then
        local Moveable = require("engine.Moveable")
        local normal, rare = {}, {}
        for _, inst in ipairs(self.cardInstances) do
            if CardRewardScreen.isRareOffer(inst) then rare[#rare + 1] = inst else normal[#normal + 1] = inst end
        end
        for i, inst in ipairs(normal) do
            inst._entryOy = -70
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
        for k, inst in ipairs(rare) do
            self:_revealRare(inst, { delay = 0.15 + #normal * 0.13 + 0.45 + RARE_PAUSE
                + (k - 1) * (RareReveal.CHARGE + RareReveal.SIGNATURE_AT) })
        end
        dbgCards(self, "pos-show")
    end

    if self.mode ~= "rewards" and self.mode ~= "shop" then
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
                playFirstSfx({ "cardShelfPlace", "cardDraw" },
                    { pitch = 0.94 + (i - 1) * 0.05 })
            end, FXQ)
        end
    end

    local skipBonus = (self.modeConfig and self.modeConfig.skipBonus) or 0
    local skipLabel = I18n.t("reward.continue")
    if self.mode == "rewards" then
        skipLabel = I18n.t("reward.skip_no_card")
    end
    if self.mode == "shop" and skipBonus > 0 then
        skipLabel = skipLabel .. " (+$" .. skipBonus .. ")"
    end
    local skipFont = 12
    local skipW = FontManager.getFont(skipFont):getWidth(skipLabel) + 64
    skipW = math.max(200, skipW)
    local skipX = (self.panel and (self.panel.x + self.panel.w / 2) or (love.graphics.getWidth() / 2)) - skipW / 2
    local skipY, skipH = self.skipButtonY, 40
    self.skipButton = Button:new(
        skipX, skipY, skipW, skipH,
        skipLabel,
        function()
            if self._closing then return end
            if self.mode == "shop" and skipBonus > 0 and self.game.economySystem then
                self.game.economySystem:earnGold(skipBonus, "shop_skip")
            end
            self:_exitWithFlourish()
        end, nil, skipFont
    )
    self.skipButton:setIcon("arrow_right")
    if self.mode == "shop" then self.skipButton:setColorScheme("red") end

    if self.modeConfig and self.modeConfig.canReroll then
    local refreshCost = self.shopSystem:getRefreshCost()
    local rerollX = self.skipButtonX + 145
    local rerollY = self.skipButtonY
    local rerollW = 130
    local rerollH = 32
    self.refreshButton = Button:new(
        rerollX, rerollY, rerollW, rerollH,
        I18n.t("reward.refresh", { n = refreshCost }),
        function()
            local currentRefreshCost = self.shopSystem:getRefreshCost()
            if self.game.economySystem:canAfford(currentRefreshCost) then
                self.game.economySystem:spendGold(currentRefreshCost, "refresh", "shop")
                Sfx.play("shopReroll")
                self:_spawnGoldPopup(self.refreshButton.x + self.refreshButton.width / 2,
                    self.refreshButton.y, "-$" .. currentRefreshCost)
                self.shopSystem:refreshOffers()
                self.shopOffers = self.shopSystem:getCurrentOffers()
                for i, o in ipairs(self.shopOffers) do o._slot = i end
                self:_persistOffers()

                if self.scene then
                    self.scene:reroll(self.shopOffers)
                    self:_mirrorScene()
                else
                    self:createCardInstances()
                end
                self:createOfferButtons()
                self:clearSelection()
                self:_resetDetail()

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
                self:_layoutActionButtons()
            elseif self.scene then
                self.scene:onDenied(nil)
                Sfx.play("purchaseDeny")
            else
                self.game:addMessage(I18n.t("reward.refresh_fail"), "error")
                Sfx.play("purchaseDeny")
            end
        end
    )
    end

    self.buyButton = nil
    if self.mode == "shop" then
        self.buyButton = Button:new(0, 0, 160, 38, "", function()
            local toBuy = self.selectedOffer
            if not toBuy or toBuy.purchased then return end
            self:purchaseOffer(toBuy, toBuy.id)
        end, nil, 12)
        self.buyButton:setColorScheme("red")
    end

    self.diceButton = nil
    if self.mode == "shop" and _G.openScribeDice then
        self.diceButton = Button:new(0, 0, 130, 32, "", function()
            _G.openScribeDice(self.game, function() self:_refreshDiceButton() end)
        end)
        self:_refreshDiceButton()
    end

    self:_layoutActionButtons()

    for i = 1, #self.shopOffers do
        self.cardAnimations[i] = {
            scale = 0,
            targetScale = 1,
            delay = (i - 1) * 0.1,
            elapsed = 0
        }
    end
end

function CardRewardScreen.isRareOffer(inst)
    return inst ~= nil and inst.type == "joker"
end

local function rareState(inst)
    local holder = inst and (inst.shopOffer or inst)
    return holder and holder._rareReveal
end

function CardRewardScreen:_isRareHidden(offerOrInst)
    local st = offerOrInst and (offerOrInst._rareReveal or rareState(offerOrInst))
    return RareReveal.hidden(st)
end

function CardRewardScreen:_revealRare(inst, opts)
    if not inst then return nil end
    opts = opts or {}
    local holder = inst.shopOffer or inst
    local st = RareReveal.new({ delay = opts.delay or 0, reduced = reducedMotion(),
        seed = 7919 + (holder._slot or 1) * 131 })
    holder._rareReveal = st
    inst._entryOy = 0
    local function current()
        return (holder ~= inst and holder.cardInstance) or inst
    end
    st.hooks = {
        onCharge = function()
            Sfx.play("shopCrystalHum", { volume = 0.7 })
        end,
        onBurst = function(reduced)
            local c = current()
            if not reduced then
                if c.start_materialize then
                    c:start_materialize(DissolveShader.palette("joker"), true, 1.2)
                end
                Moveable.juice_up(c, 0.35, 0.1)
                Sfx.play("packSealBreak", { volume = 0.8 })
            end
            Sfx.play("cardDiscovered")
        end,
        onSignature = function()
            local c = current()
            local sig = c.id and ("jokerSig_" .. c.id)
            if sig and Sfx.has(sig) then Sfx.play(sig) else Sfx.play("jokerActivate") end
        end,
    }
    return st
end

function CardRewardScreen:_makeCardInstance(offer)
    local cardData = self.cardDatabase:getCard(offer.id)
    if not cardData then
        Debug.err("[CardRewardScreen] Card data not found for", offer.id)
        return nil
    end
    local inst = self.cardDatabase:createCardInstance(cardData)
    if not inst then
        Debug.err("[CardRewardScreen] Could not create card instance for", offer.id)
        return nil
    end
    inst.isNewDiscovery = offer.isNew or nil
    if not inst.description and offer.description then
        inst.description = offer.description
    end
    inst.isRewardCard = false
    inst.shopOffer = offer
    inst.noHoverLift = true
    if inst.cardInfoDisplay then
        inst.cardInfoDisplay:configure({ showRarity = true, showStats = true, showDescription = true })
    end
    offer.cardInstance = inst
    return inst
end

function CardRewardScreen:_mirrorScene()
    if not self.scene then return end
    self.cardInstances = self.scene:cardInstances()
end

function CardRewardScreen:createCardInstances()
    if self.mode == "shop" then
        self.scene = self.scene or ShopScene.new(self)
        self.scene:setOffers(self.shopOffers)
        self:_mirrorScene()
        return
    end
    self.cardInstances = {}

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
            cardInstance.isNewDiscovery = offer.isNew or nil
            local pos = self.cardPositions[offer._slot] or { x = 0, y = 0 }

            local imgW = cardInstance.image and cardInstance.image:getWidth() or 96
            local imgH = cardInstance.image and cardInstance.image:getHeight() or 144
            local slotW = pos.w or self.cardWidth
            local slotH = pos.h or self.cardHeight
            local fill = (self.mode == "shop") and 0.97 or 0.86
            local fitScale = math.min(slotW / imgW, slotH / imgH) * fill
            local renderW = imgW * fitScale
            local renderH = imgH * fitScale
            cardInstance.x = math.floor(pos.x + (slotW - renderW) / 2)
            cardInstance.y = math.floor(pos.y + (slotH - renderH) / 2)
            cardInstance.homeX = cardInstance.x
            cardInstance.homeY = cardInstance.y

            cardInstance.baseScale = fitScale
            cardInstance.currentScale = fitScale
            cardInstance.targetScale = fitScale
            cardInstance.noHoverLift = true

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
    if self.mode == "shop" then return end

    local maxSlots = self.slotCount or 3
    for _, offer in ipairs(self.shopOffers) do
        if not offer.purchased and (offer._slot or math.huge) <= maxSlots then
            local pos = self.cardPositions[offer._slot] or { x = 0, y = 0 }
            local btnW = pos.w or self.cardWidth
            local btnH = pos.h or self.cardHeight
            local capturedOffer = offer
            local button = Button:new(
                pos.x, pos.y, btnW, btnH,
                "",
                function()
                    if self:_isRareHidden(capturedOffer) then return end
                    self:setSelectedOffer(capturedOffer, capturedOffer._slot)
                end
            )
            button:setVariant("invisible")
            table.insert(self.cardButtons, button)
        end
    end
end

function CardRewardScreen:purchaseOffer(offer, offerId)

    if self.mode == "rewards" and self._rewardTaken then return end

    if not self.game.economySystem:canAfford(offer.cost) then
        if self.mode == "shop" and self.scene then
            self.scene:onDenied(offer)
        else
            self.game:addMessage(I18n.t("reward.insufficient_gold"), "error")
        end
        Sfx.play("purchaseDeny")
        return
    end

    if offer.type == "card" then
        local cd = self.game.deckManager.cardDatabase:getCard(offer.id)
        if cd and cd.type == "joker" and not self.game:canAcceptJoker() then
            self.game:addMessage(
                I18n.t("reward.joker_run_only", nil,
                    "Coringas so podem ser adquiridos durante uma corrida"),
                "warning")
            Sfx.play("purchaseDeny")
            return
        end
    end

    if self.game.economySystem:spendGold(offer.cost, offer.type, offer.id) then
        offer.purchased = true
        self:_persistOffers()

        if self.mode == "shop" and self.game.runManager
            and self.game.runManager.currentRun then
            self.game.runManager.currentRun._usedShop = true
        end

        if _G.jiggleScreen then _G.jiggleScreen(0.25) end

        do
            local pos = self.cardPositions[offer._slot or 0]
            if pos then
                local pw = pos.w or self.cardWidth
                self:_spawnGoldPopup(pos.x + pw - 14, pos.y + 10, "-$" .. offer.cost)
            end
        end

        if self.mode == "shop" and self.scene then
            self.scene:onPurchased(offer)
        end

        if offer.type == "card" then
            if not (self.mode == "shop" and self.scene) then self:_startFlyToDeck(offer) end
            self.game:addCardToRun(offer.id)
        elseif offer.type == "upgrade" then
            self:_startRelicFlourish(offer)
            self:applyUpgrade(offer)
        elseif offer.type == "booster_pack" then
            local BoosterPackSystem = require("src.systems.BoosterPackSystem")
            local run = self.game.runManager and self.game.runManager.currentRun
            local classId = run and run.classId
            local pack = BoosterPackSystem.expandPackRecord({
                id = offer.id, kind = offer.kind,
                size = offer.size, choose = offer.choose,
            }, classId, {
                runManager = self.game.runManager,
                actNumber = (run and run.actNumber) or 1,
            })

            if _G.openBoosterPack then
                _G.openBoosterPack(pack, function(selected)
                    for _, card in ipairs(selected or {}) do
                        if card.id then
                            self.game:addCardToRun(card.id, {
                                edition = card.edition,
                                seal = card.seal,
                            })
                        end
                    end
                end)
            else
                Debug.warn("[CardRewardScreen] _G.openBoosterPack não setado — pack ignorado")
            end
        end
        if not (self.mode == "shop" and self.scene) then Sfx.play("purchaseConfirm") end

        self:createCardInstances()
        self:createOfferButtons()

        if self.onCardPurchased then
            self.onCardPurchased(offer)
        end

        if self.mode == "shop" then
            self.selectedOffer, self.selectedIdx = nil, nil
            self:_prefocusDetail()
        end

        if self.mode == "rewards" and offer.type == "card" then
            self._rewardTaken = true
            self.cardButtons = {}
            self:clearSelection()
            self.hoveredOffer, self.hoveredInst = nil, nil
            self:_exitWithFlourish(offer.cardInstance)
        end
    end
end

function CardRewardScreen:setSelectedOffer(offer, idx)
    if not offer then return end
    if self.mode == "shop" then
        if self.selectedOffer == offer then return end
        self.selectedOffer = offer
        self.selectedIdx = idx
        self._detailPrefocus = false
        if self.scene then self.scene:_syncSelection() end
        self:_refreshBuyButton()
        Sfx.play("cardSelect", { pitch = 1.05 + (math.random() * 2 - 1) * 0.06 })
        return
    end
    if self.selectedOffer == offer then
        self:clearSelection()
        return
    end

    self.selectedOffer = offer
    self.selectedIdx = idx
    self:_buildSelectionButtons(offer, idx)

    if EventManager and EventManager.parallelEase then
        EventManager.parallelEase(self, "_selectionAnim", 1, 0.18, "smooth", "shop_select")
    else
        self._selectionAnim = 1
    end

    Sfx.play("cardSelect", { pitch = 1.05 + (math.random() * 2 - 1) * 0.06 })
end

function CardRewardScreen:_buildSelectionButtons(offer, idx)
    self._selectionButtons = {}
    if self.mode == "shop" then return end
    if not self.cardPositions[idx] then return end

    local bx0, by0, buyW, cancelW, btnH, gap = self:_selectionButtonsRect(idx)
    if not bx0 then return end
    local buyLabel = (offer.cost or 0) > 0 and ("$" .. tostring(offer.cost))
        or require("src.i18n.TextCase").upper(I18n.t("common.take"))
    if self.mode == "shop" and (offer.cost or 0) > 0 then
        local verb = I18n.t("reward.detail_buy", nil, "COMPRAR")
        if FontManager.getFont(12):getWidth(verb .. " " .. buyLabel) + 24 <= buyW then
            buyLabel = verb .. " " .. buyLabel
        end
    end

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

    local cancelBtn = Button:new(bx0 + buyW + gap, by0, cancelW, btnH, "", function()
        self:clearSelection()
    end, nil, 14)
    cancelBtn:setColorScheme("red")
    cancelBtn:setIcon("x_close")
    table.insert(self._selectionButtons, cancelBtn)
end

function CardRewardScreen:_cardDrawRect(inst)
    local img = inst.image
    if not img then
        local fx, fy = inst.x or 0, inst.y or 0
        return { drawX = fx, drawY = fy, x = fx, y = fy, w = 0, h = 0 }
    end

    local Moveable = require("engine.Moveable")
    local baseS = inst.baseScale or inst.currentScale or 1
    local s = (inst.currentScale or baseS)
        * Moveable.scaleFactor(inst) * Moveable.swellFactor(inst)

    local iw, ih = img:getWidth(), img:getHeight()
    local w, h = iw * s, ih * s
    local homeX = inst.homeX or inst.x or 0
    local homeY = inst.homeY or inst.y or 0
    local baseW, baseH = iw * baseS, ih * baseS

    local x, y = homeX, homeY
    if self.mode == "shop" then
        x = homeX + (baseW - w) / 2
        y = homeY + baseH - h
        if not reducedMotion() then
            y = y - SHOP_HOVER_LIFT * (inst.hoverStrength or 0)
        end
    end

    y = y + (inst._entryOy or 0)

    local baseFloat = Config.Cards.BASE_LIFT or 0
    local ambientY = 0
    if not inst.isHovered and not inst.isDragging then
        ambientY = math.sin(love.timer.getTime() * 0.666 + (inst._ambientSeed or 0)) * 3
    end
    return {
        drawX = x, drawY = y,
        x = x + (inst.offsetHoverX or 0),
        y = y + ambientY - baseFloat,
        w = w, h = h,
    }
end

local function measuredButtonWidth(btn, minW)
    if not btn then return 0 end
    local font = FontManager.getFont(btn.fontSize or 12)
    local textW = (btn.text and btn.text ~= "") and font:getWidth(btn.text) or 0
    local iconW = btn.iconHandle and 30 or 0
    return math.max(minW or 130, math.ceil(textW + iconW + 34))
end

function CardRewardScreen:_layoutActionButtons()
    local bar = self.actionBar
    if not bar then return end

    if self.mode == "shop" and self.scene and self.scene.L then
        local L = self.scene.L
        local function place(btn, r, invisible)
            if not btn then return end
            btn.x, btn.y, btn.width, btn.height = r.x, r.y, r.w, r.h
            if invisible then btn:setVariant("invisible") end
        end
        place(self.refreshButton, L.bell.rect, true)
        place(self.diceButton, L.dice.rect, true)
        place(self.skipButton, L.continueBtn, false)
        place(self.buyButton, L.scroll.buy, true)
        self:_refreshBuyButton()
        return
    end

    local h = math.min(40, bar.h - 6)
    local y = bar.y + math.floor((bar.h - h) / 2)
    local edge = 10
    local gap = 14

    local rerollW = measuredButtonWidth(self.refreshButton)
    local skipW = measuredButtonWidth(self.skipButton)
    local diceW = self.diceButton and measuredButtonWidth(self.diceButton) or 0
    local diceGap = self.diceButton and (gap + 26) or 0
    local avail = bar.w - edge * 2
    if rerollW + diceW + diceGap + skipW + gap > avail then
        local factor = avail / (rerollW + diceW + diceGap + skipW + gap)
        rerollW = math.floor(rerollW * factor)
        skipW = math.floor(skipW * factor)
        diceW = math.floor(diceW * factor)
    end
    if self.diceButton then
        self.diceButton.x = bar.x + edge + (self.refreshButton and (rerollW + gap) or 0)
        self.diceButton.y = y
        self.diceButton.width = diceW
        self.diceButton.height = h
    end

    if self.refreshButton then
        self.refreshButton.x = bar.x + edge
        self.refreshButton.y = y
        self.refreshButton.width = rerollW
        self.refreshButton.height = h
    end
    if self.skipButton then
        self.skipButton.x = bar.x + bar.w - edge - skipW
        self.skipButton.y = y
        self.skipButton.width = skipW
        self.skipButton.height = h
    end

end

function CardRewardScreen:_diceHelpRect()
    local b = self.diceButton
    local r = 9
    local cx = b.x + b.width + 13
    local cy = b.y + math.floor(b.height / 2)
    if self.mode == "shop" and self.scene and self.scene.L and self.scene.L.diceHelp then
        local d = self.scene.L.diceHelp
        cx, cy = d.x + math.floor(d.w / 2), d.y + math.floor(d.h / 2)
    end
    local rect = require("src.ui.HelpBadge").rect(cx, cy, r)
    rect.cx, rect.cy, rect.r = cx, cy, r
    return rect
end

function CardRewardScreen:openDiceHelp()
    if not self.diceButton then return false end
    local ok = require("src.systems.Tutorial").explain("dice_help", self.game)
    if not ok then Sfx.play("purchaseDeny") end
    return ok
end

function CardRewardScreen:_refreshDiceButton()
    if not self.diceButton then return end
    local ScribeDice = require("src.systems.ScribeDice")
    local used = ScribeDice.isUsed(self:_run())
    self.diceButton.text = I18n.t(used and "scribe_dice.open_used" or "scribe_dice.open")
    self:_layoutActionButtons()
end

function CardRewardScreen:_prefocusDetail()
    if self.mode ~= "shop" then return end
    for _, offer in ipairs(self.shopOffers or {}) do
        if not offer.purchased and (offer._slot or math.huge) <= (self.slotCount or 0) then
            self._lastDetailPayload = {
                kind = offerKind(offer), offer = offer, instance = offer.cardInstance,
            }
            self._detailPrefocus = true
            self._detailShownOffer = offer
            self.selectedOffer = offer
            self.selectedIdx = offer._slot
            if self.scene then self.scene:_syncSelection() end
            self:_refreshBuyButton()
            return
        end
    end
end

function CardRewardScreen:_refreshBuyButton()
    local b = self.buyButton
    if not b then return end
    local offer = self.selectedOffer
    if not offer or offer.purchased then
        b.text = I18n.t("reward.detail_buy", nil, "COMPRAR")
        b:setEnabled(false)
        return
    end
    local verb = I18n.t("reward.detail_buy", nil, "COMPRAR")
    b.text = verb .. " · $" .. tostring(offer.cost or 0)
    local afford = self.game and self.game.economySystem and self.game.economySystem:canAfford(offer.cost or 0)
    b:setEnabled(afford ~= false)
end

function CardRewardScreen:_resetDetail()
    self.detailPayload = nil
    self._lastDetailPayload = nil
    self._detailShownOffer = nil
    self._detailStale = false
    self._detailPrefocus = false
    self._detailAnim = 1
    self.hoveredOffer, self.hoveredInst, self.hoveredKind = nil, nil, nil
    self:_prefocusDetail()
end

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

function CardRewardScreen:showPurchaseConfirmation(offer)
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

function CardRewardScreen:cancelPurchase()
    self:clearSelection()
end

function CardRewardScreen:_startFlyToDeck(offer)
    local inst = offer.cardInstance
    if not inst or not inst.image then return end
    self._flyCards = self._flyCards or {}

    local fly = {
        img = inst.image,
        inst = inst,
        x = inst.x, y = inst.y,
        scale = inst.currentScale or inst.baseScale or 1,
        alpha = 1,
        rot = 0,
    }
    table.insert(self._flyCards, fly)

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

function CardRewardScreen:_spawnGoldPopup(x, y, text, color, centered)
    self._goldPopups = self._goldPopups or {}
    table.insert(self._goldPopups,
        { text = text, x = x, y = y, age = 0, color = color, centered = centered })
end

function CardRewardScreen:_startRelicFlourish(offer)
    local pos = offer._slot and self.cardPositions[offer._slot]
    if not pos then return end
    local w = pos.w or self.cardWidth
    local h = pos.h or self.cardHeight
    local bands = UpgradeTile.layout(pos.x, pos.y, w, h, offer.cost)
    local th = UpgradeTile.theme(offer)

    local label = UpgradeTile.effectLabel(offer)
    if label then
        self:_spawnGoldPopup(pos.x + w / 2,
            math.floor(bands.art.y + bands.art.h * 0.45), label, th.text, true)
    end

    local fx = self:_slotFx(offer._slot)
    Moveable.juice_up(fx, 0.35, 0.08)
    if self.scene then return end

    local sprite = ImageCache.tryGet(
        "assets/sprites/vouchers/" .. tostring(offer.id) .. ".png")
    if not sprite or reducedMotion() then return end

    local sw, sh = sprite:getWidth(), sprite:getHeight()
    local raw = math.min((bands.art.w - 8) / sw, (bands.art.h - 8) / sh)
    local scale = raw >= 1 and math.floor(raw) or raw
    local fly = {
        img = sprite, ox = sw / 2, oy = sh / 2,
        x = pos.x + w / 2, y = bands.art.y + bands.art.h * 0.55,
        scale = scale, alpha = 1, rot = 0,
    }
    self._flyCards = self._flyCards or {}
    table.insert(self._flyCards, fly)
    EventManager.parallelEase(fly, "y", fly.y - 64, 0.55, "ease_out", "shop_fly")
    EventManager.parallelEase(fly, "scale", scale * 1.6, 0.55, "ease_out", "shop_fly")
    EventManager.parallelEase(fly, "alpha", 0, 0.55, "ease_in", "shop_fly")
    EventManager.parallel(0.58, function() fly._done = true end, "shop_fly")
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

function CardRewardScreen:_drawPurchaseFx()
    for _, fly in ipairs(self._flyCards or {}) do
        love.graphics.setColor(1, 1, 1, fly.alpha)
        local img = fly.inst and require("src.ui.CardFrame").displayImage(fly.inst) or fly.img
        love.graphics.draw(img, fly.x, fly.y, fly.rot, fly.scale, fly.scale,
            fly.ox or 0, fly.oy or 0)
    end
    local font = FontManager.getFont(13)
    love.graphics.setFont(font)
    for _, p in ipairs(self._goldPopups or {}) do
        local t = p.age / POPUP_LIFE
        local a = 1 - t * t
        local y = p.y - 36 * t
        local x = p.centered and (p.x - font:getWidth(p.text) / 2) or p.x
        love.graphics.setColor(0, 0, 0, 0.7 * a)
        love.graphics.print(p.text, x + 1, y + 1)
        local c = p.color or { 0.95, 0.78, 0.25 }
        love.graphics.setColor(c[1], c[2], c[3], a)
        love.graphics.print(p.text, x, y)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

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

local DECK_SERVICE_PICKER = {
    forge_card     = "forge",
    remove_card    = "remove",
    duplicate_card = "duplicate",
}

function CardRewardScreen:_openDeckService(offer, pickerMode)
    local rm = self.game.runManager

    if offer.effect == "forge_card" then
        if rm and rm.registerPaidForge then rm:registerPaidForge() end
    elseif rm and rm.registerService then
        rm:registerService(offer.id)
    end

    if not _G.openCardPicker then
        Debug.warn("[CardRewardScreen] _G.openCardPicker nao registrado — servico '"
            .. tostring(offer.id) .. "' estornado")
        self:_refundDeckService(offer)
        return
    end

    local before = ShopServices.deckFingerprint(rm)
    _G.openCardPicker(pickerMode, function()
        if ShopServices.deckFingerprint(rm) == before then
            self:_refundDeckService(offer)
        end
    end)
end

function CardRewardScreen:_refundDeckService(offer)
    local rm = self.game.runManager

    if offer.effect == "forge_card" then
        if rm and rm.unregisterPaidForge then rm:unregisterPaidForge() end
    elseif rm and rm.unregisterService then
        rm:unregisterService(offer.id)
    end

    if self.game.economySystem and self.game.economySystem.refundPurchase then
        self.game.economySystem:refundPurchase(offer.cost, offer.type, offer.id)
    end

    offer.purchased = false
    self:_persistOffers()
    self.game:addMessage(
        I18n.t("reward.service_refunded", { n = offer.cost },
            "Compra cancelada - $" .. tostring(offer.cost) .. " devolvido"),
        "gold")
    Sfx.play("purchaseDeny")

    if not self.visible then return end
    self:createCardInstances()
    self:createOfferButtons()
end

function CardRewardScreen:applyUpgrade(upgrade)
    local pickerMode = DECK_SERVICE_PICKER[upgrade.effect]
    if pickerMode then
        self:_openDeckService(upgrade, pickerMode)
        return
    end

    local rm = self.game.runManager

    if upgrade.effect == "increase_max_health" then
        self.game.player.maxHealth = self.game.player.maxHealth + upgrade.value
        self.game.player.health = self.game.player.health + upgrade.value
    elseif upgrade.effect == "increase_base_mana" then
        self.game.player.baseMaxMana = self.game.player.baseMaxMana + upgrade.value
        self.game.player.maxMana = self.game.player.maxMana + upgrade.value
        self.game.player.mana = self.game.player.mana + upgrade.value

    elseif upgrade.effect == "add_joker_slot" then
        if rm and rm.registerService then rm:registerService(upgrade.id) end
        if self.game.recomputeMaxJokerSlots then
            self.game:recomputeMaxJokerSlots()
        end
        local total = (rm and rm.getMaxJokerSlots and rm:getMaxJokerSlots())
            or self.game.maxJokerSlots or 0
        self.game:addMessage(
            I18n.t("reward.joker_slot_gained", { n = total },
                "Slots de coringa: " .. tostring(total)), "success")

    elseif upgrade.effect == "raise_interest_cap" then
        if rm and rm.registerService then rm:registerService(upgrade.id) end
        if self.game.syncInterestCap then self.game:syncInterestCap() end
        local teto = (self.game.economySystem and self.game.economySystem.getInterestCap
            and self.game.economySystem:getInterestCap()) or 0
        self.game:addMessage(
            I18n.t("reward.interest_cap_raised", { n = teto },
                "Teto de juros: " .. tostring(teto)), "gold")

    elseif upgrade.effect == "increase_draw" then
        if rm and rm.registerService then rm:registerService(upgrade.id) end
        local n = (rm and rm.getServiceCount and rm:getServiceCount(upgrade.id)) or 1
        self.game:addMessage(I18n.t("reward.extra_draw", { n = n }), "success")

    else
        Debug.warn("[CardRewardScreen] upgrade sem efeito implementado: "
            .. tostring(upgrade.effect) .. " — não deveria estar na vitrine (P3.2)")
    end
end

local EXITQ = "reward_exit"
local EXIT_DISSOLVE_STAGGER = 0.07
local EXIT_HOLD = 0.55

function CardRewardScreen:_exitWithFlourish(keepInst)
    if self._closing then return end
    self._closing = true
    EventManager.clear(EXITQ)

    local cb = self.onSkipped

    if reducedMotion() then
        playFirstSfx({ "shopLeaveWhoosh", "menuClose" })
        self:hide()
        self:_clearPersistedOffers()
        if cb then cb() end
        return
    end

    for i, inst in ipairs(self.cardInstances) do
        if inst ~= keepInst and inst.start_dissolve and not inst._removed then
            EventManager.parallel((i - 1) * EXIT_DISSOLVE_STAGGER, function()
                inst:start_dissolve(nil, true, 0.55, true)
            end, EXITQ)
        end
    end

    self:slideOut()
    playFirstSfx({ "shopLeaveWhoosh", "menuClose" })

    EventManager.parallel(EXIT_HOLD, function()
        if not self.visible then return end
        self:hide()
        self:_clearPersistedOffers()
        if cb then cb() end
    end, EXITQ)
end

function CardRewardScreen:hide()
    self.visible = false
    self._closing = false
    self.shopOffers = {}
    self.cardInstances = {}
    self.cardButtons = {}
    self.skipButton = nil
    self.refreshButton = nil
    self.diceButton = nil
    self._flyCards = {}
    self._goldPopups = {}
    self._armedItem = nil
    self.buyButton = nil
    if self.scene then self.scene:clear() end

    self:cancelPurchase()
    self:_resetDetail()
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
            if self.mode ~= "shop" then
                if self.skipButton then
                    self.skipButton.x = math.floor(love.graphics.getWidth() / 2
                        - self.skipButton.width / 2)
                    self.skipButton.y = self.skipButtonY
                end
                if self.refreshButton then
                    self.refreshButton.x = self.skipButtonX + 180
                    self.refreshButton.y = self.skipButtonY
                end
            end
        end
    end

    self.animationTime = self.animationTime + dt

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

    if self.mode == "shop" and self.scene then
        self.scene:update(dt)
    else
        local mx, my = love.mouse.getPosition()
        my = my - (self.slideOffsetY or 0)
        for _, cardInstance in ipairs(self.cardInstances) do
            local st = rareState(cardInstance)
            if st then
                local r = cardInstance._drawRect
                RareReveal.update(st, dt, r and r.w, r and r.h, st.hooks)
            end
            if cardInstance and cardInstance.updateMouse then
                if RareReveal.hidden(st) then
                    cardInstance.isHovered = false
                else
                    cardInstance:updateMouse(mx, my, dt, true)
                end
            end
        end
    end

    self:_updateHoverState()
    self:_resolveDetailPayload()
    self._detailAnim = math.min(1, (self._detailAnim or 1) + dt * 7)

    for _, button in ipairs(self.cardButtons) do
        button:update(dt)
    end

    if self.skipButton then
        self.skipButton:update(dt)
    end

    if self.refreshButton then
        self.refreshButton:update(dt)
    end
    if self.diceButton then self.diceButton:update(dt) end
    if self.buyButton then self.buyButton:update(dt) end

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

function CardRewardScreen:_drawShop()
    local NavCursor = require("src.ui.NavCursor")
    love.graphics.push()
    love.graphics.translate(0, self.slideOffsetY or 0)

    self.scene:draw()

    if self.refreshButton then
        self.refreshButton:draw()
        local rb = self.refreshButton
        NavCursor.action("x", function()
            if rb.visible ~= false and not rb.disabled and rb.onClick then rb.onClick() end
        end, rb.x, rb.y, rb.width, rb.height)
    end
    if self.buyButton then
        self:_refreshBuyButton()
        self.buyButton:draw()
    end
    if self.skipButton then
        self.skipButton:draw()
        local sb = self.skipButton
        NavCursor.action("y", function()
            if sb.visible ~= false and not sb.disabled and sb.onClick then sb.onClick() end
        end, sb.x, sb.y, sb.width, sb.height)
    end
    if self.diceButton then
        self.diceButton:draw()
        local r = self:_diceHelpRect()
        local HelpBadge = require("src.ui.HelpBadge")
        local mx, my = love.mouse.getPosition()
        my = my - (self.slideOffsetY or 0)
        local hotDice = mx >= r.x and mx < r.x + r.w and my >= r.y and my < r.y + r.h
        HelpBadge.draw(r.cx, r.cy, r.r, hotDice)
        if hotDice then
            local okST, StatusTooltip = pcall(require, "src.ui.StatusTooltip")
            if okST and StatusTooltip.show then StatusTooltip.show("scribe_dice_help", mx, my + (self.slideOffsetY or 0)) end
        end
        NavCursor.target("dice_help", r.x, r.y, r.w, r.h)
        NavCursor.action("lb", function() self:openDiceHelp() end, r.x, r.y, r.w, r.h)
    end

    love.graphics.pop()

    do
        local T = require("src.systems.Tutorial")
        local occupied, prices = {}, {}
        for i, offer in ipairs(self.shopOffers or {}) do
            local p = (offer._slot and self.cardPositions[offer._slot]) or self.cardPositions[i]
            if p then occupied[#occupied + 1] = { x = p.x, y = p.y, w = p.w, h = p.h } end
        end
        local L = self.scene and self.scene.L
        for _, it in ipairs(self.scene and self.scene.items or {}) do
            local g = it.geom
            if g and g.plate and not it.sold then
                local b = (g.tag or g.plaque) and (g.tag or g.plaque).box or g.plate
                occupied[#occupied + 1] = g.plate
                prices[#prices + 1] = b
            end
        end
        if L and L.bell and L.bell.tag then prices[#prices + 1] = L.bell.tag.box end
        T.anchorList("offers", occupied)
        T.anchorList("shop_prices", prices)
        if L and L.scroll then T.anchorList("shop_scroll", { L.scroll }) end
        if self.refreshButton then
            T.anchorList("shop_refresh", { self.refreshButton, L and L.bell and L.bell.tag and L.bell.tag.box or nil })
        end
        if self.diceButton then T.anchorList("shop_dice", { self.diceButton }) end
    end

    self:_drawPurchaseFx()
    self.scene:drawFlies()

    if self.inspectModal then
        self.inspectModal:update(love.timer.getDelta())
        self.inspectModal:draw()
    end
end

function CardRewardScreen:draw()
    if not self.visible then return end
    if self.mode == "shop" and self.scene then return self:_drawShop() end

    local w, h = love.graphics.getDimensions()
    if self.mode == "rewards" then
        love.graphics.setColor(0.02, 0.015, 0.01, 0.60)
        love.graphics.rectangle("fill", 0, 0, w, h)
        love.graphics.setColor(1, 1, 1, 1)
    end

    love.graphics.push()
    love.graphics.translate(0, self.slideOffsetY or 0)

    if self.mode == "rewards" then
        self:_drawRewardsBanner()
    end

    local dbgDrawTick = false
    if REWARD_DBG and self.animationTime < 6 then
        if self.animationTime >= (self._dbgDrawNext or 0) then
            self._dbgDrawNext = (self._dbgDrawNext or 0) + 0.5
            dbgDrawTick = true
        end
    end

    for _, cardInstance in ipairs(self.cardInstances) do
        if cardInstance and cardInstance.draw then
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
                cardInstance.saleDim = (self.mode == "shop") and offer
                    and offer.cost and self.game
                    and not self.game.economySystem:canAfford(offer.cost)
                    or false
                local r = self:_cardDrawRect(cardInstance)
                cardInstance._drawRect = r
                local st = rareState(cardInstance)
                if st then RareReveal.drawBack(st, r.x + r.w / 2, r.y + r.h / 2, r.w, r.h) end
                if not RareReveal.hidden(st) then
                    cardInstance:draw(r.drawX, r.drawY, false, true)
                    self:drawPriceOverlay(cardInstance, r)
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
                local fx = self:_slotFx(slot)
                require("src.ui.NavCursor").target("offer:" .. slot, pos.x, pos.y,
                    pos.w or self.cardWidth, pos.h or self.cardHeight)
                local s = scale * Moveable.scaleFactor(fx) * Moveable.swellFactor(fx)
                local lift = Moveable.hopOffset(fx)
                local w = pos.w or self.cardWidth
                local h = pos.h or self.cardHeight
                if math.abs(s - 1) > 0.001 or lift ~= 0 then
                    love.graphics.push()
                    love.graphics.translate(pos.x + w / 2, pos.y + h / 2 + lift)
                    love.graphics.scale(s, s)
                    love.graphics.translate(-(pos.x + w / 2), -(pos.y + h / 2))
                    self:drawOffer(offer, pos.x, pos.y, slot, pos.w, pos.h)
                    love.graphics.pop()
                else
                    self:drawOffer(offer, pos.x, pos.y, slot, pos.w, pos.h)
                end
            end
        end
        if offer.purchased and slot <= slotCount and self.cardPositions[slot] then
            self:_drawSoldSlot(self.cardPositions[slot])
        end
    end

    for _, cardInstance in ipairs(self.cardInstances) do
        local st = rareState(cardInstance)
        local r = cardInstance._drawRect
        if st and r then RareReveal.drawFront(st, r.x + r.w / 2, r.y + r.h / 2, r.w, r.h) end
    end

    for _, cardInstance in ipairs(self.cardInstances) do
        local offer = cardInstance and cardInstance.shopOffer
        local slot = offer and offer._slot
        local anim = slot and self.cardAnimations[slot]
        if slot and (anim and anim.scale or 1) > 0 then
            self:drawOfferBadges(cardInstance, slot)
        end
    end

    if self.detailPanel then
        self:_drawDetailPanel()
    end

    if self.skipButton then
        self.skipButton:draw()
    end

    if self.refreshButton then
        self.refreshButton:draw()
        local rb = self.refreshButton
        require("src.ui.NavCursor").action("x", function()
            if rb.visible ~= false and not rb.disabled and rb.onClick then rb.onClick() end
        end, rb.x, rb.y, rb.width, rb.height)
    end
    if self.diceButton then
        self.diceButton:draw()
        local r = self:_diceHelpRect()
        local HelpBadge = require("src.ui.HelpBadge")
        local mx, my = love.mouse.getPosition()
        HelpBadge.draw(r.cx, r.cy, r.r, mx >= r.x and mx < r.x + r.w and my >= r.y and my < r.y + r.h)
        local NavCursor = require("src.ui.NavCursor")
        NavCursor.target("dice_help", r.x, r.y, r.w, r.h)
        NavCursor.action("y", function() self:openDiceHelp() end, r.x, r.y, r.w, r.h)
    end

    self:drawInstructions()

    love.graphics.pop()

    if self.mode == "rewards" and self.hoveredInst and not self.selectedOffer then
        local inst = self.hoveredInst
        local r = inst._drawRect
        local rx = r and r.x or inst.x or 0
        local ry = r and r.y or inst.y or 0
        local rw = r and r.w or self.cardWidth or 0
        local disp = inst.cardInfoDisplay or self.cardInfoDisplay
        disp:draw(inst, rx, ry, {
            showRarity = false,
            showStats = true,
            showDescription = true,
            side = true, cardX = rx, cardW = rw,
            minY = ((_G.topBar and _G.topBar.height) or 52) + 6,
        })
    end

    self:_drawSelectionOverlay()

    do
        local T = require("src.systems.Tutorial")
        local occupied = {}
        for i, offer in ipairs(self.shopOffers or {}) do
            local p = (offer._slot and self.cardPositions[offer._slot]) or self.cardPositions[i]
            if p then
                occupied[#occupied + 1] = { x = p.x, y = p.y,
                    w = p.w or self.cardWidth, h = p.h or self.cardHeight }
            end
        end
        T.anchorList("offers", occupied)
        if self.mode == "rewards" and self.skipButton then T.anchorList("reward_skip", { self.skipButton }) end
        if self.mode == "shop" then
            if self.refreshButton then T.anchorList("shop_refresh", { self.refreshButton }) end
            if self.diceButton then T.anchorList("shop_dice", { self.diceButton }) end
        end
    end

    self:_drawPurchaseFx()

    if self.inspectModal then
        self.inspectModal:update(love.timer.getDelta())
        self.inspectModal:draw()
    end
end

function CardRewardScreen:_drawRewardsBanner()
    local sw = love.graphics.getWidth()
    local y = self.bannerY or 80
    local cx = math.floor(sw / 2)

    local title = I18n.t("reward.rewards_title")
    local tf = FontManager.getFont(20)
    love.graphics.setFont(tf)
    local tw = tf:getWidth(title)
    local th = tf:getHeight()

    local lineY = y + math.floor(th / 2)
    local gap = math.floor(tw / 2) + 26
    local lineW = math.min(190, math.floor(sw * 0.17))
    local g = Palette.AGED_GOLD
    for _, side in ipairs({ -1, 1 }) do
        local x0 = cx + side * gap
        for seg = 0, 7 do
            local a = 0.85 * (1 - seg / 8)
            local sx0 = x0 + side * (lineW / 8) * seg
            love.graphics.setColor(g[1], g[2], g[3], a)
            love.graphics.rectangle("fill", math.min(sx0, sx0 + side * (lineW / 8)),
                lineY - 1, lineW / 8, 2)
        end
        local px = x0 - side * 4
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.polygon("fill", px, lineY - 5 + 1, px + 5, lineY + 1,
            px, lineY + 5 + 1, px - 5, lineY + 1)
        Palette.set(Palette.AGED_GOLD_LIGHT)
        love.graphics.polygon("fill", px, lineY - 5, px + 5, lineY,
            px, lineY + 5, px - 5, lineY)
    end

    local tx = cx - math.floor(tw / 2)
    love.graphics.setColor(0, 0, 0, 0.85)
    for _, o in ipairs({ {2, 0}, {-2, 0}, {0, 2}, {0, -2}, {2, 2} }) do
        love.graphics.print(title, tx + o[1], y + o[2])
    end
    Palette.set(Palette.AGED_GOLD_LIGHT)
    love.graphics.print(title, tx, y)

    local sub = I18n.t("reward.rewards_subtitle")
    local sf = FontManager.getFont(9)
    love.graphics.setFont(sf)
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.print(sub, cx - math.floor(sf:getWidth(sub) / 2) + 1, y + th + 15)
    Palette.set(Palette.PARCHMENT_LIGHT)
    love.graphics.print(sub, cx - math.floor(sf:getWidth(sub) / 2), y + th + 14)

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
    require("src.ui.NavCursor").target("rules", hx - hr - 3, hy - hr - 3, hr * 2 + 6, hr * 2 + 6)
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

local function drawMarker(cx, cy, text, color, fontSize, dia)
    ShopEngraving.marker(cx, cy, text, color, fontSize, dia)
end

function CardRewardScreen:drawOfferBadges(cardInstance, slot)
    local offer = cardInstance.shopOffer
    if not offer or offer.purchased then return end
    if (cardInstance._entryOy or 0) > 1 then return end
    if RareReveal.hidden(offer._rareReveal) then return end
    local pos = self.cardPositions[slot]
    if not pos then return end
    local w = pos.w or self.cardWidth
    local h = pos.h or self.cardHeight
    local marker = drawMarker

    local cx = pos.x + math.floor(w / 2)
    if self.mode == "shop" then
        if offer.rarity then
            local label = require("src.i18n.TextCase").upper(I18n.t("rarity." .. offer.rarity, nil, offer.rarity))
            marker(cx, pos.y + h + 13, label, Palette.forRarity(offer.rarity), 8, 3)
        end
        if offer.affinity then
            marker(cx, pos.y + h + 24, I18n.t("reward.affinity_badge"),
                Palette.AGED_GOLD_LIGHT, 7, 2)
        end
    else
        if offer.rarity then
            local label = require("src.i18n.TextCase").upper(I18n.t("rarity." .. offer.rarity, nil, offer.rarity))
            marker(cx, pos.y - (offer.isNew and 27 or 15), label, Palette.forRarity(offer.rarity), 9, 4)
        end
        local below = pos.y + h + 15
        if offer._rareReveal then
            marker(cx, below, require("src.i18n.TextCase").upper(I18n.t("reward.rare_find")),
                Palette.TOAST_GOLD, 9, 4)
            below = below + 15
        end
        if offer.affinity then
            marker(cx, below,
                I18n.t("reward.affinity_badge"), Palette.AGED_GOLD_LIGHT, 8, 3)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function CardRewardScreen:_drawDetailPanel(rect, parchment, artMaxH, objectArt)
    local dp = rect or self.detailPanel
    if not dp then return end

    local payload = self.detailPayload
    local offer = payload and payload.offer
    local canAfford = true
    if offer and (offer.cost or 0) > 0 and self.game and self.game.economySystem then
        canAfford = self.game.economySystem:canAfford(offer.cost)
    end

    local footerH = self.selectedOffer and (self.detailFooterH or 58) or 0

    local hint = nil
    if self._detailPrefocus then
        hint = I18n.t("reward.detail_prefocus", nil, "Passe o mouse pra comparar")
    elseif self._detailStale then
        hint = I18n.t("reward.detail_stale", nil, "ultima oferta observada")
    end

    self._detailFit = CardDetailPanel.draw(dp, payload, {
        priceOnButton = parchment and true or false,
        alpha     = math.max(0, math.min(1, self._detailAnim or 1)),
        stale     = hint ~= nil,
        canAfford = canAfford,
        chrome    = not parchment,
        parchment = parchment,
        artMaxH   = artMaxH,
        objectArt = objectArt,
        footerH   = footerH,
        emptyHint = I18n.t("reward.detail_empty", nil,
            "Passe o mouse sobre uma oferta para ver os detalhes"),
        staleHint = hint,
    })
end

function CardRewardScreen:_drawCardTooltipOverlay(cardInstance)
    if not cardInstance.cardInfoDisplay then return end

    local px = cardInstance.renderX or cardInstance.x or 0
    local py = cardInstance.renderY or cardInstance.y or 0

    cardInstance.cardInfoDisplay:draw(cardInstance, px, py, {
        showRarity = false,
        showStats = true,
        showDescription = true,
    })
end

function CardRewardScreen:drawOffer(offer, x, y, index, customW, customH)
    local canAfford = self.game and self.game.economySystem:canAfford(offer.cost)
    local w = customW or self.cardWidth
    local h = customH or self.cardHeight
    local compact = h < 250

    if offer.type == "booster_pack" then
        local PackSleeve = require("src.ui.PackSleeve")
        local sleeveW, sleeveH = PackSleeve.getDimensions()

        local headerH = compact and 13 or 16
        local availH = h - headerH - 10
        local availW = w - 8
        local scale = math.min(availW / sleeveW, availH / sleeveH)

        local drawW, drawH = sleeveW * scale, sleeveH * scale
        local cx = math.floor(x + w * 0.5)
        local cy = math.floor(y + headerH + 4 + drawH * 0.5)
        PackSleeve.drawAt(offer.id, offer.kind, cx, cy, scale, 1)

        Palette.set(Palette.AGED_GOLD_LIGHT)
        local nameFont = FontManager.getFont(compact and 8 or 9)
        local wordTooLong = false
        for word in tostring(offer.name or ""):gmatch("%S+") do
            if nameFont:getWidth(word) > w - 8 then wordTooLong = true break end
        end
        if wordTooLong then
            local font, txt = require("src.ui.TextFit").fit(offer.name, compact and 8 or 9, w - 8)
            love.graphics.setFont(font)
            love.graphics.printf(txt, x + 4, y + 3, w - 8, "center")
        else
            love.graphics.setFont(nameFont)
            love.graphics.printf(offer.name, x + 4, y + 3, w - 8, "center")
        end

        local sleeveRect = {
            x = math.floor(cx - drawW / 2), y = math.floor(cy - drawH / 2),
            w = math.floor(drawW), h = math.floor(drawH),
        }
        ShopEngraving.stampPrice(sleeveRect, offer.cost, {
            afford = canAfford,
            glow = (self.hoveredOffer == offer) and 1 or 0,
        })
        return
    end

    if offer.type == "upgrade" then
        local fx = self:_slotFx(index or 0)
        UpgradeTile.draw(offer, { x = x, y = y, w = w, h = h }, {
            hover  = fx.hover or 0,
            afford = canAfford,
            time   = love.timer.getTime(),
        })
        return
    end

    PixelCanvas.rect(math.floor(x), math.floor(y), math.floor(w), math.floor(h), Palette.PANEL_FILL)
    PixelCanvas.rectOutline(math.floor(x), math.floor(y), math.floor(w), math.floor(h),
        canAfford and Palette.AGED_GOLD or Palette.BLOOD)

    local displayName = offer.type == "card" and I18n.cardName({ id = offer.id, name = offer.name }) or offer.name
    local displayDesc = offer.type == "card" and I18n.cardDesc({ id = offer.id, description = offer.description }) or offer.description
    Palette.set(Palette.PARCHMENT_LIGHT)
    love.graphics.setFont(FontManager.getFont(compact and 8 or 10))
    love.graphics.printf(displayName, x + 6, y + (compact and 6 or 12), w - 12, "center")

    Palette.set(Palette.PARCHMENT)
    love.graphics.setFont(FontManager.getFont(8))
    love.graphics.printf(displayDesc, x + 8, y + 36, w - 16, "center")

    if offer.type == "card" and offer.rarity then
        Palette.set(Palette.forRarity(offer.rarity))
        love.graphics.rectangle("fill", math.floor(x + 6), math.floor(y + 4), math.floor(w - 12), 3)
    end

    Palette.set(canAfford and Palette.AGED_GOLD_LIGHT or Palette.BLOOD)
    love.graphics.setFont(FontManager.getFont(compact and 9 or 11))
    love.graphics.printf("$" .. offer.cost, x + 8, y + h - (compact and 18 or 24),
        w - 16, "center")
end

function CardRewardScreen:drawPriceOverlay(cardInstance, rect)
    local offer = cardInstance.shopOffer
    if not offer or offer.purchased then return end
    if (offer.cost or 0) <= 0 then return end

    local canAfford = self.game and self.game.economySystem:canAfford(offer.cost)
    ShopEngraving.stampPrice(rect, offer.cost, {
        afford = canAfford,
        glow = (self.hoveredOffer == offer) and 1 or 0,
    })
end

function CardRewardScreen:drawPurchaseConfirmation() end

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
    local selInst = self.selectedOffer and self.selectedOffer.cardInstance
    local selRect = selInst and selInst._drawRect
    if selRect and selRect.w > 0 then
        anchorX, anchorY = selRect.x, selRect.y
        anchorW, anchorH = selRect.w, selRect.h
    end

    local haloAlpha = 0.55 * anim * (0.7 + 0.3 * math.sin(love.timer.getTime() * 3.5))
    love.graphics.setColor(Palette.AGED_GOLD[1], Palette.AGED_GOLD[2], Palette.AGED_GOLD[3], haloAlpha)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", anchorX - 3, anchorY - 3, anchorW + 6, anchorH + 6)
    love.graphics.setColor(Palette.AGED_GOLD_LIGHT[1], Palette.AGED_GOLD_LIGHT[2], Palette.AGED_GOLD_LIGHT[3], haloAlpha * 0.6)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", anchorX - 1, anchorY - 1, anchorW + 2, anchorH + 2)

    if self._selectionButtons and #self._selectionButtons > 0 then
        local bx0, by0, _, _, _, gap = self:_selectionButtonsRect(self.selectedIdx)
        if bx0 then
            local cursorX = bx0
            for _, b in ipairs(self._selectionButtons) do
                b.x = cursorX
                b.y = by0
                b:draw()
                cursorX = cursorX + b.width + (gap or 8)
            end
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function CardRewardScreen:_updateHoverState()
    local newHovered, newInst, newKind = nil, nil, nil

    if self.mode == "shop" and self.scene then
        local it = self.scene.hovered
        if it and it.offer and not it.offer.purchased then
            newHovered, newInst = it.offer, it.card
            newKind = (it.kind == "relic") and "voucher" or it.kind
        end
        if newHovered ~= self.hoveredOffer then
            self.hoveredOffer, self.hoveredInst, self.hoveredKind = newHovered, newInst, newKind
        end
        return
    end

    for _, inst in ipairs(self.cardInstances or {}) do
        if inst and inst.isHovered then
            local offer = inst.shopOffer
            if offer and not offer.purchased then
                newHovered, newInst, newKind = offer, inst, "card"
                break
            end
        end
    end

    if not newHovered and self.mode == "shop" then
        local mx, my = love.mouse.getPosition()
        my = my - (self.slideOffsetY or 0)
        for _, offer in ipairs(self.shopOffers or {}) do
            local pos = offer._slot and self.cardPositions[offer._slot]
            if pos and offer.type ~= "card" and not offer.purchased then
                local pw = pos.w or self.cardWidth
                local ph = pos.h or self.cardHeight
                if mx >= pos.x and mx <= pos.x + pw
                    and my >= pos.y and my <= pos.y + ph then
                    newHovered = offer
                    newKind = offerKind(offer)
                    break
                end
            end
        end
    end

    if newHovered ~= self.hoveredOffer then
        self.hoveredOffer = newHovered
        self.hoveredInst = newInst
        self.hoveredKind = newKind
    end
end

function CardRewardScreen:_slotFx(slot)
    self.slotFx = self.slotFx or {}
    local fx = self.slotFx[slot]
    if not fx then
        fx = { hover = 0 }
        Moveable.initJuice(fx)
        self.slotFx[slot] = fx
    end
    return fx
end

function CardRewardScreen:_resolveDetailPayload()
    if self.mode ~= "shop" then
        self.detailPayload, self._lastDetailPayload = nil, nil
        return
    end

    local offer, inst, kind
    if self.selectedOffer then
        offer = self.selectedOffer
        kind = offerKind(offer)
        inst = offer.cardInstance
    elseif self.hoveredOffer then
        offer, inst, kind = self.hoveredOffer, self.hoveredInst, self.hoveredKind
    end

    if offer then
        self.detailPayload = { kind = kind or "card", offer = offer, instance = inst }
        self._lastDetailPayload = self.detailPayload
        self._detailStale = false
        self._detailPrefocus = false
    else
        self.detailPayload = self._lastDetailPayload
        self._detailStale = self._lastDetailPayload ~= nil
        if self.detailPayload and self.detailPayload.offer then
            self.detailPayload.instance = self.detailPayload.offer.cardInstance
                or self.detailPayload.instance
        end
    end

    if self.detailPayload and self.detailPayload.offer
        and self.detailPayload.offer.purchased then
        self.detailPayload, self._lastDetailPayload = nil, nil
        self._detailStale = false
        self:_prefocusDetail()
        self.detailPayload = self._lastDetailPayload
        self._detailStale = self._lastDetailPayload ~= nil
    end

    local shown = self.detailPayload and self.detailPayload.offer or nil
    if shown ~= self._detailShownOffer then
        self._detailShownOffer = shown
        self._detailAnim = reducedMotion() and 1 or 0.5
    end
end

function CardRewardScreen:_selectionButtonsRect(idx)
    local btnH = 40
    local gap = 8
    if self.mode == "shop" and self.detailPanel then
        local dp = self.detailPanel
        local pad = 14
        local cancelW = btnH
        local buyW = math.max(70, dp.w - pad * 2 - cancelW - gap)
        return dp.x + pad, dp.y + dp.h - pad - btnH, buyW, cancelW, btnH, gap
    end

    local pos = self.cardPositions[idx or 0]
    if not pos then return nil end
    local pw = pos.w or self.cardWidth
    local ph = pos.h or self.cardHeight
    local offer = self.selectedOffer
    btnH = 38
    local buyLabel = (offer and (offer.cost or 0) > 0) and ("$" .. tostring(offer.cost))
        or require("src.i18n.TextCase").upper(I18n.t("common.take"))
    local buyW = math.max(110, FontManager.getFont(12):getWidth(buyLabel) + 56)
    local cancelW = btnH
    local totalW = buyW + cancelW + gap
    return math.floor(pos.x + (pw - totalW) / 2),
           math.floor(pos.y + ph + (self.mode == "rewards" and 24 or 8)),
           buyW, cancelW, btnH, gap
end

function CardRewardScreen:drawInstructions()
    local text = I18n.t("reward.instructions")
    if self.mode == "shop" then
        text = I18n.t("reward.instructions_shop", nil,
            "Passe o mouse pra ler - CLIQUE seleciona - confirme no painel - DIREITO inspeciona")
    end
    HintBar.draw(text)
end

function CardRewardScreen:mousepressed(x, y, button)
    if not self.visible then return false end
    if self._closing then return true end

    if self.inspectModal and self.inspectModal:isVisible() then
        self.inspectModal:mousepressed(x, y, button)
        return true
    end

    if button == 2 then
        if self.mode == "shop" and self.scene then
            local it = self.scene:itemAt(x, y - (self.slideOffsetY or 0))
            if it and it.card then
                self.inspectModal = self.inspectModal or require("src.ui.CardInspectModal"):new()
                self.inspectModal:show(it.card)
                return true
            end
        end
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
    if self.diceButton and self.diceButton:mousepressed(x, y, button) then
        return true
    end
    if self.buyButton and self.buyButton:mousepressed(x, y, button) then return true end
    if self.mode == "shop" and self.scene and button == 1 then
        local it = self.scene:itemAt(x, y - (self.slideOffsetY or 0))
        if it then
            self._armedItem = it
            return true
        end
    end
    self._armedItem = nil

    if self.selectedOffer then
        self:clearSelection()
        return true
    end

    return false
end

function CardRewardScreen:mousereleased(x, y, button)
    if not self.visible then return false end
    if self._closing then return true end

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
    if self.diceButton and self.diceButton:mousereleased(x, y, button) then
        return true
    end
    if self.buyButton and self.buyButton:mousereleased(x, y, button) then return true end
    if self.mode == "shop" and self.scene and button == 1 and self._armedItem then
        local armed = self._armedItem
        self._armedItem = nil
        local it = self.scene:itemAt(x, y - (self.slideOffsetY or 0))
        if it == armed and it.offer and not it.offer.purchased then
            self:setSelectedOffer(it.offer, it.slot)
            return true
        end
    end
    if self.diceButton and button == 1 then
        local r = self:_diceHelpRect()
        if x >= r.x and x < r.x + r.w and y >= r.y and y < r.y + r.h then
            self:openDiceHelp()
            return true
        end
    end

    return false
end

function CardRewardScreen:isVisible()
    return self.visible
end

function CardRewardScreen:slideOut()
    if not self.visible then return end
    local h = love.graphics.getHeight()
    EventManager.parallelEase(self, "slideOffsetY", h, 0.45, "smooth", FXQ)
end

function CardRewardScreen:slideIn()
    if not self.visible then return end
    EventManager.parallelEase(self, "slideOffsetY", 0, 0.45, "smooth", FXQ)
end

return CardRewardScreen
