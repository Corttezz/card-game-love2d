-- components/EndlessCurseScreen.lua
-- ESCOLHA DE MALDIÇÃO do endless (Out/2026). A cada ciclo de 8 andares
-- (RunManager:advanceFloorInAct → RunModifiers.beginEndlessCycle) duas
-- maldições ficam ABERTAS em run.endless.pending; esta tela obriga a escolher
-- uma (não tem "pular" — StS: Neow impõe a praga; aqui o jogador escolhe QUAL).
--
-- Quem abre: EndlessCurseScreen.watch(game, state), chamado todo frame pelo
-- love.update. Observar o ESTADO em vez de ser chamado por quem gira o ciclo
-- é o que torna a escolha à prova de Continuar: a pendência viaja no save e,
-- ao voltar pro mapa, a tela reabre sozinha.
--
-- Layout em ZONAS puro (layout + validate), recalculado por frame. Entrada:
-- mouse e teclado/gamepad via MenuKit (esquerda/direita escolhe, Enter
-- confirma).

local FontManager = require("src.ui.FontManager")
local Palette     = require("src.ui.Palette")
local UiPanel     = require("src.ui.UiPanel")
local MenuKit     = require("src.ui.MenuKit")
local IconLoader  = require("src.ui.IconLoader")
local I18n        = require("src.i18n.I18n")
local Sfx         = require("src.systems.Sfx")
local RunModifiers = require("src.systems.RunModifiers")

local Screen = {}
Screen.__index = Screen

local PAD, GAP = 22, 14

local function fitFont(text, maxW, startSize, minSize)
    local size = startSize
    while size > minSize do
        local f = FontManager.getFont(size)
        if f:getWidth(text) <= maxW then return f end
        size = size - 1
    end
    return FontManager.getFont(minSize)
end

-- ===== layout puro =====
function Screen.layout(sw, sh)
    local big = sw >= 1600 and sh >= 900
    local pw = math.min(big and 860 or 680, sw - 32)
    local inner = pw - PAD * 2
    local titleH = big and 28 or 22
    local subH = big and 14 or 11
    local cardH = math.max(170, math.min(big and 250 or 200, sh - 260))
    local activeH = big and 34 or 28
    local ph = PAD + titleH + 8 + subH + GAP + cardH + GAP + activeH + PAD
    ph = math.min(ph, sh - 16)
    local px = math.floor((sw - pw) / 2)
    local py = math.floor((sh - ph) / 2)
    local L = { panel = { x = px, y = py, w = pw, h = ph }, big = big }
    local x0, y = px + PAD, py + PAD
    L.title = { x = x0, y = y, w = inner, h = titleH }; y = y + titleH + 8
    L.subtitle = { x = x0, y = y, w = inner, h = subH }; y = y + subH + GAP
    local cw = math.floor((inner - GAP) / 2)
    L.cards = {
        { x = x0, y = y, w = cw, h = cardH },
        { x = x0 + cw + GAP, y = y, w = cw, h = cardH },
    }
    y = y + cardH + GAP
    L.active = { x = x0, y = y, w = inner, h = activeH }
    return L
end

