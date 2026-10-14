local AchievementsScreen = {}
AchievementsScreen.__index = AchievementsScreen

local FontManager       = require("src.ui.FontManager")
local I18n              = require("src.i18n.I18n")
local Palette           = require("src.ui.Palette")
local Panel9            = require("src.ui.Panel9")
local HintBar           = require("src.ui.HintBar")
local TextFit           = require("src.ui.TextFit")
local AchievementIcons  = require("src.ui.AchievementIcons")
local AchievementSystem = require("src.systems.AchievementSystem")
local Sfx               = require("src.systems.Sfx")

local HEADER_H = 74
local FOOTER_H = 30
local HINT_H = 36
local PAD = 36
local GAP = 18
local TIER_HEAD_H = 20
local CELL_MAX, CELL_MIN = 62, 28

function AchievementsScreen:new()
    local instance = setmetatable({}, AchievementsScreen)
    instance.visible = false
    instance.onClose = nil
    instance.entries = {}
    instance.selected = 1
    instance.hovered = nil
    instance.t = 0
    return instance
end

function AchievementsScreen:_refresh()
    self.entries = AchievementSystem.all()
    self._builtLocale = I18n.getLocale()
end

function AchievementsScreen:_defaultSelection()
    local best, bestF = nil, -1
    for i, e in ipairs(self.entries) do
        if not e.unlocked then
            local f = e.progress and (e.progress.cur / math.max(1, e.progress.target)) or 0
            if f > bestF then best, bestF = i, f end
        end
    end
    return best or 1
end

function AchievementsScreen:show(onClose)
    self.visible = true
    self.onClose = onClose
    self:_refresh()
    self.selected = self:_defaultSelection()
    self.hovered = nil
    self.t = 0
    Sfx.play("menuOpen")
end

function AchievementsScreen:hide()
    self.visible = false
    local cb = self.onClose
    self.onClose = nil
    Sfx.play("menuClose")
    if cb then cb() end
end

function AchievementsScreen:isVisible() return self.visible end
function AchievementsScreen:update(dt)
    self.t = self.t + dt
    if not self.visible then return end
    local mx, my = love.mouse.getPosition()
    if mx ~= self._mx or my ~= self._my then
        self._mx, self._my = mx, my
        local i = self:_cellAt(mx, my)
        if i and i ~= self.hovered then Sfx.play("hoverCard") end
        self.hovered = i
    end
end
function AchievementsScreen:resize() end

function AchievementsScreen.panelRect(sw, sh)
    sw = sw or love.graphics.getWidth()
    sh = sh or love.graphics.getHeight()
    local pw = math.min(1040, math.floor(sw - 32))
    local ph = math.min(720, math.floor(sh - HINT_H - 12))
    return math.floor((sw - pw) / 2), math.floor((sh - HINT_H - ph) / 2) + 4, pw, ph
end

local function tierGroups(entries)
    local groups = {}
    for _, tier in ipairs(AchievementSystem.TIERS) do
        local g = { tier = tier, idx = {} }
        for i, e in ipairs(entries) do
            if e.tier == tier then table.insert(g.idx, i) end
        end
        if #g.idx > 0 then table.insert(groups, g) end
    end
    return groups
end

