local Debug = require("src.core.Debug")

local RoundEvalScreen = {}
RoundEvalScreen.__index = RoundEvalScreen

local Debug        = require("src.core.Debug")
local FontManager  = require("src.ui.FontManager")
local Palette      = require("src.ui.Palette")
local Button       = require("components.Button")
local Sfx          = require("src.systems.Sfx")
local EventManager = require("engine.EventManager")
local DynaText     = require("src.ui.DynaText")
local FlashShader  = require("src.ui.FlashShader")
local I18n         = require("src.i18n.I18n")

local FXQ = "round_eval_fx"

local PHASES = {
    SLIDE_IN      = 0.5,
    PRE_ROW_DELAY = 0.20,
    ROW_DELAY     = 0.45,
    COIN_STAGGER  = 0.10,
    BIG_THRESHOLD = 60,
    BUTTON_DELAY  = 0.35,
}

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
    instance.totalText = nil
    instance.rowDynas = {}
    instance._rowVisible = {}
    instance._rowCoins = {}
    instance._totalPulseTimer = 0
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
    self._closing = false
    self.slideOffsetY = love.graphics.getHeight()
    self._rowVisible = {}
    self._rowCoins = {}
    for i = 1, #self.sources do
        self._rowVisible[i] = false
        self._rowCoins[i] = 0
    end
    self._totalPulseTimer = 0

    self.scoreData = game and game.scoreSystem
        and game.scoreSystem.lastBattle or nil
    self._scoreVisible = false

    EventManager.clear(FXQ)

    self:_buildDynaTexts()
    self:_scheduleTimeline()

    Sfx.play("shopOpen")
    if _G.jiggleScreen then _G.jiggleScreen(0.8) end
end

function RoundEvalScreen:hide()
    self.visible = false
    self._coins = nil
    self._closing = false
    self.game = nil
    self.cashOutButton = nil
    self.titleText = nil
    self.totalText = nil
    self.scoreText = nil
    self.scoreData = nil
    self.rowDynas = {}
end

function RoundEvalScreen:isVisible()
    return self.visible
end

function RoundEvalScreen:resize()
    if self.visible then
        self:_buildDynaTexts()
        self:_buildCashOutButton()
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

    self.rowDynas = {}
    for i, src in ipairs(self.sources) do
        self.rowDynas[i] = DynaText.new({
            text = src.label or "",
            fontSize = 14,
            bump = false,
            rotate = false,
            pop_in = 0.35,
            pop_in_rate = 6,
            spacing = 1,
            colours = { src.color or {0.95, 0.92, 0.88, 1} },
            shadow = true,
            align = "left",
        })
    end

    self.scoreText = nil
    if self.scoreData then
        local sd = self.scoreData
        self.scoreText = DynaText.new({
            text = I18n.t("score.points_total", { n = sd.total },
                ("+%d PONTOS"):format(sd.total)),
            fontSize = 15,
            bump = false,
            pop_in = 0.4,
            pop_in_rate = 5,
            spacing = 1,
            colours = {{1, 0.85, 0.30, 1}, {0.95, 0.92, 0.88, 1}},
            colour_cycle = 2.0,
            shadow = true,
            align = "center",
        })
    end

    self.totalText = DynaText.new({
        text = I18n.t("round_eval.total", { n = self.totalDollars },
            "TOTAL: $" .. self.totalDollars),
        fontSize = 18,
        bump = false,
        pop_in = 0.5,
        pop_in_rate = 4,
        spacing = 2,
        colours = {{1, 0.92, 0.40, 1}},
        shadow = true,
        align = "center",
    })
end

