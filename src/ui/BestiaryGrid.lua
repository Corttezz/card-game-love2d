local FontManager = require("src.ui.FontManager")
local Palette = require("src.ui.Palette")
local I18n = require("src.i18n.I18n")
local TextCase = require("src.i18n.TextCase")
local TextFit = require("src.ui.TextFit")
local Layout = require("src.ui.BestiaryLayout")
local Sprites = require("src.ui.BestiarySprites")
local Card = require("src.ui.BestiaryCard")
local Bestiary = require("src.systems.Bestiary")
local Sfx = require("src.systems.Sfx")

local Grid = {}
Grid.__index = Grid

Grid.TOP = 120
Grid.BOTTOM_PAD = 40

function Grid.new()
    local self = setmetatable({}, Grid)
    self.scrollY = 0
    self.time = 0
    self.k = 1
    self.entries = {}
    self.openIdx = nil
    self.openAnim = 0
    return self
end

function Grid:refresh()
    self.entries = Bestiary.entries()
    self.actCounts = {}
    for _, e in ipairs(self.entries) do
        self.actCounts[e.act] = (self.actCounts[e.act] or 0) + 1
    end
    for a = 1, #self.actCounts do self.actCounts[a] = self.actCounts[a] or 0 end
    self.layoutKey = nil
end

function Grid:show()
    self:refresh()
    self.scrollY = 0
    self.openIdx = nil
    self.openAnim = 0
    self.hoverIdx = nil
    for _, e in ipairs(self.entries) do Sprites.prefetch(e.id, false) end
    for _, e in ipairs(self.entries) do
        if Bestiary.isSeen(e.id) then Sprites.prefetch(e.id, true) end
    end
end

function Grid:resize()
    self.layoutKey = nil
    self.cardKey = nil
end

function Grid:layout()
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local key = sw .. "x" .. sh .. "@" .. self.k
    if self.layoutKey ~= key then
        self.G = Layout.grid(sw, sh, Grid.TOP, sh - Grid.BOTTOM_PAD, self.k, self.actCounts or {})
        self.layoutKey = key
    end
    self.scrollY = math.max(0, math.min(self.G.maxScroll, self.scrollY))
    return self.G
end

function Grid:cellScreen(i)
    local G = self:layout()
    local c = G.cells[i]
    if not c then return nil end
    return c.x, G.top + c.y - self.scrollY, c.w, c.h
end

function Grid:isOpen() return self.openIdx ~= nil end

function Grid:openEntry() return self.openIdx and self.entries[self.openIdx] end

function Grid:cardLayout()
    local e = self:openEntry()
    if not e then return nil end
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local key = table.concat({ e.id, sw, sh, self.k, I18n.current or "", tostring(Bestiary.isDefeated(e.id)) }, "|")
    if self.cardKey ~= key then
        self.C, self.texts = Card.layoutFor(e, sw, sh, self.k)
        self.cardKey = key
    end
    return self.C, self.texts
end

local function inView(G, y, h)
    return y + h > G.top and y < G.bottom
end

function Grid:hitCell(mx, my)
    local G = self:layout()
    if my < G.top or my > G.bottom then return nil end
    for i, c in ipairs(G.cells) do
        local y = G.top + c.y - self.scrollY
        if mx >= c.x and mx <= c.x + c.w and my >= y and my <= y + c.h then return i end
    end
end

function Grid:ensureVisible(i)
    local G = self:layout()
    local c = G.cells[i]
    if not c then return end
    local y = c.y - self.scrollY
    local act = G.acts[c.act]
    if y < 0 then
        local top = (act and c.y - act.header.y <= Layout.HEADER_H + 1) and act.header.y or c.y
        self.scrollY = math.max(0, top)
    elseif y + c.h > G.viewH then
        self.scrollY = math.min(G.maxScroll, c.y + c.h - G.viewH)
    end
end