local function gridHeight(groups, w, cell, gap)
    local cols = math.max(1, math.floor((w + gap) / (cell + gap)))
    local h = 0
    for _, g in ipairs(groups) do
        h = h + TIER_HEAD_H + math.ceil(#g.idx / cols) * (cell + gap) + 6
    end
    return h, cols
end

function AchievementsScreen.layout(entries, sw, sh)
    local px, py, pw, ph = AchievementsScreen.panelRect(sw, sh)
    local L = { panel = { px, py, pw, ph } }
    local closeS = 28
    L.close = { px + pw - PAD - closeS, py + 28, closeS, closeS }
    L.header = { px + PAD, py + 30, pw - PAD * 2 - closeS - 14, HEADER_H - 30 }
    local bodyY = py + HEADER_H + 4
    local bodyH = ph - HEADER_H - 4 - FOOTER_H
    local innerX, innerW = px + PAD, pw - PAD * 2

    L.wide = pw >= 760
    if L.wide then
        local dW = math.max(250, math.floor(innerW * 0.34))
        L.grid = { innerX, bodyY, innerW - dW - GAP, bodyH }
        L.detail = { innerX + innerW - dW, bodyY, dW, bodyH }
    else
        local dH = math.min(170, math.floor(bodyH * 0.40))
        L.grid = { innerX, bodyY, innerW, bodyH - dH - 10 }
        L.detail = { innerX, bodyY + bodyH - dH, innerW, dH }
    end

    local groups = tierGroups(entries)
    local gx, gy, gw, gh = L.grid[1], L.grid[2], L.grid[3], L.grid[4]
    local cell, gap, cols = CELL_MAX, 10, 1
    if gridHeight(groups, gw, 64, 10) <= gh then cell = 64 end
    while cell > CELL_MIN and cell ~= 64 do
        gap = math.max(4, math.floor(cell / 6))
        local h
        h, cols = gridHeight(groups, gw, cell, gap)
        if h <= gh then break end
        cell = cell - 2
    end
    gap = math.max(4, math.floor(cell / 6))
    local _
    _, cols = gridHeight(groups, gw, cell, gap)
    L.cell, L.gap, L.cols = cell, gap, cols

    L.cells, L.tierHeads = {}, {}
    local y = gy
    for _, g in ipairs(groups) do
        table.insert(L.tierHeads, { tier = g.tier, x = gx, y = y, w = gw, idx = g.idx })
        y = y + TIER_HEAD_H
        local rows = math.ceil(#g.idx / cols)
        local per = math.ceil(#g.idx / rows)
        for k, i in ipairs(g.idx) do
            local c = (k - 1) % per
            local r = math.floor((k - 1) / per)
            L.cells[i] = { gx + c * (cell + gap), y + r * (cell + gap), cell, cell }
        end
        y = y + math.ceil(#g.idx / cols) * (cell + gap) + 6
    end
    L.gridBottom = y
    return L
end

function AchievementsScreen:_layout()
    return AchievementsScreen.layout(self.entries,
        love.graphics.getWidth(), love.graphics.getHeight())
end

local function hit(r, x, y)
    return r and x >= r[1] and x < r[1] + r[3] and y >= r[2] and y < r[2] + r[4]
end

function AchievementsScreen:_cellAt(x, y)
    local L = self:_layout()
    for i, r in pairs(L.cells) do
        if hit(r, x, y) then return i end
    end
    return nil
end

function AchievementsScreen.neighbor(L, from, dir)
    local a = L.cells[from]
    if not a then return nil end
    local ax, ay = a[1] + a[3] / 2, a[2] + a[4] / 2
    local best, bestD
    for i, r in pairs(L.cells) do
        if i ~= from then
            local dx, dy = r[1] + r[3] / 2 - ax, r[2] + r[4] / 2 - ay
            local along = dx * dir[1] + dy * dir[2]
            if along > 1 then
                local side = math.abs(dx * dir[2]) + math.abs(dy * dir[1])
                local d = along + side * 2
                if not bestD or d < bestD then best, bestD = i, d end
            end
        end
    end
    return best
end

function AchievementsScreen:keypressed(key)
    if not self.visible then return false end
    if key == "escape" then self:hide(); return true end
    local n = #self.entries
    if n == 0 then return true end
    local dir = ({ left = { -1, 0 }, right = { 1, 0 }, up = { 0, -1 }, down = { 0, 1 },
                   a = { -1, 0 }, d = { 1, 0 }, w = { 0, -1 }, s = { 0, 1 } })[key]
    if dir then
        local nxt = AchievementsScreen.neighbor(self:_layout(), self.hovered or self.selected, dir)
        if nxt then
            self.hovered = nil
            self.selected = nxt
            Sfx.play("hoverCard")
        end
    end
    return true
end

function AchievementsScreen:mousepressed(x, y, button)
    return self.visible
end

function AchievementsScreen:mousereleased(x, y, button)
    if not self.visible then return false end
    local px, py, pw, ph = AchievementsScreen.panelRect()
    if x < px or x > px + pw or y < py or y > py + ph
        or (button == 1 and hit(self:_layout().close, x, y)) then
        self:hide()
        return true
    end
    local i = self:_cellAt(x, y)
    if i then self.selected = i end
    return true
end

local function setC(c, a) love.graphics.setColor(c[1], c[2], c[3], a or 1) end

local function fmtNum(n)
    local s = tostring(math.floor(n))
    local out = s:reverse():gsub("(%d%d%d)", "%1."):reverse()
    return (out:gsub("^%.", ""))
end

local function drawBar(x, y, w, h, frac)
    setC(Palette.INK, 0.55)
    love.graphics.rectangle("fill", x, y, w, h, 2, 2)
    if frac > 0 then
        setC(Palette.AGED_GOLD)
        love.graphics.rectangle("fill", x + 1, y + 1, math.max(1, (w - 2) * math.min(1, frac)), h - 2, 2, 2)
    end
    setC(Palette.PARCHMENT_DARK)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h, 2, 2)
end

local function drawSecretMark(cx, cy, size)
    local f = FontManager.getFont(math.max(8, math.floor(size * 0.42)))
    love.graphics.setFont(f)
    local q = "?"
    setC(Palette.INK, 0.8)
    love.graphics.print(q, math.floor(cx - f:getWidth(q) / 2) + 2, math.floor(cy - f:getHeight() / 2) + 2)
    setC(Palette.PARCHMENT_LIGHT, 0.95)
    love.graphics.print(q, math.floor(cx - f:getWidth(q) / 2), math.floor(cy - f:getHeight() / 2))
end

function AchievementsScreen:_drawCell(i, r, focus)
    local e = self.entries[i]
    local x, y, s = r[1], r[2], r[3]
    local cx, cy = x + s / 2, y + s / 2
    if focus then
        local k = 0.5 + 0.5 * math.sin(self.t * 4)
        setC(Palette.AGED_GOLD_LIGHT, 0.55 + 0.35 * k)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x - 3, y - 3, s + 6, s + 6, 4, 4)
    end
    AchievementIcons.draw(e.id, not e.unlocked, cx, cy, s, 1)
    if e.secret then drawSecretMark(cx, cy, s) end
    if not e.unlocked and e.progress and e.progress.cur > 0 then
        drawBar(x + 4, y + s - 4, s - 8, 4, e.progress.cur / math.max(1, e.progress.target))
    end
end

local DESC_LH = 1.45

local function statusText(e)
    if e.unlocked and e.unlockedAt then
        local fmt = I18n.t("achievements.date_format", nil, "%d/%m/%Y")
        return I18n.t("achievements.unlocked_on", { date = os.date(fmt, e.unlockedAt) },
            "Desbloqueada")
    elseif e.unlocked then
        return I18n.t("achievements.unlocked", nil, "Desbloqueada")
    end
    return I18n.t("achievements.locked", nil, "Bloqueada")
end

local function detailText(e, tx, ty, tw, dry)
    local y0 = ty
    if not dry then
        setC(e.unlocked and Palette.INK or Palette.PARCHMENT_DARK)
        TextFit.print(e.name, tx, ty, { size = 14, maxW = tw, minSize = 9 })
    end
    ty = ty + 24
    local tierLabel = I18n.t("achievements.tier_" .. e.tier, nil, e.tier)
    if e.hidden then
        tierLabel = tierLabel .. "  |  " .. I18n.t("achievements.secret_tag", nil, "SECRETA")
    end
    if not dry then
        setC(Palette.RUST)
        TextFit.print(tierLabel, tx, ty, { size = 8, maxW = tw })
    end
    ty = ty + 20
    local df = FontManager.getFont(10)
    local _, lines = df:getWrap(e.desc, tw)
    local lh = math.floor(df:getHeight() * DESC_LH)
    if not dry then
        love.graphics.setFont(df)
        setC(Palette.INK, 0.9)
        for k, line in ipairs(lines) do
            love.graphics.print(line, tx, ty + (k - 1) * lh)
        end
    end
    ty = ty + #lines * lh + 10
    if e.progress then
        local frac = e.progress.cur / math.max(1, e.progress.target)
        if not dry then
            drawBar(tx, ty, tw, 10, frac)
            setC(Palette.PARCHMENT_DARK)
            TextFit.print(I18n.t("achievements.progress",
                { cur = fmtNum(e.progress.cur), target = fmtNum(e.progress.target) },
                fmtNum(e.progress.cur) .. " / " .. fmtNum(e.progress.target)),
                tx, ty + 15, { size = 8, maxW = tw })
        end
        ty = ty + 32
    end
    if not dry then
        setC(e.unlocked and Palette.MOSS or Palette.PARCHMENT_DARK)
        TextFit.print(statusText(e), tx, ty, { size = 8, maxW = tw })
    end
    ty = ty + 12
    return ty - y0
end

function AchievementsScreen:_drawDetail(L, e)
    local x, y, w, h = L.detail[1], L.detail[2], L.detail[3], L.detail[4]
    setC(Palette.INK, 0.10)
    love.graphics.rectangle("fill", x, y, w, h, 6, 6)
    setC(Palette.PARCHMENT_DARK, 0.8)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h, 6, 6)
    if not e then return end

    local pad = 16
    love.graphics.setScissor(x, y, w, h)
    if L.wide then
        local big = (math.min(w - pad * 2, h * 0.42) >= 128) and 128 or 64
        local tw = w - pad * 2
        local textH = detailText(e, 0, 0, tw, true)
        local total = big + 18 + textH
        local top = y + math.max(pad, math.floor((h - total) * 0.4))
        local cx, cy = x + w / 2, top + big / 2
        if e.unlocked then
            setC(Palette.AGED_GOLD, 0.25)
            love.graphics.circle("fill", cx, cy, big * 0.56)
        end
        AchievementIcons.draw(e.id, not e.unlocked, cx, cy, big, 1)
        if e.secret then drawSecretMark(cx, cy, big) end
        detailText(e, x + pad, top + big + 18, tw, false)
    else
        local big = 64
        local cx, cy = x + pad + big / 2, y + math.floor(h / 2)
        AchievementIcons.draw(e.id, not e.unlocked, cx, cy, big, 1)
        if e.secret then drawSecretMark(cx, cy, big) end
        local tx = x + pad * 2 + big
        local tw = w - (tx - x) - pad
        local textH = detailText(e, tx, 0, tw, true)
        detailText(e, tx, y + math.max(pad - 4, math.floor((h - textH) / 2)), tw, false)
    end
    love.graphics.setScissor()
end

function AchievementsScreen:draw()
    if not self.visible then return end
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    if self._builtLocale ~= I18n.getLocale() then self:_refresh() end

    love.graphics.push("all")
    setC(Palette.INK, 0.82)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    local L = self:_layout()
    local px, py, pw, ph = L.panel[1], L.panel[2], L.panel[3], L.panel[4]
    Panel9.draw("panel_main", px, py, pw, ph)

    local hx, hy, hw = L.header[1], L.header[2], L.header[3]
    local unlocked, total = AchievementSystem.countUnlocked()
    local counter = I18n.t("achievements.total", { n = unlocked, total = total },
        unlocked .. " / " .. total)
    local cf = FontManager.getFont(12)
    local cw = math.min(cf:getWidth(counter), math.floor(hw * 0.4))
    local barW = math.min(200, math.floor(hw * 0.28))
    setC(Palette.INK)
    TextFit.print(I18n.t("menu.achievements", nil, "CONQUISTAS"), hx, hy + 2,
        { size = 18, maxW = hw - barW - cw - 40, minSize = 12 })
    drawBar(hx + hw - barW, hy + 8, barW, 10, unlocked / math.max(1, total))
    setC(Palette.RUST)
    TextFit.print(counter, hx + hw - barW - 12 - cw, hy + 6, { size = 12, maxW = cw })
    setC(Palette.PARCHMENT_DARK, 0.7)
    love.graphics.setLineWidth(1)
    love.graphics.line(hx, py + HEADER_H - 2, hx + hw, py + HEADER_H - 2)

    for _, th in ipairs(L.tierHeads) do
        local n = 0
        for _, i in ipairs(th.idx) do if self.entries[i].unlocked then n = n + 1 end end
        local label = I18n.t("achievements.tier_" .. th.tier, nil, th.tier)
            .. "   " .. n .. "/" .. #th.idx
        setC(Palette.RUST)
        TextFit.print(label, th.x, th.y + 4, { size = 9, maxW = th.w })
    end
    local focus = self.hovered or self.selected
    for i, r in pairs(L.cells) do
        self:_drawCell(i, r, i == focus)
    end

    self:_drawDetail(L, self.entries[focus])

    do
        local c = L.close
        local mx, my = love.mouse.getPosition()
        local hot = hit(c, mx, my)
        setC(hot and Palette.BLOOD or Palette.PANEL_FILL)
        love.graphics.rectangle("fill", c[1], c[2], c[3], c[4], 4, 4)
        setC(Palette.AGED_GOLD)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", c[1], c[2], c[3], c[4], 4, 4)
        local xf = FontManager.getFont(14)
        love.graphics.setFont(xf)
        setC(Palette.PARCHMENT_LIGHT)
        love.graphics.print("X", math.floor(c[1] + (c[3] - xf:getWidth("X")) / 2),
            math.floor(c[2] + (c[4] - xf:getHeight()) / 2))
        if hot then require("src.ui.CursorManager").request("hand") end
    end

    HintBar.draw(I18n.t("achievements.hint", nil, "ESC fecha"))
    love.graphics.pop()
end

return AchievementsScreen
