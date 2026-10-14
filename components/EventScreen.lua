local EventScreen = {}
EventScreen.__index = EventScreen

local FontManager      = require("src.ui.FontManager")
local Palette          = require("src.ui.Palette")
local Button           = require("components.Button")
local Panel9           = require("src.ui.Panel9")
local SceneBackground  = require("src.ui.SceneBackground")
local HintBar          = require("src.ui.HintBar")
local Sfx              = require("src.systems.Sfx")
local Moveable         = require("engine.Moveable")
local I18n             = require("src.i18n.I18n")
local Debug            = require("src.core.Debug")
local EventManager     = require("engine.EventManager")
local DynaText         = require("src.ui.DynaText")
local FloatingText     = require("src.ui.FloatingText")

local illustrationCache = {}

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
            Debug.warn("[EventScreen] nenhum sfx registrado em: " .. key)
        end
    end
    return nil
end

local function getIllustration(eventId)
    if not eventId then return nil end
    if illustrationCache[eventId] ~= nil then
        return illustrationCache[eventId] or nil
    end
    local path = "assets/sprites/ui/event_" .. eventId .. ".png"
    if love.filesystem.getInfo(path) then
        local ok, img = pcall(love.graphics.newImage, path)
        if ok and img then
            img:setFilter("nearest", "nearest")
            illustrationCache[eventId] = img
            return img
        end
    end
    illustrationCache[eventId] = false
    return nil
end

local FXQ = "event_fx"

local ENTER_DUR   = 0.34
local ENTER_RISE  = 26
local EXIT_DUR    = 0.30

function EventScreen:new()
    local instance = setmetatable({}, EventScreen)
    instance.visible = false
    instance.event = nil
    instance.game = nil
    instance.onClose = nil
    instance.buttons = {}
    instance.resultText = nil
    instance.resultTimer = 0
    instance.panelOy = 0
    instance.fade    = 1
    instance._closing = false
    return instance
end

function EventScreen:show(event, game, onClose)
    self.visible = true
    self.event = event
    self.game = game
    self.onClose = onClose
    self.resultText = nil
    self.resultTimer = 0
    self._closing = false
    self:buildButtons()
    self:_buildTitle()

    EventManager.clear(FXQ)

    if reducedMotion() then
        self.panelOy, self.fade = 0, 1
    else
        self.panelOy = ENTER_RISE
        self.fade = 0
        EventManager.parallelEase(self, "panelOy", 0, ENTER_DUR, "back_out", FXQ)
        EventManager.parallelEase(self, "fade",    1, ENTER_DUR * 0.7, "smooth", FXQ)
    end

    playFirstSfx({ "eventEnterWind", "menuOpen" })
end

function EventScreen:_closeWithFade()
    if self._closing then return end
    self._closing = true
    local cb = self.onClose

    if reducedMotion() then
        self:hide()
        if cb then cb() end
        return
    end

    EventManager.parallelEase(self, "fade", 0, EXIT_DUR, "smooth", FXQ)
    EventManager.parallelEase(self, "panelOy", -ENTER_RISE * 0.6, EXIT_DUR, "smooth", FXQ)
    EventManager.parallel(EXIT_DUR + 0.02, function()
        if not self.visible then return end
        self:hide()
        if cb then cb() end
    end, FXQ)
end

function EventScreen:hide()
    self.visible = false
    self.event = nil
    self.buttons = {}
    self.titleDyna = nil
    self._closing = false
    self.panelOy, self.fade = 0, 1
    EventManager.clear(FXQ)
end

function EventScreen:isVisible() return self.visible end

function EventScreen:_buildTitle()
    local ev = self.event
    local title = ev and I18n.t("events." .. ev.id .. ".title", nil, ev.title or "") or ""
    self.titleDyna = DynaText.new({
        text = title,
        fontSize = 20,
        bump = false,
        pop_in = reducedMotion() and 0 or 0.4,
        pop_in_rate = 5,
        spacing = 1,
        colours = { { Palette.INK[1], Palette.INK[2], Palette.INK[3], 1 } },
        align = "center",
    })
end

function EventScreen:resize()
    if not self.visible then return end
    self:buildButtons()
    self:_buildTitle()
end