function RoundEvalScreen:_scheduleTimeline()
    EventManager.parallelEase(self, "slideOffsetY", 0, PHASES.SLIDE_IN, "smooth", FXQ)

    if self.scoreData then
        EventManager.parallel(PHASES.SLIDE_IN + 0.10, function()
            self._scoreVisible = true
            Sfx.play("comboTrigger", { volume = 0.7 })
            if _G.jiggleScreen then _G.jiggleScreen(0.3) end
        end, FXQ)
    end

    local t = PHASES.SLIDE_IN + PHASES.PRE_ROW_DELAY
        + (self.scoreData and 0.35 or 0)
    for i, src in ipairs(self.sources) do
        local rowAt = t

        EventManager.parallel(rowAt, function()
            self._rowVisible[i] = true
            local pitch = 0.95 + (i - 1) * 0.06
            Sfx.play("coinTotalThud", { pitch = pitch })
            if _G.jiggleScreen then _G.jiggleScreen(0.18) end
        end, FXQ)

        local dollars = src.dollars or 0
        if dollars <= PHASES.BIG_THRESHOLD then
            for c = 1, dollars do
                EventManager.parallel(rowAt + 0.20 + c * PHASES.COIN_STAGGER, function()
                    self.coinsAccumulated = self.coinsAccumulated + 1
                    self._rowCoins[i] = (self._rowCoins[i] or 0) + 1
                    self._totalPulseTimer = 0.25
                    Sfx.play("coinClink", {
                        pitch = 0.85 + math.random() * 0.3,
                        volume = 0.6,
                    })
                    if _G.jiggleScreen then _G.jiggleScreen(0.04) end
                end, FXQ)
            end
            t = rowAt + 0.20 + dollars * PHASES.COIN_STAGGER + PHASES.ROW_DELAY
        else
            EventManager.parallel(rowAt + 0.4, function()
                self.coinsAccumulated = self.coinsAccumulated + dollars
                self._rowCoins[i] = dollars
                self._totalPulseTimer = 0.4
                Sfx.play("coinTotalThud", { pitch = 1.0, volume = 0.85 })
            end, FXQ)
            t = rowAt + 0.4 + PHASES.ROW_DELAY
        end
    end

    EventManager.parallel(t + PHASES.BUTTON_DELAY, function()
        self:_buildCashOutButton()
        self.cashOutReady = true
        if FlashShader and FlashShader.trigger then
            FlashShader.trigger(0.45, 0.35)
        end
        if _G.jiggleScreen then _G.jiggleScreen(0.8) end
        Sfx.play("cashOutChime")
    end, FXQ)
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
    self.cashOutButton:setIcon("ui_gold")
end

function RoundEvalScreen:_onCashOutClick()
    if self._closing then return end
    self._closing = true
    Sfx.play("coinTotalThud", { pitch = 1.2, volume = 0.85 })
    if _G.jiggleScreen then _G.jiggleScreen(1.2) end
    if FlashShader and FlashShader.trigger then
        FlashShader.trigger(0.65, 0.4)
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

function RoundEvalScreen:_drawCoins()
    if not self._coins then return end
    local icon = require("src.ui.IconLoader").get("ui_gold")
    for _, c in ipairs(self._coins) do
        if (c.a or 0) > 0.01 then
            love.graphics.setColor(1, 1, 1, c.a)
            if icon and icon.image then
                local iw = icon.image:getWidth()
                love.graphics.draw(icon.image, c.x, c.y, c.rot,
                    c.s, c.s, iw * 0.5, icon.image:getHeight() * 0.5)
            else
                love.graphics.setColor(0.95, 0.80, 0.28, c.a)
                love.graphics.circle("fill", c.x, c.y, 7 * (c.s or 1))
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function RoundEvalScreen:update(dt)
    if not self.visible then return end

    if self.titleText then self.titleText:update(dt) end
    if self.scoreText then self.scoreText:update(dt) end
    if self.totalText then self.totalText:update(dt) end
    for _, dyna in ipairs(self.rowDynas) do dyna:update(dt) end

    if self.cashOutButton then self.cashOutButton:update(dt) end

    if self._totalPulseTimer > 0 then
        self._totalPulseTimer = math.max(0, self._totalPulseTimer - dt)
        if self.totalText and self._totalPulseTimer > 0.2 then
            self.totalText:pulse(0.2, 0.2)
        end
    end
end

