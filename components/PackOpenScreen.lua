local PackOpenScreen = {}
PackOpenScreen.__index = PackOpenScreen

local Config         = require("src.core.Config")
local FontManager    = require("src.ui.FontManager")
local Palette        = require("src.ui.Palette")
local ShopEngraving  = require("src.ui.ShopEngraving")
local PixelCanvas    = require("src.ui.PixelCanvas")
local Button         = require("components.Button")
local Sfx            = require("src.systems.Sfx")
local FlashShader    = require("src.ui.FlashShader")
local DynaText       = require("src.ui.DynaText")
local PackSleeve     = require("src.ui.PackSleeve")
local PackThemes     = require("src.ui.PackThemes")
local PackMood       = require("src.ui.PackMood")
local PackBurst      = require("src.ui.PackBurst")
local Layout         = require("src.ui.PackChoiceLayout")
local I18n           = require("src.i18n.I18n")
local TextCase       = require("src.i18n.TextCase")

local function reducedMotion()
    return (_G.gameSettings and _G.gameSettings.reducedMotion) or false
end

PackOpenScreen.TIMING = {
    enter      = 0.35,
    chargeEnd  = 1.25,
    firstCard  = 1.38,
    stagger    = 0.14,
    rareHold   = 0.22,
    fly        = 0.32,
    header     = 0.20,
    ready      = 0.10,
    selectLift = 14,
    closeAt    = 0.95,
}

PackOpenScreen.TIMING_REDUCED = {
    enter      = 0,
    chargeEnd  = 0.45,
    firstCard  = 0.55,
    stagger    = 0.08,
    rareHold   = 0.10,
    fly        = 0,
    header     = 0.10,
    ready      = 0.10,
    selectLift = 14,
    closeAt    = 0.55,
}

local function outCubic(t) local u = 1 - t; return 1 - u * u * u end
local function outBack(t)
    local c1, c3 = 1.70158, 2.70158
    local u = t - 1
    return 1 + c3 * u * u * u + c1 * u * u
end
local function linear(t) return t end
local function inCubic(t) return t * t * t end
local function inOutCubic(t)
    if t < 0.5 then return 4 * t * t * t end
    local u = -2 * t + 2
    return 1 - u * u * u / 2
end

local function isRare(card)
    return card and (card.rarity == "rare" or card.rarity == "legendary")
end

function PackOpenScreen:_overhang()
    local z = self:_z()
    local font = require("src.ui.PixelFont").get(8)
    local badge = (font:getHeight() + 4) * z.cardScale
    local hover = math.max(0, (Config.Cards.LIFT_AMOUNT or 0) - (Config.Cards.DEPTH_OFFSET or 0))
        + (Config.Cards.BASE_LIFT or 0) + 3
    return badge + hover
end

function PackOpenScreen:_liftMax()
    local z = self:_z()
    local room = z.cards.y - (z.header.y + z.header.h) - self:_overhang()
    return math.max(0, math.min(self:_timing().selectLift, math.floor(room)))
end

function PackOpenScreen:_timing()
    return reducedMotion() and PackOpenScreen.TIMING_REDUCED or PackOpenScreen.TIMING
end

