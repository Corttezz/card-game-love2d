local Debug = require("src.core.Debug")

local PackOpenScreen = {}
PackOpenScreen.__index = PackOpenScreen

local Config         = require("src.core.Config")
local Debug          = require("src.core.Debug")
local FontManager    = require("src.ui.FontManager")
local Palette        = require("src.ui.Palette")
local ShopEngraving = require("src.ui.ShopEngraving")
local PixelCanvas    = require("src.ui.PixelCanvas")
local Button         = require("components.Button")
local Sfx            = require("src.systems.Sfx")
local EventManager   = require("engine.EventManager")
local FlashShader    = require("src.ui.FlashShader")
local DynaText       = require("src.ui.DynaText")
local PackSleeve     = require("src.ui.PackSleeve")
local PackThemes     = require("src.ui.PackThemes")
local Layout         = require("src.ui.PackChoiceLayout")
local ImageCache     = require("src.ui.ImageCache")
local I18n           = require("src.i18n.I18n")

local function reducedMotion()
    return (_G.gameSettings and _G.gameSettings.reducedMotion) or false
end

local TIMING = {
    sleeveAppear   = 0.0,
    sleeveExplode  = 0.7,
    cardSpawn      = 1.3,
    cardStagger    = 0.10,
    titleAppear    = 1.5,
    skipEnable     = 1.7,
}

local function sleeveCenter(zones)
    local sw = love.graphics.getWidth()
    if zones and zones.cards then
        return sw * 0.5, zones.cards.y + zones.cards.h * 0.5
    end
    return sw * 0.5, love.graphics.getHeight() * 0.42
end