function Grid:open(i)
    local e = self.entries[i]
    if not e or not Bestiary.isSeen(e.id) then return false end
    self.openIdx = i
    self.openAnim = 0
    self.cardKey = nil
    Bestiary.clearNew(e.id)
    Sprites.want(e.id, true)
    return true
end

function Grid:close()
    self.openIdx = nil
    self.cardKey = nil
end

function Grid:step(delta)
    if not self.openIdx then return false end
    local n = #self.entries
    local i = self.openIdx
    for _ = 1, n do
        i = ((i - 1 + delta) % n) + 1
        if Bestiary.isSeen(self.entries[i].id) then break end
    end
    if i == self.openIdx then return false end
    self.openIdx = i
    self.openAnim = 0.6
    self.cardKey = nil
    Bestiary.clearNew(self.entries[i].id)
    self:ensureVisible(i)
    return true
end

function Grid:seenCount()
    local n = 0
    for _, e in ipairs(self.entries) do if Bestiary.isSeen(e.id) then n = n + 1 end end
    return n, #self.entries
end

function Grid:update(dt, mx, my)
    self.time = self.time + (dt or 0)
    Sprites.pump()
    if self.openIdx then
        self.openAnim = math.min(1, self.openAnim + (dt or 0) * 6)
        self.hoverIdx = nil
        return
    end
    self.openAnim = 0
    local prev = self.hoverIdx
    self.hoverIdx = self:hitCell(mx, my)
    if self.hoverIdx and self.hoverIdx ~= prev then
        local NavCursor = require("src.ui.NavCursor")
        if NavCursor.isActive() then self:ensureVisible(self.hoverIdx) end
        local e = self.entries[self.hoverIdx]
        Sfx.playWithVariation("hoverCard", 0.95, 0.18)
        if e and Bestiary.isNew(e.id) then Bestiary.clearNew(e.id) end
    elseif self.hoverIdx then
        local e = self.entries[self.hoverIdx]
        if e and Bestiary.isNew(e.id) then Bestiary.clearNew(e.id) end
    end
end

function Grid:wheelmoved(_, y)
    if self.openIdx then return end
    local G = self:layout()
    self.scrollY = math.max(0, math.min(G.maxScroll, self.scrollY - y * 48))
end

function Grid:scrollToAct(a)
    local G = self:layout()
    local act = G.acts[a]
    if act then self.scrollY = math.max(0, math.min(G.maxScroll, act.header.y)) end
end

function Grid:keypressed(key)
    if self.openIdx then
        if key == "escape" or key == "backspace" or key == "space" or key == "return" then
            Sfx.play("menuClose")
            self:close()
        elseif key == "left" or key == "a" then
            if self:step(-1) then Sfx.play("collectionFlip") end
        elseif key == "right" or key == "d" then
            if self:step(1) then Sfx.play("collectionFlip") end
        end
        return true
    end
    local G = self:layout()
    if key == "up" or key == "pageup" then
        self.scrollY = math.max(0, self.scrollY - (key == "up" and 100 or G.viewH))
        return true
    elseif key == "down" or key == "pagedown" then
        self.scrollY = math.min(G.maxScroll, self.scrollY + (key == "down" and 100 or G.viewH))
        return true
    end
    return false
end

function Grid:mousepressed(x, y, button)
    if button ~= 1 then return false end
    if self.openIdx then
        self.pressedCard = true
        return true
    end
    local G = self:layout()
    for a, ch in ipairs(G.chips) do
        if Card.hit(ch, x, y) then
            Sfx.play("buttonClick")
            self:scrollToAct(a)
            return true
        end
    end
    self.pressedIdx = self:hitCell(x, y)
    return self.pressedIdx ~= nil
end

