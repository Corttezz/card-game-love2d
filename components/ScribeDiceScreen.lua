local Button      = require("components.Button")
local FontManager = require("src.ui.FontManager")
local Palette     = require("src.ui.Palette")
local UiPanel     = require("src.ui.UiPanel")
local MenuKit     = require("src.ui.MenuKit")
local ImageCache  = require("src.ui.ImageCache")
local I18n        = require("src.i18n.I18n")
local Sfx         = require("src.systems.Sfx")
local ScribeDice  = require("src.systems.ScribeDice")

local ScribeDiceScreen = {}
ScribeDiceScreen.__index = ScribeDiceScreen
ScribeDiceScreen.ownsNavigation = true

local ROLL_DUR = 1.15
local FACE_SWAP = 0.075
local PAD = 22
local GAP = 12

local function reducedMotion()
    return _G.gameSettings and _G.gameSettings.reducedMotion
end

local function fitFont(text, maxW, startSize, minSize)
    local size = startSize
    while size > minSize do
        local f = FontManager.getFont(size)
        if f:getWidth(text) <= maxW then return f end
        size = size - 1
    end
    return FontManager.getFont(minSize)
end

function ScribeDiceScreen.layout(sw, sh)
    local small = sw < 900 or sh < 700
    local big = sw >= 1600 and sh >= 900
    local pw = math.min(big and 820 or 640, sw - 32)
    local inner = pw - PAD * 2
    local titleH = big and 28 or (small and 18 or 22)
    local subH = big and 14 or (small and 10 or 12)
    local statusH = (big and 16 or (small and 10 or 12)) + 10
    local betH = big and 96 or (small and 62 or 74)
    local stakeH = big and 46 or (small and 32 or 38)
    local btnH = big and 46 or (small and 32 or 38)

    local fixed = PAD + titleH + 8 + subH + GAP + GAP + statusH + GAP + betH
        + GAP + stakeH + GAP * 2 + btnH + PAD
    local tableH = math.max(70, math.min(180, sh - 32 - fixed))
    local ph = math.min(sh - 16, fixed + tableH)
    local px = math.floor((sw - pw) / 2)
    local py = math.floor((sh - ph) / 2)

    local L = { panel = { x = px, y = py, w = pw, h = ph }, small = small, big = big }
    local x0, y = px + PAD, py + PAD
    L.title = { x = x0, y = y, w = inner, h = titleH }; y = y + titleH + 8
    local hr = big and 12 or 9
    L.help = { cx = x0 + inner - hr - 3, cy = L.title.y + math.floor(titleH / 2), r = hr }
    L.titleText = { x = x0 + hr * 2 + 12, y = L.title.y, w = inner - 2 * (hr * 2 + 12), h = titleH }
    L.subtitle = { x = x0, y = y, w = inner, h = subH }; y = y + subH + GAP
    L.table = { x = x0, y = y, w = inner, h = tableH }; y = y + tableH + GAP
    L.status = { x = x0, y = y, w = inner, h = statusH }; y = y + statusH + GAP
    local bw = math.floor((inner - GAP * 2) / 3)
    L.bets = {}
    for i = 1, 3 do
        L.bets[i] = { x = x0 + (i - 1) * (bw + GAP), y = y, w = bw, h = betH }
    end
    y = y + betH + GAP
    local labelW = math.floor(inner * 0.28)
    L.stakeLabel = { x = x0, y = y, w = labelW - GAP, h = stakeH }
    local cw = math.floor((inner - labelW - GAP * 2) / 3)
    L.stakes = {}
    for i = 1, 3 do
        L.stakes[i] = { x = x0 + labelW + (i - 1) * (cw + GAP), y = y, w = cw, h = stakeH }
    end
    y = y + stakeH + GAP * 2
    local half = math.floor((inner - GAP) / 2)
    L.leave = { x = x0, y = y, w = half, h = btnH }
    L.roll = { x = x0 + half + GAP, y = y, w = half, h = btnH }
    return L