function RoundEvalScreen:draw()
    if not self.visible then return end
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()

    love.graphics.setColor(0.05, 0.04, 0.08, 0.65)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    love.graphics.push()
    love.graphics.translate(0, self.slideOffsetY or 0)

    local panelW = math.floor(sw * 0.55)
    local panelH = math.floor(sh * 0.62)
    local panelX = math.floor((sw - panelW) * 0.5)
    local panelY = math.floor(sh * 0.10)

    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", panelX + 6, panelY + 6, panelW, panelH, 8, 8)
    love.graphics.setColor(0.12, 0.10, 0.08, 0.96)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 8, 8)
    love.graphics.setColor(1, 0.88, 0.55, 0.18)
    love.graphics.setLineWidth(1)
    love.graphics.line(panelX + 8, panelY + 2, panelX + panelW - 8, panelY + 2)
    love.graphics.setColor(Palette.AGED_GOLD or {0.78, 0.65, 0.20, 1})
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 8, 8)
    love.graphics.setColor(Palette.AGED_GOLD_DARK or {0.45, 0.32, 0.10, 1})
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", panelX + 4, panelY + 4, panelW - 8, panelH - 8, 6, 6)

    do
        local cornerSize = 14
        love.graphics.setColor(Palette.AGED_GOLD_LIGHT or {1, 0.92, 0.55, 1})
        love.graphics.setLineWidth(2)
        local px = panelX
        local py = panelY
        local pw = panelW
        local ph = panelH
        love.graphics.line(px + 3, py + cornerSize, px + 3, py + 3, px + cornerSize, py + 3)
        love.graphics.line(px + pw - cornerSize, py + 3, px + pw - 3, py + 3, px + pw - 3, py + cornerSize)
        love.graphics.line(px + 3, py + ph - cornerSize, px + 3, py + ph - 3, px + cornerSize, py + ph - 3)
        love.graphics.line(px + pw - cornerSize, py + ph - 3, px + pw - 3, py + ph - 3, px + pw - 3, py + ph - cornerSize)
    end

    if self.titleText then
        self.titleText:draw(sw * 0.5, panelY + 32)
    end

    love.graphics.setColor(0.78, 0.65, 0.20, 0.6)
    love.graphics.setLineWidth(1)
    love.graphics.line(panelX + 24, panelY + 60, panelX + panelW - 24, panelY + 60)

    local scoreBlockH = 0
    if self.scoreData and self._scoreVisible then
        if self.scoreText then
            self.scoreText:draw(sw * 0.5, panelY + 80)
        end
        local lines = self.scoreData.breakdown or {}
        local lf = FontManager.getFont(10)
        love.graphics.setFont(lf)
        local ly = panelY + 98
        local lx = panelX + 60
        local rx = panelX + panelW - 60
        local TextFit = require("src.ui.TextFit")
        for _, item in ipairs(lines) do
            local valueW = lf:getWidth(item.value)
            if item.bad then
                love.graphics.setColor(0.85, 0.45, 0.35, 0.95)
            else
                love.graphics.setColor(0.82, 0.78, 0.70, 0.95)
            end
            TextFit.print(item.label, lx, ly,
                { size = 10, maxW = math.max(40, rx - lx - valueW - 12) })
            if item.bad then
                love.graphics.setColor(0.9, 0.4, 0.3, 1)
            else
                love.graphics.setColor(1, 0.85, 0.30, 1)
            end
            love.graphics.setFont(lf)
            love.graphics.print(item.value, rx - valueW, ly)
            ly = ly + 16
        end
        scoreBlockH = 34 + #lines * 16
        love.graphics.setColor(0.78, 0.65, 0.20, 0.4)
        love.graphics.setLineWidth(1)
        love.graphics.line(panelX + 24, ly + 4, panelX + panelW - 24, ly + 4)
    elseif self.scoreData then
        scoreBlockH = 34 + #(self.scoreData.breakdown or {}) * 16
    end

    local rowY = panelY + 90 + scoreBlockH
    local rowH = 36
    local labelX = panelX + 36
    local coinsX = panelX + panelW - 36

    for i, src in ipairs(self.sources) do
        if self._rowVisible[i] then
            if self.rowDynas[i] then
                self.rowDynas[i]:draw(labelX + 70, rowY + rowH * 0.5)
            end

            local coinsCount = self._rowCoins[i] or 0
            local dollars = src.dollars or 0
            if dollars <= PHASES.BIG_THRESHOLD then
                local coinsTxt = string.rep("$", coinsCount)
                local font = FontManager.getFont(15)
                love.graphics.setFont(font)
                local color = src.color or {1, 0.85, 0.30, 1}
                love.graphics.setColor(color)
                local tw = font:getWidth(coinsTxt)
                love.graphics.print(coinsTxt, coinsX - tw, rowY + rowH * 0.5 - font:getHeight() * 0.5)
            else
                local txt = "$" .. coinsCount
                local font = FontManager.getFont(18)
                love.graphics.setFont(font)
                love.graphics.setColor(src.color or {1, 0.85, 0.30, 1})
                local tw = font:getWidth(txt)
                love.graphics.print(txt, coinsX - tw, rowY + rowH * 0.5 - font:getHeight() * 0.5)
            end
        end

        rowY = rowY + rowH + 4
    end

    love.graphics.setColor(0.78, 0.65, 0.20, 0.7)
    love.graphics.setLineWidth(2)
    love.graphics.line(panelX + 60, rowY + 8, panelX + panelW - 60, rowY + 8)

    if self.totalText then
        self.totalText:setText(I18n.t("round_eval.total",
            { n = self.coinsAccumulated }, "TOTAL: $" .. self.coinsAccumulated))
        self.totalText:draw(sw * 0.5, rowY + 36)
    end

    love.graphics.pop()

    if self.cashOutButton and self.cashOutReady then
        local btn = self.cashOutButton
        love.graphics.setColor(0.99, 0.64, 0.0, 0.4)
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
    if (key == "return" or key == "space") and self.cashOutReady and not self._closing then
        self:_onCashOutClick()
        return true
    end
    return false
end

return RoundEvalScreen
