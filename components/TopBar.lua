local FontManager = require("src.ui.FontManager")
local IconLoader  = require("src.ui.IconLoader")
local PixelCanvas = require("src.ui.PixelCanvas")
local Palette     = require("src.ui.Palette")
local I18n        = require("src.i18n.I18n")
local ValueEasing = require("src.ui.ValueEasing")

local TopBar = {}
TopBar.__index = TopBar

function TopBar:new()
    local instance = setmetatable({}, TopBar)

    instance.visible = true
    instance.height = 52

    instance.gearIcon = IconLoader.get("gear")

    instance.game = nil

    instance.configHover = 0
    instance.configSpin = 0
    instance.isConfigHovered = false
    instance.mapHover = 0
    instance.isMapHovered = false
    instance.mapTime = 0

    instance.disp = {}

    return instance
end

function TopBar:setGame(game)
    self.game = game
end

function TopBar:update(dt, game)
    if not self.visible then return end

    local mx, my = love.mouse.getPosition()
    self.isConfigHovered = self:isConfigIconClicked(mx, my)

    local hoverTarget = self.isConfigHovered and 1 or 0
    self.configHover = self.configHover
        + (hoverTarget - self.configHover) * math.min(1, dt * 12)
    self.configSpin = self.configSpin + dt * 3.2 * self.configHover

    self.isMapHovered = self:_mapVisible() and self:isMapIconClicked(mx, my)
    self.mapHover = self.mapHover
        + ((self.isMapHovered and 1 or 0) - self.mapHover) * math.min(1, dt * 12)
    self.mapTime = self.mapTime + dt

    local g = game or self.game
    if g and g ~= self.game then self.game = g end
    if g and g.economySystem then
        local realGold = g.economySystem.currentGold or 0
        if self._lastGold and self._lastGold ~= realGold then
            local delta = realGold - self._lastGold
            if _G.jiggleScreen then
                local amt = math.min(0.6, 0.05 + math.abs(delta) * 0.02)
                _G.jiggleScreen(amt)
            end
            self._goldFlash = {
                dir = (delta > 0) and 1 or -1,
                t = 0.6,
            }
            self:_onGoldDelta(delta)
        end
        if self._goldFlash then
            self._goldFlash.t = self._goldFlash.t - dt
            if self._goldFlash.t <= 0 then self._goldFlash = nil end
        end
        self._lastGold = realGold
        ValueEasing.tick(self.disp, "gold", realGold, dt, 6)
    end
end

function TopBar:flashGold(dir)
    self._goldFlash = { dir = ((dir or -1) > 0) and 1 or -1, t = 0.6 }
end

function TopBar:_onGoldDelta(delta)
    if delta > 0 then
        local mag = math.min(1, delta / 25)
        local Sfx = require("src.systems.Sfx")
        Sfx.play("goldGain", { pitch = 0.94 + mag * 0.18, volume = 0.45 + mag * 0.2 })
    end

    local slots = self:_layout()
    local slot = slots and slots.gold
    if not slot then return end
    local alvoX = slot.x + slot.w * 0.5

    if delta > 0 then
        local okCB, CoinBurst = pcall(require, "src.ui.CoinBurst")
        if okCB then CoinBurst.spawn(delta, alvoX, self.height - 10) end
    end

    local okFT, FloatingText = pcall(require, "src.ui.FloatingText")
    if not okFT or not FloatingText.spawn then return end

    local sign = (delta > 0) and "+" or ""
    FloatingText.spawn(sign .. delta, alvoX, self.height - 6, {
        kind = "gold",
        color = (delta > 0) and nil or { 0.90, 0.35, 0.30, 1 },
        lift = 20,
    })
end