function PackOpenScreen:_computeZones()
    local inst = self.pack and self.pack.instances and self.pack.instances[1]
    local imgW = (inst and inst.image and inst.image:getWidth()) or 96
    local imgH = (inst and inst.image and inst.image:getHeight()) or 144
    local n = (self.pack and self.pack.instances and #self.pack.instances) or 3
    self._zones = Layout.compute(n, imgW, imgH)
    return self._zones
end

function PackOpenScreen:_z()
    return self._zones or self:_computeZones()
end

function PackOpenScreen:new()
    local instance = setmetatable({}, PackOpenScreen)
    instance.visible = false
    instance.pack = nil
    instance.onComplete = nil
    instance.choicesRemaining = 0
    instance.skipButton = nil
    instance._closing = false
    instance._selectedCards = {}
    instance._sleeveDissolve = 1
    instance._sleeveExploded = false
    instance._sleeveScale = 1
    instance._sleeveTilt = 0
    instance._burstScale = 0
    instance._burstAlpha = 0
    instance._burstRotation = 0
    instance._cardsReady = false
    instance._theme = PackThemes.get("Standard")
    instance._elapsed = 0
    instance._washAlpha = 0
    instance._ringT = nil
    instance._debris = nil
    instance._footerAlpha = 0
    instance.selectedCardIdx = nil
    instance.selectedCard = nil
    instance.selectButton = nil
    instance._selectionAnim = 0
    instance.titleText = nil
    instance.chooseText = nil
    instance._skipReady = false
    return instance
end

function PackOpenScreen:show(pack, onComplete)
    self.visible = true
    self.pack = pack
    self.onComplete = onComplete
    self.choicesRemaining = pack.choose or 1
    self._closing = false
    self._selectedCards = {}
    self._sleeveDissolve = 1
    self._sleeveExploded = false
    self._sleeveScale = 1
    self._sleeveTilt = 0
    self._burstScale = 0
    self._burstAlpha = 0
    self._burstRotation = 0
    self._cardsReady = false
    self._theme = PackThemes.get(pack.kind)
    self._elapsed = 0
    self._washAlpha = 0
    self._ringT = nil
    self._debris = nil
    self._footerAlpha = 0
    self._skipReady = false
    self.selectedCardIdx = nil
    self.selectedCard = nil
    self.selectButton = nil
    self._selectionAnim = 0

    self:_layoutCards()
    self:_buildSkipButton()
    self.titleText = nil
    self.chooseText = nil
    self:_scheduleTimeline()

    pcall(PackThemes.registerSealSounds)

    Sfx.play("shopOpen")
end

function PackOpenScreen:hide()
    self.visible = false
    self.pack = nil
    self.skipButton = nil
    self.titleText = nil
    self.chooseText = nil
    self._selectedCards = {}
end

function PackOpenScreen:isVisible() return self.visible end

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
    if self._buildSkipButton then self:_buildSkipButton() end
end

function PackOpenScreen:_dissolvePalette()
    local th = self._theme or PackThemes.get("Standard")
    return {
        {th.glow[1], th.glow[2], th.glow[3], 1.0},
        {th.titleHi[1], th.titleHi[2], th.titleHi[3], 1.0},
    }
end

function PackOpenScreen:_layoutCards()
    if not self.pack or not self.pack.instances then return end
    local n = #self.pack.instances
    if n == 0 then return end

    local z = self:_computeZones()
    local scale = z.cardScale
    self._cardScale = scale
    local cardW, cardH = z.cardW, z.cardH
    local cx, cy = sleeveCenter(z)

    self._finalCardPositions = {}

    for i, card in ipairs(self.pack.instances) do
        local finalX, finalY = Layout.cardPos(z, i)
        self._finalCardPositions[i] = { x = finalX, y = finalY }

        local spawnX, spawnY
        if card._packDispatched then
            spawnX, spawnY = finalX, finalY
        else
            spawnX = cx - cardW * 0.5
            spawnY = cy - cardH * 0.5
        end
        if card.setRenderPos then
            card:setRenderPos(spawnX, spawnY)
        else
            card.renderX = spawnX
            card.renderY = spawnY
        end
        card.targetX = spawnX
        card.targetY = spawnY
        card.x = spawnX
        card.y = spawnY
        card._posInitialized = true

        card.baseScale = scale
        card.currentScale = scale
        card.targetScale = scale *
            ((Config.Cards.HOVER_SCALE or 1.466) / (Config.Cards.BASE_SCALE or 1.333))
        card.isRewardCard = true
        card._packIndex = i

        if not card._packDispatched then
            card.dissolve = 1
            card.dissolve_colours = self:_dissolvePalette()
        end
    end
end

function PackOpenScreen:_buildSkipButton()
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()
    local label = I18n.t("common.skip")
    local btnH = 34
    local btnW = math.max(90, FontManager.getFont(12):getWidth(label) + 46)
    local footerY = sh * 0.78
    local x = sw * 0.78
    self.skipButton = Button:new(x, footerY, btnW, btnH, label,
        function() self:close() end,
        nil, 12)
    self.skipButton:setIcon("x_close")
    self.skipButton:setEnabled(false)
end

function PackOpenScreen:_buildTitleTexts()
    local th = self._theme
    local kindLabel = self:_kindLabel()
    self.titleText = DynaText.new({
        text = kindLabel,
        fontSize = 26,
        bump = true,
        bump_phase = 0.42,
        bump_amount = 0.45,
        rotate = true,
        pop_in = 0.5,
        pop_in_rate = 4,
        spacing = 2,
        colours = {
            {th.titleHi[1], th.titleHi[2], th.titleHi[3], 1},
            {th.titleLo[1], th.titleLo[2], th.titleLo[3], 1},
        },
        colour_cycle = 1.5,
        shadow = true,
        align = "center",
    })

    self.chooseText = DynaText.new({
        text = I18n.t("pack.choose", { n = self.choicesRemaining }),
        fontSize = 14,
        bump = false,
        rotate = false,
        pop_in = 0.7,
        pop_in_rate = 4,
        spacing = 1,
        colours = {{0.95, 0.92, 0.88, 1}},
        shadow = true,
        align = "center",
    })
end

function PackOpenScreen:_kindLabel()
    return PackThemes.label(self.pack and self.pack.kind or "Standard")
end

function PackOpenScreen:_scheduleTimeline()
    local th = self._theme
    local still = reducedMotion()

    EventManager.parallelEase(self, "_sleeveDissolve", 0, 0.4, "smooth")

    if not still then
        EventManager.parallel(0.45, function()
            if _G.jiggleScreen then _G.jiggleScreen(0.4) end
            EventManager.parallelEase(self, "_sleeveScale", 0.93, 0.22, "smooth")
        end)
    end

    EventManager.parallel(TIMING.sleeveExplode, function()
        self._sleeveExploded = true

        if FlashShader and FlashShader.trigger then
            FlashShader.trigger(still and 0.25 or 0.35, still and 0.20 or 0.32)
        end
        self._washAlpha = still and 0.09 or 0.16

        self._ringT = 0

        if not still and _G.jiggleScreen then _G.jiggleScreen(1.2) end

        if th.sealCode and Sfx.has and Sfx.has(th.sealCode) then
            Sfx.play(th.sealCode)
        else
            Sfx.play("packSealBreak", { pitch = th.sealPitch or 1 })
        end
        if th.sfxAccent and Sfx.has and Sfx.has(th.sfxAccent) then
            Sfx.play(th.sfxAccent, { volume = th.accentVol or 0.5, pitch = th.accentPitch or 1 })
        end

        EventManager.parallelEase(self, "_sleeveDissolve", 1, 0.22, "easeout")
        EventManager.parallelEase(self, "_sleeveScale", 1.55, 0.28, "easeout")

        local bScale = th.burstScale or 1.8
        local bTime  = th.burstTime or 0.5
        EventManager.parallelEase(self, "_burstScale", bScale, bTime * 0.5, "easeout")
        EventManager.parallelEase(self, "_burstAlpha", 0.95, 0.12, "easeout")
        if not still then
            EventManager.parallelEase(self, "_burstRotation",
                math.pi * (th.burstSpin or 0.4), bTime, "easeout")
        end
        EventManager.parallel(0.20, function()
            EventManager.parallelEase(self, "_burstAlpha", 0, bTime * 0.9, "easeout")
        end)

        self:_spawnDebris()
    end)

    for i, card in ipairs(self.pack.instances) do
        local at = TIMING.cardSpawn + (i - 1) * TIMING.cardStagger
        EventManager.parallel(at, function()
            if card.start_materialize then
                card:start_materialize(self:_dissolvePalette(), false, 0.7)
            else
                card.dissolve = 0
            end
            local basePitch = (self._theme and self._theme.revealPitch) or 0.9
            Sfx.play("packCardReveal", { pitch = basePitch + (i - 1) * 0.08, volume = 0.6 })
            if not reducedMotion() and _G.jiggleScreen then _G.jiggleScreen(0.15) end
        end)
        EventManager.parallel(at + 0.18, function()
            local fp = self._finalCardPositions[i]
            if fp and card.setTargetPos then
                card:setTargetPos(fp.x, fp.y)
                card._packDispatched = true
            end
        end)
        EventManager.parallel(at + 0.52, function()
            if card.juice_up and not reducedMotion() then
                card:juice_up(0.22, 0.10)
            end
        end)
    end

    local lastCardAt = TIMING.cardSpawn + (#self.pack.instances - 1) * TIMING.cardStagger + 0.5
    EventManager.parallel(lastCardAt, function()
        self._cardsReady = true
    end)

    EventManager.parallel(TIMING.titleAppear, function()
        self:_buildTitleTexts()
        EventManager.parallelEase(self, "_footerAlpha", 1, 0.28, "easeout")
    end)

    EventManager.parallel(TIMING.skipEnable, function()
        self._skipReady = true
        if self.skipButton then self.skipButton:setEnabled(true) end
    end)
end

function PackOpenScreen:_burstImage()
    local th = self._theme
    local path = th and th.burstFile
    if path and love.filesystem.getInfo(path) then
        return ImageCache.get(path)
    end
    if path then
        Debug.log("[PackOpenScreen] burst do tipo ausente, usando generico:", path)
    end
    return ImageCache.get("assets/sprites/packs/effects/burst.png")
end

function PackOpenScreen:_spawnDebris()
    if reducedMotion() then return end
    local d = self._theme and self._theme.debris
    if not d or (d.count or 0) <= 0 then return end

    local cx, cy = sleeveCenter(self:_z())
    local list = {}
    for i = 1, d.count do
        local ang = (i / d.count) * math.pi * 2 + (math.random() - 0.5) * 0.6
        local spd = (d.speed or 200) * (0.6 + math.random() * 0.7)
        list[#list + 1] = {
            x = cx + math.cos(ang) * 10,
            y = cy + math.sin(ang) * 10,
            vx = math.cos(ang) * spd,
            vy = math.sin(ang) * spd * 0.85,
            age = 0,
            life = (d.life or 1) * (0.7 + math.random() * 0.5),
            rot = math.random() * math.pi,
            spin = (math.random() * 2 - 1) * (d.spin or 0),
            size = d.size or 4,
            col = (i % 3 == 0) and self._theme.accent or self._theme.glow,
        }
    end
    self._debris = list
end

function PackOpenScreen:_updateDebris(dt)
    local list = self._debris
    if not list then return end
    local d = self._theme.debris
    local grav = d.gravity or 0
    local k = (1 - (d.drag or 0.9)) * 12

    for i = #list, 1, -1 do
        local p = list[i]
        p.age = p.age + dt
        if p.age >= p.life then
            table.remove(list, i)
        else
            p.vy = p.vy + grav * dt
            local damp = math.exp(-k * dt)
            p.vx = p.vx * damp
            p.vy = p.vy * damp
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            p.rot = p.rot + p.spin * dt
        end
    end
    if #list == 0 then self._debris = nil end
end

function PackOpenScreen:_drawDebris()
    local list = self._debris
    if not list then return end
    local additive = self._theme.debris and self._theme.debris.additive

    local prevMode, prevAlphaMode = love.graphics.getBlendMode()
    if additive then love.graphics.setBlendMode("add", "alphamultiply") end
    for _, p in ipairs(list) do
        local t = p.age / p.life
        local a = (1 - t) * (1 - t)
        local s = p.size * (1 - 0.35 * t)
        love.graphics.push()
        love.graphics.translate(p.x, p.y)
        love.graphics.rotate(p.rot)
        love.graphics.setColor(p.col[1], p.col[2], p.col[3], a)
        love.graphics.rectangle("fill", -s * 0.5, -s * 0.5, s, s)
        love.graphics.pop()
    end
    love.graphics.setBlendMode(prevMode, prevAlphaMode)
    love.graphics.setColor(1, 1, 1, 1)
end

function PackOpenScreen:_drawShockwave()
    local rt = self._ringT
    if not rt then return end
    local th = self._theme
    local dur = th.ringTime or 0.5
    local p = math.min(1, rt / dur)
    local eased = 1 - (1 - p) * (1 - p) * (1 - p)
    local cx, cy = sleeveCenter(self:_z())
    local maxR = 210 * (th.ringScale or 1)
    local r = 30 + maxR * eased
    local a = (1 - p) * (1 - p) * (1 - p) * 0.80

    local prevMode, prevAlphaMode = love.graphics.getBlendMode()
    love.graphics.setBlendMode("add", "alphamultiply")

    local band = { {-7, 0.22}, {-3, 0.60}, {0, 1.00}, {3, 0.45}, {7, 0.18} }
    for _, L in ipairs(band) do
        local rr = r + L[1] * (1 + 2 * (1 - p))
        if rr > 2 then
            love.graphics.setLineWidth(math.max(1, 3 * (1 - p) + 1))
            love.graphics.setColor(th.glow[1], th.glow[2], th.glow[3], a * L[2])
            love.graphics.circle("line", cx, cy, rr)
        end
    end

    if p > 0.10 then
        local p2 = (p - 0.10) / 0.90
        local a2 = (1 - p2) * (1 - p2) * 0.40
        love.graphics.setLineWidth(math.max(1, 3 * (1 - p2)))
        love.graphics.setColor(th.accent[1], th.accent[2], th.accent[3], a2)
        love.graphics.circle("line", cx, cy, 20 + maxR * 0.72 * p2)
    end

    love.graphics.setLineWidth(1)
    love.graphics.setBlendMode(prevMode, prevAlphaMode)
    love.graphics.setColor(1, 1, 1, 1)
end

function PackOpenScreen:_drawColourWash()
    local a = self._washAlpha or 0
    if a <= 0.004 then return end
    local th = self._theme
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local prevMode, prevAlphaMode = love.graphics.getBlendMode()
    love.graphics.setBlendMode("add", "alphamultiply")
    love.graphics.setColor(th.flash[1], th.flash[2], th.flash[3], a)
    love.graphics.rectangle("fill", 0, 0, sw, sh)
    love.graphics.setBlendMode(prevMode, prevAlphaMode)
    love.graphics.setColor(1, 1, 1, 1)
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

function PackOpenScreen:close()
    if self._closing then return end
    self._closing = true

    for _, card in ipairs(self.pack.instances or {}) do
        if not card._chosen and card.start_dissolve then
            card:start_dissolve(self:_dissolvePalette(), true, 0.5, false)
        end
    end

    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    for _, card in ipairs(self._selectedCards) do
        if card.setTargetPos then
            card:setTargetPos(sw * 0.5, sh + 100)
        end
        if card.start_dissolve then
            EventManager.parallel(0.3, function()
                card:start_dissolve(self:_dissolvePalette(), true, 0.5, true)
            end)
        end
    end

    local cb = self.onComplete
    local selected = self._selectedCards
    EventManager.after(0.85, function()
        self:hide()
        if cb then cb(selected) end
    end)
end

function PackOpenScreen:selectCard(card)
    if self._closing or not self._cardsReady then return end
    if not card or card._chosen then return end
    if self.choicesRemaining <= 0 then return end

    card._chosen = true
    table.insert(self._selectedCards, card)
    self.choicesRemaining = self.choicesRemaining - 1

    if card.juice_up then card:juice_up(0.6, 0.18) end
    if FlashShader and FlashShader.trigger then FlashShader.trigger(0.35, 0.2) end
    self._washAlpha = math.max(self._washAlpha or 0, 0.09)
    Sfx.play("packCardPick", { pitch = (self._theme and self._theme.sealPitch) or 1 })
    if not reducedMotion() and _G.jiggleScreen then _G.jiggleScreen(0.5) end

    self:_updateChooseText()

    if self.choicesRemaining <= 0 then
        EventManager.after(0.35, function() self:close() end)
    end
end

function PackOpenScreen:update(dt)
    if not self.visible then return end

    self._elapsed = (self._elapsed or 0) + dt

    if not self._sleeveExploded and not reducedMotion() then
        local e = self._elapsed
        local from, to = 0.45, TIMING.sleeveExplode
        if e > from then
            local ramp = math.min(1, (e - from) / math.max(0.01, to - from))
            self._sleeveTilt = math.sin((e - from) * 55) * 0.055 * ramp
        end
    end

    if (self._washAlpha or 0) > 0 then
        self._washAlpha = math.max(0, self._washAlpha - dt * 2.6)
    end

    if self._ringT then
        self._ringT = self._ringT + dt
        if self._ringT > (self._theme.ringTime or 0.5) then self._ringT = nil end
    end

    self:_updateDebris(dt)

    if self.titleText then self.titleText:update(dt) end
    if self.chooseText then self.chooseText:update(dt) end

    if self.skipButton then self.skipButton:update(dt) end
    if self.selectButton then self.selectButton:update(dt) end
    if self.cancelButton then self.cancelButton:update(dt) end

    for _, card in ipairs(self.pack.instances) do
        if card and card.updateRender then
            card:updateRender(dt)
        end
    end

    if not self._closing and self._cardsReady then
        for _, card in ipairs(self.pack.instances) do
            if card and card.updateMouse then
                local mx, my = love.mouse.getPosition()
                local interactive = (card.dissolve or 0) < 0.2 and not card._chosen
                card:updateMouse(mx, my, dt, interactive)
            end
        end
    end
end

function PackOpenScreen:draw()
    if not self.visible then return end
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()

    do
        local Palette = require("src.ui.Palette")
        local SP = require("src.ui.shop.ShopPerspective")
        local cx, cy = sleeveCenter(self:_z())
        local base = Palette.darken(Palette.INK, 0.55)
        love.graphics.setColor(base[1], base[2], base[3], 1)
        love.graphics.rectangle("fill", 0, 0, sw, sh)
        local warm = Palette.lerp(Palette.INK, Palette.AGED_GOLD_DARK, 0.28)
        local R = math.min(sw, sh) * 0.52
        local cell = math.max(2, math.floor(math.min(sw, sh) / 240))
        local steps = { 0.30, 0.52, 0.74, 0.96 }
        for ring = #steps, 1, -1 do
            local k = 1 - (ring - 1) / #steps
            local c = Palette.lerp(base, warm, k)
            love.graphics.setColor(c[1], c[2], c[3], 1)
            local r = R * steps[ring]
            local rPrev = (ring > 1) and R * steps[ring - 1] or 0
            local r2, p2 = r * r, rPrev * rPrev
            local band = r * 0.18
            for yy = math.floor((cy - r) / cell) * cell, cy + r, cell do
                for xx = math.floor((cx - r) / cell) * cell, cx + r, cell do
                    local dx, dy = xx + cell / 2 - cx, (yy + cell / 2 - cy) * 1.15
                    local d2 = dx * dx + dy * dy
                    if d2 <= r2 then
                        local d = math.sqrt(d2)
                        if d < r - band or SP.dithered(xx / cell, yy / cell, 1 - (d - (r - band)) / band) then
                            love.graphics.rectangle("fill", xx, yy, cell, cell)
                        end
                    end
                end
            end
        end
        love.graphics.setColor(1, 1, 1, 1)
    end

    if self._sleeveDissolve < 0.99 and self.pack then
        local cx, cy = sleeveCenter(self:_z())
        local scale = self._sleeveScale or 1
        local alpha = 1 - (self._sleeveDissolve or 0)
        local okSP, SP = pcall(require, "src.ui.shop.ShopPerspective")
        local frames = okSP and SP.animFrames and SP.animFrames(self.pack.id) or nil
        if frames then
            local k = math.max(0, math.min(1, (self._elapsed or 0) / TIMING.sleeveExplode))
            local idx = math.min(#frames, math.floor(k * (#frames - 1) + 1 + 1e-6))
            if reducedMotion() then idx = 1 end
            local img = frames[idx]
            local iw, ih = img:getWidth(), img:getHeight()
            local isc = math.max(3, math.floor(scale * 4 + 0.5))
            love.graphics.setColor(1, 1, 1, alpha)
            love.graphics.draw(img, math.floor(cx), math.floor(cy), self._sleeveTilt or 0, isc, isc, iw / 2, ih / 2)
            love.graphics.setColor(1, 1, 1, 1)
        else
            PackSleeve.drawAt(self.pack.id, self.pack.kind, cx, cy, scale, alpha, {
                interactive = false,
                rotation = self._sleeveTilt or 0,
            })
        end
    end

    self:_drawShockwave()

    if (self._burstAlpha or 0) > 0.001 then
        local burst = self:_burstImage()
        if burst and burst:getWidth() > 1 then
            local cx, cy = sleeveCenter(self:_z())
            local bw, bh = burst:getWidth(), burst:getHeight()
            local s = self._burstScale or 0
            love.graphics.setColor(1, 1, 1, self._burstAlpha)
            love.graphics.draw(burst, cx, cy, self._burstRotation or 0,
                               s, s, bw / 2, bh / 2)
            love.graphics.setColor(1, 1, 1, 1)
        end
    end

    self:_drawDebris()

    if self.pack and self.pack.instances then
        for _, card in ipairs(self.pack.instances) do
            if card and card.draw then
                local rx = card.renderX or card.x or 0
                local ry = card.renderY or card.y or 0
                card:draw(rx, ry, false, true)
            end
        end
    end

    self:_drawRarityTags()
    self:_drawSelectionHalo()
    self:_drawHeaderBand()
    self:_drawDetailBand()
    self:_drawActionBand()

    self:_drawColourWash()

    love.graphics.setColor(1, 1, 1, 1)
end

function PackOpenScreen:mousepressed(x, y, button)
    if not self.visible or self._closing then return false end

    if self._skipReady and self.skipButton and self.skipButton:mousepressed(x, y, button) then
        return true
    end

    if self.selectButton and self.selectButton:mousepressed(x, y, button) then
        return true
    end
    if self.cancelButton and self.cancelButton:mousepressed(x, y, button) then
        return true
    end

    if not self._cardsReady then return true end

    for i, card in ipairs(self.pack.instances or {}) do
        if card and not card._chosen and (card.dissolve or 0) < 0.2 then
            local imgW = card.image:getWidth() * (card.currentScale or 1)
            local imgH = card.image:getHeight() * (card.currentScale or 1)
            local rx = card.renderX or card.x or 0
            local ry = card.renderY or card.y or 0
            if x >= rx and x <= rx + imgW and y >= ry and y <= ry + imgH then
                if self.selectedCardIdx == i then
                    self:_clearCardSelection()
                    self:selectCard(card)
                else
                    self:_setCardSelection(i, card)
                end
                return true
            end
        end
    end

    if self.selectedCardIdx then
        self:_clearCardSelection()
    end
    return true
end

function PackOpenScreen:mousereleased(x, y, button)
    if not self.visible then return false end
    if self.skipButton and self.skipButton:mousereleased(x, y, button) then return true end
    if self.selectButton and self.selectButton:mousereleased(x, y, button) then return true end
    if self.cancelButton and self.cancelButton:mousereleased(x, y, button) then return true end
    return false
end

function PackOpenScreen:_setCardSelection(idx, card)
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
        function() self:_clearCardSelection() end, nil, 10)
    self.cancelButton:setIcon("x_close")

    if EventManager and EventManager.parallelEase then
        EventManager.parallelEase(self, "_selectionAnim", 1, 0.18, "smooth", "pack_select")
    else
        self._selectionAnim = 1
    end

    Sfx.play("cardSelect", { pitch = 1.05 + (math.random() * 2 - 1) * 0.06 })
end

function PackOpenScreen:_clearCardSelection()
    self.selectedCardIdx = nil
    self.selectedCard = nil
    self.selectButton = nil
    self.cancelButton = nil
    if EventManager and EventManager.parallelEase then
        EventManager.parallelEase(self, "_selectionAnim", 0, 0.12, "smooth", "pack_select")
    else
        self._selectionAnim = 0
    end
end

function PackOpenScreen:_drawHeaderBand()
    local fa = self._footerAlpha or 0
    if fa <= 0.01 then return end
    local z = self:_z()
    local h = z.header
    local th = self._theme

    local PF = Palette.PANEL_FILL
    PixelCanvas.rect(h.x, h.y, h.w, h.h, {PF[1], PF[2], PF[3], (PF[4] or 1) * fa * 0.92})
    PixelCanvas.rectOutline(h.x, h.y, h.w, h.h,
        {th.accent[1] * 0.55, th.accent[2] * 0.55, th.accent[3] * 0.55, fa})
    PixelCanvas.rect(h.x + 3, h.y + 3, h.w - 6, 3,
        {th.titleHi[1], th.titleHi[2], th.titleHi[3], fa})

    local nameCx = h.x + h.w * 0.42
    if self.titleText then self.titleText:draw(nameCx, h.y + 24) end
    if self.chooseText then self.chooseText:draw(nameCx, h.y + 46) end

    if self.skipButton and fa > 0.75 then
        self.skipButton.x = math.floor(h.x + h.w - self.skipButton.width - 12)
        self.skipButton.y = math.floor(h.y + (h.h - self.skipButton.height) * 0.5)
        self.skipButton:draw()
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function PackOpenScreen:_drawSelectionHalo()
    local anim = self._selectionAnim or 0
    local card = self.selectedCard
    if not card or not card.image or anim < 0.01 then return end
    local imgW = card.image:getWidth() * (card.currentScale or 1)
    local imgH = card.image:getHeight() * (card.currentScale or 1)
    local rx = card.renderX or card.x or 0
    local ry = card.renderY or card.y or 0
    local a = 0.55 * anim * (reducedMotion() and 1
        or (0.7 + 0.3 * math.sin(love.timer.getTime() * 3.5)))
    love.graphics.setColor(Palette.AGED_GOLD[1], Palette.AGED_GOLD[2], Palette.AGED_GOLD[3], a)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", rx - 3, ry - 3, imgW + 6, imgH + 6)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

function PackOpenScreen:_drawRarityTags()
    if not self._cardsReady or self._closing then return end
    if not (self.pack and self.pack.instances) then return end
    local z = self:_z()

    local font = FontManager.getFont(11)
    love.graphics.setFont(font)
    for _, card in ipairs(self.pack.instances) do
        if card and card.rarity and not card._chosen and (card.dissolve or 0) < 0.2 then
            local imgW = card.image:getWidth() * (card.currentScale or 1)
            local rx = card.renderX or card.x or 0
            local label = require("src.i18n.TextCase").upper(I18n.t("rarity." .. card.rarity, nil, card.rarity))
            local tw = font:getWidth(label)
            local tx = math.floor(rx + (imgW - tw) * 0.5)
            local ty = math.floor(z.tags.y + (z.tags.h - font:getHeight()) * 0.5)

            local rc = Palette.forRarity(card.rarity)
            local lit = { rc[1] + (1 - rc[1]) * 0.45,
                          rc[2] + (1 - rc[2]) * 0.45,
                          rc[3] + (1 - rc[3]) * 0.45, 1 }
            ShopEngraving.marker(math.floor(tx + tw * 0.5),
                math.floor(ty + font:getHeight() * 0.5), label, lit, 11, 3)
            love.graphics.setFont(font)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function PackOpenScreen:_focusedCard()
    if not (self.pack and self.pack.instances) then return nil end
    for _, card in ipairs(self.pack.instances) do
        if card and card.isHovered and not card._chosen and (card.dissolve or 0) < 0.2 then
            return card
        end
    end
    if self.selectedCard and not self.selectedCard._chosen then
        return self.selectedCard
    end
    return nil
end

local function drawChip(x, y, w, h, label, value, colour, seed)
    ShopEngraving.valuePlate(x, y, w, h, label, value,
        { accent = colour, seed = seed or 0 })
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
        chips[#chips + 1] = { I18n.t("pack.chip_cost"), tostring(card.cost or 0),
                              Palette.AGED_GOLD_LIGHT }
    end
    if (card.attack or 0) > 0 then
        chips[#chips + 1] = { I18n.t("pack.chip_damage"), tostring(card.attack),
                              Palette.forCardType("attack") }
    elseif (card.defense or 0) > 0 then
        chips[#chips + 1] = { I18n.t("pack.chip_defense"), tostring(card.defense),
                              Palette.forCardType("defense") }
    end
    local chipsW = #chips * chipW + math.max(0, #chips - 1) * chipGap
    local textW = d.w - PAD * 2 - (chipsW > 0 and (chipsW + PAD) or 0)

    local okN, hName = pcall(I18n.cardName, card)
    love.graphics.setFont(FontManager.getFont(15))
    love.graphics.setColor(Palette.AGED_GOLD_LIGHT[1], Palette.AGED_GOLD_LIGHT[2],
                           Palette.AGED_GOLD_LIGHT[3], 1)
    love.graphics.printf((okN and hName) or card.name or "?", d.x + PAD, d.y + 10, textW, "left")

    local typeLabel = I18n.t("card_type." .. (card.type or "unknown"), nil, card.type or "?")
    local rarLabel = card.rarity and I18n.t("rarity." .. card.rarity, nil, card.rarity) or nil
    love.graphics.setFont(FontManager.getFont(9))
    local tc = Palette.forCardType(card.type)
    love.graphics.setColor(tc[1], tc[2], tc[3], 1)
    love.graphics.printf(require("src.i18n.TextCase").upper(typeLabel) .. (rarLabel and ("  -  " .. require("src.i18n.TextCase").upper(rarLabel)) or ""),
        d.x + PAD, d.y + 13, textW, "right")

    love.graphics.setColor(th.accent[1], th.accent[2], th.accent[3], 0.45)
    love.graphics.rectangle("fill", d.x + PAD, d.y + 34, textW, 1)

    local okD, hDesc = pcall(I18n.cardDesc, card)
    local desc = (okD and hDesc) or card.description or ""
    love.graphics.setFont(FontManager.getFont(10))
    love.graphics.setColor(Palette.PARCHMENT_LIGHT[1], Palette.PARCHMENT_LIGHT[2],
                           Palette.PARCHMENT_LIGHT[3], 0.95)
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
        love.graphics.printf(table.concat(parts, "   -   "),
            d.x + PAD, d.y + d.h - 20, textW, "left")
    end

    local cx = d.x + d.w - PAD - chipsW
    local cy = d.y + math.floor((d.h - chipH) * 0.5)
    for _, c in ipairs(chips) do
        drawChip(cx, cy, chipW, chipH, c[1], c[2], c[3],
            ShopEngraving.seedOf(card.id))
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
        local pulse = reducedMotion() and 1
            or (0.82 + 0.18 * math.sin(love.timer.getTime() * 3))
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

function PackOpenScreen:keypressed(key)
    if not self.visible then return false end
    if key == "escape" and self._skipReady then
        self:close()
        return true
    end
    return false
end

return PackOpenScreen