function EventScreen:panelRect()
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()
    local pw = math.min(620, math.floor(sw * 0.78))
    local ph = math.min(600, math.floor(sh * 0.88))
    local px = math.floor((sw - pw) / 2)
    local py = math.floor((sh - ph) / 2)
    return px, py, pw, ph
end

local function deltaText(d)
    if type(d) == "string" then return d end
    if type(d) ~= "table" or not d.k then return tostring(d) end
    return I18n.t("events.tokens." .. d.k, d, d.fb or d.k)
end

local function composeOptionLabel(ev, opt, index)
    local label = opt.label
    if ev and ev.id then
        label = I18n.t("events." .. ev.id .. ".opt" .. index, nil, opt.label or "")
    end
    if not opt.gains and not opt.costs then return label end
    local parts = {}
    for _, g in ipairs(opt.gains or {}) do table.insert(parts, "+" .. deltaText(g)) end
    for _, c in ipairs(opt.costs or {}) do table.insert(parts, "-" .. deltaText(c)) end
    if #parts == 0 then return label end
    return label .. "  [" .. table.concat(parts, " / ") .. "]"
end

function EventScreen:optionLabel(opt, index)
    return composeOptionLabel(self.event, opt, index)
end

function EventScreen:buildButtons()
    self.buttons = {}
    if not self.event then return end
    local px, py, pw, ph = self:panelRect()
    local opts = self.event.options or {}
    local btnW = pw - 120
    local btnH = 46
    local spacing = 10
    local startY = py + ph - 40 - (#opts) * (btnH + spacing)
    for i, opt in ipairs(opts) do
        local y = startY + (i - 1) * (btnH + spacing)
        local x = math.floor(px + (pw - btnW) / 2)
        local onClick = function()
            local feedback
            local rm = self.game and self.game.runManager
            if rm and rm.journalEvent then
                rm:journalEvent(self.event and self.event.id, i, opt.label)
            end
            if opt.apply then
                local ok, res = pcall(opt.apply, self.game)
                if ok then feedback = res end
            end
            local run = rm and rm.currentRun
            if run and run.stage == "event" then run.stage = "event_done" end
            self.resultText = feedback
                or I18n.t("event.default_result", nil, "Voce segue em frente.")
            self.resultTimer = 1.8
            self.buttons = {}

            playFirstSfx({ "eventChoiceSeal", "buttonClick" })
            if _G.jiggleScreen then _G.jiggleScreen(0.45) end

            self:_spawnDeltas(opt, x + btnW * 0.5, y)
        end
        local btn = Button:new(x, y, btnW, btnH,
            composeOptionLabel(self.event, opt, i), onClick, nil, 10)
        if not require("src.data.events").canAfford(opt, self.game) then
            btn:setEnabled(false)
        end
        table.insert(self.buttons, btn)
    end
end

function EventScreen:_spawnDeltas(opt, cx, cy)
    if reducedMotion() then return end
    local i = 0
    local function emit(list, prefix, color)
        for _, txt in ipairs(list or {}) do
            local delay = i * 0.13
            i = i + 1
            local texto = deltaText(txt)
            EventManager.parallel(delay, function()
                FloatingText.spawn(prefix .. texto, cx, cy - i * 4, {
                    color = color, fontSize = 13, lift = 30, hold = 0.5,
                })
            end, FXQ)
        end
    end
    emit(opt.gains, "+", { 1, 0.84, 0.32, 1 })
    emit(opt.costs, "-", { 0.90, 0.35, 0.30, 1 })
end

function EventScreen:_isAnimating()
    return self._closing or math.abs(self.panelOy or 0) > 0.5
end

function EventScreen:update(dt)
    if not self.visible then return end
    if self:_isAnimating() then
        for _, b in ipairs(self.buttons) do b.hover = false; b.pressed = false end
    else
        for _, b in ipairs(self.buttons) do b:update(dt) end
    end
    if self.titleDyna then self.titleDyna:update(dt) end
    if self.resultTimer > 0 then
        self.resultTimer = self.resultTimer - dt
        if self.resultTimer <= 0 then
            self.resultTimer = 0
            self:_closeWithFade()
        end
    end
end

function EventScreen:draw()
    if not self.visible then return end
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()

    local drawn = SceneBackground.draw("path_event", sw, sh, 0.40)
    if not drawn then
        love.graphics.setColor(0.06, 0.05, 0.07, 1)
        love.graphics.rectangle("fill", 0, 0, sw, sh)
    end
    love.graphics.setColor(1, 1, 1, 1)

    love.graphics.push()
    love.graphics.translate(0, self.panelOy or 0)

    local px, py, pw, ph = self:panelRect()
    Panel9.draw("panel_main", px, py, pw, ph)

    local ev = self.event
    if self.titleDyna then
        self.titleDyna:draw(math.floor(px + pw / 2), py + 50)
    end

    local opts = (self.event and self.event.options) or {}
    local buttonsTop = py + ph - 40 - (#opts) * (46 + 10)
    local areaTop = py + 80
    local areaH = buttonsTop - areaTop - 16

    local img = getIllustration(self.event and self.event.id)
    local bodyFont = FontManager.getFont(10)
    local bodyText = ev and I18n.t("events." .. ev.id .. ".body", nil, ev.body or "") or ""
    local bodyW = pw - 120
    local _, bodyLines = bodyFont:getWrap(bodyText, bodyW)
    local bodyLH = math.floor(bodyFont:getHeight() * 1.3 + 0.5)
    local bodyH = #bodyLines * bodyLH

    local function drawBody(x, y)
        love.graphics.setFont(bodyFont)
        Palette.set(Palette.INK)
        for i, line in ipairs(bodyLines) do
            love.graphics.printf(line, x, y + (i - 1) * bodyLH, bodyW, "center")
        end
    end

    if img then
        local iw, ih = img:getWidth(), img:getHeight()
        local s = math.min(2, (pw - 200) / iw)
        local dw, dh = iw * s, ih * s
        local blockH = dh + 28 + bodyH
        local contentY = math.floor(areaTop + math.max(0, (areaH - blockH) / 2))
        local ix = math.floor(px + pw / 2 - dw / 2)
        Panel9.draw("panel_inner", ix - 10, contentY - 8, dw + 20, dh + 16, {
            fill = { 0.10, 0.08, 0.06, 0.95 },
        })
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(img, ix, contentY, 0, s, s)
        drawBody(px + 60, contentY + dh + 28)
    else
        local contentY = math.floor(areaTop + math.max(0, (areaH - bodyH) / 2))
        drawBody(px + 60, contentY)
    end

    for _, b in ipairs(self.buttons) do b:draw() end
    require("src.systems.Tutorial").anchorList("event_options", self.buttons)

    if self.resultText then
        local rf = FontManager.getFont(12)
        love.graphics.setFont(rf)
        Palette.set(Palette.MOSS)
        love.graphics.print(self.resultText,
            math.floor(px + pw / 2 - rf:getWidth(self.resultText) / 2),
            py + ph - 90)
    end

    love.graphics.pop()

    HintBar.draw(I18n.t("event.hint",
        { n = math.max(1, #(self.event and self.event.options or {})) },
        "Clique numa opcao OU pressione 1-{n} · a escolha e definitiva"))

    local f = self.fade or 1
    if f < 0.999 then
        love.graphics.setColor(0.03, 0.025, 0.035, 1 - f)
        love.graphics.rectangle("fill", 0, 0, sw, sh)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function EventScreen:mousepressed(x, y, button)
    if not self.visible then return false end
    if self:_isAnimating() then return true end
    for _, b in ipairs(self.buttons) do
        if b:mousepressed(x, y, button) then return true end
    end
    return true
end

function EventScreen:mousereleased(x, y, button)
    if not self.visible then return false end
    if self:_isAnimating() then return true end
    for _, b in ipairs(self.buttons) do
        if b:mousereleased(x, y, button) then return true end
    end
    return false
end

function EventScreen:keypressed(key)
    if not self.visible then return false end
    if self:_isAnimating() then return true end
    if key == "1" or key == "2" or key == "3" or key == "4" then
        local i = tonumber(key)
        local btn = self.buttons[i]
        if btn and btn.onClick and not btn.disabled then
            Sfx.playWithVariation("buttonClick", 1.0, 0.08)
            Moveable.juice_up(btn, 0.22, 0.05)
            if _G.jiggleScreen then _G.jiggleScreen(0.3) end
            btn.onClick()
        end
        return true
    end
    return false
end

return EventScreen