function Grid:mousereleased(x, y, button)
    if button ~= 1 then return false end
    if self.openIdx then
        if not self.pressedCard then return true end
        self.pressedCard = nil
        local C = self:cardLayout()
        if Card.hit(C.close, x, y) then
            Sfx.play("menuClose")
            self:close()
        elseif Card.hit(C.prev, x, y) then
            if self:step(-1) then Sfx.play("collectionFlip") end
        elseif Card.hit(C.next, x, y) then
            if self:step(1) then Sfx.play("collectionFlip") end
        elseif not Card.hit(C.page, x, y) then
            Sfx.play("menuClose")
            self:close()
        end
        return true
    end
    local i = self:hitCell(x, y)
    local pressed = self.pressedIdx
    self.pressedIdx = nil
    if i and i == pressed then
        if self:open(i) then
            Sfx.play("collectionFlip")
        else
            Sfx.play("buttonClick", { pitch = 0.7 })
        end
        return true
    end
    return false
end

local function rgba(c, a)
    love.graphics.setColor(c[1], c[2], c[3], (a or 1) * (c[4] or 1))
end

local screenScissor = Layout.scissor

function Grid:currentAct()
    local G = self:layout()
    local best = 1
    for a, act in ipairs(G.acts) do
        if act.header.y <= self.scrollY + 40 then best = a end
    end
    return best
end

local NUMERALS = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII" }

function Grid:chipStyle()
    local G = self:layout()
    local key = (self.layoutKey or "") .. (I18n.current or "")
    if self._chipKey == key then return self._chipSize, self._chipNumW end
    local f = FontManager.getFont(10)
    local numW = 0
    for a = 1, #G.chips do numW = math.max(numW, f:getWidth(NUMERALS[a] or tostring(a))) end
    local size = 10
    for a, ch in ipairs(G.chips) do
        local _, _, sz = TextFit.fit(TextCase.upper(Card.biomeName(a)), 10, ch.w - numW - 28, 6)
        size = math.min(size, sz)
    end
    self._chipKey, self._chipSize, self._chipNumW = key, size, numW
    return size, numW
end

function Grid:drawChips()
    local G = self:layout()
    local NavCursor = require("src.ui.NavCursor")
    local cur = self:currentAct()
    local mx, my = love.mouse.getPosition()
    local size, numW = self:chipStyle()
    for a, ch in ipairs(G.chips) do
        local active = a == cur
        local hot = Card.hit(ch, mx, my) and not self.openIdx
        if active then rgba(Palette.AGED_GOLD) else rgba(Palette.INK, hot and 0.85 or 0.6) end
        love.graphics.rectangle("fill", ch.x, ch.y, ch.w, ch.h, 4, 4)
        rgba(hot and Palette.AGED_GOLD_LIGHT or Palette.PARCHMENT_DARK)
        love.graphics.rectangle("line", ch.x, ch.y, ch.w, ch.h, 4, 4)
        local label = TextCase.upper(Card.biomeName(a))
        local numeral = NUMERALS[a] or tostring(a)
        local f = FontManager.getFont(10)
        love.graphics.setFont(f)
        rgba(active and Palette.INK or Palette.AGED_GOLD_LIGHT)
        love.graphics.print(numeral, ch.x + 8, ch.y + math.floor((ch.h - f:getHeight()) / 2) + 1)
        local lf = FontManager.getFont(size)
        rgba(active and Palette.INK or Palette.PARCHMENT_LIGHT)
        TextFit.print(label, ch.x + 8 + numW + 10, ch.y + math.floor((ch.h - lf:getHeight()) / 2) + 1,
            { size = size, maxW = ch.w - numW - 28, minSize = 6 })
        if self:actHasNew(a) then
            require("src.ui.DiscoveryMark").drawAlert(ch.x + ch.w - 4, ch.y - 2)
        end
        NavCursor.target("bstchip:" .. a, ch.x, ch.y, ch.w, ch.h)
    end
end

function Grid:actHasNew(a)
    for _, e in ipairs(self.entries) do
        if e.act == a and Bestiary.isNew(e.id) then return true end
    end
    return false
end