function TopBar:_layout()
    local sw = love.graphics.getWidth()
    local f14 = FontManager.getFont(14)
    local f9 = FontManager.getFont(9)
    local ICON_W = 50
    local PAD_R = 14

    local blocks = {}
    local function add(key, line1, line2)
        local w = math.max(f14:getWidth(line1 or ""), f9:getWidth(line2 or ""))
        table.insert(blocks, { key = key, w = ICON_W + math.ceil(w) + PAD_R })
    end

    if self.game and self.game.economySystem then
        add("gold", "$88888", I18n.t("top_bar.interest_suffix", { amount = 8 }))
    end
    if self.game and self.game.deck then
        add("deck", I18n.t("top_bar.deck_cards", { n = 88 }),
            I18n.t("top_bar.hand_suffix", { n = 8 }))
    end
    if self.game and self.game.scoreSystem then
        local label = I18n.t("top_bar.score_record")
        local label2 = I18n.t("top_bar.score_label")
        if f9:getWidth(label2) > f9:getWidth(label) then label = label2 end
        add("score", "888888", label)
    end
    local run = self.game and self.game.runManager
        and self.game.runManager.currentRun
    if run then
        local l1 = run.endlessMode and I18n.t("top_bar.endless")
            or I18n.t("top_bar.act", { n = 8 })
        local mods = require("src.ui.RunModsText").short(run, true)
        add("progress", l1, I18n.t("top_bar.floor", { x = 8, total = 8 })
            .. (mods ~= "" and (" · " .. mods) or ""))
    end

    local gap = 22
    local total = gap * math.max(0, #blocks - 1)
    for _, b in ipairs(blocks) do total = total + b.w end

    local x = math.max(16, math.floor((sw - total) / 2))
    local out = {}
    for _, b in ipairs(blocks) do
        out[b.key] = { x = x, w = b.w }
        x = x + b.w + gap
    end
    return out
end

function TopBar:_hoverZone(x0, w, tipName, ctx)
    require("src.ui.NavCursor").target("topbar:" .. tostring(tipName), x0, 0, w, self.height)
    local mx, my = love.mouse.getPosition()
    local hovered = mx >= x0 and mx <= x0 + w and my >= 0 and my <= self.height
    if hovered then
        PixelCanvas.rect(math.floor(x0), 3, math.floor(w), self.height - 8,
            { 0.32, 0.26, 0.11, 0.38 })
        if tipName then
            local okST, StatusTooltip = pcall(require, "src.ui.StatusTooltip")
            if okST and StatusTooltip.show then
                StatusTooltip.show(tipName, mx, my, ctx)
            end
        end
    end
    return hovered
end

function TopBar:draw()
    if not self.visible then return end
    self:_navTargets()

    local screenWidth = love.graphics.getWidth()

    self:drawFrame(screenWidth)
    self:drawGameInfo()
    self:drawMapIcon()
    self:drawConfigIcon()
end

local BAND_TOP = { 0.105, 0.080, 0.056, 0.98 }
local BAND_BOT = { 0.045, 0.034, 0.026, 0.98 }

function TopBar:drawFrame(sw)
    local h = self.height
    local bands = 6
    for i = 0, bands - 1 do
        local k = i / (bands - 1)
        local y0 = math.floor(i * h / bands)
        local y1 = math.floor((i + 1) * h / bands)
        PixelCanvas.rect(0, y0, sw, y1 - y0, {
            BAND_TOP[1] + (BAND_BOT[1] - BAND_TOP[1]) * k,
            BAND_TOP[2] + (BAND_BOT[2] - BAND_TOP[2]) * k,
            BAND_TOP[3] + (BAND_BOT[3] - BAND_TOP[3]) * k, 0.98 })
    end
    local gl, g, gd = Palette.AGED_GOLD_LIGHT, Palette.AGED_GOLD, Palette.AGED_GOLD_DARK
    PixelCanvas.hline(0, 0, sw, { gl[1], gl[2], gl[3], 0.10 })
    PixelCanvas.hline(0, h - 3, sw, { gd[1], gd[2], gd[3], 0.55 })
    PixelCanvas.hline(0, h, sw, g)
    PixelCanvas.hline(0, h + 1, sw, gd)
    PixelCanvas.hline(0, h + 2, sw, { 0, 0, 0, 0.45 })

    local L = self:_layout()
    local keys = { "gold", "deck", "score", "progress" }
    local slots = {}
    for _, k in ipairs(keys) do if L[k] then slots[#slots + 1] = L[k] end end
    if #slots == 0 then return end
    local x0 = slots[1].x - 14
    local x1 = slots[#slots].x + slots[#slots].w + 2
    self:_diamond(x0, h, 3, g, gl)
    self:_diamond(x1, h, 3, g, gl)
    self:_diamond(math.floor(sw / 2), h, 2, g, gl)
    for i = 2, #slots do
        local sx = math.floor((slots[i - 1].x + slots[i - 1].w + slots[i].x) / 2) - 2
        PixelCanvas.vline(sx, 12, h - 24, { gd[1], gd[2], gd[3], 0.9 })
        PixelCanvas.pixel(sx, 11, gd)
        self:_diamond(sx, math.floor(h / 2), 2, gd, g)
    end
end

function TopBar:_diamond(cx, cy, r, edge, core)
    for dy = -r, r do
        local half = r - math.abs(dy)
        PixelCanvas.hline(cx - half, cy + dy, half * 2 + 1, edge)
    end
    if r >= 2 then
        for dy = -(r - 1), r - 1 do
            local half = r - 1 - math.abs(dy)
            PixelCanvas.hline(cx - half, cy + dy, half * 2 + 1, core)
        end
    end
end

local ICON_PX = 32
local TEXT_DX = 44

local function drawIcon(name, x, cy)
    local icon = IconLoader.get(name)
    if icon and icon.draw then
        love.graphics.setColor(1, 1, 1, 1)
        icon.draw(x, cy - math.floor(ICON_PX / 2), ICON_PX / icon.size.w)
    end
    return icon
end

local function printShadowed(text, x, y, color)
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.print(text, x + 1, y + 1)
    if color then Palette.set(color) end
    love.graphics.print(text, x, y)
end

local ROMAN = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X" }

function TopBar:drawGameInfo()
    local centerY = math.floor(self.height / 2)
    local L = self:_layout()

    if self.game and self.game.economySystem and L.gold then
        local coinX = L.gold.x

        local interestGold = self.game.economySystem:calculateInterest()
        self:_hoverZone(coinX - 6, L.gold.w, "topbar_gold", {
            gold = self.game.economySystem.currentGold or 0,
            interest = math.floor(interestGold),
        })

        drawIcon("ui_coin", coinX + 4, centerY)

        local base = Palette.AGED_GOLD_LIGHT
        love.graphics.setFont(FontManager.getFont(14))
        local goldDisp = math.floor((self.disp.gold or self.game.economySystem.currentGold or 0) + 0.001)
        local goldText = "$" .. goldDisp
        love.graphics.setColor(0, 0, 0, 0.55)
        love.graphics.print(goldText, coinX + TEXT_DX + 1, centerY - 11)
        if self._goldFlash then
            local k = math.min(1, self._goldFlash.t / 0.6)
            local flash = self._goldFlash.dir > 0
                and { 0.45, 0.90, 0.40 }
                or  { 0.95, 0.35, 0.30 }
            love.graphics.setColor(
                base[1] + (flash[1] - base[1]) * k,
                base[2] + (flash[2] - base[2]) * k,
                base[3] + (flash[3] - base[3]) * k, 1)
        else
            Palette.set(base)
        end
        love.graphics.print(goldText, coinX + TEXT_DX, centerY - 12)

        if interestGold > 0 then
            love.graphics.setFont(FontManager.getFont(9))
            local interestText = I18n.t("top_bar.interest_suffix", { amount = math.floor(interestGold) })
            printShadowed(interestText, coinX + TEXT_DX, centerY + 5, Palette.AGED_GOLD)
        end
    end

    if self.game and self.game.deck and L.deck then
        local deckX = L.deck.x

        self:_hoverZone(deckX - 6, L.deck.w, "topbar_deck", {
            deck = #self.game.deck,
            hand = self.game.hand and #self.game.hand or 0,
        })

        drawIcon("ui_deck_backs", deckX + 4, centerY)

        love.graphics.setFont(FontManager.getFont(14))
        local deckSize = #self.game.deck
        local deckText = I18n.t("top_bar.deck_cards", { n = deckSize })
        printShadowed(deckText, deckX + TEXT_DX, centerY - 12, Palette.PARCHMENT_LIGHT)

        if self.game.hand then
            love.graphics.setFont(FontManager.getFont(9))
            local handSize = #self.game.hand
            local handText = I18n.t("top_bar.hand_suffix", { n = handSize })
            printShadowed(handText, deckX + TEXT_DX, centerY + 5, Palette.AGED_GOLD)
        end
    end

    if self.game and self.game.scoreSystem and L.score then
        local scoreX = L.score.x
        local okPS, ProfileStats = pcall(require, "engine.ProfileStats")
        self:_hoverZone(scoreX - 6, L.score.w, "score", {
            best = (okPS and ProfileStats.get().bestScore) or 0,
        })

        drawIcon("ui_score_rune", scoreX + 4, centerY)
        local record = self.game.scoreSystem.recordBroken
        love.graphics.setFont(FontManager.getFont(14))
        local scoreText = tostring(self.game.score or 0)
        love.graphics.setColor(0, 0, 0, 0.55)
        love.graphics.print(scoreText, scoreX + TEXT_DX + 1, centerY - 11)
        if record then
            local pulse = 0.85 + math.sin(love.timer.getTime() * 2.5) * 0.15
            local g = Palette.AGED_GOLD_LIGHT
            love.graphics.setColor(g[1] * pulse, g[2] * pulse, g[3], 1)
        else
            Palette.set(Palette.PARCHMENT_LIGHT)
        end
        love.graphics.print(scoreText, scoreX + TEXT_DX, centerY - 12)
        love.graphics.setFont(FontManager.getFont(9))
        printShadowed(record and I18n.t("top_bar.score_record")
            or I18n.t("top_bar.score_label"), scoreX + TEXT_DX, centerY + 5,
            record and Palette.AGED_GOLD_LIGHT or Palette.AGED_GOLD)
    end

    local run = self.game and self.game.runManager
        and self.game.runManager.currentRun
    if run and L.progress then
        local progressX = L.progress.x
        local MapManager = require("src.systems.MapManager")
        local total = MapManager.FLOORS_PER_ACT
        local act = run.actNumber or 1
        local floorIn = run.floorInAct or 1

        local RunModsText = require("src.ui.RunModsText")
        self:_hoverZone(progressX - 6, L.progress.w, "topbar_progress", {
            act = act, floor = floorIn, total = total,
            last = require("src.core.Config").TotalActs,
            mods = RunModsText.long(run),
        })

        drawIcon("ui_act_banner", progressX + 4, centerY)
        local numeral = run.endlessMode and "" or (ROMAN[act] or tostring(act))
        if numeral ~= "" then
            local fn = FontManager.getFont(9)
            love.graphics.setFont(fn)
            local nx = progressX + 4 + math.floor((ICON_PX - fn:getWidth(numeral)) / 2)
            local ny = centerY - math.floor(ICON_PX / 2) + 9
            printShadowed(numeral, nx, ny, Palette.PARCHMENT_LIGHT)
        end

        love.graphics.setFont(FontManager.getFont(14))
        local actText = run.endlessMode and I18n.t("top_bar.endless")
            or I18n.t("top_bar.act", { n = act })
        printShadowed(actText, progressX + TEXT_DX, centerY - 12, Palette.PARCHMENT_LIGHT)

        love.graphics.setFont(FontManager.getFont(9))
        local mods = RunModsText.short(run, true)
        printShadowed(I18n.t("top_bar.floor", { x = floorIn, total = total })
            .. (mods ~= "" and (" · " .. mods) or ""), progressX + TEXT_DX, centerY + 5, Palette.AGED_GOLD)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function TopBar:_navTargets()
    local NavCursor = require("src.ui.NavCursor")
    local cx, cy, sz = self:_getConfigRect()
    NavCursor.target("topbar:gear", cx - 4, cy - 4, sz + 8, sz + 8)
    if self:_mapVisible() then
        local mx, my, msz = self:_getMapRect()
        NavCursor.target("topbar:map", mx - 4, my - 4, msz + 8, msz + 8)
    end
end

function TopBar:_mapVisible()
    local run = self.game and self.game.runManager and self.game.runManager.currentRun
    return self.onMapClick ~= nil and run ~= nil and run.actMap ~= nil
end

function TopBar:_mapPending()
    local rm = self.game and self.game.runManager
    local pend = rm and rm.pendingNodes
    return pend ~= nil and #pend > 0
end

function TopBar:_getMapRect()
    local cx, cy, sz = self:_getConfigRect()
    return cx - sz - 18, cy, sz
end

function TopBar:isMapIconClicked(x, y)
    local mx, my, sz = self:_getMapRect()
    return x >= mx and x <= mx + sz and y >= my and y <= my + sz
end

function TopBar:drawMapIcon()
    if not self:_mapVisible() then return end
    local x, y, sz = self:_getMapRect()
    local hover = self.mapHover or 0
    local pending = self:_mapPending()
    local pad = 5
    local gd, gl = Palette.AGED_GOLD_DARK, Palette.AGED_GOLD_LIGHT
    local glow = hover
    if pending then glow = math.max(glow, 0.35 + 0.3 * math.sin(self.mapTime * 4)) end
    if glow > 0.02 then
        PixelCanvas.rectRounded(x - pad, y - pad, sz + pad * 2, sz + pad * 2, 3,
            { gd[1], gd[2], gd[3], 0.55 * glow })
        PixelCanvas.rectRoundedOutline(x - pad, y - pad, sz + pad * 2, sz + pad * 2, 3,
            { gl[1], gl[2], gl[3], 0.9 * glow })
    end
    if self.isMapHovered then
        local okST, StatusTooltip = pcall(require, "src.ui.StatusTooltip")
        if okST and StatusTooltip.show then
            local mx, my = love.mouse.getPosition()
            StatusTooltip.show("topbar_map", mx, my)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
    IconLoader.drawFit("ui_map", x + sz / 2, y + sz / 2 - hover, sz * (1 + 0.12 * hover))
    love.graphics.setColor(1, 1, 1, 1)
end

function TopBar:setMapClickCallback(cb) self.onMapClick = cb end

function TopBar:_getConfigRect()
    local iconPxSize = 32
    local configX = love.graphics.getWidth() - iconPxSize - 30
    local configY = math.floor((self.height - iconPxSize) / 2)
    return configX, configY, iconPxSize
end

function TopBar:drawConfigIcon()
    local configX, configY, iconPxSize = self:_getConfigRect()
    local centerX = configX + iconPxSize / 2
    local centerY = configY + iconPxSize / 2
    local hover = self.configHover or 0

    if hover > 0.02 then
        local pad = 5
        local gd, gl = Palette.AGED_GOLD_DARK, Palette.AGED_GOLD_LIGHT
        PixelCanvas.rectRounded(configX - pad, configY - pad,
            iconPxSize + pad * 2, iconPxSize + pad * 2, 3,
            { gd[1], gd[2], gd[3], 0.55 * hover })
        PixelCanvas.rectRoundedOutline(configX - pad, configY - pad,
            iconPxSize + pad * 2, iconPxSize + pad * 2, 3,
            { gl[1], gl[2], gl[3], 0.9 * hover })
    end
    if self.isConfigHovered then
        local okST, StatusTooltip = pcall(require, "src.ui.StatusTooltip")
        if okST and StatusTooltip.show then
            local mx, my = love.mouse.getPosition()
            StatusTooltip.show("topbar_config", mx, my)
        end
    end

    local drawSize = iconPxSize * (1 + 0.12 * hover)
    local scale = drawSize / (self.gearIcon.size and self.gearIcon.size.w or 16)
    love.graphics.push()
    love.graphics.translate(centerX, centerY)
    love.graphics.rotate(self.configSpin)
    self.gearIcon.draw(-drawSize / 2, -drawSize / 2, scale)
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
end

function TopBar:setDeckClickCallback(cb) self.onDeckClick = cb end

function TopBar:setActClickCallback(cb) self.onActClick = cb end

function TopBar:mousepressed(x, y, button)
    if not self.visible then return false end
    if y <= self.height then
        if self:isConfigIconClicked(x, y) then
            if _G.togglePauseMenu then
                _G.togglePauseMenu()
            elseif self.game and self.game.toggleMenu then
                self.game:toggleMenu()
            end
            return true
        end
        if self:_mapVisible() and self:isMapIconClicked(x, y) then
            self.onMapClick()
            return true
        end
        local L = self:_layout()
        if self.onDeckClick and L.deck
            and x >= L.deck.x - 6 and x <= L.deck.x + L.deck.w then
            self.onDeckClick()
            return true
        end
        if self.onActClick and L.progress
            and x >= L.progress.x - 6 and x <= L.progress.x + L.progress.w then
            self.onActClick()
            return true
        end
        return true
    end
    return false
end

function TopBar:mousereleased(x, y, button)
    if not self.visible then return false end
    return y <= self.height
end

function TopBar:resize() end

function TopBar:isConfigIconClicked(x, y)
    local configX, configY, iconPxSize = self:_getConfigRect()
    return x >= configX and x <= configX + iconPxSize
        and y >= configY and y <= configY + iconPxSize
end

return TopBar