function PackOpenScreen:_computeZones()
    local inst = self.pack and self.pack.instances and self.pack.instances[1]
    local imgW = (inst and inst.image and inst.image:getWidth()) or 96
    local imgH = (inst and inst.image and inst.image:getHeight()) or 144
    local n = (self.pack and self.pack.instances and #self.pack.instances) or 3
    local tb = _G.topBar
    local inset = (tb and tb.visible ~= false and tb.game) and (tb.height or 52) or 0
    self._zones = Layout.compute(n, imgW, imgH, nil, nil, inset)
    return self._zones
end

function PackOpenScreen:_z()
    return self._zones or self:_computeZones()
end

function PackOpenScreen:_packCenter()
    local z = self:_z()
    return love.graphics.getWidth() * 0.5, z.cards.y + z.cards.h * 0.5
end

function PackOpenScreen.new()
    local instance = setmetatable({}, PackOpenScreen)
    instance.visible = false
    instance.pack = nil
    instance._selectedCards = {}
    instance._theme = PackThemes.get("Standard")
    return instance
end

function PackOpenScreen:show(pack, onComplete)
    self.visible = true
    self.pack = pack
    self.onComplete = onComplete
    self.choicesRemaining = pack.choose or 1
    self._closing = false
    self._closeAt = nil
    self._selectedCards = {}
    self._theme = PackThemes.get(pack.kind)
    self._mood = PackMood.new(self._theme)
    self._burst = PackBurst.new(self._theme)
    self._t = 0
    self._beats = {}
    self._tweens = {}
    self._instant = false
    self._bgAlpha = 0
    self._packVisible = true
    self._packAlpha = 1
    self._packYOff = 0
    self._packRot = 0
    self._packScale = 1
    self._sleeveExploded = false
    self._chargeP = 0
    if self._stripQuad then self._stripQuad:release() end
    self._stripQuad, self._stripRows = nil, nil
    self._cardsReady = false
    self._skipReady = false
    self._headerOff = 0
    self._footerAlpha = 0
    self._selectionAnim = 0
    self.selectedCardIdx = nil
    self.selectedCard = nil
    self.selectButton = nil
    self.cancelButton = nil
    self.titleText = nil
    self.chooseText = nil

    self:_layoutCards()
    self:_buildSkipButton()
    self:_scheduleTimeline()

    pcall(PackThemes.registerSealSounds)
    Sfx.play("shopPackLift", { volume = 0.9 })
end

function PackOpenScreen:hide()
    self.visible = false
    self.pack = nil
    self.skipButton = nil
    self.selectButton = nil
    self.cancelButton = nil
    self.titleText = nil
    self.chooseText = nil
    self._selectedCards = {}
    if self._burst then self._burst:clear() end
    if self._mood then self._mood:resize() end
end

function PackOpenScreen:isVisible() return self.visible end

function PackOpenScreen:_tween(obj, key, to, dur, ease, delay)
    for i = #self._tweens, 1, -1 do
        local tw = self._tweens[i]
        if tw.obj == obj and tw.key == key then table.remove(self._tweens, i) end
    end
    if self._instant or (dur or 0) <= 0 then
        obj[key] = to
        return
    end
    self._tweens[#self._tweens + 1] = {
        obj = obj, key = key, from = obj[key] or 0, to = to,
        dur = dur, t = -(delay or 0), ease = ease or outCubic,
    }
end

function PackOpenScreen:_updateTweens(dt)
    for i = #self._tweens, 1, -1 do
        local tw = self._tweens[i]
        tw.t = tw.t + dt
        if tw.t >= 0 then
            if tw.t <= dt then tw.from = tw.obj[tw.key] or tw.from end
            local p = math.min(1, tw.t / tw.dur)
            tw.obj[tw.key] = tw.from + (tw.to - tw.from) * tw.ease(p)
            if p >= 1 then table.remove(self._tweens, i) end
        end
    end
end

function PackOpenScreen:_finishTweens()
    for _, tw in ipairs(self._tweens) do tw.obj[tw.key] = tw.to end
    self._tweens = {}
end

function PackOpenScreen:_at(t, fn)
    self._beats[#self._beats + 1] = { at = t, fn = fn }
end

function PackOpenScreen:_fireBeats(upTo)
    local i = 1
    while i <= #self._beats do
        local b = self._beats[i]
        if b.at <= upTo then
            table.remove(self._beats, i)
            b.fn()
            i = 1
        else
            i = i + 1
        end
    end
end

function PackOpenScreen:_rebuildCardArt()
    if not (self.pack and self.pack.instances) then return end
    local CardFrame = require("src.ui.CardFrame")
    if CardFrame.clearCache then CardFrame.clearCache() end
    for _, card in ipairs(self.pack.instances) do
        if card then
            local ok, img = pcall(CardFrame.render, card)
            if ok and img then
                card.image = img
            else
                love.graphics.setCanvas()
            end
        end
    end
end

function PackOpenScreen:resize()
    if not self.visible or not self.pack then return end
    ShopEngraving.clearCache()
    self:_rebuildCardArt()
    self:_computeZones()
    self:_layoutCards()
    if self._mood then self._mood:resize() end
    self:_buildSkipButton()
    if self._skipReady and self.skipButton then self.skipButton:setEnabled(true) end
end

function PackOpenScreen:_dissolvePalette(card)
    local th = self._theme or PackThemes.get("Standard")
    if card and isRare(card) then
        local rc = Palette.forRarity(card.rarity)
        return { { rc[1], rc[2], rc[3], 1 }, { th.titleHi[1], th.titleHi[2], th.titleHi[3], 1 } }
    end
    return {
        { th.glow[1], th.glow[2], th.glow[3], 1.0 },
        { th.titleHi[1], th.titleHi[2], th.titleHi[3], 1.0 },
    }
end

function PackOpenScreen:_layoutCards()
    if not self.pack or not self.pack.instances then return end
    local n = #self.pack.instances
    if n == 0 then return end

    local z = self:_computeZones()
    local scale = z.cardScale
    self._cardScale = scale
    self._finalCardPositions = {}

    for i, card in ipairs(self.pack.instances) do
        local fx, fy = Layout.cardPos(z, i)
        self._finalCardPositions[i] = { x = fx, y = fy }
        card.baseScale = scale
        card.targetScale = scale
        card.isRewardCard = true
        card._packIndex = i
        if card._packShown and not card._chosen and not self._closing then
            card:setRenderPos(fx, fy)
            card.layoutX, card.layoutY = fx, fy
            card.x, card.y = fx, fy
            card.currentScale = scale
        elseif not card._packShown then
            card:setRenderPos(fx, fy)
            card.x, card.y = fx, fy
            card.currentScale = scale
            card.dissolve = 1
            card.dissolve_colours = self:_dissolvePalette(card)
            card._tagPop = 0
            card._selLift = 0
        end
        card._posInitialized = true
    end
end

function PackOpenScreen:_buildSkipButton()
    local label = I18n.t("common.skip")
    local btnH = 34
    local btnW = math.max(90, FontManager.getFont(12):getWidth(label) + 46)
    local h = self:_z().header
    self.skipButton = Button:new(h.x + h.w - btnW - 12, h.y + (h.h - btnH) * 0.5,
        btnW, btnH, label, function() self:skip() end, nil, 12)
    self.skipButton:setIcon("x_close")
    self.skipButton:setEnabled(false)
end

function PackOpenScreen:_buildTitleTexts()
    local th = self._theme
    self.titleText = DynaText.new({
        text = PackThemes.label(self.pack and self.pack.kind or "Standard"),
        fontSize = 26, bump = true, bump_phase = 0.42, bump_amount = 0.45,
        rotate = true, pop_in = self._instant and 0 or 0.25, pop_in_rate = 4, spacing = 2,
        colours = {
            { th.titleHi[1], th.titleHi[2], th.titleHi[3], 1 },
            { th.titleLo[1], th.titleLo[2], th.titleLo[3], 1 },
        },
        colour_cycle = 1.5, shadow = true, align = "center",
    })
    self.chooseText = DynaText.new({
        text = I18n.t("pack.choose", { n = self.choicesRemaining }),
        fontSize = 14, bump = false, rotate = false,
        pop_in = self._instant and 0 or 0.45, pop_in_rate = 4, spacing = 1,
        colours = { { 0.95, 0.92, 0.88, 1 } }, shadow = true, align = "center",
    })
end

function PackOpenScreen:_packImage()
    if not self.pack then return nil end
    local SP = require("src.ui.shop.ShopPerspective")
    local img = SP.v4Art and SP.v4Art(self.pack.id)
    if img then return SP.crisp(img), img end
    local fb = PackSleeve.getImage(self.pack.id, self.pack.kind)
    return fb, fb
end

function PackOpenScreen:_packDrawScale(img)
    local z = self:_z()
    local ih = img and img:getHeight() or 80
    return math.max(2, math.floor(z.cardH * 1.05 / ih))
end

function PackOpenScreen:_scheduleTimeline()
    local T = self:_timing()
    local still = reducedMotion()

    self:_tween(self, "_bgAlpha", 1, still and 0.2 or 0.3, linear)
    if not still then
        self._packYOff = love.graphics.getHeight() * 0.6
        self:_tween(self, "_packYOff", 0, T.enter, outBack)
        self:_at(T.enter, function()
            if not self._instant then Sfx.play("sceneRustle", { pitch = 0.85, volume = 0.8 }) end
        end)
        self:_at(T.enter + 0.3, function()
            if not self._instant then Sfx.play("sceneRustle", { pitch = 0.97, volume = 0.9 }) end
        end)
        self:_at(T.enter + 0.6, function()
            if not self._instant then Sfx.play("sceneRustle", { pitch = 1.1, volume = 1 }) end
        end)
        self:_at(T.chargeEnd - PackOpenScreen.STRIP_LEAD, function() self:_stripTop() end)
    end

    self:_at(T.chargeEnd, function() self:_tearOpen() end)
    self:_at(T.header, function()
        self:_buildTitleTexts()
        local h = self:_z().header
        self._headerOff = -(h.y + h.h + 8)
        self:_tween(self, "_headerOff", 0, still and 0 or 0.35, outBack)
        self:_tween(self, "_footerAlpha", 1, 0.2, linear)
    end)

    local at = T.firstCard
    local lastLand = at
    for i, card in ipairs(self.pack.instances) do
        local dealAt = at
        self:_at(dealAt, function() self:_dealCard(i, card) end)
        self:_at(dealAt + T.fly, function() self:_landCard(i, card) end)
        lastLand = dealAt + T.fly
        at = at + T.stagger + (isRare(card) and T.rareHold or 0)
    end
    self._readyAt = lastLand + T.ready
    self:_at(self._readyAt, function()
        self._cardsReady = true
        self._skipReady = true
        if self.skipButton then self.skipButton:setEnabled(true) end
    end)
end

PackOpenScreen.STRIP_LEAD = 0.2
PackOpenScreen.STRIP_FRAC = 0.2
local stripCache = {}

function PackOpenScreen.stripRowsFor(id, ih)
    if stripCache[id] ~= nil then return stripCache[id] end
    local top = 0
    for _, p in ipairs({ "assets/sprites/shop/v5/" .. tostring(id) .. ".png",
                         "assets/sprites/shop/v4/" .. tostring(id) .. ".png" }) do
        if love.filesystem.getInfo(p) then
            local ok, data = pcall(love.image.newImageData, p)
            if ok and data then
                local found = false
                for y = 0, data:getHeight() - 1 do
                    for x = 0, data:getWidth() - 1 do
                        local _, _, _, a = data:getPixel(x, y)
                        if a > 0.5 then found = true break end
                    end
                    if found then top = y break end
                end
                data:release()
            end
            break
        end
    end
    local rows = top + math.floor((ih - top) * PackOpenScreen.STRIP_FRAC)
    stripCache[id] = rows
    return rows
end

function PackOpenScreen:_stripTop()
    if self._instant or reducedMotion() or not self.pack then return end
    local img = self:_packImage()
    if not img then return end
    local rows = PackOpenScreen.stripRowsFor(self.pack.id, img:getHeight())
    local cx, cy = self:_packCenter()
    local s = self:_packDrawScale(img) * (self._packScale or 1)
    self._burst:strip(img, cx, cy, s, rows)
    self._stripRows = rows
    self._stripQuad = love.graphics.newQuad(0, rows, img:getWidth(), img:getHeight() - rows,
        img:getWidth(), img:getHeight())
    Sfx.play("shopPackOpenTear", { volume = 1 })
    if _G.jiggleScreen then _G.jiggleScreen(0.5) end
end

function PackOpenScreen:_tearOpen()
    self._sleeveExploded = true
    local th = self._theme
    local still = reducedMotion()
    local cx, cy = self:_packCenter()

    if not self._instant then
        if th.sealCode and Sfx.has and Sfx.has(th.sealCode) then
            Sfx.play(th.sealCode)
        else
            Sfx.play("packSealBreak", { pitch = th.sealPitch or 1 })
        end
        if th.sfxAccent and Sfx.has and Sfx.has(th.sfxAccent) then
            Sfx.play(th.sfxAccent, { volume = th.accentVol or 0.5, pitch = th.accentPitch or 1 })
        end
    end

    if still or self._instant then
        self:_tween(self, "_packAlpha", 0, self._instant and 0 or 0.2, linear)
        return
    end
    self._packVisible = false
    local _, base = self:_packImage()
    local s = self:_packDrawScale(base) * (self._packScale or 1)
    self._burst:tear(base, cx, cy, s, self._stripRows or 0)
    self._burst:burst(cx, cy, 1)
    if FlashShader and FlashShader.trigger then FlashShader.trigger(0.22, 0.22) end
    if _G.jiggleScreen then _G.jiggleScreen(1.0) end
end

function PackOpenScreen:_dealCard(i, card)
    local T = self:_timing()
    local still = reducedMotion()
    local fp = self._finalCardPositions[i]
    local scale = self._cardScale
    card._packShown = true
    card._packDispatched = true
    card.dissolve = 1
    card.dissolve_colours = self:_dissolvePalette(card)
    if still or self._instant then
        card:setRenderPos(fp.x, fp.y)
        card.currentScale = scale
    else
        local cx, cy = self:_packCenter()
        local s0 = scale * 0.55
        local w0 = card.image:getWidth() * s0
        local h0 = card.image:getHeight() * s0
        card:setRenderPos(cx - w0 * 0.5, cy - h0 * 0.5)
        card:setTargetPos(fp.x, fp.y)
        card.currentScale = s0
        self:_tween(card, "currentScale", scale, T.fly, outBack)
    end
    card.x, card.y = card.renderX, card.renderY
    card.layoutX, card.layoutY = fp.x, fp.y
    self:_tween(card, "dissolve", 0, 0.35, outCubic)
    if not self._instant then
        local basePitch = (self._theme and self._theme.revealPitch) or 0.9
        Sfx.play("packCardReveal", { pitch = basePitch + (i - 1) * 0.07, volume = 0.6 })
    end
end

function PackOpenScreen:_landCard(i, card)
    local still = reducedMotion()
    local rare = isRare(card)
    card._landed = true
    if self._instant then
        card._tagPop = 1
        card.dissolve = 0
        return
    end
    Sfx.play("cardShelfPlace", { volume = 0.9, pitch = 0.95 + i * 0.03 })
    card._tagPop = 0
    self:_tween(card, "_tagPop", 1, still and 0 or (rare and 0.4 or 0.25), outBack)
    if not still and card.juice_up then card:juice_up(rare and 0.45 or 0.22, rare and 0.12 or 0.06) end
    if rare then
        if card.rarity == "legendary" and Sfx.has and Sfx.has("cardDiscovered") then
            Sfx.play("cardDiscovered", { volume = 0.8 })
        else
            Sfx.play("packCardPick", { volume = 0.45, pitch = 1.25 })
        end
        if not still and _G.jiggleScreen then _G.jiggleScreen(0.35) end
    end
end

function PackOpenScreen:fastForward()
    if not self.visible or self._cardsReady or self._closing then return false end
    self._instant = true
    self._burst:clear()
    self:_fireBeats(math.huge)
    self:_finishTweens()
    self._bgAlpha = 1
    self._packVisible = false
    self._packAlpha = 0
    self._packYOff = 0
    self._headerOff = 0
    self._footerAlpha = 1
    for i, card in ipairs(self.pack.instances) do
        local fp = self._finalCardPositions[i]
        card:setRenderPos(fp.x, fp.y)
        card.currentScale = self._cardScale
        card.dissolve = 0
        card._tagPop = 1
    end
    self._t = math.max(self._t, self._readyAt or self._t)
    self._instant = false
    Sfx.play("cardShelfPlace", { volume = 0.9 })
    return true
end

function PackOpenScreen:_updateChooseText()
    if not self.chooseText then return end
    local label = self.choicesRemaining > 0
        and I18n.t("pack.choose", { n = self.choicesRemaining })
        or I18n.t("pack.closing")
    if self.chooseText.text ~= label then
        self.chooseText:setText(label)
        self.chooseText:pulse(0.4, 0.4)
    end
end

function PackOpenScreen:skip()
    if self._closing then return end
    if not self._cardsReady then self:fastForward() end
    Sfx.play("cardDeselect", { volume = 0.8 })
    self:close()
end

function PackOpenScreen:close()
    if self._closing or not self.pack then return end
    self._closing = true
    local T = self:_timing()
    local still = reducedMotion()
    self:_clearCardSelection()

    local vh = love.graphics.getHeight()
    for _, card in ipairs(self.pack.instances or {}) do
        if card._packShown and not card._chosen then
            if not still then self:_tween(card, "targetY", vh + 30, 0.45, inCubic, 0.15) end
            self:_tween(card, "dissolve", 1, 0.35, linear, still and 0 or 0.3)
        end
    end
    local h = self:_z().header
    self:_tween(self, "_headerOff", -(h.y + h.h + 8), still and 0 or 0.3, outCubic)
    self:_tween(self, "_bgAlpha", 0, 0.35, linear, T.closeAt - 0.4)
    Sfx.play("shopLeaveWhoosh", { volume = 0.8 })
    self._closeAt = self._t + T.closeAt
end

function PackOpenScreen:_finishClose()
    local cb = self.onComplete
    local selected = self._selectedCards
    self:hide()
    if cb then cb(selected) end
end

function PackOpenScreen:selectCard(card)
    if self._closing or not self._cardsReady then return end
    if not card or card._chosen then return end
    if self.choicesRemaining <= 0 then return end
    local still = reducedMotion()

    card._chosen = true
    table.insert(self._selectedCards, card)
    self.choicesRemaining = self.choicesRemaining - 1

    if card.juice_up and not still then card:juice_up(0.5, 0.15) end
    if FlashShader and FlashShader.trigger then FlashShader.trigger(0.25, 0.18) end
    Sfx.play("packCardPick", { pitch = (self._theme and self._theme.sealPitch) or 1 })
    if not still and _G.jiggleScreen then _G.jiggleScreen(0.4) end

    local vw = love.graphics.getWidth()
    local cardW = card.image:getWidth() * (card.currentScale or 1)
    if not still then
        self:_tween(card, "_selLift", self:_liftMax(), 0.15, outBack)
        self:_tween(card, "targetX", vw - cardW * 0.7, 0.45, inOutCubic, 0.3)
        self:_tween(card, "targetY", -card.image:getHeight() * card.currentScale * 0.8, 0.45, inOutCubic, 0.3)
        self:_tween(card, "currentScale", (card.currentScale or 1) * 0.45, 0.45, inOutCubic, 0.3)
    else
        card._selLift = 0
    end
    self:_tween(card, "dissolve", 1, 0.25, linear, still and 0.1 or 0.55)

    self:_updateChooseText()
    if self.choicesRemaining <= 0 then
        self:close()
    end
end

function PackOpenScreen:_setCardSelection(idx, card)
    if self.selectedCard and self.selectedCard ~= card then
        self:_tween(self.selectedCard, "_selLift", 0, 0.12, outCubic)
    end
    self.selectedCardIdx = idx
    self.selectedCard = card

    local btnH = 36
    local selLabel = I18n.t("reward.select_card", nil, "ESCOLHER")
    local selW = math.max(120, FontManager.getFont(10):getWidth(selLabel) + 40)
    self.selectButton = Button:new(0, 0, selW, btnH, selLabel,
        function()
            local toSelect = self.selectedCard
            self:_clearCardSelection()
            if toSelect then self:selectCard(toSelect) end
        end, nil, 10)

    local cancelLabel = I18n.t("reward.cancel", nil, "Cancelar")
    local cancelW = math.max(100, FontManager.getFont(10):getWidth(cancelLabel) + 40)
    self.cancelButton = Button:new(0, 0, cancelW, btnH, cancelLabel,
        function()
            Sfx.play("cardDeselect", { volume = 0.8 })
            self:_clearCardSelection()
        end, nil, 10)
    self.cancelButton:setIcon("x_close")

    local still = reducedMotion()
    self:_tween(self, "_selectionAnim", 1, 0.18, outCubic)
    self:_tween(card, "_selLift", self:_liftMax(), still and 0 or 0.18, outBack)
    if card.juice_up and not still then card:juice_up(0.18, 0.05) end
    Sfx.play("cardSelect", { pitch = 1.05 + (math.random() * 2 - 1) * 0.06 })
end

function PackOpenScreen:_clearCardSelection()
    if self.selectedCard then
        self:_tween(self.selectedCard, "_selLift", 0, 0.12, outCubic)
    end
    self.selectedCardIdx = nil
    self.selectedCard = nil
    self.selectButton = nil
    self.cancelButton = nil
    self:_tween(self, "_selectionAnim", 0, 0.12, outCubic)
end

function PackOpenScreen:update(dt)
    if not self.visible then return end
    local T = self:_timing()
    local still = reducedMotion()
    self._t = self._t + dt
    self:_fireBeats(self._t)
    if not self.visible then return end
    self:_updateTweens(dt)
    self._mood:update(dt, still)
    self._burst:update(dt)

    if self._packVisible and not still and not self._sleeveExploded then
        local t = self._t
        local p = math.max(0, math.min(1, (t - T.enter) / math.max(0.01, T.chargeEnd - T.enter)))
        p = p * p
        self._packRot = 0.05 * (math.sin(5 * t) + math.cos(0.33 + 41.15 * t) + math.cos(67.12 * t)) * p
        self._packScale = 1 + 0.12 * p
        self._chargeP = p
        if p > 0 then
            local img = self:_packImage()
            local s = self:_packDrawScale(img) * self._packScale
            local w, h = img:getWidth() * s, img:getHeight() * s
            local cx, cy = self:_packCenter()
            self._burst:charge(dt, 10 + 80 * p, cx - w * 0.5, cy - h * 0.5, w, h)
        end
    end

    if self.titleText then self.titleText:update(dt) end
    if self.chooseText then self.chooseText:update(dt) end
    if self.skipButton then self.skipButton:update(dt) end
    if self.selectButton then self.selectButton:update(dt) end
    if self.cancelButton then self.cancelButton:update(dt) end

    for _, card in ipairs(self.pack.instances) do
        if card._packShown and card.updateRender then card:updateRender(dt) end
    end

    if not self._closing and self._cardsReady then
        local mx, my = love.mouse.getPosition()
        for _, card in ipairs(self.pack.instances) do
            if card._packShown and card.updateMouse then
                local interactive = (card.dissolve or 0) < 0.2 and not card._chosen
                card:updateMouse(mx, my, dt, interactive)
            end
        end
    end

    if self._closeAt and self._t >= self._closeAt then
        self:_finishClose()
    end
end

function PackOpenScreen:_drawPack()
    if not self._packVisible and (self._packAlpha or 0) <= 0.01 then return end
    if self._sleeveExploded and not reducedMotion() then return end
    local img = self:_packImage()
    if not img then return end
    local cx, cy = self:_packCenter()
    local s = self:_packDrawScale(img) * (self._packScale or 1)
    love.graphics.setColor(1, 1, 1, self._packAlpha or 1)
    local px, py = math.floor(cx), math.floor(cy + (self._packYOff or 0))
    local ox, oy = img:getWidth() * 0.5, img:getHeight() * 0.5
    local function blit()
        if self._stripQuad then
            love.graphics.draw(img, self._stripQuad, px, py, self._packRot or 0, s, s, ox, oy - self._stripRows)
        else
            love.graphics.draw(img, px, py, self._packRot or 0, s, s, ox, oy)
        end
    end
    blit()
    local glow = math.max(0, ((self._chargeP or 0) - 0.55) / 0.45)
    if glow > 0 and not self._sleeveExploded then
        local th = self._theme
        local step = math.floor(glow * 4) / 4
        local prevMode, prevAlpha = love.graphics.getBlendMode()
        love.graphics.setBlendMode("add", "alphamultiply")
        love.graphics.setColor(th.titleHi[1], th.titleHi[2], th.titleHi[3], 0.45 * step)
        blit()
        love.graphics.setBlendMode(prevMode, prevAlpha)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function PackOpenScreen:_cardDrawOrder()
    local list, top = {}, {}
    for _, card in ipairs(self.pack.instances) do
        if card._packShown and (card.dissolve or 0) < 0.999 then
            if card.isHovered or card == self.selectedCard or card._chosen then
                top[#top + 1] = card
            else
                list[#list + 1] = card
            end
        end
    end
    for _, c in ipairs(top) do list[#list + 1] = c end
    return list
end

function PackOpenScreen:draw()
    if not self.visible then return end
    local still = reducedMotion()

    self._mood:drawBackground(self._bgAlpha or 0)
    self._mood:drawMotes(self._bgAlpha or 0, still)

    self:_drawPack()
    self._burst:drawBits()
    self._burst:drawFragments()

    for _, card in ipairs(self:_cardDrawOrder()) do
        local rx = card.renderX or card.x or 0
        local ry = (card.renderY or card.y or 0) - (card._selLift or 0)
        card:draw(rx, ry, false, true)
    end

    self:_drawRarityTags()
    self:_drawHeaderBand()
    self:_drawDetailBand()
    self:_drawActionBand()

    love.graphics.setColor(1, 1, 1, 1)
end

function PackOpenScreen:_cardAt(x, y)
    for i = #self.pack.instances, 1, -1 do
        local card = self.pack.instances[i]
        if card and card._packShown and not card._chosen and (card.dissolve or 0) < 0.2 then
            local s = card.currentScale or 1
            local w, h = card.image:getWidth() * s, card.image:getHeight() * s
            local rx = card.renderX or card.x or 0
            local ry = (card.renderY or card.y or 0) - (card._selLift or 0)
            if x >= rx and x <= rx + w and y >= ry and y <= ry + h then return i, card end
        end
    end
    return nil
end

function PackOpenScreen:mousepressed(x, y, button)
    if not self.visible then return false end
    if self._closing then return true end
    if not self._cardsReady then
        self:fastForward()
        return true
    end

    if self._skipReady and self.skipButton and self.skipButton:mousepressed(x, y, button) then
        return true
    end
    if self.selectButton and self.selectButton:mousepressed(x, y, button) then return true end
    if self.cancelButton and self.cancelButton:mousepressed(x, y, button) then return true end

    local i, card = self:_cardAt(x, y)
    if card then
        if self.selectedCardIdx == i then
            self:_clearCardSelection()
            self:selectCard(card)
        else
            self:_setCardSelection(i, card)
        end
        return true
    end

    if self.selectedCardIdx then self:_clearCardSelection() end
    return true
end

function PackOpenScreen:mousereleased(x, y, button)
    if not self.visible then return false end
    if self.skipButton and self.skipButton:mousereleased(x, y, button) then return true end
    if self.selectButton and self.selectButton:mousereleased(x, y, button) then return true end
    if self.cancelButton and self.cancelButton:mousereleased(x, y, button) then return true end
    return false
end

function PackOpenScreen:keypressed(key)
    if not self.visible then return false end
    if self._closing then return true end
    if not self._cardsReady then
        if key == "escape" or key == "return" or key == "space" or key == "kpenter" then
            self:fastForward()
            return true
        end
        return false
    end
    if key == "escape" and self._skipReady then
        self:skip()
        return true
    end
    return false
end

function PackOpenScreen:_drawHeaderBand()
    local fa = self._footerAlpha or 0
    if fa <= 0.01 then return end
    local z = self:_z()
    local h = z.header
    local th = self._theme
    love.graphics.push()
    love.graphics.translate(0, math.floor(self._headerOff or 0))

    local PF = Palette.PANEL_FILL
    PixelCanvas.rect(h.x, h.y, h.w, h.h, { PF[1], PF[2], PF[3], (PF[4] or 1) * fa * 0.92 })
    PixelCanvas.rectOutline(h.x, h.y, h.w, h.h,
        { th.accent[1] * 0.55, th.accent[2] * 0.55, th.accent[3] * 0.55, fa })
    PixelCanvas.rect(h.x + 3, h.y + 3, h.w - 6, 3, { th.titleHi[1], th.titleHi[2], th.titleHi[3], fa })

    local nameCx = h.x + h.w * 0.42
    if self.titleText then self.titleText:draw(nameCx, h.y + 24) end
    if self.chooseText and (self.choicesRemaining or 1) > 1 then
        self.chooseText:draw(nameCx, h.y + 46)
    end

    local b = self.skipButton
    if b then
        b.x = math.floor(h.x + h.w - b.width - 12)
        b.y = math.floor(h.y + (h.h - b.height) * 0.5)
        if fa > 0.75 then b:draw() end
        if self._skipReady and not self._closing then
            require("src.ui.NavCursor").action("y", function() self:skip() end,
                b.x, b.y, b.width, b.height)
        end
    end
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
end

function PackOpenScreen:_tagRect(card)
    local z = self:_z()
    local s = card.currentScale or 1
    local imgW = card.image:getWidth() * s
    local rx = card.renderX or card.x or 0
    return rx, z.tags.y, imgW, z.tags.h
end

function PackOpenScreen:_drawRarityTags()
    if not (self.pack and self.pack.instances) or self._closing then return end
    local z = self:_z()
    local font = FontManager.getFont(11)
    love.graphics.setFont(font)
    for _, card in ipairs(self.pack.instances) do
        local pop = card._tagPop or 0
        if card._packShown and card.rarity and not card._chosen and pop > 0.01
            and (card.dissolve or 0) < 0.5 then
            local rx, ty, imgW, th = self:_tagRect(card)
            local label = TextCase.upper(I18n.t("rarity." .. card.rarity, nil, card.rarity))
            local cx = math.floor(rx + imgW * 0.5)
            local cy = math.floor(ty + th * 0.5)
            local rc = Palette.forRarity(card.rarity)
            local lit = { rc[1] + (1 - rc[1]) * 0.45, rc[2] + (1 - rc[2]) * 0.45,
                          rc[3] + (1 - rc[3]) * 0.45, math.min(1, pop) }
            local amp = isRare(card) and 0.9 or 0.5
            local sc = 1 + amp * (1 - math.min(1, pop))
            sc = math.min(sc, (z.tags.h + 6) / th)
            love.graphics.push()
            love.graphics.translate(cx, cy)
            love.graphics.scale(sc, sc)
            ShopEngraving.marker(0, 0, label, lit, 11, 3)
            love.graphics.pop()
            love.graphics.setFont(font)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function PackOpenScreen:_focusedCard()
    if not (self.pack and self.pack.instances) then return nil end
    for _, card in ipairs(self.pack.instances) do
        if card._packShown and card.isHovered and not card._chosen and (card.dissolve or 0) < 0.2 then
            return card
        end
    end
    if self.selectedCard and not self.selectedCard._chosen then return self.selectedCard end
    return nil
end

function PackOpenScreen:_drawDetailBand()
    if not self._cardsReady or self._closing then return end
    local z = self:_z()
    local d = z.detail
    local th = self._theme
    local card = self:_focusedCard()
    if not card then return end

    love.graphics.setColor(Palette.INK[1], Palette.INK[2], Palette.INK[3], 0.92)
    love.graphics.rectangle("fill", d.x, d.y, d.w, d.h)
    love.graphics.setColor(th.accent[1] * 0.5, th.accent[2] * 0.5, th.accent[3] * 0.5, 1)
    love.graphics.rectangle("line", d.x, d.y, d.w, d.h)

    local PAD = 16
    local chipW, chipH, chipGap = 76, 40, 8
    local chips = {}
    if require("src.ui.CardFrame").showsManaCost(card) then
        chips[#chips + 1] = { I18n.t("pack.chip_cost"), tostring(card.cost or 0), Palette.AGED_GOLD_LIGHT }
    end
    if (card.attack or 0) > 0 then
        chips[#chips + 1] = { I18n.t("pack.chip_damage"), tostring(card.attack), Palette.forCardType("attack") }
    elseif (card.defense or 0) > 0 then
        chips[#chips + 1] = { I18n.t("pack.chip_defense"), tostring(card.defense), Palette.forCardType("defense") }
    end
    local chipsW = #chips * chipW + math.max(0, #chips - 1) * chipGap
    local textW = d.w - PAD * 2 - (chipsW > 0 and (chipsW + PAD) or 0)

    local okN, hName = pcall(I18n.cardName, card)
    love.graphics.setFont(FontManager.getFont(15))
    love.graphics.setColor(Palette.AGED_GOLD_LIGHT[1], Palette.AGED_GOLD_LIGHT[2], Palette.AGED_GOLD_LIGHT[3], 1)
    love.graphics.printf((okN and hName) or card.name or "?", d.x + PAD, d.y + 10, textW, "left")

    local typeLabel = I18n.t("card_type." .. (card.type or "unknown"), nil, card.type or "?")
    local rarLabel = card.rarity and I18n.t("rarity." .. card.rarity, nil, card.rarity) or nil
    love.graphics.setFont(FontManager.getFont(9))
    local tc = Palette.forCardType(card.type)
    love.graphics.setColor(tc[1], tc[2], tc[3], 1)
    love.graphics.printf(TextCase.upper(typeLabel) .. (rarLabel and ("  ·  " .. TextCase.upper(rarLabel)) or ""),
        d.x + PAD, d.y + 13, textW, "right")

    love.graphics.setColor(th.accent[1], th.accent[2], th.accent[3], 0.45)
    love.graphics.rectangle("fill", d.x + PAD, d.y + 34, textW, 1)

    local okD, hDesc = pcall(I18n.cardDesc, card)
    local desc = (okD and hDesc) or card.description or ""
    love.graphics.setFont(FontManager.getFont(10))
    love.graphics.setColor(Palette.PARCHMENT_LIGHT[1], Palette.PARCHMENT_LIGHT[2], Palette.PARCHMENT_LIGHT[3], 0.95)
    love.graphics.printf(desc, d.x + PAD, d.y + 42, textW, "left")

    if card.effects and #card.effects > 0 then
        local parts = {}
        for i = 1, math.min(3, #card.effects) do
            local okE, txt = pcall(I18n.effectDesc, card.effects[i])
            if okE and txt and txt ~= "" and not (txt:find("_") and not txt:find(" ")) then
                parts[#parts + 1] = txt
            end
        end
        love.graphics.setFont(FontManager.getFont(8))
        love.graphics.setColor(th.titleHi[1], th.titleHi[2], th.titleHi[3], 0.75)
        love.graphics.printf(table.concat(parts, "   ·   "), d.x + PAD, d.y + d.h - 20, textW, "left")
    end

    local cx = d.x + d.w - PAD - chipsW
    local cy = d.y + math.floor((d.h - chipH) * 0.5)
    for _, c in ipairs(chips) do
        ShopEngraving.valuePlate(cx, cy, chipW, chipH, c[1], c[2],
            { accent = c[3], seed = ShopEngraving.seedOf(card.id) })
        cx = cx + chipW + chipGap
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function PackOpenScreen:_drawActionBand()
    if not self._cardsReady or self._closing then return end
    local z = self:_z()
    local a = z.action
    local th = self._theme

    if self.selectedCard and self.selectButton and self.cancelButton then
        local gap = 12
        local totalW = self.selectButton.width + self.cancelButton.width + gap
        local bx = math.floor(a.x + (a.w - totalW) * 0.5)
        local by = math.floor(a.y + (a.h - self.selectButton.height) * 0.5)
        self.selectButton.x, self.selectButton.y = bx, by
        self.cancelButton.x = bx + self.selectButton.width + gap
        self.cancelButton.y = by
        self.selectButton:draw()
        self.cancelButton:draw()
    elseif self.choicesRemaining > 0 then
        local pulse = reducedMotion() and 1 or (0.82 + 0.18 * math.sin(self._t * 3))
        local f = FontManager.getFont(14)
        love.graphics.setFont(f)
        local hint = I18n.t("pack.click_hint")
        local hw = f:getWidth(hint)
        FontManager.drawWithOutline(hint,
            math.floor(a.x + (a.w - hw) * 0.5),
            math.floor(a.y + (a.h - f:getHeight()) * 0.5),
            { th.titleHi[1], th.titleHi[2], th.titleHi[3], pulse }, 0.9)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return PackOpenScreen
