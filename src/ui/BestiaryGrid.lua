local FontManager = require("src.ui.FontManager")
local Palette = require("src.ui.Palette")
local I18n = require("src.i18n.I18n")
local TextCase = require("src.i18n.TextCase")
local TextFit = require("src.ui.TextFit")
local Layout = require("src.ui.BestiaryLayout")
local Sprites = require("src.ui.BestiarySprites")
local Card = require("src.ui.BestiaryCard")
local BInk = require("src.ui.BestiaryInk")
local Ink = require("src.ui.RunJournalInk")
local Bestiary = require("src.systems.Bestiary")
local Sfx = require("src.systems.Sfx")

local Grid = {}
Grid.__index = Grid

Grid.TOP = 114
Grid.BOTTOM_PAD = 36
Grid.PAGE_CACHE = 4
Grid.SCROLL_RATE = 12
Grid.NUMERALS = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII" }
Grid.RIBBON = {
    Palette.BLOOD, Palette.STEEL, Palette.RUST,
    Palette.lerp(Palette.STEEL, Palette.STEEL_LIGHT, 0.4), Palette.MOSS,
    Palette.lerp(Palette.BLOOD_DARK, Palette.ARCANE_INK or Palette.INK, 0.3),
}

local function rgba(c, a)
    love.graphics.setColor(c[1], c[2], c[3], (a or 1) * (c[4] or 1))
end

function Grid.new()
    local self = setmetatable({}, Grid)
    self.scrollY = 0
    self.scrollTarget = 0
    self.time = 0
    self.k = 1
    self.entries = {}
    self.openIdx = nil
    self.openAnim = 0
    self.pages = {}
    self.pageOrder = {}
    pcall(BInk.prewarm)
    return self
end

function Grid:refresh()
    self.entries = Bestiary.entries()
    self.layoutKey = nil
    self:dropPages()
end

function Grid:dropPages()
    for _, p in pairs(self.pages or {}) do
        if p.canvas and p.canvas.release then p.canvas:release() end
    end
    self.pages, self.pageOrder = {}, {}
end

