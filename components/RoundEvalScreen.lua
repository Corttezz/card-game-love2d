local Debug = require("src.core.Debug")

local RoundEvalScreen = {}
RoundEvalScreen.__index = RoundEvalScreen

local FontManager  = require("src.ui.FontManager")
local Palette      = require("src.ui.Palette")
local Button       = require("components.Button")
local Sfx          = require("src.systems.Sfx")
local EventManager = require("engine.EventManager")
local DynaText     = require("src.ui.DynaText")
local FlashShader  = require("src.ui.FlashShader")
local I18n         = require("src.i18n.I18n")

local FXQ = "round_eval_fx"

local T = {
    SLIDE_IN       = 0.45,
    SCORE_AT       = 0.55,
    SCORE_COUNT    = 0.7,
    SCORE_LINE     = 0.12,
    ROWS_AT        = 1.0,
    ROWS_AT_BOSS   = 1.6,
    STING_END      = 1.1,
    STING_END_BOSS = 2.0,
    REVEAL         = 0.18,
    ROW_GAP        = 0.16,
    LAND_PAUSE     = 0.24,
    BUTTON_AFTER   = 0.4,
    SKIP_GRACE     = 0.25,
    TICK_MIN       = 0.032,
    PUNCH          = 0.32,
}

local ROW_ICONS = {
    victory  = "intent_attack",
    full_hp  = "ui_health",
    elite    = "skull_horned",
    boss     = "skull_crowned",
    interest = "ui_coin",
}

local MAX_ROW_COINS = 10

RoundEvalScreen.TIMING = T
RoundEvalScreen.ROW_ICONS = ROW_ICONS

local function reducedMotion()
    return (_G.gameSettings and _G.gameSettings.reducedMotion) and true or false
end

local function countDuration(n)
    return math.max(0.35, math.min(1.0, 0.3 + 0.045 * n))
end

local function rnd(a, b) return a + math.random() * (b - a) end

function RoundEvalScreen:new()
    local instance = setmetatable({}, RoundEvalScreen)
    instance.visible = false
    instance.game = nil
    instance.onCashOut = nil
    instance.sources = {}
    instance.totalDollars = 0
    instance.coinsAccumulated = 0
    instance.cashOutButton = nil
    instance.cashOutReady = false
    instance._closing = false
    instance.slideOffsetY = 0
    instance.titleText = nil
    instance.rows = {}
    instance.t = 0
    instance.landed = false
    instance.skipped = false
    instance._fx = {}
    instance._glints = {}
    return instance
end

function RoundEvalScreen:show(game, sources, onCashOut)
    self.visible = true
    self.game = game
    self.onCashOut = onCashOut
    self.sources = sources or {}
    self.totalDollars = 0
    for _, s in ipairs(self.sources) do
        self.totalDollars = self.totalDollars + (s.dollars or 0)
    end
    self.coinsAccumulated = 0
    self.cashOutReady = false
    self.cashOutButton = nil
    self._closing = false
    self._coins = nil
    self.t = 0
    self.landed = false
    self.skipped = false
    self._fx = {}
    self._glints = {}
    self._dustT = 0
    self._lastTick = -1
    self._punch = 0
    self._landGlow = 0
    self._totalPulse = 0
    self.reduced = reducedMotion()
    self.slideOffsetY = self.reduced and 0 or love.graphics.getHeight()

    self.scoreData = game and game.scoreSystem and game.scoreSystem.lastBattle or nil
    self._scoreShown = 0
    self._scoreValue = 0
    self._scoreLines = 0

    local run = game and game.runManager and game.runManager.currentRun
    local nodeType = run and run.currentNode and run.currentNode.type
    self._boss = nodeType == "boss"
    self._stingEnd = self._boss and T.STING_END_BOSS or T.STING_END

    EventManager.clear(FXQ)
    self:_buildDynaTexts()
    self:_buildRows()

    if not self.reduced then
        EventManager.parallelEase(self, "slideOffsetY", 0, T.SLIDE_IN, "smooth", FXQ)
    end
    Sfx.play("shopOpen", { volume = 0.8 })
    if _G.jiggleScreen and not self.reduced then _G.jiggleScreen(0.5) end
