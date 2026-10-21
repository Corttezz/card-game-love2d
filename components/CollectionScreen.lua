local Debug        = require("src.core.Debug")
local FontManager  = require("src.ui.FontManager")
local Palette      = require("src.ui.Palette")
local PixelBackground = require("src.ui.PixelBackground")
local PixelCanvas  = require("src.ui.PixelCanvas")
local SceneBackground = require("src.ui.SceneBackground")
local CardDatabase = require("src.systems.CardDatabase")
local CardAnimationLayer = require("src.ui.card.CardAnimationLayer")
local CardArt      = require("src.ui.CardArt")
local CardFrame    = require("src.ui.CardFrame")
local CardMesh     = require("src.ui.CardMesh")
local I18n         = require("src.i18n.I18n")
local Sfx          = require("src.systems.Sfx")
local UnlockSystem = require("src.systems.UnlockSystem")
local CardBack     = require("src.ui.CardBack")
local BestiaryGrid = require("src.ui.BestiaryGrid")
local Bestiary     = require("src.systems.Bestiary")

local CollectionScreen = {}
CollectionScreen.__index = CollectionScreen

local RARITY_ORDER = { basic = 1, common = 2, uncommon = 3, rare = 4, legendary = 5 }
local CLASS_ORDER  = { warrior = 1, mage = 2, rogue = 3, [""] = 4 }

local FILTERS = {
    { id = "all",     i18n = "collection.filter_all" },
    { id = "warrior", i18n = "collection.filter_warrior" },
    { id = "mage",    i18n = "collection.filter_mage" },
    { id = "rogue",   i18n = "collection.filter_rogue" },
    { id = "attack",  i18n = "collection.filter_attack" },
    { id = "defense", i18n = "collection.filter_defense" },
    { id = "joker",   i18n = "collection.filter_joker" },
    { id = "effect",  i18n = "collection.filter_effect" },
}

local function filterLabel(f) return I18n.t(f.i18n) end

local CARD_W, CARD_H = 128, 192
local GAP_X, GAP_Y = 18, 24
local COLS = 5
local TOP_OFFSET = 120
local BOTTOM_PAD = 40

function CollectionScreen:new()
    local self = setmetatable({}, CollectionScreen)
    self.visible = false
    self.scrollY = 0
    self.maxScrollY = 0
    self.hoverCard = nil
    self.filter = "all"
    self.cardInstances = {}
    self.filtered = {}
    self.onCloseCallback = nil
    self.inspectedCard = nil
    self.inspectAnim = 0
    self.section = "cards"
    self.bestiary = BestiaryGrid.new()
    return self
end

CollectionScreen.SECTIONS = {
    { id = "cards", i18n = "bestiary.ui.tab_cards" },
    { id = "creatures", i18n = "bestiary.ui.tab" },
}