function Grid:show()
    self:refresh()
    self.scrollY, self.scrollTarget = 0, 0
    self.openIdx = nil
    self.openAnim = 0
    self.hoverIdx = nil
    self.hoverT = {}
    self.bakeHold = 1
    self.warm = { function() BInk.engraveShader() end }
    for a = 1, 6 do
        local b = Card.biomeId(a)
        if b then
            self.warm[#self.warm + 1] = function() BInk.image("assets/sprites/world/" .. b .. "_mountains.png") end
            self.warm[#self.warm + 1] = function() BInk.image("assets/sprites/world/" .. b .. "_castle.png") end
        end
    end
    for _, e in ipairs(self.entries) do
        if Bestiary.isSeen(e.id) then Sprites.prefetch(e.id, false) end
    end
    for _, e in ipairs(self.entries) do
        if Bestiary.isSeen(e.id) then Sprites.prefetch(e.id, true) end
    end
end

function Grid:resize()
    self.layoutKey = nil
    self.cardKey = nil
    self:dropPages()
end

function Grid:layout()
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local key = sw .. "x" .. sh .. "@" .. self.k
    if self.layoutKey ~= key then
        self.G = Layout.grid(sw, sh, Grid.TOP, sh - Grid.BOTTOM_PAD, self.k, self.entries)
        self.layoutKey = key
        self:dropPages()
    end
    local mx = self.G.maxScroll
    self.scrollTarget = math.max(0, math.min(mx, self.scrollTarget or 0))
    self.scrollY = math.max(0, math.min(mx, self.scrollY))
    return self.G
end

function Grid:setScroll(y, instant)
    local G = self:layout()
    self.scrollTarget = math.max(0, math.min(G.maxScroll, y))
    if instant or BInk.reduced() then self.scrollY = self.scrollTarget end
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
    for i, c in pairs(G.cells) do
        local y = G.top + c.y - self.scrollY
        if mx >= c.x and mx <= c.x + c.w and my >= y and my <= y + c.h then return i end
    end
end

function Grid:ensureVisible(i)
    local G = self:layout()
    local c = G.cells[i]
    if not c then return end
    local y = c.y - self.scrollTarget
    if y < 0 then
        self:setScroll(c.y - 8)
    elseif y + c.h > G.viewH then
        self:setScroll(c.y + c.h - G.viewH + 8)
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
    if not BInk.reduced() then
        local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
        self.splash = BInk.splash(sw / 2, sh / 2, i * 31 + 7)
    end
    return true
end

function Grid:close()
    self.openIdx = nil
    self.cardKey = nil
    self.splash = nil
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
    self.openAnim = 0.55
    self.turnDir = delta
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

function Grid:actSeen(a)
    local seen, total = 0, 0
    for _, e in ipairs(self.entries) do
        if e.act == a then
            total = total + 1
            if Bestiary.isSeen(e.id) then seen = seen + 1 end
        end
    end
    return seen, total
end

function Grid:update(dt, mx, my)
    dt = dt or 0
    self.time = self.time + dt
    if self.warm and #self.warm > 0 then
        table.remove(self.warm, 1)()
    else
        Sprites.pump()
    end
    if BInk.reduced() then
        self.scrollY = self.scrollTarget or self.scrollY
    else
        local d = (self.scrollTarget or self.scrollY) - self.scrollY
        if math.abs(d) < 0.5 then self.scrollY = self.scrollTarget
        else self.scrollY = self.scrollY + d * math.min(1, dt * Grid.SCROLL_RATE) end
    end
    self.splash = BInk.updateSplash(self.splash, dt)
    local e = self:openEntry()
    if e and e.tier == "boss" then
        local okA, BossAura = pcall(require, "src.ui.BossAura")
        if okA and BossAura.has(e.id) then BossAura.update(dt, e.id) end
    end
    self.hoverT = self.hoverT or {}
    for i, v in pairs(self.hoverT) do
        local target = (i == self.hoverIdx) and 1 or 0
        local nv = v + (target - v) * math.min(1, dt * 12)
        if BInk.reduced() then nv = target end
        self.hoverT[i] = (nv < 0.01 and target == 0) and nil or nv
    end
    if self.openIdx then
        self.openAnim = math.min(1, self.openAnim + dt * 5)
        self.hoverIdx = nil
        return
    end
    self.openAnim = 0
    local prev = self.hoverIdx
    self.hoverIdx = self:hitCell(mx, my)
    if self.hoverIdx then self.hoverT[self.hoverIdx] = self.hoverT[self.hoverIdx] or 0 end
    if self.hoverIdx and self.hoverIdx ~= prev then
        local NavCursor = require("src.ui.NavCursor")
        if NavCursor.isActive() then self:ensureVisible(self.hoverIdx) end
        Sfx.playWithVariation("hoverCard", 0.95, 0.18)
    end
    if self.hoverIdx then
        local h = self.entries[self.hoverIdx]
        if h and Bestiary.isNew(h.id) then Bestiary.clearNew(h.id) end
    end
end

function Grid:columnNeighbor(i, dir)
    local G = self:layout()
    local c = G.cells[i]
    if not c then return nil end
    local cx = c.x + c.w / 2
    local best, bd
    for j, d in pairs(G.cells) do
        if j ~= i and cx >= d.x - 8 and cx <= d.x + d.w + 8 then
            local dy = (d.y - c.y) * dir
            if dy > 0 and (not bd or dy < bd) then best, bd = j, dy end
        end
    end
    return best
end

function Grid:wheelmoved(_, y)
    if self.openIdx then return end
    local NavCursor = require("src.ui.NavCursor")
    if NavCursor.synthesizing and self.hoverIdx then
        local nxt = self:columnNeighbor(self.hoverIdx, y < 0 and 1 or -1)
        if nxt then
            local G = self:layout()
            local d = G.cells[nxt]
            local peek = math.min(d.h * 0.6, 110)
            local want = y < 0 and (d.y + peek - G.viewH) or (d.y + d.h - peek)
            if y < 0 then want = math.max(want, self.scrollTarget + 20) else want = math.min(want, self.scrollTarget - 20) end
            self:setScroll(want, true)
            return
        end
    end
    self:setScroll((self.scrollTarget or self.scrollY) - y * 60)
end

function Grid:scrollToAct(a)
    local G = self:layout()
    local act = G.acts[a]
    if act then self:setScroll(act.page.y) end
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
        self:setScroll(self.scrollTarget - (key == "up" and 100 or G.viewH))
        return true
    elseif key == "down" or key == "pagedown" then
        self:setScroll(self.scrollTarget + (key == "down" and 100 or G.viewH))
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
    for a, ch in pairs(G.chips) do
        if Card.hit(ch, x, y) then
            Sfx.play("collectionFlip")
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

local screenScissor = Layout.scissor

function Grid:currentAct()
    local G = self:layout()
    local best
    for a, act in pairs(G.acts) do
        if act.page.y <= self.scrollY + G.viewH * 0.4 and (not best or act.page.y > G.acts[best].page.y) then
            best = a
        end
    end
    return best or 1
end

function Grid:actHasNew(a)
    for _, e in ipairs(self.entries) do
        if e.act == a and Bestiary.isNew(e.id) then return true end
    end
    return false
end

function Grid.ribbonText(ch)
    local nf = FontManager.getFont(10)
    local tx = ch.x + 8 + nf:getWidth("VIII") + 6
    return tx, ch.x + ch.w - 8 - tx
end

function Grid:ribbonLines(a, w)
    local label = Card.biomeName(a)
    local f = FontManager.getFont(8)
    local _, lines = f:getWrap(label, w)
    return lines
end

function Grid:drawChips()
    local G = self:layout()
    local NavCursor = require("src.ui.NavCursor")
    local cur = self:currentAct()
    local mx, my = love.mouse.getPosition()
    for a, ch in pairs(G.chips) do
        local active = a == cur
        local hot = Card.hit(ch, mx, my) and not self.openIdx
        local drop = active and 6 or (hot and 3 or 0)
        local col = Grid.RIBBON[((a - 1) % #Grid.RIBBON) + 1]
        local x, y, w, h = ch.x, ch.y, ch.w, ch.h + drop
        rgba(Palette.INK, 0.5)
        love.graphics.rectangle("fill", x + 2, y + 2, w, h - 6)
        rgba(col)
        love.graphics.rectangle("fill", x, y, w, h - 6)
        love.graphics.polygon("fill", x, y + h - 6, x + w / 2, y + h - 6, x, y + h)
        love.graphics.polygon("fill", x + w, y + h - 6, x + w / 2, y + h - 6, x + w, y + h)
        rgba(Palette.lighten(col, 0.25), 0.8)
        love.graphics.rectangle("fill", x + 3, y, 1, h - 7)
        love.graphics.rectangle("fill", x + w - 4, y, 1, h - 7)
        rgba(Palette.darken(col, 0.45), 0.9)
        love.graphics.rectangle("fill", x, y, w, 2)
        local numeral = Grid.NUMERALS[a] or tostring(a)
        local nf = FontManager.getFont(10)
        love.graphics.setFont(nf)
        rgba(Palette.PARCHMENT_LIGHT, active and 1 or 0.85)
        local ny = y + math.floor((h - 6 - nf:getHeight()) / 2) + 1
        love.graphics.print(numeral, x + 8, ny)
        local tx, tw = Grid.ribbonText(ch)
        local lines = self:ribbonLines(a, tw)
        local f = FontManager.getFont(8)
        love.graphics.setFont(f)
        local lh = f:getHeight() + 2
        local ty = y + math.floor((h - 6 - #lines * lh) / 2) + 1
        for li, line in ipairs(lines) do
            love.graphics.print(line, tx, ty + (li - 1) * lh)
        end
        if self:actHasNew(a) then BInk.alert(x + w - 6, y + 4, self.time) end
        NavCursor.target("bstchip:" .. a, ch.x, ch.y, ch.w, ch.h)
    end
end

function Grid:pageKey(page)
    local parts = { self.layoutKey or "", I18n.current or "" }
    for i, c in pairs(self.G.cells) do
        if c.act == page.act then
            local id = self.entries[i].id
            parts[#parts + 1] = (Bestiary.isSeen(id) and "s" or "-") .. (Bestiary.isDefeated(id) and "d" or "-")
        end
    end
    return table.concat(parts, "")
end

local function nameFont(c)
    return c.tier == "boss" and 12 or 8
end

function Grid:bakeSlot(i, c)
    local e = self.entries[i]
    local seen = Bestiary.isSeen(e.id)
    local seed = i * 97
    Ink.begin()
    if not seen then
        BInk.frame(c.x + 6, c.y + 6, c.w - 12, c.h - 12, seed, BInk.FADED, 0.75, { wobble = 0.5 })
        Ink.flush()
        return
    end
    if c.tier == "boss" then
        Ink.flush()
        rgba(Ink.PAPER_DARK, 0.55)
        love.graphics.rectangle("fill", c.x + 4, c.y + 4, c.w - 8, c.h - 8)
        Ink.begin()
        BInk.frame(c.x + 2, c.y + 2, c.w - 4, c.h - 4, seed, BInk.INK, 0.85, { overshoot = 6 })
        BInk.frame(c.x + 7, c.y + 7, c.w - 14, c.h - 14, seed + 50, BInk.SEPIA, 0.7, { wobble = 0.6 })
        BInk.corners(c.x + 7, c.y + 7, c.w - 14, c.h - 14, BInk.INK, 0.8, seed, 12)
    elseif c.tier == "miniboss" then
        BInk.frame(c.x + 3, c.y + 3, c.w - 6, c.h - 6, seed, BInk.SEPIA, 0.85, { overshoot = 4 })
        BInk.frame(c.x + 7, c.y + 7, c.w - 14, c.h - 14, seed + 50, BInk.SEPIA, 0.5, { wobble = 0.6 })
    elseif c.tier == "elite" then
        BInk.frame(c.x + 4, c.y + 4, c.w - 8, c.h - 8, seed, BInk.SEPIA, 0.8, { overshoot = 3 })
    else
        BInk.tape(c.x + 18, c.y + 8, 28, 9, -0.12, seed)
        BInk.tape(c.x + c.w - 18, c.y + 8, 28, 9, 0.12, seed + 3)
    end
    BInk.hatchGround(c.x + math.floor(c.w * 0.2), c.groundY + 2, math.floor(c.w * 0.6), seed, BInk.SEPIA, 0.55)
    if c.tier ~= "common" then BInk.seal(c.seal.x, c.seal.y, c.seal.r, c.tier, seed) end
    Ink.flush()
    local name = Card.name(e.id)
    rgba(BInk.INK, 0.92)
    local nf = nameFont(c)
    local w = TextFit.print(name, c.x + 10, c.nameY, { size = nf, maxW = c.w - 20, align = "center", minSize = 7 })
    local f = FontManager.getFont(nf)
    local ux = c.x + math.floor((c.w - w) / 2)
    Ink.begin()
    Ink.line(ux, c.nameY + f:getHeight() + 3, ux + w, c.nameY + f:getHeight() + 2, BInk.SEPIA, 0.6, seed + 9, { wobble = 0.4 })
    Ink.flush()
    if c.tier == "boss" then
        local ep = I18n.t("bestiary.creature." .. e.id .. ".epithet", nil, "")
        if ep ~= "" and ep ~= "bestiary.creature." .. e.id .. ".epithet" then
            rgba(Palette.RUST)
            TextFit.print(ep, c.x + 12, c.nameY + f:getHeight() + 8,
                { size = 8, maxW = c.w - 24, align = "center", minSize = 7 })
        end
    end
    if Bestiary.isDefeated(e.id) then
        Ink.begin()
        local tx, ty = c.x + 12, c.y + (c.tier == "common" and 18 or 14)
        Ink.line(tx, ty + 3, tx + 3, ty + 6, BInk.RED, 0.85, seed + 21, { wobble = 0.2, weight = 2 })
        Ink.line(tx + 3, ty + 6, tx + 9, ty - 1, BInk.RED, 0.85, seed + 22, { wobble = 0.2, weight = 2 })
        Ink.flush()
    end
end

function Grid:bakePage(page)
    local k = self.k
    local W, H = math.ceil(page.w * k), math.ceil(page.h * k)
    local canvas = love.graphics.newCanvas(W, H)
    canvas:setFilter("nearest", "nearest")
    love.graphics.push("all")
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.origin()
    love.graphics.setScissor()
    love.graphics.scale(k)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(BInk.paper(page.w, page.h, 13 + page.act % 2), 0, 0)
    love.graphics.translate(-page.x, -page.y)
    local a = page.act
    local h = page.header
    local v = page.vignette
    local biome = Card.biomeId(a)
    if biome then
        BInk.engrave("assets/sprites/world/" .. biome .. "_mountains.png", v.x, v.y, v.w, v.h, 0.9, BInk.SEPIA, 1.5)
        BInk.engrave("assets/sprites/world/" .. biome .. "_castle.png", v.x + v.w - 96, v.y + 6, 80, v.h - 6, 0.9, BInk.SEPIA, 1.25)
    end
    local numeral = Grid.NUMERALS[a] or tostring(a)
    local big = FontManager.getFont(24)
    love.graphics.setFont(big)
    rgba(BInk.RED, 0.9)
    love.graphics.print(numeral, h.x, h.y + 4)
    local nx = h.x + big:getWidth(numeral) + 14
    rgba(BInk.SEPIA)
    TextFit.print(TextCase.upper(I18n.t("acts.fallback", { n = a })), nx, h.y + 4,
        { size = 8, maxW = v.x - nx - 12, minSize = 7 })
    rgba(BInk.INK)
    TextFit.print(Card.biomeName(a), nx, h.y + 18, { size = 16, maxW = v.x - nx - 12, minSize = 10 })
    local seen, total = self:actSeen(a)
    rgba(Palette.RUST)
    TextFit.print(I18n.t("bestiary.ui.count", { n = seen, total = total }), nx, h.y + 42,
        { size = 8, maxW = v.x - nx - 12, minSize = 7 })
    Ink.begin()
    local ly = h.y + h.h - 2
    Ink.line(h.x, ly, h.x + h.w, ly + 1, BInk.SEPIA, 0.7, a * 7, { wobble = 0.8 })
    Ink.line(h.x + 40, ly + 3, h.x + h.w - 40, ly + 4, BInk.SEPIA, 0.35, a * 7 + 1, { wobble = 0.8, dash = 6, gap = 4 })
    BInk.tally(nx, h.y + 54, seen, BInk.INK, 0.75, a * 5, 8)
    local f = page.footer
    Ink.line(f.x + f.w / 2 - 60, f.y + 6, f.x + f.w / 2 - 12, f.y + 6, BInk.SEPIA, 0.5, a * 3, { wobble = 0.5 })
    Ink.line(f.x + f.w / 2 + 12, f.y + 6, f.x + f.w / 2 + 60, f.y + 6, BInk.SEPIA, 0.5, a * 3 + 1, { wobble = 0.5 })
    Ink.flush()
    local ff = FontManager.getFont(8)
    love.graphics.setFont(ff)
    rgba(BInk.SEPIA)
    love.graphics.print(numeral, math.floor(f.x + f.w / 2 - ff:getWidth(numeral) / 2), f.y + 2)
    for i, c in pairs(self.G.cells) do
        if c.act == a then self:bakeSlot(i, c) end
    end
    love.graphics.pop()
    return canvas
end

function Grid:pageCanvas(page, allowBake)
    local p = self.pages[page.act]
    local key = self:pageKey(page)
    if p and p.key == key then return p.canvas, false end
    if not allowBake then return p and p.canvas or nil, false end
    if p and p.canvas then p.canvas:release() end
    local canvas = self:bakePage(page)
    self.pages[page.act] = { canvas = canvas, key = key }
    for i, a in ipairs(self.pageOrder) do if a == page.act then table.remove(self.pageOrder, i) break end end
    self.pageOrder[#self.pageOrder + 1] = page.act
    while #self.pageOrder > Grid.PAGE_CACHE do
        local old = table.remove(self.pageOrder, 1)
        local op = self.pages[old]
        if op and op.canvas then op.canvas:release() end
        self.pages[old] = nil
    end
    return canvas, true
end

function Grid:drawSlotLive(i, c, y)
    local e = self.entries[i]
    local seen = Bestiary.isSeen(e.id)
    local hv = (self.hoverT and self.hoverT[i]) or 0
    local dy = y - c.y
    if not seen then
        local size = c.tier == "boss" and 48 or 32
        local cy = c.y + dy + math.floor((c.h - (c.tier == "boss" and 10 or 0)) / 2)
        BInk.question(c.x + c.w / 2, cy, self.time + i * 0.7, size, 1)
        if hv > 0.05 then
            Ink.begin()
            BInk.frame(c.x + 6, c.y + dy + 6, c.w - 12, c.h - 12, i * 97, BInk.SEPIA, 0.6 * hv, { wobble = 0.5 })
            Ink.flush()
        end
        return
    end
    Sprites.want(e.id, true)
    local lift = math.floor(hv * 3 + 0.5)
    local gy = c.groundY + dy + 2
    local s = c.s
    BInk.shadow(c.x + c.w / 2, gy, math.floor(Layout.REF_W * s * (0.62 + 0.1 * hv)), 1 - 0.3 * hv)
    local box = c.spriteBox
    local sx0, sy0, sw0, sh0 = love.graphics.getScissor()
    local vy0 = math.max(box.y + dy - 6, self.G.top)
    local vy1 = math.min(box.y + dy + box.h, self.G.bottom)
    if vy1 > vy0 then
        screenScissor(box.x, vy0, box.w, vy1 - vy0)
        Card.drawSprite(e.id, c.x + c.w / 2, gy - lift, s, self.time, 1, false)
        if sx0 then love.graphics.setScissor(sx0, sy0, sw0, sh0) else love.graphics.setScissor() end
    end
    if hv > 0.05 then
        Ink.begin()
        BInk.corners(c.x + 3, c.y + dy + 3, c.w - 6, c.h - 6, BInk.INK, 0.85 * hv, i * 3, c.tier == "boss" and 16 or 10)
        Ink.flush()
        rgba(BInk.INK, hv)
        TextFit.print(Card.name(e.id), c.x + 10, c.nameY + dy,
            { size = nameFont(c), maxW = c.w - 20, align = "center", minSize = 7 })
        require("src.ui.CursorManager").request("hand")
    end
    if Bestiary.isNew(e.id) then
        BInk.alert(c.x + c.w - (c.tier == "common" and 12 or 32), c.y + dy + 12, self.time)
    end
end

function Grid:draw()
    self.k = Layout.physScale()
    local G = self:layout()
    local width = love.graphics.getWidth()
    self:drawChips()
    screenScissor(0, G.top, width, G.viewH)
    local baked = 0
    if (self.bakeHold or 0) > 0 then
        self.bakeHold = self.bakeHold - 1
        baked = 1
    end
    for _, page in ipairs(G.pages) do
        local y = G.top + page.y - self.scrollY
        if inView(G, y, page.h) then
            local canvas, did = self:pageCanvas(page, baked < 1)
            if did then baked = baked + 1 end
            rgba(Palette.INK, 0.55)
            love.graphics.rectangle("fill", page.x + 4, y + 6, page.w, page.h)
            if canvas then
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(canvas, page.x, y, 0, 1 / self.k, 1 / self.k)
            else
                rgba(Ink.PAPER)
                love.graphics.rectangle("fill", page.x, y, page.w, page.h)
            end
        end
    end
    local NavCursor = require("src.ui.NavCursor")
    for i, c in pairs(G.cells) do
        local y = G.top + c.y - self.scrollY
        if inView(G, y, c.h) then
            self:drawSlotLive(i, c, y)
            local fh = math.min(c.h, G.slotH)
            local ty0 = math.max(y, G.top)
            local ty1 = math.min(y + fh, G.bottom)
            if ty1 - ty0 >= math.min(fh * 0.5, 90) then
                NavCursor.target("bst:" .. i, c.x, ty0, c.w, ty1 - ty0)
            end
        end
    end
    love.graphics.setScissor()
    if G.maxScroll > 0 then
        local barX = width - 10
        local frac = self.scrollY / G.maxScroll
        local knobH = math.max(30, G.viewH * (G.viewH / (G.viewH + G.maxScroll)))
        rgba(Palette.PARCHMENT_DARK, 0.6)
        love.graphics.rectangle("fill", barX + 2, G.top, 1, G.viewH)
        rgba(Palette.PARCHMENT_LIGHT, 0.9)
        love.graphics.rectangle("fill", barX, G.top + frac * (G.viewH - knobH), 5, knobH)
    end
end

function Grid:drawCard()
    if not self.openIdx then return end
    local C, texts = self:cardLayout()
    local e = self:openEntry()
    local mx, my = love.mouse.getPosition()
    local seen = self:seenCount()
    local idx = 0
    for i = 1, self.openIdx do if Bestiary.isSeen(self.entries[i].id) then idx = idx + 1 end end
    local ease = 1 - (1 - self.openAnim) ^ 3
    local reduced = BInk.reduced()
    Card.draw(C, texts, e, { anim = reduced and 1 or ease, t = self.time, mx = mx, my = my,
        canNav = seen > 1, counter = idx .. "/" .. seen, turn = self.turnDir })
    BInk.drawSplash(self.splash)
    love.graphics.setColor(1, 1, 1, 1)
end

return Grid