function Grid:drawCell(i, c, x, y, hovered)
    local G = self.G
    local e = self.entries[i]
    local seen = Bestiary.isSeen(e.id)
    local fresh = seen and Bestiary.isNew(e.id)
    local tierCol = Card.TIER_COLOR[e.tier] or Palette.PARCHMENT_LIGHT
    local tierInk = Card.TIER_INK[e.tier] or Palette.PARCHMENT_DARK
    rgba(Palette.INK, 0.55)
    love.graphics.rectangle("fill", x + 3, y + 4, c.w, c.h)
    rgba(Palette.lerp(Palette.INK, tierInk, seen and 0.22 or 0.08), seen and 0.92 or 0.86)
    love.graphics.rectangle("fill", x, y, c.w, c.h)
    local groundY = y + Layout.CELL_PAD + G.spriteH - 6
    rgba(Palette.lerp(Palette.INK, Palette.PARCHMENT_DARK, 0.18), 1)
    love.graphics.rectangle("fill", x + 2, groundY, c.w - 4, y + c.h - Layout.NAME_H - groundY)
    if seen then
        Sprites.want(e.id, true)
    else
        Sprites.want(e.id, false)
    end
    Card.drawGround(x + c.w / 2, groundY + 2, math.floor(Layout.REF_W * G.spriteS * 0.6), seen and 1 or 0.6)
    local sx0, sy0, sw0, sh0 = love.graphics.getScissor()
    local vy0 = math.max(y + 2, G.top)
    local vy1 = math.min(y + c.h - Layout.NAME_H, G.bottom)
    if vy1 > vy0 then
        screenScissor(x + 2, vy0, c.w - 4, vy1 - vy0)
        Card.drawSprite(e.id, x + c.w / 2, groundY + 2, G.spriteS, self.time, 1, not seen)
        if sx0 then love.graphics.setScissor(sx0, sy0, sw0, sh0) else love.graphics.setScissor() end
    end
    local ny = y + c.h - Layout.NAME_H
    rgba(Palette.INK, 0.9)
    love.graphics.rectangle("fill", x + 1, ny, c.w - 2, Layout.NAME_H - 1)
    rgba(seen and Palette.PARCHMENT_LIGHT or Palette.PARCHMENT_DARK)
    local name = seen and Card.name(e.id) or I18n.t("bestiary.ui.unknown", nil, "???")
    local f = FontManager.getFont(8)
    TextFit.print(name, x + 4, ny + math.floor((Layout.NAME_H - f:getHeight()) / 2),
        { size = 8, maxW = c.w - 8, align = "center", minSize = 6 })
    local tl = TextCase.upper(Card.tierLabel(e.tier))
    local tf = FontManager.getFont(8)
    local tw = math.min(c.w - 8, tf:getWidth(tl) + 10)
    rgba(Palette.INK, 0.92)
    love.graphics.rectangle("fill", x + 4, y + 4, tw, tf:getHeight() + 6)
    rgba(tierInk, 1)
    love.graphics.rectangle("fill", x + 4, y + 4, 2, tf:getHeight() + 6)
    rgba(tierCol, seen and 1 or 0.6)
    TextFit.print(tl, x + 8, y + 7, { size = 8, maxW = tw - 6, minSize = 6 })
    if e.tier == "boss" or e.tier == "miniboss" then
        rgba(tierCol, seen and 0.9 or 0.4)
        love.graphics.rectangle("line", x + 2.5, y + 2.5, c.w - 5, c.h - 5)
    end
    if hovered then
        rgba(Palette.AGED_GOLD_LIGHT)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x + 1, y + 1, c.w - 2, c.h - 2)
        love.graphics.setLineWidth(1)
    else
        rgba(seen and Palette.AGED_GOLD_DARK or Palette.PARCHMENT_DARK, seen and 1 or 0.6)
        love.graphics.rectangle("line", x + 0.5, y + 0.5, c.w - 1, c.h - 1)
    end
    if fresh then
        require("src.ui.DiscoveryMark").drawAlert(x + c.w - 4, y + 4, 9)
    end
    if hovered then
        require("src.ui.CursorManager").request(seen and "hand" or "arrow")
    end