local function sectionRects()
    local font = FontManager.getFont(12)
    local x, out = 20, {}
    for _, sct in ipairs(CollectionScreen.SECTIONS) do
        local w = font:getWidth(I18n.t(sct.i18n)) + 24
        out[#out + 1] = { id = sct.id, label = I18n.t(sct.i18n), x = x, y = 16, w = w, h = 30 }
        x = x + w + 6
    end
    return out
end
CollectionScreen._sectionRects = sectionRects

function CollectionScreen:setSection(id)
    if self.section == id then return end
    self.section = id
    self.hoverCard = nil
    self.inspectedCard = nil
    if id == "creatures" then self.bestiary:show() end
end

function CollectionScreen:ownsNavigation()
    return self.inspectedCard ~= nil or (self.section == "creatures" and self.bestiary:isOpen())
end

function CollectionScreen:sectionHasNew(id)
    if id == "creatures" then return Bestiary.anyNew() end
    return self:freshInFilter("all")
end

local function sortCards(list)
    table.sort(list, function(a, b)
        local ca = CLASS_ORDER[a.class or ""] or 99
        local cb = CLASS_ORDER[b.class or ""] or 99
        if ca ~= cb then return ca < cb end
        local ra = RARITY_ORDER[a.rarity or "common"] or 99
        local rb = RARITY_ORDER[b.rarity or "common"] or 99
        if ra ~= rb then return ra < rb end
        return I18n.cardName(a) < I18n.cardName(b)
    end)
end

function CollectionScreen:_buildInstances(budgetSecs)
    if self._buildDone then return end
    if not self._buildList then
        local db = CardDatabase:new()
        local all = db:getAllCards()
        local list = {}
        for _, cd in pairs(all) do list[#list + 1] = cd end
        sortCards(list)
        self._buildList = list
        self._buildIdx = 0
        self._buildDb = db
    end
    local t0 = love.timer.getTime()
    local budget = budgetSecs or 0.006
    while self._buildIdx < #self._buildList do
        self._buildIdx = self._buildIdx + 1
        local cd = self._buildList[self._buildIdx]
        local db = self._buildDb
        if not UnlockSystem.isCardDiscovered(cd.id) then
            self.cardInstances[#self.cardInstances + 1] = self:_makeHidden(cd)
        else
            local ok, instance = pcall(function() return db:createCardInstance(cd) end)
            if ok and instance then
                self.cardInstances[#self.cardInstances + 1] = instance
            else
                Debug.warn("[CollectionScreen] falha ao instanciar carta: " .. tostring(cd.id))
            end
        end
        if (love.timer.getTime() - t0) >= budget then break end
    end
    if self._buildIdx >= #self._buildList then
        self._buildDone = true
        self._buildList = nil
        self._buildDb = nil
    end
    self:_applyFilter()
end

function CollectionScreen:_makeHidden(cd)
    return {
        id = cd.id, name = cd.name, class = cd.class, type = cd.type,
        rarity = cd.rarity, _hidden = true,
        _locked = not UnlockSystem.isCardUnlockedReal(cd.id),
    }
end

function CollectionScreen:_refreshDiscovery()
    if not self._buildDone then return end
    local db
    for i, inst in ipairs(self.cardInstances) do
        if inst._hidden then
            if UnlockSystem.isCardDiscovered(inst.id) then
                db = db or CardDatabase:new()
                local cd = db:getCard(inst.id)
                local ok, real = pcall(function() return db:createCardInstance(cd) end)
                if ok and real then
                    self.cardInstances[i] = real
                else
                    Debug.warn("[CollectionScreen] falha ao revelar carta: " .. tostring(inst.id))
                end
            else
                inst._locked = not UnlockSystem.isCardUnlockedReal(inst.id)
            end
        end
    end
end

function CollectionScreen:_applyFilter()
    self._hasManualOrder = false
    self.filtered = {}
    for _, inst in ipairs(self.cardInstances) do
        local match = false
        if self.filter == "all" then
            match = true
        elseif self.filter == "warrior" or self.filter == "mage" or self.filter == "rogue" then
            match = inst.class == self.filter
        elseif self.filter == "attack" or self.filter == "defense"
            or self.filter == "joker" or self.filter == "effect" then
            match = inst.type == self.filter
        end
        if match then self.filtered[#self.filtered + 1] = inst end
    end
    local disc = 0
    for _, inst in ipairs(self.filtered) do
        if not inst._hidden then disc = disc + 1 end
    end
    self.discoveredCount = disc
    local rows = math.ceil(#self.filtered / COLS)
    local contentH = rows * (CARD_H + GAP_Y)
    local viewH = love.graphics.getHeight() - TOP_OFFSET - BOTTOM_PAD
    self.maxScrollY = math.max(0, contentH - viewH)
    self.scrollY = math.min(self.scrollY, self.maxScrollY)
end

function CollectionScreen:show(onClose)
    self.visible = true
    self.scrollY = 0
    self.onCloseCallback = onClose
    self:_refreshDiscovery()
    self._fresh = {}
    for id in pairs(UnlockSystem.freshSet()) do self._fresh[id] = true end
    self._pulsed = {}
    self._tabFresh = nil
    self:_buildInstances(0.012)
    self:_applyFilter()
    if self.section == "creatures" then self.bestiary:show() else self.bestiary:refresh() end
end

function CollectionScreen:hide()
    self.visible = false
    self.hoverCard = nil
end

function CollectionScreen:isVisible()
    return self.visible
end

function CollectionScreen:resize()
    self.bestiary:resize()
    self._mysteryCanvas = nil
    self._lockedCanvas = nil
    self:_applyFilter()
end

local function gridOrigin()
    local width = love.graphics.getWidth()
    local totalW = COLS * CARD_W + (COLS - 1) * GAP_X
    local startX = (width - totalW) / 2
    return startX, TOP_OFFSET
end

local function cardRect(index)
    local col = (index - 1) % COLS
    local row = math.floor((index - 1) / COLS)
    local ox, oy = gridOrigin()
    return ox + col * (CARD_W + GAP_X), oy + row * (CARD_H + GAP_Y)
end

function CollectionScreen:update(dt)
    if not self.visible then return end
    if not self._buildDone then self:_buildInstances() end
    if self.section == "creatures" then
        local mx, my = love.mouse.getPosition()
        self.hoverCard = nil
        self.bestiary:update(dt, mx, my)
        return
    end
    if self.inspectedCard then
        self.inspectAnim = math.min(1, self.inspectAnim + dt * 6)
    else
        self.inspectAnim = math.max(0, self.inspectAnim - dt * 8)
    end
    if self.inspectedCard or self._draggingIdx then
        self.hoverCard = nil
        return
    end
    local mx, my = love.mouse.getPosition()
    local prevHover = self.hoverCard and self.hoverCard.instance or nil
    self.hoverCard = nil
    local inGrid = my >= TOP_OFFSET and my <= love.graphics.getHeight() - BOTTOM_PAD
    for i, inst in ipairs(inGrid and self.filtered or {}) do
        local x, y = cardRect(i)
        y = y - self.scrollY
        if mx >= x and mx <= x + CARD_W and my >= y and my <= y + CARD_H then
            self.hoverCard = { instance = inst, x = x, y = y, index = i }
            break
        end
    end
    local newHover = self.hoverCard and self.hoverCard.instance or nil
    if newHover and newHover ~= prevHover then
        Sfx.playWithVariation("hoverCard", 0.95, 0.18)
    end
    if newHover then self:_seeFresh(newHover) end
end

function CollectionScreen:_seeFresh(inst)
    if inst._hidden or not (self._fresh and self._fresh[inst.id]) then return end
    self._fresh[inst.id] = nil
    self._tabFresh = nil
    UnlockSystem.clearFresh(inst.id)
end

function CollectionScreen:freshInFilter(filterId)
    if not self._buildDone or not next(self._fresh or {}) then return false end
    if not self._tabFresh then
        local tabs = {}
        for _, inst in ipairs(self.cardInstances) do
            if not inst._hidden and self._fresh[inst.id] then
                tabs.all = true
                if inst.class then tabs[inst.class] = true end
                if inst.type then tabs[inst.type] = true end
            end
        end
        self._tabFresh = tabs
    end
    return self._tabFresh[filterId] and true or false
end

function CollectionScreen:wheelmoved(x, y)
    if not self.visible then return end
    if self.inspectedCard then return end
    if self.section == "creatures" then return self.bestiary:wheelmoved(x, y) end
    self.scrollY = math.max(0, math.min(self.maxScrollY, self.scrollY - y * 40))
end

function CollectionScreen:keypressed(key)
    if not self.visible then return end
    if self.section == "creatures" and self.bestiary:keypressed(key) then return end
    if self.inspectedCard then
        if key == "escape" or key == "space" or key == "return" then
            Sfx.play("menuClose")
            self.inspectedCard = nil
        elseif key == "left" or key == "a" then
            Sfx.play("collectionFlip")
            self:_inspectNeighbor(-1)
        elseif key == "right" or key == "d" then
            Sfx.play("collectionFlip")
            self:_inspectNeighbor(1)
        end
        return
    end
    if key == "escape" then
        self:hide()
        if self.onCloseCallback then self.onCloseCallback() end
    elseif key == "up" or key == "pageup" then
        self.scrollY = math.max(0, self.scrollY - 100)
    elseif key == "down" or key == "pagedown" then
        self.scrollY = math.min(self.maxScrollY, self.scrollY + 100)
    end
end

function CollectionScreen:_inspectNeighbor(delta)
    if not self.inspectedCard then return end
    local idx = nil
    for i, inst in ipairs(self.filtered) do
        if inst == self.inspectedCard then idx = i; break end
    end
    if not idx then return end
    local n = #self.filtered
    local newIdx = idx
    for _ = 1, n do
        newIdx = ((newIdx - 1 + delta) % n) + 1
        if not self.filtered[newIdx]._hidden then break end
    end
    self.inspectedCard = self.filtered[newIdx]
    self.inspectAnim = 0.3
end

local function closeRect()
    return love.graphics.getWidth() - 52, 24, 30, 30
end

local function inRect(x, y, rx, ry, rw, rh)
    return x >= rx and x <= rx + rw and y >= ry and y <= ry + rh
end

function CollectionScreen:mousepressed(x, y, button)
    if not self.visible then return end
    if button == 1 and not self:ownsNavigation() then
        for _, r in ipairs(sectionRects()) do
            if inRect(x, y, r.x, r.y, r.w, r.h) then
                Sfx.play("buttonClick")
                self:setSection(r.id)
                return
            end
        end
    end
    if self.section == "creatures" and self.bestiary:isOpen() then
        self.bestiary:mousepressed(x, y, button)
        return
    end
    if button == 1 and not self.inspectedCard and inRect(x, y, closeRect()) then
        Sfx.play("menuClose")
        self:hide()
        if self.onCloseCallback then self.onCloseCallback() end
        return
    end
    if self.section == "creatures" then
        self.bestiary:mousepressed(x, y, button)
        return
    end
    if button == 1 then
        if self.inspectedCard then
            local w, h = love.graphics.getDimensions()
            local cardW, cardH = 384, 576
            local cardX = (w - cardW) / 2 - 140
            local cardY = (h - cardH) / 2
            local arrowY = h / 2 - 30
            if x >= 20 and x <= 100 and y >= arrowY and y <= arrowY + 60 then
                Sfx.play("collectionFlip")
                self:_inspectNeighbor(-1)
                return
            end
            if x >= w - 100 and x <= w - 20 and y >= arrowY and y <= arrowY + 60 then
                Sfx.play("collectionFlip")
                self:_inspectNeighbor(1)
                return
            end
            if x < cardX or x > cardX + cardW + 320 or y < cardY - 20 or y > cardY + cardH + 20 then
                Sfx.play("menuClose")
                self.inspectedCard = nil
            end
            return
        end
        local font = FontManager.getFont(14)
        local tabY = 70
        local tabX = 20
        love.graphics.setFont(font)
        for _, f in ipairs(FILTERS) do
            local w = font:getWidth(filterLabel(f)) + 20
            if x >= tabX and x <= tabX + w and y >= tabY and y <= tabY + 28 then
                Sfx.play("buttonClick")
                self.filter = f.id
                self.scrollY = 0
                self:_applyFilter()
                return
            end
            tabX = tabX + w + 8
        end
        local inGrid = y >= TOP_OFFSET and y <= love.graphics.getHeight() - BOTTOM_PAD
        for i, inst in ipairs(inGrid and self.filtered or {}) do
            local cx, cy = cardRect(i)
            cy = cy - self.scrollY
            if x >= cx and x <= cx + CARD_W and y >= cy and y <= cy + CARD_H then
                self._dragPendingIdx = i
                self._dragStartMX = x
                self._dragStartMY = y
                self._dragOffsetX = cx - x
                self._dragOffsetY = cy - y
                self._draggingIdx = nil
                return
            end
        end
    end
end

function CollectionScreen:_computeDropIndex(mx, my)
    local total = #self.filtered
    if total <= 1 then return 1 end
    local w = love.graphics.getWidth()
    local totalW = COLS * CARD_W + (COLS - 1) * GAP_X
    local ox = (w - totalW) / 2
    local oy = TOP_OFFSET
    local col = math.floor((mx - ox + GAP_X / 2) / (CARD_W + GAP_X))
    col = math.max(0, math.min(COLS - 1, col))
    local row = math.floor((my - oy + self.scrollY + GAP_Y / 2) / (CARD_H + GAP_Y))
    row = math.max(0, row)
    local idx = row * COLS + col + 1
    return math.max(1, math.min(total, idx))
end

function CollectionScreen:mousemoved(x, y, dx, dy)
    if not self.visible or self.inspectedCard or self.section == "creatures" then return end
    if self._dragPendingIdx and not self._draggingIdx then
        local Config = require("src.core.Config")
        local threshold = (Config.Cards and Config.Cards.DRAG_THRESHOLD_PX) or 6
        local distX = x - self._dragStartMX
        local distY = y - self._dragStartMY
        if (distX * distX + distY * distY) > (threshold * threshold) then
            self._draggingIdx = self._dragPendingIdx
        end
    end
end

function CollectionScreen:mousereleased(x, y, button)
    if not self.visible then return end
    if button ~= 1 then return end
    if self.section == "creatures" then
        self.bestiary:mousereleased(x, y, button)
        return
    end

    if self._draggingIdx then
        local dropIdx = self:_computeDropIndex(x, y)
        if dropIdx ~= self._draggingIdx then
            local inst = table.remove(self.filtered, self._draggingIdx)
            table.insert(self.filtered, dropIdx, inst)
            Sfx.play("collectionFlip")
            self._hasManualOrder = true
        end
    elseif self._dragPendingIdx then
        local inst = self.filtered[self._dragPendingIdx]
        if inst and inst._hidden then
            Sfx.play("buttonClick", { pitch = 0.7 })
        elseif inst then
            Sfx.play("collectionFlip")
            self.inspectedCard = inst
            self.inspectAnim = 0
        end
    end

    self._dragPendingIdx = nil
    self._draggingIdx = nil
end

local function drawBackground()
    local w, h = love.graphics.getDimensions()
    if SceneBackground.draw("collection", w, h, 0.55) then return end
    local bg = PixelBackground.voidStars(w, h)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(bg, 0, 0)
    love.graphics.setColor(Palette.INK[1], Palette.INK[2], Palette.INK[3], 0.55)
    love.graphics.rectangle("fill", 0, 0, w, h)
end

local function drawSections(self)
    local NavCursor = require("src.ui.NavCursor")
    local mx, my = love.mouse.getPosition()
    local font = FontManager.getFont(12)
    for _, r in ipairs(sectionRects()) do
        local active = self.section == r.id
        local hot = inRect(mx, my, r.x, r.y, r.w, r.h) and not self:ownsNavigation()
        Palette.set(Palette.INK, 0.6)
        love.graphics.rectangle("fill", r.x + 2, r.y + 3, r.w, r.h)
        if active then
            Palette.set(Palette.AGED_GOLD)
        else
            Palette.set(hot and Palette.PARCHMENT_DARK or Palette.INK, hot and 1 or 0.85)
        end
        love.graphics.rectangle("fill", r.x, r.y, r.w, r.h)
        Palette.set(active and Palette.AGED_GOLD_LIGHT or Palette.AGED_GOLD_DARK)
        love.graphics.rectangle("line", r.x + 0.5, r.y + 0.5, r.w - 1, r.h - 1)
        if active then
            Palette.set(Palette.AGED_GOLD_LIGHT)
            love.graphics.rectangle("fill", r.x + 2, r.y + 2, r.w - 4, 1)
        end
        love.graphics.setFont(font)
        Palette.set(active and Palette.INK or Palette.PARCHMENT_LIGHT)
        love.graphics.print(r.label, r.x + 12, r.y + math.floor((r.h - font:getHeight()) / 2) + 1)
        if not active and self:sectionHasNew(r.id) then
            require("src.ui.DiscoveryMark").drawAlert(r.x + r.w - 4, r.y - 2)
        end
        NavCursor.target("section:" .. r.id, r.x, r.y, r.w, r.h)
    end
end

local function drawTitleAndFilters(self)
    local width = love.graphics.getWidth()

    local titleFont = FontManager.getResponsiveFont(0.05, 36)
    love.graphics.setFont(titleFont)
    local title = I18n.t("collection.title")
    love.graphics.setColor(Palette.AGED_GOLD_LIGHT)
    love.graphics.print(title, (width - titleFont:getWidth(title)) / 2, 12)

    drawSections(self)

    local subFont = FontManager.getFont(14)
    love.graphics.setFont(subFont)
    if self.section == "creatures" then
        local n, total = self.bestiary:seenCount()
        local sub = I18n.t("bestiary.ui.count", { n = n, total = total })
        love.graphics.setColor(Palette.PARCHMENT_LIGHT)
        love.graphics.print(sub, (width - subFont:getWidth(sub)) / 2, 50)
        return
    end
    local sub = I18n.t("unlocks.discovered_count",
        { n = self.discoveredCount or #self.filtered, total = #self.filtered })
    love.graphics.setColor(Palette.PARCHMENT_LIGHT)
    love.graphics.print(sub, (width - subFont:getWidth(sub)) / 2, 50)

    local font = FontManager.getFont(14)
    love.graphics.setFont(font)
    local tabX = 20
    local tabY = 70
    for _, f in ipairs(FILTERS) do
        local label = filterLabel(f)
        local w = font:getWidth(label) + 20
        local active = self.filter == f.id
        if active then
            love.graphics.setColor(Palette.AGED_GOLD)
        else
            love.graphics.setColor(Palette.INK[1], Palette.INK[2], Palette.INK[3], 0.6)
        end
        love.graphics.rectangle("fill", tabX, tabY, w, 28, 4, 4)
        require("src.ui.NavCursor").target("filter:" .. f.id, tabX, tabY, w, 28)
        love.graphics.setColor(Palette.PARCHMENT_DARK)
        love.graphics.rectangle("line", tabX, tabY, w, 28, 4, 4)
        love.graphics.setColor(active and Palette.INK or Palette.PARCHMENT_LIGHT)
        love.graphics.print(label, tabX + 10, tabY + 6)
        if self:freshInFilter(f.id) then
            require("src.ui.DiscoveryMark").drawAlert(tabX + w - 4, tabY - 2)
            love.graphics.setFont(font)
        end
        tabX = tabX + w + 8
    end

    if self.maxScrollY > 0 then
        local barX = width - 12
        local barH = love.graphics.getHeight() - TOP_OFFSET - BOTTOM_PAD
        local scrollFrac = self.scrollY / self.maxScrollY
        local knobH = math.max(30, barH * (barH / (barH + self.maxScrollY)))
        love.graphics.setColor(Palette.INK[1], Palette.INK[2], Palette.INK[3], 0.5)
        love.graphics.rectangle("fill", barX, TOP_OFFSET, 6, barH)
        love.graphics.setColor(Palette.AGED_GOLD)
        love.graphics.rectangle("fill", barX, TOP_OFFSET + scrollFrac * (barH - knobH), 6, knobH)
    end
end

local function drawCardMini(instance, x, y, hoverScale, alpha, mouseUV, hoverStrength)
    if not instance.image then return end
    hoverScale = hoverScale or 1
    alpha = alpha or 1
    mouseUV = mouseUV or { 0, 0 }
    hoverStrength = hoverStrength or 0

    local _prevImage = instance.image
    instance.image = CardFrame.displayImage(instance) or instance.image

    local baseScale = CARD_W / instance.image:getWidth()
    local drawScale = baseScale * hoverScale
    local drawW = instance.image:getWidth() * drawScale
    local drawH = instance.image:getHeight() * drawScale
    local lift = (hoverScale - 1) * 30
    local cx = x + CARD_W / 2
    local cy = y + CARD_H / 2 - lift

    local Config = require("src.core.Config")
    local screenW = love.graphics.getWidth()
    local dirX = (cx - screenW / 2) / (screenW / 2)
    if dirX > 1 then dirX = 1 elseif dirX < -1 then dirX = -1 end
    local shadowMaxX = (Config.Cards and Config.Cards.SHADOW_MAX_HORIZ_OFFSET) or 20
    local shadowBaseY = (Config.Cards and Config.Cards.SHADOW_BASE_OFFSET_Y) or 6
    local shadowPressShift = (Config.Cards and Config.Cards.SHADOW_PRESS_SHIFT) or 14
    local shadowBaseAlpha = (Config.Cards and Config.Cards.SHADOW_ALPHA) or 0.50
    local baseLift = (Config.Cards and Config.Cards.BASE_LIFT) or 3

    local shadowDx = -dirX * shadowMaxX - mouseUV[1] * shadowPressShift * hoverStrength
    local shadowDy = shadowBaseY + (baseLift + lift) * 0.5
                   - mouseUV[2] * shadowPressShift * hoverStrength * 0.7
    local shAlpha = shadowBaseAlpha * alpha + (hoverScale - 1) * 0.4
    if shAlpha > 0.85 then shAlpha = 0.85 end

    local px = math.floor(cx - drawW / 2)
    local py = math.floor(cy - drawH / 2)

    local shader = (hoverStrength > 0.001) and CardMesh.getShader() or nil
    local timeNow = love.timer.getTime()
    if shader then
        local mesh = CardMesh.getMesh(instance.image:getWidth(), instance.image:getHeight())
        mesh:setTexture(instance.image)
        love.graphics.setShader(shader)
        CardMesh.setUniforms(shader, mouseUV, hoverStrength, timeNow, instance.image)
        love.graphics.setColor(0, 0, 0, shAlpha)
        love.graphics.draw(mesh,
            px + shadowDx, py + shadowDy,
            0, drawScale, drawScale)
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.draw(mesh, px, py, 0, drawScale, drawScale)
        love.graphics.setShader()
    else
        love.graphics.setColor(0, 0, 0, shAlpha)
        love.graphics.draw(instance.image,
            math.floor(px + shadowDx), math.floor(py + shadowDy),
            0, drawScale, drawScale)
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.draw(instance.image, px, py, 0, drawScale, drawScale)
    end

    if not instance._cachedArt then
        local ok, a = pcall(CardArt.resolve, instance)
        instance._cachedArt = ok and a or { bgPattern = nil }
    end
    CardAnimationLayer.draw(instance, instance._cachedArt, px, py, drawScale, drawScale)
    if instance._freshPulse and not require("src.ui.DiscoveryMark")
            .drawCollectionPulse(instance.id, instance.image, px, py, drawScale) then
        instance._freshPulse = nil
    end
    love.graphics.setColor(1, 1, 1, 1)
    instance.image = _prevImage
end

local function drawFreshBadge(x, y, hs)
    local lift = ((hs or 1) - 1) * 30
    require("src.ui.DiscoveryMark").drawAlert(x + CARD_W - 3, y + 9 - lift, 10)
    love.graphics.setColor(1, 1, 1, 1)
end
CollectionScreen._drawFreshBadge = drawFreshBadge

local function drawPadlock(cx, cy)
    local ink, gold, dark = Palette.INK, Palette.AGED_GOLD_LIGHT, Palette.AGED_GOLD_DARK
    local bw, bh = 22, 16
    local bx, by = cx - bw / 2, cy - 2
    love.graphics.setColor(ink[1], ink[2], ink[3], 0.85)
    love.graphics.rectangle("fill", bx - 6, by - 14, bw + 12, bh + 19)
    love.graphics.setColor(dark)
    love.graphics.rectangle("fill", bx + 3, by - 10, 3, 10)
    love.graphics.rectangle("fill", bx + bw - 6, by - 10, 3, 10)
    love.graphics.rectangle("fill", bx + 5, by - 12, bw - 10, 3)
    love.graphics.setColor(gold)
    love.graphics.rectangle("fill", bx + 4, by - 10, 1, 9)
    love.graphics.rectangle("fill", bx + 6, by - 11, bw - 12, 1)
    love.graphics.setColor(gold)
    love.graphics.rectangle("fill", bx, by, bw, bh)
    love.graphics.setColor(dark)
    love.graphics.rectangle("fill", bx, by + bh - 3, bw, 3)
    love.graphics.rectangle("line", bx + 0.5, by + 0.5, bw - 1, bh - 1)
    love.graphics.setColor(ink)
    love.graphics.rectangle("fill", cx - 2, by + 4, 4, 4)
    love.graphics.rectangle("fill", cx - 1, by + 8, 2, 4)
end

local function getMysteryCanvas(self, locked)
    if locked and self._lockedCanvas then return self._lockedCanvas end
    if not locked and self._mysteryCanvas then return self._mysteryCanvas end
    local W, H = CardFrame.WIDTH, CardFrame.HEIGHT
    local c = love.graphics.newCanvas(W, H)
    c:setFilter("nearest", "nearest")
    love.graphics.push("all")
    love.graphics.origin()
    love.graphics.setScissor()
    love.graphics.setShader()
    love.graphics.setCanvas(c)
    love.graphics.clear(0, 0, 0, 0)
    local img = CardBack.getImage()
    if img then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(img, 0, 0, 0, W / img:getWidth(), H / img:getHeight())
    else
        Debug.warn("[CollectionScreen] verso da carta ausente (assets/cards/back.png) — usando fallback chapado")
        love.graphics.setColor(Palette.INK)
        love.graphics.rectangle("fill", 0, 0, W, H)
        love.graphics.setColor(Palette.AGED_GOLD)
        love.graphics.rectangle("line", 1.5, 1.5, W - 3, H - 3)
    end
    love.graphics.setColor(Palette.INK[1], Palette.INK[2], Palette.INK[3], locked and 0.72 or 0.45)
    love.graphics.rectangle("fill", 0, 0, W, H)
    if locked then
        drawPadlock(math.floor(W / 2), math.floor(H / 2) - 6)
    else
        local f = FontManager.getFont(32)
        love.graphics.setFont(f)
        local q = "?"
        local qx = math.floor((W - f:getWidth(q)) / 2)
        local qy = math.floor((H - f:getHeight()) / 2)
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.print(q, qx + 2, qy + 2)
        love.graphics.setColor(Palette.AGED_GOLD_LIGHT)
        love.graphics.print(q, qx, qy)
    end
    love.graphics.pop()
    if locked then self._lockedCanvas = c else self._mysteryCanvas = c end
    return c
end

local function drawMystery(self, inst, x, y, hoverScale)
    local img = getMysteryCanvas(self, inst._locked)
    local drawScale = (CARD_W / img:getWidth()) * hoverScale
    local drawW, drawH = img:getWidth() * drawScale, img:getHeight() * drawScale
    local lift = (hoverScale - 1) * 30
    local px = math.floor(x + CARD_W / 2 - drawW / 2)
    local py = math.floor(y + CARD_H / 2 - lift - drawH / 2)
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.draw(img, px + 4, py + 7, 0, drawScale, drawScale)
    local k = inst._locked and 0.8 or 0.9
    love.graphics.setColor(k, k, k, 1)
    love.graphics.draw(img, px, py, 0, drawScale, drawScale)
    if inst._locked then
        local key, vars = UnlockSystem.getCardHint(inst.id)
        local f = FontManager.getFont(8)
        love.graphics.setFont(f)
        local tw = drawW - 20
        local _, lines = f:getWrap(I18n.t(key, vars), tw)
        local ty = math.floor(py + drawH * 0.62)
        love.graphics.setColor(Palette.INK[1], Palette.INK[2], Palette.INK[3], 0.8)
        love.graphics.rectangle("fill", px + 6, ty - 4, drawW - 12, #lines * f:getHeight() + 8)
        Palette.set(Palette.PARCHMENT_LIGHT)
        love.graphics.printf(I18n.t(key, vars), math.floor(px + 10), ty, tw, "center")
    end
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawHiddenTooltip(self, inst)
    local TIP_W, TIP_H, PAD = 300, 110, 10
    local cx = self.hoverCard.x + CARD_W + 10
    local cy = self.hoverCard.y
    if cx + TIP_W > love.graphics.getWidth() then cx = self.hoverCard.x - TIP_W - 10 end
    if cx < 0 then cx = 0 end
    if cy + TIP_H > love.graphics.getHeight() then cy = love.graphics.getHeight() - TIP_H - 10 end
    PixelCanvas.rect(cx, cy, TIP_W, TIP_H, Palette.PANEL_FILL)
    PixelCanvas.rectOutline(cx, cy, TIP_W, TIP_H, Palette.AGED_GOLD)
    PixelCanvas.rectOutline(cx + 2, cy + 2, TIP_W - 4, TIP_H - 4, Palette.AGED_GOLD_DARK)
    local nameFont = FontManager.getFont(12)
    love.graphics.setFont(nameFont)
    Palette.set(Palette.AGED_GOLD_LIGHT)
    love.graphics.print("???", cx + PAD, cy + PAD)
    local metaFont = FontManager.getFont(10)
    love.graphics.setFont(metaFont)
    if inst._locked then Palette.set(Palette.BLOOD) else Palette.set(Palette.PARCHMENT) end
    love.graphics.print(I18n.t(inst._locked and "unlocks.locked" or "unlocks.undiscovered"),
        cx + PAD, cy + PAD + 24)
    local key, vars = UnlockSystem.getCardHint(inst.id)
    local descFont = FontManager.getFont(8)
    love.graphics.setFont(descFont)
    Palette.set(Palette.PARCHMENT_LIGHT)
    love.graphics.printf(I18n.t(key, vars), cx + PAD, cy + PAD + 46, TIP_W - PAD * 2)
end

local function drawHoverTooltip(self)
    if not self.hoverCard then return end
    local inst = self.hoverCard.instance
    if inst._hidden then return drawHiddenTooltip(self, inst) end

    local TIP_W = 320
    local TIP_H = 180
    local PAD = 10
    local TEXT_W = TIP_W - PAD * 2

    local cx = self.hoverCard.x + CARD_W + 10
    local cy = self.hoverCard.y
    if cx + TIP_W > love.graphics.getWidth() then
        cx = self.hoverCard.x - TIP_W - 10
    end
    if cx < 0 then cx = 0 end
    if cy + TIP_H > love.graphics.getHeight() then
        cy = love.graphics.getHeight() - TIP_H - 10
    end

    PixelCanvas.rect(cx, cy, TIP_W, TIP_H, Palette.PANEL_FILL)
    PixelCanvas.rectOutline(cx, cy, TIP_W, TIP_H, Palette.AGED_GOLD)
    PixelCanvas.rectOutline(cx + 2, cy + 2, TIP_W - 4, TIP_H - 4, Palette.AGED_GOLD_DARK)

    local nameFont = FontManager.getFont(12)
    love.graphics.setFont(nameFont)
    Palette.set(Palette.AGED_GOLD_LIGHT)
    love.graphics.printf(I18n.cardName(inst), cx + PAD, cy + PAD, TEXT_W)

    PixelCanvas.hline(cx + PAD, cy + PAD + 30, TEXT_W, Palette.AGED_GOLD_DARK)

    local metaFont = FontManager.getFont(8)
    love.graphics.setFont(metaFont)
    local typeColor = Palette.forCardType(inst.type) or Palette.PARCHMENT
    local rarityColor = Palette.forRarity(inst.rarity) or Palette.PARCHMENT
    local typeLabel = I18n.t("card_type." .. (inst.type or "unknown"), nil, I18n.t("card_type.unknown"))
    local classLabel = inst.class and I18n.t("classes." .. inst.class .. ".name", nil, inst.class)
                                   or I18n.t("collection.class_basic")
    local rarityLabel = I18n.t("rarity." .. (inst.rarity or "common"), nil, inst.rarity or "")

    local mY = cy + PAD + 36
    local TextFit = require("src.ui.TextFit")
    local mX = cx + PAD
    local mEnd = cx + TIP_W - PAD
    Palette.set(typeColor)
    local w1 = TextFit.print(typeLabel, mX, mY,
        { size = 8, maxW = math.floor((mEnd - mX) * 0.34) })
    mX = mX + w1 + 12
    Palette.set(Palette.PARCHMENT)
    local w2 = TextFit.print(classLabel, mX, mY,
        { size = 8, maxW = math.floor((mEnd - mX) * 0.5) })
    mX = mX + w2 + 12
    Palette.set(rarityColor)
    TextFit.print(rarityLabel, mX, mY, { size = 8, maxW = mEnd - mX })

    local descFont = FontManager.getFont(8)
    love.graphics.setFont(descFont)
    Palette.set(Palette.PARCHMENT_LIGHT)
    local descText = I18n.cardDesc(inst)
    if not descText or descText == "" then descText = I18n.t("card_info.no_desc") end
    love.graphics.printf(descText, cx + PAD, cy + PAD + 54, TEXT_W)

    local statFont = FontManager.getFont(10)
    love.graphics.setFont(statFont)
    Palette.set(Palette.AGED_GOLD_LIGHT)
    local statLine = CardFrame.showsManaCost(inst)
        and (I18n.t("card_info.cost") .. tostring(inst.cost or 0)) or ""
    if inst.type == "attack" then
        statLine = statLine .. "  ATK: " .. tostring(inst.attack or 0)
    elseif inst.type == "defense" then
        statLine = statLine .. "  DEF: " .. tostring(inst.defense or 0)
    end
    love.graphics.print(statLine, cx + PAD, cy + TIP_H - 20)
end

local function drawInspectArrows(self, width, height)
    if #self.filtered <= 1 then return end
    local arrowY = height / 2 - 30
    local t = love.timer.getTime()
    local pulse = 0.7 + math.sin(t * 3) * 0.2
    local arrowFont = FontManager.getFont(48)
    love.graphics.setFont(arrowFont)
    love.graphics.setColor(Palette.AGED_GOLD_LIGHT[1], Palette.AGED_GOLD_LIGHT[2], Palette.AGED_GOLD_LIGHT[3], pulse)
    love.graphics.print("‹", 40, arrowY)
    love.graphics.print("›", width - 80, arrowY)
end

local function drawInspectModal(self)
    if not self.inspectedCard and self.inspectAnim <= 0 then return end
    local inst = self.inspectedCard or self.lastInspected
    if not inst then return end
    self.lastInspected = inst

    local width, height = love.graphics.getDimensions()
    local anim = self.inspectAnim

    love.graphics.setColor(0, 0, 0, 0.82 * anim)
    love.graphics.rectangle("fill", 0, 0, width, height)

    local scale = 4 * (0.85 + 0.15 * anim)
    local cardW = 96 * scale
    local cardH = 144 * scale
    local cardX = (width - cardW) / 2 - 140
    local cardY = (height - cardH) / 2

    local _prevImage = inst.image
    do
        local shown = CardFrame.displayImage(inst)
        if shown then inst.image = shown end
    end
    if inst.image then
        local mx, my = love.mouse.getPosition()
        local cx = cardX + cardW / 2
        local cy = cardY + cardH / 2
        local uvx = (mx - cx) / (cardW / 2)
        local uvy = (my - cy) / (cardH / 2)
        if uvx > 1 then uvx = 1 elseif uvx < -1 then uvx = -1 end
        if uvy > 1 then uvy = 1 elseif uvy < -1 then uvy = -1 end
        local uvInside = math.abs(uvx) < 1.05 and math.abs(uvy) < 1.05
        local mouseUV = uvInside and { uvx, uvy } or { 0, 0 }
        local hoverStrength = uvInside and anim or 0

        local shadowPressShift = 40
        local dirX = (cx - width / 2) / (width / 2)
        if dirX > 1 then dirX = 1 elseif dirX < -1 then dirX = -1 end
        local shDx = -dirX * 30 - uvx * shadowPressShift * hoverStrength
        local shDy = 16 - uvy * shadowPressShift * hoverStrength * 0.7

        local shader = CardMesh.getShader()
        local timeNow = love.timer.getTime()
        if shader then
            local mesh = CardMesh.getMesh(inst.image:getWidth(), inst.image:getHeight())
            mesh:setTexture(inst.image)
            love.graphics.setShader(shader)
            CardMesh.setUniforms(shader, mouseUV, hoverStrength, timeNow, inst.image)
            love.graphics.setColor(0, 0, 0, 0.55 * anim)
            love.graphics.draw(mesh, cardX + shDx, cardY + shDy, 0, scale, scale)
            love.graphics.setColor(1, 1, 1, anim)
            love.graphics.draw(mesh, cardX, cardY, 0, scale, scale)
            love.graphics.setShader()
        else
            love.graphics.setColor(0, 0, 0, 0.55 * anim)
            love.graphics.draw(inst.image, cardX + shDx, cardY + shDy, 0, scale, scale)
            love.graphics.setColor(1, 1, 1, anim)
            love.graphics.draw(inst.image, cardX, cardY, 0, scale, scale)
        end

        if not inst._cachedArt then
            local ok, a = pcall(CardArt.resolve, inst)
            inst._cachedArt = ok and a or { bgPattern = nil }
        end
        CardAnimationLayer.draw(inst, inst._cachedArt, cardX, cardY, scale, scale)
    end
    inst.image = _prevImage

    local panelX = cardX + cardW + 30
    local panelY = cardY
    local panelW = 340
    local panelH = cardH
    local PAD = 16
    local TEXT_W = panelW - PAD * 2

    love.graphics.setColor(Palette.INK[1], Palette.INK[2], Palette.INK[3], 0.92 * anim)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH)
    love.graphics.setColor(Palette.AGED_GOLD[1], Palette.AGED_GOLD[2], Palette.AGED_GOLD[3], anim)
    love.graphics.rectangle("line", panelX,     panelY,     panelW,     panelH)
    love.graphics.setColor(Palette.AGED_GOLD_DARK[1], Palette.AGED_GOLD_DARK[2], Palette.AGED_GOLD_DARK[3], anim)
    love.graphics.rectangle("line", panelX + 2, panelY + 2, panelW - 4, panelH - 4)

    local nameFont = FontManager.getFont(16)
    love.graphics.setFont(nameFont)
    love.graphics.setColor(Palette.AGED_GOLD_LIGHT[1], Palette.AGED_GOLD_LIGHT[2], Palette.AGED_GOLD_LIGHT[3], anim)
    love.graphics.printf(I18n.cardName(inst), panelX + PAD, panelY + 18, TEXT_W)

    love.graphics.setColor(Palette.AGED_GOLD[1], Palette.AGED_GOLD[2], Palette.AGED_GOLD[3], 0.6 * anim)
    love.graphics.rectangle("fill", panelX + PAD, panelY + 72, TEXT_W, 1)

    local metaFont = FontManager.getFont(10)
    love.graphics.setFont(metaFont)
    local typeColor = Palette.forCardType(inst.type) or Palette.PARCHMENT
    local rarityColor = Palette.forRarity(inst.rarity) or Palette.PARCHMENT
    local typeLabel = I18n.t("card_type." .. (inst.type or "unknown"), nil, I18n.t("card_type.unknown"))
    local classLabel = inst.class and I18n.t("classes." .. inst.class .. ".name", nil, inst.class)
                                   or I18n.t("collection.class_basic")
    local rarityLabel = I18n.t("rarity." .. (inst.rarity or "common"), nil, inst.rarity or "")

    local metaY = panelY + 84
    local lineH = metaFont:getHeight() + 4
    love.graphics.setColor(typeColor[1], typeColor[2], typeColor[3], anim)
    love.graphics.print(typeLabel, panelX + PAD, metaY)
    love.graphics.setColor(Palette.PARCHMENT[1], Palette.PARCHMENT[2], Palette.PARCHMENT[3], anim)
    love.graphics.print(classLabel, panelX + PAD, metaY + lineH)
    love.graphics.setColor(rarityColor[1], rarityColor[2], rarityColor[3], anim)
    love.graphics.print(rarityLabel, panelX + PAD, metaY + lineH * 2)

    local statFont = FontManager.getFont(12)
    love.graphics.setFont(statFont)
    love.graphics.setColor(Palette.PARCHMENT_LIGHT[1], Palette.PARCHMENT_LIGHT[2], Palette.PARCHMENT_LIGHT[3], anim)
    local statY = metaY + lineH * 3 + 12
    if CardFrame.showsManaCost(inst) then
        love.graphics.print(I18n.t("card_info.cost") .. tostring(inst.cost or 0),
            panelX + PAD, statY)
        statY = statY + 20
    end
    if inst.type == "attack" then
        love.graphics.setColor(Palette.BLOOD[1], Palette.BLOOD[2], Palette.BLOOD[3], anim)
        love.graphics.print(I18n.t("card_info.damage") .. tostring(inst.attack or 0), panelX + PAD, statY)
        statY = statY + 20
    elseif inst.type == "defense" then
        love.graphics.setColor(Palette.STEEL_LIGHT[1], Palette.STEEL_LIGHT[2], Palette.STEEL_LIGHT[3], anim)
        love.graphics.print(I18n.t("card_info.defense") .. tostring(inst.defense or 0), panelX + PAD, statY)
        statY = statY + 20
    end

    love.graphics.setColor(Palette.AGED_GOLD[1], Palette.AGED_GOLD[2], Palette.AGED_GOLD[3], 0.6 * anim)
    love.graphics.rectangle("fill", panelX + PAD, statY + 4, TEXT_W, 1)
    statY = statY + 14
    local descFont = FontManager.getFont(10)
    love.graphics.setFont(descFont)
    love.graphics.setColor(Palette.PARCHMENT_LIGHT[1], Palette.PARCHMENT_LIGHT[2], Palette.PARCHMENT_LIGHT[3], anim)
    local fullDesc = I18n.cardDesc(inst)
    if not fullDesc or fullDesc == "" then fullDesc = I18n.t("card_info.no_desc") end
    love.graphics.printf(fullDesc, panelX + PAD, statY, TEXT_W)

    if inst.effects and #inst.effects > 0 then
        local effY = statY + 80
        love.graphics.setColor(Palette.AGED_GOLD[1], Palette.AGED_GOLD[2], Palette.AGED_GOLD[3], anim)
        love.graphics.print(I18n.t("card_info.effects"), panelX + PAD, effY)
        love.graphics.setColor(Palette.PARCHMENT_LIGHT[1], Palette.PARCHMENT_LIGHT[2], Palette.PARCHMENT_LIGHT[3], anim)
        love.graphics.setFont(descFont)
        for i, e in ipairs(inst.effects) do
            local desc = I18n.effectDesc(e)
            love.graphics.printf("- " .. desc, panelX + PAD + 8, effY + 16 * i, TEXT_W - 8)
            if i >= 4 then break end
        end
    end

    local idFont = FontManager.getFont(8)
    love.graphics.setFont(idFont)
    love.graphics.setColor(Palette.PARCHMENT[1], Palette.PARCHMENT[2], Palette.PARCHMENT[3], 0.4 * anim)
    love.graphics.printf(inst.id or "", panelX + PAD, panelY + panelH - 16, TEXT_W)

    drawInspectArrows(self, width, height)

    local closeFont = FontManager.getFont(13)
    love.graphics.setFont(closeFont)
    love.graphics.setColor(Palette.AGED_GOLD_LIGHT[1], Palette.AGED_GOLD_LIGHT[2], Palette.AGED_GOLD_LIGHT[3], anim)
    local closeMsg = I18n.t(require("src.ui.NavCursor").device() == "pad"
        and "collection.inspect_help_pad" or "collection.inspect_help")
    love.graphics.print(closeMsg, (width - closeFont:getWidth(closeMsg)) / 2, height - 30)

    love.graphics.setColor(1, 1, 1, 1)
end

local function drawCloseButton()
    local cx, cy, cw, ch = closeRect()
    require("src.ui.NavCursor").target("close", cx, cy, cw, ch)
    local mx, my = love.mouse.getPosition()
    local hot = inRect(mx, my, cx, cy, cw, ch)
    Palette.set(hot and Palette.BLOOD or Palette.PANEL_FILL)
    love.graphics.rectangle("fill", cx, cy, cw, ch, 4, 4)
    Palette.set(Palette.AGED_GOLD)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", cx, cy, cw, ch, 4, 4)
    local xf = FontManager.getFont(14)
    love.graphics.setFont(xf)
    Palette.set(Palette.PARCHMENT_LIGHT)
    love.graphics.print("X", math.floor(cx + (cw - xf:getWidth("X")) / 2),
        math.floor(cy + (ch - xf:getHeight()) / 2))
    if hot then require("src.ui.CursorManager").request("hand") end
end

function CollectionScreen:draw()
    if not self.visible then return end
    drawBackground()
    drawTitleAndFilters(self)
    if self.section == "creatures" then
        self.bestiary:draw()
        if not self.bestiary:isOpen() then drawCloseButton() end
        self.bestiary:drawCard()
        love.graphics.setColor(1, 1, 1, 1)
        return
    end

    local width, height = love.graphics.getDimensions()
    local dt = love.timer.getDelta()
    local mx, my = love.mouse.getPosition()

    local hoveringIdx = self.hoverCard and self.hoverCard.index or nil

    self._cardAnim = self._cardAnim or {}
    local ease = 1 - math.exp(-18 * dt)
    for i, inst in ipairs(self.filtered) do
        local anim = self._cardAnim[inst] or { rx = 0, ry = 0, hs = 1.0, inited = false }
        local tx, ty = cardRect(i)
        ty = ty - self.scrollY
        if not anim.inited then
            anim.rx = tx; anim.ry = ty; anim.inited = true
        end
        if self._draggingIdx == i then
            anim.rx = mx + (self._dragOffsetX or 0)
            anim.ry = my + (self._dragOffsetY or 0)
        else
            anim.rx = anim.rx + (tx - anim.rx) * ease
            anim.ry = anim.ry + (ty - anim.ry) * ease
        end
        local targetHs = (i == hoveringIdx) and 1.08 or 1.0
        if self._draggingIdx == i then targetHs = 1.10 end
        anim.hs = anim.hs + (targetHs - anim.hs) * ease
        self._cardAnim[inst] = anim
    end

    local function computeMouseUV(anim)
        local cx = anim.rx + CARD_W / 2
        local cy = anim.ry + CARD_H / 2
        local uvx = (mx - cx) / (CARD_W / 2)
        local uvy = (my - cy) / (CARD_H / 2)
        if uvx > 1 then uvx = 1 elseif uvx < -1 then uvx = -1 end
        if uvy > 1 then uvy = 1 elseif uvy < -1 then uvy = -1 end
        return { uvx, uvy }
    end

    local hoverStrFromScale = function(hs) return math.max(0, math.min(1, (hs - 1.0) / 0.08)) end

    love.graphics.setScissor(0, TOP_OFFSET, width, height - TOP_OFFSET - BOTTOM_PAD)
    for i, inst in ipairs(self.filtered) do
        if i ~= self._draggingIdx and i ~= hoveringIdx then
            local anim = self._cardAnim[inst]
            if anim and anim.ry + CARD_H >= TOP_OFFSET and anim.ry <= height - BOTTOM_PAD then
                if inst._hidden then
                    drawMystery(self, inst, anim.rx, anim.ry, anim.hs)
                else
                    local fresh = self._fresh and self._fresh[inst.id]
                    if fresh and not self._pulsed[inst.id] then
                        inst._freshPulse = true
                        self._pulsed[inst.id] = true
                    end
                    drawCardMini(inst, anim.rx, anim.ry, anim.hs, 1, { 0, 0 }, 0)
                    if fresh then drawFreshBadge(anim.rx, anim.ry, anim.hs) end
                end
            end
        end
    end
    do
        local NavCursor = require("src.ui.NavCursor")
        for i in ipairs(self.filtered) do
            local cx, cy = cardRect(i)
            NavCursor.target("col:" .. i, cx, cy - self.scrollY, CARD_W, CARD_H)
        end
    end
    love.graphics.setScissor()

    if hoveringIdx then
        local inst = self.filtered[hoveringIdx]
        local anim = self._cardAnim[inst]
        local clipped = anim and (anim.ry < TOP_OFFSET or anim.ry + CARD_H > height - BOTTOM_PAD)
        if clipped then love.graphics.setScissor(0, TOP_OFFSET, width, height - TOP_OFFSET - BOTTOM_PAD) end
        if anim then
            if inst._hidden then
                drawMystery(self, inst, anim.rx, anim.ry, anim.hs)
            else
                local uv = computeMouseUV(anim)
                local str = hoverStrFromScale(anim.hs)
                drawCardMini(inst, anim.rx, anim.ry, anim.hs, 1, uv, str)
            end
        end
        if clipped then love.graphics.setScissor() end
    end

    if self._draggingIdx then
        local inst = self.filtered[self._draggingIdx]
        local anim = self._cardAnim[inst]
        if anim and inst and inst._hidden then
            drawMystery(self, inst, anim.rx, anim.ry, anim.hs)
        elseif anim and inst then
            drawCardMini(inst, anim.rx, anim.ry, anim.hs, 0.95, { 0, 0 }, 0)
        end
    end

    if not self.inspectedCard and self.inspectAnim < 0.1 then
        drawHoverTooltip(self)
    end

    if not self.inspectedCard then drawCloseButton() end

    drawInspectModal(self)

    love.graphics.setColor(1, 1, 1, 1)
end

return CollectionScreen
