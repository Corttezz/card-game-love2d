local FontManager = require("src.ui.FontManager")
local ImageCache  = require("src.ui.ImageCache")
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

    instance.coinIcon = ImageCache.get("assets/icons/coin.png")
    instance.deckIcon = ImageCache.get("assets/icons/deck.png")

    instance.gearIcon = IconLoader.get("gear")

    instance.game = nil

    instance.configHover = 0
    instance.configSpin = 0
    instance.isConfigHovered = false

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

    PixelCanvas.rect(0, 0, screenWidth, self.height, { 0.07, 0.055, 0.04, 0.98 })
    PixelCanvas.hline(0, self.height,     screenWidth, Palette.AGED_GOLD)
    PixelCanvas.hline(0, self.height + 1, screenWidth, Palette.AGED_GOLD_DARK)

    for i = 0, 4 do
        local x = 20 + math.floor(i * (screenWidth - 40) / 4)
        PixelCanvas.rect(x - 2, self.height - 6, 4, 4, Palette.AGED_GOLD)
        PixelCanvas.pixel(x - 1, self.height - 5, Palette.AGED_GOLD_LIGHT)
    end

    self:drawGameInfo()
    self:drawConfigIcon()
end

function TopBar:drawGameInfo()
    local iconScale = 0.05
    local centerY = math.floor(self.height / 2)
    local L = self:_layout()

    if self.game and self.game.economySystem and L.gold then
        local coinX = L.gold.x
        local coinY = centerY - 22

        local interestGold = self.game.economySystem:calculateInterest()
        self:_hoverZone(coinX - 6, L.gold.w, "topbar_gold", {
            gold = self.game.economySystem.currentGold or 0,
            interest = math.floor(interestGold),
        })

        love.graphics.setColor(1, 1, 1, 1)
        local rm = _G.gameSettings and _G.gameSettings.reducedMotion
        local pulse = rm and 1 or (1 + math.sin(love.timer.getTime() * 0.7) * 0.03)
        local cw, ch = self.coinIcon:getWidth(), self.coinIcon:getHeight()
        local scaledIcon = iconScale * pulse
        love.graphics.draw(self.coinIcon, coinX + cw * iconScale * 0.5, coinY + ch * iconScale * 0.5, 0,
                           scaledIcon, scaledIcon, cw / 2, ch / 2)

        local base = Palette.AGED_GOLD_LIGHT
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
        love.graphics.setFont(FontManager.getFont(14))
        local goldDisp = math.floor((self.disp.gold or self.game.economySystem.currentGold or 0) + 0.001)
        local goldText = "$" .. goldDisp
        love.graphics.print(goldText, coinX + 50, centerY - 10)

        if interestGold > 0 then
            Palette.set(Palette.PARCHMENT)
            love.graphics.setFont(FontManager.getFont(9))
            local interestText = I18n.t("top_bar.interest_suffix", { amount = math.floor(interestGold) })
            love.graphics.print(interestText, coinX + 50, centerY + 6)
        end
    end

    if self.game and self.game.deck and L.deck then
        local deckX = L.deck.x
        local deckY = centerY - 22

        self:_hoverZone(deckX - 6, L.deck.w, "topbar_deck", {
            deck = #self.game.deck,
            hand = self.game.hand and #self.game.hand or 0,
        })

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(self.deckIcon, deckX, deckY, 0, iconScale, iconScale)

        Palette.set(Palette.PARCHMENT_LIGHT)
        love.graphics.setFont(FontManager.getFont(14))
        local deckSize = #self.game.deck
        local deckText = I18n.t("top_bar.deck_cards", { n = deckSize })
        love.graphics.print(deckText, deckX + 50, centerY - 10)

        if self.game.hand then
            Palette.set(Palette.PARCHMENT)
            love.graphics.setFont(FontManager.getFont(9))
            local handSize = #self.game.hand
            local handText = I18n.t("top_bar.hand_suffix", { n = handSize })
            love.graphics.print(handText, deckX + 50, centerY + 6)
        end
    end

    if self.game and self.game.scoreSystem and L.score then
        local scoreX = L.score.x
        local IconLoader = require("src.ui.IconLoader")

        local okPS, ProfileStats = pcall(require, "engine.ProfileStats")
        self:_hoverZone(scoreX - 6, L.score.w, "score", {
            best = (okPS and ProfileStats.get().bestScore) or 0,
        })

        local icon = IconLoader.get("ui_score_star")
        if icon and icon.draw and icon.size then
            local sc = 26 / icon.size.w
            love.graphics.setColor(1, 1, 1, 1)
            icon.draw(scoreX, centerY - 14, sc)
        end
        local record = self.game.scoreSystem.recordBroken
        if record then
            local pulse = 0.85 + math.sin(love.timer.getTime() * 2.5) * 0.15
            local g = Palette.AGED_GOLD_LIGHT
            love.graphics.setColor(g[1] * pulse, g[2] * pulse, g[3], 1)
        else
            Palette.set(Palette.PARCHMENT_LIGHT)
        end
        love.graphics.setFont(FontManager.getFont(14))
        love.graphics.print(tostring(self.game.score or 0), scoreX + 34, centerY - 10)
        Palette.set(record and Palette.AGED_GOLD or Palette.PARCHMENT)
        love.graphics.setFont(FontManager.getFont(9))
        love.graphics.print(record and I18n.t("top_bar.score_record")
            or I18n.t("top_bar.score_label"), scoreX + 34, centerY + 6)
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

        local icon = IconLoader.get("ui_act_scroll")
        if icon and icon.draw and icon.size then
            local sc = 26 / icon.size.w
            love.graphics.setColor(1, 1, 1, 1)
            icon.draw(progressX, centerY - 14, sc)
        end

        Palette.set(Palette.PARCHMENT_LIGHT)
        love.graphics.setFont(FontManager.getFont(14))
        local actText = run.endlessMode and I18n.t("top_bar.endless")
            or I18n.t("top_bar.act", { n = act })
        love.graphics.print(actText, progressX + 34, centerY - 10)

        Palette.set(Palette.PARCHMENT)
        love.graphics.setFont(FontManager.getFont(9))
        local mods = RunModsText.short(run, true)
        love.graphics.print(I18n.t("top_bar.floor", { x = floorIn, total = total })
            .. (mods ~= "" and (" · " .. mods) or ""), progressX + 34, centerY + 6)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function TopBar:_navTargets()
    local NavCursor = require("src.ui.NavCursor")
    local cx, cy, sz = self:_getConfigRect()
    NavCursor.target("topbar:gear", cx - 4, cy - 4, sz + 8, sz + 8)
end

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
