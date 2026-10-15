local FontManager = require("src.ui.FontManager")
local Palette = require("src.ui.Palette")
local Panel9 = require("src.ui.Panel9")
local TextFit = require("src.ui.TextFit")
local Theme = require("src.ui.Theme")
local I18n = require("src.i18n.I18n")

local CheatPanel = {}

CheatPanel.MARGIN = 18
CheatPanel.PAD = 14
CheatPanel.COL_W = 220
CheatPanel.COL_GAP = 10
CheatPanel.BTN_H = 26
CheatPanel.SMALL_H = 20
CheatPanel.BTN_GAP = 4
CheatPanel.TITLE_H = 20
CheatPanel.SECTION_H = 15
CheatPanel.HEADER_H = 12
CheatPanel.STATUS_H = 16
CheatPanel.TAB_W = 132
CheatPanel.TAB_H = 22
CheatPanel.FONT = 8
CheatPanel.MIN_FONT = 6
CheatPanel.HIDE_W = 96

local last = nil

local function CM() return require("src.systems.CheatMode") end
local function Actions() return require("src.ui.CheatActions") end

local function topOffset()
    local tb = _G.topBar
    return ((tb and tb.height) or 52) + 6
end

local function layoutColumn(sections, x, y, L)
    local cy = y
    for si, sec in ipairs(sections) do
        if si > 1 then cy = cy + 6 end
        L.texts[#L.texts + 1] = { kind = "section", text = sec.title, x = x, y = cy,
            w = CheatPanel.COL_W }
        cy = cy + CheatPanel.SECTION_H
        for _, row in ipairs(sec.rows) do
            if row.header then
                L.texts[#L.texts + 1] = { kind = "header", text = row.header, x = x, y = cy,
                    w = CheatPanel.COL_W }
                cy = cy + CheatPanel.HEADER_H
            end
            local per = math.max(1, row.per or 2)
            local bw = (CheatPanel.COL_W - (per - 1) * CheatPanel.BTN_GAP) / per
            local bh = per > 2 and CheatPanel.SMALL_H or CheatPanel.BTN_H
            for i, a in ipairs(row.actions) do
                local col = (i - 1) % per
                local line = math.floor((i - 1) / per)
                L.buttons[#L.buttons + 1] = {
                    x = math.floor(x + col * (bw + CheatPanel.BTN_GAP)),
                    y = cy + line * (bh + CheatPanel.BTN_GAP),
                    w = math.floor(bw), h = bh, action = a, small = per > 2,
                }
            end
            local lines = math.ceil(#row.actions / per)
            cy = cy + lines * (bh + CheatPanel.BTN_GAP)
        end
    end
    return cy
end

function CheatPanel.layout(columns, sw, sh, open, hasStatus)
    local L = { open = open, buttons = {}, texts = {} }
    local top = topOffset()
    if not open then
        L.tab = { x = sw - CheatPanel.TAB_W - CheatPanel.MARGIN, y = top,
                  w = CheatPanel.TAB_W, h = CheatPanel.TAB_H }
        L.x, L.y, L.w, L.h = L.tab.x, L.tab.y, L.tab.w, L.tab.h
        return L
    end
    local used = {}
    for _, col in ipairs(columns or {}) do
        if #col > 0 then used[#used + 1] = col end
    end
    local nc = math.max(1, #used)
    local w = CheatPanel.PAD * 2 + nc * CheatPanel.COL_W + (nc - 1) * CheatPanel.COL_GAP
    local x = sw - w - CheatPanel.MARGIN
    local y = top
    L.title = { x = x, y = y, w = w, h = CheatPanel.TITLE_H + CheatPanel.PAD }
    local bodyY = y + CheatPanel.PAD + CheatPanel.TITLE_H
    local bottom = bodyY
    if #used == 0 then
        L.texts[#L.texts + 1] = { kind = "hint", text = I18n.t("cheat.hint_no_run"),
            x = x + CheatPanel.PAD, y = bodyY, w = CheatPanel.COL_W }
        local f = FontManager.getFont(CheatPanel.FONT)
        local _, lines = f:getWrap(I18n.t("cheat.hint_no_run"), CheatPanel.COL_W)
        bottom = bodyY + #lines * (f:getHeight() + 2)
    end
    for i, col in ipairs(used) do
        local cx = x + CheatPanel.PAD + (i - 1) * (CheatPanel.COL_W + CheatPanel.COL_GAP)
        bottom = math.max(bottom, layoutColumn(col, cx, bodyY, L))
    end
    if hasStatus then
        L.status = { x = x + CheatPanel.PAD, y = bottom + 2, w = w - CheatPanel.PAD * 2,
                     h = CheatPanel.STATUS_H }
        bottom = bottom + CheatPanel.STATUS_H + 2
    end
    L.x, L.y, L.w, L.h = x, y, w, bottom - y + CheatPanel.PAD
    return L
end

function CheatPanel.validate(L, sw, sh)
    local errs = {}
    local function inside(r, what)
        if r.x < 0 or r.y < 0 or r.x + r.w > sw + 0.5 or r.y + r.h > sh + 0.5 then
            errs[#errs + 1] = what .. " fora da tela"
        end
    end
    inside(L, "painel")
    for i, b in ipairs(L.buttons) do
        if b.x < L.x or b.y < L.y or b.x + b.w > L.x + L.w + 0.5 or b.y + b.h > L.y + L.h + 0.5 then
            errs[#errs + 1] = "botao " .. tostring(b.action.id) .. " vaza do painel"
        end
        for j = i + 1, #L.buttons do
            local o = L.buttons[j]
            if b.x < o.x + o.w and o.x < b.x + b.w and b.y < o.y + o.h and o.y < b.y + b.h then
                errs[#errs + 1] = "botoes " .. tostring(b.action.id) .. " e "
                    .. tostring(o.action.id) .. " se sobrepoem"
            end
        end
    end
    return errs
end

function CheatPanel.currentLayout()
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local cm = CM()
    local cols = Actions().sections(cm.currentState())
    return CheatPanel.layout(cols, sw, sh, cm.panelOpen, cm.statusText() ~= nil)
end

local function hit(r, mx, my)
    return r and mx >= r.x and mx <= r.x + r.w and my >= r.y and my <= r.y + r.h
end

local function drawButton(b, mx, my)
    local A = Actions()
    local a = b.action
    local avail = A.isAvailable(a)
    local on = a.on and a.on() or false
    local hover = avail and hit(b, mx, my)
    local fill = on and Theme.Colors.SUCCESS or (hover and Theme.Colors.UI_HIGHLIGHT
        or Theme.Colors.PRIMARY)
    Palette.set(fill, avail and 0.92 or 0.45)
    love.graphics.rectangle("fill", b.x, b.y, b.w, b.h, 3, 3)
    Palette.set(hover and Palette.AGED_GOLD_LIGHT or Palette.AGED_GOLD_DARK, avail and 1 or 0.5)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", b.x + 0.5, b.y + 0.5, b.w - 1, b.h - 1, 3, 3)
    local label = a.label()
    if b.small then
        Palette.set(Theme.Colors.TEXT_PRIMARY, avail and 1 or 0.45)
        TextFit.print(label, b.x + 2, b.y + math.floor((b.h - 8) / 2),
            { size = CheatPanel.FONT, minSize = CheatPanel.MIN_FONT, maxW = b.w - 4, align = "center" })
        return
    end
    Palette.set(Theme.Colors.TEXT_PRIMARY, avail and 1 or 0.45)
    TextFit.print(label, b.x + 4, b.y + 4,
        { size = CheatPanel.FONT, minSize = CheatPanel.MIN_FONT, maxW = b.w - 8, align = "center" })
    Palette.set(Theme.Colors.ACCENT, avail and 1 or 0.45)
    TextFit.print(A.keyLabel(a), b.x + 4, b.y + 15,
        { size = CheatPanel.FONT, minSize = CheatPanel.MIN_FONT, maxW = b.w - 8, align = "center" })
end

function CheatPanel.draw()
    local L = CheatPanel.currentLayout()
    last = L
    local mx, my = love.mouse.getPosition()
    local font = FontManager.getFont(CheatPanel.FONT)
    if not L.open then
        local t = L.tab
        Palette.set(Theme.Colors.UI_BACKGROUND)
        love.graphics.rectangle("fill", t.x, t.y, t.w, t.h, 4, 4)
        Palette.set(hit(t, mx, my) and Palette.AGED_GOLD_LIGHT or Palette.AGED_GOLD)
        love.graphics.rectangle("line", t.x + 0.5, t.y + 0.5, t.w - 1, t.h - 1, 4, 4)
        Palette.set(Theme.Colors.TEXT_PRIMARY)
        TextFit.print(I18n.t("cheat.tab", { k = "F1" }), t.x + 6, t.y + 7,
            { size = CheatPanel.FONT, minSize = CheatPanel.MIN_FONT, maxW = t.w - 12, align = "center" })
        love.graphics.setColor(1, 1, 1, 1)
        return
    end
    Panel9.draw("panel_inner", L.x, L.y, L.w, L.h, { fill = Theme.Colors.UI_BACKGROUND })
    love.graphics.setFont(font)
    Palette.set(Theme.Colors.TEXT_PRIMARY)
    TextFit.print(I18n.t("cheat.title"), L.x + CheatPanel.PAD, L.y + CheatPanel.PAD,
        { size = CheatPanel.FONT, minSize = CheatPanel.MIN_FONT, maxW = L.w - CheatPanel.PAD * 2 - CheatPanel.HIDE_W })
    Palette.set(Theme.Colors.ACCENT)
    TextFit.print(I18n.t("cheat.hide", { k = "F1" }), L.x + L.w - CheatPanel.PAD - CheatPanel.HIDE_W,
        L.y + CheatPanel.PAD, { size = CheatPanel.FONT, minSize = CheatPanel.MIN_FONT,
            maxW = CheatPanel.HIDE_W, align = "right" })
    for _, tx in ipairs(L.texts) do
        if tx.kind == "section" then
            Palette.set(Palette.AGED_GOLD_LIGHT)
        elseif tx.kind == "header" then
            Palette.set(Theme.Colors.TEXT_SECONDARY)
        else
            Palette.set(Theme.Colors.TEXT_SECONDARY)
        end
        if tx.kind == "hint" then
            love.graphics.setFont(font)
            love.graphics.printf(tx.text, tx.x, tx.y, tx.w, "left")
        else
            TextFit.print(tx.text, tx.x, tx.y, { size = CheatPanel.FONT,
                minSize = CheatPanel.MIN_FONT, maxW = tx.w })
        end
    end
    for _, b in ipairs(L.buttons) do drawButton(b, mx, my) end
    local st = CM().statusText()
    if st and L.status then
        Palette.set(Palette.TOAST_INFO)
        TextFit.print(st, L.status.x, L.status.y + 4,
            { size = CheatPanel.FONT, minSize = CheatPanel.MIN_FONT, maxW = L.status.w })
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function CheatPanel.mousepressed(x, y, button)
    local L = last or CheatPanel.currentLayout()
    if not hit(L, x, y) then return false end
    local cm = CM()
    if not L.open then
        if button == 1 then cm.panelOpen = true end
        return true
    end
    if button ~= 1 then return true end
    if hit(L.title, x, y) and y <= L.y + CheatPanel.PAD + CheatPanel.TITLE_H then
        cm.panelOpen = false
        return true
    end
    for _, b in ipairs(L.buttons) do
        if hit(b, x, y) then
            local A = Actions()
            if A.isAvailable(b.action) then
                require("src.systems.Sfx").play("buttonClick")
                b.action.run()
            end
            return true
        end
    end
    return true
end

function CheatPanel.lastLayout() return last end

return CheatPanel