end

function ScribeDiceScreen.validate(L, sw, sh)
    local probs = {}
    local p = L.panel
    local function inside(r, name)
        if r.x < p.x or r.y < p.y or r.x + r.w > p.x + p.w + 0.5
            or r.y + r.h > p.y + p.h + 0.5 then
            probs[#probs + 1] = name .. " fora do painel"
        end
    end
    if p.x < 0 or p.y < 0 or p.x + p.w > sw or p.y + p.h > sh then
        probs[#probs + 1] = "painel fora da tela"
    end
    if L.help and L.titleText then
        local hr = require("src.ui.HelpBadge").rect(L.help.cx, L.help.cy, L.help.r)
        inside(hr, "help")
        if MenuKit.overlaps(hr, L.titleText) then probs[#probs + 1] = "help x titulo" end
        if MenuKit.overlaps(hr, L.subtitle) then probs[#probs + 1] = "help x subtitulo" end
    end
    local all = { { L.title, "title" }, { L.subtitle, "subtitle" }, { L.table, "table" },
        { L.status, "status" }, { L.stakeLabel, "stakeLabel" }, { L.leave, "leave" },
        { L.roll, "roll" } }
    for i = 1, 3 do
        all[#all + 1] = { L.bets[i], "bet" .. i }
        all[#all + 1] = { L.stakes[i], "stake" .. i }
    end
    for i, a in ipairs(all) do
        inside(a[1], a[2])
        if a[1].w <= 0 or a[1].h <= 0 then probs[#probs + 1] = a[2] .. " vazio" end
        for j = i + 1, #all do
            if MenuKit.overlaps(a[1], all[j][1]) then
                probs[#probs + 1] = a[2] .. " x " .. all[j][2]
            end
        end
    end
    return probs
end

function ScribeDiceScreen:new()
    local s = setmetatable({}, ScribeDiceScreen)
    s.visible = false
    s.time = 0
    s.bet = 3
    s.stake = 1
    s.row = 1
    s.col = 3
    s.rolling = nil
    s.flash = nil
    s.leaveBtn = Button:new(0, 0, 10, 10, "", function() s:hide() end, nil, 12)
    s.rollBtn = Button:new(0, 0, 10, 10, "", function() s:_roll() end, nil, 12)
    s.rollBtn:setColorScheme("red")
    return s
end

function ScribeDiceScreen:isVisible() return self.visible end

function ScribeDiceScreen:show(game, onClose)
    self.game = game
    self.onClose = onClose
    self.visible = true
    self.time = 0
    self.rolling = nil
    self.flash = nil
    self.row, self.col = 1, self.bet
    local stakes = self:_stakes()
    self.stake = 1
    local gold = self:_gold()
    for i = #stakes, 1, -1 do
        if stakes[i] <= gold then self.stake = i; break end
    end
    if self:_used() then self.row, self.col = 3, 1 end
    Sfx.play("menuOpen")
end

function ScribeDiceScreen:hide()
    if not self.visible then return end
    self.rolling = nil
    self.visible = false
    Sfx.play("menuClose")
    local cb = self.onClose
    self.onClose = nil
    if cb then cb() end
end

function ScribeDiceScreen:resize() end

function ScribeDiceScreen:_run()
    local rm = self.game and self.game.runManager
    return rm and rm.currentRun
end

function ScribeDiceScreen:_gold()
    local e = self.game and self.game.economySystem
    return (e and e.currentGold) or 0
end

function ScribeDiceScreen:_stakes()
    local run = self:_run()
    return ScribeDice.stakes(run and run.actNumber or 1)
end

function ScribeDiceScreen:_used()
    return ScribeDice.isUsed(self:_run())
end

function ScribeDiceScreen:_roll()
    if self.rolling or self:_used() then return end
    local run = self:_run()
    local economy = self.game and self.game.economySystem
    local betId = ScribeDice.BET_IDS[self.bet]
    local stake = self:_stakes()[self.stake]
    local st, why = ScribeDice.roll(run, economy, betId, stake)
    if not st then
        self.flash = { key = (why == "poor") and "scribe_dice.poor" or "scribe_dice.used", t = 1.6 }
        Sfx.play("purchaseDeny")
        return
    end
    if self.game and self.game.checkpointRun then self.game:checkpointRun() end

    Sfx.play("coinClink", { pitch = 0.9 })
    if reducedMotion() then
        self.rolling = { t = ROLL_DUR - 0.2, faces = { st.dice[1], st.dice[2] }, swap = 0, knock = 99 }
    else
        self.rolling = { t = 0, faces = { love.math.random(6), love.math.random(6) },
            swap = 0, knock = 0 }
    end
    self.row, self.col = 3, 1
end

function ScribeDiceScreen:_finishRoll()
    self.rolling = nil
    local st = ScribeDice.state(self:_run())
    if not st then return end
    if st.won then
        Sfx.play("coinTotalThud")
        Sfx.play("cashOutChime")
    else
        Sfx.play("sceneStoneThud")
    end
end

function ScribeDiceScreen:update(dt)
    if not self.visible then return end
    self.time = self.time + dt
    if self.flash then
        self.flash.t = self.flash.t - dt
        if self.flash.t <= 0 then self.flash = nil end
    end
    local r = self.rolling
    if r then
        r.t = r.t + dt
        r.swap = r.swap + dt
        if r.t < ROLL_DUR - 0.25 and r.swap >= FACE_SWAP then
            r.swap = 0
            r.faces = { love.math.random(6), love.math.random(6) }
        end
        local knocks = { 0.18, 0.52, 0.80 }
        if r.knock < #knocks and r.t >= knocks[r.knock + 1] then
            r.knock = r.knock + 1
            Sfx.play("sceneWoodKnock", { pitch = 1.15 - r.knock * 0.08 })
        end
        if r.t >= ROLL_DUR then self:_finishRoll() end
    end

    local L = ScribeDiceScreen.layout(love.graphics.getWidth(), love.graphics.getHeight())
    local used = self:_used()
    local stake = self:_stakes()[self.stake] or 0
    local leaveR = L.leave
    if used and not self.rolling then
        leaveR = { x = math.floor(L.panel.x + (L.panel.w - L.leave.w) / 2),
            y = L.leave.y, w = L.leave.w, h = L.leave.h }
    end
    self._leaveR = leaveR
    for _, pair in ipairs({ { self.leaveBtn, leaveR }, { self.rollBtn, L.roll } }) do
        local b, rr = pair[1], pair[2]
        b.x, b.y, b.width, b.height = rr.x, rr.y, rr.w, rr.h
        b.fontSize = L.big and 14 or (L.small and 10 or 12)
        b:update(dt)
    end
    self.leaveBtn:setText(I18n.t("scribe_dice.leave", nil, "Sair"))
    self.rollBtn:setText(I18n.t("scribe_dice.roll", { n = stake }, "Lancar"))
    self.rollBtn:setEnabled(not used and not self.rolling and self:_gold() >= stake)
    self.rollBtn:setVisible(not used or self.rolling ~= nil)
    self.leaveBtn:setEnabled(not self.rolling)
end

local function printCentered(text, r, font, color, alpha)
    love.graphics.setFont(font)
    local tx = math.floor(r.x + r.w / 2 - font:getWidth(text) / 2)
    local ty = math.floor(r.y + r.h / 2 - font:getHeight() / 2)
    love.graphics.setColor(0, 0, 0, 0.8 * (alpha or 1))
    love.graphics.print(text, tx + 1, ty + 1)
    Palette.set(color, alpha)
    love.graphics.print(text, tx, ty)
end

function ScribeDiceScreen:_drawTable(r, st)
    UiPanel.draw(r.x, r.y, r.w, r.h, { depth = "inner", fill = { 0.09, 0.13, 0.08, 0.92 } })
    local cup = ImageCache.tryGet("assets/sprites/minigame/dice_cup.png")
    local cupS = math.max(1, math.floor((r.h - 12) / 64))
    if cup then
        cup:setFilter("nearest", "nearest")
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(cup, r.x + 10, math.floor(r.y + r.h / 2 - 32 * cupS), 0, cupS, cupS)
    end

    local faces = (self.rolling and self.rolling.faces) or (st and st.dice) or { 6, 6 }
    local dieS = math.max(2, math.floor((r.h * 0.55) / 22))
    local size = 22 * dieS
    local cx = r.x + r.w / 2 + (cup and 32 * cupS / 2 or 0)
    local baseY = math.floor(r.y + r.h / 2 - size / 2)
    for i = 1, 2 do
        local img = ImageCache.tryGet("assets/sprites/minigame/die_" .. faces[i] .. ".png")
        local dx = math.floor(cx + (i == 1 and -size - 10 or 10))
        local dy, rot = baseY, 0
        if self.rolling then
            local t = self.rolling.t / ROLL_DUR
            local damp = (1 - t) ^ 1.6
            dy = baseY - math.floor(math.abs(math.sin(t * math.pi * 3.2 + i)) * r.h * 0.28 * damp)
            rot = math.sin(t * 18 + i * 2) * 0.35 * damp
        end
        love.graphics.setColor(0, 0, 0, 0.35)
        love.graphics.ellipse("fill", dx + size / 2, baseY + size + 3, size * 0.45, 4)
        love.graphics.setColor(1, 1, 1, (st or self.rolling) and 1 or 0.45)
        if img then
            img:setFilter("nearest", "nearest")
            love.graphics.draw(img, dx + size / 2, dy + size / 2, rot, dieS, dieS, 11, 11)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function ScribeDiceScreen:_drawBet(i, r, used)
    local id = ScribeDice.BET_IDS[i]
    local sel = (self.bet == i)
    local hov = MenuKit.hit(r, love.mouse.getPosition())
    local fill = sel and { 0.22, 0.15, 0.07, 0.95 } or { 0.07, 0.05, 0.04, 0.9 }
    love.graphics.setColor(fill)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 5, 5)
    Palette.set(sel and Palette.AGED_GOLD_LIGHT or Palette.AGED_GOLD_DARK, (hov and not used) and 1 or 0.9)
    love.graphics.setLineWidth(sel and 2 or 1)
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 5, 5)
    love.graphics.setLineWidth(1)
    local a = used and not sel and 0.5 or 1
    local lineH = math.floor(r.h / 3)
    local nameF = fitFont(I18n.t("scribe_dice.bet_" .. id), r.w - 12,
        r.h > 90 and 18 or (r.h > 66 and 14 or 12), 8)
    printCentered(I18n.t("scribe_dice.bet_" .. id), { x = r.x, y = r.y + 4, w = r.w, h = lineH },
        nameF, Palette.AGED_GOLD_LIGHT, a)
    local pct = math.floor(ScribeDice.chance(id) * 100 + 0.5)
    local rangeT = I18n.t("scribe_dice.range_" .. id)
    printCentered(rangeT, { x = r.x, y = r.y + lineH, w = r.w, h = lineH },
        fitFont(rangeT, r.w - 10, r.h > 90 and 14 or (r.h > 66 and 10 or 8), 7), Palette.PARCHMENT_LIGHT, a)
    local mult = string.format("%g", ScribeDice.payoutMult(id))
    if I18n.getLocale() ~= "en" then mult = (mult:gsub("%.", ",")) end
    local odds = I18n.t("scribe_dice.chance", { n = pct }) .. " · "
        .. I18n.t("scribe_dice.pays", { m = mult })
    printCentered(odds, { x = r.x, y = r.y + lineH * 2 - 4, w = r.w, h = lineH },
        fitFont(odds, r.w - 10, r.h > 90 and 12 or (r.h > 66 and 10 or 8), 6), Palette.PARCHMENT, a)
    if self.row == 1 and self.col == i and not used then
        MenuKit.focusRing(r.x, r.y, r.w, r.h, self.time)
    end
end

function ScribeDiceScreen:_drawStake(i, r, value, used)
    local sel = (self.stake == i)
    local afford = used or self:_gold() >= value
    love.graphics.setColor(sel and { 0.30, 0.20, 0.06, 0.95 } or { 0.07, 0.05, 0.04, 0.9 })
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, r.h / 2, r.h / 2)
    Palette.set(sel and Palette.AGED_GOLD_LIGHT or Palette.AGED_GOLD_DARK)
    love.graphics.setLineWidth(sel and 2 or 1)
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, r.h / 2, r.h / 2)
    love.graphics.setLineWidth(1)
    local a = ((used and not sel) or not afford) and 0.45 or 1
    printCentered("$" .. value, r, FontManager.getFont(r.h > 42 and 18 or (r.h > 34 and 14 or 11)),
        afford and Palette.AGED_GOLD_LIGHT or (Palette.BLOOD_LIGHT or Palette.BLOOD), a)
    if self.row == 2 and self.col == i and not used then
        MenuKit.focusRing(r.x, r.y, r.w, r.h, self.time)
    end
end

function ScribeDiceScreen:draw()
    if not self.visible then return end
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local L = ScribeDiceScreen.layout(sw, sh)
    MenuKit.drawVeil(self.time, 0.66)
    MenuKit.pushEnter(self.time)

    local p = L.panel
    UiPanel.draw(p.x, p.y, p.w, p.h)

    local title = I18n.t("scribe_dice.title")
    printCentered(title, L.titleText, fitFont(title, L.titleText.w, L.title.h, 10),
        Palette.AGED_GOLD_LIGHT)
    local sub = I18n.t("scribe_dice.subtitle")
    printCentered(sub, L.subtitle, fitFont(sub, L.subtitle.w, L.subtitle.h, 6),
        Palette.PARCHMENT)

    local st = ScribeDice.state(self:_run())
    local used = st ~= nil and st.used
    self:_drawTable(L.table, used and st or nil)

    local text, color = I18n.t("scribe_dice.pick"), Palette.PARCHMENT
    if self.flash then
        text, color = I18n.t(self.flash.key), (Palette.BLOOD_LIGHT or Palette.BLOOD)
    elseif used and not self.rolling then
        if st.won then
            text = I18n.t("scribe_dice.win", { sum = st.sum, n = st.payout })
            color = Palette.AGED_GOLD_LIGHT
        else
            text = I18n.t("scribe_dice.lose", { sum = st.sum, n = st.stake })
            color = Palette.BLOOD_LIGHT or Palette.BLOOD
        end
    elseif self.rolling then
        text = ""
    end
    if text ~= "" then
        printCentered(text, L.status, fitFont(text, L.status.w, L.big and 18 or (L.small and 12 or 14), 7), color)
    end

    for i = 1, 3 do self:_drawBet(i, L.bets[i], used) end
    require("src.systems.Tutorial").anchor("dice_table", L.table.x, L.table.y, L.table.w, L.table.h)
    require("src.systems.Tutorial").anchorList("dice_bets", L.bets)
    require("src.systems.Tutorial").anchorList("dice_stakes", L.stakes)
    do
        local HelpBadge = require("src.ui.HelpBadge")
        local hr = HelpBadge.rect(L.help.cx, L.help.cy, L.help.r)
        HelpBadge.draw(L.help.cx, L.help.cy, L.help.r,
            MenuKit.hit(hr, love.mouse.getPosition()))
        require("src.ui.NavCursor").target("dice_help", hr.x, hr.y, hr.w, hr.h)
    end

    local stakes = self:_stakes()
    local lbl = I18n.t("scribe_dice.stake")
    love.graphics.setFont(fitFont(lbl, L.stakeLabel.w, L.big and 16 or (L.small and 10 or 12), 7))
    local f = love.graphics.getFont()
    Palette.set(Palette.PARCHMENT_LIGHT)
    love.graphics.print(lbl, L.stakeLabel.x,
        math.floor(L.stakeLabel.y + L.stakeLabel.h / 2 - f:getHeight() / 2))
    for i = 1, 3 do
        if stakes[i] then self:_drawStake(i, L.stakes[i], stakes[i], used) end
    end

    self.leaveBtn:draw()
    self.rollBtn:draw()
    if self.row == 3 then
        local r = (self.col == 2 and self.rollBtn.visible and not used) and L.roll
            or (self._leaveR or L.leave)
        MenuKit.focusRing(r.x, r.y, r.w, r.h, self.time)
    end

    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
end

function ScribeDiceScreen:mousepressed(x, y, button)
    if not self.visible then return false end
    self.leaveBtn:mousepressed(x, y, button)
    self.rollBtn:mousepressed(x, y, button)
    return true
end

function ScribeDiceScreen:openHelp()
    local ok = require("src.systems.Tutorial").explain("dice_help", self.game)
    if not ok then Sfx.play("purchaseDeny") end
    return ok
end

function ScribeDiceScreen:mousereleased(x, y, button)
    if not self.visible then return false end
    if self.rolling then return true end
    if button == 1 then
        local L0 = ScribeDiceScreen.layout(love.graphics.getWidth(), love.graphics.getHeight())
        if MenuKit.hit(require("src.ui.HelpBadge").rect(L0.help.cx, L0.help.cy, L0.help.r), x, y) then
            self:openHelp()
            return true
        end
    end
    if self.leaveBtn:mousereleased(x, y, button) then return true end
    if self.rollBtn:mousereleased(x, y, button) then return true end
    if button ~= 1 or self:_used() then return true end
    local L = ScribeDiceScreen.layout(love.graphics.getWidth(), love.graphics.getHeight())
    for i = 1, 3 do
        if MenuKit.hit(L.bets[i], x, y) then
            self.bet = i; self.row, self.col = 1, i
            Sfx.play("cardSelect")
            return true
        end
        if MenuKit.hit(L.stakes[i], x, y) then
            self.stake = i; self.row, self.col = 2, i
            Sfx.play("coinClink", { pitch = 1 + i * 0.08 })
            return true
        end
    end
    return true
end

function ScribeDiceScreen:wheelmoved() return true end

function ScribeDiceScreen:keypressed(key)
    if not self.visible then return false end
    if self.rolling then return true end
    if key == "h" or key == "e" then self:openHelp(); return true end
    local it = MenuKit.intent(key, MenuKit.shiftDown())
    local used = self:_used()
    if it == "back" then self:hide(); return true end
    if used then
        if it == "confirm" then self:hide() end
        return true
    end
    if it == "up" then
        self.row = math.max(1, self.row - 1)
    elseif it == "down" then
        self.row = math.min(3, self.row + 1)
    elseif it == "left" then
        self.col = math.max(1, self.col - 1)
    elseif it == "right" then
        self.col = math.min(self.row == 3 and 2 or 3, self.col + 1)
    elseif it == "confirm" then
        if self.row == 1 then
            self.bet = self.col; Sfx.play("cardSelect")
            self.row = 2; self.col = self.stake
        elseif self.row == 2 then
            self.stake = self.col; Sfx.play("coinClink")
            self.row = 3; self.col = 2
        else
            if self.col == 2 then self:_roll() else self:hide() end
        end
        return true
    else
        return true
    end
    if it == "up" or it == "down" then
        self.col = (self.row == 1 and self.bet) or (self.row == 2 and self.stake) or 2
    end
    Sfx.play("menuHover")
    return true
end

return ScribeDiceScreen