end

function Grid:drawHeaders()
    local G = self.G
    for a, act in ipairs(G.acts) do
        local y = G.top + act.header.y - self.scrollY
        if inView(G, y, act.header.h) then
            local label = TextCase.upper(Card.actLabel(a))
            local f = FontManager.getFont(12)
            rgba(Palette.AGED_GOLD_LIGHT)
            local w = TextFit.print(label, act.header.x, y + 6, { size = 12, maxW = act.header.w * 0.7, minSize = 8 })
            local seen, total = 0, 0
            for _, e in ipairs(self.entries) do
                if e.act == a then
                    total = total + 1
                    if Bestiary.isSeen(e.id) then seen = seen + 1 end
                end
            end
            local cnt = seen .. "/" .. total
            local cf = FontManager.getFont(10)
            love.graphics.setFont(cf)
            local cw = cf:getWidth(cnt)
            rgba(seen == total and Palette.AGED_GOLD_LIGHT or Palette.PARCHMENT)
            love.graphics.print(cnt, act.header.x + act.header.w - cw, y + 8)
            local rx = act.header.x + w + 12
            local rw = act.header.x + act.header.w - cw - 12 - rx
            if rw > 0 then
                rgba(Palette.AGED_GOLD_DARK, 0.9)
                love.graphics.rectangle("fill", rx, y + 6 + math.floor(f:getHeight() / 2), rw, 1)
                rgba(Palette.AGED_GOLD, 0.5)
                love.graphics.rectangle("fill", rx, y + 8 + math.floor(f:getHeight() / 2), math.floor(rw * 0.3), 1)
            end
        end
    end
end

function Grid:draw()
    self.k = Layout.physScale()
    local G = self:layout()
    local width = love.graphics.getWidth()
    self:drawChips()
    screenScissor(0, G.top, width, G.viewH)
    self:drawHeaders()
    local NavCursor = require("src.ui.NavCursor")
    for i, c in ipairs(G.cells) do
        local y = G.top + c.y - self.scrollY
        if inView(G, y, c.h) then
            self:drawCell(i, c, c.x, y, i == self.hoverIdx)
            local ty0 = math.max(y, G.top)
            local ty1 = math.min(y + c.h, G.bottom)
            if ty1 - ty0 >= c.h * 0.5 then
                NavCursor.target("bst:" .. i, c.x, ty0, c.w, ty1 - ty0)
            end
        end
    end
    love.graphics.setScissor()
    if G.maxScroll > 0 then
        local barX = width - 12
        local frac = self.scrollY / G.maxScroll
        local knobH = math.max(30, G.viewH * (G.viewH / (G.viewH + G.maxScroll)))
        rgba(Palette.INK, 0.5)
        love.graphics.rectangle("fill", barX, G.top, 6, G.viewH)
        rgba(Palette.AGED_GOLD)
        love.graphics.rectangle("fill", barX, G.top + frac * (G.viewH - knobH), 6, knobH)
    end
end

function Grid:drawCard()
    if not self.openIdx then return end
    local C, texts = self:cardLayout()
    local e = self:openEntry()
    local mx, my = love.mouse.getPosition()
    local seen, total = self:seenCount()
    local idx = 0
    for i = 1, self.openIdx do if Bestiary.isSeen(self.entries[i].id) then idx = idx + 1 end end
    local ease = 1 - (1 - self.openAnim) ^ 3
    local reduced = _G.gameSettings and _G.gameSettings.reducedMotion
    Card.draw(C, texts, e, { anim = reduced and 1 or (0.25 + 0.75 * ease), t = self.time, mx = mx, my = my,
        canNav = seen > 1, counter = idx .. "/" .. seen })
end

return Grid