end

function RoundEvalScreen:_buildRows()
    self.rows = {}
    local at = self._boss and T.ROWS_AT_BOSS or T.ROWS_AT
    if self.scoreData then
        local span = T.SCORE_COUNT + #(self.scoreData.breakdown or {}) * T.SCORE_LINE
        at = math.max(at, T.SCORE_AT + span + 0.15)
    end
    for i, src in ipairs(self.sources) do
        local n = math.max(0, math.floor(src.dollars or 0))
        local dur = self.reduced and 0 or countDuration(n)
        local row = {
            src = src,
            n = n,
            kind = src.kind,
            revealAt = at,
            countAt = at + (self.reduced and 0 or T.REVEAL),
            countEnd = at + (self.reduced and 0 or T.REVEAL) + dur,
            value = 0,
            shown = false,
            done = false,
            coins = math.min(MAX_ROW_COINS, n),
            coinPop = {},
        }
        self.rows[i] = row
        at = row.countEnd + (self.reduced and 0.22 or T.ROW_GAP)
    end
    self.landAt = at - (self.reduced and 0.22 or T.ROW_GAP) + T.LAND_PAUSE
    self.buttonAt = self.landAt + T.BUTTON_AFTER
end

function RoundEvalScreen:hide()
    self.visible = false
    self._coins = nil
    self._closing = false
    self.game = nil
    self.cashOutButton = nil
    self.titleText = nil
    self.scoreData = nil
    self.rows = {}
    self._fx = {}
    self._glints = {}
end

function RoundEvalScreen:isVisible()
    return self.visible
end

function RoundEvalScreen:isCounting()
    return self.visible and not self.landed
end

function RoundEvalScreen:resize()
    if self.visible then
        self:_buildDynaTexts()
        if self.cashOutReady then self:_buildCashOutButton() end
    end
end

function RoundEvalScreen:_buildDynaTexts()
    self.titleText = DynaText.new({
        text = I18n.t("round_eval.title", nil, "AVALIACAO DA RODADA"),
        fontSize = 22,
        bump = true,
        bump_phase = 0.42,
        bump_amount = 0.45,
        rotate = true,
        pop_in = 0.5,
        pop_in_rate = 4,
        spacing = 2,
        colours = {{1, 0.85, 0.30, 1}, {1, 0.92, 0.55, 1}},
        colour_cycle = 1.5,
        shadow = true,
        align = "center",
    })
end