function Screen.validate(L, sw, sh)
    local probs = {}
    local p = L.panel
    if p.x < 0 or p.y < 0 or p.x + p.w > sw or p.y + p.h > sh then probs[#probs + 1] = "painel fora da tela" end
    local all = { { L.title, "title" }, { L.subtitle, "subtitle" }, { L.cards[1], "card1" },
        { L.cards[2], "card2" }, { L.active, "active" } }
    for i, a in ipairs(all) do
        local r = a[1]
        if r.x < p.x or r.y < p.y or r.x + r.w > p.x + p.w or r.y + r.h > p.y + p.h then
            probs[#probs + 1] = a[2] .. " fora do painel"
        end
        for j = i + 1, #all do
            if MenuKit.overlaps(r, all[j][1]) then probs[#probs + 1] = a[2] .. " x " .. all[j][2] end
        end
    end
    return probs
end

-- ===== ciclo =====
function Screen:new()
    return setmetatable({ visible = false, time = 0, focus = 1 }, Screen)
end

function Screen:isVisible() return self.visible end

function Screen:_run()
    local rm = self.game and self.game.runManager
    return rm and rm.currentRun
end

function Screen:show(game)
    self.game = game
    self.visible = true
    self.time = 0
    self.focus = 1
    self._chosen = nil
    Sfx.play("menuOpen")
end

-- Fechar SEM escolher só acontece de fora (voltar ao menu); a pendência
-- continua no save e a tela reabre no próximo mapa.
function Screen:hide()
    self.visible = false
end

function Screen:resize() end

-- Observa o estado: escolha pendente + mapa na tela = abre.
function Screen.watch(screen, game, state)
    if not screen or screen.visible or not game then return end
    if state ~= "mapSelection" then return end
    local rm = game.runManager
    local run = rm and rm.currentRun
    if run and RunModifiers.pending(run) then screen:show(game) end
end

function Screen:choose(i)
    local run = self:_run()
    local pend = RunModifiers.pending(run)
    local id = pend and pend[i]
    if not id then return end
    if RunModifiers.chooseCurse(run, id) then
        -- Escolha é estado da run: grava na hora (anti save-scum).
        if self.game.checkpointRun then self.game:checkpointRun() end
        Sfx.play("debuffApplied")
        Sfx.play("coinTotalThud")
        if self.game.addMessage then
            self.game:addMessage(I18n.t("endless.curse_taken", {
                name = I18n.t("endless_curses." .. id .. ".name") }), "warning")
        end
        self.visible = false
    end
end

function Screen:update(dt)
    if not self.visible then return end
    self.time = self.time + dt
    local L = Screen.layout(love.graphics.getWidth(), love.graphics.getHeight())
    local mx, my = love.mouse.getPosition()
    for i = 1, 2 do
        if MenuKit.hit(L.cards[i], mx, my) and self.focus ~= i then
            self.focus = i
            Sfx.play("menuHover")
        end
    end
end

-- Texto da regra de uma maldição com o acúmulo que ela TERIA ao ser escolhida.
local function curseLines(run, id)
    local c = RunModifiers.getCurse(id)
    local stacks = RunModifiers.curseStacks(run, id)
    return I18n.t("endless_curses." .. id .. ".name"),
        I18n.t("endless_curses." .. id .. ".desc"),
        I18n.t("endless.stacks", { n = stacks + 1, max = c and c.max or "?" }),
        I18n.t("endless.score_bonus", { n = math.floor(((c and c.score) or 0) * 100 + 0.5) })
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

function Screen:_drawCard(i, r, id, run, big)
    local focus = (self.focus == i)
    love.graphics.setColor(focus and { 0.20, 0.07, 0.10, 0.96 } or { 0.08, 0.05, 0.06, 0.92 })
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 6, 6)
    Palette.set(focus and Palette.BLOOD or Palette.AGED_GOLD_DARK)
    love.graphics.setLineWidth(focus and 2 or 1)
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 6, 6)
    love.graphics.setLineWidth(1)

    local name, desc, stacks, score = curseLines(run, id)
    local iconS = math.floor(math.min(r.w * 0.45, r.h * 0.38) / 16) * 16
    local icon = IconLoader.get("curse_" .. id)
    local y = r.y + 10
    if icon and icon.image then
        love.graphics.setColor(1, 1, 1, 1)
        local sc = iconS / icon.image:getWidth()
        love.graphics.draw(icon.image, math.floor(r.x + r.w / 2 - iconS / 2), y, 0, sc, sc)
    end
    y = y + iconS + 6
    local nameH = big and 24 or 18
    printCentered(name, { x = r.x + 6, y = y, w = r.w - 12, h = nameH },
        fitFont(name, r.w - 16, big and 18 or 14, 8), Palette.BLOOD_LIGHT or Palette.AGED_GOLD_LIGHT)
    y = y + nameH + 4
    local df = FontManager.getFont(big and 12 or 10)
    local _, lines = df:getWrap(desc, r.w - 20)
    love.graphics.setFont(df)
    Palette.set(Palette.PARCHMENT_LIGHT)
    local lh = math.ceil(df:getHeight() * 1.25)
    local footH = (big and 16 or 12) * 2 + 8
    local maxLines = math.max(1, math.floor((r.y + r.h - footH - y) / lh))
    for k = 1, math.min(#lines, maxLines) do
        love.graphics.print(lines[k], math.floor(r.x + r.w / 2 - df:getWidth(lines[k]) / 2), y)
        y = y + lh
    end
    local ff = FontManager.getFont(big and 12 or 10)
    local fy = r.y + r.h - footH
    printCentered(stacks, { x = r.x, y = fy, w = r.w, h = footH / 2 }, ff, Palette.PARCHMENT)
    printCentered(score, { x = r.x, y = fy + footH / 2, w = r.w, h = footH / 2 }, ff, Palette.AGED_GOLD_LIGHT)
    if focus then MenuKit.focusRing(r.x, r.y, r.w, r.h, self.time) end
end

function Screen:draw()
    if not self.visible then return end
    local run = self:_run()
    local pend = RunModifiers.pending(run)
    if not pend then self.visible = false; return end
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local L = Screen.layout(sw, sh)
    MenuKit.drawVeil(self.time, 0.72)
    MenuKit.pushEnter(self.time)
    local p = L.panel
    UiPanel.draw(p.x, p.y, p.w, p.h)
    local title = I18n.t("endless.cycle_title", { n = RunModifiers.cycle(run) })
    printCentered(title, L.title, fitFont(title, L.title.w, L.title.h, 10), Palette.AGED_GOLD_LIGHT)
    local sub = I18n.t("endless.cycle_sub")
    printCentered(sub, L.subtitle, fitFont(sub, L.subtitle.w, L.subtitle.h, 6), Palette.PARCHMENT)
    for i = 1, 2 do
        if pend[i] then self:_drawCard(i, L.cards[i], pend[i], run, L.big) end
    end
    -- Maldições já carregadas (o peso que se acumula).
    local list = RunModifiers.curseList(run)
    local parts = {}
    for _, c in ipairs(list) do
        parts[#parts + 1] = I18n.t("endless_curses." .. c.id .. ".name") .. " x" .. c.stacks
    end
    local active = (#parts > 0)
        and I18n.t("endless.active", { list = table.concat(parts, " · ") })
        or I18n.t("endless.active_none")
    active = active .. "   " .. I18n.t("endless.score_total", {
        n = string.format("%.2f", RunModifiers.scoreMul(run)) })
    printCentered(active, L.active, fitFont(active, L.active.w, L.big and 12 or 10, 6), Palette.PARCHMENT)
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
end

-- ===== entrada =====
function Screen:mousepressed() return true end

function Screen:mousereleased(x, y, button)
    if not self.visible or button ~= 1 then return true end
    local L = Screen.layout(love.graphics.getWidth(), love.graphics.getHeight())
    for i = 1, 2 do
        if MenuKit.hit(L.cards[i], x, y) then self:choose(i); return true end
    end
    return true
end

function Screen:wheelmoved() return true end

function Screen:keypressed(key)
    if not self.visible then return false end
    local it = MenuKit.intent(key, MenuKit.shiftDown())
    if it == "left" or it == "up" then
        if self.focus ~= 1 then Sfx.play("menuHover") end
        self.focus = 1
    elseif it == "right" or it == "down" then
        if self.focus ~= 2 then Sfx.play("menuHover") end
        self.focus = 2
    elseif it == "confirm" then
        self:choose(self.focus)
    end
    -- "back" não fecha: a escolha é obrigatória (o modal captura o teclado,
    -- então nem a pausa abre por cima — decide-se primeiro).
    return true
end

return Screen