function RoundEvalScreen:_layout()
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local panelW = math.floor(sw * 0.55)
    local panelX = math.floor((sw - panelW) * 0.5)
    local panelY = math.floor(sh * 0.09)
    local L = { sw = sw, sh = sh, x = panelX, y = panelY, w = panelW, h = 0 }
    local y = panelY + 70
    if self.scoreData then
        L.scoreY = y
        L.scoreLinesY = y + 24
        y = y + 30 + #(self.scoreData.breakdown or {}) * 15 + 12
        L.scoreSepY = y - 6
    end
    L.rowY = y + 6
    L.rowH = 34
    local rowsEnd = L.rowY + math.max(1, #self.sources) * (L.rowH + 4)
    L.totalY = rowsEnd + 26
    L.h = math.max(math.floor(sh * 0.4), L.totalY + 56 - panelY)
    L.h = math.min(L.h, math.floor(sh * 0.78 - 10 - panelY))
    L.totalY = math.min(L.totalY, panelY + L.h - 56)
    return L
end

function RoundEvalScreen:_tick(k, rowIndex)
    if self.t - self._lastTick < T.TICK_MIN then return end
    self._lastTick = self.t
    local vol = 0.42
    if self.t < self._stingEnd then vol = vol * 0.55 end
    Sfx.play("coinTick", {
        pitch = 0.92 + 0.42 * k + (rowIndex - 1) * 0.03 + rnd(-0.02, 0.02),
        volume = vol,
    })
end

function RoundEvalScreen:_sparkle(x, y, n, spread, colour)
    if self.reduced then return end
    for _ = 1, n do
        local a = rnd(0, math.pi * 2)
        local v = rnd(30, spread or 110)
        self._fx[#self._fx + 1] = {
            x = x, y = y,
            vx = math.cos(a) * v, vy = math.sin(a) * v - rnd(10, 50),
            life = rnd(0.35, 0.7), age = 0,
            size = rnd(1, 2.5),
            colour = colour or { 1, rnd(0.78, 0.95), rnd(0.3, 0.55) },
            grav = 140,
        }
    end
end

function RoundEvalScreen:_glint(x, y, size)
    if self.reduced then return end
    self._glints[#self._glints + 1] = { x = x, y = y, age = 0, life = 0.45, size = size or 7 }
end

function RoundEvalScreen:_rowAnchor(i)
    local L = self:_layout()
    local y = L.rowY + (i - 1) * (L.rowH + 4) + L.rowH * 0.5
    return L, y
end

function RoundEvalScreen:_revealRow(i)
    local row = self.rows[i]
    row.shown = true
    if self.reduced then
        Sfx.play("coinTotalThud", { pitch = 0.95 + (i - 1) * 0.05, volume = 0.7 })
        return
    end
    local vol = self.t < self._stingEnd and 0.45 or 0.7
    Sfx.play("coinTotalThud", { pitch = 1.05 + (i - 1) * 0.06, volume = vol })
    if _G.jiggleScreen then _G.jiggleScreen(0.12) end
end

function RoundEvalScreen:_finishRow(i)
    local row = self.rows[i]
    if row.done then return end
    row.done = true
    local before = row.value
    row.value = row.n
    self.coinsAccumulated = self.coinsAccumulated + (row.n - before)
    for c = 1, row.coins do row.coinPop[c] = row.coinPop[c] or self.t end
    if row.n > 0 and not self.skipped then
        local L, y = self:_rowAnchor(i)
        local x = L.x + L.w - 40
        self:_glint(x, y - 2, 6)
        self:_sparkle(x - 10, y, 5, 70)
    end
end

function RoundEvalScreen:_land()
    if self.landed then return end
    self.landed = true
    for i = 1, #self.rows do
        if not self.rows[i].shown then self.rows[i].shown = true end
        self:_finishRow(i)
    end
    self.coinsAccumulated = self.totalDollars
    if self.scoreData then
        self._scoreShown = 1
        self._scoreValue = self.scoreData.total or 0
        self._scoreLines = #(self.scoreData.breakdown or {})
    end
    Sfx.play("coinTotalThud", { pitch = 0.86, volume = 0.95 })
    Sfx.play("shopChestCoins", { volume = 0.5 })
    if self.reduced then return end
    self._punch = T.PUNCH
    self._landGlow = 1
    local L = self:_layout()
    local cx, cy = L.sw * 0.5, L.totalY + 18 + (self.slideOffsetY or 0)
    self:_sparkle(cx, cy, 34, 190)
    for k = 1, 5 do
        self:_glint(cx + rnd(-90, 90), cy + rnd(-22, 18), rnd(6, 10))
        if k <= 2 then self:_glint(L.x + rnd(20, L.w - 20), L.y + rnd(4, 8), 6) end
    end
    if FlashShader and FlashShader.trigger then FlashShader.trigger(0.3, 0.3, 0.12) end
    if _G.jiggleScreen then _G.jiggleScreen(0.7) end
end

function RoundEvalScreen:_ready()
    if self.cashOutReady then return end
    self:_buildCashOutButton()
    self.cashOutReady = true
    if FlashShader and FlashShader.trigger and not self.reduced then
        FlashShader.trigger(0.25, 0.3, 0.2)
    end
    Sfx.play("cashOutChime")
end

function RoundEvalScreen:skip()
    if self.landed or self._closing or not self.visible then return false end
    self.skipped = true
    if self.slideOffsetY ~= 0 then
        EventManager.clear(FXQ)
        self.slideOffsetY = 0
    end
    self:_land()
    self.buttonAt = self.t + 0.18
    return true
end

function RoundEvalScreen:_buildCashOutButton()
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()
    local btnW = 240
    local btnH = 42
    local btnX = sw * 0.5 - btnW * 0.5
    local btnY = sh * 0.78
    self.cashOutButton = Button:new(
        btnX, btnY, btnW, btnH,
        I18n.t("round_eval.cash_out", { n = self.totalDollars }),
        function() self:_onCashOutClick() end,
        nil, 12
    )
    self.cashOutButton:setIcon("ui_coin")
end

function RoundEvalScreen:_onCashOutClick()
    if self._closing then return end
    if not self.landed then
        self.skipped = true
        self.landed = true
        self.coinsAccumulated = self.totalDollars
    end
    self._closing = true
    Sfx.play("coinTotalThud", { pitch = 1.2, volume = 0.85 })
    if _G.jiggleScreen and not self.reduced then _G.jiggleScreen(1.2) end
    if FlashShader and FlashShader.trigger and not self.reduced then
        FlashShader.trigger(0.55, 0.4, 0.2)
    end

    local landAt = self:_launchCoins()

    EventManager.parallel(landAt, function()
        if self.game and self.game.economySystem and self.game.economySystem.earnGold then
            self.game.economySystem:earnGold(self.totalDollars, "round_eval")
        end
    end, FXQ)

    local cb = self.onCashOut
    EventManager.parallelEase(self, "slideOffsetY", love.graphics.getHeight(),
        0.45, "smooth", FXQ)
    EventManager.parallel(landAt + 0.30, function()
        self:hide()
        if cb then cb() end
    end, FXQ)
end

local COIN_FLY_DUR   = 0.42
local COIN_STAGGER   = 0.045
local COIN_MAX       = 10

local _targetWarned = false
local function goldCounterPos()
    local topBar = _G.topBar
    if topBar and topBar._layout then
        local ok, slots = pcall(topBar._layout, topBar)
        if ok and slots and slots.gold then
            return slots.gold.x + slots.gold.w * 0.5, (topBar.height or 52) * 0.5
        end
    end
    if _G.audioSystem and not _targetWarned then
        _targetWarned = true
        Debug.warn("[RoundEvalScreen] _G.topBar ausente: moedas voam pro centro")
    end
    return love.graphics.getWidth() * 0.5, 26
end

function RoundEvalScreen:_launchCoins()
    self._coins = {}

    local reduced = _G.gameSettings and _G.gameSettings.reducedMotion
    if reduced or not love.graphics then
        return 0.02
    end

    local n = math.max(1, math.min(COIN_MAX, self.totalDollars))
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local sx, sy = sw * 0.5, sh * 0.62
    local tx, ty = goldCounterPos()

    for i = 1, n do
        local coin = {
            x = sx + (math.random() * 2 - 1) * 46,
            y = sy + (math.random() * 2 - 1) * 10,
            a = 1, s = 1, rot = 0,
        }
        self._coins[i] = coin
        local d = (i - 1) * COIN_STAGGER
        EventManager.parallel(d, function()
            EventManager.parallelEase(coin, "x", tx, COIN_FLY_DUR, "smooth", FXQ)
            EventManager.parallelEase(coin, "y", ty, COIN_FLY_DUR, "ease_in", FXQ)
            EventManager.parallelEase(coin, "s", 0.45, COIN_FLY_DUR, "ease_in", FXQ)
            EventManager.parallelEase(coin, "rot", 1.6, COIN_FLY_DUR, "smooth", FXQ)
        end, FXQ)
        EventManager.parallel(d + COIN_FLY_DUR, function()
            coin.a = 0
            Sfx.play("coinClink", {
                pitch = 0.94 + (i - 1) * 0.05,
                volume = 0.38,
            })
        end, FXQ)
    end

    return (n - 1) * COIN_STAGGER + COIN_FLY_DUR
end

local function drawIcon(name, cx, cy, size, alpha)
    local icon = require("src.ui.IconLoader").get(name)
    if not (icon and icon.image) then return end
    local iw = icon.image:getWidth()
    local k = size / iw
    love.graphics.setColor(1, 1, 1, alpha or 1)
    love.graphics.draw(icon.image, math.floor(cx), math.floor(cy), 0, k, k, iw * 0.5, icon.image:getHeight() * 0.5)
end

function RoundEvalScreen:_drawCoins()
    if not self._coins then return end
    for _, c in ipairs(self._coins) do
        if (c.a or 0) > 0.01 then
            love.graphics.push()
            love.graphics.translate(c.x, c.y)
            love.graphics.rotate(c.rot or 0)
            drawIcon("ui_coin", 0, 0, 22 * (c.s or 1), c.a)
            love.graphics.pop()
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function RoundEvalScreen:_updateScore()
    local sd = self.scoreData
    if not sd then return end
    if self.t < T.SCORE_AT then return end
    self._scoreShown = 1
    if self.reduced then
        self._scoreValue = sd.total or 0
        self._scoreLines = #(sd.breakdown or {})
        return
    end
    local k = math.min(1, (self.t - T.SCORE_AT) / T.SCORE_COUNT)
    self._scoreValue = math.floor((sd.total or 0) * (1 - (1 - k) * (1 - k)) + 0.5)
    self._scoreLines = math.min(#(sd.breakdown or {}), math.floor((self.t - T.SCORE_AT) / T.SCORE_LINE) + 1)
end

function RoundEvalScreen:_updateRows()
    for i, row in ipairs(self.rows) do
        if not row.shown and self.t >= row.revealAt then self:_revealRow(i) end
        if row.shown and not row.done and self.t >= row.countAt then
            if self.t >= row.countEnd then
                if row.value < row.n and not self.reduced then self:_tick(1, i) end
                self:_finishRow(i)
            else
                local k = (self.t - row.countAt) / (row.countEnd - row.countAt)
                local v = math.floor(row.n * k * k)
                if v > row.value then
                    self.coinsAccumulated = self.coinsAccumulated + (v - row.value)
                    row.value = v
                    self._totalPulse = 0.12
                    self:_tick(k, i)
                    local due = row.n > 0 and math.floor(row.value * row.coins / row.n) or 0
                    for c = 1, due do
                        if not row.coinPop[c] then row.coinPop[c] = self.t end
                    end
                end
            end
        end
    end
end

function RoundEvalScreen:_updateFx(dt)
    for i = #self._fx, 1, -1 do
        local p = self._fx[i]
        p.age = p.age + dt
        if p.age >= p.life then
            table.remove(self._fx, i)
        else
            p.vy = p.vy + p.grav * dt
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            p.vx = p.vx * (1 - 1.6 * dt)
        end
    end
    for i = #self._glints, 1, -1 do
        local g = self._glints[i]
        g.age = g.age + dt
        if g.age >= g.life then table.remove(self._glints, i) end
    end
    if self.reduced or self._closing then return end
    self._dustT = (self._dustT or 0) + dt
    if self._dustT > 0.09 then
        self._dustT = 0
        local L = self:_layout()
        self._fx[#self._fx + 1] = {
            x = L.x + rnd(16, L.w - 16), y = L.y + L.h - rnd(4, 30),
            vx = rnd(-6, 6), vy = rnd(-26, -12),
            life = rnd(1.4, 2.4), age = 0, size = 1,
            colour = { 1, 0.86, 0.45 }, grav = 0, dust = true,
        }
    end
    if self.landed and math.random() < dt * 1.2 then
        local L = self:_layout()
        self:_glint(L.sw * 0.5 + rnd(-70, 70), L.totalY + rnd(6, 30), rnd(4, 7))
    end
end

function RoundEvalScreen:update(dt)
    if not self.visible then return end
    self.t = self.t + dt

    if self.titleText then self.titleText:update(dt) end
    if self.cashOutButton then self.cashOutButton:update(dt) end

    if not self._closing then
        if not self.landed then
            self:_updateScore()
            self:_updateRows()
            if self.t >= self.landAt then self:_land() end
        end
        if self.landed and not self.cashOutReady and self.t >= self.buttonAt then self:_ready() end
    end

    self._punch = math.max(0, (self._punch or 0) - dt)
    self._landGlow = math.max(0, (self._landGlow or 0) - dt * 1.4)
    self._totalPulse = math.max(0, (self._totalPulse or 0) - dt)
    self:_updateFx(dt)
end

local function drawGlint(x, y, size, a)
    love.graphics.setColor(1, 0.97, 0.82, a)
    love.graphics.setLineWidth(1)
    love.graphics.line(x - size, y, x + size, y)
    love.graphics.line(x, y - size, x, y + size)
    local d = size * 0.4
    love.graphics.line(x - d, y - d, x + d, y + d)
    love.graphics.line(x - d, y + d, x + d, y - d)
    love.graphics.rectangle("fill", math.floor(x) - 1, math.floor(y) - 1, 2, 2)
end

function RoundEvalScreen:_drawPanel(L)
    local px, py, pw, ph = L.x, L.y, L.w, L.h
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", px + 6, py + 6, pw, ph, 8, 8)
    love.graphics.setColor(0.12, 0.10, 0.08, 0.96)
    love.graphics.rectangle("fill", px, py, pw, ph, 8, 8)
    love.graphics.setColor(0.2, 0.15, 0.09, 0.55)
    love.graphics.rectangle("fill", px + 10, L.totalY - 6, pw - 20, 50, 6, 6)
    if (self._landGlow or 0) > 0 then
        love.graphics.setColor(1, 0.8, 0.3, 0.22 * self._landGlow)
        love.graphics.rectangle("fill", px + 10, L.totalY - 6, pw - 20, 50, 6, 6)
    end
    love.graphics.setColor(1, 0.88, 0.55, 0.18)
    love.graphics.setLineWidth(1)
    love.graphics.line(px + 8, py + 2, px + pw - 8, py + 2)
    love.graphics.setColor(Palette.AGED_GOLD or {0.78, 0.65, 0.20, 1})
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", px, py, pw, ph, 8, 8)
    love.graphics.setColor(Palette.AGED_GOLD_DARK or {0.45, 0.32, 0.10, 1})
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", px + 4, py + 4, pw - 8, ph - 8, 6, 6)
    local c = 14
    love.graphics.setColor(Palette.AGED_GOLD_LIGHT or {1, 0.92, 0.55, 1})
    love.graphics.setLineWidth(2)
    love.graphics.line(px + 3, py + c, px + 3, py + 3, px + c, py + 3)
    love.graphics.line(px + pw - c, py + 3, px + pw - 3, py + 3, px + pw - 3, py + c)
    love.graphics.line(px + 3, py + ph - c, px + 3, py + ph - 3, px + c, py + ph - 3)
    love.graphics.line(px + pw - c, py + ph - 3, px + pw - 3, py + ph - 3, px + pw - 3, py + ph - c)
    love.graphics.setColor(0.78, 0.65, 0.20, 0.6)
    love.graphics.setLineWidth(1)
    love.graphics.line(px + 24, py + 56, px + pw - 24, py + 56)
end

function RoundEvalScreen:_drawScore(L)
    local sd = self.scoreData
    if not sd or self._scoreShown <= 0 then return end
    local TextFit = require("src.ui.TextFit")
    local f = FontManager.getFont(15)
    love.graphics.setFont(f)
    local txt = I18n.t("score.points_total", { n = self._scoreValue }, ("+%d PONTOS"):format(self._scoreValue))
    local tw = f:getWidth(txt)
    local tx = math.floor(L.sw * 0.5 - tw * 0.5 + 8)
    drawIcon("ui_score_rune", tx - 14, L.scoreY + f:getHeight() * 0.5, 18)
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.print(txt, tx + 1, L.scoreY + 1)
    love.graphics.setColor(1, 0.86, 0.32, 1)
    love.graphics.print(txt, tx, L.scoreY)
    local lf = FontManager.getFont(10)
    local lx, rx = L.x + 60, L.x + L.w - 60
    local ly = L.scoreLinesY
    for i, item in ipairs(sd.breakdown or {}) do
        if i > self._scoreLines then break end
        love.graphics.setFont(lf)
        local valueW = lf:getWidth(item.value)
        if item.bad then love.graphics.setColor(0.85, 0.45, 0.35, 0.95) else love.graphics.setColor(0.82, 0.78, 0.70, 0.95) end
        TextFit.print(item.label, lx, ly, { size = 10, maxW = math.max(40, rx - lx - valueW - 12) })
        if item.bad then love.graphics.setColor(0.9, 0.4, 0.3, 1) else love.graphics.setColor(1, 0.85, 0.30, 1) end
        love.graphics.setFont(lf)
        love.graphics.print(item.value, rx - valueW, ly)
        ly = ly + 15
    end
    love.graphics.setColor(0.78, 0.65, 0.20, 0.4)
    love.graphics.setLineWidth(1)
    love.graphics.line(L.x + 24, L.scoreSepY, L.x + L.w - 24, L.scoreSepY)
end

function RoundEvalScreen:_drawRow(L, i, row, font, vfont)
    local TextFit = require("src.ui.TextFit")
    local y = L.rowY + (i - 1) * (L.rowH + 4)
    local cy = y + L.rowH * 0.5
    local k = (self.reduced or self.skipped) and 1 or math.min(1, (self.t - row.revealAt) / T.REVEAL)
    local e = 1 - (1 - k) * (1 - k)
    local dx = math.floor((1 - e) * -26)
    local a = e
    local src = row.src
    local colour = src.color or {0.95, 0.92, 0.88, 1}
    local iconX = L.x + 40
    local labelX = L.x + 62
    local valueR = L.x + L.w - 34

    love.graphics.setColor(1, 0.85, 0.4, 0.06 * a)
    love.graphics.rectangle("fill", L.x + 22, y + 2, L.w - 44, L.rowH - 4, 4, 4)
    drawIcon(ROW_ICONS[row.kind] or "ui_coin", iconX + dx, cy, 24, a)

    love.graphics.setFont(vfont)
    local vtxt = "+$" .. row.value
    local vw = vfont:getWidth(vtxt)
    local pop = 0
    if row.done and row.n > 0 and not self.skipped and not self.reduced then
        local since = self.t - row.countEnd
        if since >= 0 and since < 0.18 then pop = (1 - since / 0.18) * 0.25 end
    end
    local vh = vfont:getHeight()
    love.graphics.push()
    love.graphics.translate(valueR - vw * 0.5, cy)
    love.graphics.scale(1 + pop, 1 + pop)
    love.graphics.setColor(0, 0, 0, 0.6 * a)
    love.graphics.print(vtxt, math.floor(-vw * 0.5) + 1, math.floor(-vh * 0.5) + 1)
    love.graphics.setColor(colour[1], colour[2], colour[3], a)
    love.graphics.print(vtxt, math.floor(-vw * 0.5), math.floor(-vh * 0.5))
    love.graphics.pop()

    local step = 9
    local stackR = valueR - vw - 16
    local stackL = stackR - (math.max(1, row.coins) - 1) * step
    for c = 1, row.coins do
        local at = row.coinPop[c]
        if at then
            local ck = (self.reduced or self.skipped) and 1 or math.min(1, (self.t - at) / 0.14)
            drawIcon("ui_coin", stackL + (c - 1) * step, cy + (1 - ck) * -7, 15, a * (0.4 + 0.6 * ck))
        end
    end

    love.graphics.setFont(font)
    local maxLabel = math.max(40, stackL - labelX - 22)
    local fy = cy - font:getHeight() * 0.5
    love.graphics.setColor(0, 0, 0, 0.6 * a)
    TextFit.print(src.label or "", labelX + dx + 1, fy + 1, { size = 14, maxW = maxLabel })
    love.graphics.setColor(colour[1], colour[2], colour[3], a)
    local lw = TextFit.print(src.label or "", labelX + dx, fy, { size = 14, maxW = maxLabel })
    if type(lw) ~= "number" then lw = math.min(maxLabel, font:getWidth(src.label or "")) end

    love.graphics.setColor(0.78, 0.65, 0.20, 0.35 * a)
    local dotTo = stackL - 14
    local d = labelX + lw + 10
    while d < dotTo do
        love.graphics.rectangle("fill", math.floor(d), math.floor(cy + 5), 2, 2)
        d = d + 6
    end
end

function RoundEvalScreen:_drawRows(L)
    local font = FontManager.getFont(14)
    local vfont = FontManager.getFont(16)
    for i, row in ipairs(self.rows) do
        if row.shown then self:_drawRow(L, i, row, font, vfont) end
    end
end

function RoundEvalScreen:_drawTotal(L)
    local label = I18n.t("round_eval.total", { n = self.coinsAccumulated }, "TOTAL: $" .. self.coinsAccumulated)
    local f = FontManager.getFont(22)
    love.graphics.setFont(f)
    local tw = f:getWidth(label)
    local cx, cy = L.sw * 0.5 + 12, L.totalY + 19
    local s = 1
    if (self._punch or 0) > 0 then
        local k = 1 - self._punch / T.PUNCH
        s = 1 + 0.45 * (1 - k) * (1 - k)
    elseif (self._totalPulse or 0) > 0 then
        s = 1 + 0.06 * (self._totalPulse / 0.12)
    end
    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.scale(s, s)
    local ox, oy = math.floor(-tw * 0.5), math.floor(-f:getHeight() * 0.5)
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.print(label, ox + 2, oy + 2)
    if self.landed then
        love.graphics.setColor(1, 0.94, 0.5, 1)
    else
        love.graphics.setColor(0.95, 0.82, 0.38, 0.95)
    end
    love.graphics.print(label, ox, oy)
    love.graphics.pop()
    drawIcon("ui_coin", cx - tw * 0.5 * s - 18, cy, 22, 1)
end

function RoundEvalScreen:_drawFx(oy)
    for _, p in ipairs(self._fx) do
        local k = p.age / p.life
        local a = p.dust and (math.sin(k * math.pi) * 0.45) or (1 - k)
        love.graphics.setColor(p.colour[1], p.colour[2], p.colour[3], a)
        local s = math.max(1, math.floor(p.size + 0.5))
        local y = p.dust and (p.y + oy) or p.y
        love.graphics.rectangle("fill", math.floor(p.x), math.floor(y), s, s)
    end
    for _, g in ipairs(self._glints) do
        local k = g.age / g.life
        local a = math.sin(k * math.pi)
        drawGlint(g.x, g.y, g.size * (0.5 + 0.5 * a), a)
    end
end

function RoundEvalScreen:draw()
    if not self.visible then return end
    local L = self:_layout()
    local oy = self.slideOffsetY or 0

    love.graphics.setColor(0.05, 0.04, 0.08, 0.65)
    love.graphics.rectangle("fill", 0, 0, L.sw, L.sh)

    love.graphics.push()
    love.graphics.translate(0, oy)
    self:_drawPanel(L)
    if self.titleText then self.titleText:draw(L.sw * 0.5, L.y + 30) end
    self:_drawScore(L)
    self:_drawRows(L)
    love.graphics.setColor(0.78, 0.65, 0.20, 0.7)
    love.graphics.setLineWidth(2)
    love.graphics.line(L.x + 60, L.totalY - 12, L.x + L.w - 60, L.totalY - 12)
    self:_drawTotal(L)
    love.graphics.pop()

    self:_drawFx(oy)

    if self.cashOutButton and self.cashOutReady then
        local btn = self.cashOutButton
        local pulse = 0.32 + 0.1 * math.sin(self.t * 4)
        love.graphics.setColor(0.99, 0.64, 0.0, pulse)
        love.graphics.rectangle("fill", btn.x - 6, btn.y - 6, btn.width + 12, btn.height + 12, 12, 12)
        love.graphics.setColor(1, 1, 1, 1)
        btn:draw()
    end

    self:_drawCoins()
    love.graphics.setColor(1, 1, 1, 1)
end

function RoundEvalScreen:mousepressed(x, y, button)
    if not self.visible or self._closing then return false end
    if self.cashOutButton and self.cashOutReady then
        if self.cashOutButton:mousepressed(x, y, button) then return true end
    end
    if not self.landed and self.t >= T.SKIP_GRACE then self:skip() end
    return true
end

function RoundEvalScreen:mousereleased(x, y, button)
    if not self.visible then return false end
    if self.cashOutButton and self.cashOutReady then
        if self.cashOutButton:mousereleased(x, y, button) then return true end
    end
    return false
end

function RoundEvalScreen:keypressed(key)
    if not self.visible then return false end
    if key ~= "return" and key ~= "space" then return false end
    if not self.landed then
        if self.t >= T.SKIP_GRACE then self:skip() end
        return true
    end
    if self.cashOutReady and not self._closing then
        self:_onCashOutClick()
        return true
    end
    return true
end

return RoundEvalScreen
